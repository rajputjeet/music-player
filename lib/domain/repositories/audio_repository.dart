import '../entities/audios_page_entity.dart';
import '../../core/errors/failures.dart';

/// Contract for fetching audios. Implemented in the data layer.
abstract interface class AudioRepository {
  /// Fetches a page of audios.
  /// Returns [AudiosPageEntity] on success or throws [Failure].
  Future<AudiosPageEntity> getAudios({
    int page = 1,
    int perPage = 10,
    String type = 'bhajan',
  });
}
