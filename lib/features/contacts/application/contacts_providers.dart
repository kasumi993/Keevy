import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../boards/application/boards_providers.dart';
import '../../boards/domain/card_item.dart';
import '../../planning/application/planning_providers.dart';
import '../../planning/domain/task.dart';
import '../data/contacts_repository.dart';
import '../domain/contact.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) => ContactsRepository(ref.watch(supabaseProvider)));

// ── Global address book ───────────────────────────────────────────────────
final contactsProvider = AsyncNotifierProvider<ContactsNotifier, List<Contact>>(ContactsNotifier.new);

class ContactsNotifier extends AsyncNotifier<List<Contact>> {
  ContactsRepository get _repo => ref.read(contactsRepositoryProvider);

  @override
  Future<List<Contact>> build() async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return const [];
    return _repo.fetchAll(uid);
  }

  Future<void> refresh() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    state = await AsyncValue.guard(() => _repo.fetchAll(uid));
  }

  /// Creates (or finds) a contact and optionally links it to a board.
  Future<({Contact contact, bool existed})> create(ContactDraft draft, {String? boardId}) async {
    final uid = ref.read(currentUserIdProvider)!;
    final result = await _repo.createOrFind(draft, ownerId: uid);
    if (boardId != null) {
      await _repo.link(boardId, result.contact.id);
      ref.invalidate(boardVendorsProvider(boardId));
      unawaited(ref.read(boardsProvider.notifier).refresh());
    }
    await refresh();
    return result;
  }

  Future<Contact> updateContact(String id, ContactDraft draft) async {
    final uid = ref.read(currentUserIdProvider)!;
    final updated = await _repo.update(id, draft, ownerId: uid);
    await refresh();
    _invalidateLinks(updated);
    return updated;
  }

  Future<void> delete(Contact contact) async {
    await _repo.delete(contact.id);
    _invalidateLinks(contact);
    await refresh();
  }

  Future<void> linkToBoard(String contactId, String boardId) async {
    await _repo.link(boardId, contactId);
    ref.invalidate(boardVendorsProvider(boardId));
    ref.invalidate(contactDetailProvider(contactId));
    unawaited(ref.read(boardsProvider.notifier).refresh());
    await refresh();
  }

  Future<void> unlinkFromBoard(String contactId, String boardId) async {
    await _repo.unlink(boardId, contactId);
    ref.invalidate(boardVendorsProvider(boardId));
    ref.invalidate(contactDetailProvider(contactId));
    unawaited(ref.read(boardsProvider.notifier).refresh());
    await refresh();
  }

  Future<void> updateLink(BoardContactLink link, {VendorStatus? status, double? price, bool clearPrice = false, String? notes}) async {
    await _repo.updateLink(link.boardId, link.contactId, {
      if (status != null) 'status': status.name,
      if (price != null || clearPrice) 'price_estimate': price,
      if (notes != null) 'notes': notes,
    });
    ref.invalidate(boardVendorsProvider(link.boardId));
    ref.invalidate(contactDetailProvider(link.contactId));
    await refresh();
  }

  void _invalidateLinks(Contact c) {
    for (final l in c.links) {
      ref.invalidate(boardVendorsProvider(l.boardId));
    }
    ref.invalidate(contactDetailProvider(c.id));
  }
}

// ── Vendors of one board ──────────────────────────────────────────────────
final boardVendorsProvider = FutureProvider.autoDispose.family<List<BoardVendor>, String>((ref, boardId) {
  return ref.watch(contactsRepositoryProvider).fetchForBoard(boardId);
});

// ── Contact detail (slide-over) ───────────────────────────────────────────
class ContactDetail {
  const ContactDetail({required this.contact, required this.cards, required this.tasks});
  final Contact contact;
  final List<CardItem> cards;
  final List<TaskItem> tasks;
}

final contactDetailProvider = FutureProvider.autoDispose.family<ContactDetail?, String>((ref, contactId) async {
  final contact = await ref.watch(contactsRepositoryProvider).fetchOne(contactId);
  if (contact == null) return null;
  final results = await Future.wait([
    ref.watch(cardsRepositoryProvider).fetchForContact(contactId),
    ref.watch(tasksRepositoryProvider).fetchForContact(contactId),
  ]);
  return ContactDetail(
    contact: contact,
    cards: results[0] as List<CardItem>,
    tasks: results[1] as List<TaskItem>,
  );
});
