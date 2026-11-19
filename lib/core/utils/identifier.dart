import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'link_detector.dart';

/// Builds the de-duplication key of a contact: the strongest identifier wins
/// (instagram > tiktok > email > phone > website), normalised then sha256-hashed.
class ContactIdentity {
  ContactIdentity._();

  static String normaliseHandle(String input) {
    var v = input.trim().toLowerCase();
    final fromUrl = LinkDetector.instagramHandle(v) ?? LinkDetector.tiktokHandle(v);
    if (fromUrl != null) return fromUrl;
    if (v.startsWith('@')) v = v.substring(1);
    return v.replaceAll(RegExp(r'[^a-z0-9._]'), '');
  }

  /// Digits only; French national numbers (0X XX XX XX XX) become 33XXXXXXXXX.
  static String normalisePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 10 && digits.startsWith('0')) digits = '33${digits.substring(1)}';
    return digits;
  }

  static String normaliseEmail(String input) => input.trim().toLowerCase();

  static String normaliseWebsite(String input) {
    var v = input.trim().toLowerCase();
    if (!v.startsWith('http')) v = 'https://$v';
    final host = LinkDetector.hostOf(v);
    return host;
  }

  /// Returns the normalised key (e.g. "ig:atelier.rosa") or null when no identifier is set.
  static String? keyFor({String? instagram, String? tiktok, String? email, String? phone, String? website}) {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s;
    if (clean(instagram) != null) {
      final h = normaliseHandle(instagram!);
      if (h.isNotEmpty) return 'ig:$h';
    }
    if (clean(tiktok) != null) {
      final h = normaliseHandle(tiktok!);
      if (h.isNotEmpty) return 'tt:$h';
    }
    if (clean(email) != null) return 'em:${normaliseEmail(email!)}';
    if (clean(phone) != null) {
      final p = normalisePhone(phone!);
      if (p.length >= 9) return 'ph:$p';
    }
    if (clean(website) != null) {
      final w = normaliseWebsite(website!);
      if (w.isNotEmpty) return 'web:$w';
    }
    return null;
  }

  static String hash(String key) => sha256.convert(utf8.encode(key)).toString();

  static String? hashFor({String? instagram, String? tiktok, String? email, String? phone, String? website}) {
    final key = keyFor(instagram: instagram, tiktok: tiktok, email: email, phone: phone, website: website);
    return key == null ? null : hash(key);
  }
}
