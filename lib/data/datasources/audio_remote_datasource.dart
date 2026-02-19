import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/audios_response_model.dart';

/// Fetches audios from the remote API. Data layer only; no domain types.
abstract interface class AudioRemoteDatasource {
  Future<AudiosResponseModel> fetchAudios({
    int page = 1,
    int perPage = 10,
    String type = 'bhajan',
  });
}

final class AudioRemoteDatasourceImpl implements AudioRemoteDatasource {
  AudioRemoteDatasourceImpl({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AudiosResponseModel> fetchAudios({
    int page = 1,
    int perPage = 10,
    String type = ApiConstants.defaultType,
  }) async {
    final uri = Uri.parse(ApiConstants.audiosBaseUrl).replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
        'type': type,
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load audios: ${response.statusCode}');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return AudiosResponseModel.fromJson(map);
  }
}
