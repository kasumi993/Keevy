import '../../boards/domain/board.dart';

/// One task of a checklist template. [daysBefore] is relative to the event date.
class TemplateTask {
  const TemplateTask(this.daysBefore, this.fr, this.en);
  final int daysBefore;
  final String fr;
  final String en;

  String title(bool isFr) => isFr ? fr : en;
}

class ChecklistTemplate {
  const ChecklistTemplate(this.type, this.tasks);
  final EventType type;
  final List<TemplateTask> tasks;

  String get key => 'tpl_${type.id}';

  /// Due date for a task, or null when the board has no date yet.
  /// Dates already in the past are clamped to today so nothing is born overdue.
  DateTime? dueDateFor(TemplateTask task, DateTime? target, {DateTime? now}) {
    if (target == null) return null;
    final due = DateTime(target.year, target.month, target.day).subtract(Duration(days: task.daysBefore));
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return due.isBefore(todayDate) ? todayDate : due;
  }
}

class ChecklistTemplates {
  ChecklistTemplates._();

  static ChecklistTemplate forType(EventType? type) {
    final t = type ?? EventType.autre;
    return _all.firstWhere((tpl) => tpl.type == t, orElse: () => _all.last);
  }

  static const _all = <ChecklistTemplate>[
    ChecklistTemplate(EventType.mariage, [
      TemplateTask(365, 'Fixer le budget global', 'Set the overall budget'),
      TemplateTask(360, 'Établir une première liste d’invités', 'Draft the guest list'),
      TemplateTask(330, 'Réserver le lieu de réception', 'Book the venue'),
      TemplateTask(300, 'Choisir les témoins', 'Choose the witnesses'),
      TemplateTask(300, 'Réserver photographe et vidéaste', 'Book photographer and videographer'),
      TemplateTask(270, 'Choisir le traiteur', 'Choose the caterer'),
      TemplateTask(240, 'Commencer les essayages de robe', 'Start dress fittings'),
      TemplateTask(240, 'Réserver DJ ou groupe', 'Book DJ or band'),
      TemplateTask(210, 'Envoyer les save-the-date', 'Send the save-the-dates'),
      TemplateTask(180, 'Choisir le fleuriste', 'Choose the florist'),
      TemplateTask(180, 'Réserver la mairie / la cérémonie', 'Book the town hall / ceremony'),
      TemplateTask(150, 'Commander les faire-part', 'Order the invitations'),
      TemplateTask(120, 'Choisir les alliances', 'Choose the rings'),
      TemplateTask(120, 'Organiser l’hébergement des invités', 'Arrange guest accommodation'),
      TemplateTask(90, 'Envoyer les faire-part', 'Send the invitations'),
      TemplateTask(90, 'Réserver coiffure et maquillage', 'Book hair and make-up'),
      TemplateTask(60, 'Déposer le dossier de mariage en mairie', 'File the marriage paperwork'),
      TemplateTask(60, 'Valider le menu et faire la dégustation', 'Confirm menu and tasting'),
      TemplateTask(45, 'Préparer la playlist', 'Prepare the playlist'),
      TemplateTask(30, 'Faire le plan de table', 'Make the seating plan'),
      TemplateTask(30, 'Dernier essayage de la robe', 'Final dress fitting'),
      TemplateTask(14, 'Confirmer les horaires avec chaque prestataire', 'Confirm timings with every vendor'),
      TemplateTask(7, 'Préparer les enveloppes de paiement', 'Prepare vendor payments'),
      TemplateTask(2, 'Préparer la valise de la nuit de noces', 'Pack the wedding-night bag'),
    ]),
    ChecklistTemplate(EventType.babyShower, [
      TemplateTask(60, 'Choisir la date avec la future maman', 'Pick the date with the mum-to-be'),
      TemplateTask(50, 'Faire la liste des invitées', 'Make the guest list'),
      TemplateTask(45, 'Choisir le thème et les couleurs', 'Choose theme and colours'),
      TemplateTask(40, 'Réserver le lieu', 'Book the venue'),
      TemplateTask(35, 'Envoyer les invitations', 'Send the invitations'),
      TemplateTask(30, 'Créer la liste de naissance', 'Set up the baby registry'),
      TemplateTask(21, 'Commander le gâteau', 'Order the cake'),
      TemplateTask(14, 'Préparer les jeux', 'Prepare the games'),
      TemplateTask(10, 'Acheter la déco', 'Buy the decorations'),
      TemplateTask(7, 'Prévoir le menu et les boissons', 'Plan food and drinks'),
      TemplateTask(3, 'Confirmer les présences', 'Confirm attendance'),
      TemplateTask(1, 'Installer la déco', 'Set up the decorations'),
    ]),
    ChecklistTemplate(EventType.anniversaire, [
      TemplateTask(45, 'Fixer le budget', 'Set the budget'),
      TemplateTask(40, 'Choisir le thème', 'Choose the theme'),
      TemplateTask(35, 'Réserver le lieu', 'Book the venue'),
      TemplateTask(30, 'Envoyer les invitations', 'Send the invitations'),
      TemplateTask(21, 'Commander le gâteau', 'Order the cake'),
      TemplateTask(14, 'Prévoir les animations', 'Plan the entertainment'),
      TemplateTask(10, 'Acheter la déco', 'Buy the decorations'),
      TemplateTask(7, 'Préparer la playlist', 'Prepare the playlist'),
      TemplateTask(3, 'Faire les courses', 'Do the shopping'),
      TemplateTask(1, 'Confirmer les présences', 'Confirm attendance'),
    ]),
    ChecklistTemplate(EventType.cremaillere, [
      TemplateTask(30, 'Choisir la date', 'Pick the date'),
      TemplateTask(25, 'Prévenir les voisins', 'Let the neighbours know'),
      TemplateTask(21, 'Envoyer les invitations', 'Send the invitations'),
      TemplateTask(14, 'Prévoir le menu apéro', 'Plan the food'),
      TemplateTask(10, 'Louer ou emprunter verres et chaises', 'Rent or borrow glasses and chairs'),
      TemplateTask(7, 'Préparer la playlist', 'Prepare the playlist'),
      TemplateTask(3, 'Faire les courses', 'Do the shopping'),
      TemplateTask(1, 'Ranger et décorer', 'Tidy up and decorate'),
    ]),
    ChecklistTemplate(EventType.evjf, [
      TemplateTask(90, 'Créer le groupe avec les témoins', 'Create the group with the bridesmaids'),
      TemplateTask(80, 'Fixer le budget par personne', 'Set the budget per person'),
      TemplateTask(75, 'Choisir la destination', 'Choose the destination'),
      TemplateTask(60, 'Réserver l’hébergement', 'Book accommodation'),
      TemplateTask(45, 'Réserver les activités', 'Book the activities'),
      TemplateTask(30, 'Organiser les transports', 'Arrange transport'),
      TemplateTask(21, 'Commander tenues et accessoires', 'Order outfits and accessories'),
      TemplateTask(14, 'Préparer les jeux et surprises', 'Prepare games and surprises'),
      TemplateTask(7, 'Collecter les participations', 'Collect contributions'),
      TemplateTask(2, 'Partager le programme final', 'Share the final schedule'),
    ]),
    ChecklistTemplate(EventType.demenagement, [
      TemplateTask(60, 'Donner son préavis', 'Give notice'),
      TemplateTask(45, 'Demander des devis de déménageurs', 'Get quotes from movers'),
      TemplateTask(40, 'Trier et vendre ce qu’on ne garde pas', 'Sort and sell what you don’t keep'),
      TemplateTask(30, 'Réserver le déménageur ou l’utilitaire', 'Book movers or a van'),
      TemplateTask(30, 'Transférer électricité, gaz et internet', 'Transfer utilities and internet'),
      TemplateTask(21, 'Acheter cartons et adhésif', 'Buy boxes and tape'),
      TemplateTask(14, 'Faire suivre le courrier', 'Set up mail forwarding'),
      TemplateTask(14, 'Prévenir banque, employeur, assurances', 'Notify bank, employer, insurers'),
      TemplateTask(7, 'Faire les cartons pièce par pièce', 'Pack room by room'),
      TemplateTask(2, 'Préparer un carton « première nuit »', 'Pack a first-night box'),
      TemplateTask(0, 'État des lieux de sortie', 'Move-out inspection'),
    ]),
    ChecklistTemplate(EventType.autre, [
      TemplateTask(60, 'Fixer le budget', 'Set the budget'),
      TemplateTask(45, 'Faire la liste des invités', 'Make the guest list'),
      TemplateTask(30, 'Réserver le lieu', 'Book the venue'),
      TemplateTask(21, 'Envoyer les invitations', 'Send the invitations'),
      TemplateTask(14, 'Réserver les prestataires', 'Book the vendors'),
      TemplateTask(7, 'Confirmer les présences', 'Confirm attendance'),
      TemplateTask(1, 'Derniers préparatifs', 'Final preparations'),
    ]),
  ];
}
