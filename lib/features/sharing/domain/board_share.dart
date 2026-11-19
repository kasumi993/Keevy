import '../../../core/env.dart';
import '../../../core/utils/dates.dart';

enum ShareAccess { read, edit }

class BoardShare {
  const BoardShare({
    required this.id,
    required this.boardId,
    required this.token,
    required this.access,
    this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String boardId;
  final String token;
  final ShareAccess access;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  /// Read-only links open the web viewer; collaborative links open the join flow.
  String get url => access == ShareAccess.edit ? '${Env.webBaseUrl}/join/$token' : '${Env.webBaseUrl}/s/$token';

  factory BoardShare.fromJson(Map<String, dynamic> json) => BoardShare(
        id: json['id'] as String,
        boardId: json['board_id'] as String,
        token: json['token'] as String,
        access: json['access'] == 'edit' ? ShareAccess.edit : ShareAccess.read,
        createdAt: parseDate(json['created_at']),
        revokedAt: parseDate(json['revoked_at']),
      );
}
