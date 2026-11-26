import Foundation

/// 通信の種類
enum Network: String, Codable {
    case cellular
    case wifi
}

/// 通信インターフェースのカウンタを読んだ値。
/// キーは「インターフェース名.向き」(例: pdp_ip0.in)。iOS は 32bit で返すので、約4GiBで一周する。
struct RawCounters: Codable, Equatable {
    var values: [String: UInt32]
    /// 携帯が起動した時刻。カウンタは再起動で 0 に戻るので、これが変わったら再起動と見なす
    var bootTime: Date
}

/// 前回読んだ値からの増加量
struct CounterDelta: Equatable {
    var cellular: UInt64 = 0
    var wifi: UInt64 = 0
    /// 再起動をはさんだ (再起動の直前に使った分は取りこぼしている)
    var rebooted = false
    /// 一周ではなくカウンタが 0 に戻った (回線のつなぎ直しなど)
    var reset = false
}

enum CounterMath {
    /// これより大きい値から小さくなったときだけ、一周したと見なす (3GiB)
    static let wrapThreshold: UInt32 = 0xC000_0000

    static func network(ofInterface name: String) -> Network? {
        if name.hasPrefix("pdp_ip") { return .cellular }
        if name == "en0" { return .wifi }
        return nil
    }

    static func network(ofKey key: String) -> Network? {
        network(ofInterface: String(key.prefix { $0 != "." }))
    }

    static func delta(from old: RawCounters, to new: RawCounters) -> CounterDelta {
        var result = CounterDelta()
        // 起動時刻は時計の補正で少し動くことがあるので、2 分以上ずれたときだけ再起動とする
        result.rebooted = abs(new.bootTime.timeIntervalSince(old.bootTime)) > 120
        for (key, value) in new.values {
            guard let network = network(ofKey: key) else { continue }
            var amount = UInt64(value)
            if !result.rebooted, let previous = old.values[key] {
                if value >= previous {
                    amount = UInt64(value - previous)
                } else if previous >= wrapThreshold {
                    amount = UInt64(value) + (UInt64(1) << 32) - UInt64(previous)
                } else {
                    result.reset = true
                }
            }
            switch network {
            case .cellular: result.cellular += amount
            case .wifi: result.wifi += amount
            }
        }
        return result
    }
}

/// 期間 (end は含まない)
struct TimeRange: Equatable {
    var start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func contains(_ date: Date) -> Bool { date >= start && date < end }
}

/// 3 時間ごとなどに記録した、前回からの増加量
struct Sample: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        /// ショートカットのオートメーション
        case automation
        /// アプリを開いたとき
        case app
        /// iOS のバックグラウンド更新
        case background
    }

    var id = UUID()
    /// この増加量が使われた期間の始まり (前回の記録、再起動ならその起動時刻)
    var previousDate: Date
    var date: Date
    var cellular: UInt64
    var wifi: UInt64
    /// 再起動やカウンタのリセットをはさみ、取りこぼしがあるかもしれない
    var estimated: Bool
    var source: Source

    var span: TimeInterval { date.timeIntervalSince(previousDate) }

    /// 期間に重なる割合。記録の間は一定のペースで使ったと見なして按分する
    func portion(in range: TimeRange) -> Double {
        guard span > 0 else { return range.contains(date) ? 1 : 0 }
        let overlap = min(date, range.end).timeIntervalSince(max(previousDate, range.start))
        return max(0, overlap) / span
    }

    func cellular(in range: TimeRange) -> Double { portion(in: range) * Double(cellular) }
    func wifi(in range: TimeRange) -> Double { portion(in: range) * Double(wifi) }
}

/// 選んだプラン。中身は PlanCatalog にあり、保存するのは名前 (id) だけ。
/// 前の版で保存した "linemoMini" "povo20" "custom" もそのまま読める
struct PlanPreset: Codable, Hashable, Identifiable {
    let id: String

    static let linemoMini = PlanPreset(id: "linemoMini")
    static let povo20 = PlanPreset(id: "povo20")
    static let custom = PlanPreset(id: "custom")

    init(id: String) { self.id = id }

    init(from decoder: Decoder) throws {
        id = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }

    /// 一覧にない名前 (この先プランを消したときなど) は「そのほかのプラン」として扱う
    var spec: PlanSpec { PlanCatalog.spec(id: id) ?? PlanCatalog.spec(id: "custom")! }

    var title: String { spec.title }
    var defaultCapGB: Double { spec.defaultCapGB }

    /// LINE ギガフリーで、LINE アプリの通信は通信会社が数えない
    var excludesLINE: Bool { spec.excludesLINE }
}

struct Plan: Codable, Equatable {
    var preset: PlanPreset
    var capGB: Double
    /// 締め日。0 は月末、1〜27 はその日の終わりで締める
    var closingDay: Int

    init(preset: PlanPreset, capGB: Double? = nil, closingDay: Int = 0) {
        self.preset = preset
        self.capGB = capGB ?? preset.defaultCapGB
        self.closingDay = closingDay
    }

    /// 通信会社は 1GB を 10 億バイトとして数える前提にする (1024 で数えるより上限が小さくなり、早めに気づける)
    static let bytesPerGB = 1_000_000_000.0

    /// その日時を含む、締め日から締め日までの期間
    func period(containing date: Date, calendar: Calendar) -> TimeRange {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let monthStart = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1))!
        let nextMonth = { (date: Date) in calendar.date(byAdding: .month, value: 1, to: date)! }
        guard (1...27).contains(closingDay) else {
            return TimeRange(start: monthStart, end: nextMonth(monthStart))
        }
        let cut = calendar.date(byAdding: .day, value: closingDay, to: monthStart)!
        if date < cut {
            return TimeRange(start: calendar.date(byAdding: .month, value: -1, to: cut)!, end: cut)
        }
        return TimeRange(start: cut, end: nextMonth(cut))
    }
}

/// 通信会社の値で補正した記録
struct Correction: Codable, Identifiable, Equatable {
    var id = UUID()
    /// 通信会社がこの値を集計した時刻 (入力した時刻ではない)
    var asOf: Date
    var usedBytes: Double
    /// 買い切りのプランで入れた「その時点の残り」。月ごとのプランでは nil
    var remainingBytes: Double? = nil
}

/// 買い切りのトッピング (povo2.0 など)。期間の中だけ使え、期限が近いものから減る
struct Topping: Codable, Identifiable, Equatable {
    var id = UUID()
    /// 容量 (GB)。nil は使い放題 (その間の通信は数えない)
    var gb: Double?
    var start: Date
    /// 期限 (この時刻からは使えない)
    var end: Date

    var range: TimeRange { TimeRange(start: start, end: end) }
    var bytes: Double? { gb.map { $0 * Plan.bytesPerGB } }
}

/// トッピングごとの残り
struct ToppingStatus: Identifiable, Equatable {
    var topping: Topping
    /// 残りのバイト数。使い放題なら nil
    var remaining: Double?
    var id: UUID { topping.id }
}

/// 容量を追加で買った記録
struct Extra: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var gb: Double
}

/// 警告の段階 (大きいほど危ない)
enum AlertLevel: Int, Codable, Comparable {
    case normal
    /// 理想のペースを 20% 超えた
    case pace
    /// 残り 20%
    case low
    /// 残り 5%、または上限まで 2 日以内
    case critical

    static func < (a: AlertLevel, b: AlertLevel) -> Bool { a.rawValue < b.rawValue }
}

struct UsageSummary: Equatable {
    var period: TimeRange
    var now: Date
    var used: Double
    var cap: Double
    /// 直近のペース (1 日あたりのバイト数)。記録が少なければ nil
    var pacePerDay: Double?
    /// このペースで上限に達する日時。締め日まで持つなら nil
    var forecast: Date?
    var today: Double
    var hasEstimate: Bool
    /// 買い切りのプランで、使えるトッピングがない
    var noActiveTopping = false

    var remaining: Double { cap - used }
    var usedFraction: Double { cap > 0 ? used / cap : 0 }
    var remainingFraction: Double { cap > 0 ? max(0, remaining) / cap : 0 }
    var elapsedFraction: Double { min(1, max(0, now.timeIntervalSince(period.start) / period.duration)) }
    /// 月の初めの 5 日間は、予測の誤差が大きい
    var isEarly: Bool { now.timeIntervalSince(period.start) < 5 * 86400 }
    var lastsUntilEnd: Bool { pacePerDay != nil && forecast == nil }

    var level: AlertLevel {
        if noActiveTopping { return .normal }
        if remainingFraction <= 0.05 { return .critical }
        if let forecast, forecast.timeIntervalSince(now) <= 2 * 86400 { return .critical }
        if remainingFraction <= 0.2 { return .low }
        // 使い始めは少しの量でも割合が大きく出るので、上限の 1 割を超えてから見る
        if usedFraction >= 0.1, usedFraction > elapsedFraction * 1.2 { return .pace }
        return .normal
    }
}

/// 記録から、今月の使用量や予測を計算する
struct Ledger {
    var plan: Plan
    var samples: [Sample]
    var corrections: [Correction] = []
    var extras: [Extra] = []
    var toppings: [Topping] = []
    var calendar: Calendar

    var isPrepaid: Bool { plan.preset.spec.kind == .prepaid }

    func cellular(in range: TimeRange) -> Double {
        samples.reduce(0) { $0 + $1.cellular(in: range) }
    }

    func wifi(in range: TimeRange) -> Double {
        samples.reduce(0) { $0 + $1.wifi(in: range) }
    }

    func cap(for period: TimeRange) -> Double {
        let extra = extras.filter { period.contains($0.date) }.reduce(0) { $0 + $1.gb }
        return (plan.capGB + extra) * Plan.bytesPerGB
    }

    /// その期間に、指定の時刻までに使った量。期間内に補正があれば、最後の補正を起点にする
    func used(in period: TimeRange, until moment: Date) -> Double {
        let end = min(moment, period.end)
        let correction = corrections
            .filter { $0.asOf >= period.start && $0.asOf <= end }
            .max { $0.asOf < $1.asOf }
        if let correction {
            return correction.usedBytes + cellular(in: TimeRange(start: correction.asOf, end: end))
        }
        return cellular(in: TimeRange(start: period.start, end: end))
    }

    func summary(at now: Date) -> UsageSummary {
        if isPrepaid { return prepaidSummary(at: now) }
        let period = plan.period(containing: now, calendar: calendar)
        let used = used(in: period, until: now)
        let cap = cap(for: period)
        let pace = self.pace(at: now)
        var forecast: Date?
        if cap - used <= 0 {
            forecast = now
        } else if let pace, pace > 0 {
            let reach = now.addingTimeInterval((cap - used) / pace * 86400)
            if reach < period.end { forecast = reach }
        }

        let today = TimeRange(start: calendar.startOfDay(for: now), end: now)
        let hasEstimate = samples.contains { $0.estimated && $0.portion(in: period) > 0 }
        return UsageSummary(period: period, now: now, used: used, cap: cap, pacePerDay: pace,
                            forecast: forecast, today: cellular(in: today), hasEstimate: hasEstimate)
    }

    /// 直近 3 日間 (記録がそれより短ければ、記録のある間) のペース。記録が 6 時間分に満たなければ nil
    func pace(at now: Date) -> Double? {
        guard let first = samples.map(\.previousDate).min() else { return nil }
        let window = TimeRange(start: max(now.addingTimeInterval(-3 * 86400), first), end: now)
        guard window.duration >= 6 * 3600 else { return nil }
        return cellular(in: window) / window.duration * 86400
    }

    // MARK: - 買い切りのプラン

    /// その時刻までの使用量を、トッピングに割り振った結果。期限が近いものから減らし、
    /// 使い放題のトッピングの間の通信は数えない。補正で入れた残りに合わせて、その時点の残りを直す
    func toppingStatuses(at now: Date) -> [ToppingStatus] {
        var remaining: [UUID: Double] = [:]
        for topping in toppings { if let bytes = topping.bytes { remaining[topping.id] = bytes } }
        guard let first = toppings.map(\.start).min(), first < now else {
            return toppings.map { ToppingStatus(topping: $0, remaining: remaining[$0.id]) }
        }

        // 記録は、その記録の時刻に使ったものとして割り振る
        enum Event { case use(Double), correct(Double) }
        var events: [(date: Date, order: Int, event: Event)] = []
        for sample in samples where sample.date > first && sample.previousDate < now {
            let amount = sample.cellular(in: TimeRange(start: first, end: now))
            if amount > 0 { events.append((min(sample.date, now), 0, .use(amount))) }
        }
        for correction in corrections {
            if let target = correction.remainingBytes, correction.asOf >= first, correction.asOf <= now {
                events.append((correction.asOf, 1, .correct(target)))
            }
        }
        events.sort { ($0.date, $0.order) < ($1.date, $1.order) }

        for item in events {
            let active = toppings.filter { $0.range.contains(item.date) }.sorted { $0.end < $1.end }
            let finite = active.filter { $0.gb != nil }
            switch item.event {
            case .use(let amount):
                guard !active.contains(where: { $0.gb == nil }) else { continue }
                var left = amount
                for topping in finite where left > 0 {
                    let take = min(remaining[topping.id] ?? 0, left)
                    remaining[topping.id, default: 0] -= take
                    left -= take
                }
            case .correct(let target):
                let current = finite.reduce(0) { $0 + (remaining[$1.id] ?? 0) }
                if current > target {
                    var left = current - target
                    for topping in finite where left > 0 {
                        let take = min(remaining[topping.id] ?? 0, left)
                        remaining[topping.id, default: 0] -= take
                        left -= take
                    }
                } else {
                    var left = target - current
                    for topping in finite where left > 0 {
                        let room = (topping.bytes ?? 0) - (remaining[topping.id] ?? 0)
                        let put = min(room, left)
                        remaining[topping.id, default: 0] += put
                        left -= put
                    }
                }
            }
        }
        return toppings.map { ToppingStatus(topping: $0, remaining: remaining[$0.id]) }
    }

    /// 今使えるトッピング (期限の近い順)
    func activeToppings(at now: Date) -> [ToppingStatus] {
        toppingStatuses(at: now).filter { $0.topping.range.contains(now) }.sorted { $0.topping.end < $1.topping.end }
    }

    /// 買い切りのプランの集計。期間は、今使えるトッピングのうち最も早い使い始めから最も遅い期限まで
    func prepaidSummary(at now: Date) -> UsageSummary {
        let active = activeToppings(at: now).filter { $0.topping.gb != nil }
        let todayRange = TimeRange(start: calendar.startOfDay(for: now), end: now)
        guard let start = active.map(\.topping.start).min(), let end = active.map(\.topping.end).max() else {
            return UsageSummary(period: TimeRange(start: todayRange.start, end: now.addingTimeInterval(86400)), now: now,
                                used: 0, cap: 0, pacePerDay: self.pace(at: now), forecast: nil,
                                today: cellular(in: todayRange), hasEstimate: false, noActiveTopping: true)
        }
        let period = TimeRange(start: start, end: end)
        let cap = active.reduce(0) { $0 + ($1.topping.bytes ?? 0) }
        let left = active.reduce(0) { $0 + max(0, $1.remaining ?? 0) }
        let pace = self.pace(at: now)
        var forecast: Date?
        if left <= 0 {
            forecast = now
        } else if let pace, pace > 0 {
            let reach = now.addingTimeInterval(left / pace * 86400)
            if reach < period.end { forecast = reach }
        }
        let hasEstimate = samples.contains { $0.estimated && $0.portion(in: period) > 0 }
        return UsageSummary(period: period, now: now, used: cap - left, cap: cap, pacePerDay: pace,
                            forecast: forecast, today: cellular(in: todayRange), hasEstimate: hasEstimate)
    }

    /// 期間の日ごとの使用量と、その日の終わりまでの累計 (今日まで)
    func days(in period: TimeRange, now: Date) -> [DayUsage] {
        var result: [DayUsage] = []
        var day = calendar.startOfDay(for: period.start)
        while day < min(period.end, now) {
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            let range = TimeRange(start: max(day, period.start), end: min(next, now))
            let cumulative = isPrepaid ? prepaidSummary(at: range.end).used : used(in: period, until: range.end)
            result.append(DayUsage(date: day, amount: cellular(in: range), cumulative: cumulative))
            day = next
        }
        return result
    }

    /// 3 時間ごとの時間帯 (0時, 3時 … 21時) の使用量。記録の間が 4 時間を超えるか、
    /// 再起動をはさんだ記録は、どの時間帯に使ったか分からないので unknown に入れる
    func slots(in period: TimeRange, now: Date) -> SlotUsage {
        var usage = SlotUsage()
        let range = TimeRange(start: period.start, end: min(period.end, now))
        for sample in samples {
            let amount = sample.cellular(in: range)
            guard amount > 0 else { continue }
            if sample.span > 4 * 3600 || sample.estimated {
                usage.unknown += amount
                continue
            }
            var cursor = max(sample.previousDate, range.start)
            let end = min(sample.date, range.end)
            while cursor < end {
                let slot = calendar.component(.hour, from: cursor) / 3
                let slotStart = calendar.date(bySettingHour: slot * 3, minute: 0, second: 0, of: cursor)!
                let next = min(slotStart.addingTimeInterval(3 * 3600), end)
                usage.slots[slot] += sample.cellular(in: TimeRange(start: cursor, end: next))
                cursor = next
            }
        }
        return usage
    }

    /// オートメーションの時刻 (0時, 3時 … 21時) のうち、直近 24 時間で記録が届かなかったもの
    func missingAutomationHours(now: Date) -> [Int] {
        let automation = samples.filter { $0.source == .automation }.map(\.date)
        return stride(from: 0, to: 24, by: 3).filter { hour in
            // 1 時間の猶予をみて、いちばん最近のその時刻を調べる
            var slot = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)!
            if slot > now.addingTimeInterval(-3600) {
                slot = calendar.date(byAdding: .day, value: -1, to: slot)!
            }
            return !automation.contains { $0 >= slot.addingTimeInterval(-600) && $0 <= slot.addingTimeInterval(3600) }
        }
    }
}

struct DayUsage: Identifiable, Equatable {
    var date: Date
    var amount: Double
    var cumulative: Double
    var id: Date { date }
}

struct SlotUsage: Equatable {
    var slots = Array(repeating: 0.0, count: 8)
    var unknown = 0.0
    var total: Double { slots.reduce(0, +) + unknown }
}
