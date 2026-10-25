import Foundation
import Observation

/// 端末に保存する内容 (Documents/pakezan.json。ファイルアプリからも見える)
struct StoredState: Codable, Equatable {
    var plan: Plan?
    var samples: [Sample] = []
    var lastRaw: RawCounters?
    var lastRawDate: Date?
    var corrections: [Correction] = []
    var extras: [Extra] = []
    /// 期間ごとに、通知した中でいちばん高い段階 (キーは期間の始まりの時刻)
    var notifiedLevels: [String: AlertLevel] = [:]
    /// 毎日のまとめを最後に送った日 (yyyy-MM-dd)
    var lastDailySummary: String?
    var dailySummaryEnabled = true
    var onboardedAt: Date?
    /// 初回設定で「作った」と印を付けたオートメーションの時刻
    var automationHoursDone: [Int] = []

    init() {}

    // 項目を足しても古いファイルを読めるように、無い項目は既定値にする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plan = try c.decodeIfPresent(Plan.self, forKey: .plan)
        samples = try c.decodeIfPresent([Sample].self, forKey: .samples) ?? []
        lastRaw = try c.decodeIfPresent(RawCounters.self, forKey: .lastRaw)
        lastRawDate = try c.decodeIfPresent(Date.self, forKey: .lastRawDate)
        corrections = try c.decodeIfPresent([Correction].self, forKey: .corrections) ?? []
        extras = try c.decodeIfPresent([Extra].self, forKey: .extras) ?? []
        notifiedLevels = try c.decodeIfPresent([String: AlertLevel].self, forKey: .notifiedLevels) ?? [:]
        lastDailySummary = try c.decodeIfPresent(String.self, forKey: .lastDailySummary)
        dailySummaryEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailySummaryEnabled) ?? true
        onboardedAt = try c.decodeIfPresent(Date.self, forKey: .onboardedAt)
        automationHoursDone = try c.decodeIfPresent([Int].self, forKey: .automationHoursDone) ?? []
    }
}

enum Storage {
    static var url: URL {
        URL.documentsDirectory.appending(path: "pakezan.json")
    }

    static func load() -> StoredState {
        guard let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(StoredState.self, from: data) else { return StoredState() }
        return state
    }

    static func save(_ state: StoredState) {
        guard let data = try? encoder.encode(state) else { return }
        // オートメーションは画面のロック中にも動くので、最初のロック解除のあとなら書けるようにする
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var state: StoredState
    let notifier = Notifier()
    var calendar = Calendar.current

    init(state: StoredState = Storage.load()) {
        self.state = state
    }

    var isOnboarded: Bool { state.onboardedAt != nil && state.plan != nil }
    var plan: Plan { state.plan ?? Plan(preset: .linemoMini) }

    var ledger: Ledger {
        Ledger(plan: plan, samples: state.samples, corrections: state.corrections,
               extras: state.extras, calendar: calendar)
    }

    var summary: UsageSummary { ledger.summary(at: .now) }

    var lastMeasured: Date? { state.lastRawDate }

    /// 12 時間以上記録がない
    var isStale: Bool {
        guard let lastMeasured else { return true }
        return Date.now.timeIntervalSince(lastMeasured) > 12 * 3600
    }

    /// 直近 24 時間で記録が届かなかったオートメーションの時刻 (初回設定から 1 日たつまでは出さない)
    var missingAutomationHours: [Int] {
        guard let onboardedAt = state.onboardedAt, Date.now.timeIntervalSince(onboardedAt) > 86400 else { return [] }
        return ledger.missingAutomationHours(now: .now)
    }

    // MARK: - 記録

    /// カウンタを読み、前回からの増加量を記録する。最初の 1 回は起点を覚えるだけ
    func measure(source: Sample.Source) async {
        let raw = InterfaceCounters.read()
        let now = Date.now
        // 別の時刻の処理が先にファイルへ書いていることがあるので、読み直してから足す
        state = Storage.load()
        if let old = state.lastRaw, let oldDate = state.lastRawDate, now > oldDate {
            let delta = CounterMath.delta(from: old, to: raw)
            let start = delta.rebooted ? min(now, max(oldDate, raw.bootTime)) : oldDate
            state.samples.append(Sample(previousDate: start, date: now, cellular: delta.cellular, wifi: delta.wifi,
                                        estimated: delta.rebooted || delta.reset, source: source))
        }
        state.lastRaw = raw
        state.lastRawDate = now
        // 400 日より前の記録は消す
        state.samples.removeAll { now.timeIntervalSince($0.date) > 400 * 86400 }
        Storage.save(state)
        await afterMeasure(now: now)
    }

    /// 通知とバッジを今の状態に合わせる
    private func afterMeasure(now: Date) async {
        guard isOnboarded else { return }
        let summary = ledger.summary(at: now)
        notifier.setBadge(Int((summary.remainingFraction * 100).rounded()))

        let key = ISO8601DateFormatter().string(from: summary.period.start)
        let level = summary.level
        if level > (state.notifiedLevels[key] ?? .normal) {
            notifier.postAlert(level: level, summary: summary)
            state.notifiedLevels[key] = level
        }

        let day = Format.dayKey(now, calendar: calendar)
        if state.dailySummaryEnabled, calendar.component(.hour, from: now) >= 21, state.lastDailySummary != day {
            notifier.postDailySummary(summary)
            state.lastDailySummary = day
        }
        Storage.save(state)

        if let expiry = SigningInfo.expiry {
            await notifier.scheduleSigningReminders(expiry: expiry)
        }
    }

    // MARK: - 設定

    func setPlan(_ plan: Plan) {
        update { $0.plan = plan }
    }

    func setDailySummary(_ enabled: Bool) {
        update { $0.dailySummaryEnabled = enabled }
    }

    func addCorrection(usedGB: Double, asOf: Date) {
        update { $0.corrections.append(Correction(asOf: asOf, usedBytes: usedGB * Plan.bytesPerGB)) }
    }

    func addExtra(gb: Double) {
        update { $0.extras.append(Extra(date: .now, gb: gb)) }
    }

    /// 今の期間に足した容量
    var extrasThisPeriod: [Extra] {
        let period = summary.period
        return state.extras.filter { period.contains($0.date) }
    }

    func removeExtra(_ extra: Extra) {
        update { $0.extras.removeAll { $0.id == extra.id } }
    }

    var latestCorrection: Correction? { state.corrections.max { $0.asOf < $1.asOf } }

    func toggleAutomationHour(_ hour: Int) {
        update {
            if let index = $0.automationHoursDone.firstIndex(of: hour) {
                $0.automationHoursDone.remove(at: index)
            } else {
                $0.automationHoursDone.append(hour)
            }
        }
    }

    func finishOnboarding() {
        update { $0.onboardedAt = .now }
    }

    private func update(_ change: (inout StoredState) -> Void) {
        state = Storage.load()
        change(&state)
        Storage.save(state)
    }

    // MARK: - 書き出し

    /// 記録を CSV にして一時ファイルに書き、その場所を返す
    func exportCSV() -> URL? {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        var lines = ["開始,終了,モバイル(バイト),Wi-Fi(バイト),推定,記録のきっかけ"]
        for sample in state.samples {
            lines.append([formatter.string(from: sample.previousDate), formatter.string(from: sample.date),
                          String(sample.cellular), String(sample.wifi), sample.estimated ? "はい" : "",
                          sample.source.rawValue].joined(separator: ","))
        }
        let url = URL.temporaryDirectory.appending(path: "pakezan-\(Format.dayKey(.now, calendar: calendar)).csv")
        // Excel で文字化けしないよう、先頭に BOM を付ける
        guard (try? ("\u{FEFF}" + lines.joined(separator: "\n")).write(to: url, atomically: true, encoding: .utf8)) != nil
        else { return nil }
        return url
    }
}
