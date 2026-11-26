import Foundation

/// 料金の段階 (使った量で月額が決まるプランの 1 段)
struct PlanTier: Equatable {
    /// この段階の上限 (GB)。nil は無制限
    var upToGB: Double?
    /// 割引前の税込の月額 (円)。分からなければ nil
    var yen: Int?
}

/// 選べるプランの中身。2026 年 11 月下旬に各社の公式ページと比較記事で確かめた内容
/// (ドコモの ahamo と mini2 は 2026 年 12 月 1 日の改定後)
struct PlanSpec: Identifiable, Equatable {
    enum Kind: Equatable {
        /// 毎月決まった容量
        case fixed
        /// 使った量で月額が変わる段階制
        case tiered
        /// 容量の上限がない
        case unlimited
        /// 容量と有効期間を決めて、そのつど買い切る (povo2.0 のトッピング)
        case prepaid
    }

    let id: String
    let carrier: Carrier
    let name: String
    let kind: Kind
    /// 上限として選べる量 (GB)。fixed は契約できる容量、tiered は段階の境目、unlimited は目安
    let capOptions: [Double]
    let tiers: [PlanTier]
    /// 余った容量を翌月に繰り越せる
    let carryover: Bool
    /// LINE ギガフリーで、LINE アプリの通信を数えない
    let excludesLINE: Bool
    /// 上限を超えたあとの速度など
    let afterCap: String?
    let note: String?
    /// 新規の受付を終えたプラン (契約中の人のために残す)
    let closed: Bool

    init(_ id: String, _ carrier: Carrier, _ name: String, _ kind: Kind, caps: [Double], tiers: [PlanTier] = [],
         carryover: Bool = false, excludesLINE: Bool = false, afterCap: String? = nil, note: String? = nil,
         closed: Bool = false) {
        self.id = id
        self.carrier = carrier
        self.name = name
        self.kind = kind
        self.capOptions = caps
        self.tiers = tiers
        self.carryover = carryover
        self.excludesLINE = excludesLINE
        self.afterCap = afterCap
        self.note = note
        self.closed = closed
    }

    /// 選んだときの上限。段階制は、いちばん安い段階に収める前提にする
    var defaultCapGB: Double { capOptions.first ?? 3 }

    var title: String { closed ? "\(name)（受付終了）" : name }

    /// 通信会社が使用量に数えない通信。パケざんは数えてしまうので、残りが実際より少なく出る
    var uncountedTraffic: String? { excludesLINE ? "LINE アプリの通信（LINE ギガフリー）" : nil }

    /// 数えない通信があるプランで、残りのずれを知らせる文
    var uncountedNotice: (title: String, message: String)? {
        guard let uncountedTraffic else { return nil }
        return ("実際の残りはパケざんの表示より多めです",
                "\(carrier.name)は\(uncountedTraffic)を使用量に数えません。パケざんはこの携帯の通信をすべて数えるので、その分だけ使用量が多く、残りが少なく出ます。ずれが気になるときは、ホームの「通信会社の値で補正」で実際の値に合わせてください。")
    }

    /// 設定の画面で、上限の行に付ける名前
    var capLabel: String {
        switch kind {
        case .fixed: "月の容量"
        case .tiered: "収めたい段階"
        case .unlimited: "見守る目安"
        case .prepaid: "容量"
        }
    }

    /// 使った量 (GB) が入る段階の番号
    func tierIndex(usedGB: Double) -> Int? {
        guard kind == .tiered else { return nil }
        return tiers.firstIndex { tier in tier.upToGB.map { usedGB <= $0 } ?? true } ?? tiers.indices.last
    }
}

/// 通信会社 (ブランド)
enum Carrier: String, CaseIterable, Identifiable {
    case docomo, au, uq, povo, softbank, ymobile, linemo, rakuten, iijmio, mineo, nihontsushin, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .docomo: "ドコモ・ahamo"
        case .au: "au"
        case .uq: "UQ mobile"
        case .povo: "povo"
        case .softbank: "ソフトバンク"
        case .ymobile: "ワイモバイル"
        case .linemo: "LINEMO"
        case .rakuten: "楽天モバイル"
        case .iijmio: "IIJmio"
        case .mineo: "mineo"
        case .nihontsushin: "日本通信SIM"
        case .other: "そのほかの会社"
        }
    }

    var plans: [PlanSpec] { PlanCatalog.all.filter { $0.carrier == self } }
}

enum PlanCatalog {
    private static let unlimitedNote = "容量の上限がないプランです。使いすぎに気づきたい量を、見守る目安として決めてください。"

    static let all: [PlanSpec] = [
        // ドコモ
        PlanSpec("ahamo", .docomo, "ahamo", .tiered, caps: [40, 60, 120],
                 tiers: [PlanTier(upToGB: 40, yen: 3135), PlanTier(upToGB: 60, yen: 4125), PlanTier(upToGB: 120, yen: 5115)],
                 afterCap: "120GBを超えると、月末まで最大1Mbpsになります。",
                 note: "2026年12月1日からの料金です。11月までは30GB（大盛りオプションは110GB）でした。"),
        PlanSpec("docomoMax", .docomo, "ドコモ MAX", .tiered, caps: [1, 3],
                 tiers: [PlanTier(upToGB: 1, yen: 5698), PlanTier(upToGB: 3, yen: 6798), PlanTier(upToGB: nil, yen: 8448)]),
        PlanSpec("docomoPoikatsuMax", .docomo, "ドコモ ポイ活 MAX", .unlimited, caps: [100], note: unlimitedNote),
        PlanSpec("docomoPoikatsu20", .docomo, "ドコモ ポイ活 20", .tiered, caps: [20],
                 tiers: [PlanTier(upToGB: 20, yen: 7898), PlanTier(upToGB: nil, yen: 9570)]),
        PlanSpec("docomoMini2", .docomo, "ドコモ mini2", .tiered, caps: [6, 12],
                 tiers: [PlanTier(upToGB: 6, yen: 3278), PlanTier(upToGB: 12, yen: 4598)],
                 note: "2026年12月1日に始まるプランです。"),
        PlanSpec("docomoMini", .docomo, "ドコモ mini", .fixed, caps: [4, 10], closed: true),

        // au
        PlanSpec("auMax", .au, "使い放題MAX＋・auバリューリンク（マネ活2を含む）", .unlimited, caps: [200, 100, 60],
                 afterCap: "月200GBを超えると最大5Mbpsになります。テザリングとデータシェアは合わせて60GBまでです。",
                 note: unlimitedNote),
        PlanSpec("auMini", .au, "スマホミニプラン＋", .tiered, caps: [1, 3, 5],
                 tiers: [PlanTier(upToGB: 1, yen: 4928), PlanTier(upToGB: 3, yen: 6578), PlanTier(upToGB: 5, yen: 8228)],
                 afterCap: "5GBを超えると、月末まで最大300kbpsになります。"),
        PlanSpec("auSenior", .au, "シニアバリュープラン", .fixed, caps: [5],
                 afterCap: "5GBを超えると、月末まで最大128kbpsになります。"),
        PlanSpec("auU18", .au, "U18バリュープラン", .tiered, caps: [3, 20],
                 tiers: [PlanTier(upToGB: 3, yen: 2398), PlanTier(upToGB: 20, yen: 4048)]),

        // UQ mobile
        PlanSpec("uqTokutoku2", .uq, "トクトクプラン2", .tiered, caps: [5, 30],
                 tiers: [PlanTier(upToGB: 5, yen: 2948), PlanTier(upToGB: 30, yen: 4048)], carryover: true),
        PlanSpec("uqComikomiValue", .uq, "コミコミプランバリュー", .fixed, caps: [35], carryover: true),

        // povo
        PlanSpec("povo2Topping", .povo, "povo2.0（トッピング）", .prepaid, caps: [],
                 afterCap: "トッピングを使い切るか期限が切れると、最大128kbpsになります。"),
        PlanSpec("povo20", .povo, "povo1.0（20GB）", .fixed, caps: [20], closed: true),

        // ソフトバンク
        PlanSpec("sbUnlimited", .softbank, "ペイトク2・テイガク無制限", .unlimited, caps: [300, 100],
                 afterCap: "直近30日間で300GBを超えると、最大4.5Mbpsになります。", note: unlimitedNote),
        PlanSpec("sbMinifit2", .softbank, "ミニフィット2", .tiered, caps: [2, 5],
                 tiers: [PlanTier(upToGB: 2, yen: nil), PlanTier(upToGB: 5, yen: nil)]),
        PlanSpec("sbDebut2", .softbank, "スマホデビュープラン2", .tiered, caps: [3, 30],
                 tiers: [PlanTier(upToGB: 3, yen: nil), PlanTier(upToGB: 30, yen: nil)]),

        // ワイモバイル
        PlanSpec("ymobileS", .ymobile, "シンプル3 S", .fixed, caps: [5], carryover: true),
        PlanSpec("ymobileM", .ymobile, "シンプル3 M", .fixed, caps: [30], carryover: true),
        PlanSpec("ymobileL", .ymobile, "シンプル3 L", .fixed, caps: [35], carryover: true),

        // LINEMO
        PlanSpec("linemoBest", .linemo, "ベストプラン", .tiered, caps: [3, 10],
                 tiers: [PlanTier(upToGB: 3, yen: 990), PlanTier(upToGB: 10, yen: 2090)], excludesLINE: true,
                 afterCap: "10GBを超えると最大300kbps、15GBを超えると最大128kbpsになります。"),
        PlanSpec("linemoBestV", .linemo, "ベストプランV", .fixed, caps: [30], excludesLINE: true,
                 afterCap: "30GBを超えると最大1Mbps、45GBを超えると最大128kbpsになります。"),
        PlanSpec("linemoMini", .linemo, "ミニプラン（3GB）", .fixed, caps: [3], excludesLINE: true, closed: true),
        PlanSpec("linemoSmart", .linemo, "スマホプラン（20GB）", .fixed, caps: [20], excludesLINE: true, closed: true),

        // 楽天モバイル
        PlanSpec("rakutenSaikyo", .rakuten, "Rakuten最強プラン", .tiered, caps: [3, 20],
                 tiers: [PlanTier(upToGB: 3, yen: 1078), PlanTier(upToGB: 20, yen: 2178), PlanTier(upToGB: nil, yen: 3278)]),

        // IIJmio
        PlanSpec("iijmioGiga", .iijmio, "ギガプラン", .fixed, caps: [2, 5, 10, 15, 25, 35, 45, 55], carryover: true),

        // mineo
        PlanSpec("mineoMypita", .mineo, "マイピタ", .fixed, caps: [3, 7, 15, 30, 50], carryover: true,
                 afterCap: "容量を使い切ると、最大200kbpsになります。"),
        PlanSpec("mineoMysoku", .mineo, "マイそく", .unlimited, caps: [30, 10],
                 afterCap: "平日の12時台は最大32kbpsになります。",
                 note: "速度で選ぶプランで、容量の上限がありません。使いすぎに気づきたい量を、見守る目安として決めてください。"),

        // 日本通信SIM
        PlanSpec("nihontsushin", .nihontsushin, "合理的プラン・ネットだけプラン", .fixed, caps: [1, 20, 50],
                 note: "1GB（シンプル290）、20GB（みんなのプラン、ネットだけプラン）、50GB から選びます。"),

        // そのほか
        PlanSpec("custom", .other, "そのほかのプラン", .fixed, caps: [3],
                 note: "容量と締め日を契約に合わせて入れてください。"),
    ]

    static func spec(id: String) -> PlanSpec? { all.first { $0.id == id } }

    /// povo2.0 のデータトッピングの主なもの (2026 年 11 月下旬に比較記事で確かめた内容。期間限定のものを含む)
    static let povoToppings: [ToppingPreset] = [
        ToppingPreset(gb: nil, days: 1, label: "使い放題（24時間）"),
        ToppingPreset(gb: 1, days: 7),
        ToppingPreset(gb: 3, days: 30),
        ToppingPreset(gb: 30, days: 30),
        ToppingPreset(gb: 90, days: 90),
        ToppingPreset(gb: 1, days: 180),
        ToppingPreset(gb: 180, days: 180),
        ToppingPreset(gb: 360, days: 365),
        ToppingPreset(gb: 1320, days: 365),
    ]
}

/// トッピングの選択肢
struct ToppingPreset: Identifiable, Hashable {
    /// 容量 (GB)。nil は使い放題
    let gb: Double?
    let days: Int
    var label: String?

    var id: String { "\(gb.map { "\($0)" } ?? "unlimited")-\(days)" }

    var title: String {
        if let label { return label }
        return "\(Format.toppingAmount(gb))（\(days)日間）"
    }
}
