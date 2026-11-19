import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../boards/presentation/labels.dart';
import '../application/contacts_providers.dart';
import '../domain/contact.dart';
import 'contact_form.dart';
import 'contact_sheet.dart';

/// Global address book: every vendor of every project.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _query = '';
  VendorStatus? _status;

  bool _matches(Contact c) {
    if (_status != null && !c.links.any((l) => l.showsStatus && l.status == _status)) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [c.name, c.profession, c.instagram, c.recommendedBy, c.email]
        .whereType<String>()
        .any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-contact',
        tooltip: s.newContact,
        onPressed: () async {
          final message = await showContactFormSheet(context);
          if (message != null && context.mounted) showSnack(context, message);
        },
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: KColors.primary,
          onRefresh: () => ref.read(contactsProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.lg, KSpacing.lg, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.contactsTitle, style: t.displayLarge),
                      Text(s.contactsSubtitle, style: t.bodyMedium),
                      const SizedBox(height: KSpacing.lg),
                      TextField(
                        onChanged: (v) => setState(() => _query = v.trim()),
                        decoration: InputDecoration(
                          hintText: s.searchContacts,
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: KSpacing.md),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(s.all),
                                selected: _status == null,
                                onSelected: (_) => setState(() => _status = null),
                              ),
                            ),
                            for (final st in VendorStatus.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(vendorStatusLabel(s, st)),
                                  selected: _status == st,
                                  selectedColor: st.color,
                                  onSelected: (_) => setState(() => _status = _status == st ? null : st),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...contactsAsync.when<List<Widget>>(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))],
                error: (e, _) => [SliverFillRemaining(child: ErrorState(onRetry: () => ref.invalidate(contactsProvider)))],
                data: (contacts) {
                  if (contacts.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(emoji: '📇', title: s.emptyContactsTitle, body: s.emptyContactsBody),
                      ),
                    ];
                  }
                  final filtered = contacts.where(_matches).toList();
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.md, KSpacing.lg, 120),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: KSpacing.sm),
                        itemBuilder: (context, i) => _ContactTile(contact: filtered[i]),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final best = contact.bestStatus;
    return Surface(
      padding: const EdgeInsets.all(KSpacing.md),
      onTap: () => showContactSheet(context, contact.id),
      child: Row(
        children: [
          InitialsAvatar(initials: contact.initials, seed: contact.id),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (contact.profession != null || contact.instagram != null)
                  Text(
                    [if (contact.profession != null) contact.profession!, if (contact.instagram != null) '@${contact.instagram}'].join(' · '),
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (contact.links.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final l in contact.links.take(3))
                        DotChip(label: l.boardName ?? '', color: l.boardColor ?? KColors.brown, dense: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (best != null) DotChip(label: vendorStatusLabel(s, best), color: best.color, dense: true),
        ],
      ),
    );
  }
}
