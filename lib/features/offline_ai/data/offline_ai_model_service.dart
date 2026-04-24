import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/offline_ai_model.dart';
import 'offline_ai_model_downloader.dart';
import 'offline_ai_model_store.dart';

enum OfflineAiModelStatus {
  notInstalled,
  downloading,
  ready,
  error,
}

class OfflineAiModelState {
  const OfflineAiModelState({
    required this.selectedModel,
    required this.status,
    this.downloadProgress = 0,
    this.localPath,
    this.errorMessage,
  });

  final OfflineAiModel selectedModel;
  final OfflineAiModelStatus status;
  final double downloadProgress;
  final String? localPath;
  final String? errorMessage;

  bool get isReady => status == OfflineAiModelStatus.ready && localPath != null;

  OfflineAiModelState copyWith({
    OfflineAiModel? selectedModel,
    OfflineAiModelStatus? status,
    double? downloadProgress,
    String? localPath,
    String? errorMessage,
  }) {
    return OfflineAiModelState(
      selectedModel: selectedModel ?? this.selectedModel,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage,
    );
  }
}

class OfflineAiModelService extends ChangeNotifier {
  OfflineAiModelService({
    OfflineAiModelStore? store,
    OfflineAiModelDownloader? downloader,
  })  : _store = store ?? OfflineAiModelStore(),
        _downloader = downloader ?? const OfflineAiModelDownloader();

  OfflineAiModelService._()
      : _store = OfflineAiModelStore(),
        _downloader = const OfflineAiModelDownloader();

  static final OfflineAiModelService instance = OfflineAiModelService._();

  final OfflineAiModelStore _store;
  final OfflineAiModelDownloader _downloader;

  OfflineAiModelState _state = OfflineAiModelState(
    selectedModel: offlineAiModels.first,
    status: OfflineAiModelStatus.notInstalled,
  );
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  OfflineAiModelState get state => _state;

  Future<void> ensureInitialized() {
    return _initializationFuture ??= _loadState();
  }

  Future<void> selectModel(OfflineAiModel model) async {
    await ensureInitialized();
    if (_state.selectedModel.id == model.id) {
      return;
    }

    final modelPath = await _store.modelPath(model);
    final isInstalled = await _store.isInstalled(model);
    _state = OfflineAiModelState(
      selectedModel: model,
      status: isInstalled
          ? OfflineAiModelStatus.ready
          : OfflineAiModelStatus.notInstalled,
      localPath: isInstalled ? modelPath : null,
    );
    notifyListeners();
    await _store.saveSelectedModel(model);
  }

  Future<void> downloadSelectedModel() async {
    await ensureInitialized();
    final model = _state.selectedModel;
    if (!model.hasDownloadUrl) {
      _state = _state.copyWith(
        status: OfflineAiModelStatus.error,
        downloadProgress: 0,
        errorMessage: 'Model download URL is not configured yet.',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      status: OfflineAiModelStatus.downloading,
      downloadProgress: 0,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final targetPath = await _store.modelPath(model);
      final localPath = await _downloader.downloadModel(
        model: model,
        targetPath: targetPath,
        onProgress: (progress) {
          _state = _state.copyWith(downloadProgress: progress);
          notifyListeners();
        },
      );

      _state = _state.copyWith(
        status: OfflineAiModelStatus.ready,
        downloadProgress: 1,
        localPath: localPath,
        errorMessage: null,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        status: OfflineAiModelStatus.error,
        downloadProgress: 0,
        errorMessage: error.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> deleteSelectedModel() async {
    await ensureInitialized();
    await _downloader.deleteModel(await _store.modelPath(_state.selectedModel));

    _state = OfflineAiModelState(
      selectedModel: _state.selectedModel,
      status: OfflineAiModelStatus.notInstalled,
    );
    notifyListeners();
  }

  Future<void> _loadState() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    final selectedModel = await _store.loadSelectedModel();
    final modelPath = await _store.modelPath(selectedModel);
    final isInstalled = await _store.isInstalled(selectedModel);
    _state = OfflineAiModelState(
      selectedModel: selectedModel,
      status: isInstalled
          ? OfflineAiModelStatus.ready
          : OfflineAiModelStatus.notInstalled,
      localPath: isInstalled ? modelPath : null,
    );
    notifyListeners();
  }
}
