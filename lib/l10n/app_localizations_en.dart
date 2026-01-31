// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PowerTrain';

  @override
  String get buyMeCoffee => 'Buy me a coffee';

  @override
  String get coffeeLinkError =>
      'Could not open the coffee link. Please visit https://coff.ee/iliuta manually.';

  @override
  String coffeeLinkErrorWithDetails(Object error) {
    return 'Error opening coffee link: $error';
  }

  @override
  String get trainingSessions => 'Training Sessions';

  @override
  String get unsynchronizedActivities => 'Unsynchronized activities';

  @override
  String get settings => 'Settings';

  @override
  String get help => 'Help';

  @override
  String get helpUrl =>
      'https://iliuta.github.io/powertrain-training-sessions/';

  @override
  String disconnectedFromDevice(Object deviceName) {
    return 'Disconnected from $deviceName';
  }

  @override
  String failedToDisconnect(Object error) {
    return 'Failed to disconnect: $error';
  }

  @override
  String get openingStravaAuth => 'Opening Strava authorization...';

  @override
  String get signInStravaPopup =>
      'Sign in with your Strava account in the popup';

  @override
  String get stravaConnected => 'Successfully connected to Strava!';

  @override
  String get stravaAuthIncomplete => 'Strava authentication was not completed';

  @override
  String get stravaAuthRetry =>
      'Please try again or check your Strava credentials';

  @override
  String stravaError(Object error) {
    return 'Error connecting to Strava: $error';
  }

  @override
  String get bluetoothPermissionsRequired =>
      'Bluetooth permissions are required to scan for devices';

  @override
  String get bluetoothScanFailed =>
      'Failed to start Bluetooth scan. Please try again later.';

  @override
  String get scanForDevices => 'Scan for Devices';

  @override
  String get connectedToStrava => 'Connected to Strava';

  @override
  String get connectToStrava => 'Connect to Strava';

  @override
  String get disconnectedFromStrava => 'Disconnected from Strava';

  @override
  String connectedAsAthlete(Object athleteName) {
    return 'Connected as $athleteName';
  }

  @override
  String get failedLoadTrainingSessions => 'Failed to load training sessions.';

  @override
  String get noTrainingSessionsFound =>
      'No training sessions found for this machine type.';

  @override
  String get couldNotRetrieveDeviceInformation =>
      'Could not retrieve device information. Please check your connection and try again.';

  @override
  String get noFtmsDataFound => 'No FTMSData found!';

  @override
  String get goBack => 'Go Back';

  @override
  String get freeRide => 'Free Ride';

  @override
  String freeRideSessionTitle(Object target) {
    return 'Free Ride $target';
  }

  @override
  String get time => 'Time';

  @override
  String get distance => 'Distance';

  @override
  String get targets => 'Targets';

  @override
  String get resistance => 'Resistance:';

  @override
  String get warmUp => 'Warm up';

  @override
  String get warmingUpMachine => 'Machine is finishing its coffee...';

  @override
  String get coolDown => 'Cool down';

  @override
  String get start => 'Start';

  @override
  String get loadTrainingSession => 'Load Training Session';

  @override
  String get trainingSessionGenerator => 'Training Session Generator';

  @override
  String get deviceDataFeatures => 'Device Data Features';

  @override
  String get machineFeatures => 'Machine Features';

  @override
  String get cyclingFtp => 'Cycling FTP';

  @override
  String watts(Object value) {
    return '$value watts';
  }

  @override
  String get rowingFtp => 'Rowing FTP';

  @override
  String per500m(Object value) {
    return '$value per 500m';
  }

  @override
  String get developerMode => 'Developer Mode';

  @override
  String get developerModeSubtitle =>
      'Enable debugging options and beta features';

  @override
  String get soundEnabled => 'Sound Alerts';

  @override
  String get soundEnabledSubtitle => 'Play sound notifications during workouts';

  @override
  String get invalidFtp => 'Please enter a valid FTP (50-1000 watts)';

  @override
  String get invalidTimeFormat => 'Please enter a valid time format (M:SS)';

  @override
  String commandSent(Object opcode) {
    return '✅ Command $opcode sent successfully';
  }

  @override
  String commandFailed(Object error) {
    return '❌ Failed: $error';
  }

  @override
  String invalidValueRange(Object max, Object min) {
    return 'Invalid value. Range: $min-$max';
  }

  @override
  String get test => 'Test';

  @override
  String get loadingMachineFeatures => 'Loading machine features...';

  @override
  String get noMachineFeaturesFound => 'No Machine Features found!';

  @override
  String get retry => 'Retry';

  @override
  String get loadTrainingSessionButton => 'Load training session';

  @override
  String get loading => '...';

  @override
  String get noTrainingSessions => 'No Training Sessions';

  @override
  String get waitingForDeviceData => 'Waiting for device data...';

  @override
  String get noData => 'No data';

  @override
  String get noDeviceConnected => 'No Device Connected';

  @override
  String get noDeviceConnectedMessage =>
      'To start a training session, please connect to a compatible fitness machine first.\n\nYou can scan for devices from the main page.';

  @override
  String get ok => 'OK';

  @override
  String trainingSessionDeleted(Object title) {
    return 'Training session \"$title\" deleted successfully';
  }

  @override
  String get failedToDeleteTrainingSession =>
      'Failed to delete training session';

  @override
  String errorDeletingTrainingSession(Object error) {
    return 'Error deleting training session: $error';
  }

  @override
  String get machineType => 'Machine Type: ';

  @override
  String get indoorBike => 'Indoor Bike';

  @override
  String get rowingMachine => 'Rowing Machine';

  @override
  String failedToLoadUserSettings(Object error) {
    return 'Failed to load user settings: $error';
  }

  @override
  String failedToLoadTrainingSessions(Object error) {
    return 'Failed to load training sessions: $error';
  }

  @override
  String get addTrainingSession => 'Add Training Session';

  @override
  String get editTrainingSession => 'Edit Training Session';

  @override
  String get unableToLoadConfiguration =>
      'Unable to load configuration for this machine type';

  @override
  String get update => 'Update';

  @override
  String get save => 'Save';

  @override
  String get sessionTitle => 'Session Title';

  @override
  String get enterSessionName => 'Enter session name';

  @override
  String get sessionType => 'Session Type: ';

  @override
  String get distanceBased => 'Distance-based';

  @override
  String get timeBased => 'Time-based';

  @override
  String get distanceBasedSession => 'Distance-based session';

  @override
  String get trainingPreview => 'Training Preview';

  @override
  String get noIntervalsAdded =>
      'No intervals added yet.\nTap the + button to add intervals.';

  @override
  String get group => 'Group';

  @override
  String get interval => 'Interval';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get delete => 'Delete';

  @override
  String get distanceLabel => 'Distance:';

  @override
  String get durationLabel => 'Duration:';

  @override
  String targetsLabel(Object targets) {
    return 'Targets: $targets';
  }

  @override
  String get resistanceLabel => 'Resistance:';

  @override
  String get repeatLabel => 'Repeat:';

  @override
  String get subIntervals => 'Sub-intervals:';

  @override
  String get addSubInterval => 'Add Sub-interval';

  @override
  String get addGroupInterval => 'Add Group Interval';

  @override
  String get addUnitInterval => 'Add Unit Interval';

  @override
  String get subInterval => 'Sub-interval';

  @override
  String get removeSubInterval => 'Remove Sub-interval';

  @override
  String get noSubIntervals =>
      'No sub-intervals. Add one using the + button above.';

  @override
  String get enterSessionTitle => 'Please enter a session title';

  @override
  String get addAtLeastOneInterval => 'Please add at least one interval';

  @override
  String get updatingSession => 'Updating session...';

  @override
  String get savingSession => 'Saving session...';

  @override
  String sessionUpdated(Object title) {
    return 'Session \"$title\" updated successfully!';
  }

  @override
  String sessionSaved(Object title) {
    return 'Session \"$title\" saved successfully!';
  }

  @override
  String failedToSaveSession(Object error) {
    return 'Failed to save session: $error';
  }

  @override
  String failedToLoadConfiguration(Object error) {
    return 'Failed to load configuration: $error';
  }

  @override
  String get noIntervals => 'No intervals';

  @override
  String get instantaneousPace => 'Instantaneous Pace';

  @override
  String get power => 'Power';

  @override
  String get custom => 'Custom';

  @override
  String get builtIn => 'Built-in';

  @override
  String get trainingIntensity => 'Training Intensity';

  @override
  String get edit => 'Edit';

  @override
  String get deleteTrainingSession => 'Delete Training Session';

  @override
  String deleteConfirmation(Object title) {
    return 'Are you sure you want to delete \"$title\"?\n\nThis action cannot be undone.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get duplicateTrainingSession => 'Duplicate Training Session';

  @override
  String duplicateConfirmation(Object title) {
    return 'Create a copy of \"$title\" as a new custom session?';
  }

  @override
  String get newSessionTitle => 'New Session Title';

  @override
  String newSessionGeneratedTitle(Object machineType) {
    return 'New $machineType Session';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'Session title cannot be empty';

  @override
  String get duplicatingSession => 'Duplicating session...';

  @override
  String sessionDuplicated(Object title) {
    return 'Session \"$title\" duplicated successfully!';
  }

  @override
  String failedToDuplicateSession(Object error) {
    return 'Failed to duplicate session: $error';
  }

  @override
  String get startSession => 'Start Session';

  @override
  String get notConnected => 'Not connected';

  @override
  String get failedToLoadSession => 'Failed to load session';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get sessionCompleted =>
      'You have completed the training session. Would you like to save your workout or continue with an extended session?';

  @override
  String get confirmStopSession =>
      'Are you sure you want to stop the training session? This action cannot be undone.';

  @override
  String get continueSession => 'Continue';

  @override
  String get discard => 'Discard';

  @override
  String get savingWorkout => 'Saving workout...';

  @override
  String get workoutSavedAndUploaded => 'Workout saved and uploaded to Strava!';

  @override
  String get workoutSavedNoStrava => 'Workout saved (Strava not connected)';

  @override
  String get workoutSaved => 'Workout saved!';

  @override
  String get examplePercentage => 'e.g. 80';

  @override
  String get enterValue => 'Enter value';

  @override
  String get waiting => 'WAITING';

  @override
  String get paused => 'PAUSED';

  @override
  String intervalsCount(Object count) {
    return 'Intervals: $count';
  }

  @override
  String get deviceTypeNotDetected => 'Device type not detected';

  @override
  String get noConfigForMachineType => 'No config for this machine type';

  @override
  String get noFtmsData => 'No FTMS data';

  @override
  String get workout => 'Workout';

  @override
  String get copySuffix => ' (Copy)';

  @override
  String get sessionPaused => 'Session Paused - Press Resume to continue';

  @override
  String get resume => 'Resume';

  @override
  String get notAvailable => 'Not available';

  @override
  String get controlFeatures => 'Control Features (Interactive):';

  @override
  String get resistanceLevel => 'Resistance Level';

  @override
  String get powerTargetErgMode => 'Power Target (ERG Mode)';

  @override
  String get supportedRange => 'Supported Range:';

  @override
  String get inclination => 'Inclination';

  @override
  String get generalCommands => 'General Commands:';

  @override
  String get requestControl => 'Request Control';

  @override
  String get startOrResume => 'Start/Resume';

  @override
  String get stopOrPause => 'Stop/Pause';

  @override
  String get reset => 'Reset';

  @override
  String get readOnlyFeatures => 'Data Features (Read-only):';

  @override
  String get cadence => 'Cadence';

  @override
  String get totalDistance => 'Total Distance';

  @override
  String get heartRate => 'Heart Rate';

  @override
  String get powerMeasurement => 'Power Measurement';

  @override
  String get elapsedTime => 'Elapsed Time';

  @override
  String get expendedEnergy => 'Expended Energy';

  @override
  String get resetCommand => 'Reset';

  @override
  String get averageSpeed => 'Average Speed';

  @override
  String get kilometers => 'km';

  @override
  String get fitFiles => 'FIT Files';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get selectAll => 'Select All';

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get deleting => 'Deleting...';

  @override
  String get noFitFilesFound => 'No FIT files found';

  @override
  String get fitFilesWillAppear =>
      'FIT files will appear here after completing training sessions';

  @override
  String filesInfo(Object count) {
    return '$count file(s) • Tap to select, long press for options';
  }

  @override
  String get deleteFitFiles => 'Delete FIT Files';

  @override
  String deleteFitFilesConfirmation(Object count) {
    return 'Are you sure you want to delete $count selected file(s)? This action cannot be undone.';
  }

  @override
  String get uploadToStrava => 'Upload to Strava';

  @override
  String get share => 'Share';

  @override
  String failedToLoadFitFiles(Object error) {
    return 'Failed to load FIT files: $error';
  }

  @override
  String successfullyDeletedFiles(Object count) {
    return 'Successfully deleted $count file(s)';
  }

  @override
  String failedToDeleteFiles(Object count) {
    return 'Failed to delete $count file(s)';
  }

  @override
  String errorDeletingFiles(Object error) {
    return 'Error deleting files: $error';
  }

  @override
  String get stravaAuthRequired =>
      'Please authenticate with Strava first in Settings';

  @override
  String get failedToUploadToStrava => 'Failed to upload to Strava';

  @override
  String errorUploadingToStrava(Object error) {
    return 'Error uploading to Strava: $error';
  }

  @override
  String errorSharingFile(Object error) {
    return 'Error sharing file: $error';
  }

  @override
  String get uploadedToStravaAndDeleted =>
      'Successfully uploaded to Strava and deleted local file';

  @override
  String get uploadedToStravaFailedDelete =>
      'Uploaded to Strava but failed to delete local file';

  @override
  String get settingsSavedSuccessfully => 'Settings saved successfully';

  @override
  String get fieldLabelSpeed => 'Speed';

  @override
  String get fieldLabelPower => 'Power';

  @override
  String get fieldLabelCadence => 'Cadence';

  @override
  String get fieldLabelHeartRate => 'Heart rate';

  @override
  String get fieldLabelAvgSpeed => 'Avg speed';

  @override
  String get fieldLabelAvgPower => 'Avg power';

  @override
  String get fieldLabelDistance => 'Distance';

  @override
  String get fieldLabelResistance => 'Resistance';

  @override
  String get fieldLabelStrokeRate => 'Stroke Rate';

  @override
  String get fieldLabelCalories => 'Calories';

  @override
  String get fieldLabelNotAvailable => 'not available';

  @override
  String get fieldLabelUnknownDisplay => 'unknown display type';

  @override
  String get level => 'level';

  @override
  String get scanning => 'Scanning...';

  @override
  String get fitnessMachines => 'Fitness machines';

  @override
  String get sensors => 'Sensors';

  @override
  String get noDevicesFound =>
      'No devices found. Wake up your machine and try searching for devices again.';

  @override
  String get connected => 'Connected';

  @override
  String get unknownDevice => '(unknown device)';

  @override
  String get connect => 'Connect';

  @override
  String connectingTo(Object deviceName) {
    return 'Connecting to $deviceName...';
  }

  @override
  String connectedTo(Object deviceName, Object deviceType) {
    return 'Connected to $deviceType: $deviceName';
  }

  @override
  String failedToConnect(Object deviceName) {
    return 'Failed to connect to $deviceName';
  }

  @override
  String unsupportedDevice(Object deviceName) {
    return 'Unsupported device $deviceName';
  }

  @override
  String get disconnect => 'Disconnect';

  @override
  String autoReconnected(Object deviceName, Object deviceType) {
    return 'Auto-reconnected to $deviceType: $deviceName';
  }

  @override
  String get enjoyingAppReviewPrompt =>
      'Enjoying PowerTrain? Rate it on the app store!';

  @override
  String get rateNow => 'Rate Now';

  @override
  String get noDevice => '(no device)';

  @override
  String get open => 'Open';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get failedToLoadSettings => 'Failed to load settings';

  @override
  String get aboutSectionTitle => 'About';

  @override
  String get appName => 'PowerTrain';

  @override
  String get appDescription =>
      'Indoor Rowing and Cycling with your FTMS compatible fitness equipment.';

  @override
  String failedToSaveSettings(Object error) {
    return 'Failed to save settings: $error';
  }

  @override
  String get fitnessProfileTitle => 'Fitness Profile';

  @override
  String get fitnessProfileSubtitle =>
      'Your personal fitness metrics for accurate training targets';

  @override
  String get enterFtpHint => 'Enter FTP';

  @override
  String get enterTimeHint => 'Enter time (M:SS)';

  @override
  String failedToLoadFitFileDetail(Object error) {
    return 'Failed to load FIT file detail: $error';
  }

  @override
  String get noDataAvailable => 'No data available';

  @override
  String get summary => 'Summary';

  @override
  String get average => 'Average';

  @override
  String get speed => 'Speed';

  @override
  String get pace => 'Pace';

  @override
  String get altitude => 'Altitude';

  @override
  String get workoutTypeBaseEndurance => 'Base Endurance';

  @override
  String get workoutTypeVo2Max => 'VO2 Max';

  @override
  String get workoutTypeSprint => 'Sprint';

  @override
  String get workoutTypeTechnique => 'Technique';

  @override
  String get workoutTypeStrength => 'Strength';

  @override
  String get workoutTypePyramid => 'Pyramid';

  @override
  String get workoutTypeRaceSim => 'Race Simulation';

  @override
  String get resistanceHelp => 'Resistance Help';

  @override
  String resistanceHelpDescription(Object maxLevel) {
    return 'Set the resistance level from 1 to $maxLevel. This value is used only if the machine supports resistance adjustment and will be converted to the range accepted by your machine.';
  }

  @override
  String get resistanceHelpMachine => 'Resistance Level';

  @override
  String resistanceHelpMachineDescription(Object maxLevel) {
    return 'Set the resistance level from 1 to $maxLevel, actually supported by your machine.';
  }

  @override
  String get resistanceControlUnavailable =>
      'Use your machine\'s controls to adjust the resistance';

  @override
  String get developerModeRequired => 'Developer Mode Required';

  @override
  String get developerModeRequiredDescription =>
      'This device requires developer mode to be enabled. Please enable developer mode in the settings to view device data and features.';
}
