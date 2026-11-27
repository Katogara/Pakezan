import AppTrackingTransparency
import GoogleMobileAds
import Observation
import SwiftUI
import UIKit

/// 広告 (Google AdMob のバナー)。広告の ID は project.yml の ADMOB_APP_ID・ADMOB_BANNER_ID から Info.plist に入る。
/// 開発中は Google のテスト用の ID を使い、App Store に出すときに AdMob で作った ID に替える
@MainActor
@Observable
final class AdController {
    static let shared = AdController()

    private static let hidesSampleKey = "hidesAdSample"

    /// 開発中の版で、広告の見本を出さない (App Store の版では使わない)
    var hidesSample: Bool {
        didSet { UserDefaults.standard.set(hidesSample, forKey: Self.hidesSampleKey) }
    }

    @ObservationIgnored private var started = false

    init() {
        hidesSample = UserDefaults.standard.bool(forKey: Self.hidesSampleKey)
    }

    static var bannerUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "PakezanBannerUnitID") as? String ?? ""
    }

    /// 広告を出してよいか。はじめの説明と初回設定のあいだ、広告を消す購入のあとは出さない
    func shows(model: AppModel, adFree: AdFreeStore) -> Bool {
        guard model.isOnboarded, model.hasSeenIntro, !adFree.isPurchased, !Self.bannerUnitID.isEmpty else { return false }
        #if APP_STORE
        return true
        #else
        return !hidesSample
        #endif
    }

    /// 初めて広告を出すときに、追跡の許可を聞いてから広告の仕組みを始める
    func startIfNeeded() async {
        guard !started else { return }
        started = true
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            // 画面が出きってから聞く (出たばかりだと、許可を聞く画面が出ないことがある)
            try? await Task.sleep(for: .seconds(1))
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        _ = await MobileAds.shared.start()
    }
}

/// 画面の下に置く広告の枠。広告を出さないときは何も出さない
struct AdBannerSlot: View {
    @Environment(AppModel.self) private var model
    @State private var ads = AdController.shared
    @State private var adFree = AdFreeStore.shared
    @State private var failed = false

    var body: some View {
        if ads.shows(model: model, adFree: adFree), !failed {
            let size = largeAnchoredAdaptiveBanner(width: Self.screenWidth)
            BannerContainer(adSize: size, unitID: AdController.bannerUnitID, failed: $failed)
                .frame(width: size.size.width, height: size.size.height)
                .frame(maxWidth: .infinity)
                .background(.bar)
                .task { await ads.startIfNeeded() }
        }
    }

    private static var screenWidth: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }
            .first ?? 375
    }
}

private struct BannerContainer: UIViewRepresentable {
    let adSize: AdSize
    let unitID: String
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(failed: $failed) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = unitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        private let failed: Binding<Bool>

        init(failed: Binding<Bool>) { self.failed = failed }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            failed.wrappedValue = false
        }

        /// 通信がないときなど、広告を読めなかったら枠ごと隠す
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            failed.wrappedValue = true
        }
    }
}
