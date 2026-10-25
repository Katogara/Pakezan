import XCTest
@testable import Pakezan

final class PakezanTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private let gb = Plan.bytesPerGB

    private func sample(_ from: Date, _ to: Date, _ bytes: Double, estimated: Bool = false,
                        source: Sample.Source = .automation) -> Sample {
        Sample(previousDate: from, date: to, cellular: UInt64(bytes), wifi: 0, estimated: estimated, source: source)
    }

    // MARK: - カウンタ

    func testDeltaNormal() {
        let boot = date(10, 1)
        let old = RawCounters(values: ["pdp_ip0.in": 100, "pdp_ip0.out": 50, "en0.in": 1000], bootTime: boot)
        let new = RawCounters(values: ["pdp_ip0.in": 300, "pdp_ip0.out": 70, "en0.in": 1500], bootTime: boot)
        let delta = CounterMath.delta(from: old, to: new)
        XCTAssertEqual(delta.cellular, 220)
        XCTAssertEqual(delta.wifi, 500)
        XCTAssertFalse(delta.rebooted)
        XCTAssertFalse(delta.reset)
    }

    func testDeltaWrapsAt4GiB() {
        let boot = date(10, 1)
        let old = RawCounters(values: ["pdp_ip0.in": UInt32.max - 99], bootTime: boot)
        let new = RawCounters(values: ["pdp_ip0.in": 200], bootTime: boot)
        XCTAssertEqual(CounterMath.delta(from: old, to: new).cellular, 300)
    }

    func testDeltaResetWithoutWrap() {
        let boot = date(10, 1)
        let old = RawCounters(values: ["pdp_ip0.in": 5_000_000], bootTime: boot)
        let new = RawCounters(values: ["pdp_ip0.in": 1_000], bootTime: boot)
        let delta = CounterMath.delta(from: old, to: new)
        XCTAssertEqual(delta.cellular, 1_000)
        XCTAssertTrue(delta.reset)
    }

    func testDeltaAfterReboot() {
        let old = RawCounters(values: ["pdp_ip0.in": 9_000_000], bootTime: date(10, 1))
        let new = RawCounters(values: ["pdp_ip0.in": 4_000], bootTime: date(10, 3))
        let delta = CounterMath.delta(from: old, to: new)
        XCTAssertEqual(delta.cellular, 4_000)
        XCTAssertTrue(delta.rebooted)
    }

    func testIgnoresOtherInterfaces() {
        let boot = date(10, 1)
        let old = RawCounters(values: ["lo0.in": 0, "utun0.in": 0], bootTime: boot)
        let new = RawCounters(values: ["lo0.in": 999, "utun0.in": 999, "pdp_ip1.out": 10], bootTime: boot)
        XCTAssertEqual(CounterMath.delta(from: old, to: new), CounterDelta(cellular: 10, wifi: 0))
    }

    // MARK: - 締め日

    func testPeriodMonthEnd() {
        let plan = Plan(preset: .linemoMini)
        XCTAssertEqual(plan.period(containing: date(10, 25, 18), calendar: calendar),
                       TimeRange(start: date(10, 1), end: date(11, 1)))
    }

    func testPeriodClosingDay() {
        let plan = Plan(preset: .custom, closingDay: 20)
        XCTAssertEqual(plan.period(containing: date(10, 20, 23), calendar: calendar),
                       TimeRange(start: date(9, 21), end: date(10, 21)))
        XCTAssertEqual(plan.period(containing: date(10, 21), calendar: calendar),
                       TimeRange(start: date(10, 21), end: date(11, 21)))
    }

    // MARK: - 集計

    func testSampleIsProratedAcrossPeriodStart() {
        // 9/30 23時〜10/1 1時に 200MB → 10 月の分は半分
        let ledger = Ledger(plan: Plan(preset: .povo20), samples: [sample(date(9, 30, 23), date(10, 1, 1), 200_000_000)],
                            calendar: calendar)
        XCTAssertEqual(ledger.summary(at: date(10, 1, 2)).used, 100_000_000, accuracy: 1)
    }

    func testCorrectionBecomesBaseline() {
        let samples = [
            sample(date(10, 1), date(10, 10), 1 * gb),
            sample(date(10, 10), date(10, 10, 6), 0.6 * gb),
        ]
        // 10/10 3時の時点で通信会社は 1.5GB と言っている → その後の 3 時間分 (0.3GB) を足す
        let ledger = Ledger(plan: Plan(preset: .linemoMini), samples: samples,
                            corrections: [Correction(asOf: date(10, 10, 3), usedBytes: 1.5 * gb)], calendar: calendar)
        XCTAssertEqual(ledger.summary(at: date(10, 10, 6)).used, 1.8 * gb, accuracy: 1)
    }

    func testCorrectionFromLastPeriodIsIgnored() {
        let ledger = Ledger(plan: Plan(preset: .linemoMini), samples: [sample(date(10, 1), date(10, 2), 0.1 * gb)],
                            corrections: [Correction(asOf: date(9, 29), usedBytes: 2.9 * gb)], calendar: calendar)
        XCTAssertEqual(ledger.summary(at: date(10, 2)).used, 0.1 * gb, accuracy: 1)
    }

    func testExtraRaisesCapOnlyThisPeriod() {
        let ledger = Ledger(plan: Plan(preset: .linemoMini), samples: [],
                            extras: [Extra(date: date(9, 20), gb: 5), Extra(date: date(10, 5), gb: 1)], calendar: calendar)
        XCTAssertEqual(ledger.summary(at: date(10, 6)).cap, 4 * gb, accuracy: 1)
    }

    func testForecastFromRecentPace() {
        // 10/20〜10/23 の 3 日で 0.6GB (1 日 0.2GB)、それまでに 1.8GB。残り 0.6GB → 3 日後の 10/26
        let samples = [
            sample(date(10, 1), date(10, 20), 1.8 * gb),
            sample(date(10, 20), date(10, 23), 0.6 * gb),
        ]
        let summary = Ledger(plan: Plan(preset: .linemoMini), samples: samples, calendar: calendar).summary(at: date(10, 23))
        XCTAssertEqual(summary.pacePerDay ?? 0, 0.2 * gb, accuracy: 1)
        XCTAssertEqual(summary.forecast!.timeIntervalSince1970, date(10, 26).timeIntervalSince1970, accuracy: 1)
    }

    func testNoForecastWhenItLasts() {
        let samples = [sample(date(10, 1), date(10, 10), 1 * gb)]
        let summary = Ledger(plan: Plan(preset: .povo20), samples: samples, calendar: calendar).summary(at: date(10, 10))
        XCTAssertNil(summary.forecast)
        XCTAssertTrue(summary.lastsUntilEnd)
    }

    // MARK: - 警告の段階

    private func level(used: Double, on day: Int, pace: Double? = nil) -> AlertLevel {
        let period = TimeRange(start: date(10, 1), end: date(11, 1))
        let now = date(10, day)
        var forecast: Date?
        if let pace { forecast = now.addingTimeInterval((3 * gb - used) / pace * 86400) }
        return UsageSummary(period: period, now: now, used: used, cap: 3 * gb, pacePerDay: pace,
                            forecast: forecast, today: 0, hasEstimate: false).level
    }

    func testAlertLevels() {
        XCTAssertEqual(level(used: 1.4 * gb, on: 16), .normal)    // 理想 1.45GB
        XCTAssertEqual(level(used: 1.2 * gb, on: 11), .pace)      // 理想 0.97GB の 1.2 倍を超えた
        XCTAssertEqual(level(used: 0.4 * gb, on: 2), .pace)       // 序盤でも 1 割を超えて早すぎる
        XCTAssertEqual(level(used: 0.05 * gb, on: 1), .normal)    // 1 割未満は見ない
        XCTAssertEqual(level(used: 2.5 * gb, on: 28), .low)
        XCTAssertEqual(level(used: 2.9 * gb, on: 30), .critical)
        XCTAssertEqual(level(used: 2.0 * gb, on: 25, pace: 0.6 * gb), .critical) // あと 1.7 日で上限
    }

    // MARK: - 時間帯

    func testSlotsSplitByThreeHours() {
        // 20時〜23時に 300MB → 18時の枠に 100MB、21時の枠に 200MB
        let samples = [
            sample(date(10, 5, 20), date(10, 5, 23), 300_000_000),
            sample(date(10, 1), date(10, 5, 20), 999, estimated: false), // 4 時間を超える記録
            sample(date(10, 5, 23), date(10, 6, 1), 50, estimated: true),
        ]
        let ledger = Ledger(plan: Plan(preset: .povo20), samples: samples, calendar: calendar)
        let usage = ledger.slots(in: TimeRange(start: date(10, 1), end: date(11, 1)), now: date(10, 7))
        XCTAssertEqual(usage.slots[6], 100_000_000, accuracy: 1)
        XCTAssertEqual(usage.slots[7], 200_000_000, accuracy: 1)
        XCTAssertEqual(usage.unknown, 1049, accuracy: 1)
    }

    func testMissingAutomationHours() {
        let now = date(10, 25, 10, 30)
        var samples: [Sample] = []
        for (day, hour) in [(24, 12), (24, 15), (24, 18), (24, 21), (25, 0), (25, 6), (25, 9)] {
            samples.append(sample(date(10, day, hour) - 3 * 3600, date(10, day, hour, 1), 1))
        }
        // 3 時はアプリを開いたときの記録なので、オートメーションには数えない
        samples.append(sample(date(10, 25, 0, 1), date(10, 25, 3, 2), 1, source: .app))
        let ledger = Ledger(plan: Plan(preset: .povo20), samples: samples, calendar: calendar)
        XCTAssertEqual(ledger.missingAutomationHours(now: now), [3])
    }

    // MARK: - 署名

    func testParseSigningExpiry() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>ExpirationDate</key><date>2026-11-01T12:00:00Z</date></dict></plist>
        """
        var data = Data([0x30, 0x82, 0x01])
        data.append(Data(plist.utf8))
        data.append(Data([0x00, 0xA0]))
        XCTAssertEqual(SigningInfo.parseExpiry(data), ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z"))
    }

    // MARK: - 保存

    func testOldFileWithoutNewKeysLoads() throws {
        let json = #"{"samples":[],"dailySummaryEnabled":false}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(StoredState.self, from: Data(json.utf8))
        XCTAssertFalse(state.dailySummaryEnabled)
        XCTAssertTrue(state.corrections.isEmpty)
        XCTAssertNil(state.plan)
    }
}
