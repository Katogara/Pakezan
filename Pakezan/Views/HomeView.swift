import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showCorrection = false
    @State private var showExtra = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let summary = model.summary
                    RemainingCard(summary: summary, plan: model.plan)
                    ForecastCard(summary: summary)
                    WarningCards()
                    DetailsCard(summary: summary)

                    HStack(spacing: 12) {
                        Button {
                            showCorrection = true
                        } label: {
                            Label("通信会社の値で補正", systemImage: "checkmark.seal")
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            showExtra = true
                        } label: {
                            Label("容量を追加した", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle("パケざん")
            .refreshable { await model.measure(source: .app) }
            .sheet(isPresented: $showCorrection) { CorrectionSheet().environment(model) }
            .sheet(isPresented: $showExtra) { ExtraSheet().environment(model) }
        }
    }
}

/// 残り容量と円のゲージ
private struct RemainingCard: View {
    let summary: UsageSummary
    let plan: Plan

    var body: some View {
        let color = Palette.color(for: summary.level)
        Card {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle().stroke(color.opacity(0.2), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: summary.remainingFraction)
                        .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("残り")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Format.percent(summary.remainingFraction))
                            .font(.title2.bold())
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 6) {
                    Text(Palette.label(for: summary.level))
                        .font(.subheadline.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.2), in: .capsule)
                    Text("残り \(Format.bytes(max(0, summary.remaining)))")
                        .font(.title.bold())
                    Text("\(Format.bytes(summary.used)) / \(Format.bytes(summary.cap)) 使用")
                        .foregroundStyle(.secondary)
                    if plan.preset.excludesLINE {
                        PhraseText("LINE の分も含むので、通信会社の値より多めに出ます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// このペースだといつ上限に達するか
private struct ForecastCard: View {
    let summary: UsageSummary

    var body: some View {
        Card {
            Text("このペースだと")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let forecast = summary.forecast {
                Text(summary.remaining <= 0 ? "上限に達しました" : "\(Format.day(forecast))に上限")
                    .font(.title2.bold())
                    .foregroundStyle(Palette.color(for: summary.level))
            } else if summary.lastsUntilEnd {
                Text("締め日まで持ちます")
                    .font(.title2.bold())
            } else {
                PhraseText("記録がたまると予測を出します")
                    .font(.headline)
            }
            HStack {
                let daysLeft = Int(ceil(summary.period.end.timeIntervalSince(summary.now) / 86400))
                Text("締め日まで\(daysLeft)日")
                if let pace = summary.pacePerDay {
                    Text("・1日あたり \(Format.bytes(pace))")
                }
                if summary.isEarly, summary.forecast != nil {
                    Text("・月の初めなので目安です")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

/// 記録が止まっている・署名が切れそう、などの知らせ
private struct WarningCards: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.isStale {
            warning("記録が止まっています",
                    "12時間以上、記録がありません。ショートカットのオートメーションが動いているか確かめてください。")
        }
        let missing = model.missingAutomationHours
        if !model.isStale, !missing.isEmpty {
            warning("届いていない時刻があります",
                    "直近24時間で、\(missing.map { "\($0)時" }.joined(separator: "、"))の記録が届きませんでした。その時刻のオートメーションを確かめてください。")
        }
        if let expiry = SigningInfo.expiry, expiry.timeIntervalSinceNow < 2 * 86400 {
            warning("署名の期限が近づいています",
                    "\(Format.dateTime(expiry))に署名が切れます。切れると記録が止まるので、Sideloadly で入れ直してください。")
        }
    }

    private func warning(_ title: String, _ message: String) -> some View {
        Card {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            PhraseText(message)
                .font(.subheadline)
        }
    }
}

private struct DetailsCard: View {
    @Environment(AppModel.self) private var model
    let summary: UsageSummary

    var body: some View {
        Card {
            row("今日", Format.bytes(summary.today))
            row("最後の記録", model.lastMeasured.map(Format.dateTime) ?? "まだありません")
            if let correction = model.latestCorrection, summary.period.contains(correction.asOf) {
                row("最後の補正", "\(Format.dateTime(correction.asOf)) 時点")
            }
            if let expiry = SigningInfo.expiry {
                let days = Int(floor(expiry.timeIntervalSinceNow / 86400))
                row("署名の期限", days >= 1 ? "あと\(days)日（\(Format.day(expiry))）" : Format.dateTime(expiry))
            }
            if summary.hasEstimate {
                PhraseText("再起動をはさんだ区間があり、その直前に使った分は数えられていません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
