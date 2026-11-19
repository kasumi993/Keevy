import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Overridden in main() once SharedPreferences is loaded.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('sharedPrefsProvider'));

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(supabaseProvider).auth.onAuthStateChange);

/// Current user id; recomputed on every auth event (sign in / out / refresh).
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});

/// User-chosen language: null = follow the device.
final localeOverrideProvider = StateNotifierProvider<LocaleOverride, Locale?>((ref) {
  return LocaleOverride(ref.watch(sharedPrefsProvider));
});

class LocaleOverride extends StateNotifier<Locale?> {
  LocaleOverride(this._prefs) : super(_read(_prefs));
  final SharedPreferences _prefs;
  static const _key = 'locale_override';

  static Locale? _read(SharedPreferences p) {
    final code = p.getString(_key);
    return code == null ? null : Locale(code);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, locale.languageCode);
    }
  }
}

const onboardingSeenKey = 'onboarding_seen';
