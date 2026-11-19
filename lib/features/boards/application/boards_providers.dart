import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/dates.dart';
import '../data/boards_repository.dart';
import '../data/cards_repository.dart';
import '../domain/board.dart';
import '../domain/card_item.dart';
import '../domain/section.dart';

final boardsRepositoryProvider = Provider<BoardsRepository>((ref) => BoardsRepository(ref.watch(supabaseProvider)));
final cardsRepositoryProvider = Provider<CardsRepository>((ref) => CardsRepository(ref.watch(supabaseProvider)));

// ═══════════════════════════════════════════════════════════════════════════
// Boards list (home)
// ═══════════════════════════════════════════════════════════════════════════

final boardsProvider = AsyncNotifierProvider<BoardsNotifier, List<Board>>(BoardsNotifier.new);

class BoardsNotifier extends AsyncNotifier<List<Board>> {
  BoardsRepository get _repo => ref.read(boardsRepositoryProvider);

  @override
  Future<List<Board>> build() async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return const [];
    final boards = await _repo.fetchAll();
    unawaited(ref.read(cardsRepositoryProvider).warmSignedUrls(
          boards.expand((b) => b.previews).map((p) => p.path).whereType<String>(),
        ));
    return boards;
  }

  /// Re-fetch without flashing a loading state.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_repo.fetchAll);
    if (next.hasValue) {
      await ref.read(cardsRepositoryProvider).warmSignedUrls(
            next.value!.expand((b) => b.previews).map((p) => p.path).whereType<String>(),
          );
    }
    state = next;
  }

  Future<Board> create({
    required String name,
    required String colorHex,
    required BoardMode mode,
    String? emoji,
    EventType? eventType,
    DateTime? targetDate,
    List<String> sections = const [],
  }) async {
    final board = await _repo.create(
      name: name,
      colorHex: colorHex,
      mode: mode,
      emoji: emoji,
      eventType: eventType,
      targetDate: targetDate,
      sections: sections,
    );
    await refresh();
    return board;
  }

  Future<void> patch(String id, Map<String, dynamic> patch) async {
    await _repo.update(id, patch);
    await refresh();
  }

  Future<void> rename(String id, String name) => patch(id, {'name': name.trim()});

  Future<void> setMode(String id, BoardMode mode) => patch(id, {'mode': mode.name});

  Future<void> setAppearance(String id, {String? emoji, String? colorHex}) => patch(id, {
        if (emoji != null) 'emoji': emoji,
        if (colorHex != null) 'color': colorHex,
      });

  Future<void> setEvent(String id, {EventType? type, DateTime? date, bool clearDate = false}) => patch(id, {
        if (type != null) 'event_type': type.id,
        if (date != null || clearDate) 'target_date': formatSqlDate(date),
      });

  Future<void> archive(String id, {required bool archived}) =>
      patch(id, {'archived_at': archived ? DateTime.now().toUtc().toIso8601String() : null});

  Future<void> delete(String id) async {
    final previous = state.valueOrNull;
    if (previous != null) state = AsyncData(previous.where((b) => b.id != id).toList());
    try {
      await _repo.delete(id);
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> leave(String id) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    await _repo.leave(id, uid);
    await refresh();
  }
}

final boardByIdProvider = Provider.family<Board?, String>((ref, id) {
  final boards = ref.watch(boardsProvider).valueOrNull;
  if (boards == null) return null;
  for (final b in boards) {
    if (b.id == id) return b;
  }
  return null;
});

/// Active boards the user can write to (share sheet, "add to board" pickers).
final activeBoardsProvider = Provider<List<Board>>((ref) {
  final boards = ref.watch(boardsProvider).valueOrNull ?? const <Board>[];
  return boards.where((b) => !b.isArchived).toList();
});

// ═══════════════════════════════════════════════════════════════════════════
// Board content: sections + cards
// ═══════════════════════════════════════════════════════════════════════════

class BoardContent {
  const BoardContent({required this.sections, required this.cards});
  final List<Section> sections;
  final List<CardItem> cards;

  List<CardItem> cardsIn(String? sectionId) => cards.where((c) => c.sectionId == sectionId).toList();
  bool get hasUnsorted => cards.any((c) => c.sectionId == null);

  BoardContent copyWith({List<Section>? sections, List<CardItem>? cards}) =>
      BoardContent(sections: sections ?? this.sections, cards: cards ?? this.cards);
}

final boardContentProvider =
    AsyncNotifierProvider.autoDispose.family<BoardContentNotifier, BoardContent, String>(BoardContentNotifier.new);

class BoardContentNotifier extends AutoDisposeFamilyAsyncNotifier<BoardContent, String> {
  BoardsRepository get _boards => ref.read(boardsRepositoryProvider);
  CardsRepository get _cards => ref.read(cardsRepositoryProvider);

  @override
  Future<BoardContent> build(String arg) async {
    final results = await Future.wait([_boards.fetchSections(arg), _cards.fetchForBoard(arg)]);
    return BoardContent(sections: results[0] as List<Section>, cards: results[1] as List<CardItem>);
  }

  BoardContent get _current => state.valueOrNull ?? const BoardContent(sections: [], cards: []);

  void _touchBoards() => unawaited(ref.read(boardsProvider.notifier).refresh());

  Future<Section> addSection(String name) async {
    final position = _current.sections.isEmpty ? 0.0 : _current.sections.last.position + 1;
    final section = await _boards.createSection(arg, name, position);
    state = AsyncData(_current.copyWith(sections: [..._current.sections, section]));
    return section;
  }

  Future<void> renameSection(String id, String name) async {
    state = AsyncData(_current.copyWith(
      sections: [for (final s in _current.sections) s.id == id ? s.copyWith(name: name) : s],
    ));
    await _boards.updateSection(id, {'name': name.trim()});
  }

  Future<void> deleteSection(String id) async {
    state = AsyncData(_current.copyWith(
      sections: _current.sections.where((s) => s.id != id).toList(),
      cards: [for (final c in _current.cards) c.sectionId == id ? c.copyWith(clearSection: true) : c],
    ));
    await _boards.deleteSection(id);
  }

  /// Inserts a card at the top of its section.
  Future<CardItem> addCard(CardItem draft) async {
    final siblings = _current.cardsIn(draft.sectionId);
    final top = siblings.isEmpty ? 0.0 : siblings.map((c) => c.position).reduce((a, b) => a < b ? a : b) - 1;
    final card = await _cards.insert(draft.copyWith(position: top));
    if (card.imagePath != null) await _cards.warmSignedUrls([card.imagePath!]);
    state = AsyncData(_current.copyWith(cards: [card, ..._current.cards]));
    _touchBoards();
    return card;
  }

  Future<void> updateCard(CardItem card, Map<String, dynamic> patch) async {
    state = AsyncData(_current.copyWith(cards: [for (final c in _current.cards) c.id == card.id ? card : c]));
    await _cards.update(card.id, patch);
  }

  Future<void> moveCard(CardItem card, String? sectionId) async {
    final siblings = _current.cardsIn(sectionId);
    final top = siblings.isEmpty ? 0.0 : siblings.map((c) => c.position).reduce((a, b) => a < b ? a : b) - 1;
    final moved = sectionId == null ? card.copyWith(clearSection: true, position: top) : card.copyWith(sectionId: sectionId, position: top);
    await updateCard(moved, {'section_id': sectionId, 'position': top});
  }

  Future<void> deleteCard(CardItem card) async {
    final previous = _current;
    state = AsyncData(_current.copyWith(cards: _current.cards.where((c) => c.id != card.id).toList()));
    try {
      await _cards.delete(card);
      _touchBoards();
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() => build(arg));
  }
}

/// Signed URL for a private image path (cached in the repository).
final signedImageUrlProvider = FutureProvider.family<String?, String>((ref, path) {
  return ref.watch(cardsRepositoryProvider).signedUrl(path);
});
