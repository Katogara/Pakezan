import SwiftUI

/// 通信会社の会員ページや公式アプリの使用量を入れて、以後の起点にする
struct CorrectionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var usedGB: Double?
    @State private var asOf = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例: 1.25", value: $usedGB, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("今月の使用量（GB）")
                } footer: {
                    PhraseText("会員ページや公式アプリに出ている、今月使った量を入れてください。")
                }
                Section {
                    DatePicker("この値の時点", selection: $asOf, in: ...Date.now)
                } footer: {
                    PhraseText("会員ページの値は、少し前の時点のものの場合があります。ページに書かれている時点を選んでください。")
                }
            }
            .navigationTitle("通信会社の値で補正")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("補正する") {
                        if let usedGB {
                            model.addCorrection(usedGB: usedGB, asOf: asOf)
                        }
                        dismiss()
                    }
                    .disabled(usedGB == nil)
                }
            }
        }
    }
}

/// 容量を追加で買った月に、今月の上限に足す
struct ExtraSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var gb: Double? = 1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例: 1", value: $gb, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("追加した容量（GB）")
                } footer: {
                    PhraseText("今月の上限に足します。次の締め日を過ぎると元の上限に戻ります。")
                }
                if !model.extrasThisPeriod.isEmpty {
                    Section("今月足した容量") {
                        ForEach(model.extrasThisPeriod) { extra in
                            HStack {
                                Text(Format.day(extra.date))
                                Spacer()
                                Text("\(extra.gb.formatted())GB")
                            }
                            .swipeActions {
                                Button("消す", role: .destructive) { model.removeExtra(extra) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("容量を追加した")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("足す") {
                        if let gb, gb > 0 {
                            model.addExtra(gb: gb)
                        }
                        dismiss()
                    }
                    .disabled((gb ?? 0) <= 0)
                }
            }
        }
    }
}
