import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/boards/application/boards_providers.dart';
import '../theme/tokens.dart';

/// Displays a private storage image (signed URL) or a remote image URL.
class KImage extends ConsumerWidget {
  const KImage({super.key, this.path, this.url, this.fit = BoxFit.cover, this.placeholderColor});

  final String? path;
  final String? url;
  final BoxFit fit;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = Container(color: placeholderColor ?? KColors.surf2);
    final p = path;
    if (p != null) {
      final cached = ref.watch(cardsRepositoryProvider).cachedSignedUrl(p);
      final signed = cached ?? ref.watch(signedImageUrlProvider(p)).valueOrNull;
      if (signed == null) return placeholder;
      return _network(signed, cacheKey: p, placeholder: placeholder);
    }
    final u = url;
    if (u == null || u.isEmpty) return placeholder;
    return _network(u, placeholder: placeholder);
  }

  Widget _network(String src, {String? cacheKey, required Widget placeholder}) {
    return CachedNetworkImage(
      imageUrl: src,
      cacheKey: cacheKey,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => Container(
        color: placeholderColor ?? KColors.surf2,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: KColors.t3, size: 22),
      ),
    );
  }
}
