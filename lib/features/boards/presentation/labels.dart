import '../../../core/l10n/strings.dart';
import '../../contacts/domain/contact.dart';
import '../domain/board.dart';

String eventTypeLabel(S s, EventType type) => switch (type) {
      EventType.mariage => s.eventMariage,
      EventType.babyShower => s.eventBabyShower,
      EventType.anniversaire => s.eventAnniversaire,
      EventType.cremaillere => s.eventCremaillere,
      EventType.evjf => s.eventEvjf,
      EventType.demenagement => s.eventDemenagement,
      EventType.autre => s.eventAutre,
    };

String vendorStatusLabel(S s, VendorStatus status) => switch (status) {
      VendorStatus.decouvert => s.statusDecouvert,
      VendorStatus.contacte => s.statusContacte,
      VendorStatus.devis => s.statusDevis,
      VendorStatus.confirme => s.statusConfirme,
      VendorStatus.ecarte => s.statusEcarte,
    };
