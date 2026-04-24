import 'dart:io';

import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../domain/sherpa_tts_config.dart';

class SherpaTtsSynthesisResult {
  const SherpaTtsSynthesisResult({
    required this.sampleRate,
    required this.samples,
    required this.utteranceEndTimes,
  });

  final int sampleRate;
  final List<double> samples;
  final List<Duration> utteranceEndTimes;
}

class SherpaTtsEngine {
  OfflineTts? _tts;

  Future<bool> configFilesExist(SherpaTtsConfig config) async {
    if (!config.isComplete) {
      return false;
    }

    final modelExists = await File(config.modelPath).exists();
    final tokensExists = await File(config.tokensPath).exists();
    final dataDirExists = await Directory(config.dataDir).exists();
    return modelExists && tokensExists && dataDirExists;
  }

  Future<SherpaTtsSynthesisResult> synthesizeSegments({
    required SherpaTtsConfig config,
    required List<String> utterances,
    required bool Function() isCancelled,
    void Function(List<Duration> utteranceEndTimes)? onProgress,
  }) async {
    final tts = await ensureReady(config);
    final combinedSamples = <double>[];
    int? sampleRate;
    var cumulativeMicroseconds = 0;
    final utteranceEndTimes = <Duration>[];

    for (final segment in utterances) {
      if (isCancelled()) {
        throw const SherpaTtsEngineCancelledException();
      }

      final generated = tts.generate(
        text: segment,
        sid: config.speakerId,
        speed: config.speed,
      );

      sampleRate ??= generated.sampleRate;
      combinedSamples.addAll(generated.samples);
      cumulativeMicroseconds +=
          (generated.samples.length * Duration.microsecondsPerSecond) ~/
              generated.sampleRate;
      utteranceEndTimes.add(Duration(microseconds: cumulativeMicroseconds));
      onProgress?.call(List.unmodifiable(utteranceEndTimes));
    }

    if (sampleRate == null) {
      throw const SherpaTtsEngineException('No audio was generated.');
    }

    return SherpaTtsSynthesisResult(
      sampleRate: sampleRate,
      samples: List.unmodifiable(combinedSamples),
      utteranceEndTimes: List.unmodifiable(utteranceEndTimes),
    );
  }

  Future<OfflineTts> ensureReady(SherpaTtsConfig config) async {
    if (_tts != null) {
      return _tts!;
    }

    final modelConfig = OfflineTtsModelConfig(
      vits: OfflineTtsVitsModelConfig(
        model: config.modelPath,
        tokens: config.tokensPath,
        dataDir: config.dataDir,
      ),
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    );

    _tts = OfflineTts(
      OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
      ),
    );

    return _tts!;
  }

  Future<void> dispose() async {
    _tts?.free();
    _tts = null;
  }
}

class SherpaTtsEngineException implements Exception {
  const SherpaTtsEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SherpaTtsEngineCancelledException extends SherpaTtsEngineException {
  const SherpaTtsEngineCancelledException() : super('TTS synthesis cancelled.');
}
