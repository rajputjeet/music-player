import '../../core/errors/failures.dart';
import '../../domain/entities/audios_page_entity.dart';
import '../../domain/repositories/audio_repository.dart';
import '../datasources/audio_remote_datasource.dart';

/// Implementation of [AudioRepository]. Uses [AudioRemoteDatasource].
final class AudioRepositoryImpl implements AudioRepository {
  AudioRepositoryImpl(this._datasource);

  final AudioRemoteDatasource _datasource;

  @override
  Future<AudiosPageEntity> getAudios({
    int page = 1,
    int perPage = 10,
    String type = 'bhajan',
  }) async {
    try {
      final response = await _datasource.fetchAudios(
        page: page,
        perPage: perPage,
        type: type,
      );
      return response.toEntity();
    } on Exception catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
