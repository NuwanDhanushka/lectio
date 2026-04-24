import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/library_item.dart';
import 'library_repository.dart';

const String _libraryFolderName = 'library';

class DocumentImportService {
  const DocumentImportService({
    required this.repository,
  });

  final LibraryRepository repository;

  Future<LibraryItem?> importDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'epub', 'txt'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selectedFile = result.files.single;
    final sourcePath = selectedFile.path;

    if (sourcePath == null) {
      return null;
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final libraryDirectory = Directory(
      p.join(appDirectory.path, _libraryFolderName),
    );
    await libraryDirectory.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeFileName = selectedFile.name.replaceAll(' ', '_');
    final storedFilePath = p.join(
      _libraryFolderName,
      '${timestamp}_$safeFileName',
    );
    final destinationPath = p.join(appDirectory.path, storedFilePath);

    final copiedFile = await sourceFile.copy(destinationPath);
    final sizeInBytes = await copiedFile.length();
    final now = DateTime.now();

    final item = LibraryItem(
      title: _titleFromFileName(selectedFile.name),
      fileName: selectedFile.name,
      filePath: storedFilePath,
      format: _formatFromExtension(selectedFile.extension),
      progress: 0,
      fileSizeBytes: sizeInBytes,
      importedAt: now,
      lastAccessedAt: now,
    );

    return repository.addDocument(item);
  }
}

String _titleFromFileName(String fileName) {
  return p.basenameWithoutExtension(fileName).replaceAll('_', ' ');
}

String _formatFromExtension(String? extension) {
  switch ((extension ?? '').toUpperCase()) {
    case 'TXT':
      return 'TXT';
    case 'EPUB':
      return 'EPUB';
    default:
      return 'PDF';
  }
}
