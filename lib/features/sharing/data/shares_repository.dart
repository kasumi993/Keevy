import 'package:supabase_flutter/supabase_flutter.dart';

import '../../boards/domain/board.dart';
import '../../boards/domain/card_item.dart';
import '../../boards/domain/section.dart';
import '../domain/board_share.dart';

/// Public, read-only snapshot of a shared board (web viewer).
class SharedBoardSnapshot {
  const SharedBoardSnapshot({
    required this.access,
    required this.board,
    required this.ownerName,
    required this.sections,
    required this.cards,
  });

  final ShareAccess access;
  final Board board;
  final String ownerName;
  final List<Section> sections;
  final List<CardItem> cards;

  factory SharedBoardSnapshot.fromJson(Map<String, dynamic> json) => SharedBoardSnapshot(
        access: json['access'] == 'edit' ? ShareAccess.edit : ShareAccess.read,
        board: Board.fromJson({...(json['board'] as Map<String, dynamic>), 'is_owner': false}),
        ownerName: json['owner_name'] as String? ?? '',
        sections: (json['sections'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Section.fromJson)
            .toList(),
        cards: (json['cards'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CardItem.fromJson)
            .toList(),
      );
}

class SharesRepository {
  SharesRepository(this._db);
  final SupabaseClient _db;

  Future<List<BoardShare>> fetchForBoard(String boardId) async {
    final rows = await _db
        .from('board_shares')
        .select()
        .eq('board_id', boardId)
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);
    return rows.map(BoardShare.fromJson).toList();
  }

  Future<BoardShare> create(String boardId, ShareAccess access) async {
    final row = await _db.from('board_shares').insert({'board_id': boardId, 'access': access.name}).select().single();
    return BoardShare.fromJson(row);
  }

  Future<void> revoke(String id) async {
    await _db.from('board_shares').update({'revoked_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  /// Joins a board through a collaborative link; returns the board id.
  Future<String> accept(String token) async {
    final result = await _db.rpc('accept_board_share', params: {'p_token': token});
    return result as String;
  }

  /// Snapshot through the shared-board Edge Function (signs private image URLs).
  Future<SharedBoardSnapshot?> fetchShared(String token) async {
    final res = await _db.functions.invoke('shared-board', body: {'token': token});
    final data = res.data;
    if (data is Map<String, dynamic> && data['board'] is Map<String, dynamic>) {
      return SharedBoardSnapshot.fromJson(data);
    }
    return null;
  }
}
