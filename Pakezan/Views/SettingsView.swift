import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PlanFields()
                } header: {
                    Text("プラン")
                }

                Section {
                    Toggle("毎日21時のまとめ", isOn: Binding(get: { model.state.dailySummaryEnabled },
                                                       set: { model.setDailySummary($0) }))
                } header: {
                    Text("通知")
                } footer: {
                    PhraseText("警告（ペースが早め・残り20%・まもなく上限）は、段階ごとに1回だけ届きます。")
                }

                Section("記録") {
                    NavigationLink("オートメーションの設定") {
                        ScrollView { AutomationGuideView().padding() }
                            .navigationTitle("オートメーション")
                    }
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("記録を CSV で書き出す", systemImage: "square.and.arrow.up")
                        }
                    }
                    LabeledContent("記録の件数", value: "\(model.state.samples.count)件")
                }

                Section("このアプリ") {
                    if let expiry = SigningInfo.expiry {
                        LabeledContent("署名の期限", value: Format.dateTime(expiry))
                    }
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                    LabeledContent("バージョン", value: version)
                }
            }
            .navigationTitle("設定")
            .onAppear { exportURL = model.exportCSV() }
        }
    }
}

/// プラン・上限・締め日。初回設定と設定画面の両方で使う
struct PlanFields: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.plan
        Picker("プラン", selection: Binding(get: { plan.preset },
                                          set: { model.setPlan(Plan(preset: $0, closingDay: plan.closingDay)) })) {
            ForEach(PlanPreset.allCases) { preset in
                Text(preset.title).tag(preset)
            }
        }
        Stepper(value: Binding(get: { plan.capGB }, set: { var p = plan; p.capGB = $0; model.setPlan(p) }),
                in: 1...200, step: 1) {
            LabeledContent("月の上限", value: "\(plan.capGB.formatted())GB")
        }
        Picker("締め日", selection: Binding(get: { plan.closingDay },
                                          set: { var p = plan; p.closingDay = $0; model.setPlan(p) })) {
            Text("月末").tag(0)
            ForEach(1...27, id: \.self) { day in
                Text("\(day)日").tag(day)
            }
        }
    }
}
