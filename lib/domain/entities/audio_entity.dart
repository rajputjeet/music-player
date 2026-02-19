/// Domain entity for an audio track. No JSON or platform details.
class AudioEntity {
  const AudioEntity({
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
}
