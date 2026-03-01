import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TINS CARS'**
  String get appTitle;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to TINS CARS'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @signUpLink.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpLink;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Up for TINS CARS'**
  String get registerTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get nameLabel;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// No description provided for @successRegister.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get successRegister;

  /// No description provided for @passengerMode.
  ///
  /// In en, this message translates to:
  /// **'Passenger Mode'**
  String get passengerMode;

  /// No description provided for @driverMode.
  ///
  /// In en, this message translates to:
  /// **'Driver Mode'**
  String get driverMode;

  /// No description provided for @whereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// No description provided for @searchDestination.
  ///
  /// In en, this message translates to:
  /// **'Search destination...'**
  String get searchDestination;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Select your service'**
  String get selectService;

  /// No description provided for @confirmRide.
  ///
  /// In en, this message translates to:
  /// **'Confirm Ride'**
  String get confirmRide;

  /// No description provided for @youAreOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get youAreOffline;

  /// No description provided for @goOnline.
  ///
  /// In en, this message translates to:
  /// **'Go Online'**
  String get goOnline;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get myTrips;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @switchToDriver.
  ///
  /// In en, this message translates to:
  /// **'Switch to Driver'**
  String get switchToDriver;

  /// No description provided for @switchToPassenger.
  ///
  /// In en, this message translates to:
  /// **'Switch to Passenger'**
  String get switchToPassenger;

  /// No description provided for @planYourTrip.
  ///
  /// In en, this message translates to:
  /// **'Plan your trip'**
  String get planYourTrip;

  /// No description provided for @whereAmI.
  ///
  /// In en, this message translates to:
  /// **'Where am I'**
  String get whereAmI;

  /// No description provided for @whereToDest.
  ///
  /// In en, this message translates to:
  /// **'Where to'**
  String get whereToDest;

  /// No description provided for @recentTrips.
  ///
  /// In en, this message translates to:
  /// **'Recent trips'**
  String get recentTrips;

  /// No description provided for @savedPlace.
  ///
  /// In en, this message translates to:
  /// **'Saved place'**
  String get savedPlace;

  /// No description provided for @frequentDestination.
  ///
  /// In en, this message translates to:
  /// **'Frequent destination'**
  String get frequentDestination;

  /// No description provided for @yourTripsHistory.
  ///
  /// In en, this message translates to:
  /// **'Your Trips (History)'**
  String get yourTripsHistory;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get accessDenied;

  /// No description provided for @requestPending.
  ///
  /// In en, this message translates to:
  /// **'Your request is under review.'**
  String get requestPending;

  /// No description provided for @onlineStatus.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get onlineStatus;

  /// No description provided for @offlineStatus.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get offlineStatus;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today;

  /// No description provided for @tripsCount.
  ///
  /// In en, this message translates to:
  /// **'TRIPS'**
  String get tripsCount;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @nameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated successfully'**
  String get nameUpdated;

  /// No description provided for @errorUpdating.
  ///
  /// In en, this message translates to:
  /// **'Error updating'**
  String get errorUpdating;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

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

  /// No description provided for @cancelReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us the reason'**
  String get cancelReasonTitle;

  /// No description provided for @cancelReasonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps us improve the service.'**
  String get cancelReasonSubtitle;

  /// No description provided for @cancelAreYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get cancelAreYouSure;

  /// No description provided for @cancelWarning.
  ///
  /// In en, this message translates to:
  /// **'If you cancel now, you might lose your current booking and affect your rating.'**
  String get cancelWarning;

  /// No description provided for @continueCancellation.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE WITH CANCELLATION'**
  String get continueCancellation;

  /// No description provided for @keepTrip.
  ///
  /// In en, this message translates to:
  /// **'KEEP TRIP'**
  String get keepTrip;

  /// No description provided for @confirmCancellation.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM CANCELLATION'**
  String get confirmCancellation;

  /// No description provided for @reasonNoLongerNeed.
  ///
  /// In en, this message translates to:
  /// **'I no longer need the trip'**
  String get reasonNoLongerNeed;

  /// No description provided for @reasonDriverTooFar.
  ///
  /// In en, this message translates to:
  /// **'The driver is too far away'**
  String get reasonDriverTooFar;

  /// No description provided for @reasonErrorRequesting.
  ///
  /// In en, this message translates to:
  /// **'Error while requesting the trip'**
  String get reasonErrorRequesting;

  /// No description provided for @reasonOrderedAnother.
  ///
  /// In en, this message translates to:
  /// **'Ordered another vehicle'**
  String get reasonOrderedAnother;

  /// No description provided for @reasonPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal reasons'**
  String get reasonPersonal;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @reasonOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Write the reason here...'**
  String get reasonOtherHint;

  /// No description provided for @noDriverAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'NO DRIVER AVAILABLE'**
  String get noDriverAvailableTitle;

  /// No description provided for @noDriverAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find an available driver at this moment.'**
  String get noDriverAvailableMessage;

  /// No description provided for @keepWaiting.
  ///
  /// In en, this message translates to:
  /// **'KEEP WAITING'**
  String get keepWaiting;

  /// No description provided for @searchingDriver.
  ///
  /// In en, this message translates to:
  /// **'SEARCHING FOR DRIVER'**
  String get searchingDriver;

  /// No description provided for @connectingDrivers.
  ///
  /// In en, this message translates to:
  /// **'Connecting with nearby drivers...'**
  String get connectingDrivers;

  /// No description provided for @yourOffer.
  ///
  /// In en, this message translates to:
  /// **'YOUR OFFER'**
  String get yourOffer;

  /// No description provided for @addPrice.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get addPrice;

  /// No description provided for @cancelRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'CANCEL REQUEST?'**
  String get cancelRequestTitle;

  /// No description provided for @cancelRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to cancel the driver search?'**
  String get cancelRequestMessage;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'NO'**
  String get no;

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'YES, CANCEL'**
  String get yesCancel;

  /// No description provided for @cancelTrip.
  ///
  /// In en, this message translates to:
  /// **'CANCEL TRIP'**
  String get cancelTrip;

  /// No description provided for @yourDriver.
  ///
  /// In en, this message translates to:
  /// **'Your Driver'**
  String get yourDriver;

  /// No description provided for @driverOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way'**
  String get driverOnTheWay;

  /// No description provided for @driverHasArrived.
  ///
  /// In en, this message translates to:
  /// **'Your driver has arrived'**
  String get driverHasArrived;

  /// No description provided for @tripInProgress.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get tripInProgress;

  /// No description provided for @updatingStatus.
  ///
  /// In en, this message translates to:
  /// **'Updating status...'**
  String get updatingStatus;

  /// No description provided for @enCaminoBadge.
  ///
  /// In en, this message translates to:
  /// **'ON THE WAY'**
  String get enCaminoBadge;

  /// No description provided for @haLlegadoBadge.
  ///
  /// In en, this message translates to:
  /// **'HAS ARRIVED'**
  String get haLlegadoBadge;

  /// No description provided for @enCursoBadge.
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get enCursoBadge;

  /// No description provided for @procesandoBadge.
  ///
  /// In en, this message translates to:
  /// **'PROCESSING'**
  String get procesandoBadge;

  /// No description provided for @fare.
  ///
  /// In en, this message translates to:
  /// **'FARE'**
  String get fare;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @walletAndPayments.
  ///
  /// In en, this message translates to:
  /// **'Wallet and Payments'**
  String get walletAndPayments;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get addVehicle;

  /// No description provided for @serviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Service settings'**
  String get serviceSettings;

  /// No description provided for @accountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get accountDetails;

  /// No description provided for @securityAndAccess.
  ///
  /// In en, this message translates to:
  /// **'Security and Access'**
  String get securityAndAccess;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced Options'**
  String get advancedOptions;

  /// No description provided for @securityOptions.
  ///
  /// In en, this message translates to:
  /// **'Security Options'**
  String get securityOptions;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInfo;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get birthDate;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get preferNotToSay;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get passwordUpdated;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your data, trips, and history will be deleted. Are you sure you want to permanently delete your account?'**
  String get deleteAccountConfirmMessage;

  /// No description provided for @deleteAccountPermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deleteAccountPermanently;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;

  /// No description provided for @driveWithTins.
  ///
  /// In en, this message translates to:
  /// **'Drive with TINS'**
  String get driveWithTins;

  /// No description provided for @travelWithTins.
  ///
  /// In en, this message translates to:
  /// **'Travel with TINS'**
  String get travelWithTins;

  /// No description provided for @generateIncome.
  ///
  /// In en, this message translates to:
  /// **'Generate income'**
  String get generateIncome;

  /// No description provided for @requestRideNow.
  ///
  /// In en, this message translates to:
  /// **'Request a ride now'**
  String get requestRideNow;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use by another account.'**
  String get errorEmailInUse;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is too weak. Please use at least 6 characters.'**
  String get errorWeakPassword;

  /// No description provided for @errorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found. Please register.'**
  String get errorUserNotFound;

  /// No description provided for @errorGenericAuth.
  ///
  /// In en, this message translates to:
  /// **'An error occurred during authentication. Please try again.'**
  String get errorGenericAuth;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
