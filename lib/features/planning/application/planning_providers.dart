import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/utils/dates.dart';
import '../../boards/application/boards_providers.dart';
import '../../boards/domain/board.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';
import '../domain/templates.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) => TasksRepository(ref.watch(supabaseProvider)));

final boardTasksProvider =
    AsyncNotifierProvider.autoDispose.family<BoardTasksNotifier, List<TaskItem>, String>(BoardTasksNotifier.new);

class BoardTasksNotifier extends AutoDisposeFamilyAsyncNotifier<List<TaskItem>, String> {
  TasksRepository get _repo => ref.read(tasksRepositoryProvider);

  @override
  Future<List<TaskItem>> build(String arg) => _repo.fetchForBoard(arg);

  List<TaskItem> get _current => state.valueOrNull ?? const [];

  void _touchBoards() => unawaited(ref.read(boardsProvider.notifier).refresh());

  Future<void> add(String title, {DateTime? dueDate, String? contactId, String? parentId}) async {
    final position = _current.isEmpty ? 0.0 : _current.map((t) => t.position).reduce((a, b) => a > b ? a : b) + 1;
    final draft = TaskItem(
      id: const Uuid().v4(),
      boardId: arg,
      title: title.trim(),
      dueDate: dueDate,
      contactId: contactId,
      parentId: parentId,
      position: position,
    );
    state = AsyncData([..._current, draft]);
    try {
      await _repo.insert(draft);
      _touchBoards();
    } catch (_) {
      state = AsyncData(_current.where((t) => t.id != draft.id).toList());
      rethrow;
    }
  }

  Future<void> toggle(TaskItem task) => _patch(task.copyWith(done: !task.done), {'done': !task.done}, touch: true);

  Future<void> rename(TaskItem task, String title) => _patch(task.copyWith(title: title), {'title': title.trim()});

  Future<void> setDueDate(TaskItem task, DateTime? date) => _patch(
        date == null ? task.copyWith(clearDueDate: true) : task.copyWith(dueDate: date),
        {'due_date': formatSqlDate(date)},
      );

  Future<void> setContact(TaskItem task, String? contactId) => _patch(
        contactId == null ? task.copyWith(clearContact: true) : task.copyWith(contactId: contactId),
        {'contact_id': contactId},
      );

  Future<void> delete(TaskItem task) async {
    final previous = _current;
    // Sub-tasks are deleted by the database cascade.
    state = AsyncData(_current.where((t) => t.id != task.id && t.parentId != task.id).toList());
    try {
      await _repo.delete(task.id);
      _touchBoards();
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Creates the event-type checklist, with due dates computed from the board date.
  Future<void> applyTemplate(Board board, {required bool isFr}) async {
    final template = ChecklistTemplates.forType(board.eventType);
    final start = _current.isEmpty ? 0.0 : _current.map((t) => t.position).reduce((a, b) => a > b ? a : b) + 1;
    final tasks = [
      for (var i = 0; i < template.tasks.length; i++)
        TaskItem(
          id: const Uuid().v4(),
          boardId: arg,
          title: template.tasks[i].title(isFr),
          dueDate: template.dueDateFor(template.tasks[i], board.targetDate),
          position: start + i,
          templateKey: template.key,
        ),
    ];
    final created = await _repo.insertMany(tasks);
    state = AsyncData([..._current, ...created]);
    _touchBoards();
  }

  Future<void> _patch(TaskItem updated, Map<String, dynamic> patch, {bool touch = false}) async {
    final previous = _current;
    state = AsyncData([for (final t in _current) t.id == updated.id ? updated : t]);
    try {
      await _repo.update(updated.id, patch);
      if (touch) _touchBoards();
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
