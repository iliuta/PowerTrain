// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Fitnessgeräte';

  @override
  String get buyMeCoffee => 'Kaufen Sie mir einen Kaffee';

  @override
  String get coffeeLinkError =>
      'Konnte den Kaffee-Link nicht öffnen. Bitte besuchen Sie https://coff.ee/iliuta manuell.';

  @override
  String coffeeLinkErrorWithDetails(Object error) {
    return 'Fehler beim Öffnen des Kaffee-Links: $error';
  }

  @override
  String get trainingSessions => 'Trainingseinheiten';

  @override
  String get unsynchronizedActivities => 'Nicht synchronisierte Aktivitäten';

  @override
  String get settings => 'Einstellungen';

  @override
  String get help => 'Hilfe';

  @override
  String disconnectedFromDevice(Object deviceName) {
    return 'Von $deviceName getrennt';
  }

  @override
  String failedToDisconnect(Object error) {
    return 'Trennung fehlgeschlagen: $error';
  }

  @override
  String get openingStravaAuth => 'Strava-Autorisierung wird geöffnet...';

  @override
  String get signInStravaPopup =>
      'Melden Sie sich mit Ihrem Strava-Konto im Popup an';

  @override
  String get stravaConnected => 'Erfolgreich mit Strava verbunden!';

  @override
  String get stravaAuthIncomplete =>
      'Strava-Authentifizierung wurde nicht abgeschlossen';

  @override
  String get stravaAuthRetry =>
      'Bitte versuchen Sie es erneut oder überprüfen Sie Ihre Strava-Anmeldedaten';

  @override
  String stravaError(Object error) {
    return 'Fehler bei der Verbindung zu Strava: $error';
  }

  @override
  String get bluetoothPermissionsRequired =>
      'Bluetooth-Berechtigungen sind erforderlich, um Geräte zu scannen';

  @override
  String get bluetoothScanFailed =>
      'Bluetooth-Scan konnte nicht gestartet werden. Bitte versuchen Sie es später erneut.';

  @override
  String get scanForDevices => 'Geräte scannen';

  @override
  String get connectedToStrava => 'Mit Strava verbunden';

  @override
  String get connectToStrava => 'Mit Strava verbinden';

  @override
  String get disconnectedFromStrava => 'Von Strava getrennt';

  @override
  String connectedAsAthlete(Object athleteName) {
    return 'Verbunden als $athleteName';
  }

  @override
  String get failedLoadTrainingSessions =>
      'Laden der Trainingseinheiten fehlgeschlagen.';

  @override
  String get noTrainingSessionsFound =>
      'Keine Trainingseinheiten für diesen Maschinentyp gefunden.';

  @override
  String get noFtmsDataFound => 'Keine FTMS-Daten gefunden!';

  @override
  String get goBack => 'Zurück';

  @override
  String get freeRide => 'Freie Fahrt';

  @override
  String get time => 'Zeit';

  @override
  String get distance => 'Distanz';

  @override
  String get targets => 'Ziele';

  @override
  String get resistance => 'Widerstand:';

  @override
  String get warmUp => 'Aufwärmen';

  @override
  String get warmingUpMachine =>
      'Die Maschine trinkt noch kurz ihren Kaffee...';

  @override
  String get coolDown => 'Abkühlen';

  @override
  String get start => 'Start';

  @override
  String get loadTrainingSession => 'Trainingseinheit laden';

  @override
  String get trainingSessionGenerator => 'Trainingseinheiten-Generator';

  @override
  String get deviceDataFeatures => 'Gerätedaten-Funktionen';

  @override
  String get machineFeatures => 'Maschinenfunktionen';

  @override
  String get cyclingFtp => 'Radfahren FTP';

  @override
  String watts(Object value) {
    return '$value Watt';
  }

  @override
  String get rowingFtp => 'Rudern FTP';

  @override
  String per500m(Object value) {
    return '$value pro 500m';
  }

  @override
  String get developerMode => 'Entwicklermodus';

  @override
  String get developerModeSubtitle =>
      'Debugging-Optionen und Beta-Funktionen aktivieren';

  @override
  String get soundEnabled => 'Tonbenachrichtigungen';

  @override
  String get soundEnabledSubtitle =>
      'Tonbenachrichtigungen während des Trainings abspielen';

  @override
  String get invalidFtp =>
      'Bitte geben Sie einen gültigen FTP ein (50-1000 Watt)';

  @override
  String get invalidTimeFormat =>
      'Bitte geben Sie ein gültiges Zeitformat ein (M:SS)';

  @override
  String commandSent(Object opcode) {
    return '✅ Befehl $opcode erfolgreich gesendet';
  }

  @override
  String commandFailed(Object error) {
    return '❌ Fehlgeschlagen: $error';
  }

  @override
  String invalidValueRange(Object max, Object min) {
    return 'Ungültiger Wert. Bereich: $min-$max';
  }

  @override
  String get test => 'Test';

  @override
  String get loadingMachineFeatures => 'Maschinenfunktionen werden geladen...';

  @override
  String get noMachineFeaturesFound => 'Keine Maschinenfunktionen gefunden!';

  @override
  String get retry => 'Wiederholen';

  @override
  String get loadTrainingSessionButton => 'Trainingseinheit laden';

  @override
  String get loading => '...';

  @override
  String get noTrainingSessions => 'Keine Trainingseinheiten';

  @override
  String get waitingForDeviceData => 'Warten auf Gerätedaten...';

  @override
  String get noData => 'Keine Daten';

  @override
  String get noDeviceConnected => 'Kein Gerät verbunden';

  @override
  String get noDeviceConnectedMessage =>
      'Um eine Trainingseinheit zu starten, verbinden Sie bitte zuerst eine kompatible Fitnessmaschine.\n\nSie können Geräte von der Hauptseite aus scannen.';

  @override
  String get ok => 'OK';

  @override
  String trainingSessionDeleted(Object title) {
    return 'Trainingseinheit \"$title\" erfolgreich gelöscht';
  }

  @override
  String get failedToDeleteTrainingSession =>
      'Löschen der Trainingseinheit fehlgeschlagen';

  @override
  String errorDeletingTrainingSession(Object error) {
    return 'Fehler beim Löschen der Trainingseinheit: $error';
  }

  @override
  String get machineType => 'Maschinentyp: ';

  @override
  String get indoorBike => 'Indoor-Fahrrad';

  @override
  String get rowingMachine => 'Rudergerät';

  @override
  String failedToLoadUserSettings(Object error) {
    return 'Laden der Benutzereinstellungen fehlgeschlagen: $error';
  }

  @override
  String failedToLoadTrainingSessions(Object error) {
    return 'Laden der Trainingseinheiten fehlgeschlagen: $error';
  }

  @override
  String get addTrainingSession => 'Trainingseinheit hinzufügen';

  @override
  String get editTrainingSession => 'Trainingseinheit bearbeiten';

  @override
  String get unableToLoadConfiguration =>
      'Konfiguration für diesen Maschinentyp kann nicht geladen werden';

  @override
  String get update => 'Aktualisieren';

  @override
  String get save => 'Speichern';

  @override
  String get sessionTitle => 'Sitzungstitel';

  @override
  String get enterSessionName => 'Sitzungsnamen eingeben';

  @override
  String get sessionType => 'Sitzungstyp: ';

  @override
  String get distanceBased => 'Distanzbasiert';

  @override
  String get timeBased => 'Zeitbasiert';

  @override
  String get distanceBasedSession => 'Distanzbasierte Sitzung';

  @override
  String get trainingPreview => 'Trainingsvorschau';

  @override
  String get noIntervalsAdded =>
      'Noch keine Intervalle hinzugefügt.\nTippen Sie auf die + Schaltfläche, um Intervalle hinzuzufügen.';

  @override
  String get group => 'Gruppe';

  @override
  String get interval => 'Intervall';

  @override
  String get duplicate => 'Duplizieren';

  @override
  String get delete => 'Löschen';

  @override
  String get distanceLabel => 'Distanz:';

  @override
  String get durationLabel => 'Dauer:';

  @override
  String targetsLabel(Object targets) {
    return 'Ziele: $targets';
  }

  @override
  String get resistanceLabel => 'Widerstand:';

  @override
  String get repeatLabel => 'Wiederholen:';

  @override
  String get subIntervals => 'Unterintervalle:';

  @override
  String get addSubInterval => 'Unterintervall hinzufügen';

  @override
  String get addGroupInterval => 'Gruppenintervall hinzufügen';

  @override
  String get addUnitInterval => 'Einzelintervall hinzufügen';

  @override
  String get subInterval => 'Unterintervall';

  @override
  String get removeSubInterval => 'Unterintervall entfernen';

  @override
  String get noSubIntervals =>
      'Keine Unterintervalle. Fügen Sie eines mit der + Schaltfläche oben hinzu.';

  @override
  String get enterSessionTitle => 'Bitte geben Sie einen Sitzungstitel ein';

  @override
  String get addAtLeastOneInterval =>
      'Bitte fügen Sie mindestens ein Intervall hinzu';

  @override
  String get updatingSession => 'Sitzung wird aktualisiert...';

  @override
  String get savingSession => 'Sitzung wird gespeichert...';

  @override
  String sessionUpdated(Object title) {
    return 'Sitzung \"$title\" erfolgreich aktualisiert!';
  }

  @override
  String sessionSaved(Object title) {
    return 'Sitzung \"$title\" erfolgreich gespeichert!';
  }

  @override
  String failedToSaveSession(Object error) {
    return 'Speichern der Sitzung fehlgeschlagen: $error';
  }

  @override
  String failedToLoadConfiguration(Object error) {
    return 'Laden der Konfiguration fehlgeschlagen: $error';
  }

  @override
  String get noIntervals => 'Keine Intervalle';

  @override
  String get instantaneousPace => 'Sofortiges Tempo';

  @override
  String get power => 'Leistung';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get builtIn => 'Integriert';

  @override
  String get trainingIntensity => 'Trainingsintensität';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get deleteTrainingSession => 'Trainingseinheit löschen';

  @override
  String deleteConfirmation(Object title) {
    return 'Sind Sie sicher, dass Sie \"$title\" löschen möchten?\n\nDiese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String get duplicateTrainingSession => 'Trainingseinheit duplizieren';

  @override
  String duplicateConfirmation(Object title) {
    return 'Eine Kopie von \"$title\" als neue benutzerdefinierte Sitzung erstellen?';
  }

  @override
  String get newSessionTitle => 'Neuer Sitzungstitel';

  @override
  String get sessionTitleCannotBeEmpty => 'Sitzungstitel darf nicht leer sein';

  @override
  String get duplicatingSession => 'Sitzung wird dupliziert...';

  @override
  String sessionDuplicated(Object title) {
    return 'Sitzung \"$title\" erfolgreich dupliziert!';
  }

  @override
  String failedToDuplicateSession(Object error) {
    return 'Duplizierung der Sitzung fehlgeschlagen: $error';
  }

  @override
  String get startSession => 'Sitzung starten';

  @override
  String get notConnected => 'Nicht verbunden';

  @override
  String get failedToLoadSession => 'Laden der Sitzung fehlgeschlagen';

  @override
  String get congratulations => 'Herzlichen Glückwunsch!';

  @override
  String get sessionCompleted =>
      'Sie haben die Trainingseinheit abgeschlossen. Möchten Sie Ihr Workout speichern oder mit einer verlängerten Sitzung fortfahren?';

  @override
  String get confirmStopSession =>
      'Sind Sie sicher, dass Sie die Trainingseinheit stoppen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get continueSession => 'Fortfahren';

  @override
  String get discard => 'Verwerfen';

  @override
  String get savingWorkout => 'Workout wird gespeichert...';

  @override
  String get workoutSavedAndUploaded =>
      'Workout gespeichert und auf Strava hochgeladen!';

  @override
  String get workoutSavedNoStrava =>
      'Workout gespeichert (Strava nicht verbunden)';

  @override
  String get workoutSaved => 'Workout gespeichert!';

  @override
  String get examplePercentage => 'z.B. 80';

  @override
  String get enterValue => 'Wert eingeben';

  @override
  String get waiting => 'WARTEN';

  @override
  String get paused => 'PAUSIERT';

  @override
  String intervalsCount(Object count) {
    return 'Intervalle: $count';
  }

  @override
  String get deviceTypeNotDetected => 'Gerätetyp nicht erkannt';

  @override
  String get noConfigForMachineType =>
      'Keine Konfiguration für diesen Maschinentyp';

  @override
  String get noFtmsData => 'Keine FTMS-Daten';

  @override
  String get workout => 'Training';

  @override
  String get copySuffix => ' (Kopie)';

  @override
  String get sessionPaused =>
      'Sitzung pausiert - Drücken Sie Fortsetzen, um fortzufahren';

  @override
  String get resume => 'Fortsetzen';

  @override
  String get notAvailable => 'Nicht verfügbar';

  @override
  String get controlFeatures => 'Steuerungsfunktionen (Interaktiv):';

  @override
  String get resistanceLevel => 'Widerstandsniveau';

  @override
  String get powerTargetErgMode => 'Leistungsziel (ERG-Modus)';

  @override
  String get supportedRange => 'Unterstützter Bereich:';

  @override
  String get inclination => 'Neigung';

  @override
  String get generalCommands => 'Allgemeine Befehle:';

  @override
  String get requestControl => 'Steuerung anfordern';

  @override
  String get startOrResume => 'Starten/Fortsetzen';

  @override
  String get stopOrPause => 'Stoppen/Pausieren';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get readOnlyFeatures => 'Datenfunktionen (Schreibgeschützt):';

  @override
  String get cadence => 'Kadenz';

  @override
  String get totalDistance => 'Gesamtdistanz';

  @override
  String get heartRate => 'Herzfrequenz';

  @override
  String get powerMeasurement => 'Leistungsmessung';

  @override
  String get elapsedTime => 'Verstrichene Zeit';

  @override
  String get expendedEnergy => 'Verbrauchte Energie';

  @override
  String get resetCommand => 'Zurücksetzen';

  @override
  String get averageSpeed => 'Durchschnittsgeschwindigkeit';

  @override
  String get kilometers => 'km';

  @override
  String get fitFiles => 'FIT-Dateien';

  @override
  String get deselectAll => 'Alle abwählen';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get deleteSelected => 'Auswahl löschen';

  @override
  String get deleting => 'Löschen...';

  @override
  String get noFitFilesFound => 'Keine FIT-Dateien gefunden';

  @override
  String get fitFilesWillAppear =>
      'FIT-Dateien werden hier angezeigt, nachdem Trainingseinheiten abgeschlossen wurden';

  @override
  String filesInfo(Object count) {
    return '$count Datei(en) • Tippen zum Auswählen, lange drücken für Optionen';
  }

  @override
  String get deleteFitFiles => 'FIT-Dateien löschen';

  @override
  String deleteFitFilesConfirmation(Object count) {
    return 'Sind Sie sicher, dass Sie $count ausgewählte Datei(en) löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get uploadToStrava => 'Zu Strava hochladen';

  @override
  String get share => 'Teilen';

  @override
  String failedToLoadFitFiles(Object error) {
    return 'Fehler beim Laden der FIT-Dateien: $error';
  }

  @override
  String successfullyDeletedFiles(Object count) {
    return '$count Datei(en) erfolgreich gelöscht';
  }

  @override
  String failedToDeleteFiles(Object count) {
    return 'Fehler beim Löschen von $count Datei(en)';
  }

  @override
  String errorDeletingFiles(Object error) {
    return 'Fehler beim Löschen der Dateien: $error';
  }

  @override
  String get stravaAuthRequired =>
      'Bitte zuerst bei Strava in den Einstellungen authentifizieren';

  @override
  String get failedToUploadToStrava => 'Fehler beim Hochladen zu Strava';

  @override
  String errorUploadingToStrava(Object error) {
    return 'Fehler beim Hochladen zu Strava: $error';
  }

  @override
  String errorSharingFile(Object error) {
    return 'Fehler beim Teilen der Datei: $error';
  }

  @override
  String get uploadedToStravaAndDeleted =>
      'Erfolgreich zu Strava hochgeladen und lokale Datei gelöscht';

  @override
  String get uploadedToStravaFailedDelete =>
      'Zu Strava hochgeladen, aber lokale Datei konnte nicht gelöscht werden';

  @override
  String get settingsSavedSuccessfully =>
      'Einstellungen erfolgreich gespeichert';

  @override
  String get fieldLabelSpeed => 'Geschwindigkeit';

  @override
  String get fieldLabelPower => 'Leistung';

  @override
  String get fieldLabelCadence => 'Trittfrequenz';

  @override
  String get fieldLabelHeartRate => 'Herzfrequenz';

  @override
  String get fieldLabelAvgSpeed => 'Ø Geschw.';

  @override
  String get fieldLabelAvgPower => 'Ø Leist.';

  @override
  String get fieldLabelDistance => 'Strecke';

  @override
  String get fieldLabelResistance => 'Widerstand';

  @override
  String get fieldLabelStrokeRate => 'Schlagfrequenz';

  @override
  String get fieldLabelCalories => 'Kalorien';

  @override
  String get fieldLabelNotAvailable => 'nicht verfügbar';

  @override
  String get fieldLabelUnknownDisplay => 'unbekannter Anzeigetyp';

  @override
  String get level => 'Stufe';

  @override
  String get scanning => 'Suche...';

  @override
  String get fitnessMachines => 'Fitnessmaschinen';

  @override
  String get sensors => 'Sensoren';

  @override
  String get noDevicesFound =>
      'Keine Geräte gefunden. Versuchen Sie, nach Geräten zu suchen.';

  @override
  String get connected => 'Verbunden';

  @override
  String get unknownDevice => '(unbekanntes Gerät)';

  @override
  String get connect => 'Verbinden';

  @override
  String connectingTo(Object deviceName) {
    return 'Verbinde mit $deviceName...';
  }

  @override
  String connectedTo(Object deviceName, Object deviceType) {
    return 'Verbunden mit $deviceType: $deviceName';
  }

  @override
  String failedToConnect(Object deviceName) {
    return 'Verbindung zu $deviceName fehlgeschlagen';
  }

  @override
  String unsupportedDevice(Object deviceName) {
    return 'Nicht unterstütztes Gerät $deviceName';
  }

  @override
  String get disconnect => 'Trennen';

  @override
  String autoReconnected(Object deviceName, Object deviceType) {
    return 'Automatisch wieder verbunden mit $deviceType: $deviceName';
  }

  @override
  String get enjoyingAppReviewPrompt =>
      'Gefällt Ihnen PowerTrain? Bewerten Sie es im App Store!';

  @override
  String get rateNow => 'Jetzt bewerten';

  @override
  String get noDevice => '(kein Gerät)';

  @override
  String get open => 'Öffnen';

  @override
  String get settingsPageTitle => 'Einstellungen';

  @override
  String get failedToLoadSettings => 'Fehler beim Laden der Einstellungen';

  @override
  String get aboutSectionTitle => 'Über';

  @override
  String get appName => 'PowerTrain';

  @override
  String get appDescription =>
      'Indoor-Rudern und -Radfahren mit Ihrer FTMS-kompatiblen Fitnessausrüstung.';

  @override
  String failedToSaveSettings(Object error) {
    return 'Fehler beim Speichern der Einstellungen: $error';
  }

  @override
  String get fitnessProfileTitle => 'Fitnessprofil';

  @override
  String get fitnessProfileSubtitle =>
      'Ihre persönlichen Fitnessmetriken für genaue Trainingsziele';

  @override
  String get enterFtpHint => 'FTP eingeben';

  @override
  String get enterTimeHint => 'Zeit eingeben (M:SS)';

  @override
  String failedToLoadFitFileDetail(Object error) {
    return 'Fehler beim Laden der FIT-Dateidetails: $error';
  }

  @override
  String get noDataAvailable => 'Keine Daten verfügbar';

  @override
  String get summary => 'Zusammenfassung';

  @override
  String get average => 'Durchschnitt';

  @override
  String get speed => 'Geschwindigkeit';

  @override
  String get pace => 'Tempo';

  @override
  String get altitude => 'Höhe';

  @override
  String get workoutTypeBaseEndurance => 'Grundlagenausdauer';

  @override
  String get workoutTypeVo2Max => 'VO2 Max';

  @override
  String get workoutTypeSprint => 'Sprint';

  @override
  String get workoutTypeTechnique => 'Technik';

  @override
  String get workoutTypeStrength => 'Kraft';

  @override
  String get workoutTypePyramid => 'Pyramide';

  @override
  String get workoutTypeRaceSim => 'Rennsimulation';
}
