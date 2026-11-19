import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/dates.dart';
import '../domain/board.dart';
import '../domain/section.dart';

class BoardsRepository {
  BoardsRepository(this._db);
  final SupabaseClient _db;

  static const imagesBucket = 'card-images';

  Future<List<Board>> fetchAll() async {
    final rows = await _db
        .from('board_overview')
        .select()
        .order('position', ascending: true)
        .order('updated_at', ascending: false);
    return rows.map(Board.fromJson).toList();
  }

  Future<Board?> fetchOne(String id) async {
    final row = await _db.from('board_overview').select().eq('id', id).maybeSingle();
    return row == null ? null : Board.fromJson(row);
  }

  Future<Board> create({
    required String name,
    required String colorHex,
    required BoardMode mode,
    String? emoji,
    EventType? eventType,
    DateTime? targetDate,
    List<String> sections = const [],
  }) async {
    final row = await _db
        .from('boards')
        .insert({
          'name': name.trim(),
          'color': colorHex,
          'mode': mode.name,
          'emoji': emoji,
          'event_type': eventType?.id,
          'target_date': formatSqlDate(targetDate),
          'position': -DateTime.now().millisecondsSinceEpoch / 1000,
        })
        .select()
        .single();
    final board = Board.fromJson(row);
    if (sections.isNotEmpty) {
      await _db.from('sections').insert([
        for (var i = 0; i < sections.length; i++) {'board_id': board.id, 'name': sections[i], 'position': i.toDouble()},
      ]);
    }
    return board;
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _db.from('boards').update(patch).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _removeFolder(id);
    await _db.from('boards').delete().eq('id', id);
  }

  Future<void> leave(String boardId, String userId) async {
    await _db.from('board_members').delete().eq('board_id', boardId).eq('user_id', userId);
  }

  Future<void> _removeFolder(String boardId) async {
    try {
      final storage = _db.storage.from(imagesBucket);
      while (true) {
        final files = await storage.list(path: boardId, searchOptions: const SearchOptions(limit: 100));
        if (files.isEmpty) break;
        await storage.remove([for (final f in files) '$boardId/${f.name}']);
        if (files.length < 100) break;
      }
    } catch (_) {
      // Images are best-effort: the board itself must still be deletable.
    }
  }

  // ── Sections ────────────────────────────────────────────────────────────
  Future<List<Section>> fetchSections(String boardId) async {
    final rows = await _db
        .from('sections')
        .select()
        .eq('board_id', boardId)
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    return rows.map(Section.fromJson).toList();
  }

  Future<Map<String, List<Section>>> fetchSectionsFor(List<String> boardIds) async {
    if (boardIds.isEmpty) return const {};
    final rows = await _db
        .from('sections')
        .select()
        .inFilter('board_id', boardIds)
        .order('position', ascending: true);
    final result = <String, List<Section>>{};
    for (final s in rows.map(Section.fromJson)) {
      result.putIfAbsent(s.boardId, () => []).add(s);
    }
    return result;
  }

  Future<Section> createSection(String boardId, String name, double position) async {
    final row = await _db
        .from('sections')
        .insert({'board_id': boardId, 'name': name.trim(), 'position': position})
        .select()
        .single();
    return Section.fromJson(row);
  }

  Future<void> updateSection(String id, Map<String, dynamic> patch) async {
    await _db.from('sections').update(patch).eq('id', id);
  }

  Future<void> deleteSection(String id) async {
    await _db.from('sections').delete().eq('id', id);
  }
}
