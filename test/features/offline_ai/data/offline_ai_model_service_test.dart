import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/offline_ai/data/offline_ai_model_downloader.dart';
import 'package:lectio/features/offline_ai/data/offline_ai_model_service.dart';
import 'package:lectio/features/offline_ai/data/offline_ai_model_store.dart';
import 'package:lectio/features/offline_ai/domain/offline_ai_model.dart';

const _altModel = OfflineAiModel(
  id: 'tiny_local',
  name: 'Tiny Local',
  fileName: 'tiny.gguf',
  sizeLabel: '~10 MB',
  description: 'Test model',
  downloadUrl: 'https://example.com/tiny.gguf',
  sha256: '',
);

class _FakeOfflineAiModelStore extends OfflineAiModelStore {
  OfflineAiModel loadedModel = offlineAiModels.first;
  final Map<String, bool> installedById = <String, bool>{};
  final Map<String, String> pathById = <String, String>{};
  OfflineAiModel? savedModel;

  @override
  Future<OfflineAiModel> loadSelectedModel() async => loadedModel;

  @override
  Future<void> saveSelectedModel(OfflineAiModel model) async {
    savedModel = model;
  }

  @override
  Future<String> modelPath(OfflineAiModel model) async {
    return pathById[model.id] ?? '/models/${model.fileName}';
  }

  @override
  Future<bool> isInstalled(OfflineAiModel model) async {
    return installedById[model.id] ?? false;
  }
}

class _FakeOfflineAiModelDownloader extends OfflineAiModelDownloader {
  String? lastDownloadedTargetPath;
  OfflineAiModel? lastDownloadedModel;
  String? lastDeletedPath;
  Object? downloadError;
  final List<double> emittedProgress = <double>[];

  @override
  Future<String> downloadModel({
    required OfflineAiModel model,
    required String targetPath,
    required OfflineAiDownloadProgressCallback onProgress,
  }) async {
    if (downloadError != null) {
      throw downloadError!;
    }
    lastDownloadedModel = model;
    lastDownloadedTargetPath = targetPath;
    onProgress(0.25);
    emittedProgress.add(0.25);
    onProgress(0.75);
    emittedProgress.add(0.75);
    return targetPath;
  }

  @override
  Future<void> deleteModel(String path) async {
    lastDeletedPath = path;
  }
}

void main() {
  group('OfflineAiModelService', () {
    late _FakeOfflineAiModelStore store;
    late _FakeOfflineAiModelDownloader downloader;
    late OfflineAiModelService service;

    setUp(() {
      store = _FakeOfflineAiModelStore();
      downloader = _FakeOfflineAiModelDownloader();
      service = OfflineAiModelService(
        store: store,
        downloader: downloader,
      );
    });

    test('initializes with default model when nothing is installed', () async {
      await service.ensureInitialized();

      expect(service.state.selectedModel, offlineAiModels.first);
      expect(service.state.status, OfflineAiModelStatus.notInstalled);
      expect(service.state.localPath, isNull);
    });

    test('initializes with saved installed model as ready', () async {
      store.loadedModel = _altModel;
      store.installedById[_altModel.id] = true;
      store.pathById[_altModel.id] = '/models/tiny.gguf';

      await service.ensureInitialized();

      expect(service.state.selectedModel, _altModel);
      expect(service.state.status, OfflineAiModelStatus.ready);
      expect(service.state.localPath, '/models/tiny.gguf');
    });

    test('selectModel updates state and persists selection', () async {
      store.pathById[_altModel.id] = '/models/tiny.gguf';

      await service.selectModel(_altModel);

      expect(service.state.selectedModel, _altModel);
      expect(service.state.status, OfflineAiModelStatus.notInstalled);
      expect(store.savedModel, _altModel);
    });

    test('downloadSelectedModel updates progress and ends ready', () async {
      store.pathById[offlineAiModels.first.id] = '/models/qwen.gguf';

      await service.downloadSelectedModel();

      expect(downloader.lastDownloadedModel, offlineAiModels.first);
      expect(downloader.lastDownloadedTargetPath, '/models/qwen.gguf');
      expect(downloader.emittedProgress, [0.25, 0.75]);
      expect(service.state.status, OfflineAiModelStatus.ready);
      expect(service.state.downloadProgress, 1);
      expect(service.state.localPath, '/models/qwen.gguf');
      expect(service.state.errorMessage, isNull);
    });

    test('downloadSelectedModel ends in error when download fails', () async {
      downloader.downloadError = Exception('network failed');

      await service.downloadSelectedModel();

      expect(service.state.status, OfflineAiModelStatus.error);
      expect(service.state.downloadProgress, 0);
      expect(service.state.errorMessage, contains('network failed'));
    });

    test('deleteSelectedModel removes file and resets state', () async {
      store.loadedModel = _altModel;
      store.installedById[_altModel.id] = true;
      store.pathById[_altModel.id] = '/models/tiny.gguf';
      await service.ensureInitialized();

      await service.deleteSelectedModel();

      expect(downloader.lastDeletedPath, '/models/tiny.gguf');
      expect(service.state.selectedModel, _altModel);
      expect(service.state.status, OfflineAiModelStatus.notInstalled);
      expect(service.state.localPath, isNull);
    });
  });
}
