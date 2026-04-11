import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
    Locale('ja'),
    Locale('ko')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'dol-pin'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'my dol-pin'**
  String get profile;

  /// No description provided for @upcomingConcerts.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Concerts'**
  String get upcomingConcerts;

  /// No description provided for @trendingItems.
  ///
  /// In en, this message translates to:
  /// **'Trending Items'**
  String get trendingItems;

  /// No description provided for @nearbyItems.
  ///
  /// In en, this message translates to:
  /// **'Nearby Items'**
  String get nearbyItems;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signup;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @pinItem.
  ///
  /// In en, this message translates to:
  /// **'Pin it'**
  String get pinItem;

  /// No description provided for @myPins.
  ///
  /// In en, this message translates to:
  /// **'My Pins'**
  String get myPins;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your concert, one tap away.\nSafe. Fast. Local.'**
  String get tagline;

  /// No description provided for @continueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone'**
  String get continueWithPhone;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number (+82...)'**
  String get phoneHint;

  /// No description provided for @invalidPhoneFormat.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number (e.g. +821012345678)'**
  String get invalidPhoneFormat;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @termsNotice.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our Terms of Service'**
  String get termsNotice;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get enterVerificationCode;

  /// No description provided for @sentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {phone}'**
  String sentTo(Object phone);

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Please try again.'**
  String get invalidCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @codeResent.
  ///
  /// In en, this message translates to:
  /// **'Code resent'**
  String get codeResent;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfile;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @enterNickname.
  ///
  /// In en, this message translates to:
  /// **'Enter nickname'**
  String get enterNickname;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @favoriteGroups.
  ///
  /// In en, this message translates to:
  /// **'Favorite Groups (optional)'**
  String get favoriteGroups;

  /// No description provided for @typeAndEnter.
  ///
  /// In en, this message translates to:
  /// **'Type and press enter'**
  String get typeAndEnter;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation by booking a rental'**
  String get startConversation;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get messageHint;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get blockUser;

  /// No description provided for @startChatting.
  ///
  /// In en, this message translates to:
  /// **'Start chatting'**
  String get startChatting;

  /// No description provided for @bookRental.
  ///
  /// In en, this message translates to:
  /// **'Book Rental'**
  String get bookRental;

  /// No description provided for @selectRentalDates.
  ///
  /// In en, this message translates to:
  /// **'Select rental dates'**
  String get selectRentalDates;

  /// No description provided for @priceSummary.
  ///
  /// In en, this message translates to:
  /// **'Price Summary'**
  String get priceSummary;

  /// No description provided for @rentalFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Rental fee ({price} x {days} days)'**
  String rentalFeeLabel(Object price, Object days);

  /// No description provided for @depositRefundable.
  ///
  /// In en, this message translates to:
  /// **'Deposit (refundable)'**
  String get depositRefundable;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @escrowProtected.
  ///
  /// In en, this message translates to:
  /// **'Escrow Protected'**
  String get escrowProtected;

  /// No description provided for @escrowProtectedFull.
  ///
  /// In en, this message translates to:
  /// **'Escrow Protected - Deposit refunded on return'**
  String get escrowProtectedFull;

  /// No description provided for @proceedToPayment.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Payment'**
  String get proceedToPayment;

  /// No description provided for @reservationCreated.
  ///
  /// In en, this message translates to:
  /// **'Reservation created! The lender will confirm soon.'**
  String get reservationCreated;

  /// No description provided for @reservationFailed.
  ///
  /// In en, this message translates to:
  /// **'Reservation failed'**
  String get reservationFailed;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @perDay.
  ///
  /// In en, this message translates to:
  /// **'/ day'**
  String get perDay;

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} day{count, plural, =1{} other{s}}'**
  String dayCount(num count);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search items, concerts, artists...'**
  String get searchHint;

  /// No description provided for @selectCategoryOrSearch.
  ///
  /// In en, this message translates to:
  /// **'Select a category or search\nto find rentals'**
  String get selectCategoryOrSearch;

  /// No description provided for @noItemsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No items found in this category'**
  String get noItemsInCategory;

  /// No description provided for @couldNotLoadItems.
  ///
  /// In en, this message translates to:
  /// **'Could not load items'**
  String get couldNotLoadItems;

  /// No description provided for @couldNotLoadConcerts.
  ///
  /// In en, this message translates to:
  /// **'Could not load concerts'**
  String get couldNotLoadConcerts;

  /// No description provided for @couldNotLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Could not load messages'**
  String get couldNotLoadMessages;

  /// No description provided for @noUpcomingConcerts.
  ///
  /// In en, this message translates to:
  /// **'No upcoming concerts found.\nCheck back later!'**
  String get noUpcomingConcerts;

  /// No description provided for @registerItem.
  ///
  /// In en, this message translates to:
  /// **'Register Item'**
  String get registerItem;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @dailyPrice.
  ///
  /// In en, this message translates to:
  /// **'Daily Price'**
  String get dailyPrice;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @depositAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit: {amount}'**
  String depositAmount(Object amount);

  /// No description provided for @pickupMethod.
  ///
  /// In en, this message translates to:
  /// **'Pickup Method'**
  String get pickupMethod;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @photosRequired.
  ///
  /// In en, this message translates to:
  /// **'At least 2 photos required'**
  String get photosRequired;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields'**
  String get fillAllFields;

  /// No description provided for @validNumbers.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid numbers for price and deposit'**
  String get validNumbers;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @myRentals.
  ///
  /// In en, this message translates to:
  /// **'My Rentals'**
  String get myRentals;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get help;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy;

  /// No description provided for @lentOut.
  ///
  /// In en, this message translates to:
  /// **'Lent Out'**
  String get lentOut;

  /// No description provided for @borrowed.
  ///
  /// In en, this message translates to:
  /// **'Borrowed'**
  String get borrowed;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get sendFailed;

  /// No description provided for @errorLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Error loading messages'**
  String get errorLoadingMessages;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @appleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple sign in failed'**
  String get appleSignInFailed;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign in failed'**
  String get googleSignInFailed;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorPrefix(Object message);

  /// No description provided for @countryKorea.
  ///
  /// In en, this message translates to:
  /// **'Korea'**
  String get countryKorea;

  /// No description provided for @countryIndonesia.
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get countryIndonesia;

  /// No description provided for @countryJapan.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get countryJapan;

  /// No description provided for @countryUS.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get countryUS;

  /// No description provided for @btVerified.
  ///
  /// In en, this message translates to:
  /// **'BT Verified'**
  String get btVerified;

  /// No description provided for @gradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grade {grade}'**
  String gradeLabel(Object grade);

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @photosCounter.
  ///
  /// In en, this message translates to:
  /// **'{count}/10 (min 2)'**
  String photosCounter(Object count);

  /// No description provided for @cover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get cover;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., BTS Official Lightstick Ver.4'**
  String get titleHint;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the condition, accessories included...'**
  String get descriptionHint;

  /// No description provided for @conditionS.
  ///
  /// In en, this message translates to:
  /// **'Like New'**
  String get conditionS;

  /// No description provided for @conditionSDesc.
  ///
  /// In en, this message translates to:
  /// **'No signs of use'**
  String get conditionSDesc;

  /// No description provided for @conditionA.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get conditionA;

  /// No description provided for @conditionADesc.
  ///
  /// In en, this message translates to:
  /// **'Minor signs of use'**
  String get conditionADesc;

  /// No description provided for @conditionB.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get conditionB;

  /// No description provided for @conditionBDesc.
  ///
  /// In en, this message translates to:
  /// **'Visible wear but functional'**
  String get conditionBDesc;

  /// No description provided for @conditionC.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get conditionC;

  /// No description provided for @conditionCDesc.
  ///
  /// In en, this message translates to:
  /// **'Significant wear'**
  String get conditionCDesc;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @categoryLightstick.
  ///
  /// In en, this message translates to:
  /// **'Lightstick'**
  String get categoryLightstick;

  /// No description provided for @categoryPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get categoryPhone;

  /// No description provided for @categoryCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get categoryCamera;

  /// No description provided for @categorySlogan.
  ///
  /// In en, this message translates to:
  /// **'Slogan'**
  String get categorySlogan;

  /// No description provided for @categoryCostume.
  ///
  /// In en, this message translates to:
  /// **'Costume'**
  String get categoryCostume;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @errorLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error loading profile'**
  String get errorLoadingProfile;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @chatNotifications.
  ///
  /// In en, this message translates to:
  /// **'Chat Notifications'**
  String get chatNotifications;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @exportMyData.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get exportMyData;

  /// No description provided for @downloadAsJson.
  ///
  /// In en, this message translates to:
  /// **'Download as JSON'**
  String get downloadAsJson;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all data. This cannot be undone.'**
  String get deleteAccountMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'dol-pin v{version}'**
  String appVersion(Object version);

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get deleteAccountFailed;

  /// No description provided for @langKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get langKorean;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get langIndonesian;

  /// No description provided for @langJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get langJapanese;

  /// No description provided for @currencyKRW.
  ///
  /// In en, this message translates to:
  /// **'Korean Won (₩)'**
  String get currencyKRW;

  /// No description provided for @currencyIDR.
  ///
  /// In en, this message translates to:
  /// **'Indonesian Rupiah (Rp)'**
  String get currencyIDR;

  /// No description provided for @currencyJPY.
  ///
  /// In en, this message translates to:
  /// **'Japanese Yen (¥)'**
  String get currencyJPY;

  /// No description provided for @currencyUSD.
  ///
  /// In en, this message translates to:
  /// **'US Dollar (\$)'**
  String get currencyUSD;

  /// No description provided for @asLender.
  ///
  /// In en, this message translates to:
  /// **'As Lender'**
  String get asLender;

  /// No description provided for @asBorrower.
  ///
  /// In en, this message translates to:
  /// **'As Borrower'**
  String get asBorrower;

  /// No description provided for @pleaseLogIn.
  ///
  /// In en, this message translates to:
  /// **'Please log in'**
  String get pleaseLogIn;

  /// No description provided for @noItemsRegistered.
  ///
  /// In en, this message translates to:
  /// **'No items registered yet.\nTap + to register your first item!'**
  String get noItemsRegistered;

  /// No description provided for @noReservationsYet.
  ///
  /// In en, this message translates to:
  /// **'No reservations yet.\nExplore items to get started!'**
  String get noReservationsYet;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String reportTitle(Object name);

  /// No description provided for @selectReason.
  ///
  /// In en, this message translates to:
  /// **'Select a reason:'**
  String get selectReason;

  /// No description provided for @reasonScam.
  ///
  /// In en, this message translates to:
  /// **'Scam / Fraud'**
  String get reasonScam;

  /// No description provided for @reasonCounterfeit.
  ///
  /// In en, this message translates to:
  /// **'Counterfeit Item'**
  String get reasonCounterfeit;

  /// No description provided for @reasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate Content'**
  String get reasonInappropriate;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get additionalDetails;

  /// No description provided for @powerLender.
  ///
  /// In en, this message translates to:
  /// **'Power Lender'**
  String get powerLender;

  /// No description provided for @regularLender.
  ///
  /// In en, this message translates to:
  /// **'Regular Lender'**
  String get regularLender;

  /// No description provided for @newMember.
  ///
  /// In en, this message translates to:
  /// **'New Member'**
  String get newMember;

  /// No description provided for @userBlocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked'**
  String get userBlocked;

  /// No description provided for @userBlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to block user'**
  String get userBlockFailed;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get reportSubmitted;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report'**
  String get reportFailed;

  /// No description provided for @datesOutsideAvailability.
  ///
  /// In en, this message translates to:
  /// **'Selected dates are outside the item\'s availability window'**
  String get datesOutsideAvailability;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @pickupDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct Meetup'**
  String get pickupDirect;

  /// No description provided for @pickupDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get pickupDelivery;

  /// No description provided for @pickupBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get pickupBoth;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @bluetoothNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is not available'**
  String get bluetoothNotAvailable;

  /// No description provided for @noLightsticksFound.
  ///
  /// In en, this message translates to:
  /// **'No lightsticks found nearby'**
  String get noLightsticksFound;

  /// No description provided for @selectYourLightstick.
  ///
  /// In en, this message translates to:
  /// **'Select your lightstick'**
  String get selectYourLightstick;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @verifyLightstick.
  ///
  /// In en, this message translates to:
  /// **'Verify Lightstick'**
  String get verifyLightstick;

  /// No description provided for @autoTagging.
  ///
  /// In en, this message translates to:
  /// **'Auto-tagging...'**
  String get autoTagging;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeDaysAgo(int days);

  /// No description provided for @pricePositiveRequired.
  ///
  /// In en, this message translates to:
  /// **'Price and deposit must be greater than 0'**
  String get pricePositiveRequired;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied!'**
  String get linkCopied;

  /// No description provided for @shareItem.
  ///
  /// In en, this message translates to:
  /// **'Share item'**
  String get shareItem;

  /// No description provided for @checkOutThisItem.
  ///
  /// In en, this message translates to:
  /// **'Check out this item on dol-pin! {title} - {price}/day'**
  String checkOutThisItem(Object title, Object price);

  /// No description provided for @shareConcert.
  ///
  /// In en, this message translates to:
  /// **'Check out this concert on dol-pin! {title}'**
  String shareConcert(Object title);

  /// No description provided for @otpRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again in {seconds} seconds.'**
  String otpRateLimit(int seconds);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'id', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'id': return AppLocalizationsId();
    case 'ja': return AppLocalizationsJa();
    case 'ko': return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
