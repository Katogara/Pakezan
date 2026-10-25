import BudouX
import SwiftUI

/// 日本語を文節の切れ目だけで折り返す。
/// 日本語には単語の間の空白がないので、そのままでは「イノベーシ／ョン」のように語の途中で折り返されることがある。
/// 改行の位置は `\n` で決め打ちせず (画面の幅が変わると半端な行ができる)、BudouX で文節に分けて幅に任せる。
/// BudouX の分け方には次の手直しを加える。
/// - 短いカギ括弧・丸括弧の中では折り返さない (「は／じめる」「（の／こり」を防ぐ)
/// - 「「」で行を終えず、「」」「、」「！」などで行を始めない (禁則)
/// - アプリでよく出る語 (パケざん、オートメーション) の途中では折り返さない
enum Phrases {
    private static let parser = Parser()
    private static let protectedWords: [[Character]] = ["パケざん", "オートメーション", "ショートカット"].map { Array($0) }
    private static let pairs: [Character: Character] = ["「": "」", "『": "』", "（": "）", "(": ")"]
    /// これより長い括弧の中は、ふつうに文節で折り返す
    private static let maxGroup = 12
    private static let opening: Set<Character> = ["「", "『", "（", "(", "[", "【", "〈", "《", "“"]
    private static let noLineStart = Set<Character>("」』）)]】〉》”、。，．！？!?ー…")

    /// 文節に分ける (例: 「通信量を記録する」→「通信量を」「記録する」)
    static func split(_ text: String) -> [String] {
        let chars = Array(text)
        guard !chars.isEmpty else { return [] }
        // 折り返してよい位置 (その文字の前で折り返す)
        var cuts = Set<Int>()
        var position = 0
        for chunk in parser.parse(sentence: text).dropLast() {
            position += chunk.count
            cuts.insert(position)
        }
        for word in protectedWords where word.count <= chars.count {
            for start in 0...(chars.count - word.count) where Array(chars[start..<start + word.count]) == word {
                cuts.subtract((start + 1)..<(start + word.count))
            }
        }
        for (start, character) in chars.enumerated() {
            guard let close = pairs[character],
                  let end = chars[(start + 1)...].firstIndex(of: close),
                  end - start <= maxGroup else { continue }
            cuts.subtract((start + 1)...end)
        }
        for cut in cuts.sorted() where opening.contains(chars[cut - 1]) {
            cuts.remove(cut)
            if cut - 1 > 0 { cuts.insert(cut - 1) }
        }
        cuts = cuts.filter { $0 > 0 && $0 < chars.count && !noLineStart.contains(chars[$0]) }

        var result: [String] = []
        var start = 0
        for cut in cuts.sorted() {
            result.append(String(chars[start..<cut]))
            start = cut
        }
        result.append(String(chars[start...]))
        return result
    }

    /// 文節の中では折り返さない文字列にする (文節の中の文字を Word Joiner でつなぎ、文節の間にゼロ幅スペースを入れる)
    static func wrapped(_ text: String) -> String {
        split(text).map(unbreakable).joined(separator: Parser.zeroWidthSpace)
    }

    /// どこでも折り返さない文字列にする
    static func unbreakable(_ text: String) -> String {
        text.map { String($0) }.joined(separator: Parser.wordJoiner)
    }

    /// 句読点 (、。！？) の後ろで行を分けた文字列。分ける所がなければ nil
    static func punctuationLines(_ text: String) -> String? {
        var lines: [String] = []
        var line = ""
        for character in text {
            line.append(character)
            if "、。！？".contains(character) {
                lines.append(line)
                line = ""
            }
        }
        if !line.trimmingCharacters(in: .whitespaces).isEmpty { lines.append(line) }
        guard lines.count > 1 else { return nil }
        return lines.map(unbreakable).joined(separator: "\n")
    }
}

/// 文節の切れ目だけで折り返す `Text`。文や説明はこれで出す
func PhraseText(_ text: String) -> Text {
    Text(verbatim: Phrases.wrapped(text))
}

/// 見出しや褒め言葉。1 行に収まればそのまま、収まらなければ句読点の後ろで行を分け、
/// それでも収まらないときだけ文節で折り返す (「考える前に、もう／始めている」のような切れ方を防ぐ)
struct HeadlineText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(verbatim: Phrases.unbreakable(text))
            if let lines = Phrases.punctuationLines(text) {
                Text(verbatim: lines)
            }
            PhraseText(text)
        }
    }
}
