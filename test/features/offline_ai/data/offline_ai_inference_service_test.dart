import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/offline_ai/data/offline_ai_inference_service.dart';
import 'package:lectio/features/offline_ai/data/offline_ai_model_service.dart';
import 'package:lectio/features/offline_ai/domain/offline_ai_model.dart';

void main() {
  group('OfflineAiInferenceService', () {
    final service = OfflineAiInferenceService.instance;

    const readyState = OfflineAiModelState(
      selectedModel: OfflineAiModel(
        id: 'test',
        name: 'Test Model',
        fileName: 'test.gguf',
        sizeLabel: '~1 MB',
        description: 'Test',
        downloadUrl: 'https://example.com/test.gguf',
        sha256: '',
      ),
      status: OfflineAiModelStatus.ready,
      localPath: '/tmp/test.gguf',
    );

    const notReadyState = OfflineAiModelState(
      selectedModel: OfflineAiModel(
        id: 'test',
        name: 'Test Model',
        fileName: 'test.gguf',
        sizeLabel: '~1 MB',
        description: 'Test',
        downloadUrl: 'https://example.com/test.gguf',
        sha256: '',
      ),
      status: OfflineAiModelStatus.notInstalled,
    );

    tearDown(() async {
      await service.dispose();
    });

    test('throws when summarizing without a ready model', () async {
      expect(
        () => service.summarizePage(
          modelState: notReadyState,
          pageText: 'Some text',
        ),
        throwsA(
          isA<OfflineAiInferenceException>().having(
            (error) => error.message,
            'message',
            'Download the offline AI model before using AI features.',
          ),
        ),
      );
    });

    test('throws helpful message for empty page summary input', () async {
      expect(
        service
            .streamPageSummary(
              modelState: readyState,
              pageText: '   \n  ',
            )
            .drain<void>(),
        throwsA(
          isA<OfflineAiInferenceException>().having(
            (error) => error.message,
            'message',
            'No readable text was found on this page.',
          ),
        ),
      );
    });

    test('throws helpful message for empty sentence explanation input',
        () async {
      expect(
        service
            .streamSentenceExplanation(
              modelState: readyState,
              sentenceText: '   ',
            )
            .drain<void>(),
        throwsA(
          isA<OfflineAiInferenceException>().having(
            (error) => error.message,
            'message',
            'Tap a sentence before asking for an explanation.',
          ),
        ),
      );
    });
  });
}
