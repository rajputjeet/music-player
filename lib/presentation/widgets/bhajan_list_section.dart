import 'package:flutter/material.dart';

import '../../domain/entities/audio_entity.dart';

class BhajanListSection extends StatefulWidget {
  const BhajanListSection({
    super.key,
    required this.audios,
    required this.loading,
    required this.loadingMore,
    this.error,
    required this.hasMore,
    required this.onPlay,
    required this.onLoadMore,
    required this.onRetry,
  });

  final List<AudioEntity> audios;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool hasMore;
  final void Function(int indexInList) onPlay;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  State<BhajanListSection> createState() => _BhajanListSectionState();
}

class _BhajanListSectionState extends State<BhajanListSection> {
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
      return const Center(child: Text('No bhajans yet.'));
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
        return _SongTile(
          audio: audio,
          onTap: () => widget.onPlay(index),
        );
      },
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.audio, required this.onTap});

  final AudioEntity audio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(audio.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${audio.duration} • ${audio.type}'),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_fill),
        onPressed: onTap,
        color: Theme.of(context).colorScheme.primary,
      ),
      onTap: onTap,
    );
  }
}
