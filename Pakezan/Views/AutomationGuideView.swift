import SwiftUI

/// ショートカットの時刻オートメーションを 8 本作る手順。初回設定と設定画面の両方で使う
struct AutomationGuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    static let hours = Array(stride(from: 0, to: 24, by: 3))

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhraseText("3時間ごとに記録するため、ショートカットアプリで時刻のオートメーションを8本作ります。最初に一度だけ必要な作業です。")

            VStack(alignment: .leading, spacing: 10) {
                step(1, "ショートカットアプリを開き、下の「オートメーション」を選ぶ")
                step(2, "右上の「＋」を押し、「特定の時刻」を選ぶ")
                step(3, "時刻を下の一覧のどれかにし、「毎日」を選ぶ")
                step(4, "「すぐに実行」を選ぶ（確認なしで動かすために必要です）")
                step(5, "アクションで「パケざん」の「通信量を記録する」を選び、完了を押す")
            }

            Button {
                if let url = URL(string: "shortcuts://") { openURL(url) }
            } label: {
                Label("ショートカットアプリを開く", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("作った時刻に印を付けてください")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(Self.hours, id: \.self) { hour in
                    let done = model.state.automationHoursDone.contains(hour)
                    Button {
                        model.toggleAutomationHour(hour)
                    } label: {
                        Label("\(hour):00", systemImage: done ? "checkmark.circle.fill" : "circle")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.monospacedDigit())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(done ? Palette.accent : Color.secondary)
                }
            }
            PhraseText("8本そろうと、ホームで「届いていない時刻」が出なくなります。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.subheadline.bold())
                .frame(width: 24, height: 24)
                .background(Palette.accent.opacity(0.2), in: .circle)
            PhraseText(text)
        }
    }
}
