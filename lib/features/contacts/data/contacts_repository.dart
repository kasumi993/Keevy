import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/identifier.dart';
import '../domain/contact.dart';

/// A vendor as seen from one board: the link (status, price) + the contact.
class BoardVendor {
  const BoardVendor(this.link, this.contact);
  final BoardContactLink link;
  final Contact contact;
}

class ContactsRepository {
  ContactsRepository(this._db);
  final SupabaseClient _db;

  static const _select =
      '*, board_contacts(board_id, contact_id, status, price_estimate, currency, notes, boards(name, color, mode))';

  Future<List<Contact>> fetchAll(String ownerId) async {
    final rows = await _db.from('contacts').select(_select).eq('owner_id', ownerId).order('name', ascending: true);
    return rows.map(Contact.fromJson).toList();
  }

  Future<Contact?> fetchOne(String id) async {
    final row = await _db.from('contacts').select(_select).eq('id', id).maybeSingle();
    return row == null ? null : Contact.fromJson(row);
  }

  static String? hashOf(ContactDraft d) => ContactIdentity.hashFor(
        instagram: d.instagram,
        tiktok: d.tiktok,
        email: d.email,
        phone: d.phone,
        website: d.website,
      );

  /// Creates the contact, or returns the existing one with the same identifier
  /// ("create once, find everywhere"). `existed` tells the UI which happened.
  Future<({Contact contact, bool existed})> createOrFind(ContactDraft d, {required String ownerId}) async {
    final hash = hashOf(d);
    if (hash != null) {
      final existing =
          await _db.from('contacts').select(_select).eq('owner_id', ownerId).eq('identifier_hash', hash).maybeSingle();
      if (existing != null) {
        final contact = Contact.fromJson(existing);
        await _fillBlanks(contact, d);
        return (contact: (await fetchOne(contact.id)) ?? contact, existed: true);
      }
    }
    final draft = _toContact(d, ownerId: ownerId, hash: hash);
    final row = await _db.from('contacts').insert(draft.toWrite()).select(_select).single();
    return (contact: Contact.fromJson(row), existed: false);
  }

  Future<Contact> update(String id, ContactDraft d, {required String ownerId}) async {
    final hash = hashOf(d);
    final patch = _toContact(d, ownerId: ownerId, hash: hash).toWrite();
    try {
      await _db.from('contacts').update(patch).eq('id', id);
    } on PostgrestException catch (e) {
      // Another contact already owns this identifier: save the rest, keep the old hash.
      if (e.code != '23505') rethrow;
      patch.remove('identifier_hash');
      await _db.from('contacts').update(patch).eq('id', id);
    }
    return (await fetchOne(id))!;
  }

  Future<void> delete(String id) async {
    await _db.from('contacts').delete().eq('id', id);
  }

  Future<void> _fillBlanks(Contact c, ContactDraft d) async {
    final patch = <String, dynamic>{};
    void fill(String column, String? current, String? incoming) {
      if ((current == null || current.isEmpty) && incoming != null && incoming.trim().isNotEmpty) {
        patch[column] = incoming.trim();
      }
    }

    fill('profession', c.profession, d.profession);
    fill('phone', c.phone, d.phone);
    fill('email', c.email, d.email);
    fill('instagram', c.instagram, d.instagram);
    fill('tiktok', c.tiktok, d.tiktok);
    fill('website', c.website, d.website);
    fill('recommended_by', c.recommendedBy, d.recommendedBy);
    if (patch.isNotEmpty) await _db.from('contacts').update(patch).eq('id', c.id);
  }

  Contact _toContact(ContactDraft d, {required String ownerId, String? hash}) => Contact(
        id: '',
        ownerId: ownerId,
        name: d.name.trim(),
        profession: d.profession,
        phone: d.phone,
        email: d.email,
        instagram: d.instagram == null ? null : ContactIdentity.normaliseHandle(d.instagram!),
        tiktok: d.tiktok == null ? null : ContactIdentity.normaliseHandle(d.tiktok!),
        website: d.website,
        recommendedBy: d.recommendedBy,
        notes: d.notes,
        identifierHash: hash,
      );

  // ── Board links ─────────────────────────────────────────────────────────
  Future<List<BoardVendor>> fetchForBoard(String boardId) async {
    final rows = await _db
        .from('board_contacts')
        .select('*, contacts(*)')
        .eq('board_id', boardId)
        .order('created_at', ascending: true);
    return [
      for (final r in rows)
        if (r['contacts'] is Map<String, dynamic>)
          BoardVendor(BoardContactLink.fromJson(r), Contact.fromJson(r['contacts'] as Map<String, dynamic>)),
    ];
  }

  Future<void> link(String boardId, String contactId, {VendorStatus status = VendorStatus.decouvert}) async {
    await _db.from('board_contacts').upsert(
      {'board_id': boardId, 'contact_id': contactId, 'status': status.name},
      onConflict: 'board_id,contact_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> updateLink(String boardId, String contactId, Map<String, dynamic> patch) async {
    await _db.from('board_contacts').update(patch).eq('board_id', boardId).eq('contact_id', contactId);
  }

  Future<void> unlink(String boardId, String contactId) async {
    await _db.from('board_contacts').delete().eq('board_id', boardId).eq('contact_id', contactId);
  }
}
