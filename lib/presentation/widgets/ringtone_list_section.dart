import 'package:flutter/material.dart';

import '../../domain/entities/audio_entity.dart';
import 'ringtone_play_dialog.dart';

/// Ringtone list: play (dialog), set as ringtone, download. Infinite scroll.
class RingtoneListSection extends StatefulWidget {
  const RingtoneListSection({
    super.key,
    required this.audios,
    required this.loading,
    required this.loadingMore,
    this.error,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRetry,
  });

  final List<AudioEntity> audios;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  State<RingtoneListSection> createState() => _RingtoneListSectionState();
}

class _RingtoneListSectionState extends State<RingtoneListSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || widget.loadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  void _openPlayDialog(AudioEntity audio) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RingtonePlayDialog(audio: audio),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: widget.onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (widget.audios.isEmpty) {
      return const Center(child: Text('No ringtones yet.'));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.audios.length + (widget.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.audios.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final audio = widget.audios[index];
        return _RingtoneTile(
          audio: audio,
          onPlay: () => _openPlayDialog(audio),
        );
      },
    );
  }
}

class _RingtoneTile extends StatelessWidget {
  const _RingtoneTile({required this.audio, required this.onPlay});

  final AudioEntity audio;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(Icons.ring_volume, color: Theme.of(context).colorScheme.onSecondaryContainer),
      ),
      title: Text(audio.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${audio.duration} • ringtone'),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_fill),
        onPressed: onPlay,
        color: Theme.of(context).colorScheme.primary,
      ),
      onTap: onPlay,
    );
  }
}
