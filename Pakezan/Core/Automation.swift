import AppIntents
import BackgroundTasks
import Foundation

/// ショートカットのオートメーションから呼ぶ「通信量を記録する」。アプリは開かない
struct RecordUsageIntent: AppIntent {
    static var title: LocalizedStringResource = "通信量を記録する"
    static var description = IntentDescription("パケざんが、前回からのモバイル通信量を記録します。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppModel.shared.measure(source: .automation)
        return .result()
    }
}

/// ショートカットアプリに、設定なしで「通信量を記録する」を出す
struct PakezanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecordUsageIntent(),
                    phrases: ["\(.applicationName)で通信量を記録"],
                    shortTitle: "通信量を記録する",
                    systemImageName: "antenna.radiowaves.left.and.right")
    }
}

/// iOS のバックグラウンド更新。いつ動くかは iOS しだいなので、オートメーションの補助にする
enum BackgroundRefresh {
    static let identifier = "com.example.Pakezan.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            schedule()
            let work = Task { @MainActor in
                await AppModel.shared.measure(source: .background)
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
