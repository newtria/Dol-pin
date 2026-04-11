// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '돌핀';

  @override
  String get home => '홈';

  @override
  String get explore => '탐색';

  @override
  String get chat => '채팅';

  @override
  String get profile => 'my 돌핀';

  @override
  String get upcomingConcerts => '다가오는 콘서트';

  @override
  String get trendingItems => '인기 아이템';

  @override
  String get nearbyItems => '내 근처';

  @override
  String get login => '로그인';

  @override
  String get signup => '회원가입';

  @override
  String get comingSoon => '준비 중';

  @override
  String get pinItem => '핀하기';

  @override
  String get myPins => '내 핀';

  @override
  String get tagline => '콘서트, 한 번의 탭으로.\n안전하게. 빠르게. 가까이서.';

  @override
  String get continueWithPhone => '전화번호로 계속하기';

  @override
  String get phoneHint => '전화번호 (+82...)';

  @override
  String get invalidPhoneFormat => '올바른 전화번호를 입력하세요 (예: +821012345678)';

  @override
  String get or => '또는';

  @override
  String get termsNotice => '계속하면 이용약관에 동의하는 것입니다';

  @override
  String get verify => '인증하기';

  @override
  String get enterVerificationCode => '인증번호를 입력하세요';

  @override
  String sentTo(Object phone) {
    return '$phone(으)로 전송됨';
  }

  @override
  String get invalidCode => '잘못된 코드입니다. 다시 시도해주세요.';

  @override
  String get resendCode => '코드 재전송';

  @override
  String get codeResent => '코드가 재전송되었습니다';

  @override
  String get createProfile => '프로필 만들기';

  @override
  String get nickname => '닉네임';

  @override
  String get enterNickname => '닉네임을 입력하세요';

  @override
  String get country => '국가';

  @override
  String get favoriteGroups => '최애 그룹 (선택)';

  @override
  String get typeAndEnter => '입력 후 엔터를 누르세요';

  @override
  String get getStarted => '시작하기';

  @override
  String get messages => '메시지';

  @override
  String get noMessagesYet => '아직 메시지가 없습니다';

  @override
  String get startConversation => '대여를 예약하면 대화가 시작됩니다';

  @override
  String get messageHint => '메시지...';

  @override
  String get report => '신고하기';

  @override
  String get blockUser => '차단하기';

  @override
  String get startChatting => '대화를 시작하세요';

  @override
  String get bookRental => '대여 예약';

  @override
  String get selectRentalDates => '대여 날짜를 선택하세요';

  @override
  String get priceSummary => '가격 요약';

  @override
  String rentalFeeLabel(Object price, Object days) {
    return '대여비 ($price x $days일)';
  }

  @override
  String get depositRefundable => '보증금 (환불 가능)';

  @override
  String get total => '합계';

  @override
  String get escrowProtected => '에스크로 보호';

  @override
  String get escrowProtectedFull => '에스크로 보호 - 반납 시 보증금 환불';

  @override
  String get proceedToPayment => '결제하기';

  @override
  String get reservationCreated => '예약이 생성되었습니다! 대여자가 곧 확인할 거예요.';

  @override
  String get reservationFailed => '예약 실패';

  @override
  String get bookNow => '지금 예약';

  @override
  String get perDay => '/ 일';

  @override
  String dayCount(num count) {
    return '$count일';
  }

  @override
  String get searchHint => '아이템, 콘서트, 아티스트 검색...';

  @override
  String get selectCategoryOrSearch => '카테고리를 선택하거나 검색해서\n대여 물건을 찾아보세요';

  @override
  String get noItemsInCategory => '이 카테고리에 물건이 없습니다';

  @override
  String get couldNotLoadItems => '물건을 불러올 수 없습니다';

  @override
  String get couldNotLoadConcerts => '콘서트를 불러올 수 없습니다';

  @override
  String get couldNotLoadMessages => '메시지를 불러올 수 없습니다';

  @override
  String get noUpcomingConcerts => '다가오는 콘서트가 없습니다.\n나중에 다시 확인해주세요!';

  @override
  String get registerItem => '물건 등록';

  @override
  String get category => '카테고리';

  @override
  String get title => '제목';

  @override
  String get description => '설명';

  @override
  String get condition => '상태';

  @override
  String get dailyPrice => '일일 대여비';

  @override
  String get deposit => '보증금';

  @override
  String depositAmount(Object amount) {
    return '보증금: $amount';
  }

  @override
  String get pickupMethod => '수령 방법';

  @override
  String get register => '등록하기';

  @override
  String get photosRequired => '최소 2장의 사진이 필요합니다';

  @override
  String get fillAllFields => '모든 필수 항목을 입력해주세요';

  @override
  String get validNumbers => '가격과 보증금에 올바른 숫자를 입력해주세요';

  @override
  String get settings => '설정';

  @override
  String get myRentals => '내 대여';

  @override
  String get reviews => '리뷰';

  @override
  String get help => '도움말';

  @override
  String get privacy => '개인정보처리방침';

  @override
  String get lentOut => '빌려준 것';

  @override
  String get borrowed => '빌린 것';

  @override
  String get notLoggedIn => '로그인 필요';

  @override
  String get sendFailed => '전송 실패';

  @override
  String get errorLoadingMessages => '메시지 로딩 오류';

  @override
  String get continueWithApple => 'Apple로 계속하기';

  @override
  String get continueWithGoogle => 'Google로 계속하기';

  @override
  String get appleSignInFailed => 'Apple 로그인 실패';

  @override
  String get googleSignInFailed => 'Google 로그인 실패';

  @override
  String errorPrefix(Object message) {
    return '오류: $message';
  }

  @override
  String get countryKorea => '한국';

  @override
  String get countryIndonesia => '인도네시아';

  @override
  String get countryJapan => '일본';

  @override
  String get countryUS => '미국';

  @override
  String get btVerified => 'BT 인증';

  @override
  String gradeLabel(Object grade) {
    return '등급 $grade';
  }

  @override
  String get pickup => '수령';

  @override
  String get available => '이용 가능';

  @override
  String get photos => '사진';

  @override
  String photosCounter(Object count) {
    return '$count/10 (최소 2장)';
  }

  @override
  String get cover => '대표';

  @override
  String get add => '추가';

  @override
  String get titleHint => '예: BTS 공식 응원봉 Ver.4';

  @override
  String get descriptionHint => '상태, 포함 구성품 등을 설명해주세요...';

  @override
  String get conditionS => '새 것 같은';

  @override
  String get conditionSDesc => '사용 흔적 없음';

  @override
  String get conditionA => '매우 양호';

  @override
  String get conditionADesc => '경미한 사용 흔적';

  @override
  String get conditionB => '양호';

  @override
  String get conditionBDesc => '사용감 있으나 기능 정상';

  @override
  String get conditionC => '보통';

  @override
  String get conditionCDesc => '상당한 사용감';

  @override
  String get categoryAll => '전체';

  @override
  String get categoryLightstick => '응원봉';

  @override
  String get categoryPhone => '폰';

  @override
  String get categoryCamera => '카메라';

  @override
  String get categorySlogan => '슬로건';

  @override
  String get categoryCostume => '의상';

  @override
  String get categoryOther => '기타';

  @override
  String get logOut => '로그아웃';

  @override
  String get errorLoadingProfile => '프로필 로딩 오류';

  @override
  String get guest => '게스트';

  @override
  String get preferences => '설정';

  @override
  String get language => '언어';

  @override
  String get currency => '통화';

  @override
  String get region => '지역';

  @override
  String get notifications => '알림';

  @override
  String get pushNotifications => '푸시 알림';

  @override
  String get chatNotifications => '채팅 알림';

  @override
  String get account => '계정';

  @override
  String get exportMyData => '내 데이터 내보내기';

  @override
  String get downloadAsJson => 'JSON으로 다운로드';

  @override
  String get deleteAccount => '계정 삭제';

  @override
  String get deleteAccountMessage => '계정과 모든 데이터가 영구 삭제됩니다. 되돌릴 수 없습니다.';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String appVersion(Object version) {
    return '돌핀 v$version';
  }

  @override
  String get deleteAccountFailed => '계정 삭제 실패';

  @override
  String get langKorean => '한국어';

  @override
  String get langEnglish => '영어';

  @override
  String get langIndonesian => '인도네시아어';

  @override
  String get langJapanese => '일본어';

  @override
  String get currencyKRW => '대한민국 원 (₩)';

  @override
  String get currencyIDR => '인도네시아 루피아 (Rp)';

  @override
  String get currencyJPY => '일본 엔 (¥)';

  @override
  String get currencyUSD => '미국 달러 (\$)';

  @override
  String get asLender => '빌려준 것';

  @override
  String get asBorrower => '빌린 것';

  @override
  String get pleaseLogIn => '로그인 해주세요';

  @override
  String get noItemsRegistered => '등록된 물건이 없습니다.\n+ 버튼을 눌러 첫 물건을 등록하세요!';

  @override
  String get noReservationsYet => '아직 예약이 없습니다.\n탐색에서 물건을 찾아보세요!';

  @override
  String reportTitle(Object name) {
    return '$name 신고';
  }

  @override
  String get selectReason => '사유를 선택하세요:';

  @override
  String get reasonScam => '사기 / 기만';

  @override
  String get reasonCounterfeit => '위조품';

  @override
  String get reasonInappropriate => '부적절한 콘텐츠';

  @override
  String get reasonOther => '기타';

  @override
  String get additionalDetails => '추가 설명 (선택)';

  @override
  String get powerLender => '파워 대여자';

  @override
  String get regularLender => '일반 대여자';

  @override
  String get newMember => '신규 회원';

  @override
  String get userBlocked => '사용자가 차단되었습니다';

  @override
  String get userBlockFailed => '차단 실패';

  @override
  String get reportSubmitted => '신고가 접수되었습니다';

  @override
  String get reportFailed => '신고 접수 실패';

  @override
  String get datesOutsideAvailability => '선택한 날짜가 물건 이용 가능 기간을 벗어납니다';

  @override
  String get retry => '다시 시도';

  @override
  String get pickupDirect => '직거래';

  @override
  String get pickupDelivery => '택배';

  @override
  String get pickupBoth => '둘 다';

  @override
  String get somethingWentWrong => '문제가 발생했습니다';

  @override
  String get tryAgain => '다시 시도';

  @override
  String get bluetoothNotAvailable => '블루투스를 사용할 수 없습니다';

  @override
  String get noLightsticksFound => '근처에 응원봉이 없습니다';

  @override
  String get selectYourLightstick => '응원봉을 선택하세요';

  @override
  String get scanning => '스캔 중...';

  @override
  String get verifyLightstick => '응원봉 인증';

  @override
  String get autoTagging => '자동 태그 중...';

  @override
  String get timeJustNow => '방금';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes분 전';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours시간 전';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days일 전';
  }

  @override
  String get pricePositiveRequired => '가격과 보증금은 0보다 커야 합니다';

  @override
  String get share => '공유';

  @override
  String get linkCopied => '링크가 복사되었습니다';

  @override
  String get shareItem => '아이템 공유';

  @override
  String checkOutThisItem(Object title, Object price) {
    return '돌핀에서 이 아이템을 확인해보세요! $title - $price/일';
  }

  @override
  String shareConcert(Object title) {
    return '돌핀에서 이 콘서트를 확인해보세요! $title';
  }

  @override
  String otpRateLimit(int seconds) {
    return '요청이 너무 많습니다. $seconds초 후 다시 시도해주세요.';
  }
}
