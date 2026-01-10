// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Machines';

  @override
  String get buyMeCoffee => 'Offrez-moi un café';

  @override
  String get coffeeLinkError =>
      'Impossible d\'ouvrir le lien. Veuillez visiter https://coff.ee/iliuta manuellement.';

  @override
  String coffeeLinkErrorWithDetails(Object error) {
    return 'Erreur lors de l\'ouverture du lien : $error';
  }

  @override
  String get trainingSessions => 'Sessions d\'entraînement';

  @override
  String get unsynchronizedActivities => 'Activités non synchronisées';

  @override
  String get settings => 'Paramètres';

  @override
  String get help => 'Aide';

  @override
  String disconnectedFromDevice(Object deviceName) {
    return 'Déconnecté de $deviceName';
  }

  @override
  String failedToDisconnect(Object error) {
    return 'Échec de la déconnexion : $error';
  }

  @override
  String get openingStravaAuth => 'Ouverture de l\'autorisation Strava...';

  @override
  String get signInStravaPopup => 'Connectez-vous avec votre compte Strava';

  @override
  String get stravaConnected => 'Connecté à Strava !';

  @override
  String get stravaAuthIncomplete =>
      'L\'authentification Strava n\'a pas été terminée';

  @override
  String get stravaAuthRetry =>
      'Veuillez réessayer ou vérifier vos identifiants Strava';

  @override
  String stravaError(Object error) {
    return 'Erreur de connexion à Strava : $error';
  }

  @override
  String get bluetoothPermissionsRequired =>
      'Les permissions Bluetooth sont requises pour rechercher les appareils';

  @override
  String get bluetoothScanFailed =>
      'Échec du démarrage du scan Bluetooth. Veuillez réessayer plus tard.';

  @override
  String get scanForDevices => 'Rechercher les appareils';

  @override
  String get connectedToStrava => 'Connecté à Strava';

  @override
  String get connectToStrava => 'Se connecter à Strava';

  @override
  String get disconnectedFromStrava => 'Déconnecté de Strava';

  @override
  String connectedAsAthlete(Object athleteName) {
    return 'Connecté en tant que $athleteName';
  }

  @override
  String get failedLoadTrainingSessions =>
      'Échec du chargement des sessions d\'entraînement.';

  @override
  String get noTrainingSessionsFound =>
      'Aucune session d\'entraînement trouvée pour ce type de machine.';

  @override
  String get noFtmsDataFound => 'Aucune donnée !';

  @override
  String get goBack => 'Retour';

  @override
  String get freeRide => 'Sortie libre';

  @override
  String get time => 'Temps';

  @override
  String get distance => 'Distance';

  @override
  String get targets => 'Objectifs';

  @override
  String get resistance => 'Résistance :';

  @override
  String get warmUp => 'Échauf.';

  @override
  String get warmingUpMachine => 'La machine finit son café...';

  @override
  String get coolDown => 'Ret. au calme';

  @override
  String get start => 'Démarrer';

  @override
  String get loadTrainingSession => 'Charger une session d\'entraînement';

  @override
  String get trainingSessionGenerator =>
      'Générateur de session d\'entraînement';

  @override
  String get deviceDataFeatures => 'Fonctionnalités de l\'appareil';

  @override
  String get machineFeatures => 'Fonctionnalités de la machine';

  @override
  String get cyclingFtp => 'FTP Vélo';

  @override
  String watts(Object value) {
    return '$value watts';
  }

  @override
  String get rowingFtp => 'FTP Rameur';

  @override
  String per500m(Object value) {
    return '$value par 500m';
  }

  @override
  String get developerMode => 'Mode développeur';

  @override
  String get developerModeSubtitle =>
      'Activer les options de débogage et les fonctionnalités bêta';

  @override
  String get soundEnabled => 'Alertes sonores';

  @override
  String get soundEnabledSubtitle =>
      'Jouer les notifications sonores pendant les entraînements';

  @override
  String get invalidFtp => 'Veuillez saisir un FTP valide (50-1000 watts)';

  @override
  String get invalidTimeFormat =>
      'Veuillez saisir un format de temps valide (M:SS)';

  @override
  String commandSent(Object opcode) {
    return 'Commande $opcode envoyée avec succès';
  }

  @override
  String commandFailed(Object error) {
    return 'Échec : $error';
  }

  @override
  String invalidValueRange(Object max, Object min) {
    return 'Valeur invalide. Plage : $min-$max';
  }

  @override
  String get test => 'Test';

  @override
  String get loadingMachineFeatures =>
      'Chargement des fonctionnalités de la machine...';

  @override
  String get noMachineFeaturesFound =>
      'Aucune fonctionnalité de machine trouvée !';

  @override
  String get retry => 'Réessayer';

  @override
  String get loadTrainingSessionButton => 'Charger une session d\'entraînement';

  @override
  String get loading => '...';

  @override
  String get noTrainingSessions => 'Aucune session d\'entraînement';

  @override
  String get waitingForDeviceData => 'En attente des données de l\'appareil...';

  @override
  String get noData => 'Aucune donnée';

  @override
  String get noDeviceConnected => 'Aucun appareil connecté';

  @override
  String get noDeviceConnectedMessage =>
      'Pour démarrer une session d\'entraînement, veuillez d\'abord connecter une machine de fitness compatible.\n\nVous pouvez rechercher les appareils depuis la page principale.';

  @override
  String get ok => 'OK';

  @override
  String trainingSessionDeleted(Object title) {
    return 'Session d\'entraînement \"$title\" supprimée avec succès';
  }

  @override
  String get failedToDeleteTrainingSession =>
      'Échec de la suppression de la session d\'entraînement';

  @override
  String errorDeletingTrainingSession(Object error) {
    return 'Erreur lors de la suppression de la session d\'entraînement : $error';
  }

  @override
  String get machineType => 'Type de machine : ';

  @override
  String get indoorBike => 'Vélo d\'intérieur';

  @override
  String get rowingMachine => 'Rameur';

  @override
  String failedToLoadUserSettings(Object error) {
    return 'Échec du chargement des paramètres utilisateur : $error';
  }

  @override
  String failedToLoadTrainingSessions(Object error) {
    return 'Échec du chargement des sessions d\'entraînement : $error';
  }

  @override
  String get addTrainingSession => 'Ajouter une session d\'entraînement';

  @override
  String get editTrainingSession => 'Modifier la session d\'entraînement';

  @override
  String get unableToLoadConfiguration =>
      'Impossible de charger la configuration pour ce type de machine';

  @override
  String get update => 'Mettre à jour';

  @override
  String get save => 'Enregistrer';

  @override
  String get sessionTitle => 'Titre de la session';

  @override
  String get enterSessionName => 'Entrez le nom de la session';

  @override
  String get sessionType => 'Type de session : ';

  @override
  String get distanceBased => 'Basée sur la distance';

  @override
  String get timeBased => 'Basée sur le temps';

  @override
  String get distanceBasedSession => 'Session basée sur la distance';

  @override
  String get trainingPreview => 'Aperçu de l\'entraînement';

  @override
  String get noIntervalsAdded =>
      'Aucun intervalle ajouté pour le moment.\nAppuyez sur le bouton + pour ajouter des intervalles.';

  @override
  String get group => 'Groupe';

  @override
  String get interval => 'Intervalle';

  @override
  String get duplicate => 'Dupliquer';

  @override
  String get delete => 'Supprimer';

  @override
  String get distanceLabel => 'Distance :';

  @override
  String get durationLabel => 'Durée :';

  @override
  String targetsLabel(Object targets) {
    return 'Objectifs : $targets';
  }

  @override
  String get resistanceLabel => 'Résistance :';

  @override
  String get repeatLabel => 'Répéter :';

  @override
  String get subIntervals => 'Sous-intervalles :';

  @override
  String get addSubInterval => 'Ajouter un sous-intervalle';

  @override
  String get addGroupInterval => 'Ajouter un intervalle de groupe';

  @override
  String get addUnitInterval => 'Ajouter un intervalle unitaire';

  @override
  String get subInterval => 'Sous-intervalle';

  @override
  String get removeSubInterval => 'Supprimer le sous-intervalle';

  @override
  String get noSubIntervals =>
      'Aucun sous-intervalle. Ajoutez-en un en utilisant le bouton + ci-dessus.';

  @override
  String get enterSessionTitle => 'Veuillez saisir un titre de session';

  @override
  String get addAtLeastOneInterval => 'Veuillez ajouter au moins un intervalle';

  @override
  String get updatingSession => 'Mise à jour de la session...';

  @override
  String get savingSession => 'Enregistrement de la session...';

  @override
  String sessionUpdated(Object title) {
    return 'Session \"$title\" mise à jour avec succès !';
  }

  @override
  String sessionSaved(Object title) {
    return 'Session \"$title\" enregistrée avec succès !';
  }

  @override
  String failedToSaveSession(Object error) {
    return 'Échec de l\'enregistrement de la session : $error';
  }

  @override
  String failedToLoadConfiguration(Object error) {
    return 'Échec du chargement de la configuration : $error';
  }

  @override
  String get noIntervals => 'Aucun intervalle';

  @override
  String get instantaneousPace => 'Allure instantanée';

  @override
  String get power => 'Puissance';

  @override
  String get custom => 'Personnalisé';

  @override
  String get builtIn => 'Intégré';

  @override
  String get trainingIntensity => 'Intensité d\'entraînement';

  @override
  String get edit => 'Modifier';

  @override
  String get deleteTrainingSession => 'Supprimer la session d\'entraînement';

  @override
  String deleteConfirmation(Object title) {
    return 'Êtes-vous sûr de vouloir supprimer \"$title\" ?\n\nCette action ne peut pas être annulée.';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get duplicateTrainingSession => 'Dupliquer la session d\'entraînement';

  @override
  String duplicateConfirmation(Object title) {
    return 'Créer une copie de \"$title\" en tant que nouvelle session personnalisée ?';
  }

  @override
  String get newSessionTitle => 'Nouveau titre de session';

  @override
  String get sessionTitleCannotBeEmpty =>
      'Le titre de la session ne peut pas être vide';

  @override
  String get duplicatingSession => 'Duplication de la session...';

  @override
  String sessionDuplicated(Object title) {
    return 'Session \"$title\" dupliquée avec succès !';
  }

  @override
  String failedToDuplicateSession(Object error) {
    return 'Échec de la duplication de la session : $error';
  }

  @override
  String get startSession => 'Démarrer la session';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get failedToLoadSession => 'Échec du chargement de la session';

  @override
  String get congratulations => 'Félicitations !';

  @override
  String get sessionCompleted =>
      'Vous avez terminé la session d\'entraînement. Souhaitez-vous enregistrer votre entraînement ou continuer avec une session prolongée ?';

  @override
  String get confirmStopSession =>
      'Êtes-vous sûr de vouloir arrêter la session d\'entraînement ? Cette action ne peut pas être annulée.';

  @override
  String get continueSession => 'Continuer';

  @override
  String get discard => 'Abandonner';

  @override
  String get savingWorkout => 'Enregistrement de l\'entraînement...';

  @override
  String get workoutSavedAndUploaded =>
      'Entraînement enregistré et téléchargé sur Strava !';

  @override
  String get workoutSavedNoStrava =>
      'Entraînement enregistré (Strava non connecté)';

  @override
  String get workoutSaved => 'Entraînement enregistré !';

  @override
  String get examplePercentage => 'par ex. 80';

  @override
  String get enterValue => 'Entrez une valeur';

  @override
  String get waiting => 'EN ATTENTE';

  @override
  String get paused => 'EN PAUSE';

  @override
  String intervalsCount(Object count) {
    return 'Intervalles : $count';
  }

  @override
  String get deviceTypeNotDetected => 'Type d\'appareil non détecté';

  @override
  String get noConfigForMachineType =>
      'Aucune configuration pour ce type de machine';

  @override
  String get noFtmsData => 'Aucune donnée de la machine';

  @override
  String get workout => 'Entraînement';

  @override
  String get copySuffix => ' (Copie)';

  @override
  String get sessionPaused =>
      'Session en pause - Appuyez sur Reprendre pour continuer';

  @override
  String get resume => 'Reprendre';

  @override
  String get notAvailable => 'Non disponible';

  @override
  String get controlFeatures => 'Fonctionnalités de contrôle (Interactif) :';

  @override
  String get resistanceLevel => 'Niveau de résistance';

  @override
  String get powerTargetErgMode => 'Cible de puissance (Mode ERG)';

  @override
  String get supportedRange => 'Plage supportée :';

  @override
  String get inclination => 'Inclinaison';

  @override
  String get generalCommands => 'Commandes générales :';

  @override
  String get requestControl => 'Demander le contrôle';

  @override
  String get startOrResume => 'Démarrer/Reprendre';

  @override
  String get stopOrPause => 'Arrêter/Mettre en pause';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get readOnlyFeatures => 'Fonctionnalités de données (Lecture seule) :';

  @override
  String get cadence => 'Cadence';

  @override
  String get totalDistance => 'Distance totale';

  @override
  String get heartRate => 'Fréquence cardiaque';

  @override
  String get powerMeasurement => 'Mesure de puissance';

  @override
  String get elapsedTime => 'Temps écoulé';

  @override
  String get expendedEnergy => 'Énergie dépensée';

  @override
  String get resetCommand => 'Réinitialiser';

  @override
  String get averageSpeed => 'Vitesse moyenne';

  @override
  String get kilometers => 'km';

  @override
  String get fitFiles => 'Sessions non synchronisées';

  @override
  String get deselectAll => 'Tout désélectionner';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get deleteSelected => 'Supprimer la sélection';

  @override
  String get deleting => 'Suppression...';

  @override
  String get noFitFilesFound => 'Aucune session trouvée';

  @override
  String get fitFilesWillAppear =>
      'Les sessions non synchronisées apparaîtront ici après avoir terminé les sessions d\'entraînement';

  @override
  String filesInfo(Object count) {
    return '$count fichier(s) • Appuyez pour sélectionner, appuyez longuement pour les options';
  }

  @override
  String get deleteFitFiles => 'Supprimer les sessions';

  @override
  String deleteFitFilesConfirmation(Object count) {
    return 'Êtes-vous sûr de vouloir supprimer $count session(s) sélectionné(s) ? Cette action ne peut pas être annulée.';
  }

  @override
  String get uploadToStrava => 'Envoyer à Strava';

  @override
  String get share => 'Partager';

  @override
  String failedToLoadFitFiles(Object error) {
    return 'Échec du chargement des sessions : $error';
  }

  @override
  String successfullyDeletedFiles(Object count) {
    return '$count fichier(s) supprimé(s) avec succès';
  }

  @override
  String failedToDeleteFiles(Object count) {
    return 'Échec de la suppression de $count fichier(s)';
  }

  @override
  String errorDeletingFiles(Object error) {
    return 'Erreur lors de la suppression des fichiers : $error';
  }

  @override
  String get stravaAuthRequired =>
      'Veuillez d\'abord vous authentifier avec Strava dans les paramètres';

  @override
  String get failedToUploadToStrava => 'Échec d\'envoi vers Strava';

  @override
  String errorUploadingToStrava(Object error) {
    return 'Erreur lors de l\'envoi vers Strava : $error';
  }

  @override
  String errorSharingFile(Object error) {
    return 'Erreur lors du partage du fichier : $error';
  }

  @override
  String get uploadedToStravaAndDeleted =>
      'Envoyé avec succès à Strava et fichier local supprimé';

  @override
  String get uploadedToStravaFailedDelete =>
      'Envoyé à Strava mais échec de la suppression du fichier local';

  @override
  String get settingsSavedSuccessfully => 'Paramètres enregistrés avec succès';

  @override
  String get fieldLabelSpeed => 'Vitesse';

  @override
  String get fieldLabelPower => 'Puissance';

  @override
  String get fieldLabelCadence => 'Cadence';

  @override
  String get fieldLabelHeartRate => 'Fréquence cardiaque';

  @override
  String get fieldLabelAvgSpeed => 'Vitesse moy.';

  @override
  String get fieldLabelAvgPower => 'Puiss. moy.';

  @override
  String get fieldLabelDistance => 'Distance';

  @override
  String get fieldLabelResistance => 'Résistance';

  @override
  String get fieldLabelStrokeRate => 'Cadence';

  @override
  String get fieldLabelCalories => 'Calories';

  @override
  String get fieldLabelNotAvailable => 'non disponible';

  @override
  String get fieldLabelUnknownDisplay => 'type d\'affichage inconnu';

  @override
  String get level => 'niveau';

  @override
  String get scanning => 'Recherche...';

  @override
  String get fitnessMachines => 'Machines de fitness';

  @override
  String get sensors => 'Capteurs';

  @override
  String get noDevicesFound =>
      'Aucun appareil trouvé. Essayez de rechercher des appareils.';

  @override
  String get connected => 'Connecté';

  @override
  String get unknownDevice => '(appareil inconnu)';

  @override
  String get connect => 'Connecter';

  @override
  String connectingTo(Object deviceName) {
    return 'Connexion à $deviceName...';
  }

  @override
  String connectedTo(Object deviceName, Object deviceType) {
    return 'Connecté à $deviceType : $deviceName';
  }

  @override
  String failedToConnect(Object deviceName) {
    return 'Échec de la connexion à $deviceName';
  }

  @override
  String unsupportedDevice(Object deviceName) {
    return 'Appareil non pris en charge $deviceName';
  }

  @override
  String get disconnect => 'Déconnecter';

  @override
  String autoReconnected(Object deviceName, Object deviceType) {
    return 'Reconnexion automatique à $deviceType : $deviceName';
  }

  @override
  String get enjoyingAppReviewPrompt =>
      'Vous aimez PowerTrain ? Notez-le sur l\'App Store !';

  @override
  String get rateNow => 'Noter maintenant';

  @override
  String get noDevice => '(aucun appareil)';

  @override
  String get open => 'Ouvrir';

  @override
  String get settingsPageTitle => 'Paramètres';

  @override
  String get failedToLoadSettings => 'Échec du chargement des paramètres';

  @override
  String get aboutSectionTitle => 'À propos';

  @override
  String get appName => 'PowerTrain';

  @override
  String get appDescription =>
      'Rameur et vélo d\'intérieur avec votre équipement de fitness compatible FTMS.';

  @override
  String failedToSaveSettings(Object error) {
    return 'Échec de la sauvegarde des paramètres : $error';
  }

  @override
  String get fitnessProfileTitle => 'Profil de fitness';

  @override
  String get fitnessProfileSubtitle =>
      'Vos paramètres de fitness pour des objectifs d\'entraînement précis';

  @override
  String get enterFtpHint => 'Saisir FTP';

  @override
  String get enterTimeHint => 'Saisir temps (M:SS)';

  @override
  String failedToLoadFitFileDetail(Object error) {
    return 'Échec du chargement des détails du fichier FIT : $error';
  }

  @override
  String get noDataAvailable => 'Aucune donnée disponible';

  @override
  String get summary => 'Résumé';

  @override
  String get average => 'Moyenne';

  @override
  String get speed => 'Vitesse';

  @override
  String get pace => 'Allure';

  @override
  String get altitude => 'Altitude';

  @override
  String get workoutTypeBaseEndurance => 'Endurance de base';

  @override
  String get workoutTypeVo2Max => 'VO2 Max';

  @override
  String get workoutTypeSprint => 'Sprint';

  @override
  String get workoutTypeTechnique => 'Technique';

  @override
  String get workoutTypeStrength => 'Force';

  @override
  String get workoutTypePyramid => 'Pyramide';

  @override
  String get workoutTypeRaceSim => 'Simulation de course';
}
