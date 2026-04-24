import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../../data/bundled_voice_installer.dart';
import '../../data/sherpa_tts_config_store.dart';
import '../../data/sherpa_tts_engine.dart';
import '../../domain/sherpa_tts_config.dart';
import '../../domain/tts_segmenter.dart';
import 'tts_playback_controller.dart';

enum SherpaTtsStatus {
  loading,
  unconfigured,
  ready,
  synthesizing,
  playing,
  paused,
  error,
}

class SherpaTtsService extends ChangeNotifier {
  SherpaTtsService._();

  static const _legacyBundledModelName = 'en_US-lessac-medium.onnx';

  static final SherpaTtsService instance = SherpaTtsService._();

  final BundledVoiceInstaller _bundledVoiceInstaller = BundledVoiceInstaller();
  final SherpaTtsConfigStore _store = SherpaTtsConfigStore();
  final SherpaTtsEngine _engine = SherpaTtsEngine();
  final TtsPlaybackController _playbackController = TtsPlaybackController();

  SherpaTtsConfig _config = const SherpaTtsConfig();
  SherpaTtsStatus _status = SherpaTtsStatus.loading;
  String? _errorMessage;
  bool _initialized = false;

  SherpaTtsConfig get config => _config;
  SherpaTtsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => _config.isComplete;
  String get currentUtteranceText => _playbackController.currentUtteranceText;
  int get currentUtteranceIndex => _playbackController.currentUtteranceIndex;
  int get utteranceCount => _playbackController.utteranceCount;
  double get currentUtteranceProgress =>
      _playbackController.currentUtteranceProgress;
  Duration get playbackPosition => _playbackController.playbackPosition;
  Duration get playbackDuration => _playbackController.playbackDuration;
  double get playbackProgress => _playbackController.playbackProgress;
  bool get isBusy =>
      _status == SherpaTtsStatus.synthesizing ||
      _status == SherpaTtsStatus.playing ||
      _status == SherpaTtsStatus.paused;
  bool get canResume =>
      _status == SherpaTtsStatus.paused && currentUtteranceText.isNotEmpty;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await _playbackController.ensureInitialized(
      onPlaybackCompleted: () {
        _setStatus(
          _config.isComplete
              ? SherpaTtsStatus.ready
              : SherpaTtsStatus.unconfigured,
        );
      },
    );
    _playbackController.addListener(notifyListeners);

    final savedConfig = await _store.load();
    if (savedConfig == null || _isLegacyBundledConfig(savedConfig)) {
      _config = await _bundledVoiceInstaller.ensureInstalled();
    } else {
      _config = savedConfig;
    }
    if (!await _engine.configFilesExist(_config)) {
      _config = await _bundledVoiceInstaller.ensureInstalled();
    }
    await _store.save(_config);
    _initialized = true;
    _setStatus(
      _config.isComplete ? SherpaTtsStatus.ready : SherpaTtsStatus.unconfigured,
      notify: false,
    );
    notifyListeners();
  }

  Future<void> updateConfig(SherpaTtsConfig config) async {
    await ensureInitialized();
    _config = config;
    await _disposeEngine();
    await _store.save(config);
    _errorMessage = null;
    _setStatus(
      _config.isComplete ? SherpaTtsStatus.ready : SherpaTtsStatus.unconfigured,
    );
  }

  Future<void> clearConfig() async {
    await ensureInitialized();
    await stop();
    _config = const SherpaTtsConfig();
    _errorMessage = null;
    await _disposeEngine();
    await _store.clear();
    _setStatus(SherpaTtsStatus.unconfigured);
  }

  Future<SherpaTtsConfig> restoreBundledVoice() async {
    await ensureInitialized();
    final bundled = await _bundledVoiceInstaller.ensureInstalled();
    await updateConfig(bundled);
    return bundled;
  }

  Future<void> speak(String text) async {
    await speakSegments(splitTextIntoSpeechSegments(text));
  }

  Future<void> speakSegments(List<String> segments) async {
    final utterances = segments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (utterances.isEmpty) {
      return;
    }

    _setStatus(SherpaTtsStatus.synthesizing);
    await ensureInitialized();
    if (!_config.isComplete) {
      _setError('Choose the Sherpa model, tokens, and data directory first.');
      return;
    }
    if (!await _engine.configFilesExist(_config)) {
      _config = await _bundledVoiceInstaller.ensureInstalled();
      await _store.save(_config);
    }

    try {
      final sessionId = await _playbackController.startSynthesisSession(
        utterances,
      );
      final tempDir = await getTemporaryDirectory();
      final synthesisResult = await _engine.synthesizeSegments(
        config: _config,
        utterances: utterances,
        isCancelled: () => !_playbackController.isCurrentSession(sessionId),
        onProgress: _playbackController.updateQueuedUtteranceEndTimes,
      );

      if (!_playbackController.isCurrentSession(sessionId)) {
        return;
      }

      final filePath = p.join(tempDir.path, 'lectio_sherpa_preview_full.wav');
      writeWave(
        filename: filePath,
        samples: Float32List.fromList(synthesisResult.samples),
        sampleRate: synthesisResult.sampleRate,
      );

      await _playbackController.playFile(
        filePath: filePath,
        utteranceEndTimes: synthesisResult.utteranceEndTimes,
      );
      _setStatus(SherpaTtsStatus.playing);
    } on SherpaTtsEngineCancelledException {
      return;
    } catch (error) {
      await _playbackController.stop();
      _setError(error.toString());
    }
  }

  Future<void> stop() async {
    await ensureInitialized();
    await _playbackController.stop();
    _setStatus(
      _config.isComplete ? SherpaTtsStatus.ready : SherpaTtsStatus.unconfigured,
    );
  }

  Future<void> pause() async {
    await ensureInitialized();
    if (_status != SherpaTtsStatus.playing) {
      return;
    }

    await _playbackController.pause();
    _setStatus(SherpaTtsStatus.paused);
  }

  Future<void> resume() async {
    await ensureInitialized();
    if (_status != SherpaTtsStatus.paused) {
      return;
    }

    await _playbackController.resume();
    _setStatus(SherpaTtsStatus.playing);
  }

  Future<void> seekBy(Duration offset) async {
    await ensureInitialized();
    if (!_playbackController.isQueuePlaybackActive ||
        playbackDuration == Duration.zero) {
      return;
    }

    await _playbackController.seekBy(offset);
  }

  Future<void> seekToUtteranceOffset(int offset) async {
    await ensureInitialized();
    if (!_playbackController.isQueuePlaybackActive) {
      return;
    }

    await _playbackController.seekToUtteranceOffset(offset);
  }

  bool _isLegacyBundledConfig(SherpaTtsConfig config) {
    return p.basename(config.modelPath) == _legacyBundledModelName;
  }

  Future<void> _disposeEngine() async {
    await _engine.dispose();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = SherpaTtsStatus.error;
    notifyListeners();
  }

  void _setStatus(SherpaTtsStatus status, {bool notify = true}) {
    _status = status;
    if (status != SherpaTtsStatus.error) {
      _errorMessage = null;
    }

    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _playbackController.removeListener(notifyListeners);
    _playbackController.dispose();
    _disposeEngine();
    super.dispose();
  }
}
