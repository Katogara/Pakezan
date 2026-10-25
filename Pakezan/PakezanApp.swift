import SwiftUI

@main
struct PakezanApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel.shared

    init() {
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .fontDesign(.rounded)
                .tint(Palette.accent)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                // 開いたときにも記録する (オートメーションの合間の分が分かる)
                Task { await model.measure(source: .app) }
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}
