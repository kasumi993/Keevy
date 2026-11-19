import 'package:flutter_test/flutter_test.dart';
import 'package:keevy/core/utils/link_detector.dart';

void main() {
  group('LinkDetector.sourceOf', () {
    test('recognises platforms', () {
      expect(LinkDetector.sourceOf('https://www.instagram.com/reel/abc/'), LinkSource.instagram);
      expect(LinkDetector.sourceOf('https://vm.tiktok.com/ZMabc/'), LinkSource.tiktok);
      expect(LinkDetector.sourceOf('https://pin.it/3xyz'), LinkSource.pinterest);
      expect(LinkDetector.sourceOf('https://fr.pinterest.com/pin/123/'), LinkSource.pinterest);
      expect(LinkDetector.sourceOf('https://x.com/user/status/1'), LinkSource.twitter);
      expect(LinkDetector.sourceOf('https://youtu.be/dQw4w9WgXcQ'), LinkSource.youtube);
      expect(LinkDetector.sourceOf('https://www.fleuriste-rosa.fr/mariage'), LinkSource.web);
    });

    test('does not confuse look-alike domains', () {
      expect(LinkDetector.sourceOf('https://notinstagram.com/x'), LinkSource.web);
    });
  });

  group('LinkDetector.analyse', () {
    test('Instagram post is content, not a vendor', () {
      final d = LinkDetector.analyse('Regarde ça 😍 https://www.instagram.com/p/C1abc/?igsh=xyz');
      expect(d.url, 'https://www.instagram.com/p/C1abc/?igsh=xyz');
      expect(d.source, LinkSource.instagram);
      expect(d.isProfile, isFalse);
      expect(d.textWithoutUrl, 'Regarde ça 😍');
    });

    test('Instagram profile suggests a vendor', () {
      final d = LinkDetector.analyse('https://instagram.com/atelier.rosa?igsh=1');
      expect(d.isProfile, isTrue);
      expect(d.identifier, const DetectedIdentifier(IdentifierType.instagram, 'atelier.rosa'));
    });

    test('TikTok profile vs video', () {
      expect(LinkDetector.analyse('https://www.tiktok.com/@lafleuriste').identifier,
          const DetectedIdentifier(IdentifierType.tiktok, 'lafleuriste'));
      expect(LinkDetector.analyse('https://www.tiktok.com/@lafleuriste/video/123').isProfile, isFalse);
    });

    test('website homepage is a vendor, deep link is content', () {
      expect(LinkDetector.analyse('https://www.chateau-bellevue.fr/').isProfile, isTrue);
      expect(LinkDetector.analyse('https://www.chateau-bellevue.fr/galerie/photo-1').isProfile, isFalse);
    });

    test('email and phone', () {
      expect(LinkDetector.analyse('contact: Hello@Traiteur.FR').identifier,
          const DetectedIdentifier(IdentifierType.email, 'hello@traiteur.fr'));
      final phone = LinkDetector.analyse('Appelle Sarah au 06 12 34 56 78');
      expect(phone.identifier?.type, IdentifierType.phone);
      expect(phone.isProfile, isTrue);
    });

    test('plain text', () {
      final d = LinkDetector.analyse('Pivoines blanches pour la table');
      expect(d.url, isNull);
      expect(d.identifier, isNull);
      expect(d.isProfile, isFalse);
    });

    test('strips trailing punctuation', () {
      expect(LinkDetector.extractUrl('Vu ici (https://site.fr/robe).'), 'https://site.fr/robe');
    });
  });

  group('LinkDetector.normaliseUserUrl', () {
    test('adds a scheme', () {
      expect(LinkDetector.normaliseUserUrl('www.site.fr/robe'), 'https://www.site.fr/robe');
      expect(LinkDetector.normaliseUserUrl(' https://a.fr '), 'https://a.fr');
    });

    test('rejects garbage', () {
      expect(LinkDetector.normaliseUserUrl('pas un lien'), isNull);
      expect(LinkDetector.normaliseUserUrl(''), isNull);
    });
  });
}
