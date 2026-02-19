import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/audio_remote_datasource.dart';
import '../../data/repositories/audio_repository_impl.dart';
import '../../domain/entities/audio_entity.dart';
import '../../domain/entities/audios_page_entity.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../core/constants/api_constants.dart';

/// Provides the remote datasource. Override in tests.
final audioRemoteDatasourceProvider = Provider<AudioRemoteDatasource>((ref) {
  return AudioRemoteDatasourceImpl();
});

/// Provides the audio repository.
final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  final datasource = ref.watch(audioRemoteDatasourceProvider);
  return AudioRepositoryImpl(datasource);
});

/// State for an audios list: supports infinite scroll (append on load more).
class AudiosListState {
  const AudiosListState({
    this.audios = const [],
    this.currentPage = 0,
    this.lastPage = 1,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<AudioEntity> audios;
  final int currentPage;
  final int lastPage;
  final bool loading;
  final bool loadingMore;
  final String? error;

  AudiosListState copyWith({
    List<AudioEntity>? audios,
    int? currentPage,
    int? lastPage,
    bool? loading,
    bool? loadingMore,
    String? error,
  }) {
    return AudiosListState(
      audios: audios ?? this.audios,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }
}

abstract class _BaseAudiosNotifier extends Notifier<AudiosListState> {
  String get audioType;

  @override
  AudiosListState build() => const AudiosListState();

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, error: null);
    final repository = ref.read(audioRepositoryProvider);
    try {
      final AudiosPageEntity result = await repository.getAudios(
        page: 1,
        perPage: ApiConstants.defaultPerPage,
        type: audioType,
      );
      state = state.copyWith(
        audios: result.audios,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        loading: false,
        loadingMore: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.currentPage >= state.lastPage) return;
    state = state.copyWith(loadingMore: true);
    final repository = ref.read(audioRepositoryProvider);
    final nextPage = state.currentPage + 1;
    try {
      final AudiosPageEntity result = await repository.getAudios(
        page: nextPage,
        perPage: ApiConstants.defaultPerPage,
        type: audioType,
      );
      state = state.copyWith(
        audios: [...state.audios, ...result.audios],
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        loadingMore: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }

  void retry() => loadInitial();
}

class _BhajanAudiosNotifier extends _BaseAudiosNotifier {
  @override
  String get audioType => 'bhajan';
}

class _RingtoneAudiosNotifier extends _BaseAudiosNotifier {
  @override
  String get audioType => 'ringtone';
}

final bhajanAudiosProvider =
    NotifierProvider<_BhajanAudiosNotifier, AudiosListState>(_BhajanAudiosNotifier.new);

final ringtoneAudiosProvider =
    NotifierProvider<_RingtoneAudiosNotifier, AudiosListState>(_RingtoneAudiosNotifier.new);
