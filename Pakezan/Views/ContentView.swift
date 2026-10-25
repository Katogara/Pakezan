import SwiftUI

enum Palette {
    static let accent = Color.teal

    static func color(for level: AlertLevel) -> Color {
        switch level {
        case .normal: .teal
        case .pace: .yellow
        case .low: .orange
        case .critical: .red
        }
    }

    static func label(for level: AlertLevel) -> String {
        switch level {
        case .normal: "順調"
        case .pace: "ペースが早め"
        case .low: "残りわずか"
        case .critical: "まもなく上限"
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "gauge.with.dots.needle.33percent") }
            TrendView()
                .tabItem { Label("推移", systemImage: "chart.line.uptrend.xyaxis") }
            HoursView()
                .tabItem { Label("時間帯", systemImage: "clock") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: .constant(!model.isOnboarded)) {
            OnboardingView()
                .environment(model)
                .fontDesign(.rounded)
        }
    }
}

/// 角を丸めたカード
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}
