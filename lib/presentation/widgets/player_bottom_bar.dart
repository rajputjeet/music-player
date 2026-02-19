import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../domain/entities/audio_entity.dart';
import '../player/player_controller.dart';
import '../providers/player_provider.dart';

class PlayerBottomBar extends ConsumerStatefulWidget {
  const PlayerBottomBar({super.key});

  @override
  ConsumerState<PlayerBottomBar> createState() => _PlayerBottomBarState();
}

class _PlayerBottomBarState extends ConsumerState<PlayerBottomBar> {
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<(int?, int)>? _queueSub;

  bool _playing = false;
  AudioEntity? _currentAudio;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _attach(ref.read(playerControllerProvider)));
  }

  void _attach(PlayerController player) {
    _playing = player.isPlaying;
    _currentAudio = player.currentAudio;
    _position = Duration.zero;
    _duration = null;

    _playingSub = player.playingStream.listen(_onPlaying);
    _indexSub = player.currentIndexStream.listen(_onIndex);
    _positionSub = player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    // Rebuild when queue length/index changes so hasNext/hasPrevious reflect new pages.
    _queueSub = player.queueIndexAndLengthStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onPlaying(bool playing) {
    if (mounted) setState(() => _playing = playing);
  }

  void _onIndex(int? i) {
    if (mounted) {
      final player = ref.read(playerControllerProvider);
      setState(() => _currentAudio = player.currentAudio);
    }
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _indexSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openExpandedPlayer(BuildContext context) {
    final player = ref.read(playerControllerProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExpandedPlayerSheet(
        playing: _playing,
        player: player,
        onPlayPause: () {
          if (_playing) {
            player.pause();
          } else {
            player.play();
          }
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerControllerProvider);
    final hasTrack = _currentAudio != null || player.isPreviewMode;
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds > 0
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final title = player.isPreviewMode ? 'Preview' : (_currentAudio?.title ?? '');
    final durationText = player.isPreviewMode
        ? _duration != null
            ? _formatDuration(_duration!)
            : '--:--'
        : (_currentAudio?.duration ?? '');

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface.withValues(alpha: 0.98),
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasTrack ? () => _openExpandedPlayer(context) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasTrack) ...[
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor:
                            colorScheme.primary.withValues(alpha: 0.85),
                        inactiveTrackColor: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.25),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (v) {
                          if (total.inMilliseconds > 0) {
                            player.seek(
                              Duration(
                                milliseconds:
                                    (v * total.inMilliseconds).round(),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      if (hasTrack) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            ApiConstants.notificationArtUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primaryContainer,
                                    colorScheme.secondaryContainer,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.music_note,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                durationText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Expanded(
                          child: Text(
                            'No track selected',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      _ActionBar(
                        player: player,
                        playing: _playing,
                        onPlayPause: () {
                          if (_playing) {
                            player.pause();
                          } else {
                            player.play();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen style sheet: centered artwork with shadow, title/artist, seek bar, actions (Spotify/YT Music style).
class _ExpandedPlayerSheet extends StatefulWidget {
  const _ExpandedPlayerSheet({
    required this.playing,
    required this.player,
    required this.onPlayPause,
    required this.onClose,
  });

  final bool playing;
  final PlayerController player;
  final VoidCallback onPlayPause;
  final VoidCallback onClose;

  @override
  State<_ExpandedPlayerSheet> createState() => _ExpandedPlayerSheetState();
}

class _ExpandedPlayerSheetState extends State<_ExpandedPlayerSheet> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _positionSub = widget.player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = widget.player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  static String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final playing = widget.playing;
    final onPlayPause = widget.onPlayPause;
    final onClose = widget.onClose;
    final audio = player.currentAudio;
    final title = player.isPreviewMode ? 'Preview' : (audio?.title ?? '');
    final subtitle = player.isPreviewMode ? '' : (audio?.type ?? '');
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds > 0
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle + close
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          // Centered artwork with shadow and padding (Spotify/YT Music style)
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 36,
                            spreadRadius: 4,
                            offset: const Offset(0, 18),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            ApiConstants.notificationArtUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primaryContainer,
                                    colorScheme.secondaryContainer,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                Icons.music_note,
                                size: 96,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // Seek bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) {
                      if (total.inMilliseconds > 0) {
                        player.seek(Duration(
                          milliseconds: (v * total.inMilliseconds).round(),
                        ));
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(_position), style: Theme.of(context).textTheme.bodySmall),
                      Text(_format(total), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _ActionBar(
              player: player,
              playing: playing,
              onPlayPause: onPlayPause,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.player,
    required this.playing,
    required this.onPlayPause,
  });

  final PlayerController player;
  final bool playing;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: player.shuffleEnabled
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          onPressed: () => player.toggleShuffle(),
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: player.hasPrevious ? () => player.skipToPrevious() : null,
        ),
        IconButton(
          iconSize: 56,
          icon: Icon(
            playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: onPlayPause,
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: player.hasNext ? () => player.skipToNext() : null,
        ),
      ],
    );
  }
}
