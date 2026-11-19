import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../boards/domain/board.dart';
import '../../contacts/application/contacts_providers.dart';
import '../application/planning_providers.dart';
import '../domain/task.dart';

Future<void> showTaskSheet(BuildContext context, {required Board board, required TaskItem task}) {
  return showKSheet<void>(context, builder: (_) => TaskSheet(board: board, taskId: task.id));
}

class TaskSheet extends ConsumerStatefulWidget {
  const TaskSheet({super.key, required this.board, required this.taskId});
  final Board board;
  final String taskId;

  @override
  ConsumerState<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<TaskSheet> {
  final _title = TextEditingController();
  final _subtask = TextEditingController();
  bool _initialised = false;

  @override
  void dispose() {
    _title.dispose();
    _subtask.dispose();
    super.dispose();
  }

  BoardTasksNotifier get _notifier => ref.read(boardTasksProvider(widget.board.id).notifier);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final tasks = ref.watch(boardTasksProvider(widget.board.id)).valueOrNull ?? const <TaskItem>[];
    TaskItem? found;
    for (final x in tasks) {
      if (x.id == widget.taskId) found = x;
    }
    final task = found;
    if (task == null) return const SizedBox(height: 120);
    if (!_initialised) {
      _title.text = task.title;
      _initialised = true;
    }
    final vendors = ref.watch(boardVendorsProvider(widget.board.id)).valueOrNull ?? const [];
    final subtasks = tasks.where((x) => x.parentId == task.id).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(value: task.done, onChanged: (_) => _guard(() => _notifier.toggle(task))),
              Expanded(
                child: TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  style: t.titleLarge,
                  decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, filled: false),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) _guard(() => _notifier.rename(task, v));
                  },
                  onTapOutside: (_) {
                    final v = _title.text.trim();
                    if (v.isNotEmpty && v != task.title) _guard(() => _notifier.rename(task, v));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          Text(s.dueDate, style: t.titleSmall),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: task.dueDate ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 5),
                    );
                    if (picked != null) await _guard(() => _notifier.setDueDate(task, picked));
                  },
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(task.dueDate == null ? s.pickDate : formatLongDate(task.dueDate!, locale)),
                ),
              ),
              if (task.dueDate != null)
                IconButton(onPressed: () => _guard(() => _notifier.setDueDate(task, null)), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          if (vendors.isNotEmpty) ...[
            const SizedBox(height: KSpacing.lg),
            Text(s.addVendor, style: t.titleSmall),
            const SizedBox(height: KSpacing.sm),
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                for (final v in vendors)
                  ChoiceChip(
                    avatar: InitialsAvatar(initials: v.contact.initials, seed: v.contact.id, size: 20),
                    label: Text(v.contact.name),
                    selected: task.contactId == v.contact.id,
                    onSelected: (sel) => _guard(() => _notifier.setContact(task, sel ? v.contact.id : null)),
                  ),
              ],
            ),
          ],
          if (task.parentId == null) ...[
            const SizedBox(height: KSpacing.lg),
            for (final sub in subtasks)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: sub.done,
                title: Text(sub.title, style: TextStyle(decoration: sub.done ? TextDecoration.lineThrough : null)),
                onChanged: (_) => _guard(() => _notifier.toggle(sub)),
                secondary: IconButton(
                  onPressed: () => _guard(() => _notifier.delete(sub)),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            TextField(
              controller: _subtask,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: '+ ${s.taskHint}', isDense: true),
              onSubmitted: (v) {
                if (v.trim().isEmpty) return;
                _subtask.clear();
                _guard(() => _notifier.add(v, parentId: task.id));
              },
            ),
          ],
          const SizedBox(height: KSpacing.xl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: KColors.err),
            onPressed: () {
              final notifier = _notifier;
              Navigator.of(context).pop();
              notifier.delete(task).ignore();
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(s.deleteTask),
          ),
        ],
      ),
    );
  }
}
