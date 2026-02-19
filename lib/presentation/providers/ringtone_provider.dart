import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ringtone_service.dart';

final ringtoneServiceProvider = Provider<RingtoneService>((ref) {
  return RingtoneService();
});
