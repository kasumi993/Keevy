/// Detects what a shared text/URL is: which platform it comes from, and whether
/// it points to a person/business (→ suggest saving it as a vendor) rather than
/// a piece of content (→ save it as an inspiration). Pure Dart, unit-tested.
enum LinkSource { instagram, tiktok, pinterest, twitter, youtube, facebook, web }

extension LinkSourceX on LinkSource {
  String get id => name;

  String get label => switch (this) {
        LinkSource.instagram => 'Instagram',
        LinkSource.tiktok => 'TikTok',
        LinkSource.pinterest => 'Pinterest',
        LinkSource.twitter => 'X',
        LinkSource.youtube => 'YouTube',
        LinkSource.facebook => 'Facebook',
        LinkSource.web => 'Web',
      };

  static LinkSource fromId(String? id) =>
      LinkSource.values.firstWhere((s) => s.name == id, orElse: () => LinkSource.web);
}

enum IdentifierType { instagram, tiktok, email, phone, website }

class DetectedIdentifier {
  const DetectedIdentifier(this.type, this.value);
  final IdentifierType type;

  /// Normalised value: handle without @, lower-cased email, phone digits, bare host.
  final String value;

  @override
  bool operator ==(Object other) => other is DetectedIdentifier && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);

  @override
  String toString() => 'DetectedIdentifier($type, $value)';
}

class DetectedShare {
  const DetectedShare({
    required this.rawText,
    this.url,
    this.source = LinkSource.web,
    this.identifier,
    this.isProfile = false,
  });

  final String rawText;
  final String? url;
  final LinkSource source;
  final DetectedIdentifier? identifier;

  /// True when the share points to an account/business (profile URL, phone, email).
  final bool isProfile;

  bool get looksLikeVendor => isProfile;

  /// Text that is not part of the URL (often the caption shared alongside it).
  String get textWithoutUrl {
    final u = url;
    final t = u == null ? rawText : rawText.replaceAll(u, '');
    return t.trim();
  }
}

class LinkDetector {
  LinkDetector._();

  static final _urlRe = RegExp(r'''https?://[^\s<>"'`]+''', caseSensitive: false);
  static final _emailRe = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
  static final _phoneRe = RegExp(r'(?:\+|00)?\d[\d .\-()]{7,}\d');

  static const _instagramReserved = {
    'p', 'reel', 'reels', 'tv', 'stories', 'explore', 'accounts', 'direct', 's', 'about', 'legal', 'developer',
  };

  static String? extractUrl(String text) {
    final m = _urlRe.firstMatch(text);
    if (m == null) return null;
    // Strip trailing punctuation that is rarely part of a URL.
    return m.group(0)!.replaceFirst(RegExp(r'[).,;!?\]]+$'), '');
  }

  static bool isValidUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.contains('.');
  }

  /// Adds https:// when the user typed "www.site.com" or "site.com/path".
  static String? normaliseUserUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final extracted = extractUrl(trimmed);
    if (extracted != null) return extracted;
    if (!trimmed.contains(' ') && trimmed.contains('.')) {
      final candidate = 'https://$trimmed';
      if (isValidUrl(candidate)) return candidate;
    }
    return null;
  }

  static String hostOf(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static LinkSource sourceOf(String url) {
    final host = hostOf(url);
    bool on(String domain) => host == domain || host.endsWith('.$domain');
    if (on('instagram.com') || on('instagr.am')) return LinkSource.instagram;
    if (on('tiktok.com')) return LinkSource.tiktok;
    if (on('pinterest.com') || on('pin.it') || RegExp(r'(^|\.)pinterest\.[a-z.]+$').hasMatch(host)) {
      return LinkSource.pinterest;
    }
    if (on('twitter.com') || on('x.com') || on('t.co')) return LinkSource.twitter;
    if (on('youtube.com') || on('youtu.be')) return LinkSource.youtube;
    if (on('facebook.com') || on('fb.watch') || on('fb.com')) return LinkSource.facebook;
    return LinkSource.web;
  }

  /// Instagram handle when [url] is a profile (instagram.com/<handle>), else null.
  static String? instagramHandle(String url) {
    if (sourceOf(url) != LinkSource.instagram) return null;
    final segments = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
    if (segments.isEmpty) return null;
    final first = segments.first.toLowerCase();
    if (_instagramReserved.contains(first)) return null;
    if (!RegExp(r'^[a-z0-9._]{1,30}$').hasMatch(first)) return null;
    // instagram.com/<handle>/reel/<id> is content, not a profile.
    if (segments.length > 1 && {'p', 'reel', 'reels', 'tv'}.contains(segments[1].toLowerCase())) return null;
    return first;
  }

  /// TikTok handle when [url] is a profile (tiktok.com/@handle), else null.
  static String? tiktokHandle(String url) {
    if (sourceOf(url) != LinkSource.tiktok) return null;
    final segments = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
    if (segments.length != 1) return null;
    final first = segments.first;
    if (!first.startsWith('@') || first.length < 2) return null;
    return first.substring(1).toLowerCase();
  }

  static String? extractEmail(String text) => _emailRe.firstMatch(text)?.group(0)?.toLowerCase();

  static String? extractPhone(String text) {
    for (final m in _phoneRe.allMatches(text)) {
      final raw = m.group(0)!;
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 9 && digits.length <= 15) return raw.trim();
    }
    return null;
  }

  static DetectedShare analyse(String text) {
    final url = extractUrl(text);
    if (url != null) {
      final source = sourceOf(url);
      final ig = instagramHandle(url);
      if (ig != null) {
        return DetectedShare(rawText: text, url: url, source: source,
            identifier: DetectedIdentifier(IdentifierType.instagram, ig), isProfile: true);
      }
      final tt = tiktokHandle(url);
      if (tt != null) {
        return DetectedShare(rawText: text, url: url, source: source,
            identifier: DetectedIdentifier(IdentifierType.tiktok, tt), isProfile: true);
      }
      final segments = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
      final isHomepage = source == LinkSource.web && segments.isEmpty;
      return DetectedShare(
        rawText: text,
        url: url,
        source: source,
        identifier: source == LinkSource.web ? DetectedIdentifier(IdentifierType.website, hostOf(url)) : null,
        // A bare website homepage is usually a business (vendor), a deep link is content.
        isProfile: isHomepage,
      );
    }
    final email = extractEmail(text);
    if (email != null) {
      return DetectedShare(rawText: text, identifier: DetectedIdentifier(IdentifierType.email, email), isProfile: true);
    }
    final phone = extractPhone(text);
    if (phone != null) {
      return DetectedShare(rawText: text, identifier: DetectedIdentifier(IdentifierType.phone, phone), isProfile: true);
    }
    return DetectedShare(rawText: text);
  }
}
