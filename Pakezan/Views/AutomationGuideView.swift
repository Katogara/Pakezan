import SwiftUI

/// ショートカットに時刻のオートメーションを 8 つ付ける手順 (iOS 27 の画面で確認)。初回設定と設定画面の両方で使う
struct AutomationGuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    static let hours = Array(stride(from: 0, to: 24, by: 3))

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhraseText("3時間ごとに記録するため、ショートカットアプリで、パケざんを動かす時刻を8つ設定します。最初に一度だけ必要な作業です。手順は iOS 27 の画面に合わせています。")

            VStack(alignment: .leading, spacing: 10) {
                step(1, "ショートカットアプリを開く。「すべてのショートカット」の画面が出たら、左上の「＜」を押し、「ライブラリ」の「オートメーション」を選ぶ")
                step(2, "下の「＋」を押し、「新規ショートカット」の画面が出たら、右上の「編集」を押す")
                step(3, "下の検索欄を上に引き出して「パケざん」と入れ、「通信量を記録する」を押す")
                step(4, "もう一度検索欄を引き出し、青い「オートメーション」を押してから「時刻」を押す。増えた「時間」を押して 0:00 にする")
                step(5, "4をくり返して、3:00、6:00、9:00、12:00、15:00、18:00、21:00 を足す。時刻どうしは「または」でつながります")
                step(6, "どれかの時刻の右の「＞」を押し、「繰り返し」が「毎日」、「オートメーション」がオンになっていることを確かめる")
                step(7, "左上の「＜」で戻り、「オートメーション」の一覧に出ていれば完了")
            }

            Button {
                if let url = URL(string: "shortcuts://") { openURL(url) }
            } label: {
                Label("ショートカットアプリを開く", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("設定した時刻に印を付けてください")
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
            PhraseText("8つそろうと、ホームで「届いていない時刻」が出なくなります。")
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
