import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var exportURL: URL?
    @State private var showIntro = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PlanFields()
                } header: {
                    Text("プラン")
                }
                PlanInfoSection()

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
                    Button("はじめの説明を見る") { showIntro = true }
                    if let expiry = SigningInfo.expiry {
                        LabeledContent("署名の期限", value: Format.dateTime(expiry))
                    }
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                    LabeledContent("バージョン", value: version)
                }
            }
            .navigationTitle("設定")
            .onAppear { exportURL = model.exportCSV() }
            .fullScreenCover(isPresented: $showIntro) {
                IntroView { showIntro = false }
            }
        }
    }
}

/// 会社・プラン・上限・締め日。初回設定と設定画面の両方で使う
struct PlanFields: View {
    @Environment(AppModel.self) private var model
    /// 選べる量のほかに、自分で量を入れている
    @State private var entersOwnCap = false

    /// Picker で「ほかの量」を表す値
    private static let ownCapTag = -1.0

    var body: some View {
        let plan = model.plan
        let spec = plan.preset.spec
        Picker("会社", selection: Binding(get: { spec.carrier }, set: { carrier in
            guard carrier != spec.carrier, let first = carrier.plans.first else { return }
            entersOwnCap = false
            model.choosePlan(PlanPreset(id: first.id))
        })) {
            ForEach(Carrier.allCases) { carrier in
                Text(carrier.name).tag(carrier)
            }
        }
        if spec.carrier.plans.count > 1 {
            Picker("プラン", selection: Binding(get: { spec.id }, set: { id in
                entersOwnCap = false
                model.choosePlan(PlanPreset(id: id))
            })) {
                ForEach(spec.carrier.plans) { item in
                    Text(item.title).tag(item.id)
                }
            }
        }
        if spec.id != PlanPreset.custom.id {
            Picker(spec.capLabel, selection: Binding(get: {
                entersOwnCap || !spec.capOptions.contains(plan.capGB) ? Self.ownCapTag : plan.capGB
            }, set: { value in
                entersOwnCap = value == Self.ownCapTag
                guard !entersOwnCap else { return }
                var p = plan
                p.capGB = value
                model.setPlan(p)
            })) {
                ForEach(spec.capOptions, id: \.self) { gb in
                    Text(capOptionText(spec, gb)).tag(gb)
                }
                Text("ほかの量を入れる").tag(Self.ownCapTag)
            }
        }
        if spec.id == PlanPreset.custom.id || entersOwnCap || !spec.capOptions.contains(plan.capGB) {
            Stepper(onIncrement: {
                var p = plan
                p.capGB = min(1000, plan.capGB + Self.step(above: plan.capGB))
                model.setPlan(p)
            }, onDecrement: {
                var p = plan
                p.capGB = max(1, plan.capGB - Self.step(above: plan.capGB - 0.001))
                model.setPlan(p)
            }) {
                LabeledContent(spec.id == PlanPreset.custom.id ? "月の容量" : "量", value: Format.gbText(plan.capGB))
            }
        }
        Picker("締め日", selection: Binding(get: { plan.closingDay },
                                          set: { var p = plan; p.closingDay = $0; model.setPlan(p) })) {
            Text("月末").tag(0)
            ForEach(1...27, id: \.self) { day in
                Text("\(day)日").tag(day)
            }
        }
    }

    /// 選べる量の表示。段階制なら、その段階の月額も添える
    private func capOptionText(_ spec: PlanSpec, _ gb: Double) -> String {
        if spec.kind == .tiered, let yen = spec.tiers.first(where: { $0.upToGB == gb })?.yen {
            return "〜\(Format.gbText(gb))（\(yen.formatted())円）"
        }
        return spec.kind == .tiered ? "〜\(Format.gbText(gb))" : Format.gbText(gb)
    }

    /// 量を増やす・減らす幅。量が大きいほど大きく動かす
    static func step(above gb: Double) -> Double {
        switch gb {
        case ..<10: 1
        case ..<50: 5
        default: 10
        }
    }
}

/// 選んだプランの説明 (料金の段階、上限を超えたあと、繰り越しなど)
struct PlanInfoSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let spec = model.plan.preset.spec
        let lines = PlanInfo.lines(for: spec)
        if spec.kind == .tiered || !lines.isEmpty {
            Section {
                if spec.kind == .tiered {
                    ForEach(Array(spec.tiers.enumerated()), id: \.offset) { _, tier in
                        LabeledContent(Format.tierText(tier), value: tier.yen.map { "\($0.formatted())円" } ?? "")
                    }
                }
                ForEach(lines, id: \.self) { line in
                    PhraseText(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(spec.kind == .tiered ? "料金の段階（割引前・税込）" : "このプランについて")
            }
        }
    }
}

enum PlanInfo {
    /// プランについて、利用者に知らせておくこと
    static func lines(for spec: PlanSpec) -> [String] {
        var lines: [String] = []
        if spec.kind == .tiered {
            lines.append("使った量で料金が決まります。パケざんは「収めたい段階」を上限として見守り、次の段階に入ったときにも知らせます。")
        }
        if let afterCap = spec.afterCap { lines.append(afterCap) }
        if spec.carryover {
            lines.append("先月の余りを繰り越せるプランです。繰り越した分はホームの「容量を追加した」で足してください。")
        }
        if spec.excludesLINE {
            lines.append("通信会社は LINE アプリの通信を数えません（LINE ギガフリー）。パケざんは LINE の分も含めて数えるので、少し多めに出ます。")
        }
        if let note = spec.note { lines.append(note) }
        return lines
    }
}
