import 'package:flutter/foundation.dart';

import '../../data/document_import_service.dart';
import '../../data/library_repository.dart';
import '../../domain/library_item.dart';

class HomePageController extends ChangeNotifier {
  HomePageController({
    required LibraryRepository repository,
    required DocumentImportService importService,
  })  : _repository = repository,
        _importService = importService;

  final LibraryRepository _repository;
  final DocumentImportService _importService;

  LibrarySnapshot _snapshot = const LibrarySnapshot.empty();
  bool _isLoading = true;
  bool _isImporting = false;

  LibrarySnapshot get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;

  Future<String?> loadLibrary() async {
    try {
      final snapshot = await _repository.fetchSnapshot();
      _snapshot = snapshot;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (_) {
      _snapshot = const LibrarySnapshot.empty();
      _isLoading = false;
      notifyListeners();
      return 'Could not load your library.';
    }
  }

  Future<String?> importDocument() async {
    if (_isImporting) {
      return null;
    }

    _isImporting = true;
    notifyListeners();

    try {
      final importedItem = await _importService.importDocument();
      if (importedItem == null) {
        return null;
      }

      await loadLibrary();
      return '${importedItem.fileName} imported';
    } catch (_) {
      return 'Import failed. Please try again.';
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<String?> removeDocument(LibraryItem item) async {
    try {
      await _repository.removeDocument(item);
      await loadLibrary();
      return '${item.title} removed from recent';
    } catch (_) {
      return 'Could not remove this document.';
    }
  }
}
