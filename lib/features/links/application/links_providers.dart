import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../boards/application/boards_providers.dart';
import '../../boards/domain/card_item.dart';

final linksProvider = FutureProvider<List<CardItem>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  // Refresh when boards change (cards added / removed).
  ref.watch(boardsProvider);
  return ref.watch(cardsRepositoryProvider).fetchLinks();
});
