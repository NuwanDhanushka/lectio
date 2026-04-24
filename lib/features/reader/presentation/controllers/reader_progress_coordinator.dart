import 'package:pdfrx/pdfrx.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../domain/reader_page_analysis.dart';

class ReaderProgressCoordinator {
  int? _lastPersistedPage;
  bool _isRestoringSavedPage = false;

  bool get isRestoringSavedPage => _isRestoringSavedPage;

  void reset() {
    _lastPersistedPage = null;
    _isRestoringSavedPage = false;
  }

  Future<int?> restoreSavedReadingPosition({
    required LibraryItem? item,
    required bool viewerReady,
    required int pageCount,
    required int currentPage,
    required int? initialPage,
    required PdfViewerController controller,
  }) async {
    if (item == null || !viewerReady || pageCount <= 1) {
      return null;
    }

    final savedPage = initialPage?.clamp(1, pageCount) ??
        pageNumberForStoredProgress(
          progress: item.progress,
          pageCount: pageCount,
        );
    if (savedPage <= 1 || savedPage == currentPage) {
      _lastPersistedPage = currentPage;
      return null;
    }

    _isRestoringSavedPage = true;
    try {
      await controller.goToPage(pageNumber: savedPage);
      _lastPersistedPage = savedPage;
      return savedPage;
    } finally {
      _isRestoringSavedPage = false;
    }
  }

  Future<LibraryItem?> persistReadingProgress({
    required int pageNumber,
    required LibraryItem? item,
    required LibraryRepository? repository,
    required int pageCount,
  }) async {
    if (item == null || repository == null || pageCount <= 0) {
      return null;
    }
    if (_lastPersistedPage == pageNumber) {
      return null;
    }

    _lastPersistedPage = pageNumber;
    return repository.updateReadingProgress(
      item: item,
      progress: storedProgressForPage(
        pageNumber: pageNumber,
        pageCount: pageCount,
      ),
      lastAccessedAt: DateTime.now(),
    );
  }
}
