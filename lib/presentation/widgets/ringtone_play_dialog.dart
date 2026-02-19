import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/audio_entity.dart';
import '../player/player_controller.dart';
import '../providers/player_provider.dart';
import '../providers/ringtone_provider.dart';

/// Dialog: play/pause, seek bar, Set as ringtone, Download.
/// Uses the shared [PlayerController] in preview mode (single player instance).
class RingtonePlayDialog extends ConsumerStatefulWidget {
  const RingtonePlayDialog({super.key, required this.audio});

  final AudioEntity audio;

  @override
  ConsumerState<RingtonePlayDialog> createState() => _RingtonePlayDialogState();
}

class _RingtonePlayDialogState extends ConsumerState<RingtonePlayDialog> {
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _settingRingtone = false;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPreview());
  }

  void _startPreview() {
    final player = ref.read(playerControllerProvider);
    _playing = player.isPlaying;
    _position = Duration.zero;
    _duration = null;

    _playingSub = player.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    _positionSub = player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    player.enterPreviewMode(widget.audio.path);
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    ref.read(playerControllerProvider).exitPreviewMode();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _setAsRingtone() async {
    setState(() {
      _settingRingtone = true;
      _error = null;
    });
    try {
      await ref.read(ringtoneServiceProvider).setAsRingtone(widget.audio);
      if (mounted) {
        setState(() => _settingRingtone = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set as ringtone successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _settingRingtone = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final path = await ref.read(ringtoneServiceProvider).downloadToAppDir(widget.audio);
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerControllerProvider);
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds > 0
        ? _position.inMilliseconds / total.inMilliseconds
        : 0.0;

    return AlertDialog(
      title: Text(
        widget.audio.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seek bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (v) {
                  if (total.inMilliseconds > 0) {
                    player.seek(Duration(
                      milliseconds: (v * total.inMilliseconds).round(),
                    ));
                  }
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_format(_position), style: Theme.of(context).textTheme.bodySmall),
                Text(_format(total), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            // Play / Pause
            Center(
              child: IconButton(
                iconSize: 56,
                icon: Icon(
                  _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  if (_playing) {
                    player.pause();
                  } else {
                    player.play();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            // Two options: Set ringtone, Download
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _settingRingtone ? null : _setAsRingtone,
                    icon: _settingRingtone
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ring_volume),
                    label: const Text('Set ringtone'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(playerControllerProvider).exitPreviewMode();
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
