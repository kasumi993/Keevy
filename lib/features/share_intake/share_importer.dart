import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/link_detector.dart';
import '../boards/application/boards_providers.dart';
import '../boards/data/cards_repository.dart';
import '../boards/domain/card_item.dart';
import '../contacts/application/contacts_providers.dart';
import '../contacts/domain/contact.dart';
import 'share_channel.dart';

/// Turns shared items (or in-app additions) into cards and contacts.
class ShareImporter {
  ShareImporter(this._ref);
  final Ref _ref;

  CardsRepository get _cards => _ref.read(cardsRepositoryProvider);

  /// Builds (but does not insert) a card draft from raw text: link with preview, or note.
  Future<CardItem> draftFromText({
    required String boardId,
    String? sectionId,
    required String text,
    String? note,
  }) async {
    final detected = LinkDetector.analyse(text);
    final url = detected.url;
    if (url != null) {
      final preview = await _cards.preview(url);
      final caption = detected.textWithoutUrl;
      final body = [if (note != null && note.trim().isNotEmpty) note.trim(), if (caption.isNotEmpty) caption].join('\n\n');
      return CardItem(
        id: CardsRepository.newId(),
        boardId: boardId,
        sectionId: sectionId,
        kind: CardKind.link,
        url: preview.url,
        title: _clip(preview.title, 300),
        body: body.isEmpty ? null : _clip(body, 10000),
        imageUrl: preview.image,
        domain: preview.domain ?? LinkDetector.hostOf(preview.url),
        source: preview.source ?? detected.source.id,
      );
    }
    final body = [text.trim(), if (note != null && note.trim().isNotEmpty) note.trim()].join('\n\n');
    return CardItem(
      id: CardsRepository.newId(),
      boardId: boardId,
      sectionId: sectionId,
      kind: CardKind.note,
      body: _clip(body, 10000),
      source: 'note',
    );
  }

  /// Uploads an image and builds the card draft.
  Future<CardItem> draftFromImage({
    required String boardId,
    String? sectionId,
    required Uint8List bytes,
    required String extension,
    String? note,
  }) async {
    int? width;
    int? height;
    try {
      final image = await decodeImageFromList(bytes);
      width = image.width;
      height = image.height;
      image.dispose();
    } catch (_) {
      // HEIC on some Android devices: keep going without dimensions.
    }
    final path = await _cards.uploadImage(boardId: boardId, bytes: bytes, extension: extension);
    return CardItem(
      id: CardsRepository.newId(),
      boardId: boardId,
      sectionId: sectionId,
      kind: CardKind.image,
      imagePath: path,
      imageWidth: width,
      imageHeight: height,
      body: (note == null || note.trim().isEmpty) ? null : note.trim(),
      source: 'gallery',
    );
  }

  /// Saves a shared item as an inspiration card in [boardId].
  Future<CardItem> saveInspiration(SharedItem item, {required String boardId, String? sectionId, String? note}) async {
    final CardItem draft;
    if (item.isImage) {
      final file = XFile(item.value);
      final bytes = await file.readAsBytes();
      final ext = item.value.contains('.') ? item.value.split('.').last : 'jpg';
      draft = await draftFromImage(boardId: boardId, sectionId: sectionId, bytes: bytes, extension: ext, note: note);
    } else {
      draft = await draftFromText(boardId: boardId, sectionId: sectionId, text: item.value, note: note);
    }
    final card = await _insert(draft);
    return card;
  }

  Future<CardItem> _insert(CardItem draft) async {
    // Use the live board notifier when the board is open, so the UI updates in place.
    if (_ref.exists(boardContentProvider(draft.boardId))) {
      return _ref.read(boardContentProvider(draft.boardId).notifier).addCard(draft);
    }
    final card = await _cards.insert(draft);
    unawaited(_ref.read(boardsProvider.notifier).refresh());
    return card;
  }

  /// Creates (or finds) a vendor and links it to [boardId].
  Future<({Contact contact, bool existed})> saveVendor(ContactDraft draft, {required String boardId}) {
    return _ref.read(contactsProvider.notifier).create(draft, boardId: boardId);
  }

  /// Pre-fills a vendor form from a shared text/URL.
  static ContactDraft vendorDraftFrom(String text) {
    final d = LinkDetector.analyse(text);
    final id = d.identifier;
    String? handleName(String handle) {
      final cleaned = handle.replaceAll(RegExp(r'[._]+'), ' ').trim();
      if (cleaned.isEmpty) return null;
      return cleaned.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
    }

    return switch (id?.type) {
      IdentifierType.instagram => ContactDraft(name: handleName(id!.value) ?? '', instagram: id.value),
      IdentifierType.tiktok => ContactDraft(name: handleName(id!.value) ?? '', tiktok: id.value),
      IdentifierType.email => ContactDraft(email: id!.value),
      IdentifierType.phone => ContactDraft(phone: id!.value),
      IdentifierType.website => ContactDraft(
          name: handleName(id!.value.split('.').first) ?? '',
          website: d.url ?? id.value,
        ),
      null => ContactDraft(notes: text.trim().isEmpty ? null : text.trim()),
    };
  }

  static String? _clip(String? s, int max) => s == null ? null : (s.length <= max ? s : s.substring(0, max));
}

final shareImporterProvider = Provider<ShareImporter>((ref) => ShareImporter(ref));
