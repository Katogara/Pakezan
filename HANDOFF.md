# パケざん 引き継ぎ

- 仕様書（Claude Docs の「引き継ぎ仕様書」のタブ）：https://claude.ai/artifact/Td9sAxbudCx49n8S22HY6d
- 2026年11月26日時点で、ビルド17まで。F11（ウィジェット）のほかは実装済み。
- 11月28日の改修：広告（AdMob のバナー）と、有料で広告を消す購入。プライバシーの申告のファイル。
- 11月26日の改修：プランの一覧（PlanCatalog.swift）、はじめの説明（IntroView.swift）、料金の段階の通知、povo2.0 のトッピング（買い切り）、アイコンの「%」の吹き出しを1.5倍。

## 設計メモ

- 通信量は getifaddrs の pdp_ip*（モバイル）と en0（Wi-Fi）のカウンタの差分を足して数える。カウンタは32ビットで約4GiBで一周し、再起動で0に戻る。
- 3時間ごとの記録は、ショートカットの時刻オートメーション（0:00〜21:00 の8つ）から App Intent「通信量を記録する」を呼ぶ。アプリからオートメーションは作れないので、利用者が手で作る。
- 締め日で区切った期間ごとに数える。締め日が「月末」なら、毎月1日の0:00に0から数え直す。
- プランは PlanCatalog.swift の一覧から選ぶ。保存するのはプランの名前（id）だけで、前の版の "linemoMini" "povo20" "custom" もそのまま読める。一覧にない名前は「そのほかのプラン」として扱う。
- プランの種類は4つ。毎月の容量（fixed）、段階制（tiered。「収めたい段階」を上限にし、次の段階に入ったら知らせる）、無制限（unlimited。「見守る目安」を上限にする）、買い切り（prepaid）。
- 買い切りは、トッピングごとに容量・使い始め・期限を持つ。記録はその記録の時刻に使ったものとして、その時刻に使えるトッピングの期限の近い順に減らす。使い放題のトッピングの間は減らさない。補正は「今の残り」で入れる。
- 広告は Google AdMob のバナー（AdBanner.swift）。ホーム・推移・時間帯の画面の下に出し、はじめの説明・初回設定・設定の画面には出さない。初めて広告を出すときに追跡の許可（ATT）を聞いてから SDK を始める。広告の ID は project.yml の ADMOB_APP_ID・ADMOB_BANNER_ID（いまは Google のテスト用）から Info.plist に入る。
- 「広告を消す」は App Store の非消耗型の製品 `pakezan.removeads`（AdFreeStore.swift。作りはいびきアラームの SubscriptionStore と同じ）。設定の「広告」の欄に、StoreKit の ProductView と「購入を復元」を置く。署名なしで入れる開発中の版では製品を読めず、買えない。
- App Store に出すときは、project.yml の広告の ID を本番のものに替え、SWIFT_ACTIVE_COMPILATION_CONDITIONS に APP_STORE を足す（設定の「広告の見本を出す（開発用）」が消える）。値段と販売の方針は、公開リポジトリの外のメモで管理する。
- プライバシーの申告は Pakezan/PrivacyInfo.xcprivacy。プライバシーポリシーは https://katogara.github.io/pakezan/privacy.html（サポートサイトのリポジトリ Katogara/Katogara.github.io）。
- アイコンのバッジは残りの割合（%）。iPhone ではバッジがアイコンの右上（横0.71〜1.18、縦−0.15〜0.22）を覆うので、アイコンの「%」の吹き出しはその下に置いている。
