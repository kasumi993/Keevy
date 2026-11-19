import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../planning/application/planning_providers.dart';
import '../../planning/domain/task.dart';
import '../../planning/domain/templates.dart';
import '../application/boards_providers.dart';
import '../domain/board.dart';
import 'labels.dart';

const boardEmojis = ['✨', '💍', '🍼', '🎂', '🏡', '🥂', '📦', '🌸', '👗', '🍰', '🎨', '🌿', '✈️', '🎄', '💡', '📸'];

Future<void> showCreateBoardSheet(BuildContext context, {BoardMode initialMode = BoardMode.inspiration}) async {
  final boardId = await showKSheet<String>(context, builder: (_) => CreateBoardSheet(initialMode: initialMode));
  if (boardId != null && context.mounted) context.go('/boards/$boardId');
}

class CreateBoardSheet extends ConsumerStatefulWidget {
  const CreateBoardSheet({super.key, this.initialMode = BoardMode.inspiration});
  final BoardMode initialMode;

  @override
  ConsumerState<CreateBoardSheet> createState() => _CreateBoardSheetState();
}

class _CreateBoardSheetState extends ConsumerState<CreateBoardSheet> {
  final _name = TextEditingController();
  late BoardMode _mode = widget.initialMode;
  String _emoji = boardEmojis.first;
  Color _color = KColors.boardAccents.first;
  EventType? _eventType;
  DateTime? _date;
  bool _withTemplate = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 180)),
      firstDate: dateOnly(now),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final s = S.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = s.nameRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final isProjet = _mode == BoardMode.projet;
      final type = isProjet ? (_eventType ?? EventType.autre) : null;
      final board = await ref.read(boardsProvider.notifier).create(
            name: name,
            colorHex: _color.toHex(),
            mode: _mode,
            emoji: _emoji,
            eventType: type,
            targetDate: isProjet ? _date : null,
            sections: defaultSectionsFor(type, isFr: s.isFr),
          );
      if (isProjet && _withTemplate) {
        final template = ChecklistTemplates.forType(type);
        await ref.read(tasksRepositoryProvider).insertMany([
          for (var i = 0; i < template.tasks.length; i++)
            TaskItem(
              id: const Uuid().v4(),
              boardId: board.id,
              title: template.tasks[i].title(s.isFr),
              dueDate: template.dueDateFor(template.tasks[i], _date),
              position: i.toDouble(),
              templateKey: template.key,
            ),
        ]);
        await ref.read(boardsProvider.notifier).refresh();
      }
      if (mounted) Navigator.of(context).pop(board.id);
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final isProjet = _mode == BoardMode.projet;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.createBoardTitle, style: t.displaySmall),
          const SizedBox(height: KSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.boardName, hintText: s.boardNameHint, errorText: _error),
          ),
          const SizedBox(height: KSpacing.lg),
          Text(s.boardEmoji, style: t.titleSmall),
          const SizedBox(height: KSpacing.sm),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in boardEmojis)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      margin: const EdgeInsets.only(right: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _emoji == e ? _color.withValues(alpha: 0.18) : KColors.white,
                        borderRadius: const BorderRadius.all(KRadius.sm),
                        border: Border.all(color: _emoji == e ? _color : KColors.border, width: _emoji == e ? 1.5 : 1),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.lg),
          Text(s.boardColor, style: t.titleSmall),
          const SizedBox(height: KSpacing.sm),
          ColorPickerRow(selected: _color, onSelected: (c) => setState(() => _color = c)),
          const SizedBox(height: KSpacing.xl),
          ModeSelector(mode: _mode, onChanged: (m) => setState(() => _mode = m)),
          if (isProjet) ...[
            const SizedBox(height: KSpacing.lg),
            Text(s.eventTypeLabel, style: t.titleSmall),
            const SizedBox(height: KSpacing.sm),
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                for (final type in EventType.values)
                  ChoiceChip(
                    label: Text('${type.emoji} ${eventTypeLabel(s, type)}'),
                    selected: _eventType == type,
                    onSelected: (_) => setState(() {
                      _eventType = type;
                      if (_emoji == boardEmojis.first || boardEmojis.contains(_emoji)) _emoji = type.emoji;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.lg),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(_date == null ? s.pickDate : formatLongDate(_date!, locale)),
            ),
            const SizedBox(height: KSpacing.sm),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _withTemplate,
              onChanged: (v) => setState(() => _withTemplate = v),
              title: Text(s.addTemplateChecklist, style: t.titleMedium),
              subtitle: Text(
                '${ChecklistTemplates.forType(_eventType).tasks.length} ${s.checklist.toLowerCase()}',
                style: t.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: KSpacing.xl),
          BusyButton(label: s.createBoard, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({super.key, required this.selected, required this.onSelected});
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in KColors.boardAccents)
          GestureDetector(
            onTap: () => onSelected(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: c.toHex() == selected.toHex() ? KColors.t1 : Colors.transparent, width: 2.5),
              ),
              child: c.toHex() == selected.toHex() ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
            ),
          ),
      ],
    );
  }
}

/// Inspiration / Projet toggle with descriptions.
class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key, required this.mode, required this.onChanged});
  final BoardMode mode;
  final ValueChanged<BoardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget option(BoardMode m, String emoji, String title, String desc) {
      final selected = m == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: selected ? KColors.primary : KColors.white,
              borderRadius: const BorderRadius.all(KRadius.md),
              border: Border.all(color: selected ? KColors.primary : KColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(fontFamily: KFonts.sans, fontWeight: FontWeight.w700, fontSize: 14, color: selected ? Colors.white : KColors.t1),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontFamily: KFonts.sans, fontSize: 11, height: 1.3, color: selected ? Colors.white70 : KColors.t2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        option(BoardMode.inspiration, '🌸', s.modeInspiration, s.modeInspirationDesc),
        const SizedBox(width: KSpacing.md),
        option(BoardMode.projet, '🗓️', s.modeProjet, s.modeProjetDesc),
      ],
    );
  }
}
