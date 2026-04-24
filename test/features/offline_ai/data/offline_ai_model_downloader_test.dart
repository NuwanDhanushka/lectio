import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/offline_ai/data/offline_ai_model_downloader.dart';
import 'package:lectio/features/offline_ai/domain/offline_ai_model.dart';

void main() {
  group('OfflineAiModelDownloader checksum verification', () {
    const downloader = OfflineAiModelDownloader();

    test('accepts matching sha256 hash', () async {
      final tempDir = await Directory.systemTemp.createTemp('lectio_hash_ok');
      final file = File('${tempDir.path}/model.gguf');
      await file.writeAsString('hello');

      const model = OfflineAiModel(
        id: 'test',
        name: 'Test',
        fileName: 'model.gguf',
        sizeLabel: '~1 MB',
        description: 'Test model',
        downloadUrl: 'https://example.com/model.gguf',
        sha256:
            '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );

      await downloader.verifyModelChecksum(model: model, file: file);
    });

    test('throws on mismatched sha256 hash', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lectio_hash_bad',
      );
      final file = File('${tempDir.path}/model.gguf');
      await file.writeAsString('hello');

      const model = OfflineAiModel(
        id: 'test',
        name: 'Test',
        fileName: 'model.gguf',
        sizeLabel: '~1 MB',
        description: 'Test model',
        downloadUrl: 'https://example.com/model.gguf',
        sha256: 'deadbeef',
      );

      expect(
        downloader.verifyModelChecksum(model: model, file: file),
        throwsA(isA<OfflineAiModelIntegrityException>()),
      );
    });

    test('skips verification when sha256 is empty', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lectio_hash_skip',
      );
      final file = File('${tempDir.path}/model.gguf');
      await file.writeAsString('hello');

      const model = OfflineAiModel(
        id: 'test',
        name: 'Test',
        fileName: 'model.gguf',
        sizeLabel: '~1 MB',
        description: 'Test model',
        downloadUrl: 'https://example.com/model.gguf',
        sha256: '',
      );

      await downloader.verifyModelChecksum(model: model, file: file);
    });
  });
}
