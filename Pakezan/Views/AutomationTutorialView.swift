import SwiftUI

/// オートメーションを作る手順を、1画面ずつ絵を見せながら案内する (iOS 27 の画面で確認)。
/// 絵は実際の画面を写したものではなく、押す所が分かるように描いた見本
struct AutomationTutorialView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// ショートカットアプリと行き来しても続きから見られるよう、見ていたページを覚えておく
    @AppStorage("automationTutorialPage") private var page = 0

    /// 手順の数 (0 ページ目は前置き、最後のページは完了)
    static let stepCount = 9

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(min(page, Self.stepCount)), total: Double(Self.stepCount))
                    .tint(Palette.accent)
                    .padding(.horizontal)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        content
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(page)
            }
            .navigationTitle((1...Self.stepCount).contains(page) ? "手順 \(page) / \(Self.stepCount)" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("とじる") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
    }

    // MARK: - ページ

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0: intro
        case 1: openShortcuts
        case 2: chooseAutomation
        case 3: tapPlus
        case 4: tapEdit
        case 5: addAction
        case 6: chooseTime
        case 7: setTime
        case 8: addOtherTimes
        case 9: confirm
        default: finished
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(.rect(cornerRadius: 26))
                .frame(maxWidth: .infinity)
            HeadlineText("最初だけめんどくさい初期設定！")
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
            PhraseText("パケざんが3時間ごとに通信量を記録できるよう、iPhone の「ショートカット」アプリに、パケざんを動かす時刻を8つ登録します。")
            PhraseText("iPhone の決まりで、この登録だけはパケざんが代わりにできません。そのかわり、一度終われば、あとはずっと何もしなくて大丈夫です。")
            Card {
                Label("かかる時間：5分ほど", systemImage: "clock")
                Label("登録する時刻：0:00、3:00 … 21:00 の8つ", systemImage: "list.number")
            }
            PhraseText("このガイドとショートカットアプリを行き来しながら進めます。パケざんに戻ってくると、続きのページから見られます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var openShortcuts: some View {
        StepPage(title: "ショートカットアプリを開く",
                 message: "下のボタンでショートカットアプリを開きます。「すべてのショートカット」の画面が出たら、左上の「＜」を押してください。",
                 tip: "ほかの画面が出たときは、左上の「＜」を何回か押すと「ライブラリ」の画面に戻れます。") {
            Button {
                if let url = URL(string: "shortcuts://") { openURL(url) }
            } label: {
                Label("ショートカットアプリを開く", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            MockScreen {
                HStack {
                    MockCircleButton(systemImage: "chevron.left").highlight()
                    Spacer()
                    MockPill(text: "選択")
                }
                MockLargeTitle(text: "すべてのショートカット")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 12)
                            .fill([Color.blue, .pink, .orange, .purple][index].opacity(0.35))
                            .frame(height: 44)
                    }
                }
            }
        }
    }

    private var chooseAutomation: some View {
        StepPage(title: "「オートメーション」を選ぶ",
                 message: "「ライブラリ」の画面になります。並んでいる中から「オートメーション」を押してください。",
                 tip: nil) {
            MockScreen {
                MockLargeTitle(text: "ライブラリ")
                VStack(spacing: 0) {
                    MockListRow(systemImage: "square.stack", text: "すべてのショートカット")
                    MockListRow(systemImage: "square.and.arrow.up", text: "共有シート")
                    MockListRow(systemImage: "square.grid.2x2", text: "ギャラリー")
                    MockListRow(systemImage: "clock", text: "オートメーション").highlight()
                }
                .background(Mock.card, in: .rect(cornerRadius: 14))
            }
        }
    }

    private var tapPlus: some View {
        StepPage(title: "下の「＋」を押す",
                 message: "「オートメーション」の画面になったら、いちばん下のまん中にある「＋」を押します。",
                 tip: "右上の「≡」は一覧を絞り込むボタンです。押さなくて大丈夫です。") {
            MockScreen {
                HStack {
                    MockCircleButton(systemImage: "chevron.left")
                    Spacer()
                    MockCircleButton(systemImage: "line.3.horizontal")
                }
                MockLargeTitle(text: "オートメーション")
                Text("オートメーションなし")
                    .font(.caption.bold())
                    .foregroundStyle(Mock.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                MockCircleButton(systemImage: "plus", size: 46)
                    .highlight()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var tapEdit: some View {
        StepPage(title: "右上の「編集」を押す",
                 message: "「ショートカットでどのような操作を実行しますか？」と聞かれる画面が出ます。ここには何も入れず、右上の「編集」を押してください。",
                 tip: "キーボードが出ても、文字は入れなくて大丈夫です。") {
            MockScreen {
                HStack {
                    MockCircleButton(systemImage: "chevron.left")
                    Spacer()
                    Text("新規ショートカット")
                        .font(.caption.bold())
                        .foregroundStyle(Mock.text)
                    Spacer()
                    MockPill(text: "編集").highlight()
                }
                Text("ショートカットでどのような操作を実行しますか？")
                    .font(.caption.bold())
                    .foregroundStyle(Mock.text)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.88, green: 0.93, blue: 1), in: .rect(cornerRadius: 22))
            }
        }
    }

    private var addAction: some View {
        StepPage(title: "「通信量を記録する」を入れる",
                 message: "画面の下にある検索欄を、指で上に引き出します。「パケざん」と入れると出てくる「通信量を記録する」を押してください。",
                 tip: "検索欄は画面の下のふちに小さく隠れています。下のふちに指を置いて、上へすっとなぞると出てきます。") {
            MockScreen {
                MockSheet {
                    MockSearchField(text: "パケざん")
                    HStack(spacing: 6) {
                        MockChip(systemImage: "clock", text: "オートメーション")
                        MockChip(systemImage: "curlybraces", text: "スクリプティング")
                    }
                    HStack(spacing: 10) {
                        Image("Mascot")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .clipShape(.rect(cornerRadius: 6))
                        Text("通信量を記録する")
                            .font(.caption.bold())
                            .foregroundStyle(Mock.text)
                        Spacer()
                    }
                    .padding(10)
                    .background(Mock.card, in: .capsule)
                    .highlight()
                }
            }
        }
    }

    private var chooseTime: some View {
        StepPage(title: "「時刻」を選ぶ",
                 message: "もう一度検索欄を引き出し、青い「オートメーション」を押します（①）。続いて、いちばん上の「時刻」を押してください（②）。",
                 tip: "「パケざん」の文字が残っていたら、検索欄の右の「×」で消してから押してください。") {
            MockScreen {
                MockSheet {
                    MockSearchField(text: "")
                    HStack(spacing: 6) {
                        MockChip(systemImage: "clock", text: "オートメーション").highlight(number: 1)
                        MockChip(systemImage: "curlybraces", text: "スクリプティング")
                    }
                    Text("日ごろの行動")
                        .font(.caption.bold())
                        .foregroundStyle(Mock.text)
                    VStack(spacing: 6) {
                        MockTriggerRow(color: .orange, title: "時刻", example: "“平日の午前8:00”").highlight(number: 2)
                        MockTriggerRow(color: .orange, title: "アラーム", example: "“アラームが止まったとき”")
                    }
                }
            }
        }
    }

    private var setTime: some View {
        StepPage(title: "時刻を 0:00 にする",
                 message: "上に「時間 に ＞」の行が増えます。うすい青の「時間」を押して、0 と 00 に合わせてください。",
                 tip: "時刻を回す所は、左が「時」、右が「分」です。") {
            MockScreen {
                Text("このオートメーションを有効にするには、「時間」を構成してください。")
                    .font(.caption2)
                    .foregroundStyle(Mock.text)
                    .padding(8)
                    .background(Color(white: 0.88), in: .rect(cornerRadius: 12))
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Mock.secondary)
                    Text("時間")
                        .font(.callout)
                        .foregroundStyle(Mock.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Mock.blue.opacity(0.15), in: .rect(cornerRadius: 8))
                        .highlight()
                    Text("に")
                        .font(.callout.bold())
                        .foregroundStyle(Mock.text)
                    Image(systemName: "chevron.right.circle")
                        .foregroundStyle(Mock.blue)
                    Spacer()
                }
                HStack(spacing: 28) {
                    Text("0")
                    Text("00")
                }
                .font(.title2.monospacedDigit())
                .foregroundStyle(Mock.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(white: 0.9), in: .capsule)
                MockActionRow()
            }
        }
    }

    private var addOtherTimes: some View {
        let done = model.state.automationHoursDone.count
        return StepPage(title: "残りの7つを足す",
                        message: "手順6と手順7をくり返して、3:00、6:00、9:00、12:00、15:00、18:00、21:00 を足します。時刻どうしは「または」でつながります。",
                        tip: "まちがえた時刻は、その行の右の「×」で消せます。") {
            MockScreen {
                MockTimeRow(time: "0:00")
                Text("または")
                    .font(.caption.bold())
                    .foregroundStyle(Mock.secondary)
                    .frame(maxWidth: .infinity)
                MockTimeRow(time: "3:00").highlight(showsHand: false)
                MockActionRow()
            }
            Text("足した時刻に印を付けていきましょう")
                .font(.headline)
            HourChecklist()
            HeadlineText(done >= 8 ? "8つそろいました！" : "あと\(8 - done)つ！")
                .font(.title3.bold())
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity)
        }
    }

    private var confirm: some View {
        StepPage(title: "最後に確かめる",
                 message: "どれか1つの時刻の右にある「＞」を押します。「繰り返し」が「毎日」、「オートメーション」がオンになっていれば大丈夫です。",
                 tip: "「通知」はオフのままで大丈夫です。") {
            MockScreen {
                VStack(spacing: 0) {
                    MockSettingRow(title: "予定") { Text("時刻").foregroundStyle(Mock.blue) }
                    MockSettingRow(title: "繰り返し") { Text("毎日").foregroundStyle(Mock.blue) }
                        .highlight(showsHand: false)
                    MockSettingRow(title: "オートメーション") { MockToggle(isOn: true) }
                        .highlight(showsHand: false)
                    MockSettingRow(title: "通知") { MockToggle(isOn: false) }
                }
                .background(Mock.card, in: .rect(cornerRadius: 14))
            }
            PhraseText("確かめたら、左上の「＜」で戻ります。「オートメーション」の一覧に出ていれば完成です。")
        }
    }

    private var finished: some View {
        let missing = AutomationGuideView.hours.filter { !model.state.automationHoursDone.contains($0) }
        return VStack(alignment: .leading, spacing: 18) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(.rect(cornerRadius: 26))
                .frame(maxWidth: .infinity)
            HeadlineText("おつかれさまでした！")
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
            PhraseText("最初だけめんどくさい設定はこれでおしまいです。あとはアプリを開かなくても、パケざんが3時間ごとに記録します。")
            PhraseText("次の 0:00 か 3:00 を過ぎたら、ホームの「最後の記録」の時刻が新しくなっているかを見てみてください。")
            if !missing.isEmpty {
                Card {
                    Label("印が付いていない時刻があります", systemImage: "exclamationmark.circle")
                        .font(.headline)
                    PhraseText("足し忘れていないか、ショートカットアプリでもう一度見てみてください。")
                    HourChecklist()
                }
            }
        }
    }

    // MARK: - 下のボタン

    private var footer: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button {
                    page -= 1
                } label: {
                    Text("もどる")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button {
                if page > Self.stepCount {
                    // 次に開いたときは最初から見られるようにする
                    page = 0
                    dismiss()
                } else {
                    page += 1
                }
            } label: {
                Text(nextTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding()
        .background(.bar)
    }

    private var nextTitle: String {
        if page == 0 { return "はじめる" }
        if page == Self.stepCount { return "できた！" }
        return page > Self.stepCount ? "とじる" : "次へ"
    }
}

/// 8つの時刻に印を付ける。初回設定のガイドと設定画面の両方で使う
struct HourChecklist: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            ForEach(AutomationGuideView.hours, id: \.self) { hour in
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
    }
}

// MARK: - 手順のページの型

private struct StepPage<Content: View>: View {
    let title: String
    let message: String
    let tip: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeadlineText(title)
                .font(.title2.bold())
            PhraseText(message)
            content
            if let tip {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    PhraseText(tip)
                        .font(.callout)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.15), in: .rect(cornerRadius: 14))
            }
        }
    }
}

// MARK: - 画面の見本の部品 (iOS のライトモードの色で描く)

private enum Mock {
    static let background = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let card = Color.white
    static let text = Color.black
    static let secondary = Color(white: 0.5)
    static let blue = Color(red: 0.2, green: 0.48, blue: 1)
}

/// 押す所を、脈打つオレンジの枠と指の印で示す
private struct Highlight: ViewModifier {
    var showsHand: Bool
    var number: Int?
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .padding(3)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange, lineWidth: 3)
                    .scaleEffect(pulse ? 1.06 : 1)
                    .opacity(pulse ? 0.45 : 1)
            }
            .overlay(alignment: .bottomTrailing) {
                if showsHand {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .shadow(color: .white, radius: 2)
                        .offset(x: 10, y: 16)
                }
            }
            .overlay(alignment: .topLeading) {
                if let number {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.orange, in: .circle)
                        .offset(x: -8, y: -8)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

private extension View {
    func highlight(showsHand: Bool = true, number: Int? = nil) -> some View {
        modifier(Highlight(showsHand: showsHand || number != nil, number: number))
    }
}

/// iPhone の画面に見立てた枠
private struct MockScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: 300)
        .background(Mock.background, in: .rect(cornerRadius: 32))
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color(white: 0.75), lineWidth: 4)
        }
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .light)
        .accessibilityHidden(true)
    }
}

private struct MockCircleButton: View {
    let systemImage: String
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Mock.text)
            .frame(width: size, height: size)
            .background(Mock.card, in: .circle)
            .overlay { Circle().stroke(Color(white: 0.85)) }
    }
}

private struct MockPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(Mock.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Mock.card, in: .capsule)
            .overlay { Capsule().stroke(Color(white: 0.85)) }
    }
}

private struct MockLargeTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(Mock.text)
    }
}

private struct MockListRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Mock.blue)
                .frame(width: 22)
            Text(text)
                .font(.callout)
                .foregroundStyle(Mock.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Mock.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

/// 下から引き出す検索の板
private struct MockSheet<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule()
                .fill(Color(white: 0.8))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
            content
        }
        .padding(12)
        .background(Color(white: 0.97), in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(white: 0.85))
        }
    }
}

private struct MockSearchField: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
            Text(text.isEmpty ? "検索" : text)
                .foregroundStyle(text.isEmpty ? Mock.secondary : Mock.text)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(Mock.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.89), in: .capsule)
    }
}

private struct MockChip: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.bold())
            .foregroundStyle(Mock.blue)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Mock.card, in: .capsule)
    }
}

private struct MockTriggerRow: View {
    let color: Color
    let title: String
    let example: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(Mock.text)
                Text(example)
                    .font(.caption2)
                    .foregroundStyle(Mock.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Mock.card, in: .rect(cornerRadius: 14))
    }
}

private struct MockTimeRow: View {
    let time: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
            Text(time)
                .font(.callout)
                .foregroundStyle(Mock.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Mock.blue.opacity(0.12), in: .rect(cornerRadius: 8))
            Text("に")
                .font(.callout.bold())
                .foregroundStyle(Mock.text)
            Image(systemName: "chevron.right.circle")
                .foregroundStyle(Mock.blue)
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color(white: 0.8))
        }
        .padding(10)
        .background(Mock.card, in: .capsule)
    }
}

private struct MockActionRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("Mascot")
                .resizable()
                .frame(width: 24, height: 24)
                .clipShape(.rect(cornerRadius: 6))
            Text("通信量を記録する")
                .font(.callout.bold())
                .foregroundStyle(Mock.text)
            Spacer()
        }
        .padding(10)
        .background(Mock.card, in: .capsule)
    }
}

private struct MockSettingRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Mock.text)
            Spacer()
            trailing
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct MockToggle: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Color.green : Color(white: 0.85))
            .frame(width: 44, height: 26)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .padding(2)
            }
    }
}
