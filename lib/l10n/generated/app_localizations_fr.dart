// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'OpenTranscribe';

  @override
  String get settingsOffline =>
      'Tout reste sur cet appareil. Aucun compte, aucun cloud, aucun réseau.';

  @override
  String get entryUntranscribed => 'Non transcrit';

  @override
  String get entryUntranscribedTitle => 'Pas encore transcrit';

  @override
  String get entryUntranscribedMessage =>
      'Transformez cet enregistrement en texte à relire. Cela se fait sur votre appareil.';

  @override
  String get entryNoSpeechTitle => 'Aucun mot à afficher';

  @override
  String get entryNoSpeechMessage =>
      'Cet enregistrement a été transcrit, mais aucune parole n\'y a été trouvée.';

  @override
  String get retranscribe => 'Retranscrire';

  @override
  String get delete => 'Supprimer';

  @override
  String get homeEmptyHeadline => 'Parlez, et c\'est écrit.';

  @override
  String get homeEmptySubtitle =>
      'Tout ce que vous dites est transcrit et conservé sur cet appareil. Tirez vers le bas pour enregistrer votre première entrée.';

  @override
  String get homePullToRecord => 'Tirez pour enregistrer';

  @override
  String get menuSourceCode => 'Code source';

  @override
  String get recordStateRecording => 'Enregistrement';

  @override
  String get recordStatePaused => 'En pause';

  @override
  String get recordErrorMessage => 'Une erreur s\'est produite pendant l\'enregistrement.';

  @override
  String get recordLiveUnavailable =>
      'Le texte en direct n\'est pas disponible pour l\'instant. Votre enregistrement est en sécurité et sera transcrit une fois terminé.';

  @override
  String get recordInterruptedSaved =>
      'Enregistrement interrompu. Votre prise a été enregistrée et peut être transcrite depuis votre journal.';

  @override
  String get recordPermissionTitle => 'Le micro est désactivé';

  @override
  String get recordPermissionMessage =>
      'Autorisez l\'accès au micro pour opentranscribe dans l\'app Réglages, puis réessayez.';

  @override
  String get rename => 'Renommer';

  @override
  String get transcribe => 'Transcrire';

  @override
  String get transcribeIn => 'Transcrire en…';

  @override
  String get playbackFailed => 'La lecture n\'est pas disponible pour l\'instant.';

  @override
  String get transcribeErrorModelInstall =>
      'Impossible d\'obtenir le modèle vocal pour cette langue. Vérifiez votre connexion et l\'espace disponible, ou gérez les langues dans Modèles.';

  @override
  String get transcribeErrorPermission =>
      'Autorisez la reconnaissance vocale pour opentranscribe dans l\'app Réglages, puis réessayez.';

  @override
  String get transcribeErrorUnavailable =>
      'La transcription sur l\'appareil n\'est pas disponible pour cette langue sur cet appareil.';

  @override
  String get transcribeErrorGeneric => 'Une erreur s\'est produite. Réessayez.';

  @override
  String get transcribeErrorCapReached =>
      'Limite de langues atteinte. Retirez une langue dans les Réglages, puis réessayez.';

  @override
  String get transcribeErrorLabelPermission => 'Reconnaissance vocale désactivée';

  @override
  String get transcribeErrorLabelUnavailable => 'Indisponible sur cet appareil';

  @override
  String get transcribeErrorLabelModelInstall => 'Modèle de langue non obtenu';

  @override
  String get transcribeErrorLabelCapReached => 'Limite de langues atteinte';

  @override
  String get transcribeErrorLabelGeneric => 'Échec de la transcription';

  @override
  String get transcribeErrorTitlePermission => 'Activer la reconnaissance vocale';

  @override
  String get transcribeErrorTitleUnavailable => 'Indisponible ici';

  @override
  String get transcribeErrorTitleModelInstall => 'Téléchargement du modèle impossible';

  @override
  String get transcribeErrorTitleCapReached => 'Limite de langues atteinte';

  @override
  String get transcribeErrorTitleGeneric => 'Une erreur s\'est produite';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeNameDefault => 'Par défaut';

  @override
  String get themeNameGruvbox => 'Gruvbox';

  @override
  String get themeNameSolarized => 'Solarized';

  @override
  String get themeNameSepia => 'Sépia';

  @override
  String get settingsAppLanguage => 'Langue';

  @override
  String get transcriptionInfo =>
      'Chaque langue utilise son propre modèle sur l\'appareil, téléchargé une fois et partagé avec le système ; les modèles ne comptent pas dans le stockage de cette app. Le système limite le nombre de langues qu\'une app peut garder prêtes à la fois.';

  @override
  String transcriptionCap(int used, int max) {
    return '$used emplacements de langue sur $max utilisés';
  }

  @override
  String get transcriptionRemoveHint => 'Balayez une langue vers la gauche pour la retirer.';

  @override
  String get transcriptionErrorUnsupported =>
      'Cette langue ne peut pas encore être téléchargée sur cet appareil.';

  @override
  String get transcriptionErrorStuck =>
      'Un téléchargement précédent est encore en attente. Le système réessaie quand les conditions s\'améliorent ; réessayer ne pose aucun problème.';

  @override
  String get transcriptionErrorGeneric =>
      'Échec du téléchargement. Vérifiez votre connexion et l\'espace disponible, puis réessayez.';

  @override
  String get transcriptionErrorCap =>
      'Limite de langues atteinte. Retirez une langue pour ajouter celle-ci.';

  @override
  String get transcriptionErrorRemove => 'Impossible de retirer cette langue. Réessayez.';

  @override
  String get transcriptionDownloading => 'Téléchargement';

  @override
  String get retry => 'Réessayer';

  @override
  String get modelFailCapTitle => 'Limite de langues atteinte';

  @override
  String modelFailCapBody(String language) {
    return 'Le système limite le nombre de langues qu\'une app peut garder prêtes à la fois. Retirez-en une pour faire de la place à $language.';
  }

  @override
  String get modelFailUnsupportedTitle => 'Pas encore disponible';

  @override
  String modelFailUnsupportedBody(String language) {
    return 'Il n\'y a pas encore de modèle sur l\'appareil pour $language sur cet appareil. Il pourrait arriver avec une mise à jour système.';
  }

  @override
  String get modelFailStuckTitle => 'Téléchargement en cours';

  @override
  String modelFailStuckBody(String language) {
    return 'Un téléchargement précédent pour $language est encore en attente. Le système le réessaie quand les conditions s\'améliorent, et redemander ne pose aucun problème.';
  }

  @override
  String get modelFailGenericTitle => 'Téléchargement impossible';

  @override
  String modelFailGenericBody(String language) {
    return 'Le modèle $language n\'a pas pu être téléchargé. Vérifiez votre connexion et l\'espace disponible, puis réessayez.';
  }

  @override
  String get modelFailRemoveTitle => 'Suppression impossible';

  @override
  String modelFailRemoveBody(String language) {
    return 'Le système n\'a pas libéré $language. Réessayer ne pose aucun problème.';
  }

  @override
  String get settingsModels => 'Transcription';

  @override
  String get transcriptionLanguages => 'Langues';

  @override
  String get transcriptionDefaultTag => 'Par défaut';

  @override
  String get transcriptionDefaultHint =>
      'Touchez et maintenez une langue pour en faire la langue par défaut.';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'La langue de votre téléphone n\'est pas encore prise en charge pour la transcription sur l\'appareil, donc $fallback est la langue par défaut.';
  }

  @override
  String get onboardingIntroBody => 'Vous exprimez ce que vous avez en tête, et c\'est écrit.';

  @override
  String get onboardingSpeakTitle => 'Parlez, tout simplement';

  @override
  String get onboardingSpeakLine => 'Appuyez sur enregistrer et dites ce que vous avez en tête.';

  @override
  String get onboardingWriteTitle => 'Relisez-le';

  @override
  String get onboardingWriteLine => 'Chaque enregistrement est mis par écrit.';

  @override
  String get onboardingPrivateTitle => 'Rien ne quitte le téléphone';

  @override
  String get onboardingPrivateLine => 'Aucun compte, aucun cloud. Le mode avion n\'y change rien.';

  @override
  String get onboardingReflectTitle => 'Réflexions';

  @override
  String get onboardingReflectLine =>
      'Vos entrées reviennent en une courte note, entièrement sur l\'appareil.';

  @override
  String get onboardingSource => 'Open source';

  @override
  String get onboardingSourceLine => 'Chaque ligne est publique. Lisez-la sur GitHub.';

  @override
  String get onboardingPermissionsTitle => 'Autoriser l\'accès';

  @override
  String get onboardingPermissionsBody => 'Tout cela fonctionne entièrement sur votre appareil.';

  @override
  String get onboardingMicName => 'Micro';

  @override
  String get onboardingMicReason => 'Pour enregistrer votre voix.';

  @override
  String get onboardingSpeechName => 'Reconnaissance vocale';

  @override
  String get onboardingSpeechReason =>
      'Pour transformer vos enregistrements en texte, sur l\'appareil.';

  @override
  String get onboardingNotifyName => 'Notifications';

  @override
  String get onboardingNotifyReason => 'Pour un rappel quand une réflexion est prête.';

  @override
  String get onboardingAllow => 'Autoriser';

  @override
  String get onboardingOpenSettings => 'Activer dans les Réglages';

  @override
  String get onboardingModelsTitle => 'Configurer la transcription';

  @override
  String get onboardingModelsBody =>
      'Elle fonctionne hors ligne une fois votre langue installée sur l\'appareil. Vous pouvez en ajouter à tout moment depuis le menu.';

  @override
  String get onboardingReflectionsOn =>
      'Vos entrées deviennent une courte réflexion, entièrement sur cet appareil.';

  @override
  String get onboardingReflectionsPreparing =>
      'Commence dès qu\'Apple Intelligence est prêt sur cet appareil.';

  @override
  String get onboardingReflectionsOff =>
      'Activez Apple Intelligence dans Réglages, sous Apple Intelligence et Siri, pour les recevoir.';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get settingsCache => 'Cache';

  @override
  String cacheRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements',
      one: '$count enregistrement',
    );
    return '$_temp0';
  }

  @override
  String get cacheReclaimable => 'Récupérable';

  @override
  String get cacheReclaimableInfo => 'Transcrit, peut être effacé';

  @override
  String get cacheUsageInfo =>
      'L\'audio des entrées transcrites peut être effacé ; le texte reste. Les enregistrements pas encore transcrits ne sont jamais touchés.';

  @override
  String get cacheKeepAudio => 'Conserver l\'audio';

  @override
  String get cacheKeepAudioInfo =>
      'Si désactivé, chaque enregistrement est supprimé dès que sa transcription réussit. Ces entrées sont texte seul : pas de lecture, pas de retranscription par un meilleur moteur plus tard.';

  @override
  String get cacheClear => 'Effacer l\'audio transcrit';

  @override
  String get cacheClearTitle => 'Effacer l\'audio transcrit ?';

  @override
  String cacheClearBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Supprime l\'audio de $count entrées transcrites ($size). Le texte reste. Irréversible.',
      one: 'Supprime l\'audio de $count entrée transcrite ($size). Le texte reste. Irréversible.',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => 'Supprimer les enregistrements';

  @override
  String get reflectionsTitle => 'Réflexions';

  @override
  String get reflectionPeriods => 'Périodes';

  @override
  String get reflectionDaily => 'Quotidiennes';

  @override
  String get reflectionWeekly => 'Hebdomadaires';

  @override
  String get reflectionMonthly => 'Mensuelles';

  @override
  String get reflectionsEmptyTitle => 'Aucune réflexion pour l\'instant';

  @override
  String get reflectionsEmptyBody =>
      'La première arrive une fois que vous avez tenu votre journal, tirée de ce que vous avez enregistré.';

  @override
  String get reflectionQuietDay => 'Une journée calme.';

  @override
  String get reflectionQuietWeek => 'Une semaine calme.';

  @override
  String get reflectionQuietMonth => 'Un mois calme.';

  @override
  String get reflectionWaitingTitle => 'Pas encore écrite';

  @override
  String get reflectionWaitingBody =>
      'Ceci sera lu à la prochaine ouverture du journal, dès qu\'Apple Intelligence est prêt.';

  @override
  String get reflectionErasedTitle => 'Effacée';

  @override
  String get reflectionErasedBody =>
      'Vous avez supprimé cette réflexion. Régénérer l\'écrit à nouveau.';

  @override
  String get reflectionQuietBody => 'Rien n\'a donné lieu à une réflexion.';

  @override
  String reflectionWrittenOn(String date) {
    return 'Écrite le $date';
  }

  @override
  String reflectionOfPeriod(String range) {
    return 'Réflexion du $range';
  }

  @override
  String get reflectionVoice => 'Voix';

  @override
  String get reflectionVoiceLiterary => 'Littéraire';

  @override
  String get reflectionVoiceObservational => 'Observatrice';

  @override
  String get reflectionVoiceSparse => 'Épurée';

  @override
  String get reflectionLength => 'Longueur';

  @override
  String get reflectionLengthOneLine => 'Une ligne';

  @override
  String get reflectionLengthSentences => 'Quelques phrases';

  @override
  String get reflectionLengthParagraph => 'Court paragraphe';

  @override
  String get reflectionSpecifics => 'Détails';

  @override
  String get reflectionSpecificsNameFreely => 'Nommer les détails';

  @override
  String get reflectionSpecificsThemes => 'Thèmes seulement';

  @override
  String get reflectionSpecificsLetPeriod => 'Laisser décider';

  @override
  String get reflectionGenerateAll => 'Générer les rétrospectives';

  @override
  String get reflectionRegenerate => 'Régénérer';

  @override
  String get reflectionDeleteDay => 'Supprimer le jour';

  @override
  String get reflectionDeleteWeek => 'Supprimer la semaine';

  @override
  String get reflectionDeleteMonth => 'Supprimer le mois';

  @override
  String get reflectionRegenerateFailed => 'Réflexion impossible. Réessayez.';

  @override
  String get reflectionsDisabledTitle => 'Les réflexions sont désactivées';

  @override
  String get reflectionsDisabledBody =>
      'Rien de nouveau ne sera écrit tant que les réflexions sont désactivées.';

  @override
  String get reflectionsDisabledEnable => 'Activer';

  @override
  String get reflectionOffTitle => 'Apple Intelligence est désactivé';

  @override
  String get reflectionOffBody =>
      'Activez-le dans Réglages, sous Apple Intelligence et Siri, pour recevoir des réflexions.';

  @override
  String get reflectionPreparingTitle => 'Préparation en cours';

  @override
  String get reflectionPreparingBody =>
      'Apple Intelligence se prépare sur cet appareil. Les réflexions commencent une fois terminé.';

  @override
  String get reflectionUnsupportedTitle => 'Non disponible ici';

  @override
  String get reflectionUnsupportedBody =>
      'Cet appareil ne prend pas en charge Apple Intelligence, nécessaire aux réflexions.';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get notifyReflectionReminders => 'Rappels de réflexion';

  @override
  String get notifyPeriodDay => 'Jour';

  @override
  String get notifyPeriodWeek => 'Semaine';

  @override
  String get notifyPeriodMonth => 'Mois';

  @override
  String get notifyReflectionsInfo =>
      'Un rappel quand une nouvelle réflexion est prête à lire. Il se déclenche sur votre appareil ; rien n\'est envoyé où que ce soit.';

  @override
  String get notifyTime => 'Heure';

  @override
  String get notifyPermissionDenied => 'Les notifications sont désactivées dans Réglages.';

  @override
  String get notifyOpenSettings => 'Ouvrir Réglages';

  @override
  String get notifyDailyTitle => 'Votre journée est prête';

  @override
  String get notifyDailyBody => 'Ouvrez pour lire la réflexion d\'hier.';

  @override
  String get notifyWeeklyTitle => 'Votre semaine est prête';

  @override
  String get notifyWeeklyBody => 'Ouvrez pour lire la réflexion de la semaine dernière.';

  @override
  String get notifyMonthlyTitle => 'Votre mois est prêt';

  @override
  String get notifyMonthlyBody => 'Ouvrez pour lire la réflexion du mois dernier.';

  @override
  String get notifyNeedsReflections =>
      'Les rappels arrivent quand une nouvelle réflexion est prête à lire. Les réflexions sont désactivées pour le moment.';

  @override
  String get notifyTurnOnReflections => 'Activer les réflexions';

  @override
  String get notifyReflectionsUnavailable =>
      'Cet appareil ne peut pas générer de réflexions, il n\'y a donc pas de rappel à envoyer.';

  @override
  String get themeRequestInfo =>
      'Vous voulez OpenTranscribe dans un thème absent d\'ici ? Ouvrez une issue sur GitHub et nous l\'ajouterons dans une prochaine version.';

  @override
  String get themeRequestLink => 'Demander un thème sur GitHub';

  @override
  String get exportEntry => 'Exporter';

  @override
  String get exportEntryTitle => 'Exporter l\'entrée';

  @override
  String get exportFormatPlain => 'Markdown brut';

  @override
  String get exportIncludeAudio => 'Inclure l\'audio';

  @override
  String get exportFailedTitle => 'Échec de l\'export';

  @override
  String get exportFailedBody => 'Impossible de préparer les fichiers. Rien n\'a été partagé.';

  @override
  String get exportUntitled => 'Sans titre';

  @override
  String get exportTranscriptHeading => 'Transcription';

  @override
  String get exportQuiet => 'Une période calme.';

  @override
  String get exportRecorded => 'Enregistré';

  @override
  String get exportDuration => 'Durée';

  @override
  String get exportLanguage => 'Langue';

  @override
  String get exportAudio => 'Audio';

  @override
  String get settingsBackup => 'Sauvegarde et export';

  @override
  String get backupInfo =>
      'Tout vit sur ce téléphone ; supprimer l\'app supprime le journal. Un export ou une sauvegarde ne part vers la feuille de partage que sur ta demande.';

  @override
  String backupInfoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tes $count entrées ne vivent que sur ce téléphone ; supprimer l\'app supprime le journal. Un export ou une sauvegarde ne part vers la feuille de partage que sur ta demande.',
      one:
          'Ton unique entrée ne vit que sur ce téléphone ; supprimer l\'app supprime le journal. Un export ou une sauvegarde ne part vers la feuille de partage que sur ta demande.',
      zero:
          'Aucune entrée pour l\'instant ; le journal ne vit que sur ce téléphone, et supprimer l\'app le supprime. Un export ou une sauvegarde ne part vers la feuille de partage que sur ta demande.',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => 'Export';

  @override
  String get backupExportJournal => 'Exporter le journal';

  @override
  String get backupExportInfo =>
      'Écrit chaque entrée dans le format choisi, audio compris, en zip pour la feuille de partage. Une copie pour d\'autres apps ; restaurer demande une sauvegarde.';

  @override
  String get backupSeal => 'Chiffrer avec une phrase secrète';

  @override
  String get backupSave => 'Enregistrer la sauvegarde';

  @override
  String backupLastBackup(String date) {
    return 'Dernière sauvegarde $date';
  }

  @override
  String get backupRestore => 'Restaurer une sauvegarde';

  @override
  String get passphraseCreateTitle => 'Chiffrer la sauvegarde';

  @override
  String get passphraseCreateBody =>
      'La phrase secrète est la seule clé. Elle n\'est stockée nulle part ; sans elle, la sauvegarde n\'est que du bruit.';

  @override
  String get passphrasePlaceholder => 'Phrase secrète';

  @override
  String get passphraseRepeatPlaceholder => 'Répéter la phrase secrète';

  @override
  String get passphraseTooShort => 'Au moins 8 caractères';

  @override
  String get passphraseMismatch => 'Les phrases secrètes ne correspondent pas';

  @override
  String get importUnlockTitle => 'Sauvegarde chiffrée';

  @override
  String get importUnlockBody =>
      'Saisis la phrase secrète avec laquelle cette sauvegarde a été chiffrée.';

  @override
  String get importUnlock => 'Déverrouiller';

  @override
  String get importWrongPassphrase =>
      'Déverrouillage impossible. Phrase secrète erronée, ou fichier endommagé.';

  @override
  String get importConfirmTitle => 'Restaurer cette sauvegarde ?';

  @override
  String get importConfirmBody =>
      'Ajoute ses entrées à ton journal. Restaurer deux fois la même sauvegarde ne duplique jamais.';

  @override
  String get importConfirm => 'Restaurer';

  @override
  String get importSummaryTitle => 'Restauration terminée';

  @override
  String importSummaryImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées restaurées.',
      one: '1 entrée restaurée.',
      zero: 'Rien de nouveau à restaurer.',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées étaient déjà dans le journal.',
      one: '1 entrée était déjà dans le journal.',
    );
    return '$_temp0';
  }

  @override
  String get importFailedTitle => 'Échec de la restauration';

  @override
  String get importFailedBody =>
      'La sauvegarde n\'a pas pu être lue. Rien dans le journal n\'a été modifié.';

  @override
  String get importNotArchive =>
      'Ce n\'est pas une sauvegarde OpenTranscribe. Rien dans le journal n\'a été modifié.';

  @override
  String get importNewerVersion =>
      'Créée par une version plus récente de l\'app. Mets à jour pour l\'importer.';

  @override
  String get importRezipped =>
      'Cette sauvegarde a été re-zippée par un autre outil. Enregistre-en une fraîche et restaure celle-là.';

  @override
  String get done => 'OK';

  @override
  String get importFailedMidway =>
      'La restauration s\'est arrêtée en cours de route. Ce qui a été restauré est conservé ; restaure à nouveau pour terminer.';
}
