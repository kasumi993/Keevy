import '../../../core/utils/dates.dart';

class Profile {
  const Profile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.locale = 'fr',
    this.isPremium = false,
    this.premiumUntil,
    this.onboardedAt,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String locale;
  final bool isPremium;
  final DateTime? premiumUntil;
  final DateTime? onboardedAt;

  /// Mirrors public.is_premium() on the server.
  bool get hasPremium => isPremium && (premiumUntil == null || premiumUntil!.isAfter(DateTime.now()));

  String get firstName {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n.split(RegExp(r'\s+')).first;
    final e = email;
    if (e == null) return '';
    final local = e.split('@').first.split(RegExp(r'[._\-+]')).first;
    if (local.isEmpty) return '';
    return local[0].toUpperCase() + local.substring(1);
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        email: json['email'] as String?,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        locale: json['locale'] as String? ?? 'fr',
        isPremium: json['is_premium'] as bool? ?? false,
        premiumUntil: parseDate(json['premium_until']),
        onboardedAt: parseDate(json['onboarded_at']),
      );
}
