import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../core/constants/api_constants.dart';
import '../domain/entities/audio_entity.dart';


final AudioPlayer sharedAudioPlayer = AudioPlayer();

late final MyAudioHandler audioHandler;

Future<void> initAudioService() async {
  final handler = await AudioService.init(
    builder: () => MyAudioHandler(sharedAudioPlayer),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music.channel.audio',
      androidNotificationChannelName: 'Bhajan playback',
      androidNotificationOngoing: true,
    ),
  );
  audioHandler = handler as MyAudioHandler;
}


class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  MyAudioHandler(this._player) {
    _listenToPlayer();
  }

  final AudioPlayer _player;
  List<MediaItem> _queueItems = [];

  static Duration? _parseDuration(String value) {
    // Accepts "mm:ss" or "hh:mm:ss".
    final parts = value.split(':').map((e) => e.trim()).toList();
    if (parts.length < 2 || parts.length > 3) return null;
    final nums = parts.map(int.tryParse).toList();
    if (nums.any((e) => e == null)) return null;
    if (parts.length == 2) {
      final m = nums[0]!;
      final s = nums[1]!;
      return Duration(minutes: m, seconds: s);
    }
    final h = nums[0]!;
    final m = nums[1]!;
    final s = nums[2]!;
    return Duration(hours: h, minutes: m, seconds: s);
  }

  void _listenToPlayer() {
    _player.playerStateStream.listen((_) => _broadcastState());
    _player.positionStream.listen((_) => _broadcastState());
    _player.currentIndexStream.listen((index) {
      if (index != null &&
          index >= 0 &&
          index < _queueItems.length &&
          _queueItems.isNotEmpty) {
        mediaItem.add(_queueItems[index]);
      }
      _broadcastState();
    });
  }

  void setQueueFromEntities(List<AudioEntity> entities, {int currentIndex = 0}) {
    _queueItems = entities
        .map(
          (e) => MediaItem(
            id: e.id.toString(),
            title: e.title,
            album: e.type,
            artUri: Uri.parse(ApiConstants.notificationArtUrl),
            duration: _parseDuration(e.duration),
          ),
        )
        .toList();
    queue.add(_queueItems);
    if (currentIndex >= 0 &&
        currentIndex < _queueItems.length &&
        _queueItems.isNotEmpty) {
      mediaItem.add(_queueItems[currentIndex]);
    }
    _broadcastState();
  }

  void _broadcastState() {
    final playing = _player.playing;
    final processing = _toProcessingState(_player.playerState.processingState);
    final index = _player.currentIndex ?? 0;

    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.custom(
        androidIcon: 'drawable/ic_shuffle',
        label: 'Shuffle',
        name: 'shuffle',
      ),
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processing,
        playing: playing,
        updatePosition: _player.position,
        updateTime: DateTime.now(),
        queueIndex: index,
      ),
    );
  }

  AudioProcessingState _toProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }


  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= (_queueItems.length)) return;
    await _player.seek(Duration.zero, index: index);
    _broadcastState();
  }

  @override
  Future<void> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == 'shuffle') {
      final enabled = _player.shuffleModeEnabled;
      await _player.setShuffleModeEnabled(!enabled);
      if (!enabled && (_player.sequence?.length ?? 0) > 1) {
        await _player.shuffle();
      }
      _broadcastState();
    }
  }
}

