import SwiftUI

/// はじめの説明。紙芝居のように左へめくり、パケざんが吹き出しで話しかけながら、
/// アプリが何をするかと、最初にしてもらうことを伝える。設定の「はじめの説明を見る」から、もう一度見られる
struct IntroView: View {
    /// 見終えたとき (または飛ばしたとき) に呼ぶ
    let onFinish: () -> Void
    @State private var page = 0

    private static let pages: [IntroPage] = [
        IntroPage(line: "パケです〜。パケットの残り（パケざん）、パケが見ておきますね",
                  symbol: "exclamationmark.triangle.fill", symbolColor: .orange,
                  title: "気づいたらギガがない",
                  lines: ["月の途中で急に通信が遅くなって、そこで初めて使い切ったと気づく。",
                          "iPhone の画面では、今月あとどれだけ使えるかが分かりません。"]),
        IntroPage(line: "アプリを開かなくても大丈夫。パケが数えておきますよ〜",
                  symbol: "clock.arrow.circlepath", symbolColor: .teal,
                  title: "3時間ごとにそっと記録",
                  lines: ["パケざんはこの携帯のモバイル通信量を3時間ごとに記録します。",
                          "締め日で区切って数えるので、毎月の数え直しも自動です。"]),
        IntroPage(line: "アイコンの数字はねぇ、残りの「%」なんです",
                  symbol: nil, symbolColor: .teal,
                  title: "残りがひと目で分かる",
                  lines: ["アイコンの右上の数字は残りの割合です。ホーム画面を見るだけで分かります。",
                          "アプリを開けば、残りの量と、このペースだと何日に上限に達するかが見られます。"]),
        IntroPage(line: "あぶないときだけ、そっとお知らせしますね〜",
                  symbol: "bell.badge.fill", symbolColor: .red,
                  title: "危ないときだけお知らせ",
                  lines: ["ペースが早いとき、残りが20%になったとき、上限が近いときに通知が届きます。",
                          "使った量で料金が変わるプランなら、次の料金の段階に入ったときにも知らせます。"]),
        IntroPage(line: "最初の設定だけ、いっしょにがんばりましょ〜",
                  symbol: "checklist", symbolColor: .indigo,
                  title: "最初だけひと手間",
                  lines: ["使っている会社とプランを選び、ショートカットアプリに記録する時刻を8つ登録します（5分ほど）。",
                          "それが終われば、あとは何もしなくて大丈夫です。"]),
    ]

    private var lastPage: Int { Self.pages.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.55, blue: 0.56), Color(red: 0.13, green: 0.36, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("スキップ") { onFinish() }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .opacity(page < lastPage ? 1 : 0)
                        .disabled(page >= lastPage)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(Self.pages.indices, id: \.self) { index in
                        IntroCard(page: Self.pages[index], number: index + 1, total: Self.pages.count,
                                  isCurrent: page == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                IntroDots(count: Self.pages.count, current: page)
                    .padding(.vertical, 12)

                Button {
                    if page < lastPage {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < lastPage ? "次へ" : "はじめる")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .tint(page < lastPage ? Color.white.opacity(0.25) : Color.orange)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .fontDesign(.rounded)
        .interactiveDismissDisabled()
    }
}

/// 説明の 1 ページ分の中身
private struct IntroPage {
    /// パケさんのひとこと (2 行まで。のんびりした口調で、自分のことは「パケ」と呼ぶ)
    let line: String
    /// 絵にする SF Symbols。nil ならアイコンとバッジの見本を出す
    let symbol: String?
    let symbolColor: Color
    let title: String
    let lines: [String]
}

/// 紙の色のカードに、上にパケざんと吹き出し、まん中に絵、下に文を置く。めくって来たときに絵が弾んで出てくる
private struct IntroCard: View {
    let page: IntroPage
    let number: Int
    let total: Int
    let isCurrent: Bool
    @State private var appeared = false

    /// 紙の色と文字の色。暗い画面の設定でも紙は明るいままにする
    private static let paper = Color(red: 1.0, green: 0.99, blue: 0.96)
    private static let ink = Color(red: 0.14, green: 0.24, blue: 0.36)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    Image("Mascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(.rect(cornerRadius: 16))
                        .scaleEffect(appeared ? 1 : 0.6)
                        .rotationEffect(.degrees(appeared ? 0 : -12))
                        .animation(.spring(response: 0.5, dampingFraction: 0.45), value: appeared)
                        .accessibilityHidden(true)
                    SpeechBubble {
                        PhraseText(page.line)
                            .font(.subheadline.bold())
                            .foregroundStyle(Self.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
                }
                .padding(.top, 24)

                illustration
                    .frame(height: 130)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(.spring(response: 0.55, dampingFraction: 0.5).delay(0.1), value: appeared)
                    .accessibilityHidden(true)

                Text(verbatim: "\(number) / \(total)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(Self.ink.opacity(0.45))

                HeadlineText(page.title)
                    .font(.title2.bold())
                    .foregroundStyle(Self.ink)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(page.lines, id: \.self) { line in
                        PhraseText(line)
                    }
                }
                .foregroundStyle(Self.ink.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Self.paper)
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { if isCurrent { appeared = true } }
        .onChange(of: isCurrent) { _, current in
            // めくって来たら弾ませて出し、離れたら元に戻しておく (次に来たときにもう一度弾ませるため)
            appeared = current
        }
    }

    @ViewBuilder
    private var illustration: some View {
        if let symbol = page.symbol {
            ZStack {
                Circle()
                    .fill(page.symbolColor.opacity(0.15))
                    .frame(width: 130, height: 130)
                Image(systemName: symbol)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(page.symbolColor)
                    .symbolEffect(.bounce, value: appeared)
            }
        } else {
            BadgeSample(appeared: appeared)
        }
    }
}

/// ホーム画面のアイコンと、残りの割合のバッジの見本
private struct BadgeSample: View {
    let appeared: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 22))
                .overlay(alignment: .topTrailing) {
                    Text(verbatim: "62")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 34, minHeight: 34)
                        .background(.red, in: .capsule)
                        .offset(x: 12, y: -12)
                        .scaleEffect(appeared ? 1 : 0.2)
                        .animation(.spring(response: 0.45, dampingFraction: 0.5).delay(0.4), value: appeared)
                }
            Text(verbatim: "パケざん")
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.55))
        }
    }
}

/// 吹き出しの色 (型引数を持つ型の中には static の定数を置けないので、外に置く)
private let speechBubbleFill = Color(red: 0.88, green: 0.96, blue: 0.96)

/// 左にしっぽのある吹き出し
private struct SpeechBubble<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(speechBubbleFill, in: .rect(cornerRadius: 16))
            .background(alignment: .leading) {
                Triangle()
                    .fill(speechBubbleFill)
                    .frame(width: 12, height: 16)
                    .offset(x: -9)
            }
    }
}

/// 左を向いた三角 (吹き出しのしっぽ)
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// ページの位置。今のページだけ横に伸びた白い丸
private struct IntroDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.white : Color.white.opacity(0.35))
                    .frame(width: index == current ? 24 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: current)
        .accessibilityHidden(true)
    }
}
