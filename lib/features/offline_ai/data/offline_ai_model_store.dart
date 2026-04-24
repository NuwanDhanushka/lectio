import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/offline_ai_model.dart';

class OfflineAiModelStore {
  static const _settingsFileName = 'offline_ai_settings.json';
  static const _modelsDirectoryName = 'offline_ai_models';

  Future<OfflineAiModel> loadSelectedModel() async {
    final settingsFile = await _settingsFile();
    if (!await settingsFile.exists()) {
      return offlineAiModels.first;
    }

    try {
      final json = jsonDecode(await settingsFile.readAsString());
      if (json is Map<String, Object?>) {
        final selectedModelId = json['selected_model_id'];
        if (selectedModelId is String) {
          return offlineAiModelById(selectedModelId);
        }
      }
    } catch (_) {
      return offlineAiModels.first;
    }

    return offlineAiModels.first;
  }

  Future<void> saveSelectedModel(OfflineAiModel model) async {
    final settingsFile = await _settingsFile();
    await settingsFile.parent.create(recursive: true);
    await settingsFile.writeAsString(
      jsonEncode({'selected_model_id': model.id}),
    );
  }

  Future<String> modelPath(OfflineAiModel model) async {
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, _modelsDirectoryName, model.fileName);
  }

  Future<bool> isInstalled(OfflineAiModel model) async {
    return File(await modelPath(model)).exists();
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, _settingsFileName));
  }
}
