import 'package:flutter/painting.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/link_detector.dart';

enum CardKind { image, link, note }

/// An inspiration card (named CardItem to avoid clashing with Material's Card).
class CardItem {
  const CardItem({
    required this.id,
    required this.boardId,
    required this.kind,
    this.sectionId,
    this.title,
    this.body,
    this.url,
    this.imagePath,
    this.imageUrl,
    this.imageWidth,
    this.imageHeight,
    this.source,
    this.domain,
    this.contactId,
    this.position = 0,
    this.createdAt,
    this.boardName,
    this.boardColor,
    this.signedImageUrl,
  });

  final String id;
  final String boardId;
  final CardKind kind;
  final String? sectionId;
  final String? title;
  final String? body;
  final String? url;
  final String? imagePath;
  final String? imageUrl;
  final int? imageWidth;
  final int? imageHeight;
  final String? source;
  final String? domain;
  final String? contactId;
  final double position;
  final DateTime? createdAt;

  // Joined fields (links tab).
  final String? boardName;
  final Color? boardColor;

  // Pre-signed URL (public shared-board viewer).
  final String? signedImageUrl;

  bool get hasImage => imagePath != null || imageUrl != null || signedImageUrl != null;
  LinkSource get linkSource => LinkSourceX.fromId(source);

  double? get aspectRatio {
    final w = imageWidth, h = imageHeight;
    if (w == null || h == null || w == 0 || h == 0) return null;
    return (w / h).clamp(0.5, 1.8);
  }

  factory CardItem.fromJson(Map<String, dynamic> json) {
    final board = json['boards'];
    return CardItem(
      id: json['id'] as String,
      boardId: json['board_id'] as String,
      kind: CardKind.values.firstWhere((k) => k.name == json['kind'], orElse: () => CardKind.note),
      sectionId: json['section_id'] as String?,
      title: json['title'] as String?,
      body: json['body'] as String?,
      url: json['url'] as String?,
      imagePath: json['image_path'] as String?,
      imageUrl: json['image_url'] as String?,
      imageWidth: (json['image_width'] as num?)?.toInt(),
      imageHeight: (json['image_height'] as num?)?.toInt(),
      source: json['source'] as String?,
      domain: json['domain'] as String?,
      contactId: json['contact_id'] as String?,
      position: (json['position'] as num?)?.toDouble() ?? 0,
      createdAt: parseDate(json['created_at']),
      boardName: board is Map<String, dynamic> ? board['name'] as String? : null,
      boardColor: board is Map<String, dynamic> ? colorFromHex(board['color'] as String?) : null,
      signedImageUrl: json['signed_url'] as String?,
    );
  }

  /// Columns written on insert/update.
  Map<String, dynamic> toInsert() => {
        'id': id,
        'board_id': boardId,
        'section_id': sectionId,
        'kind': kind.name,
        'title': title,
        'body': body,
        'url': url,
        'image_path': imagePath,
        'image_url': imageUrl,
        'image_width': imageWidth,
        'image_height': imageHeight,
        'source': source,
        'domain': domain,
        'contact_id': contactId,
        'position': position,
      };

  CardItem copyWith({
    String? sectionId,
    bool clearSection = false,
    String? title,
    String? body,
    String? contactId,
    bool clearContact = false,
    double? position,
  }) {
    return CardItem(
      id: id,
      boardId: boardId,
      kind: kind,
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      title: title ?? this.title,
      body: body ?? this.body,
      url: url,
      imagePath: imagePath,
      imageUrl: imageUrl,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      source: source,
      domain: domain,
      contactId: clearContact ? null : (contactId ?? this.contactId),
      position: position ?? this.position,
      createdAt: createdAt,
      boardName: boardName,
      boardColor: boardColor,
      signedImageUrl: signedImageUrl,
    );
  }
}

/// Result of the link-preview Edge Function.
class LinkPreview {
  const LinkPreview({required this.url, this.title, this.description, this.image, this.domain, this.siteName, this.source});

  final String url;
  final String? title;
  final String? description;
  final String? image;
  final String? domain;
  final String? siteName;
  final String? source;

  factory LinkPreview.fromJson(Map<String, dynamic> json, String fallbackUrl) => LinkPreview(
        url: json['finalUrl'] as String? ?? json['url'] as String? ?? fallbackUrl,
        title: json['title'] as String?,
        description: json['description'] as String?,
        image: json['image'] as String?,
        domain: json['domain'] as String?,
        siteName: json['siteName'] as String?,
        source: json['source'] as String?,
      );

  factory LinkPreview.offline(String url) => LinkPreview(
        url: url,
        domain: LinkDetector.hostOf(url),
        source: LinkDetector.sourceOf(url).id,
      );
}
