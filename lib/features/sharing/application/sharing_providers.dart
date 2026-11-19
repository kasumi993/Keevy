import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/shares_repository.dart';
import '../domain/board_share.dart';

final sharesRepositoryProvider = Provider<SharesRepository>((ref) => SharesRepository(ref.watch(supabaseProvider)));

final boardSharesProvider =
    AsyncNotifierProvider.autoDispose.family<BoardSharesNotifier, List<BoardShare>, String>(BoardSharesNotifier.new);

class BoardSharesNotifier extends AutoDisposeFamilyAsyncNotifier<List<BoardShare>, String> {
  SharesRepository get _repo => ref.read(sharesRepositoryProvider);

  @override
  Future<List<BoardShare>> build(String arg) => _repo.fetchForBoard(arg);

  Future<BoardShare> create(ShareAccess access) async {
    final share = await _repo.create(arg, access);
    state = AsyncData([share, ...state.valueOrNull ?? const []]);
    return share;
  }

  Future<void> revoke(BoardShare share) async {
    state = AsyncData((state.valueOrNull ?? const []).where((s) => s.id != share.id).toList());
    await _repo.revoke(share.id);
  }
}

final sharedBoardProvider = FutureProvider.autoDispose.family<SharedBoardSnapshot?, String>((ref, token) {
  return ref.watch(sharesRepositoryProvider).fetchShared(token);
});
