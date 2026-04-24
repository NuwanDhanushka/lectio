import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/sherpa_tts_config.dart';

class BundledVoiceInstaller {
  static const _archiveAsset =
      'assets/models/default_voice/vits-piper-en_US-libritts_r-medium.tar.bz2';

  Future<SherpaTtsConfig> ensureInstalled() async {
    final root = await _installRoot();
    final extractedRoot = p.join(root.path, 'vits-piper-en_US-libritts_r-medium');
    final modelPath = p.join(extractedRoot, 'en_US-libritts_r-medium.onnx');
    final tokensPath = p.join(extractedRoot, 'tokens.txt');
    final dataDir = p.join(extractedRoot, 'espeak-ng-data');

    if (!await File(modelPath).exists()) {
      await _extractBundledArchive(root.path);
    }

    return SherpaTtsConfig(
      engine: 'vits',
      modelPath: modelPath,
      tokensPath: tokensPath,
      dataDir: dataDir,
      speed: 1.0,
      speakerId: 109,
    );
  }

  Future<void> _extractBundledArchive(String destinationRoot) async {
    final byteData = await rootBundle.load(_archiveAsset);
    final compressedBytes = byteData.buffer.asUint8List();
    final tarBytes = BZip2Decoder().decodeBytes(compressedBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    for (final entry in archive) {
      final outputPath = p.join(destinationRoot, entry.name);
      if (entry.isFile) {
        final outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(entry.content as List<int>, flush: true);
      } else {
        await Directory(outputPath).create(recursive: true);
      }
    }
  }

  Future<Directory> _installRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(
      p.join(documents.path, 'lectio', 'tts', 'default_voice'),
    );
    await root.create(recursive: true);
    return root;
  }
}
