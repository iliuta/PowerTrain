import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
    Locale('de'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RowerTrain'**
  String get appTitle;

  /// No description provided for @buyMeCoffee.
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee'**
  String get buyMeCoffee;

  /// No description provided for @coffeeLinkError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the coffee link. Please visit https://coff.ee/iliuta manually.'**
  String get coffeeLinkError;

  /// No description provided for @coffeeLinkErrorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error opening coffee link: {error}'**
  String coffeeLinkErrorWithDetails(Object error);

  /// No description provided for @trainingSessions.
  ///
  /// In en, this message translates to:
  /// **'Training Sessions'**
  String get trainingSessions;

  /// No description provided for @unsynchronizedActivities.
  ///
  /// In en, this message translates to:
  /// **'Unsynchronized activities'**
  String get unsynchronizedActivities;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @helpUrl.
  ///
  /// In en, this message translates to:
  /// **'https://iliuta.github.io/powertrain-training-sessions/'**
  String get helpUrl;

  /// No description provided for @disconnectedFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from {deviceName}'**
  String disconnectedFromDevice(Object deviceName);

  /// No description provided for @failedToDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to disconnect: {error}'**
  String failedToDisconnect(Object error);

  /// No description provided for @openingStravaAuth.
  ///
  /// In en, this message translates to:
  /// **'Opening Strava authorization...'**
  String get openingStravaAuth;

  /// No description provided for @signInStravaPopup.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Strava account in the popup'**
  String get signInStravaPopup;

  /// No description provided for @stravaConnected.
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to Strava!'**
  String get stravaConnected;

  /// No description provided for @stravaAuthIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Strava authentication was not completed'**
  String get stravaAuthIncomplete;

  /// No description provided for @stravaAuthRetry.
  ///
  /// In en, this message translates to:
  /// **'Please try again or check your Strava credentials'**
  String get stravaAuthRetry;

  /// No description provided for @stravaError.
  ///
  /// In en, this message translates to:
  /// **'Error connecting to Strava: {error}'**
  String stravaError(Object error);

  /// No description provided for @bluetoothPermissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permissions are required to scan for devices'**
  String get bluetoothPermissionsRequired;

  /// No description provided for @bluetoothScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start Bluetooth scan. Please try again later.'**
  String get bluetoothScanFailed;

  /// No description provided for @scanForDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan for Devices'**
  String get scanForDevices;

  /// No description provided for @connectedToStrava.
  ///
  /// In en, this message translates to:
  /// **'Connected to Strava'**
  String get connectedToStrava;

  /// No description provided for @connectToStrava.
  ///
  /// In en, this message translates to:
  /// **'Connect to Strava'**
  String get connectToStrava;

  /// No description provided for @disconnectedFromStrava.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from Strava'**
  String get disconnectedFromStrava;

  /// No description provided for @connectedAsAthlete.
  ///
  /// In en, this message translates to:
  /// **'Connected as {athleteName}'**
  String connectedAsAthlete(Object athleteName);

  /// No description provided for @failedLoadTrainingSessions.
  ///
  /// In en, this message translates to:
  /// **'Failed to load training sessions.'**
  String get failedLoadTrainingSessions;

  /// No description provided for @noTrainingSessionsFound.
  ///
  /// In en, this message translates to:
  /// **'No training sessions found for this machine type.'**
  String get noTrainingSessionsFound;

  /// No description provided for @couldNotRetrieveDeviceInformation.
  ///
  /// In en, this message translates to:
  /// **'Could not retrieve device information. Please check your connection and try again.'**
  String get couldNotRetrieveDeviceInformation;

  /// No description provided for @noFtmsDataFound.
  ///
  /// In en, this message translates to:
  /// **'No FTMSData found!'**
  String get noFtmsDataFound;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @freeRide.
  ///
  /// In en, this message translates to:
  /// **'Free Ride'**
  String get freeRide;

  /// No description provided for @freeRideSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Free Ride {target}'**
  String freeRideSessionTitle(Object target);

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @targets.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get targets;

  /// No description provided for @resistance.
  ///
  /// In en, this message translates to:
  /// **'Resistance:'**
  String get resistance;

  /// No description provided for @warmUp.
  ///
  /// In en, this message translates to:
  /// **'Warm up'**
  String get warmUp;

  /// No description provided for @warmingUpMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine is finishing its coffee...'**
  String get warmingUpMachine;

  /// No description provided for @coolDown.
  ///
  /// In en, this message translates to:
  /// **'Cool down'**
  String get coolDown;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @loadTrainingSession.
  ///
  /// In en, this message translates to:
  /// **'Load Training Session'**
  String get loadTrainingSession;

  /// No description provided for @trainingSessionGenerator.
  ///
  /// In en, this message translates to:
  /// **'Training Session Generator'**
  String get trainingSessionGenerator;

  /// No description provided for @deviceDataFeatures.
  ///
  /// In en, this message translates to:
  /// **'Device Data Features'**
  String get deviceDataFeatures;

  /// No description provided for @machineFeatures.
  ///
  /// In en, this message translates to:
  /// **'Machine Features'**
  String get machineFeatures;

  /// No description provided for @cyclingFtp.
  ///
  /// In en, this message translates to:
  /// **'Cycling FTP'**
  String get cyclingFtp;

  /// No description provided for @watts.
  ///
  /// In en, this message translates to:
  /// **'{value} watts'**
  String watts(Object value);

  /// No description provided for @rowingFtp.
  ///
  /// In en, this message translates to:
  /// **'Rowing FTP'**
  String get rowingFtp;

  /// No description provided for @per500m.
  ///
  /// In en, this message translates to:
  /// **'{value} per 500m'**
  String per500m(Object value);

  /// No description provided for @developerMode.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get developerMode;

  /// No description provided for @developerModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable debugging options and beta features'**
  String get developerModeSubtitle;

  /// No description provided for @soundEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sound Alerts'**
  String get soundEnabled;

  /// No description provided for @soundEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play sound notifications during workouts'**
  String get soundEnabledSubtitle;

  /// No description provided for @invalidFtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid FTP (50-1000 watts)'**
  String get invalidFtp;

  /// No description provided for @invalidTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid time format (M:SS)'**
  String get invalidTimeFormat;

  /// No description provided for @commandSent.
  ///
  /// In en, this message translates to:
  /// **'✅ Command {opcode} sent successfully'**
  String commandSent(Object opcode);

  /// No description provided for @commandFailed.
  ///
  /// In en, this message translates to:
  /// **'❌ Failed: {error}'**
  String commandFailed(Object error);

  /// No description provided for @invalidValueRange.
  ///
  /// In en, this message translates to:
  /// **'Invalid value. Range: {min}-{max}'**
  String invalidValueRange(Object max, Object min);

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @loadingMachineFeatures.
  ///
  /// In en, this message translates to:
  /// **'Loading machine features...'**
  String get loadingMachineFeatures;

  /// No description provided for @noMachineFeaturesFound.
  ///
  /// In en, this message translates to:
  /// **'No Machine Features found!'**
  String get noMachineFeaturesFound;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loadTrainingSessionButton.
  ///
  /// In en, this message translates to:
  /// **'Load training session'**
  String get loadTrainingSessionButton;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'...'**
  String get loading;

  /// No description provided for @noTrainingSessions.
  ///
  /// In en, this message translates to:
  /// **'No Training Sessions'**
  String get noTrainingSessions;

  /// No description provided for @waitingForDeviceData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device data...'**
  String get waitingForDeviceData;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @noDeviceConnected.
  ///
  /// In en, this message translates to:
  /// **'No Device Connected'**
  String get noDeviceConnected;

  /// No description provided for @noDeviceConnectedMessage.
  ///
  /// In en, this message translates to:
  /// **'To start a training session, please connect to a compatible fitness machine first.\n\nYou can scan for devices from the main page.'**
  String get noDeviceConnectedMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @trainingSessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Training session \"{title}\" deleted successfully'**
  String trainingSessionDeleted(Object title);

  /// No description provided for @failedToDeleteTrainingSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete training session'**
  String get failedToDeleteTrainingSession;

  /// No description provided for @errorDeletingTrainingSession.
  ///
  /// In en, this message translates to:
  /// **'Error deleting training session: {error}'**
  String errorDeletingTrainingSession(Object error);

  /// No description provided for @machineType.
  ///
  /// In en, this message translates to:
  /// **'Machine Type: '**
  String get machineType;

  /// No description provided for @indoorBike.
  ///
  /// In en, this message translates to:
  /// **'Indoor Bike'**
  String get indoorBike;

  /// No description provided for @rowingMachine.
  ///
  /// In en, this message translates to:
  /// **'Rowing Machine'**
  String get rowingMachine;

  /// No description provided for @failedToLoadUserSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to load user settings: {error}'**
  String failedToLoadUserSettings(Object error);

  /// No description provided for @failedToLoadTrainingSessions.
  ///
  /// In en, this message translates to:
  /// **'Failed to load training sessions: {error}'**
  String failedToLoadTrainingSessions(Object error);

  /// No description provided for @addTrainingSession.
  ///
  /// In en, this message translates to:
  /// **'Add Training Session'**
  String get addTrainingSession;

  /// No description provided for @editTrainingSession.
  ///
  /// In en, this message translates to:
  /// **'Edit Training Session'**
  String get editTrainingSession;

  /// No description provided for @unableToLoadConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Unable to load configuration for this machine type'**
  String get unableToLoadConfiguration;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Title'**
  String get sessionTitle;

  /// No description provided for @enterSessionName.
  ///
  /// In en, this message translates to:
  /// **'Enter session name'**
  String get enterSessionName;

  /// No description provided for @sessionType.
  ///
  /// In en, this message translates to:
  /// **'Session Type: '**
  String get sessionType;

  /// No description provided for @distanceBased.
  ///
  /// In en, this message translates to:
  /// **'Distance-based'**
  String get distanceBased;

  /// No description provided for @timeBased.
  ///
  /// In en, this message translates to:
  /// **'Time-based'**
  String get timeBased;

  /// No description provided for @distanceBasedSession.
  ///
  /// In en, this message translates to:
  /// **'Distance-based session'**
  String get distanceBasedSession;

  /// No description provided for @trainingPreview.
  ///
  /// In en, this message translates to:
  /// **'Training Preview'**
  String get trainingPreview;

  /// No description provided for @noIntervalsAdded.
  ///
  /// In en, this message translates to:
  /// **'No intervals added yet.\nTap the + button to add intervals.'**
  String get noIntervalsAdded;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @interval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get interval;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @distanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance:'**
  String get distanceLabel;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration:'**
  String get durationLabel;

  /// No description provided for @targetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Targets: {targets}'**
  String targetsLabel(Object targets);

  /// No description provided for @resistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Resistance:'**
  String get resistanceLabel;

  /// No description provided for @repeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat:'**
  String get repeatLabel;

  /// No description provided for @subIntervals.
  ///
  /// In en, this message translates to:
  /// **'Sub-intervals:'**
  String get subIntervals;

  /// No description provided for @addSubInterval.
  ///
  /// In en, this message translates to:
  /// **'Add Sub-interval'**
  String get addSubInterval;

  /// No description provided for @addGroupInterval.
  ///
  /// In en, this message translates to:
  /// **'Add Group Interval'**
  String get addGroupInterval;

  /// No description provided for @addUnitInterval.
  ///
  /// In en, this message translates to:
  /// **'Add Unit Interval'**
  String get addUnitInterval;

  /// No description provided for @subInterval.
  ///
  /// In en, this message translates to:
  /// **'Sub-interval'**
  String get subInterval;

  /// No description provided for @removeSubInterval.
  ///
  /// In en, this message translates to:
  /// **'Remove Sub-interval'**
  String get removeSubInterval;

  /// No description provided for @noSubIntervals.
  ///
  /// In en, this message translates to:
  /// **'No sub-intervals. Add one using the + button above.'**
  String get noSubIntervals;

  /// No description provided for @enterSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a session title'**
  String get enterSessionTitle;

  /// No description provided for @addAtLeastOneInterval.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one interval'**
  String get addAtLeastOneInterval;

  /// No description provided for @updatingSession.
  ///
  /// In en, this message translates to:
  /// **'Updating session...'**
  String get updatingSession;

  /// No description provided for @savingSession.
  ///
  /// In en, this message translates to:
  /// **'Saving session...'**
  String get savingSession;

  /// No description provided for @sessionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Session \"{title}\" updated successfully!'**
  String sessionUpdated(Object title);

  /// No description provided for @sessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Session \"{title}\" saved successfully!'**
  String sessionSaved(Object title);

  /// No description provided for @failedToSaveSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to save session: {error}'**
  String failedToSaveSession(Object error);

  /// No description provided for @failedToLoadConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Failed to load configuration: {error}'**
  String failedToLoadConfiguration(Object error);

  /// No description provided for @noIntervals.
  ///
  /// In en, this message translates to:
  /// **'No intervals'**
  String get noIntervals;

  /// No description provided for @instantaneousPace.
  ///
  /// In en, this message translates to:
  /// **'Instantaneous Pace'**
  String get instantaneousPace;

  /// No description provided for @power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @builtIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtIn;

  /// No description provided for @trainingIntensity.
  ///
  /// In en, this message translates to:
  /// **'Training Intensity'**
  String get trainingIntensity;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deleteTrainingSession.
  ///
  /// In en, this message translates to:
  /// **'Delete Training Session'**
  String get deleteTrainingSession;

  /// No description provided for @deleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?\n\nThis action cannot be undone.'**
  String deleteConfirmation(Object title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @duplicateTrainingSession.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Training Session'**
  String get duplicateTrainingSession;

  /// No description provided for @duplicateConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Create a copy of \"{title}\" as a new custom session?'**
  String duplicateConfirmation(Object title);

  /// No description provided for @newSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'New Session Title'**
  String get newSessionTitle;

  /// No description provided for @newSessionGeneratedTitle.
  ///
  /// In en, this message translates to:
  /// **'New {machineType} Session'**
  String newSessionGeneratedTitle(Object machineType);

  /// No description provided for @sessionTitleCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Session title cannot be empty'**
  String get sessionTitleCannotBeEmpty;

  /// No description provided for @duplicatingSession.
  ///
  /// In en, this message translates to:
  /// **'Duplicating session...'**
  String get duplicatingSession;

  /// No description provided for @sessionDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Session \"{title}\" duplicated successfully!'**
  String sessionDuplicated(Object title);

  /// No description provided for @failedToDuplicateSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to duplicate session: {error}'**
  String failedToDuplicateSession(Object error);

  /// No description provided for @startSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get startSession;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @failedToLoadSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to load session'**
  String get failedToLoadSession;

  /// No description provided for @congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get congratulations;

  /// No description provided for @sessionCompleted.
  ///
  /// In en, this message translates to:
  /// **'You have completed the training session. Would you like to save your workout or continue with an extended session?'**
  String get sessionCompleted;

  /// No description provided for @confirmStopSession.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop the training session? This action cannot be undone.'**
  String get confirmStopSession;

  /// No description provided for @continueSession.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueSession;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @savingWorkout.
  ///
  /// In en, this message translates to:
  /// **'Saving workout...'**
  String get savingWorkout;

  /// No description provided for @workoutSavedAndUploaded.
  ///
  /// In en, this message translates to:
  /// **'Workout saved and uploaded to Strava!'**
  String get workoutSavedAndUploaded;

  /// No description provided for @workoutSavedNoStrava.
  ///
  /// In en, this message translates to:
  /// **'Workout saved (Strava not connected)'**
  String get workoutSavedNoStrava;

  /// No description provided for @workoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Workout saved!'**
  String get workoutSaved;

  /// No description provided for @examplePercentage.
  ///
  /// In en, this message translates to:
  /// **'e.g. 80'**
  String get examplePercentage;

  /// No description provided for @enterValue.
  ///
  /// In en, this message translates to:
  /// **'Enter value'**
  String get enterValue;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get waiting;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get paused;

  /// No description provided for @intervalsCount.
  ///
  /// In en, this message translates to:
  /// **'Intervals: {count}'**
  String intervalsCount(Object count);

  /// No description provided for @deviceTypeNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Device type not detected'**
  String get deviceTypeNotDetected;

  /// No description provided for @noConfigForMachineType.
  ///
  /// In en, this message translates to:
  /// **'No config for this machine type'**
  String get noConfigForMachineType;

  /// No description provided for @noFtmsData.
  ///
  /// In en, this message translates to:
  /// **'No FTMS data'**
  String get noFtmsData;

  /// No description provided for @workout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @copySuffix.
  ///
  /// In en, this message translates to:
  /// **' (Copy)'**
  String get copySuffix;

  /// No description provided for @sessionPaused.
  ///
  /// In en, this message translates to:
  /// **'Session Paused - Press Resume to continue'**
  String get sessionPaused;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @controlFeatures.
  ///
  /// In en, this message translates to:
  /// **'Control Features (Interactive):'**
  String get controlFeatures;

  /// No description provided for @resistanceLevel.
  ///
  /// In en, this message translates to:
  /// **'Resistance Level'**
  String get resistanceLevel;

  /// No description provided for @powerTargetErgMode.
  ///
  /// In en, this message translates to:
  /// **'Power Target (ERG Mode)'**
  String get powerTargetErgMode;

  /// No description provided for @supportedRange.
  ///
  /// In en, this message translates to:
  /// **'Supported Range:'**
  String get supportedRange;

  /// No description provided for @inclination.
  ///
  /// In en, this message translates to:
  /// **'Inclination'**
  String get inclination;

  /// No description provided for @generalCommands.
  ///
  /// In en, this message translates to:
  /// **'General Commands:'**
  String get generalCommands;

  /// No description provided for @requestControl.
  ///
  /// In en, this message translates to:
  /// **'Request Control'**
  String get requestControl;

  /// No description provided for @startOrResume.
  ///
  /// In en, this message translates to:
  /// **'Start/Resume'**
  String get startOrResume;

  /// No description provided for @stopOrPause.
  ///
  /// In en, this message translates to:
  /// **'Stop/Pause'**
  String get stopOrPause;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @readOnlyFeatures.
  ///
  /// In en, this message translates to:
  /// **'Data Features (Read-only):'**
  String get readOnlyFeatures;

  /// No description provided for @cadence.
  ///
  /// In en, this message translates to:
  /// **'Cadence'**
  String get cadence;

  /// No description provided for @totalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get totalDistance;

  /// No description provided for @heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get heartRate;

  /// No description provided for @powerMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Power Measurement'**
  String get powerMeasurement;

  /// No description provided for @elapsedTime.
  ///
  /// In en, this message translates to:
  /// **'Elapsed Time'**
  String get elapsedTime;

  /// No description provided for @expendedEnergy.
  ///
  /// In en, this message translates to:
  /// **'Expended Energy'**
  String get expendedEnergy;

  /// No description provided for @resetCommand.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetCommand;

  /// No description provided for @averageSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average Speed'**
  String get averageSpeed;

  /// No description provided for @kilometers.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get kilometers;

  /// No description provided for @fitFiles.
  ///
  /// In en, this message translates to:
  /// **'FIT Files'**
  String get fitFiles;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get deleteSelected;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// No description provided for @noFitFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No FIT files found'**
  String get noFitFilesFound;

  /// No description provided for @fitFilesWillAppear.
  ///
  /// In en, this message translates to:
  /// **'FIT files will appear here after completing training sessions'**
  String get fitFilesWillAppear;

  /// No description provided for @filesInfo.
  ///
  /// In en, this message translates to:
  /// **'{count} file(s) • Tap to select, long press for options'**
  String filesInfo(Object count);

  /// No description provided for @deleteFitFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete FIT Files'**
  String get deleteFitFiles;

  /// No description provided for @deleteFitFilesConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected file(s)? This action cannot be undone.'**
  String deleteFitFilesConfirmation(Object count);

  /// No description provided for @uploadToStrava.
  ///
  /// In en, this message translates to:
  /// **'Upload to Strava'**
  String get uploadToStrava;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @failedToLoadFitFiles.
  ///
  /// In en, this message translates to:
  /// **'Failed to load FIT files: {error}'**
  String failedToLoadFitFiles(Object error);

  /// No description provided for @successfullyDeletedFiles.
  ///
  /// In en, this message translates to:
  /// **'Successfully deleted {count} file(s)'**
  String successfullyDeletedFiles(Object count);

  /// No description provided for @failedToDeleteFiles.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete {count} file(s)'**
  String failedToDeleteFiles(Object count);

  /// No description provided for @errorDeletingFiles.
  ///
  /// In en, this message translates to:
  /// **'Error deleting files: {error}'**
  String errorDeletingFiles(Object error);

  /// No description provided for @stravaAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Please authenticate with Strava first in Settings'**
  String get stravaAuthRequired;

  /// No description provided for @failedToUploadToStrava.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload to Strava'**
  String get failedToUploadToStrava;

  /// No description provided for @errorUploadingToStrava.
  ///
  /// In en, this message translates to:
  /// **'Error uploading to Strava: {error}'**
  String errorUploadingToStrava(Object error);

  /// No description provided for @errorSharingFile.
  ///
  /// In en, this message translates to:
  /// **'Error sharing file: {error}'**
  String errorSharingFile(Object error);

  /// No description provided for @uploadedToStravaAndDeleted.
  ///
  /// In en, this message translates to:
  /// **'Successfully uploaded to Strava and deleted local file'**
  String get uploadedToStravaAndDeleted;

  /// No description provided for @uploadedToStravaFailedDelete.
  ///
  /// In en, this message translates to:
  /// **'Uploaded to Strava but failed to delete local file'**
  String get uploadedToStravaFailedDelete;

  /// No description provided for @settingsSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settingsSavedSuccessfully;

  /// No description provided for @fieldLabelSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get fieldLabelSpeed;

  /// No description provided for @fieldLabelPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get fieldLabelPower;

  /// No description provided for @fieldLabelCadence.
  ///
  /// In en, this message translates to:
  /// **'Cadence'**
  String get fieldLabelCadence;

  /// No description provided for @fieldLabelHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get fieldLabelHeartRate;

  /// No description provided for @fieldLabelAvgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get fieldLabelAvgSpeed;

  /// No description provided for @fieldLabelAvgPower.
  ///
  /// In en, this message translates to:
  /// **'Avg power'**
  String get fieldLabelAvgPower;

  /// No description provided for @fieldLabelDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get fieldLabelDistance;

  /// No description provided for @fieldLabelResistance.
  ///
  /// In en, this message translates to:
  /// **'Resistance'**
  String get fieldLabelResistance;

  /// No description provided for @fieldLabelStrokeRate.
  ///
  /// In en, this message translates to:
  /// **'Stroke Rate'**
  String get fieldLabelStrokeRate;

  /// No description provided for @fieldLabelCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get fieldLabelCalories;

  /// No description provided for @fieldLabelNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get fieldLabelNotAvailable;

  /// No description provided for @fieldLabelUnknownDisplay.
  ///
  /// In en, this message translates to:
  /// **'unknown display type'**
  String get fieldLabelUnknownDisplay;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'level'**
  String get level;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @fitnessMachines.
  ///
  /// In en, this message translates to:
  /// **'Fitness machines'**
  String get fitnessMachines;

  /// No description provided for @sensors.
  ///
  /// In en, this message translates to:
  /// **'Sensors'**
  String get sensors;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found. Wake up your machine and try searching for devices again.'**
  String get noDevicesFound;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'(unknown device)'**
  String get unknownDevice;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {deviceName}...'**
  String connectingTo(Object deviceName);

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {deviceType}: {deviceName}'**
  String connectedTo(Object deviceName, Object deviceType);

  /// No description provided for @failedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to {deviceName}'**
  String failedToConnect(Object deviceName);

  /// No description provided for @unsupportedDevice.
  ///
  /// In en, this message translates to:
  /// **'Unsupported device {deviceName}'**
  String unsupportedDevice(Object deviceName);

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @autoReconnected.
  ///
  /// In en, this message translates to:
  /// **'Auto-reconnected to {deviceType}: {deviceName}'**
  String autoReconnected(Object deviceName, Object deviceType);

  /// No description provided for @enjoyingAppReviewPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enjoying PowerTrain? Rate it on the app store!'**
  String get enjoyingAppReviewPrompt;

  /// No description provided for @rateNow.
  ///
  /// In en, this message translates to:
  /// **'Rate Now'**
  String get rateNow;

  /// No description provided for @noDevice.
  ///
  /// In en, this message translates to:
  /// **'(no device)'**
  String get noDevice;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @failedToLoadSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings'**
  String get failedToLoadSettings;

  /// No description provided for @aboutSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSectionTitle;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'PowerTrain'**
  String get appName;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Indoor Rowing and Cycling with your FTMS compatible fitness equipment.'**
  String get appDescription;

  /// No description provided for @failedToSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings: {error}'**
  String failedToSaveSettings(Object error);

  /// No description provided for @fitnessProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Fitness Profile'**
  String get fitnessProfileTitle;

  /// No description provided for @fitnessProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal fitness metrics for accurate training targets'**
  String get fitnessProfileSubtitle;

  /// No description provided for @enterFtpHint.
  ///
  /// In en, this message translates to:
  /// **'Enter FTP'**
  String get enterFtpHint;

  /// No description provided for @enterTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter time (M:SS)'**
  String get enterTimeHint;

  /// No description provided for @failedToLoadFitFileDetail.
  ///
  /// In en, this message translates to:
  /// **'Failed to load FIT file detail: {error}'**
  String failedToLoadFitFileDetail(Object error);

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @pace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get pace;

  /// No description provided for @altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get altitude;

  /// No description provided for @workoutTypeBaseEndurance.
  ///
  /// In en, this message translates to:
  /// **'Base Endurance'**
  String get workoutTypeBaseEndurance;

  /// No description provided for @workoutTypeVo2Max.
  ///
  /// In en, this message translates to:
  /// **'VO2 Max'**
  String get workoutTypeVo2Max;

  /// No description provided for @workoutTypeSprint.
  ///
  /// In en, this message translates to:
  /// **'Sprint'**
  String get workoutTypeSprint;

  /// No description provided for @workoutTypeTechnique.
  ///
  /// In en, this message translates to:
  /// **'Technique'**
  String get workoutTypeTechnique;

  /// No description provided for @workoutTypeStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get workoutTypeStrength;

  /// No description provided for @workoutTypePyramid.
  ///
  /// In en, this message translates to:
  /// **'Pyramid'**
  String get workoutTypePyramid;

  /// No description provided for @workoutTypeRaceSim.
  ///
  /// In en, this message translates to:
  /// **'Race Simulation'**
  String get workoutTypeRaceSim;

  /// No description provided for @resistanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Resistance Help'**
  String get resistanceHelp;

  /// No description provided for @resistanceHelpDescription.
  ///
  /// In en, this message translates to:
  /// **'Set the resistance level from 1 to {maxLevel}. This value is used only if the machine supports resistance adjustment and will be converted to the range accepted by your machine.'**
  String resistanceHelpDescription(Object maxLevel);

  /// No description provided for @resistanceHelpMachine.
  ///
  /// In en, this message translates to:
  /// **'Resistance Level'**
  String get resistanceHelpMachine;

  /// No description provided for @resistanceHelpMachineDescription.
  ///
  /// In en, this message translates to:
  /// **'Set the resistance level from 1 to {maxLevel}, actually supported by your machine.'**
  String resistanceHelpMachineDescription(Object maxLevel);

  /// No description provided for @resistanceControlUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Use your machine\'s controls to adjust the resistance'**
  String get resistanceControlUnavailable;

  /// No description provided for @developerModeRequired.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode Required'**
  String get developerModeRequired;

  /// No description provided for @developerModeRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'This device requires developer mode to be enabled. Please enable developer mode in the settings to view device data and features.'**
  String get developerModeRequiredDescription;
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
      <String>['de', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
