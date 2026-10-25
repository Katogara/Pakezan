import Charts
import SwiftUI

/// どの時間帯に使ったか (3 時間ごと) と、モバイルと Wi-Fi の比率
struct HoursView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let summary = model.summary
                    let usage = model.ledger.slots(in: summary.period, now: summary.now)
                    let known = usage.slots.reduce(0, +)

                    Card {
                        Text("今月、使った時間帯")
                            .font(.headline)
                        Chart(Array(usage.slots.enumerated()), id: \.offset) { slot, amount in
                            BarMark(x: .value("時間帯", "\(slot * 3)時"), y: .value("MB", amount / 1_000_000))
                                .foregroundStyle(Palette.accent)
                        }
                        .chartYAxisLabel("MB")
                        .frame(height: 200)
                        if known > 0, let top = usage.slots.indices.max(by: { usage.slots[$0] < usage.slots[$1] }) {
                            PhraseText("\(top * 3)〜\((top + 1) * 3)時に、時間帯が分かる分の\(Format.percent(usage.slots[top] / known))を使っています。")
                                .font(.subheadline)
                        } else {
                            PhraseText("記録がたまると、どの時間帯に多く使っているかが分かります。")
                                .font(.subheadline)
                        }
                        if usage.unknown > 0 {
                            PhraseText("時間帯が分からない分: \(Format.bytes(usage.unknown))（記録の間が4時間以上空いたか、再起動をはさんだ区間）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    let range = TimeRange(start: summary.period.start, end: summary.now)
                    let cellular = model.ledger.cellular(in: range)
                    let wifi = model.ledger.wifi(in: range)
                    Card {
                        Text("モバイルと Wi-Fi")
                            .font(.headline)
                        if cellular + wifi > 0 {
                            GeometryReader { proxy in
                                HStack(spacing: 2) {
                                    Palette.accent
                                        .frame(width: proxy.size.width * cellular / (cellular + wifi))
                                    Color.gray.opacity(0.4)
                                }
                                .clipShape(.rect(cornerRadius: 6))
                            }
                            .frame(height: 24)
                            Text("モバイル \(Format.bytes(cellular))・Wi-Fi \(Format.bytes(wifi))")
                                .font(.subheadline)
                            PhraseText("上限と比べるのはモバイルの分だけです。Wi-Fi の量は参考の値です。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            PhraseText("記録がたまると、モバイルと Wi-Fi の比率が分かります。")
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("時間帯")
        }
    }
}
