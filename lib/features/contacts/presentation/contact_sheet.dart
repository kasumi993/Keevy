import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/k_image.dart';
import '../../boards/presentation/labels.dart';
import '../../boards/presentation/widgets/board_picker.dart';
import '../application/contacts_providers.dart';
import '../domain/contact.dart';
import 'contact_form.dart';

/// Vendor detail as a slide-over: never lose the context you came from.
Future<void> showContactSheet(BuildContext context, String contactId) {
  return showKSheet<void>(context, expand: true, builder: (_) => ContactSheet(contactId: contactId));
}

class ContactSheet extends ConsumerWidget {
  const ContactSheet({super.key, required this.contactId});
  final String contactId;

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final detailAsync = ref.watch(contactDetailProvider(contactId));
    return AsyncBody<ContactDetail?>(
      value: detailAsync,
      onRetry: () => ref.invalidate(contactDetailProvider(contactId)),
      data: (detail) {
        if (detail == null) return Center(child: Text(s.errGeneric));
        final c = detail.contact;
        final t = Theme.of(context).textTheme;
        final locale = Localizations.localeOf(context).languageCode;
        final isOwner = c.ownerId == ref.watch(currentUserIdProvider);

        final actions = <({IconData icon, String label, String url})>[
          if (c.phone != null) (icon: Icons.phone_rounded, label: s.call, url: 'tel:${c.phone!.replaceAll(' ', '')}'),
          if (c.email != null) (icon: Icons.mail_rounded, label: s.email, url: 'mailto:${c.email}'),
          if (c.instagram != null) (icon: Icons.camera_alt_rounded, label: s.instagram, url: 'https://instagram.com/${c.instagram}'),
          if (c.tiktok != null) (icon: Icons.music_note_rounded, label: s.tiktok, url: 'https://www.tiktok.com/@${c.tiktok}'),
          if (c.website != null)
            (icon: Icons.language_rounded, label: s.website, url: c.website!.startsWith('http') ? c.website! : 'https://${c.website}'),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xxl),
          children: [
            Row(
              children: [
                InitialsAvatar(initials: c.initials, seed: c.id, size: 60),
                const SizedBox(width: KSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: t.displaySmall),
                      if (c.profession != null) Text(c.profession!, style: t.bodyMedium),
                      if (c.recommendedBy != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('${s.recommendedBy} ${c.recommendedBy}', style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
                if (isOwner)
                  IconButton(
                    tooltip: s.edit,
                    onPressed: () async {
                      final msg = await showContactFormSheet(context, initial: ContactDraft.fromContact(c), contactId: c.id, askBoard: false);
                      if (msg != null) ref.invalidate(contactDetailProvider(contactId));
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: KSpacing.lg),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: actions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: KSpacing.sm),
                  itemBuilder: (context, i) {
                    final a = actions[i];
                    return SizedBox(
                      width: 76,
                      child: Surface(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onTap: () => _launch(a.url),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(a.icon, size: 20, color: KColors.t1),
                            const SizedBox(height: 4),
                            Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: KColors.t2)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            SectionTitle(
              s.contactBoards,
              padding: const EdgeInsets.fromLTRB(0, KSpacing.xl, 0, KSpacing.sm),
              trailing: TextButton.icon(
                onPressed: () => _addToBoard(context, ref, c),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(s.addToBoard),
              ),
            ),
            for (final link in c.links) ...[
              _BoardLinkTile(link: link, locale: locale),
              const SizedBox(height: KSpacing.sm),
            ],
            if ((c.notes ?? '').isNotEmpty) ...[
              SectionTitle(s.notes, padding: const EdgeInsets.fromLTRB(0, KSpacing.lg, 0, KSpacing.sm)),
              Surface(child: Text(c.notes!, style: t.bodyLarge)),
            ],
            SectionTitle(s.miniBoard, padding: const EdgeInsets.fromLTRB(0, KSpacing.xl, 0, KSpacing.sm)),
            if (detail.cards.isEmpty)
              Text(s.miniBoardEmpty, style: t.bodyMedium)
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final card in detail.cards)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go('/boards/${card.boardId}');
                      },
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(KRadius.sm),
                        child: card.hasImage
                            ? KImage(path: card.imagePath, url: card.imageUrl)
                            : Container(
                                color: KColors.notePapers.first,
                                padding: const EdgeInsets.all(8),
                                child: Text(card.title ?? card.body ?? card.domain ?? '', maxLines: 5, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: KColors.t1)),
                              ),
                      ),
                    ),
                ],
              ),
            if (detail.tasks.isNotEmpty) ...[
              SectionTitle(s.linkedTasks, padding: const EdgeInsets.fromLTRB(0, KSpacing.xl, 0, KSpacing.sm)),
              Surface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final task in detail.tasks)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          task.done ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: task.done ? KColors.ok : (task.isOverdue() ? KColors.err : KColors.t3),
                        ),
                        title: Text(task.title, style: TextStyle(decoration: task.done ? TextDecoration.lineThrough : null)),
                        subtitle: Text([
                          if (task.boardName != null) task.boardName!,
                          if (task.dueDate != null) formatShortDate(task.dueDate!, locale),
                        ].join(' · ')),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: KSpacing.xl),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: KColors.err),
              onPressed: () async {
                final ok = await confirmAction(context, title: s.deleteContact, body: s.deleteContactBody, confirmLabel: s.delete);
                if (!ok || !context.mounted) return;
                final notifier = ref.read(contactsProvider.notifier);
                Navigator.of(context).pop();
                try {
                  await notifier.delete(c);
                } catch (_) {}
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(s.deleteContact),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToBoard(BuildContext context, WidgetRef ref, Contact c) async {
    final s = S.of(context);
    final boardId = await showKSheet<String>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.addToBoard, style: Theme.of(ctx).textTheme.displaySmall),
            const SizedBox(height: KSpacing.lg),
            BoardPicker(
              selectedId: null,
              excludeIds: {for (final l in c.links) l.boardId},
              onSelected: (b) => Navigator.pop(ctx, b.id),
            ),
          ],
        ),
      ),
    );
    if (boardId == null || !context.mounted) return;
    try {
      await ref.read(contactsProvider.notifier).linkToBoard(c.id, boardId);
    } catch (e) {
      if (context.mounted) handleError(context, e);
    }
  }
}

class _BoardLinkTile extends ConsumerWidget {
  const _BoardLinkTile({required this.link, required this.locale});
  final BoardContactLink link;
  final String locale;

  Future<void> _editPrice(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final text = await promptText(
      context,
      title: s.priceEstimate,
      initial: link.priceEstimate?.toStringAsFixed(0),
      hint: '1200',
    );
    if (text == null) return;
    final value = double.tryParse(text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.'));
    try {
      await ref.read(contactsProvider.notifier).updateLink(link, price: value, clearPrice: value == null);
    } catch (e) {
      if (context.mounted) handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final color = link.boardColor ?? KColors.brown;
    return Surface(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/boards/${link.boardId}');
                  },
                  child: Text(link.boardName ?? '', style: t.titleMedium),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (v) async {
                  if (v == 'remove') {
                    try {
                      await ref.read(contactsProvider.notifier).unlinkFromBoard(link.contactId, link.boardId);
                    } catch (e) {
                      if (context.mounted) handleError(context, e);
                    }
                  }
                },
                itemBuilder: (_) => [PopupMenuItem(value: 'remove', child: Text(s.removeFromBoard))],
              ),
            ],
          ),
          // Vendor status only makes sense in Projet mode (hidden for Inspiration boards).
          if (link.showsStatus) ...[
            const SizedBox(height: KSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final st in VendorStatus.values)
                  DotChip(
                    label: vendorStatusLabel(s, st),
                    color: st.color,
                    filled: st == link.status,
                    dense: true,
                    onTap: () => ref.read(contactsProvider.notifier).updateLink(link, status: st),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            GestureDetector(
              onTap: () => _editPrice(context, ref),
              child: Text(
                link.priceEstimate == null
                    ? '+ ${s.priceEstimate}'
                    : '${s.priceEstimate} : ${NumberFormat.simpleCurrency(locale: locale, name: link.currency, decimalDigits: 0).format(link.priceEstimate)}',
                style: t.labelMedium?.copyWith(color: KColors.info),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
