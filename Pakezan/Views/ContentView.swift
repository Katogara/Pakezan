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
            // 広告は画面の下 (タブの上) に出す。設定の画面には出さない
            HomeView()
                .safeAreaInset(edge: .bottom, spacing: 0) { AdBannerSlot() }
                .tabItem { Label("ホーム", systemImage: "gauge.with.dots.needle.33percent") }
            TrendView()
                .safeAreaInset(edge: .bottom, spacing: 0) { AdBannerSlot() }
                .tabItem { Label("推移", systemImage: "chart.line.uptrend.xyaxis") }
            HoursView()
                .safeAreaInset(edge: .bottom, spacing: 0) { AdBannerSlot() }
                .tabItem { Label("時間帯", systemImage: "clock") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        // はじめての人は、説明 → 初回設定の順に見る。設定を済ませた人にも、説明は一度だけ見せる
        .fullScreenCover(isPresented: .constant(!model.isOnboarded || !model.hasSeenIntro)) {
            Group {
                if !model.hasSeenIntro {
                    IntroView { model.finishIntro() }
                } else {
                    OnboardingView()
                }
            }
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
