import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

class AuthRepository {
  AuthRepository(this._db);
  final SupabaseClient _db;

  /// Passwordless sign-in: emails a 6-digit code (see supabase/templates).
  Future<void> sendCode(String email, {String locale = 'fr'}) async {
    await _db.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: true,
      data: {'locale': locale},
    );
  }

  Future<void> verifyCode(String email, String code) async {
    await _db.auth.verifyOTP(email: email.trim().toLowerCase(), token: code.trim(), type: OtpType.email);
  }

  Future<void> signOut() => _db.auth.signOut();

  /// Deletes the account, its boards, contacts and images (delete-account Edge Function).
  Future<void> deleteAccount() async {
    await _db.functions.invoke('delete-account');
    await _db.auth.signOut();
  }

  // ── Profile ─────────────────────────────────────────────────────────────
  Future<Profile?> fetchProfile(String userId) async {
    final row = await _db.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<void> updateProfile(String userId, {String? displayName, String? locale}) async {
    final patch = <String, dynamic>{
      if (displayName != null) 'display_name': displayName.trim().isEmpty ? null : displayName.trim(),
      if (locale != null) 'locale': locale,
    };
    if (patch.isEmpty) return;
    await _db.from('profiles').update(patch).eq('id', userId);
  }
}
