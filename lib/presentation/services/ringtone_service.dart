import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ringtone_set_plus/ringtone_set_plus.dart';

import '../../domain/entities/audio_entity.dart';

/// Handles ringtone: play (caller manages player), set as ringtone, download.
class RingtoneService {
  /// Sets the audio as device ringtone (Android).
  Future<void> setAsRingtone(AudioEntity audio) async {
    await RingtoneSet.setRingtoneFromNetwork(audio.path);
  }

  /// Downloads the audio file to app documents and returns the file path.
  /// Request storage permission if needed.
  Future<String> downloadToAppDir(AudioEntity audio) async {
    final status = await Permission.storage.request();
    if (!status.isGranted && !status.isLimited) {
      final manageExternal = await Permission.manageExternalStorage.request();
      if (!manageExternal.isGranted) {
        throw Exception('Storage permission needed to download');
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = audio.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final name = '${audio.id}_${safeTitle.isEmpty ? 'ringtone' : safeTitle}.mp3';
    final file = File('${dir.path}/$name');

    final response = await http.get(Uri.parse(audio.path));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }
}
