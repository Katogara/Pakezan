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
                    Text(model.isPrepaid ? "今の残り（GB）" : "今月の使用量（GB）")
                } footer: {
                    PhraseText(model.isPrepaid
                               ? "公式アプリに出ている、今使えるトッピングの残りの合計を入れてください。"
                               : "会員ページや公式アプリに出ている、今月使った量を入れてください。")
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
                            if model.isPrepaid {
                                model.addRemainingCorrection(remainingGB: usedGB, asOf: asOf)
                            } else {
                                model.addCorrection(usedGB: usedGB, asOf: asOf)
                            }
                        }
                        dismiss()
                    }
                    .disabled(usedGB == nil)
                }
            }
        }
    }
}

/// 買い切りのトッピングを入れる。買ったばかりのものと、使いかけのものの 2 通り
struct ToppingSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var inProgress = false
    /// 選んだトッピング。nil は「そのほか」
    @State private var preset: ToppingPreset? = PlanCatalog.povoToppings.first { $0.gb == 3 }
    @State private var customGB: Double?
    @State private var customDays = 30
    @State private var start = Date.now
    @State private var remainingGB: Double?
    @State private var expiry = Date.now.addingTimeInterval(30 * 86400)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("入れ方", selection: $inProgress) {
                        Text("買ったばかり").tag(false)
                        Text("使いかけ").tag(true)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    PhraseText(inProgress
                               ? "前から使っているトッピングは、公式アプリに出ている今の残りと期限を入れてください。"
                               : "買ったトッピングと、使い始めた日時を選んでください。")
                }
                if inProgress {
                    Section("使いかけのトッピング") {
                        TextField("今の残り（GB） 例: 12.5", value: $remainingGB, format: .number)
                            .keyboardType(.decimalPad)
                        DatePicker("期限", selection: $expiry, in: Date.now...)
                    }
                } else {
                    Section("買ったトッピング") {
                        ChoiceRow(title: "トッピング",
                                  choices: PlanCatalog.povoToppings.map { Choice(value: Optional($0), text: $0.title) }
                                      + [Choice(value: ToppingPreset?.none, text: "そのほか")],
                                  selection: $preset)
                        if preset == nil {
                            TextField("容量（GB） 例: 20", value: $customGB, format: .number)
                                .keyboardType(.decimalPad)
                            Stepper("有効期間 \(customDays)日", value: $customDays, in: 1...400)
                        }
                        DatePicker("使い始め", selection: $start, in: ...Date.now)
                        if let end = newTopping?.end {
                            LabeledContent("期限", value: Format.dateTime(end))
                        }
                    }
                }
                if !model.state.toppings.isEmpty {
                    Section {
                        ForEach(model.ledger.toppingStatuses(at: .now).sorted { $0.topping.end > $1.topping.end }) { status in
                            ToppingRow(status: status)
                                .swipeActions {
                                    Button("消す", role: .destructive) { model.removeTopping(status.topping) }
                                }
                        }
                    } header: {
                        Text("入れたトッピング")
                    } footer: {
                        PhraseText("間違えて入れたものは、左へなぞると消せます。")
                    }
                }
            }
            .navigationTitle("トッピングを入れる")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("入れる") {
                        if let newTopping { model.addTopping(newTopping) }
                        dismiss()
                    }
                    .disabled(newTopping == nil)
                }
            }
        }
    }

    /// 入力から作るトッピング。足りないところがあれば nil
    private var newTopping: Topping? {
        if inProgress {
            guard let remainingGB, remainingGB > 0, expiry > .now else { return nil }
            return Topping(gb: remainingGB, start: .now, end: expiry)
        }
        let gb: Double?
        let days: Int
        if let preset {
            gb = preset.gb
            days = preset.days
        } else {
            guard let customGB, customGB > 0 else { return nil }
            gb = customGB
            days = customDays
        }
        return Topping(gb: gb, start: start, end: start.addingTimeInterval(Double(days) * 86400))
    }
}

/// トッピングの 1 行。容量、残り、期限
struct ToppingRow: View {
    let status: ToppingStatus

    var body: some View {
        let topping = status.topping
        let isActive = topping.range.contains(.now)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.toppingAmount(topping.gb))
                    .font(.headline)
                Text(isActive ? "\(Format.dateTime(topping.end))まで" : (topping.end <= .now ? "期限切れ" : "\(Format.dateTime(topping.start))から"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let remaining = status.remaining {
                Text("残り \(Format.bytes(max(0, remaining)))")
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
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
