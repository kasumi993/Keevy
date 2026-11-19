import 'package:flutter_test/flutter_test.dart';
import 'package:keevy/core/utils/identifier.dart';

void main() {
  group('ContactIdentity', () {
    test('Instagram handle variants map to the same key', () {
      final keys = [
        ContactIdentity.keyFor(instagram: '@Atelier.Rosa'),
        ContactIdentity.keyFor(instagram: 'atelier.rosa'),
        ContactIdentity.keyFor(instagram: 'https://www.instagram.com/atelier.rosa/'),
      ];
      expect(keys.toSet(), {'ig:atelier.rosa'});
    });

    test('French phone numbers are normalised', () {
      expect(ContactIdentity.normalisePhone('06 12 34 56 78'), '33612345678');
      expect(ContactIdentity.normalisePhone('+33 6 12 34 56 78'), '33612345678');
      expect(ContactIdentity.normalisePhone('0033612345678'), '33612345678');
    });

    test('priority: instagram > tiktok > email > phone > website', () {
      expect(
        ContactIdentity.keyFor(instagram: 'rosa', email: 'a@b.fr', phone: '0612345678', website: 'rosa.fr'),
        'ig:rosa',
      );
      expect(ContactIdentity.keyFor(email: ' A@B.fr ', phone: '0612345678'), 'em:a@b.fr');
      expect(ContactIdentity.keyFor(phone: '0612345678', website: 'rosa.fr'), 'ph:33612345678');
      expect(ContactIdentity.keyFor(website: 'https://www.rosa.fr/contact'), 'web:rosa.fr');
    });

    test('no identifier, no hash', () {
      expect(ContactIdentity.hashFor(), isNull);
      expect(ContactIdentity.hashFor(instagram: '  ', email: ''), isNull);
    });

    test('hash is a stable sha256 hex', () {
      final h = ContactIdentity.hashFor(instagram: 'rosa');
      expect(h, hasLength(64));
      expect(h, ContactIdentity.hashFor(instagram: '@ROSA'));
    });
  });
}
