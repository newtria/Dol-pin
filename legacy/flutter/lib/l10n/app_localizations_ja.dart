// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'dol-pin';

  @override
  String get home => 'ホーム';

  @override
  String get explore => '探す';

  @override
  String get chat => 'チャット';

  @override
  String get profile => 'my dol-pin';

  @override
  String get upcomingConcerts => '今後のコンサート';

  @override
  String get trendingItems => '人気アイテム';

  @override
  String get nearbyItems => '近くのアイテム';

  @override
  String get login => 'ログイン';

  @override
  String get signup => '新規登録';

  @override
  String get comingSoon => '準備中';

  @override
  String get pinItem => 'ピンする';

  @override
  String get myPins => 'マイピン';

  @override
  String get tagline => 'コンサート、ワンタップで。\n安全。速い。地元。';

  @override
  String get continueWithPhone => '電話番号で続ける';

  @override
  String get phoneHint => '電話番号 (+81...)';

  @override
  String get invalidPhoneFormat => '有効な電話番号を入力してください（例: +819012345678）';

  @override
  String get or => 'または';

  @override
  String get termsNotice => '続行すると利用規約に同意したことになります';

  @override
  String get verify => '認証';

  @override
  String get enterVerificationCode => '認証コードを入力してください';

  @override
  String sentTo(Object phone) {
    return '$phoneに送信済み';
  }

  @override
  String get invalidCode => '無効なコードです。もう一度お試しください。';

  @override
  String get resendCode => 'コードを再送信';

  @override
  String get codeResent => 'コードを再送信しました';

  @override
  String get createProfile => 'プロフィール作成';

  @override
  String get nickname => 'ニックネーム';

  @override
  String get enterNickname => 'ニックネームを入力';

  @override
  String get country => '国';

  @override
  String get favoriteGroups => '推しグループ（任意）';

  @override
  String get typeAndEnter => '入力してEnterを押してください';

  @override
  String get getStarted => 'はじめる';

  @override
  String get messages => 'メッセージ';

  @override
  String get noMessagesYet => 'まだメッセージはありません';

  @override
  String get startConversation => 'レンタルを予約して会話を始めましょう';

  @override
  String get messageHint => 'メッセージ...';

  @override
  String get report => '報告';

  @override
  String get blockUser => 'ブロック';

  @override
  String get startChatting => 'チャットを始めましょう';

  @override
  String get bookRental => 'レンタル予約';

  @override
  String get selectRentalDates => 'レンタル日を選択してください';

  @override
  String get priceSummary => '料金まとめ';

  @override
  String rentalFeeLabel(Object price, Object days) {
    return 'レンタル料 ($price x $days日)';
  }

  @override
  String get depositRefundable => 'デポジット（返金可能）';

  @override
  String get total => '合計';

  @override
  String get escrowProtected => 'エスクロー保護';

  @override
  String get escrowProtectedFull => 'エスクロー保護 - 返却時にデポジット返金';

  @override
  String get proceedToPayment => 'お支払いへ';

  @override
  String get reservationCreated => '予約が作成されました！貸主がまもなく確認します。';

  @override
  String get reservationFailed => '予約に失敗しました';

  @override
  String paymentNotConfigured(Object currency) {
    return '$currency決済はまだ設定されていません';
  }

  @override
  String get paymentVerificationPending => '支払いを受け付けました。まだ確認を完了できないため、この予約は確認待ちになります。';

  @override
  String get paymentVerificationFailed => '決済確認に失敗しました';

  @override
  String get chatWillBeAvailableAfterConfirmation => '予約が作成されました。確認後、予約詳細からチャットを開けます。';

  @override
  String get reservationCancelled => '予約をキャンセルしました';

  @override
  String get pickupConfirmed => '受け取りを確認しました';

  @override
  String get returnConfirmed => '返却を確認しました';

  @override
  String get reservationSettled => '予約を精算しました';

  @override
  String get reservationStatusPending => '予約待ち';

  @override
  String get reservationStatusPaid => '支払い済み';

  @override
  String get reservationStatusPickedUp => '受け取り済み';

  @override
  String get reservationStatusReturned => '返却済み';

  @override
  String get reservationStatusSettled => '精算済み';

  @override
  String get reservationStatusCancelled => 'キャンセル済み';

  @override
  String get reservationStatusDisputed => '異議申し立て中';

  @override
  String get reservationStatusResolved => '解決済み';

  @override
  String get disputeOpened => '異議申し立てを開始しました';

  @override
  String get confirmPickup => '受け取り確認';

  @override
  String get cancelAndRefund => 'キャンセルして返金';

  @override
  String get confirmReturn => '返却確認';

  @override
  String get settleDeposit => '保証金を精算';

  @override
  String get confirmRefundMessage => '予約をキャンセルして返金を申請します。続行しますか？';

  @override
  String get confirmSettlementMessage => 'デポジットを返金し、予約を終了します。続行しますか？';

  @override
  String get openDispute => '異議申し立て';

  @override
  String get openChat => 'チャットを開く';

  @override
  String get reservationId => '予約ID';

  @override
  String get paymentId => '決済ID';

  @override
  String get disputeReason => '異議申し立て理由';

  @override
  String get describeIssue => '問題を説明してください';

  @override
  String get bookNow => '今すぐ予約';

  @override
  String get perDay => '/ 日';

  @override
  String dayCount(num count) {
    return '$count日';
  }

  @override
  String get searchHint => 'アイテム、コンサート、アーティスト検索...';

  @override
  String get selectCategoryOrSearch => 'カテゴリを選択するか検索して\nレンタル品を見つけましょう';

  @override
  String get noItemsInCategory => 'このカテゴリにアイテムがありません';

  @override
  String get couldNotLoadItems => 'アイテムを読み込めませんでした';

  @override
  String get couldNotLoadConcerts => 'コンサートを読み込めませんでした';

  @override
  String get couldNotLoadMessages => 'メッセージを読み込めませんでした';

  @override
  String get noUpcomingConcerts => '今後のコンサートはありません。\nまた後でチェックしてください！';

  @override
  String get registerItem => 'アイテム登録';

  @override
  String get concert => 'コンサート';

  @override
  String get selectConcert => 'コンサートを選択';

  @override
  String get category => 'カテゴリ';

  @override
  String get title => 'タイトル';

  @override
  String get description => '説明';

  @override
  String get condition => '状態';

  @override
  String get dailyPrice => '日額料金';

  @override
  String get deposit => 'デポジット';

  @override
  String depositAmount(Object amount) {
    return 'デポジット: $amount';
  }

  @override
  String get pickupMethod => '受取方法';

  @override
  String get availability => '利用可能期間';

  @override
  String get selectAvailability => '利用可能期間を選択';

  @override
  String get pickupLocation => '受取場所';

  @override
  String get pickupLocationHint => '例: KSPO Dome 2番ゲート';

  @override
  String get register => '登録';

  @override
  String get photosRequired => '写真は最低2枚必要です';

  @override
  String get fillAllFields => 'すべての必須項目を入力してください';

  @override
  String get validNumbers => '価格とデポジットに有効な数字を入力してください';

  @override
  String get settings => '設定';

  @override
  String get myRentals => 'マイレンタル';

  @override
  String get reviews => 'レビュー';

  @override
  String get help => 'ヘルプ';

  @override
  String get privacy => 'プライバシーポリシー';

  @override
  String get lentOut => '貸出中';

  @override
  String get borrowed => '借りたもの';

  @override
  String get notLoggedIn => 'ログインしていません';

  @override
  String get sendFailed => '送信に失敗しました';

  @override
  String get errorLoadingMessages => 'メッセージの読み込みに失敗';

  @override
  String get continueWithApple => 'Appleで続ける';

  @override
  String get continueWithGoogle => 'Googleで続ける';

  @override
  String get appleSignInFailed => 'Appleログイン失敗';

  @override
  String get googleSignInFailed => 'Googleログイン失敗';

  @override
  String errorPrefix(Object message) {
    return 'エラー: $message';
  }

  @override
  String get countryKorea => '韓国';

  @override
  String get countryIndonesia => 'インドネシア';

  @override
  String get countryJapan => '日本';

  @override
  String get countryUS => 'アメリカ';

  @override
  String get btVerified => 'BT認証済み';

  @override
  String gradeLabel(Object grade) {
    return 'グレード $grade';
  }

  @override
  String get pickup => '受取';

  @override
  String get available => '利用可能';

  @override
  String get photos => '写真';

  @override
  String photosCounter(Object count) {
    return '$count/10（最低2枚）';
  }

  @override
  String get cover => 'カバー';

  @override
  String get add => '追加';

  @override
  String get titleHint => '例: BTS公式ペンライト Ver.4';

  @override
  String get descriptionHint => '状態、付属品などを説明してください...';

  @override
  String get conditionS => '新品同様';

  @override
  String get conditionSDesc => '使用感なし';

  @override
  String get conditionA => '非常に良い';

  @override
  String get conditionADesc => 'わずかな使用感';

  @override
  String get conditionB => '良い';

  @override
  String get conditionBDesc => '使用感あるが機能に問題なし';

  @override
  String get conditionC => '普通';

  @override
  String get conditionCDesc => 'かなりの使用感';

  @override
  String get categoryAll => 'すべて';

  @override
  String get categoryLightstick => 'ペンライト';

  @override
  String get categoryPhone => 'スマホ';

  @override
  String get categoryCamera => 'カメラ';

  @override
  String get categorySlogan => 'スローガン';

  @override
  String get categoryCostume => '衣装';

  @override
  String get categoryOther => 'その他';

  @override
  String get logOut => 'ログアウト';

  @override
  String get errorLoadingProfile => 'プロフィールの読み込みに失敗';

  @override
  String get guest => 'ゲスト';

  @override
  String get preferences => '設定';

  @override
  String get language => '言語';

  @override
  String get currency => '通貨';

  @override
  String get region => '地域';

  @override
  String get notifications => '通知';

  @override
  String get pushNotifications => 'プッシュ通知';

  @override
  String get chatNotifications => 'チャット通知';

  @override
  String get account => 'アカウント';

  @override
  String get exportMyData => 'データをエクスポート';

  @override
  String get downloadAsJson => 'JSONでダウンロード';

  @override
  String get deleteAccount => 'アカウント削除';

  @override
  String get deleteAccountMessage => 'アカウントとすべてのデータが完全に削除されます。元に戻すことはできません。';

  @override
  String get delete => '削除';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String appVersion(Object version) {
    return 'dol-pin v$version';
  }

  @override
  String get deleteAccountFailed => 'アカウント削除に失敗';

  @override
  String get langKorean => '韓国語';

  @override
  String get langEnglish => '英語';

  @override
  String get langIndonesian => 'インドネシア語';

  @override
  String get langJapanese => '日本語';

  @override
  String get currencyKRW => '韓国ウォン (₩)';

  @override
  String get currencyIDR => 'インドネシアルピア (Rp)';

  @override
  String get currencyJPY => '日本円 (¥)';

  @override
  String get currencyUSD => '米ドル (\$)';

  @override
  String get asLender => '貸出';

  @override
  String get asBorrower => 'レンタル';

  @override
  String get pleaseLogIn => 'ログインしてください';

  @override
  String get noItemsRegistered => 'まだアイテムが登録されていません。\n+を押して最初のアイテムを登録しましょう！';

  @override
  String get noReservationsYet => 'まだ予約がありません。\nアイテムを探して始めましょう！';

  @override
  String reportTitle(Object name) {
    return '$nameを報告';
  }

  @override
  String get selectReason => '理由を選択してください：';

  @override
  String get reasonScam => '詐欺';

  @override
  String get reasonCounterfeit => '偽造品';

  @override
  String get reasonInappropriate => '不適切なコンテンツ';

  @override
  String get reasonOther => 'その他';

  @override
  String get additionalDetails => '追加情報（任意）';

  @override
  String get powerLender => 'パワー貸主';

  @override
  String get regularLender => 'レギュラー貸主';

  @override
  String get newMember => '新規メンバー';

  @override
  String get userBlocked => 'ユーザーをブロックしました';

  @override
  String get userBlockFailed => 'ブロックに失敗しました';

  @override
  String get reportSubmitted => '報告が送信されました';

  @override
  String get reportFailed => '報告の送信に失敗しました';

  @override
  String get datesOutsideAvailability => '選択した日付はアイテムの利用可能期間外です';

  @override
  String get retry => '再試行';

  @override
  String get pickupDirect => '直接受取';

  @override
  String get pickupDelivery => '配送';

  @override
  String get pickupBoth => '両方';

  @override
  String get somethingWentWrong => '問題が発生しました';

  @override
  String get tryAgain => 'もう一度試す';

  @override
  String get bluetoothNotAvailable => 'Bluetoothが利用できません';

  @override
  String get noLightsticksFound => '近くにペンライトが見つかりません';

  @override
  String get selectYourLightstick => 'ペンライトを選択してください';

  @override
  String get scanning => 'スキャン中...';

  @override
  String get verifyLightstick => 'ペンライト認証';

  @override
  String get autoTagging => '自動タグ付け中...';

  @override
  String get timeJustNow => 'たった今';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes分前';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours時間前';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days日前';
  }

  @override
  String get pricePositiveRequired => '価格とデポジットは0より大きくなければなりません';

  @override
  String get share => '共有';

  @override
  String get linkCopied => 'リンクをコピーしました！';

  @override
  String get shareItem => 'アイテムを共有';

  @override
  String checkOutThisItem(Object title, Object price) {
    return 'dol-pinでこのアイテムをチェック！ $title - $price/日';
  }

  @override
  String shareConcert(Object title) {
    return 'dol-pinでこのコンサートをチェック！ $title';
  }

  @override
  String otpRateLimit(int seconds) {
    return 'リクエストが多すぎます。$seconds秒後にもう一度お試しください。';
  }
}
