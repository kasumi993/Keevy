import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../boards/domain/board.dart';
import '../../boards/presentation/labels.dart';
import '../../contacts/application/contacts_providers.dart';
import '../../contacts/data/contacts_repository.dart';
import '../../contacts/domain/contact.dart';
import '../../contacts/presentation/contact_form.dart';
import '../../contacts/presentation/contact_sheet.dart';
import '../application/planning_providers.dart';
import '../domain/task.dart';
import '../domain/templates.dart';
import 'task_sheet.dart';

/// Projet mode: countdown, vendors with their status, checklist.
class PlanningTab extends ConsumerStatefulWidget {
  const PlanningTab({super.key, required this.board});
  final Board board;

  @override
  ConsumerState<PlanningTab> createState() => _PlanningTabState();
}

class _PlanningTabState extends ConsumerState<PlanningTab> with AutomaticKeepAliveClientMixin {
  final _newTask = TextEditingController();
  bool _applying = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final title = _newTask.text.trim();
    if (title.isEmpty) return;
    _newTask.clear();
    try {
      await ref.read(boardTasksProvider(widget.board.id).notifier).add(title);
    } catch (e) {
      if (mounted) handleError(context, e);
    }
  }

  Future<void> _applyTemplate() async {
    setState(() => _applying = true);
    try {
      await ref.read(boardTasksProvider(widget.board.id).notifier).applyTemplate(widget.board, isFr: S.of(context).isFr);
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final board = widget.board;
    final tasksAsync = ref.watch(boardTasksProvider(board.id));
    final vendors = ref.watch(boardVendorsProvider(board.id)).valueOrNull ?? const <BoardVendor>[];

    return RefreshIndicator(
      color: KColors.primary,
      onRefresh: () async {
        ref.invalidate(boardTasksProvider(board.id));
        ref.invalidate(boardVendorsProvider(board.id));
        await ref.read(boardTasksProvider(board.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.lg, KSpacing.lg, 120),
        children: [
          _CountdownCard(board: board, tasks: tasksAsync.valueOrNull ?? const [], vendors: vendors),
          SectionTitle(
            s.vendors,
            padding: const EdgeInsets.fromLTRB(KSpacing.xs, KSpacing.xl, 0, KSpacing.sm),
            trailing: TextButton.icon(
              onPressed: () async {
                final message = await showContactFormSheet(context, boardId: board.id, askBoard: false);
                if (message != null && context.mounted) showSnack(context, message);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(s.add),
            ),
          ),
          if (vendors.isEmpty)
            Surface(child: Text(s.noVendorsBody, style: Theme.of(context).textTheme.bodyMedium))
          else
            for (final v in vendors) ...[
              _VendorRow(vendor: v),
              const SizedBox(height: KSpacing.sm),
            ],
          SectionTitle(s.checklist, padding: const EdgeInsets.fromLTRB(KSpacing.xs, KSpacing.xl, 0, KSpacing.sm)),
          tasksAsync.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.all(KSpacing.xl),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => ErrorState(onRetry: () => ref.invalidate(boardTasksProvider(board.id))),
            data: (tasks) => tasks.isEmpty ? _emptyChecklist(s) : _Checklist(board: board, tasks: tasks, vendors: vendors),
          ),
          const SizedBox(height: KSpacing.md),
          TextField(
            controller: _newTask,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addTask(),
            decoration: InputDecoration(
              hintText: s.taskHint,
              prefixIcon: const Icon(Icons.add_task_rounded, size: 20),
              suffixIcon: IconButton(onPressed: _addTask, icon: const Icon(Icons.arrow_upward_rounded)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChecklist(S s) {
    final type = widget.board.eventType ?? EventType.autre;
    final template = ChecklistTemplates.forType(type);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.noTasksTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(s.noTasksBody, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: KSpacing.md),
          BusyButton(
            label: '${s.applyTemplate(eventTypeLabel(s, type))} · ${template.tasks.length}',
            icon: Icons.auto_awesome_rounded,
            busy: _applying,
            onPressed: _applyTemplate,
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends ConsumerWidget {
  const _CountdownCard({required this.board, required this.tasks, required this.vendors});
  final Board board;
  final List<TaskItem> tasks;
  final List<BoardVendor> vendors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final date = board.targetDate;
    final days = date == null ? null : daysUntil(date);
    final top = tasks.where((x) => x.parentId == null).toList();
    final done = top.where((x) => x.done).length;
    final progress = top.isEmpty ? 0.0 : done / top.length;
    final budget = vendors
        .where((v) => v.link.status != VendorStatus.ecarte && v.link.priceEstimate != null)
        .fold<double>(0, (sum, v) => sum + v.link.priceEstimate!);
    final confirmed = vendors.where((v) => v.link.status == VendorStatus.confirme).length;
    final money = NumberFormat.simpleCurrency(locale: locale, name: 'EUR', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(KSpacing.xl),
      decoration: BoxDecoration(
        color: board.color,
        borderRadius: const BorderRadius.all(KRadius.lg),
        boxShadow: KShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      days == null
                          ? s.noDate
                          : days > 0
                              ? s.daysLeft(days)
                              : days == 0
                                  ? s.dDay
                                  : s.datePassed,
                      style: t.displayLarge?.copyWith(color: board.color.onColor, fontSize: days == null ? 22 : 34),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null ? s.setDate : formatLongDate(date, locale),
                      style: t.bodyMedium?.copyWith(color: board.color.onColor.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              Text(board.displayEmoji, style: const TextStyle(fontSize: 40)),
            ],
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: KSpacing.lg),
            ClipRRect(
              borderRadius: const BorderRadius.all(KRadius.full),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: board.color.onColor,
                backgroundColor: board.color.onColor.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(s.tasksProgress(done, top.length), style: t.labelMedium?.copyWith(color: board.color.onColor)),
          ],
          if (vendors.isNotEmpty) ...[
            const SizedBox(height: KSpacing.md),
            Text(
              [
                '${vendors.length} ${s.vendors.toLowerCase()} · $confirmed ${s.confirmedVendors}',
                if (budget > 0) '${s.budgetEstimated} ${money.format(budget)}',
              ].join('  ·  '),
              style: t.labelMedium?.copyWith(color: board.color.onColor.withValues(alpha: 0.9)),
            ),
          ],
        ],
      ),
    );
  }
}

class _VendorRow extends ConsumerWidget {
  const _VendorRow({required this.vendor});
  final BoardVendor vendor;

  Future<void> _pickStatus(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final status = await showKSheet<VendorStatus>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final st in VendorStatus.values)
              ListTile(
                leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: st.color, shape: BoxShape.circle)),
                title: Text(vendorStatusLabel(s, st)),
                trailing: st == vendor.link.status ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, st),
              ),
          ],
        ),
      ),
    );
    if (status == null || !context.mounted) return;
    try {
      await ref.read(contactsProvider.notifier).updateLink(vendor.link, status: status);
    } catch (e) {
      if (context.mounted) handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final c = vendor.contact;
    final price = vendor.link.priceEstimate;
    return Surface(
      padding: const EdgeInsets.all(KSpacing.md),
      onTap: () => showContactSheet(context, c.id),
      child: Row(
        children: [
          InitialsAvatar(initials: c.initials, seed: c.id, size: 40),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [
                    if (c.profession != null) c.profession!,
                    if (price != null) NumberFormat.simpleCurrency(locale: locale, name: vendor.link.currency, decimalDigits: 0).format(price),
                  ].join(' · '),
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          DotChip(
            label: vendorStatusLabel(s, vendor.link.status),
            color: vendor.link.status.color,
            onTap: () => _pickStatus(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Checklist extends ConsumerWidget {
  const _Checklist({required this.board, required this.tasks, required this.vendors});
  final Board board;
  final List<TaskItem> tasks;
  final List<BoardVendor> vendors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final top = tasks.where((x) => x.parentId == null).toList();
    final subtasks = <String, List<TaskItem>>{};
    for (final x in tasks.where((x) => x.parentId != null)) {
      subtasks.putIfAbsent(x.parentId!, () => []).add(x);
    }

    // Groups: overdue, then by month of due date, then undated; done tasks last in each group.
    final overdue = top.where((x) => x.isOverdue()).toList();
    final dated = top.where((x) => x.dueDate != null && !x.isOverdue()).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final undated = top.where((x) => x.dueDate == null).toList();

    final groups = <(String, List<TaskItem>)>[];
    if (overdue.isNotEmpty) groups.add((s.overdue, overdue));
    final byMonth = <String, List<TaskItem>>{};
    for (final x in dated) {
      final key = formatMonthYear(x.dueDate!, locale);
      byMonth.putIfAbsent(key, () => []).add(x);
    }
    for (final e in byMonth.entries) {
      groups.add((e.key[0].toUpperCase() + e.key.substring(1), e.value));
    }
    if (undated.isNotEmpty) groups.add((s.noDueDate, undated));

    final vendorNames = {for (final v in vendors) v.contact.id: v.contact.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, items) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(KSpacing.xs, KSpacing.md, 0, KSpacing.xs),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: label == s.overdue ? KColors.err : KColors.t2),
            ),
          ),
          Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final task in [...items.where((x) => !x.done), ...items.where((x) => x.done)]) ...[
                  _TaskRow(board: board, task: task, vendorName: vendorNames[task.contactId]),
                  for (final sub in subtasks[task.id] ?? const <TaskItem>[])
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: _TaskRow(board: board, task: sub, vendorName: vendorNames[sub.contactId]),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.board, required this.task, this.vendorName});
  final Board board;
  final TaskItem task;
  final String? vendorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final notifier = ref.read(boardTasksProvider(board.id).notifier);
    return InkWell(
      onTap: () => showTaskSheet(context, board: board, task: task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: task.done,
              onChanged: (_) async {
                try {
                  await notifier.toggle(task);
                } catch (e) {
                  if (context.mounted) handleError(context, e);
                }
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: t.bodyLarge?.copyWith(
                        decoration: task.done ? TextDecoration.lineThrough : null,
                        color: task.done ? KColors.t3 : KColors.t1,
                      ),
                    ),
                    if (task.dueDate != null || vendorName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (task.dueDate != null) formatShortDate(task.dueDate!, locale),
                            if (vendorName != null) vendorName!,
                          ].join(' · '),
                          style: t.bodySmall?.copyWith(color: task.isOverdue() ? KColors.err : KColors.t3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
