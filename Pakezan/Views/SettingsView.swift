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

                AdFreeSection()

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

/// 広告を消す購入と、購入の復元。値段は App Store の設定から表示される
private struct AdFreeSection: View {
    @State private var adFree = AdFreeStore.shared
    @State private var ads = AdController.shared
    @State private var restoring = false

    var body: some View {
        Section {
            if adFree.isPurchased {
                Label("広告を消しました。ありがとうございます", systemImage: "checkmark.seal.fill")
            } else {
                ProductView(id: AdFreeStore.productID) {
                    Image(systemName: "rectangle.slash")
                        .font(.title2)
                        .foregroundStyle(Palette.accent)
                }
                .productViewStyle(.compact)
                .onInAppPurchaseCompletion { _, result in
                    if case .success(.success(let verification)) = result, case .verified(let transaction) = verification {
                        await transaction.finish()
                    }
                    await adFree.refresh()
                }
            }
            Button(restoring ? "確かめています…" : "購入を復元") {
                restoring = true
                Task {
                    await adFree.restore()
                    restoring = false
                }
            }
            .disabled(restoring)
            #if !APP_STORE
            Toggle("広告の見本を出す（開発用）", isOn: Binding(get: { !ads.hidesSample }, set: { ads.hidesSample = !$0 }))
            #endif
        } header: {
            Text("広告")
        } footer: {
            #if APP_STORE
            PhraseText("一度買うと、広告が出なくなります。iPhone を替えたときは「購入を復元」を押してください。")
            #else
            PhraseText("一度買うと、広告が出なくなります。iPhone を替えたときは「購入を復元」を押してください。開発中の版は App Store から製品を読めないので、買えません。広告はテスト用のものが出ます。")
            #endif
        }
    }
}

/// 会社・プラン・上限・締め日。初回設定と設定画面の両方で使う
struct PlanFields: View {
    @Environment(AppModel.self) private var model
    /// 選べる量のほかに、自分で量を入れている
    @State private var entersOwnCap = false
    /// 数えない通信があるプランを選んだときに出す知らせ
    @State private var notice: (title: String, message: String)?

    /// Picker で「ほかの量」を表す値
    private static let ownCapTag = -1.0

    var body: some View {
        let plan = model.plan
        let spec = plan.preset.spec
        ChoiceRow(title: "会社", choices: Carrier.allCases.map { Choice(value: $0, text: $0.name) },
                  selection: Binding(get: { spec.carrier }, set: { carrier in
            guard carrier != spec.carrier, let first = carrier.plans.first else { return }
            select(first)
        }))
        .alert(notice?.title ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("分かりました") { notice = nil }
        } message: {
            Text(notice?.message ?? "")
        }
        if spec.carrier.plans.count > 1 {
            ChoiceRow(title: "プラン", choices: spec.carrier.plans.map { Choice(value: $0.id, text: $0.title) },
                      selection: Binding(get: { spec.id }, set: { id in
                guard id != spec.id, let item = PlanCatalog.spec(id: id) else { return }
                select(item)
            }))
        }
        if spec.id != PlanPreset.custom.id, spec.kind != .prepaid {
            ChoiceRow(title: spec.capLabel,
                      choices: spec.capOptions.map { Choice(value: $0, text: capOptionText(spec, $0)) }
                          + [Choice(value: Self.ownCapTag, text: "ほかの量を入れる")],
                      selection: Binding(get: {
                entersOwnCap || !spec.capOptions.contains(plan.capGB) ? Self.ownCapTag : plan.capGB
            }, set: { value in
                entersOwnCap = value == Self.ownCapTag
                guard !entersOwnCap else { return }
                var p = plan
                p.capGB = value
                model.setPlan(p)
            }))
        }
        if spec.kind != .prepaid, spec.id == PlanPreset.custom.id || entersOwnCap || !spec.capOptions.contains(plan.capGB) {
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
        if spec.kind != .prepaid {
            Picker("締め日", selection: Binding(get: { plan.closingDay },
                                              set: { var p = plan; p.closingDay = $0; model.setPlan(p) })) {
                Text("月末").tag(0)
                ForEach(1...27, id: \.self) { day in
                    Text("\(day)日").tag(day)
                }
            }
        }
    }

    /// プランを選び直す。数えない通信があるプランなら、残りのずれを知らせる
    private func select(_ item: PlanSpec) {
        entersOwnCap = false
        model.choosePlan(PlanPreset(id: item.id))
        // 選ぶ画面から戻る動きが終わってから出す (動きの途中だと知らせが出ないことがある)
        let next = item.uncountedNotice
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { notice = next }
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
        if spec.kind == .prepaid {
            lines.append("容量と期限を決めて買い切るプランです。トッピングを買ったら、ホームの「トッピングを入れる」で入れてください。期限が近いものから減っていきます。")
            lines.append("残りがあるトッピングの期限まで2日を切ると、通知で知らせます。")
        }
        if spec.kind == .tiered {
            lines.append("使った量で料金が決まります。パケざんは「収めたい段階」を上限として見守り、次の段階に入ったときにも知らせます。")
        }
        if let afterCap = spec.afterCap { lines.append(afterCap) }
        if spec.carryover {
            lines.append("先月の余りを繰り越せるプランです。繰り越した分はホームの「容量を追加した」で足してください。")
        }
        if let notice = spec.uncountedNotice { lines.append(notice.message) }
        if let note = spec.note { lines.append(note) }
        return lines
    }
}
