import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../audio/my_audio_handler.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/audio_entity.dart';

/// UI-facing controller using just_audio_background with auto-pagination support.
class PlayerController {
  PlayerController(this._loadMoreCallback) {
    _init();
  }

  Future<void> Function()? _loadMoreCallback;
  
  void setLoadMoreCallback(Future<void> Function()? callback) {
    _loadMoreCallback = callback;
  }
  final AudioPlayer _player = sharedAudioPlayer;
  List<AudioEntity> _playlist = [];
  ConcatenatingAudioSource? _source;
  final StreamController<(int?, int)> _indexLengthController =
      StreamController<(int?, int)>.broadcast();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<SequenceState?>? _sequenceSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  bool _loadingMore = false;
  bool _hasMorePages = true;
  bool _pendingAdvanceOnAppend = false;
  bool _previewMode = false;
  List<AudioEntity>? _savedPlaylist;
  int? _savedIndex;
  bool _savedHasMorePages = true;

  int? _lastIndex;
  int _lastLength = 0;
  bool _lastPlaying = false;

  List<AudioEntity> get playlist => _playlist;

  bool get shuffleEnabled => _player.shuffleModeEnabled;

  LoopMode get loopMode => _player.loopMode;

  AudioEntity? get currentAudio {
    if (_lastIndex == null) return null;
    if (_lastIndex! < 0 || _lastIndex! >= _playlist.length) return null;
    return _playlist[_lastIndex!];
  }

  bool get hasPrevious => _player.hasPrevious;

  bool get hasNext => _player.hasNext;

  bool get isPlaying => _lastPlaying;

  bool get isPreviewMode => _previewMode;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<bool> get playingStream => _player.playerStateStream.map((s) => s.playing);

  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Stream<(int?, int)> get queueIndexAndLengthStream => _indexLengthController.stream;

  void _init() {
    _stateSub = _player.playerStateStream.listen((s) {
      _lastPlaying = s.playing;
      // If we hit the end while more pages exist, fetch and auto-advance once appended.
      if (s.processingState == ProcessingState.completed && _hasMorePages && !_previewMode) {
        // Even if a load is already in progress, remember to advance after items are appended.
        _pendingAdvanceOnAppend = true;
        if (!_loadingMore) {
          _loadMoreAndAppend();
        }
      }
    });
    _sequenceSub = _player.sequenceStateStream.listen((state) {
      if (state == null) return;
      _lastIndex = state.currentIndex;
      _lastLength = state.sequence.length;
      _indexLengthController.add((_lastIndex, _lastLength));

      // Prefetch based on the *actual* sequence length/index.
      if (_loadMoreCallback != null && _hasMorePages && !_loadingMore && !_previewMode) {
        final remaining = _lastLength - _lastIndex! - 1;
        if (remaining <= 8) {
          _loadMoreAndAppend();
        }
      }
    });
    _indexSub = _player.currentIndexStream.listen((i) {
      _lastIndex = i;
      _indexLengthController.add((_lastIndex, _lastLength));
      // Auto-load next page when approaching end (fetch earlier to avoid end-of-queue)
      if (i != null && _loadMoreCallback != null && _hasMorePages && !_loadingMore) {
        final remaining = _lastLength - i - 1;
        if (remaining <= 6) {
          _loadMoreAndAppend();
        }
      }
    });
    _positionSub = _player.positionStream.listen((_) {});
    _durationSub = _player.durationStream.listen((_) {});
  }

  Future<void> _loadMoreAndAppend() async {
    if (_loadingMore || _loadMoreCallback == null || !_hasMorePages) return;
    _loadingMore = true;
    try {
      await _loadMoreCallback!();
      // After loading, the provider state will be updated via ref.listen in HomeScreen
      // which will call appendPlaylist automatically
    } catch (e) {
      // Silently fail - user can manually scroll to load more
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> setPlaylist(
    List<AudioEntity> audios, {
    int startIndex = 0,
    String? audioType,
    bool hasMorePages = true,
  }) async {
    _playlist = List.from(audios);
    _hasMorePages = hasMorePages;
    final sources = _playlist.map((e) {
      return AudioSource.uri(
        Uri.parse(e.path),
        tag: MediaItem(
          id: e.id.toString(),
          title: e.title,
          album: e.type,
          artUri: Uri.parse(ApiConstants.notificationArtUrl),
        ),
      );
    }).toList();
    _source = ConcatenatingAudioSource(children: sources);
    await _player.setAudioSource(_source!, initialIndex: startIndex);
    _lastLength = _playlist.length;
    _lastIndex = startIndex.clamp(0, _playlist.length - 1);
    _indexLengthController.add((_lastIndex, _lastLength));
    audioHandler.setQueueFromEntities(_playlist, currentIndex: _lastIndex ?? 0);
  }

  /// Append more audios to the existing playlist without resetting playback.
  Future<void> appendPlaylist(
    List<AudioEntity> newAudios, {
    bool hasMorePages = true,
  }) async {
    if (newAudios.isEmpty) {
      _hasMorePages = hasMorePages;
      return;
    }
    if (_source == null) {
      // No existing queue; fallback to setting as a fresh playlist.
      await setPlaylist(newAudios, startIndex: 0, hasMorePages: hasMorePages);
      return;
    }
    
    _playlist.addAll(newAudios);
    _hasMorePages = hasMorePages;

    // Append into the existing concatenating source (keeps currentIndex/position stable)
    final sourcesToAdd = newAudios.map((e) {
      return AudioSource.uri(
        Uri.parse(e.path),
        tag: MediaItem(
          id: e.id.toString(),
          title: e.title,
          album: e.type,
          artUri: Uri.parse(ApiConstants.notificationArtUrl),
        ),
      );
    }).toList();
    await _source!.addAll(sourcesToAdd);

    _lastLength = _playlist.length;
    _lastIndex = _player.currentIndex;
    _indexLengthController.add((_lastIndex, _lastLength));
    audioHandler.setQueueFromEntities(
      _playlist,
      currentIndex: _lastIndex ?? 0,
    );

    // If we reached the end before the append completed, advance now.
    final shouldAdvance =
        _pendingAdvanceOnAppend || _player.processingState == ProcessingState.completed;
    if (shouldAdvance) {
      _pendingAdvanceOnAppend = false;
      if (_player.hasNext) {
        await _player.seekToNext();
        await _player.play();
      }
    }
  }

  Future<void> play() async => await _player.play();

  Future<void> pause() async => await _player.pause();

  Future<void> stop() async => await _player.stop();

  Future<void> seek(Duration position) async => await _player.seek(position);

  Future<void> skipToNext() async => await _player.seekToNext();

  Future<void> skipToPrevious() async => await _player.seekToPrevious();

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
    if (enabled) {
      // When enabling shuffle, load all remaining pages for seamless shuffle
      await _loadAllRemainingPages();
      if (_source != null && (_player.sequence?.length ?? 0) > 1) {
        await _player.shuffle();
      }
    }
  }

  Future<void> toggleShuffle() async {
    final newEnabled = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(newEnabled);
    if (newEnabled) {
      // Load all remaining pages when enabling shuffle
      await _loadAllRemainingPages();
      if (_source != null && (_player.sequence?.length ?? 0) > 1) {
        await _player.shuffle();
      }
    }
  }

  /// Load all remaining pages for shuffle mode.
  /// This triggers the callback which loads pages, and HomeScreen's ref.listen
  /// will automatically append new items via appendPlaylist.
  Future<void> _loadAllRemainingPages() async {
    if (_loadMoreCallback == null || !_hasMorePages) return;
    // Load pages in batches - HomeScreen will append them automatically
    int attempts = 0;
    while (_hasMorePages && _loadMoreCallback != null && attempts < 50) {
      attempts++;
      await _loadMoreCallback!();
      // Wait for provider state to update and appendPlaylist to be called
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> setLoopMode(LoopMode mode) async => await _player.setLoopMode(mode);

  /// Play a single URL (e.g. ringtone preview). Saves current playlist and restores on exit.
  Future<void> enterPreviewMode(String url) async {
    if (_previewMode) return;
    _savedPlaylist = _playlist.isEmpty ? null : List.from(_playlist);
    _savedIndex = _lastIndex;
    _savedHasMorePages = _hasMorePages;
    _previewMode = true;
    await _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(
          id: 'preview',
          title: 'Preview',
          album: '',
          artUri: Uri.parse(ApiConstants.notificationArtUrl),
        ),
      ),
    );
    await _player.play();
  }

  /// Exit preview and restore previous playlist (or clear if none).
  Future<void> exitPreviewMode() async {
    if (!_previewMode) return;
    _previewMode = false;
    await _player.stop();
    if (_savedPlaylist != null && _savedPlaylist!.isNotEmpty) {
      await setPlaylist(
        _savedPlaylist!,
        startIndex: _savedIndex ?? 0,
        hasMorePages: _savedHasMorePages,
      );
    } else {
      _playlist = [];
      _source = null;
      _lastLength = 0;
      _lastIndex = null;
      _indexLengthController.add((null, 0));
    }
    _savedPlaylist = null;
    _savedIndex = null;
  }

  Future<void> toggleRepeat() async {
    final next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
  }

  void dispose() {
    _stateSub?.cancel();
    _indexSub?.cancel();
    _sequenceSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _indexLengthController.close();
    _player.dispose();
  }
}
