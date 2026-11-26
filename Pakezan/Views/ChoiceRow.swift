import SwiftUI

/// 選択肢の 1 つ (値と、画面に出す名前)
struct Choice<Value: Hashable>: Identifiable {
    let value: Value
    let text: String
    var id: Value { value }
}

/// 長い名前を「…」で切らずに出す選択の行。行には項目名の下に選んだ名前を折り返して出し、
/// 押すと選択肢を全文で並べた画面に移る (Picker は行の幅で名前を省略してしまうため)
struct ChoiceRow<Value: Hashable>: View {
    let title: String
    let choices: [Choice<Value>]
    @Binding var selection: Value

    var body: some View {
        NavigationLink {
            ChoiceList(title: title, choices: choices, selection: $selection)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(choices.first { $0.value == selection }?.text ?? "")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }
}

/// 選択肢を全文で並べ、選んだら前の画面に戻る
private struct ChoiceList<Value: Hashable>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let choices: [Choice<Value>]
    @Binding var selection: Value

    var body: some View {
        List(choices) { choice in
            Button {
                selection = choice.value
                dismiss()
            } label: {
                HStack {
                    Text(choice.text)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if choice.value == selection {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
