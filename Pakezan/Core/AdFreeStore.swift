import Observation
import StoreKit

/// 「広告を消す」の購入 (App Store の買い切りの製品。非消耗型)。
/// 作りはいびきアラームの SubscriptionStore に合わせている。購入と支払いは Apple が扱い、アプリは買ったかどうかだけを見る。
/// 署名なしで入れる開発中のビルドでは App Store から製品を読めないので、買えない (広告は出る)
@MainActor
@Observable
final class AdFreeStore {
    static let shared = AdFreeStore()

    /// App Store Connect で作る製品 ID (非消耗型)
    static let productID = "pakezan.removeads"

    private static let cacheKey = "adFreePurchased"

    /// 広告を消す購入を済ませている
    private(set) var isPurchased: Bool

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        isPurchased = UserDefaults.standard.bool(forKey: Self.cacheKey)
        // ほかの端末での購入、返金などを受け取る
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    /// 買ったかを確かめ直す。端末内の記録を読むだけなので、通信を待たない
    func refresh() async {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            owned = true
        }
        guard owned != isPurchased else { return }
        isPurchased = owned
        UserDefaults.standard.set(owned, forKey: Self.cacheKey)
    }

    /// 「購入を復元」。App Store と記録を合わせ直す (Apple ID の確認が出ることがある)
    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }
}
