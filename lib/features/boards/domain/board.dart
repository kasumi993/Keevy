import 'package:flutter/painting.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';

enum BoardMode { inspiration, projet }

enum EventType {
  mariage('mariage', '💍'),
  babyShower('baby_shower', '🍼'),
  anniversaire('anniversaire', '🎂'),
  cremaillere('cremaillere', '🏡'),
  evjf('evjf', '🥂'),
  demenagement('demenagement', '📦'),
  autre('autre', '✨');

  const EventType(this.id, this.emoji);
  final String id;
  final String emoji;

  static EventType? fromId(String? id) {
    if (id == null) return null;
    for (final t in EventType.values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Image reference: either a private storage path (gallery upload) or a remote URL.
class ImageRef {
  const ImageRef({this.path, this.url});
  final String? path;
  final String? url;

  bool get isEmpty => path == null && url == null;

  factory ImageRef.fromJson(Map<String, dynamic> json) =>
      ImageRef(path: json['image_path'] as String?, url: json['image_url'] as String?);
}

class Board {
  const Board({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.color,
    required this.mode,
    this.emoji,
    this.eventType,
    this.targetDate,
    this.position = 0,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
    this.isOwner = true,
    this.cardCount = 0,
    this.contactCount = 0,
    this.taskCount = 0,
    this.taskDoneCount = 0,
    this.previews = const [],
  });

  final String id;
  final String ownerId;
  final String name;
  final Color color;
  final BoardMode mode;
  final String? emoji;
  final EventType? eventType;
  final DateTime? targetDate;
  final double position;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Overview fields (board_overview view)
  final bool isOwner;
  final int cardCount;
  final int contactCount;
  final int taskCount;
  final int taskDoneCount;
  final List<ImageRef> previews;

  bool get isProjet => mode == BoardMode.projet;
  bool get isArchived => archivedAt != null;
  String get displayEmoji => emoji ?? eventType?.emoji ?? '✨';
  double get progress => taskCount == 0 ? 0 : taskDoneCount / taskCount;

  factory Board.fromJson(Map<String, dynamic> json) {
    final previews = (json['previews'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ImageRef.fromJson)
        .where((r) => !r.isEmpty)
        .toList();
    return Board(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: colorFromHex(json['color'] as String?),
      mode: json['mode'] == 'projet' ? BoardMode.projet : BoardMode.inspiration,
      emoji: json['emoji'] as String?,
      eventType: EventType.fromId(json['event_type'] as String?),
      targetDate: parseDate(json['target_date']),
      position: (json['position'] as num?)?.toDouble() ?? 0,
      archivedAt: parseDate(json['archived_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      isOwner: json['is_owner'] as bool? ?? true,
      cardCount: (json['card_count'] as num?)?.toInt() ?? 0,
      contactCount: (json['contact_count'] as num?)?.toInt() ?? 0,
      taskCount: (json['task_count'] as num?)?.toInt() ?? 0,
      taskDoneCount: (json['task_done_count'] as num?)?.toInt() ?? 0,
      previews: previews,
    );
  }

  Board copyWith({
    String? name,
    Color? color,
    BoardMode? mode,
    String? emoji,
    EventType? eventType,
    bool clearEventType = false,
    DateTime? targetDate,
    bool clearTargetDate = false,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    int? cardCount,
    int? contactCount,
    int? taskCount,
    int? taskDoneCount,
  }) {
    return Board(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      color: color ?? this.color,
      mode: mode ?? this.mode,
      emoji: emoji ?? this.emoji,
      eventType: clearEventType ? null : (eventType ?? this.eventType),
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      position: position,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isOwner: isOwner,
      cardCount: cardCount ?? this.cardCount,
      contactCount: contactCount ?? this.contactCount,
      taskCount: taskCount ?? this.taskCount,
      taskDoneCount: taskDoneCount ?? this.taskDoneCount,
      previews: previews,
    );
  }
}

/// Default sections proposed when creating a board.
List<String> defaultSectionsFor(EventType? type, {required bool isFr}) {
  List<String> pick(List<String> fr, List<String> en) => isFr ? fr : en;
  return switch (type) {
    EventType.mariage => pick(['Robe', 'Lieu', 'Fleurs', 'Déco', 'Traiteur'], ['Dress', 'Venue', 'Flowers', 'Decor', 'Catering']),
    EventType.babyShower => pick(['Déco', 'Gâteau', 'Jeux', 'Cadeaux'], ['Decor', 'Cake', 'Games', 'Gifts']),
    EventType.anniversaire => pick(['Thème', 'Gâteau', 'Lieu', 'Tenue'], ['Theme', 'Cake', 'Venue', 'Outfit']),
    EventType.cremaillere => pick(['Déco', 'Apéro', 'Playlist'], ['Decor', 'Drinks', 'Playlist']),
    EventType.evjf => pick(['Destination', 'Activités', 'Tenues'], ['Destination', 'Activities', 'Outfits']),
    EventType.demenagement => pick(['Déco', 'Meubles', 'Démarches'], ['Decor', 'Furniture', 'Paperwork']),
    EventType.autre => pick(['Idées'], ['Ideas']),
    null => pick(['Idées'], ['Ideas']),
  };
}
