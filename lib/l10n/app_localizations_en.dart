// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'dol-pin';

  @override
  String get home => 'Home';

  @override
  String get explore => 'Explore';

  @override
  String get chat => 'Chat';

  @override
  String get profile => 'my dol-pin';

  @override
  String get upcomingConcerts => 'Upcoming Concerts';

  @override
  String get trendingItems => 'Trending Items';

  @override
  String get nearbyItems => 'Nearby Items';

  @override
  String get login => 'Log in';

  @override
  String get signup => 'Sign up';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get pinItem => 'Pin it';

  @override
  String get myPins => 'My Pins';

  @override
  String get tagline => 'Your concert, one tap away.\nSafe. Fast. Local.';

  @override
  String get continueWithPhone => 'Continue with Phone';

  @override
  String get phoneHint => 'Phone number (+82...)';

  @override
  String get invalidPhoneFormat => 'Please enter a valid phone number (e.g. +821012345678)';

  @override
  String get or => 'or';

  @override
  String get termsNotice => 'By continuing, you agree to our Terms of Service';

  @override
  String get verify => 'Verify';

  @override
  String get enterVerificationCode => 'Enter verification code';

  @override
  String sentTo(Object phone) {
    return 'Sent to $phone';
  }

  @override
  String get invalidCode => 'Invalid code. Please try again.';

  @override
  String get resendCode => 'Resend code';

  @override
  String get codeResent => 'Code resent';

  @override
  String get createProfile => 'Create Profile';

  @override
  String get nickname => 'Nickname';

  @override
  String get enterNickname => 'Enter nickname';

  @override
  String get country => 'Country';

  @override
  String get favoriteGroups => 'Favorite Groups (optional)';

  @override
  String get typeAndEnter => 'Type and press enter';

  @override
  String get getStarted => 'Get Started';

  @override
  String get messages => 'Messages';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get startConversation => 'Start a conversation by booking a rental';

  @override
  String get messageHint => 'Message...';

  @override
  String get report => 'Report';

  @override
  String get blockUser => 'Block User';

  @override
  String get startChatting => 'Start chatting';

  @override
  String get bookRental => 'Book Rental';

  @override
  String get selectRentalDates => 'Select rental dates';

  @override
  String get priceSummary => 'Price Summary';

  @override
  String rentalFeeLabel(Object price, Object days) {
    return 'Rental fee ($price x $days days)';
  }

  @override
  String get depositRefundable => 'Deposit (refundable)';

  @override
  String get total => 'Total';

  @override
  String get escrowProtected => 'Escrow Protected';

  @override
  String get escrowProtectedFull => 'Escrow Protected - Deposit refunded on return';

  @override
  String get proceedToPayment => 'Proceed to Payment';

  @override
  String get reservationCreated => 'Reservation created! The lender will confirm soon.';

  @override
  String get reservationFailed => 'Reservation failed';

  @override
  String paymentNotConfigured(Object currency) {
    return '$currency payments are not configured yet';
  }

  @override
  String get paymentVerificationPending => 'Payment was received. We could not confirm it yet, so this reservation is waiting for verification.';

  @override
  String get paymentVerificationFailed => 'Payment verification failed';

  @override
  String get chatWillBeAvailableAfterConfirmation => 'Reservation was created. Chat will be available from the reservation detail after confirmation.';

  @override
  String get reservationCancelled => 'Reservation cancelled';

  @override
  String get pickupConfirmed => 'Pickup confirmed';

  @override
  String get returnConfirmed => 'Return confirmed';

  @override
  String get reservationSettled => 'Reservation settled';

  @override
  String get reservationStatusPending => 'Pending';

  @override
  String get reservationStatusPaid => 'Paid';

  @override
  String get reservationStatusPickedUp => 'Picked up';

  @override
  String get reservationStatusReturned => 'Returned';

  @override
  String get reservationStatusSettled => 'Settled';

  @override
  String get reservationStatusCancelled => 'Cancelled';

  @override
  String get reservationStatusDisputed => 'Disputed';

  @override
  String get reservationStatusResolved => 'Resolved';

  @override
  String get disputeOpened => 'Dispute opened';

  @override
  String get confirmPickup => 'Confirm pickup';

  @override
  String get cancelAndRefund => 'Cancel and refund';

  @override
  String get confirmReturn => 'Confirm return';

  @override
  String get settleDeposit => 'Settle deposit';

  @override
  String get confirmRefundMessage => 'This will cancel the reservation and request a refund. Continue?';

  @override
  String get confirmSettlementMessage => 'This will refund the deposit and close the reservation. Continue?';

  @override
  String get openDispute => 'Open dispute';

  @override
  String get openChat => 'Open chat';

  @override
  String get reservationId => 'Reservation ID';

  @override
  String get paymentId => 'Payment ID';

  @override
  String get disputeReason => 'Dispute reason';

  @override
  String get describeIssue => 'Describe the issue';

  @override
  String get bookNow => 'Book Now';

  @override
  String get perDay => '/ day';

  @override
  String dayCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count day$_temp0';
  }

  @override
  String get searchHint => 'Search items, concerts, artists...';

  @override
  String get selectCategoryOrSearch => 'Select a category or search\nto find rentals';

  @override
  String get noItemsInCategory => 'No items found in this category';

  @override
  String get couldNotLoadItems => 'Could not load items';

  @override
  String get couldNotLoadConcerts => 'Could not load concerts';

  @override
  String get couldNotLoadMessages => 'Could not load messages';

  @override
  String get noUpcomingConcerts => 'No upcoming concerts found.\nCheck back later!';

  @override
  String get registerItem => 'Register Item';

  @override
  String get concert => 'Concert';

  @override
  String get selectConcert => 'Select concert';

  @override
  String get category => 'Category';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get condition => 'Condition';

  @override
  String get dailyPrice => 'Daily Price';

  @override
  String get deposit => 'Deposit';

  @override
  String depositAmount(Object amount) {
    return 'Deposit: $amount';
  }

  @override
  String get pickupMethod => 'Pickup Method';

  @override
  String get availability => 'Availability';

  @override
  String get selectAvailability => 'Select availability';

  @override
  String get pickupLocation => 'Pickup location';

  @override
  String get pickupLocationHint => 'e.g., KSPO Dome Gate 2';

  @override
  String get register => 'Register';

  @override
  String get photosRequired => 'At least 2 photos required';

  @override
  String get fillAllFields => 'Please fill all required fields';

  @override
  String get validNumbers => 'Please enter valid numbers for price and deposit';

  @override
  String get settings => 'Settings';

  @override
  String get myRentals => 'My Rentals';

  @override
  String get reviews => 'Reviews';

  @override
  String get help => 'Help & Support';

  @override
  String get privacy => 'Privacy Policy';

  @override
  String get lentOut => 'Lent Out';

  @override
  String get borrowed => 'Borrowed';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get sendFailed => 'Failed to send';

  @override
  String get errorLoadingMessages => 'Error loading messages';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get appleSignInFailed => 'Apple sign in failed';

  @override
  String get googleSignInFailed => 'Google sign in failed';

  @override
  String errorPrefix(Object message) {
    return 'Error: $message';
  }

  @override
  String get countryKorea => 'Korea';

  @override
  String get countryIndonesia => 'Indonesia';

  @override
  String get countryJapan => 'Japan';

  @override
  String get countryUS => 'United States';

  @override
  String get btVerified => 'BT Verified';

  @override
  String gradeLabel(Object grade) {
    return 'Grade $grade';
  }

  @override
  String get pickup => 'Pickup';

  @override
  String get available => 'Available';

  @override
  String get photos => 'Photos';

  @override
  String photosCounter(Object count) {
    return '$count/10 (min 2)';
  }

  @override
  String get cover => 'Cover';

  @override
  String get add => 'Add';

  @override
  String get titleHint => 'e.g., BTS Official Lightstick Ver.4';

  @override
  String get descriptionHint => 'Describe the condition, accessories included...';

  @override
  String get conditionS => 'Like New';

  @override
  String get conditionSDesc => 'No signs of use';

  @override
  String get conditionA => 'Excellent';

  @override
  String get conditionADesc => 'Minor signs of use';

  @override
  String get conditionB => 'Good';

  @override
  String get conditionBDesc => 'Visible wear but functional';

  @override
  String get conditionC => 'Fair';

  @override
  String get conditionCDesc => 'Significant wear';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryLightstick => 'Lightstick';

  @override
  String get categoryPhone => 'Phone';

  @override
  String get categoryCamera => 'Camera';

  @override
  String get categorySlogan => 'Slogan';

  @override
  String get categoryCostume => 'Costume';

  @override
  String get categoryOther => 'Other';

  @override
  String get logOut => 'Log Out';

  @override
  String get errorLoadingProfile => 'Error loading profile';

  @override
  String get guest => 'Guest';

  @override
  String get preferences => 'Preferences';

  @override
  String get language => 'Language';

  @override
  String get currency => 'Currency';

  @override
  String get region => 'Region';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get chatNotifications => 'Chat Notifications';

  @override
  String get account => 'Account';

  @override
  String get exportMyData => 'Export My Data';

  @override
  String get downloadAsJson => 'Download as JSON';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountMessage => 'This will permanently delete your account and all data. This cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String appVersion(Object version) {
    return 'dol-pin v$version';
  }

  @override
  String get deleteAccountFailed => 'Failed to delete account';

  @override
  String get langKorean => 'Korean';

  @override
  String get langEnglish => 'English';

  @override
  String get langIndonesian => 'Indonesian';

  @override
  String get langJapanese => 'Japanese';

  @override
  String get currencyKRW => 'Korean Won (₩)';

  @override
  String get currencyIDR => 'Indonesian Rupiah (Rp)';

  @override
  String get currencyJPY => 'Japanese Yen (¥)';

  @override
  String get currencyUSD => 'US Dollar (\$)';

  @override
  String get asLender => 'As Lender';

  @override
  String get asBorrower => 'As Borrower';

  @override
  String get pleaseLogIn => 'Please log in';

  @override
  String get noItemsRegistered => 'No items registered yet.\nTap + to register your first item!';

  @override
  String get noReservationsYet => 'No reservations yet.\nExplore items to get started!';

  @override
  String reportTitle(Object name) {
    return 'Report $name';
  }

  @override
  String get selectReason => 'Select a reason:';

  @override
  String get reasonScam => 'Scam / Fraud';

  @override
  String get reasonCounterfeit => 'Counterfeit Item';

  @override
  String get reasonInappropriate => 'Inappropriate Content';

  @override
  String get reasonOther => 'Other';

  @override
  String get additionalDetails => 'Additional details (optional)';

  @override
  String get powerLender => 'Power Lender';

  @override
  String get regularLender => 'Regular Lender';

  @override
  String get newMember => 'New Member';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get userBlockFailed => 'Failed to block user';

  @override
  String get reportSubmitted => 'Report submitted';

  @override
  String get reportFailed => 'Failed to submit report';

  @override
  String get datesOutsideAvailability => 'Selected dates are outside the item\'s availability window';

  @override
  String get retry => 'Retry';

  @override
  String get pickupDirect => 'Direct Meetup';

  @override
  String get pickupDelivery => 'Delivery';

  @override
  String get pickupBoth => 'Both';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try again';

  @override
  String get bluetoothNotAvailable => 'Bluetooth is not available';

  @override
  String get noLightsticksFound => 'No lightsticks found nearby';

  @override
  String get selectYourLightstick => 'Select your lightstick';

  @override
  String get scanning => 'Scanning...';

  @override
  String get verifyLightstick => 'Verify Lightstick';

  @override
  String get autoTagging => 'Auto-tagging...';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get pricePositiveRequired => 'Price and deposit must be greater than 0';

  @override
  String get share => 'Share';

  @override
  String get linkCopied => 'Link copied!';

  @override
  String get shareItem => 'Share item';

  @override
  String checkOutThisItem(Object title, Object price) {
    return 'Check out this item on dol-pin! $title - $price/day';
  }

  @override
  String shareConcert(Object title) {
    return 'Check out this concert on dol-pin! $title';
  }

  @override
  String otpRateLimit(int seconds) {
    return 'Too many requests. Please try again in $seconds seconds.';
  }
}
