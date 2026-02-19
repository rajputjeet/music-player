import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/bhajan_list_section.dart';
import '../widgets/player_bottom_bar.dart';
import '../widgets/ringtone_list_section.dart';
import '../providers/audio_provider.dart';
import '../providers/player_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentPlayingType; // Track which type is currently playing

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bhajanAudiosProvider.notifier).loadInitial();
      ref.read(ringtoneAudiosProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onPlayBhajan(int indexInList) async {
    final listState = ref.read(bhajanAudiosProvider);
    final audios = listState.audios;
    if (audios.isEmpty) return;

    final player = ref.read(playerControllerProvider);
    final hasMore = listState.currentPage < listState.lastPage;
    
    // Set up callback for loading more bhajan pages
    player.setLoadMoreCallback(() async {
      await ref.read(bhajanAudiosProvider.notifier).loadMore();
    });
    
    _currentPlayingType = 'bhajan';
    
    // Check if we need to set a new playlist or just skip
    if (player.playlist.isEmpty || 
        player.playlist.length != audios.length ||
        !audios.any((a) => player.playlist.any((p) => p.id == a.id))) {
      await player.setPlaylist(
        audios,
        startIndex: indexInList,
        audioType: 'bhajan',
        hasMorePages: hasMore,
      );
    } else {
      player.skipToIndex(indexInList);
    }
    player.play();
  }


  @override
  Widget build(BuildContext context) {
    final player = ref.read(playerControllerProvider);

    // Wire pagination to the player: when a new page is loaded, append it to the queue.
    ref.listen(bhajanAudiosProvider, (previous, next) {
      if (_currentPlayingType != 'bhajan') return;
      if (previous == null || next.audios.length <= previous.audios.length) return;
      final newAudios = next.audios.skip(previous.audios.length).toList();
      if (newAudios.isNotEmpty) {
        final hasMore = next.currentPage < next.lastPage;
        player.appendPlaylist(newAudios, hasMorePages: hasMore);
      }
    });

    ref.listen(ringtoneAudiosProvider, (previous, next) {
      if (_currentPlayingType != 'ringtone') return;
      if (previous == null || next.audios.length <= previous.audios.length) return;
      final newAudios = next.audios.skip(previous.audios.length).toList();
      if (newAudios.isNotEmpty) {
        final hasMore = next.currentPage < next.lastPage;
        player.appendPlaylist(newAudios, hasMorePages: hasMore);
      }
    });

    final bhajanState = ref.watch(bhajanAudiosProvider);
    final ringtoneState = ref.watch(ringtoneAudiosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ringtone'),
            Tab(text: 'Bhajan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RingtoneListSection(
            audios: ringtoneState.audios,
            loading: ringtoneState.loading,
            loadingMore: ringtoneState.loadingMore,
            error: ringtoneState.error,
            hasMore: ringtoneState.currentPage < ringtoneState.lastPage,
            onLoadMore: () =>
                ref.read(ringtoneAudiosProvider.notifier).loadMore(),
            onRetry: () => ref.read(ringtoneAudiosProvider.notifier).retry(),
          ),
          BhajanListSection(
            audios: bhajanState.audios,
            loading: bhajanState.loading,
            loadingMore: bhajanState.loadingMore,
            error: bhajanState.error,
            hasMore: bhajanState.currentPage < bhajanState.lastPage,
            onPlay: _onPlayBhajan,
            onLoadMore: () => ref.read(bhajanAudiosProvider.notifier).loadMore(),
            onRetry: () => ref.read(bhajanAudiosProvider.notifier).retry(),
          ),
        ],
      ),
      bottomNavigationBar: const PlayerBottomBar(),
    );
  }
}
