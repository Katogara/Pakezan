import Charts
import SwiftUI

/// 今月の累計と理想のペース、日ごとの使用量
struct TrendView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let summary = model.summary
                    let days = model.ledger.days(in: summary.period, now: summary.now)
                    let capGB = Format.gb(summary.cap)

                    Card {
                        Text("今月の累計")
                            .font(.headline)
                        Chart {
                            ForEach(days) { day in
                                LineMark(x: .value("日", day.date.addingTimeInterval(86400)),
                                         y: .value("GB", Format.gb(day.cumulative)),
                                         series: .value("系列", "使用量"))
                                    .foregroundStyle(Palette.color(for: summary.level))
                                    .lineStyle(StrokeStyle(lineWidth: 3))
                            }
                            LineMark(x: .value("日", summary.period.start), y: .value("GB", 0.0),
                                     series: .value("系列", "理想のペース"))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            LineMark(x: .value("日", summary.period.end), y: .value("GB", capGB),
                                     series: .value("系列", "理想のペース"))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            RuleMark(y: .value("上限", capGB))
                                .foregroundStyle(.red.opacity(0.6))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("上限 \(Format.bytes(summary.cap))")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                        }
                        .chartXScale(domain: summary.period.start...summary.period.end)
                        .frame(height: 220)
                        PhraseText("点線は、上限を締め日までの日数で割った理想のペースです。実線が点線より上なら、使い方が早めです。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Card {
                        Text("日ごとの使用量")
                            .font(.headline)
                        Chart(days) { day in
                            BarMark(x: .value("日", day.date, unit: .day), y: .value("MB", day.amount / 1_000_000))
                                .foregroundStyle(Palette.accent)
                        }
                        .chartYAxisLabel("MB")
                        .frame(height: 180)
                        if let top = days.max(by: { $0.amount < $1.amount }), top.amount > 0 {
                            Text("いちばん多かった日: \(Format.day(top.date))（\(Format.bytes(top.amount))）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("推移")
        }
    }
}
