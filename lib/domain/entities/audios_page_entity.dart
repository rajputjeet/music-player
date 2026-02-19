import 'audio_entity.dart';

/// Result of a paginated audios request.
class AudiosPageEntity {
  const AudiosPageEntity({
    required this.audios,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  final List<AudioEntity> audios;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;
}
