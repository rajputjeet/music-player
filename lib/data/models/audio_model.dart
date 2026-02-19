import '../../domain/entities/audio_entity.dart';

/// Data model for audio. Maps from API JSON and to domain entity.
class AudioModel {
  const AudioModel({
    required this.id,
    required this.title,
    required this.type,
    required this.duration,
    required this.path,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String type;
  final String duration;
  final String path;
  final String createdAt;
  final String updatedAt;

  factory AudioModel.fromJson(Map<String, dynamic> json) {
    return AudioModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? '',
      duration: json['duration'] as String? ?? '0:00',
      path: json['path'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  AudioEntity toEntity() {
    return AudioEntity(
      id: id,
      title: title,
      type: type,
      duration: duration,
      path: path,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
