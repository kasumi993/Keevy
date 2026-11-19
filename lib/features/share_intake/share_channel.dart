import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Something shared to Keevy from another app (Instagram, TikTok, Safari, Photos…).
class SharedItem {
  const SharedItem({required this.type, required this.value, this.mimeType, this.boardId, this.sectionId, this.kind, this.note});

  /// 'text' (text or URL) or 'image' (value = local file path).
  final String type;
  final String value;
  final String? mimeType;

  // Set when the item was already sorted in the iOS share extension.
  final String? boardId;
  final String? sectionId;
  final String? kind; // 'inspiration' | 'vendor'
  final String? note;

  bool get isImage => type == 'image';

  factory SharedItem.fromMap(Map<Object?, Object?> map) => SharedItem(
        type: map['type'] as String? ?? 'text',
        value: map['value'] as String? ?? '',
        mimeType: map['mimeType'] as String?,
        boardId: map['boardId'] as String?,
        sectionId: map['sectionId'] as String?,
        kind: map['kind'] as String?,
        note: map['note'] as String?,
      );
}

/// Bridge to the native share handling:
/// - Android: MainActivity receives ACTION_SEND / ACTION_SEND_MULTIPLE intents.
/// - iOS: the KeevyShare extension writes items into the App Group inbox.
class ShareChannel {
  ShareChannel._();
  static final instance = ShareChannel._();

  static const _channel = MethodChannel('app.keevy/share');
  final _controller = StreamController<List<SharedItem>>.broadcast();
  bool _initialised = false;

  bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Only iOS needs the boards list (the Android share UI is the Flutter app itself).
  bool get syncsBoards => isSupported && defaultTargetPlatform == TargetPlatform.iOS;

  /// Emits whenever new items arrive while the app is running.
  Stream<List<SharedItem>> get onItems => _controller.stream;

  void init() {
    if (_initialised || !isSupported) return;
    _initialised = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final items = await takePending();
        if (items.isNotEmpty) _controller.add(items);
      }
      return null;
    });
  }

  /// Returns and clears the items waiting to be imported.
  Future<List<SharedItem>> takePending() async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeListMethod<Object?>('takePending');
      return [
        for (final r in raw ?? const <Object?>[])
          if (r is Map<Object?, Object?>) SharedItem.fromMap(r),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('share takePending failed: $e');
      return const [];
    }
  }

  /// Gives the iOS share extension the list of boards/sections it can offer.
  Future<void> syncBoards(List<Map<String, Object?>> boards) async {
    if (!isSupported || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('syncBoards', {'boards': boards});
    } on MissingPluginException {
      // Share extension not installed (e.g. simulator build without it).
    } on PlatformException catch (e) {
      debugPrint('share syncBoards failed: $e');
    }
  }

  /// Android: closes the activity started by a share intent, back to the source app.
  Future<void> finishShareActivity() async {
    if (!isSupported || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('finishShare');
    } on MissingPluginException {
      // ignore
    }
  }
}
