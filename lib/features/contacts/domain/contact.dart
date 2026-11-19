import 'package:flutter/painting.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../boards/domain/board.dart';

enum VendorStatus {
  decouvert(KColors.purple),
  contacte(KColors.info),
  devis(KColors.warn),
  confirme(KColors.ok),
  ecarte(KColors.err);

  const VendorStatus(this.color);
  final Color color;

  static VendorStatus fromId(String? id) =>
      VendorStatus.values.firstWhere((s) => s.name == id, orElse: () => VendorStatus.decouvert);
}

/// A contact's presence on a board (board_contacts row + board info).
class BoardContactLink {
  const BoardContactLink({
    required this.boardId,
    required this.contactId,
    this.status = VendorStatus.decouvert,
    this.priceEstimate,
    this.currency = 'EUR',
    this.notes,
    this.boardName,
    this.boardColor,
    this.boardMode,
  });

  final String boardId;
  final String contactId;
  final VendorStatus status;
  final double? priceEstimate;
  final String currency;
  final String? notes;
  final String? boardName;
  final Color? boardColor;
  final BoardMode? boardMode;

  bool get showsStatus => boardMode == BoardMode.projet;

  factory BoardContactLink.fromJson(Map<String, dynamic> json) {
    final board = json['boards'];
    return BoardContactLink(
      boardId: json['board_id'] as String,
      contactId: json['contact_id'] as String,
      status: VendorStatus.fromId(json['status'] as String?),
      priceEstimate: (json['price_estimate'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      notes: json['notes'] as String?,
      boardName: board is Map<String, dynamic> ? board['name'] as String? : null,
      boardColor: board is Map<String, dynamic> ? colorFromHex(board['color'] as String?) : null,
      boardMode: board is Map<String, dynamic>
          ? (board['mode'] == 'projet' ? BoardMode.projet : BoardMode.inspiration)
          : null,
    );
  }

  BoardContactLink copyWith({VendorStatus? status, double? priceEstimate, bool clearPrice = false, String? notes}) =>
      BoardContactLink(
        boardId: boardId,
        contactId: contactId,
        status: status ?? this.status,
        priceEstimate: clearPrice ? null : (priceEstimate ?? this.priceEstimate),
        currency: currency,
        notes: notes ?? this.notes,
        boardName: boardName,
        boardColor: boardColor,
        boardMode: boardMode,
      );
}

class Contact {
  const Contact({
    required this.id,
    required this.ownerId,
    required this.name,
    this.profession,
    this.phone,
    this.email,
    this.instagram,
    this.tiktok,
    this.website,
    this.recommendedBy,
    this.notes,
    this.avatarUrl,
    this.identifierHash,
    this.createdAt,
    this.links = const [],
  });

  final String id;
  final String ownerId;
  final String name;
  final String? profession;
  final String? phone;
  final String? email;
  final String? instagram;
  final String? tiktok;
  final String? website;
  final String? recommendedBy;
  final String? notes;
  final String? avatarUrl;
  final String? identifierHash;
  final DateTime? createdAt;
  final List<BoardContactLink> links;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String firstRunes(String v, int n) => String.fromCharCodes(v.runes.take(n));
    if (parts.length == 1) return firstRunes(parts.first, 2).toUpperCase();
    return (firstRunes(parts[0], 1) + firstRunes(parts[1], 1)).toUpperCase();
  }

  /// Most advanced status across Projet boards (for the global list).
  VendorStatus? get bestStatus {
    final statuses = links.where((l) => l.showsStatus).map((l) => l.status).toList();
    if (statuses.isEmpty) return null;
    const order = [VendorStatus.confirme, VendorStatus.devis, VendorStatus.contacte, VendorStatus.decouvert, VendorStatus.ecarte];
    for (final s in order) {
      if (statuses.contains(s)) return s;
    }
    return statuses.first;
  }

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        profession: json['profession'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        instagram: json['instagram'] as String?,
        tiktok: json['tiktok'] as String?,
        website: json['website'] as String?,
        recommendedBy: json['recommended_by'] as String?,
        notes: json['notes'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        identifierHash: json['identifier_hash'] as String?,
        createdAt: parseDate(json['created_at']),
        links: (json['board_contacts'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(BoardContactLink.fromJson)
            .toList(),
      );

  Map<String, dynamic> toWrite() => {
        'name': name,
        'profession': _nullIfBlank(profession),
        'phone': _nullIfBlank(phone),
        'email': _nullIfBlank(email),
        'instagram': _nullIfBlank(instagram),
        'tiktok': _nullIfBlank(tiktok),
        'website': _nullIfBlank(website),
        'recommended_by': _nullIfBlank(recommendedBy),
        'notes': _nullIfBlank(notes),
        'avatar_url': avatarUrl,
        'identifier_hash': identifierHash,
      };

  static String? _nullIfBlank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

/// Draft used by forms and the share flow before the contact exists.
class ContactDraft {
  const ContactDraft({
    this.name = '',
    this.profession,
    this.phone,
    this.email,
    this.instagram,
    this.tiktok,
    this.website,
    this.recommendedBy,
    this.notes,
  });

  final String name;
  final String? profession;
  final String? phone;
  final String? email;
  final String? instagram;
  final String? tiktok;
  final String? website;
  final String? recommendedBy;
  final String? notes;

  factory ContactDraft.fromContact(Contact c) => ContactDraft(
        name: c.name,
        profession: c.profession,
        phone: c.phone,
        email: c.email,
        instagram: c.instagram,
        tiktok: c.tiktok,
        website: c.website,
        recommendedBy: c.recommendedBy,
        notes: c.notes,
      );
}
