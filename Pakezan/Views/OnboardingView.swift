import SwiftUI

/// 初回設定: プラン → 通知の許可 → オートメーション → 今の使用量
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var usedGB: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case 0: planStep
                    case 1: notificationStep
                    case 2: AutomationGuideView()
                    default: usageStep
                    }
                }
                .padding()
            }
            .navigationTitle(["プランを選ぶ", "通知を許可する", "オートメーションを作る", "今の使用量を入れる"][min(step, 3)])
            .safeAreaInset(edge: .bottom) {
                Button {
                    next()
                } label: {
                    Text(step < 3 ? "次へ" : (usedGB == nil ? "あとで入れる" : "はじめる"))
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
            if model.state.plan == nil { model.setPlan(Plan(preset: .linemoMini)) }
        }
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeadlineText("パケざんは、パケットの残りを見守ります")
                .font(.title2.bold())
            PhraseText("3時間ごとにこの携帯のモバイル通信量を記録し、上限に達しそうなときに早めに知らせます。この携帯で使っているプランを選んでください。")
            Form { PlanFields() }
                .frame(height: 220)
                .scrollDisabled(true)
            if model.plan.preset.excludesLINE {
                PhraseText("LINEMO は LINE アプリの通信を数えません（LINE ギガフリー）。パケざんは LINE の分も含めて数えるので、少し多めに出ます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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

    private var usageStep: some View {
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
        if let usedGB {
            model.addCorrection(usedGB: usedGB, asOf: .now)
        }
        model.finishOnboarding()
        Task { await model.measure(source: .app) }
    }
}
