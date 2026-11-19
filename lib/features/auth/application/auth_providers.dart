import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));

final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return null;
    return ref.read(authRepositoryProvider).fetchProfile(uid);
  }

  Future<void> reload() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).fetchProfile(uid));
  }

  Future<void> updateName(String name) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    await ref.read(authRepositoryProvider).updateProfile(uid, displayName: name);
    await reload();
  }

  Future<void> updateLocale(String? code) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || code == null) return;
    await ref.read(authRepositoryProvider).updateProfile(uid, locale: code);
  }
}

/// Server-side premium flag (set by the RevenueCat webhook).
final isPremiumProvider = Provider<bool>((ref) => ref.watch(profileProvider).valueOrNull?.hasPremium ?? false);
