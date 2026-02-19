import '../../domain/entities/audios_page_entity.dart';
import 'audio_model.dart';

/// Data model for the API audios list response.
class AudiosResponseModel {
  const AudiosResponseModel({
    required this.status,
    required this.statusCode,
    required this.message,
    required this.data,
    required this.total,
    required this.perPage,
    required this.lastPage,
    required this.currentPage,
  });

  final bool status;
  final int statusCode;
  final String message;
  final List<AudioModel> data;
  final int total;
  final int perPage;
  final int lastPage;
  final int currentPage;

  factory AudiosResponseModel.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? [];
    return AudiosResponseModel(
      status: json['status'] as bool? ?? false,
      statusCode: json['status_code'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      data: list
          .map((e) => AudioModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      perPage: json['per_page'] as int? ?? 10,
      lastPage: json['last_page'] as int? ?? 1,
      currentPage: json['current_page'] as int? ?? 1,
    );
  }

  AudiosPageEntity toEntity() {
    return AudiosPageEntity(
      audios: data.map((e) => e.toEntity()).toList(),
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
      perPage: perPage,
    );
  }
}
