import 'package:supabase_flutter/supabase_flutter.dart';

/// Business errors raised by the database (see the migration) or the app.
enum KeevyErrorCode { limitProjetBoards, premiumRequiredEditShare, shareNotFound, shareReadOnly, network, unknown }

class KeevyException implements Exception {
  const KeevyException(this.code, [this.details]);
  final KeevyErrorCode code;
  final Object? details;

  bool get needsPremium =>
      code == KeevyErrorCode.limitProjetBoards || code == KeevyErrorCode.premiumRequiredEditShare;

  static KeevyException from(Object error) {
    if (error is KeevyException) return error;
    final message = switch (error) {
      PostgrestException e => e.message,
      AuthException e => e.message,
      StorageException e => e.message,
      FunctionException e => '${e.details}',
      _ => error.toString(),
    };
    if (message.contains('KEEVY_LIMIT_PROJET_BOARDS')) return KeevyException(KeevyErrorCode.limitProjetBoards, error);
    if (message.contains('KEEVY_PREMIUM_REQUIRED_EDIT_SHARE')) {
      return KeevyException(KeevyErrorCode.premiumRequiredEditShare, error);
    }
    if (message.contains('KEEVY_SHARE_NOT_FOUND')) return KeevyException(KeevyErrorCode.shareNotFound, error);
    if (message.contains('KEEVY_SHARE_READ_ONLY')) return KeevyException(KeevyErrorCode.shareReadOnly, error);
    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('network')) {
      return KeevyException(KeevyErrorCode.network, error);
    }
    return KeevyException(KeevyErrorCode.unknown, error);
  }

  @override
  String toString() => 'KeevyException($code, $details)';
}
