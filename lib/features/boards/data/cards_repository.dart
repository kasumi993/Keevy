import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/card_item.dart';
import 'boards_repository.dart';

class CardsRepository {
  CardsRepository(this._db);
  final SupabaseClient _db;
  final _signed = <String, ({String url, DateTime expires})>{};

  static const _signedTtl = Duration(hours: 6);

  Future<List<CardItem>> fetchForBoard(String boardId) async {
    final rows = await _db
        .from('cards')
        .select()
        .eq('board_id', boardId)
        .order('position', ascending: true)
        .order('created_at', ascending: false);
    final cards = rows.map(CardItem.fromJson).toList();
    await warmSignedUrls(cards.map((c) => c.imagePath).whereType<String>());
    return cards;
  }

  /// Every saved link across the user's boards (Liens tab).
  Future<List<CardItem>> fetchLinks() async {
    final rows = await _db
        .from('cards')
        .select('*, boards(name, color)')
        .eq('kind', 'link')
        .order('created_at', ascending: false)
        .limit(500);
    return rows.map(CardItem.fromJson).toList();
  }

  /// Cards linked to a vendor (their mini-board).
  Future<List<CardItem>> fetchForContact(String contactId) async {
    final rows = await _db
        .from('cards')
        .select('*, boards(name, color)')
        .eq('contact_id', contactId)
        .order('created_at', ascending: false);
    final cards = rows.map(CardItem.fromJson).toList();
    await warmSignedUrls(cards.map((c) => c.imagePath).whereType<String>());
    return cards;
  }

  Future<CardItem> insert(CardItem card) async {
    final row = await _db.from('cards').insert(card.toInsert()).select().single();
    return CardItem.fromJson(row);
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _db.from('cards').update(patch).eq('id', id);
  }

  Future<void> delete(CardItem card) async {
    await _db.from('cards').delete().eq('id', card.id);
    final path = card.imagePath;
    if (path != null) {
      try {
        await _db.storage.from(BoardsRepository.imagesBucket).remove([path]);
      } catch (_) {}
      _signed.remove(path);
    }
  }

  static String newId() => const Uuid().v4();

  /// Uploads a gallery image to card-images/<boardId>/<uuid>.<ext> and returns the path.
  Future<String> uploadImage({required String boardId, required Uint8List bytes, required String extension}) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'}.contains(ext) ? ext : 'jpg';
    final mime = switch (safeExt) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    final path = '$boardId/${newId()}.$safeExt';
    await _db.storage
        .from(BoardsRepository.imagesBucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
    return path;
  }

  String? cachedSignedUrl(String path) {
    final hit = _signed[path];
    if (hit == null || hit.expires.isBefore(DateTime.now())) return null;
    return hit.url;
  }

  Future<String?> signedUrl(String path) async {
    final cached = cachedSignedUrl(path);
    if (cached != null) return cached;
    try {
      final url = await _db.storage.from(BoardsRepository.imagesBucket).createSignedUrl(path, _signedTtl.inSeconds + 600);
      _signed[path] = (url: url, expires: DateTime.now().add(_signedTtl));
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> warmSignedUrls(Iterable<String> paths) async {
    final missing = paths.where((p) => cachedSignedUrl(p) == null).toSet().toList();
    if (missing.isEmpty) return;
    try {
      final result = await _db.storage
          .from(BoardsRepository.imagesBucket)
          .createSignedUrls(missing, _signedTtl.inSeconds + 600);
      final expires = DateTime.now().add(_signedTtl);
      for (final s in result) {
        if (s.signedUrl.isNotEmpty) _signed[s.path] = (url: s.signedUrl, expires: expires);
      }
    } catch (_) {
      // Individual images will retry through signedUrl().
    }
  }

  /// Open Graph / oEmbed preview through the link-preview Edge Function.
  Future<LinkPreview> preview(String url) async {
    try {
      final res = await _db.functions.invoke('link-preview', body: {'url': url});
      final data = res.data;
      if (data is Map<String, dynamic>) return LinkPreview.fromJson(data, url);
    } catch (_) {
      // Offline or blocked by the site: keep the link without preview.
    }
    return LinkPreview.offline(url);
  }
}
