import SwiftUI

/// 初回設定: プラン → 通知の許可 → オートメーション → 今の使用量
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var usedGB: Double?
    @State private var showTopping = false

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 {
                    planStep
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            switch step {
                            case 1: notificationStep
                            case 2: AutomationGuideView()
                            default: usageStep
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(["プランを選ぶ", "通知を許可する", "オートメーションを作る",
                              model.isPrepaid ? "トッピングを入れる" : "今の使用量を入れる"][min(step, 3)])
            .sheet(isPresented: $showTopping) { ToppingSheet().environment(model) }
            .safeAreaInset(edge: .bottom) {
                Button {
                    next()
                } label: {
                    Text(step < 3 ? "次へ" : (model.isPrepaid || usedGB != nil ? "はじめる" : "あとで入れる"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("戻る") { step -= 1 }
                    }
                }
            }
        }
        .onAppear {
            if model.state.plan == nil { model.setPlan(Plan(preset: .custom)) }
        }
    }

    private var planStep: some View {
        Form {
            Section {
                PlanFields()
            } header: {
                PhraseText("この携帯で使っている会社とプランを選んでください。一覧にないときは、会社で「そのほかの会社」を選びます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .padding(.bottom, 4)
            }
            PlanInfoSection()
        }
    }

    private var notificationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhraseText("ペースが早いとき、残りが少なくなったとき、署名の期限が近いときに通知で知らせます。アイコンのバッジには残りの割合を出します。")
            Button {
                Task { await model.notifier.requestAuthorization() }
            } label: {
                Label("通知を許可する", systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var usageStep: some View {
        if model.isPrepaid {
            toppingStep
        } else {
            monthlyUsageStep
        }
    }

    private var toppingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhraseText("今使えるトッピングを入れてください。前から使っているものは、公式アプリに出ている今の残りと期限を入れます。")
            Button {
                showTopping = true
            } label: {
                Label("トッピングを入れる", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            ForEach(model.activeToppings) { status in
                ToppingRow(status: status)
            }
            PhraseText("あとから、ホームの「トッピングを入れる」でも入れられます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var monthlyUsageStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhraseText("会員ページや公式アプリで、今月すでに使った量を確かめて入れてください。ここから先は、パケざんが増えた分を足していきます。")
            TextField("今月の使用量（GB） 例: 0.8", value: $usedGB, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            PhraseText("あとから、ホームの「通信会社の値で補正」でも入れられます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func next() {
        guard step >= 3 else {
            step += 1
            return
        }
        if let usedGB, !model.isPrepaid {
            model.addCorrection(usedGB: usedGB, asOf: .now)
        }
        model.finishOnboarding()
        Task { await model.measure(source: .app) }
    }
}
