import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/player_controller.dart';

/// Provides the single [PlayerController] with auto-pagination support.
/// The controller will automatically load more pages when approaching the end.
/// The loadMoreCallback should be set by the caller (HomeScreen) based on current audio type.
final playerControllerProvider = Provider<PlayerController>((ref) {
  // Default callback - will be replaced by HomeScreen
  final controller = PlayerController(null);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Whether the bhajan player bottom bar is expanded (true) or collapsed (false).
final playerBarExpandedProvider = StateProvider<bool>((ref) => false);
