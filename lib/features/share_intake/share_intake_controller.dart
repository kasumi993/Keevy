import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../boards/application/boards_providers.dart';
import '../boards/domain/board.dart';
import '../contacts/domain/contact.dart';
import 'share_channel.dart';
import 'share_importer.dart';

/// Queue of shared items waiting for the user to sort them.
/// Items already sorted in the iOS share extension are imported silently.
class ShareIntakeController extends Notifier<List<SharedItem>> with WidgetsBindingObserver {
  StreamSubscription<List<SharedItem>>? _sub;
  bool _started = false;

  /// Number of silently imported items, consumed by the UI to show a snackbar.
  final importedCount = ValueNotifier<int>(0);

  @override
  List<SharedItem> build() {
    ref.onDispose(() {
      _sub?.cancel();
      WidgetsBinding.instance.removeObserver(this);
      importedCount.dispose();
    });
    return const [];
  }

  void start() {
    if (_started) return;
    _started = true;
    final channel = ShareChannel.instance;
    channel.init();
    _sub = channel.onItems.listen(_receive);
    WidgetsBinding.instance.addObserver(this);
    unawaited(pull());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) unawaited(pull());
  }

  Future<void> pull() async {
    final items = await ShareChannel.instance.takePending();
    if (items.isNotEmpty) await _receive(items);
  }

  Future<void> _receive(List<SharedItem> items) async {
    if (ref.read(currentUserIdProvider) == null) {
      // Not signed in yet: keep them until the user is.
      state = [...state, ...items];
      return;
    }
    final unsorted = <SharedItem>[];
    var imported = 0;
    for (final item in items) {
      if (item.boardId != null) {
        try {
          await _importSorted(item);
          imported++;
        } catch (e) {
          debugPrint('share import failed: $e');
          unsorted.add(item);
        }
      } else {
        unsorted.add(item);
      }
    }
    if (imported > 0) importedCount.value = importedCount.value + imported;
    if (unsorted.isNotEmpty) state = [...state, ...unsorted];
  }

  Future<void> _importSorted(SharedItem item) async {
    final importer = ref.read(shareImporterProvider);
    if (item.kind == 'vendor') {
      final draft = ShareImporter.vendorDraftFrom(item.value);
      final named = draft.name.isEmpty
          ? ContactDraft(
              name: item.value.length > 60 ? item.value.substring(0, 60) : item.value,
              instagram: draft.instagram,
              tiktok: draft.tiktok,
              email: draft.email,
              phone: draft.phone,
              website: draft.website,
              notes: item.note,
            )
          : draft;
      await importer.saveVendor(named, boardId: item.boardId!);
    } else {
      await importer.saveInspiration(item, boardId: item.boardId!, sectionId: item.sectionId, note: item.note);
    }
  }

  /// Removes the first item once the share sheet is done with it.
  void pop() {
    if (state.isEmpty) return;
    state = state.sublist(1);
  }

  /// Re-processes items received before sign-in.
  Future<void> retryAfterSignIn() async {
    if (state.isEmpty) return;
    final pending = state;
    state = const [];
    await _receive(pending);
  }
}

final shareIntakeProvider = NotifierProvider<ShareIntakeController, List<SharedItem>>(ShareIntakeController.new);

/// Boards + sections handed to the iOS share extension (App Group).
Future<void> syncBoardsToShareExtension(WidgetRef ref, List<Board> boards) async {
  final repo = ref.read(boardsRepositoryProvider);
  final payload = <Map<String, Object?>>[];
  for (final b in boards.where((b) => !b.isArchived).take(30)) {
    List<Map<String, Object?>> sections = const [];
    try {
      final list = await repo.fetchSections(b.id);
      sections = [for (final s in list) {'id': s.id, 'name': s.name}];
    } catch (_) {}
    payload.add({
      'id': b.id,
      'name': b.name,
      'emoji': b.displayEmoji,
      'color': '#${(b.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      'mode': b.mode.name,
      'sections': sections,
    });
  }
  await ShareChannel.instance.syncBoards(payload);
}
