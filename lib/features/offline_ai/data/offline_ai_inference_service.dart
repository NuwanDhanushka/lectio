import 'dart:async';

import 'package:llamadart/llamadart.dart';

import 'offline_ai_model_service.dart';

class OfflineAiInferenceException implements Exception {
  const OfflineAiInferenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class OfflineAiInferenceService {
  OfflineAiInferenceService._();

  static final OfflineAiInferenceService instance =
      OfflineAiInferenceService._();

  LlamaEngine? _engine;
  String? _loadedModelPath;
  Future<void>? _loadingFuture;
  bool _isGenerating = false;

  Future<String> summarizePage({
    required OfflineAiModelState modelState,
    required String pageText,
  }) async {
    final buffer = StringBuffer();
    await for (final partialSummary in streamPageSummary(
      modelState: modelState,
      pageText: pageText,
    )) {
      buffer
        ..clear()
        ..write(partialSummary);
    }

    final summary = buffer.toString().trim();
    if (summary.isEmpty) {
      throw const OfflineAiInferenceException(
        'The model finished without producing a summary.',
      );
    }
    return summary;
  }

  Stream<String> streamPageSummary({
    required OfflineAiModelState modelState,
    required String pageText,
  }) async* {
    yield* _streamTextResponse(
      modelState: modelState,
      sourceText: pageText,
      emptyTextMessage: 'No readable text was found on this page.',
      busyMessage: 'Another summary is already running. Try again in a moment.',
      promptBuilder: _summaryPrompt,
      emptyOutputMessage: 'The model finished without producing a summary.',
      failureMessage: 'Could not generate a summary on this device.',
      maxTokens: 360,
    );
  }

  Stream<String> streamSentenceExplanation({
    required OfflineAiModelState modelState,
    required String sentenceText,
  }) async* {
    yield* _streamTextResponse(
      modelState: modelState,
      sourceText: sentenceText,
      emptyTextMessage: 'Tap a sentence before asking for an explanation.',
      busyMessage:
          'Another AI response is already running. Try again in a moment.',
      promptBuilder: _explainSentencePrompt,
      emptyOutputMessage:
          'The model finished without producing an explanation.',
      failureMessage: 'Could not explain this sentence on this device.',
      maxTokens: 300,
    );
  }

  Stream<String> _streamTextResponse({
    required OfflineAiModelState modelState,
    required String sourceText,
    required String emptyTextMessage,
    required String busyMessage,
    required String Function(String text) promptBuilder,
    required String emptyOutputMessage,
    required String failureMessage,
    required int maxTokens,
  }) async* {
    final modelPath = modelState.localPath;
    if (!modelState.isReady || modelPath == null) {
      throw const OfflineAiInferenceException(
        'Download the offline AI model before using AI features.',
      );
    }

    final promptText = _trimForContext(sourceText);
    if (promptText.isEmpty) {
      throw OfflineAiInferenceException(emptyTextMessage);
    }
    if (_isGenerating) {
      throw OfflineAiInferenceException(busyMessage);
    }

    _isGenerating = true;
    try {
      final engine = await _ensureModelLoaded(modelPath);
      final buffer = StringBuffer();
      await for (final token in engine.generate(
        promptBuilder(promptText),
        params: GenerationParams(
          maxTokens: maxTokens,
          temp: 0.2,
          topK: 32,
          topP: 0.82,
          penalty: 1.05,
          stopSequences: ['<|im_end|>', '<|endoftext|>'],
          streamBatchTokenThreshold: 2,
          streamBatchByteThreshold: 128,
        ),
      )) {
        buffer.write(token);
        final partialSummary = _cleanSummary(buffer.toString());
        if (partialSummary.isNotEmpty) {
          yield partialSummary;
        }
      }

      final summary = _cleanSummary(buffer.toString());
      if (summary.isEmpty) {
        throw OfflineAiInferenceException(emptyOutputMessage);
      }
      yield summary;
    } on OfflineAiInferenceException {
      rethrow;
    } catch (error) {
      throw OfflineAiInferenceException(
        failureMessage,
        error,
      );
    } finally {
      _isGenerating = false;
    }
  }

  Future<LlamaEngine> _ensureModelLoaded(String modelPath) async {
    final loadedEngine = _engine;
    if (loadedEngine != null &&
        loadedEngine.isReady &&
        _loadedModelPath == modelPath) {
      return loadedEngine;
    }

    if (_loadingFuture != null) {
      await _loadingFuture;
      final engine = _engine;
      if (engine != null && engine.isReady && _loadedModelPath == modelPath) {
        return engine;
      }
    }

    final completer = Completer<void>();
    _loadingFuture = completer.future;
    try {
      await _engine?.dispose();
      final engine = LlamaEngine(LlamaBackend());
      await engine.loadModel(
        modelPath,
        modelParams: const ModelParams(
          contextSize: 4096,
          gpuLayers: ModelParams.maxGpuLayers,
          batchSize: 512,
          microBatchSize: 128,
        ),
      );
      _engine = engine;
      _loadedModelPath = modelPath;
      completer.complete();
      return engine;
    } catch (error) {
      _engine = null;
      _loadedModelPath = null;
      completer.complete();
      throw OfflineAiInferenceException(
        'Could not load the downloaded AI model.',
        error,
      );
    } finally {
      if (identical(_loadingFuture, completer.future)) {
        _loadingFuture = null;
      }
    }
  }

  String _summaryPrompt(String pageText) {
    return '''
<|im_start|>system
You are Lectio, a private offline reading assistant. Summarize PDF pages clearly and briefly. Do not include hidden reasoning or thinking tags.
<|im_end|>
<|im_start|>user
Summarize this page in exactly 3 concise bullet points.
Return only the final bullets.
Do not use markdown bold.
Do not include <think> tags.
Keep important names, terms, and claims.

Page text:
$pageText
<|im_end|>
<|im_start|>assistant
''';
  }

  String _explainSentencePrompt(String sentenceText) {
    return '''
<|im_start|>system
You are Lectio, a private offline reading assistant. Explain difficult reading passages clearly and briefly. Do not include hidden reasoning or thinking tags.
<|im_end|>
<|im_start|>user
Explain this sentence in simple terms.
Return 2 short bullet points:
1. What it means
2. Why it matters
Do not use markdown bold.
Do not include <think> tags.

Sentence:
$sentenceText
<|im_end|>
<|im_start|>assistant
''';
  }

  String _trimForContext(String text) {
    final cleanText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.length <= 7000) {
      return cleanText;
    }
    return cleanText.substring(0, 7000).trimRight();
  }

  String _cleanSummary(String text) {
    final withoutTags = _removeThinkingBlocks(text)
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|endoftext|>', '');

    final lines = withoutTags
        .split(RegExp(r'\r?\n'))
        .map(_cleanSummaryLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isNotEmpty) {
      return lines.join('\n');
    }

    return _cleanSummaryLine(withoutTags);
  }

  String _removeThinkingBlocks(String text) {
    final withoutClosedBlocks =
        text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    final danglingThinkIndex = withoutClosedBlocks.indexOf('<think>');
    if (danglingThinkIndex < 0) {
      return withoutClosedBlocks;
    }

    final beforeThinking = withoutClosedBlocks.substring(0, danglingThinkIndex);
    final afterThinkingTag = withoutClosedBlocks.substring(danglingThinkIndex);
    final linesAfterThinking = afterThinkingTag
        .split(RegExp(r'\r?\n'))
        .where((line) => !line.trim().startsWith('<think>'))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (linesAfterThinking.isNotEmpty) {
      return '$beforeThinking\n${linesAfterThinking.join('\n')}';
    }

    return beforeThinking;
  }

  String _cleanSummaryLine(String line) {
    return line
        .replaceAll(RegExp(r'^\s*[-*•]+\s*'), '')
        .replaceAll(RegExp(r'^\s*\d+[\.)]\s*'), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .trim();
  }

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
    _loadedModelPath = null;
    _loadingFuture = null;
    _isGenerating = false;
  }
}
