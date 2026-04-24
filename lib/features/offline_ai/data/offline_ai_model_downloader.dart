import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/offline_ai_model.dart';

typedef OfflineAiDownloadProgressCallback = void Function(double progress);

class OfflineAiModelIntegrityException implements Exception {
  const OfflineAiModelIntegrityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineAiModelDownloader {
  const OfflineAiModelDownloader();

  Future<String> downloadModel({
    required OfflineAiModel model,
    required String targetPath,
    required OfflineAiDownloadProgressCallback onProgress,
  }) async {
    final tempPath = '$targetPath.download';
    final tempFile = File(tempPath);

    try {
      await tempFile.parent.create(recursive: true);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final request = await HttpClient().getUrl(Uri.parse(model.downloadUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final sink = tempFile.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress(receivedBytes / totalBytes);
          }
        }
      } finally {
        await sink.close();
      }

      await _verifyModelChecksum(
        model: model,
        file: tempFile,
      );

      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetPath);
      return targetPath;
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  Future<void> deleteModel(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> verifyModelChecksum({
    required OfflineAiModel model,
    required File file,
  }) {
    return _verifyModelChecksum(model: model, file: file);
  }

  Future<void> _verifyModelChecksum({
    required OfflineAiModel model,
    required File file,
  }) async {
    final expectedHash = model.sha256.trim().toLowerCase();
    if (expectedHash.isEmpty) {
      return;
    }

    final bytes = await file.readAsBytes();
    final actualHash = sha256.convert(bytes).bytes.map((byte) {
      return byte.toRadixString(16).padLeft(2, '0');
    }).join();

    if (actualHash != expectedHash) {
      throw const OfflineAiModelIntegrityException(
        'Downloaded model failed SHA-256 verification.',
      );
    }
  }
}
