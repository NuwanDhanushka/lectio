import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/sherpa_tts_config.dart';

class SherpaTtsConfigStore {
  Future<SherpaTtsConfig?> load() async {
    final file = await _configFile();
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, Object?>;
    return SherpaTtsConfig.fromJson(json);
  }

  Future<void> save(SherpaTtsConfig config) async {
    final file = await _configFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  Future<void> clear() async {
    final file = await _configFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _configFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, 'lectio', 'sherpa_tts.json'));
  }
}
