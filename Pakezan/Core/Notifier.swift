import UserNotifications

/// 警告・毎日のまとめ・署名の期限の通知と、アイコンのバッジ
@MainActor
final class Notifier {
    private let center = UNUserNotificationCenter.current()
    private static let signingPrefix = "signing-"

    /// 通知とバッジの許可を求める。許可されていれば true
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func setBadge(_ number: Int) {
        center.setBadgeCount(max(0, number), withCompletionHandler: nil)
    }

    func postAlert(level: AlertLevel, summary: UsageSummary) {
        let remaining = Format.bytes(max(0, summary.remaining))
        let body: String
        switch level {
        case .normal:
            return
        case .pace:
            let reach = summary.forecast.map { "このままだと\(Format.day($0))に上限に達します。" } ?? ""
            body = "今月はペースが早めです。\(reach)動画は Wi-Fi で見るのがおすすめです。"
        case .low:
            body = "残り\(remaining)です。低データモードにすると、減り方をゆるやかにできます。"
        case .critical:
            body = "まもなく上限です（残り\(remaining)）。Wi-Fi に切り替えるか、容量の追加を考えてみてください。"
        }
        post(id: "alert-\(level.rawValue)", title: "パケざん", body: body)
    }

    /// 段階制のプランで、使った量が次の料金の段階に入った
    func postTierUp(spec: PlanSpec, index: Int) {
        guard spec.tiers.indices.contains(index), index > 0 else { return }
        let tier = spec.tiers[index]
        let previous = spec.tiers[index - 1].upToGB.map { Format.gbText($0) } ?? ""
        let price = tier.yen.map { "（月額 \($0.formatted())円）" } ?? ""
        post(id: "tier-\(index)", title: "パケざん",
             body: "今月の使用量が\(previous)を超え、\(spec.name)の料金が「\(Format.tierText(tier))」の段階になりました\(price)。")
    }

    /// 買い切りのトッピングの期限が近い
    func postToppingExpiry(status: ToppingStatus) {
        let remaining = status.remaining.map { Format.bytes(max(0, $0)) } ?? ""
        post(id: "topping-\(status.id.uuidString)", title: "パケざん",
             body: "\(Format.toppingAmount(status.topping.gb))のトッピングは、\(Format.dateTime(status.topping.end))に期限が切れます（残り\(remaining)）。")
    }

    func postDailySummary(_ summary: UsageSummary) {
        if summary.noActiveTopping {
            post(id: "daily", title: "今日の通信量",
                 body: "今日は\(Format.bytes(summary.today))使いました。今使えるトッピングはありません。")
            return
        }
        let outlook: String
        if let forecast = summary.forecast {
            outlook = "このペースだと\(Format.day(forecast))に上限です。"
        } else if summary.lastsUntilEnd {
            outlook = "このペースなら締め日まで持ちます。"
        } else {
            outlook = ""
        }
        post(id: "daily", title: "今日の通信量",
             body: "今日は\(Format.bytes(summary.today))使いました。残りは\(Format.bytes(max(0, summary.remaining)))です。\(outlook)")
    }

    /// 署名が切れる 2 日前と 6 時間前に知らせる。切れるとアプリが起動できず、記録も止まる
    func scheduleSigningReminders(expiry: Date) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier)
            .filter { $0.hasPrefix(Self.signingPrefix) })
        let reminders: [(TimeInterval, String)] = [
            (2 * 86400, "あと2日でパケざんの署名が切れます。Sideloadly で入れ直してください。"),
            (6 * 3600, "今日、パケざんの署名が切れます。切れると記録が止まるので、Sideloadly で入れ直してください。"),
        ]
        for (before, body) in reminders {
            let interval = expiry.addingTimeInterval(-before).timeIntervalSinceNow
            guard interval > 60 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "パケざん"
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(Self.signingPrefix)\(Int(before))", content: content, trigger: trigger),
                       withCompletionHandler: nil)
        }
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil), withCompletionHandler: nil)
    }
}
