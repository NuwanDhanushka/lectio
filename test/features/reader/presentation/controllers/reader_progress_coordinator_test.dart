import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/library/data/library_repository.dart';
import 'package:lectio/features/library/domain/library_item.dart';
import 'package:lectio/features/reader/presentation/controllers/reader_progress_coordinator.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakePdfViewerController implements PdfViewerController {
  int? lastPageNumber;

  @override
  Future<void> goToPage({
    required int pageNumber,
    PdfPageAnchor? anchor,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    lastPageNumber = pageNumber;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLibraryRepository implements LibraryRepository {
  LibraryItem? updatedItem;
  LibraryItem? lastItem;
  double? lastProgress;
  DateTime? lastAccessedAt;

  @override
  Future<LibraryItem?> updateReadingProgress({
    required LibraryItem item,
    required double progress,
    DateTime? lastAccessedAt,
  }) async {
    lastItem = item;
    lastProgress = progress;
    this.lastAccessedAt = lastAccessedAt;
    return updatedItem;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ReaderProgressCoordinator', () {
    late ReaderProgressCoordinator coordinator;
    late LibraryItem item;

    setUp(() {
      coordinator = ReaderProgressCoordinator();
      item = const LibraryItem(title: 'Biology Notes', progress: 0.5);
    });

    test('restoreSavedReadingPosition returns null when prerequisites fail', () async {
      final controller = _FakePdfViewerController();

      final result = await coordinator.restoreSavedReadingPosition(
        item: null,
        viewerReady: true,
        pageCount: 10,
        currentPage: 1,
        initialPage: null,
        controller: controller,
      );

      expect(result, isNull);
      expect(controller.lastPageNumber, isNull);
    });

    test('restoreSavedReadingPosition prefers explicit initialPage', () async {
      final controller = _FakePdfViewerController();

      final result = await coordinator.restoreSavedReadingPosition(
        item: item,
        viewerReady: true,
        pageCount: 20,
        currentPage: 1,
        initialPage: 8,
        controller: controller,
      );

      expect(result, 8);
      expect(controller.lastPageNumber, 8);
      expect(coordinator.isRestoringSavedPage, isFalse);
    });

    test('restoreSavedReadingPosition skips when resolved page matches current', () async {
      final controller = _FakePdfViewerController();

      final result = await coordinator.restoreSavedReadingPosition(
        item: item,
        viewerReady: true,
        pageCount: 20,
        currentPage: 10,
        initialPage: 10,
        controller: controller,
      );

      expect(result, isNull);
      expect(controller.lastPageNumber, isNull);
    });

    test('persistReadingProgress writes progress once per page', () async {
      final repository = _FakeLibraryRepository()
        ..updatedItem = const LibraryItem(title: 'Saved Item', progress: 0.4);

      final first = await coordinator.persistReadingProgress(
        pageNumber: 3,
        item: item,
        repository: repository,
        pageCount: 10,
      );
      final second = await coordinator.persistReadingProgress(
        pageNumber: 3,
        item: item,
        repository: repository,
        pageCount: 10,
      );

      expect(first?.title, 'Saved Item');
      expect(second, isNull);
      expect(repository.lastItem, same(item));
      expect(repository.lastProgress, closeTo(2 / 9, 0.0001));
      expect(repository.lastAccessedAt, isNotNull);
    });

    test('reset clears persisted-page bookkeeping', () async {
      final repository = _FakeLibraryRepository();

      await coordinator.persistReadingProgress(
        pageNumber: 5,
        item: item,
        repository: repository,
        pageCount: 10,
      );

      coordinator.reset();

      final result = await coordinator.persistReadingProgress(
        pageNumber: 5,
        item: item,
        repository: repository,
        pageCount: 10,
      );

      expect(result, isNull);
      expect(repository.lastProgress, closeTo(4 / 9, 0.0001));
    });
  });
}
