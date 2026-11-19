import 'package:flutter/widgets.dart';

/// Hand-written FR/EN strings (no codegen). French is the default.
class S {
  const S(this.isFr);
  final bool isFr;

  static S of(BuildContext context) => S(Localizations.localeOf(context).languageCode != 'en');

  String _t(String fr, String en) => isFr ? fr : en;

  // ── General ────────────────────────────────────────────────────────────
  String get appName => 'Keevy';
  String get tagline => _t('Garde tes inspirations. Planifie tes moments.', 'Save your inspiration. Plan your moments.');
  String get cancel => _t('Annuler', 'Cancel');
  String get save => _t('Enregistrer', 'Save');
  String get delete => _t('Supprimer', 'Delete');
  String get edit => _t('Modifier', 'Edit');
  String get done => _t('Terminé', 'Done');
  String get close => _t('Fermer', 'Close');
  String get add => _t('Ajouter', 'Add');
  String get create => _t('Créer', 'Create');
  String get next => _t('Suivant', 'Next');
  String get back => _t('Retour', 'Back');
  String get retry => _t('Réessayer', 'Retry');
  String get search => _t('Rechercher', 'Search');
  String get all => _t('Tous', 'All');
  String get optional => _t('optionnel', 'optional');
  String get undo => _t('Annuler', 'Undo');
  String get confirmDeleteTitle => _t('Supprimer ?', 'Delete?');
  String get errGeneric => _t('Oups, quelque chose s’est mal passé.', 'Oops, something went wrong.');
  String get errNetwork => _t('Connexion impossible. Vérifie ton réseau.', 'Can’t connect. Check your network.');
  String get copied => _t('Copié', 'Copied');

  // ── Setup ──────────────────────────────────────────────────────────────
  String get setupTitle => _t('Configuration manquante', 'Missing configuration');
  String get setupBody => _t(
        'Lance l’app avec --dart-define-from-file=dart_defines.json (SUPABASE_URL et SUPABASE_ANON_KEY). Voir docs/SETUP.md.',
        'Run the app with --dart-define-from-file=dart_defines.json (SUPABASE_URL and SUPABASE_ANON_KEY). See docs/SETUP.md.',
      );

  // ── Onboarding ─────────────────────────────────────────────────────────
  String get onb1Title => _t('Tout ce qui t’inspire, au même endroit', 'Everything that inspires you, in one place');
  String get onb1Body => _t(
        'Reels, TikTok, sites de prestataires, captures d’écran : fini les signets perdus dans dix apps.',
        'Reels, TikToks, vendor websites, screenshots: no more bookmarks lost across ten apps.',
      );
  String get onb2Title => _t('Partage depuis n’importe quelle app', 'Share from any app');
  String get onb2Body => _t(
        'Touche « Partager », choisis Keevy, range ton idée dans le bon board. Trois secondes.',
        'Tap “Share”, pick Keevy, drop your idea in the right board. Three seconds.',
      );
  String get onb3Title => _t('Passe en mode Projet le moment venu', 'Switch to Project mode when it’s time');
  String get onb3Body => _t(
        'Mariage, baby shower, crémaillère : date, checklist et prestataires, reliés à tes inspirations.',
        'Wedding, baby shower, housewarming: date, checklist and vendors, linked to your inspiration.',
      );
  String get start => _t('Commencer', 'Get started');
  String get skip => _t('Passer', 'Skip');

  // ── Auth ───────────────────────────────────────────────────────────────
  String get authTitle => _t('Bienvenue sur Keevy', 'Welcome to Keevy');
  String get authSubtitle => _t('Entre ton email, on t’envoie un code de connexion. Pas de mot de passe à retenir.',
      'Enter your email and we’ll send you a sign-in code. No password to remember.');
  String get emailLabel => _t('Email', 'Email');
  String get emailInvalid => _t('Email invalide', 'Invalid email');
  String get sendCode => _t('Recevoir mon code', 'Send my code');
  String get codeTitle => _t('Vérifie tes emails', 'Check your inbox');
  String codeSubtitle(String email) => _t('On a envoyé un code à 6 chiffres à $email.', 'We sent a 6-digit code to $email.');
  String get codeLabel => _t('Code', 'Code');
  String get verify => _t('Se connecter', 'Sign in');
  String get resendCode => _t('Renvoyer le code', 'Resend code');
  String get codeResent => _t('Nouveau code envoyé', 'New code sent');
  String get codeInvalid => _t('Code invalide ou expiré', 'Invalid or expired code');
  String get changeEmail => _t('Changer d’email', 'Use another email');
  String get privacyNotice => _t('Ton espace est privé par défaut.', 'Your space is private by default.');

  // ── Navigation ─────────────────────────────────────────────────────────
  String get navBoards => 'Boards';
  String get navContacts => 'Contacts';
  String get navLinks => _t('Liens', 'Links');

  // ── Home ───────────────────────────────────────────────────────────────
  String hello(String? name) => name == null || name.isEmpty ? _t('Bonjour', 'Hello') : _t('Bonjour $name', 'Hello $name');
  String get homeTitle => _t('Mes boards', 'My boards');
  String get projectsSection => _t('Projets', 'Projects');
  String get inspirationSection => 'Inspiration';
  String get archivedSection => _t('Archivés', 'Archived');
  String get sharedSection => _t('Partagés avec moi', 'Shared with me');
  String get emptyBoardsTitle => _t('Ton premier board t’attend', 'Your first board is waiting');
  String get emptyBoardsBody => _t(
        'Crée un board pour ranger tes idées : déco, robe, voyage… Tu pourras le passer en mode Projet plus tard.',
        'Create a board to collect ideas: decor, dress, travel… You can switch it to Project mode later.',
      );
  String get newBoard => _t('Nouveau board', 'New board');
  String inspirationsCount(int n) => n <= 1 ? _t('$n inspiration', '$n idea') : _t('$n inspirations', '$n ideas');
  String tasksProgress(int done, int total) => _t('$done/$total tâches', '$done/$total tasks');
  String daysLeft(int n) => _t('J-$n', '$n days left');
  String get dDay => _t('Jour J !', 'It’s the day!');
  String get datePassed => _t('Passé', 'Past');

  // ── Board creation ─────────────────────────────────────────────────────
  String get createBoardTitle => _t('Nouveau board', 'New board');
  String get boardName => _t('Nom du board', 'Board name');
  String get boardNameHint => _t('Ex : Mon mariage, Déco salon…', 'E.g. My wedding, Living room…');
  String get boardColor => _t('Couleur', 'Colour');
  String get boardEmoji => _t('Icône', 'Icon');
  String get modeInspiration => 'Inspiration';
  String get modeProjet => _t('Projet', 'Project');
  String get modeInspirationDesc => _t('Un espace libre pour collecter tes idées.', 'A free-form space to collect ideas.');
  String get modeProjetDesc => _t('Ajoute la planification : date, checklist et prestataires.', 'Adds planning: date, checklist and vendors.');
  String get eventTypeLabel => _t('Type d’événement', 'Event type');
  String get targetDateLabel => _t('Date de l’événement', 'Event date');
  String get pickDate => _t('Choisir une date', 'Pick a date');
  String get addTemplateChecklist => _t('Ajouter la checklist modèle', 'Add the template checklist');
  String get createBoard => _t('Créer le board', 'Create board');
  String get nameRequired => _t('Donne un nom à ton board', 'Give your board a name');

  String get eventMariage => _t('Mariage', 'Wedding');
  String get eventBabyShower => 'Baby shower';
  String get eventAnniversaire => _t('Anniversaire', 'Birthday');
  String get eventCremaillere => _t('Crémaillère', 'Housewarming');
  String get eventEvjf => _t('EVJF', 'Bachelorette');
  String get eventDemenagement => _t('Déménagement', 'Moving');
  String get eventAutre => _t('Autre', 'Other');

  // ── Board screen ───────────────────────────────────────────────────────
  String get tabInspiration => 'Inspiration';
  String get tabPlanning => _t('Planification', 'Planning');
  String get unsorted => _t('Non classé', 'Unsorted');
  String get addSection => _t('Section', 'Section');
  String get newSection => _t('Nouvelle section', 'New section');
  String get sectionName => _t('Nom de la section', 'Section name');
  String get renameSection => _t('Renommer', 'Rename');
  String get deleteSection => _t('Supprimer la section', 'Delete section');
  String get deleteSectionBody => _t('Les inspirations sont conservées et passent dans « Non classé ».',
      'Ideas are kept and moved to “Unsorted”.');
  String get emptySectionTitle => _t('Rien ici pour l’instant', 'Nothing here yet');
  String get emptySectionBody => _t('Ajoute une photo, un lien ou une note.', 'Add a photo, a link or a note.');
  String get addPhoto => _t('Photo', 'Photo');
  String get addPhotoDesc => _t('Depuis ta galerie', 'From your gallery');
  String get addLink => _t('Lien', 'Link');
  String get addLinkDesc => _t('Instagram, TikTok, Pinterest, site…', 'Instagram, TikTok, Pinterest, website…');
  String get addNote => _t('Note', 'Note');
  String get addNoteDesc => _t('Une idée, une liste, un mot', 'An idea, a list, a word');
  String get addVendor => _t('Prestataire', 'Vendor');
  String get addVendorDesc => _t('Fleuriste, photographe, lieu…', 'Florist, photographer, venue…');
  String get pasteLink => _t('Colle un lien', 'Paste a link');
  String get linkInvalid => _t('Ce lien ne semble pas valide', 'This link doesn’t look valid');
  String get fetchingPreview => _t('Récupération de l’aperçu…', 'Fetching preview…');
  String get noteHint => _t('Écris ton idée…', 'Write your idea…');
  String get titleHint => _t('Titre (optionnel)', 'Title (optional)');
  String get moveTo => _t('Déplacer vers…', 'Move to…');
  String get openLink => _t('Ouvrir le lien', 'Open link');
  String get linkVendor => _t('Lier à un prestataire', 'Link to a vendor');
  String get unlinkVendor => _t('Délier le prestataire', 'Unlink vendor');
  String get cardDeleted => _t('Inspiration supprimée', 'Idea deleted');
  String get uploadFailed => _t('Envoi de l’image impossible', 'Image upload failed');
  String get shareBoard => _t('Partager', 'Share');
  String get boardNotFound => _t('Ce board n’existe plus ou ne t’est pas accessible.', 'This board no longer exists or isn’t available to you.');
  String get sharedBadge => _t('Partagé', 'Shared');

  // ── Planning ───────────────────────────────────────────────────────────
  String get noDate => _t('Pas encore de date', 'No date yet');
  String get setDate => _t('Fixer la date', 'Set the date');
  String get checklist => _t('Checklist', 'Checklist');
  String get vendors => _t('Prestataires', 'Vendors');
  String get noTasksTitle => _t('Pas encore de checklist', 'No checklist yet');
  String get noTasksBody => _t('Pars d’un modèle adapté à ton événement ou crée tes propres tâches.',
      'Start from a template for your event or create your own tasks.');
  String applyTemplate(String type) => _t('Utiliser le modèle « $type »', 'Use the “$type” template');
  String get addTask => _t('Ajouter une tâche', 'Add a task');
  String get taskHint => _t('Nouvelle tâche…', 'New task…');
  String get dueDate => _t('Échéance', 'Due date');
  String get noVendorsTitle => _t('Aucun prestataire', 'No vendors yet');
  String get noVendorsBody => _t('Ajoute les prestataires que tu repères, suis leur statut jusqu’au « Confirmé ».',
      'Add the vendors you find and track them until “Confirmed”.');
  String get overdue => _t('En retard', 'Overdue');
  String get noDueDate => _t('Sans date', 'No date');
  String get deleteTask => _t('Supprimer la tâche', 'Delete task');
  String get budgetEstimated => _t('Budget estimé', 'Estimated budget');
  String get confirmedVendors => _t('confirmés', 'confirmed');

  String get statusDecouvert => _t('Découvert', 'Discovered');
  String get statusContacte => _t('Contacté', 'Contacted');
  String get statusDevis => _t('Devis reçu', 'Quote received');
  String get statusConfirme => _t('Confirmé', 'Confirmed');
  String get statusEcarte => _t('Écarté', 'Declined');

  // ── Board settings ─────────────────────────────────────────────────────
  String get boardSettings => _t('Réglages du board', 'Board settings');
  String get switchToProjet => _t('Passer en mode Projet', 'Switch to Project mode');
  String get switchToProjetDesc => _t('Débloque la planification : date, checklist, suivi des prestataires.',
      'Unlocks planning: date, checklist, vendor tracking.');
  String get switchToInspiration => _t('Revenir en mode Inspiration', 'Back to Inspiration mode');
  String get archiveBoard => _t('Archiver', 'Archive');
  String get unarchiveBoard => _t('Désarchiver', 'Unarchive');
  String get deleteBoard => _t('Supprimer le board', 'Delete board');
  String get deleteBoardBody => _t('Inspirations, sections et tâches de ce board seront supprimées. Tes contacts sont conservés.',
      'This board’s ideas, sections and tasks will be deleted. Your contacts are kept.');
  String get leaveBoard => _t('Quitter ce board', 'Leave this board');
  String get ownerOnly => _t('Seule la propriétaire du board peut modifier ces réglages.', 'Only the board owner can change these settings.');

  // ── Share links ────────────────────────────────────────────────────────
  String shareTitle(String name) => _t('Partager « $name »', 'Share “$name”');
  String get shareBody => _t('Ton espace reste privé. Seules les personnes qui ont le lien voient ce board.',
      'Your space stays private. Only people with the link can see this board.');
  String get readLink => _t('Lien en lecture seule', 'Read-only link');
  String get readLinkDesc => _t('Pour montrer ton board à ta témoin, ta mère, ton fleuriste…', 'Show your board to your maid of honour, your mum, your florist…');
  String get editLink => _t('Lien collaboratif', 'Collaborative link');
  String get editLinkDesc => _t('Les invitées connectées peuvent ajouter et modifier des inspirations.', 'Signed-in guests can add and edit ideas.');
  String get createLink => _t('Créer le lien', 'Create link');
  String get copyLink => _t('Copier', 'Copy');
  String get linkCopied => _t('Lien copié', 'Link copied');
  String get revokeLink => _t('Désactiver', 'Disable');
  String get premiumBadge => 'Premium';

  // ── Contacts ───────────────────────────────────────────────────────────
  String get contactsTitle => 'Contacts';
  String get contactsSubtitle => _t('Tous tes prestataires, tous projets confondus', 'All your vendors, across every project');
  String get searchContacts => _t('Rechercher un prestataire…', 'Search vendors…');
  String get emptyContactsTitle => _t('Ton carnet est vide', 'Your address book is empty');
  String get emptyContactsBody => _t('Ajoute un prestataire ou partage son profil Instagram vers Keevy.',
      'Add a vendor or share their Instagram profile to Keevy.');
  String get newContact => _t('Nouveau prestataire', 'New vendor');
  String get editContact => _t('Modifier le prestataire', 'Edit vendor');
  String get contactName => _t('Nom', 'Name');
  String get profession => _t('Métier', 'Trade');
  String get professionHint => _t('Fleuriste, photographe, traiteur…', 'Florist, photographer, caterer…');
  String get phone => _t('Téléphone', 'Phone');
  String get email => 'Email';
  String get instagram => 'Instagram';
  String get tiktok => 'TikTok';
  String get website => _t('Site web', 'Website');
  String get recommendedBy => _t('Recommandé par', 'Recommended by');
  String get notes => 'Notes';
  String get priceEstimate => _t('Prix estimé', 'Estimated price');
  String get call => _t('Appeler', 'Call');
  String get contactBoards => 'Boards';
  String get miniBoard => _t('Mini-board', 'Mini-board');
  String get miniBoardEmpty => _t('Lie des inspirations à ce prestataire depuis un board.', 'Link ideas to this vendor from a board.');
  String get linkedTasks => _t('Tâches liées', 'Linked tasks');
  String get addToBoard => _t('Ajouter à un board', 'Add to a board');
  String get removeFromBoard => _t('Retirer du board', 'Remove from board');
  String get deleteContact => _t('Supprimer le prestataire', 'Delete vendor');
  String get deleteContactBody => _t('Il sera retiré de tous tes boards. Les inspirations liées sont conservées.',
      'It will be removed from all your boards. Linked ideas are kept.');
  String get contactExists => _t('Ce prestataire était déjà dans ton carnet, on l’a retrouvé.', 'This vendor was already in your address book.');
  String get nameIsRequired => _t('Le nom est obligatoire', 'Name is required');

  // ── Links ──────────────────────────────────────────────────────────────
  String get linksTitle => _t('Liens', 'Links');
  String get linksSubtitle => _t('Tous les liens sauvegardés', 'Every saved link');
  String get searchLinks => _t('Rechercher un lien…', 'Search links…');
  String get emptyLinksTitle => _t('Aucun lien pour l’instant', 'No links yet');
  String get emptyLinksBody => _t('Partage un reel, un TikTok ou une page vers Keevy, il apparaîtra ici.',
      'Share a reel, a TikTok or a page to Keevy and it will show up here.');
  String get openBoard => _t('Voir le board', 'Open board');

  // ── Share intake ───────────────────────────────────────────────────────
  String get shareSheetTitle => _t('Enregistrer dans Keevy', 'Save to Keevy');
  String get shareAsInspiration => _t('Une inspiration', 'An idea');
  String get shareAsInspirationDesc => _t('Photo, reel, idée à garder', 'Photo, reel, something to keep');
  String get shareAsVendor => _t('Un prestataire', 'A vendor');
  String get shareAsVendorDesc => _t('Fleuriste, photographe, lieu…', 'Florist, photographer, venue…');
  String get chooseBoard => _t('Choisis un board', 'Pick a board');
  String get chooseSection => _t('Section', 'Section');
  String get noSection => _t('Sans section', 'No section');
  String get addNoteOptional => _t('Ajouter une note (optionnel)', 'Add a note (optional)');
  String savedTo(String board) => _t('Enregistré dans $board', 'Saved to $board');
  String importedFromShare(int n) => _t('$n partage(s) importé(s)', '$n shared item(s) imported');
  String detected(String what) => _t('Détecté : $what', 'Detected: $what');
  String get needLogin => _t('Connecte-toi pour enregistrer ce partage.', 'Sign in to save this item.');

  // ── Settings ───────────────────────────────────────────────────────────
  String get settingsTitle => _t('Réglages', 'Settings');
  String get account => _t('Compte', 'Account');
  String get displayName => _t('Prénom', 'First name');
  String get planFree => _t('Plan gratuit', 'Free plan');
  String get planFreeDesc => _t('3 boards Projet actifs, liens en lecture seule', '3 active Project boards, read-only links');
  String get planPremium => 'Keevy Premium';
  String get upgrade => _t('Passer Premium', 'Go Premium');
  String get language => _t('Langue', 'Language');
  String get languageSystem => _t('Langue de l’appareil', 'Device language');
  String get shareExtensionHelp => _t('Ajouter Keevy au menu Partager', 'Add Keevy to the Share menu');
  String get shareExtensionHelpBody => _t(
        'Dans Instagram, TikTok ou Safari, touche « Partager », fais défiler les apps, touche « Plus » puis active Keevy. Sur Android, Keevy apparaît directement.',
        'In Instagram, TikTok or Safari, tap “Share”, scroll the apps, tap “More” and enable Keevy. On Android, Keevy shows up directly.',
      );
  String get privacy => _t('Confidentialité', 'Privacy');
  String get terms => _t('Conditions d’utilisation', 'Terms of use');
  String get signOut => _t('Se déconnecter', 'Sign out');
  String get deleteAccount => _t('Supprimer mon compte', 'Delete my account');
  String get deleteAccountBody => _t('Tous tes boards, contacts et images seront définitivement supprimés. Cette action est irréversible.',
      'All your boards, contacts and images will be permanently deleted. This cannot be undone.');
  String get deleteAccountConfirm => _t('Supprimer définitivement', 'Delete permanently');
  String version(String v) => 'Version $v';

  // ── Paywall ────────────────────────────────────────────────────────────
  String get paywallTitle => 'Keevy Premium';
  String get paywallSubtitle => _t('Planifie tous tes moments, sans limite.', 'Plan all your moments, without limits.');
  String get benefitUnlimitedProjets => _t('Boards Projet illimités', 'Unlimited Project boards');
  String get benefitCollab => _t('Liens collaboratifs : planifiez à plusieurs', 'Collaborative links: plan together');
  String get benefitFuture => _t('Sync Pinterest et budget dès leur sortie', 'Pinterest sync and budget as soon as they ship');
  String get benefitIndie => _t('Tu soutiens une app indépendante, sans pub', 'You support an independent, ad-free app');
  String get monthly => _t('Mensuel', 'Monthly');
  String get yearly => _t('Annuel', 'Yearly');
  String get perMonth => _t('/mois', '/month');
  String get perYear => _t('/an', '/year');
  String get bestValue => _t('-33 %', '-33%');
  String get subscribe => _t('S’abonner', 'Subscribe');
  String get restore => _t('Restaurer mes achats', 'Restore purchases');
  String get paywallWebNote => _t('L’abonnement se prend depuis l’app iOS ou Android.', 'Subscribe from the iOS or Android app.');
  String get paywallUnavailable => _t('Les abonnements ne sont pas encore disponibles.', 'Subscriptions are not available yet.');
  String get purchaseSuccess => _t('Bienvenue dans Keevy Premium ✨', 'Welcome to Keevy Premium ✨');
  String get restoreNothing => _t('Aucun abonnement à restaurer', 'No subscription to restore');
  String get alreadyPremium => _t('Tu es Premium. Merci ✨', 'You’re Premium. Thank you ✨');
  String get legalSubscription => _t(
        'Renouvellement automatique, annulable à tout moment depuis les réglages de ton store.',
        'Auto-renews, cancel anytime from your store settings.',
      );

  String get limitProjetTitle => _t('Limite du plan gratuit', 'Free plan limit');
  String get limitProjetBody => _t('Le plan gratuit inclut 3 boards Projet actifs. Passe Premium ou archive un projet terminé.',
      'The free plan includes 3 active Project boards. Go Premium or archive a finished project.');
  String get premiumRequiredEditShare => _t('Les liens collaboratifs font partie de Keevy Premium.', 'Collaborative links are part of Keevy Premium.');

  // ── Shared board viewer ────────────────────────────────────────────────
  String sharedBoardBy(String name) => _t('Board de $name', '$name’s board');
  String get sharedLinkInvalid => _t('Ce lien n’est plus actif.', 'This link is no longer active.');
  String get joinBoard => _t('Rejoindre ce board', 'Join this board');
  String get joinedBoard => _t('Tu as rejoint le board ✨', 'You joined the board ✨');
  String get createYourKeevy => _t('Crée ton Keevy', 'Create your Keevy');
  String get readOnly => _t('Lecture seule', 'Read only');
}
