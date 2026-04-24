import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/library/data/document_import_service.dart';
import 'package:lectio/features/library/data/library_repository.dart';
import 'package:lectio/features/library/domain/library_item.dart';
import 'package:lectio/features/library/presentation/controllers/home_page_controller.dart';

class _FakeLibraryRepository implements LibraryRepository {
  LibrarySnapshot snapshot = const LibrarySnapshot.empty();
  Object? snapshotError;
  Object? removeError;
  final removedItems = <LibraryItem>[];

  @override
  Future<LibrarySnapshot> fetchSnapshot() async {
    if (snapshotError != null) {
      throw snapshotError!;
    }
    return snapshot;
  }

  @override
  Future<void> removeDocument(LibraryItem item) async {
    if (removeError != null) {
      throw removeError!;
    }
    removedItems.add(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentImportService extends DocumentImportService {
  _FakeDocumentImportService() : super(repository: _NoopLibraryRepository());

  LibraryItem? importedItem;
  Object? importError;

  @override
  Future<LibraryItem?> importDocument() async {
    if (importError != null) {
      throw importError!;
    }
    return importedItem;
  }
}

class _NoopLibraryRepository implements LibraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HomePageController', () {
    late _FakeLibraryRepository repository;
    late _FakeDocumentImportService importService;
    late HomePageController controller;

    const item = LibraryItem(
      id: 1,
      title: 'Physics',
      fileName: 'physics.pdf',
      progress: 0.4,
    );

    setUp(() {
      repository = _FakeLibraryRepository();
      importService = _FakeDocumentImportService();
      controller = HomePageController(
        repository: repository,
        importService: importService,
      );
    });

    test('loadLibrary stores snapshot and clears loading state', () async {
      repository.snapshot = const LibrarySnapshot(
        recentItems: [item],
        totalItems: 1,
        totalBytes: 1024,
        lastSyncedAt: null,
      );

      final message = await controller.loadLibrary();

      expect(message, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.snapshot.recentItems, hasLength(1));
    });

    test('loadLibrary returns error message on failure', () async {
      repository.snapshotError = Exception('db down');

      final message = await controller.loadLibrary();

      expect(message, 'Could not load your library.');
      expect(controller.isLoading, isFalse);
      expect(controller.snapshot.recentItems, isEmpty);
    });

    test('importDocument returns null when picker is canceled', () async {
      importService.importedItem = null;

      final message = await controller.importDocument();

      expect(message, isNull);
      expect(controller.isImporting, isFalse);
    });

    test('importDocument reloads snapshot and returns success message',
        () async {
      importService.importedItem = item;
      repository.snapshot = const LibrarySnapshot(
        recentItems: [item],
        totalItems: 1,
        totalBytes: 1024,
        lastSyncedAt: null,
      );

      final message = await controller.importDocument();

      expect(message, 'physics.pdf imported');
      expect(controller.isImporting, isFalse);
      expect(controller.snapshot.recentItems, hasLength(1));
    });

    test('importDocument returns error message on failure', () async {
      importService.importError = Exception('picker failed');

      final message = await controller.importDocument();

      expect(message, 'Import failed. Please try again.');
      expect(controller.isImporting, isFalse);
    });

    test('removeDocument reloads snapshot and returns success message',
        () async {
      repository.snapshot = const LibrarySnapshot(
        recentItems: [],
        totalItems: 0,
        totalBytes: 0,
        lastSyncedAt: null,
      );

      final message = await controller.removeDocument(item);

      expect(repository.removedItems, [item]);
      expect(message, 'Physics removed from recent');
    });

    test('removeDocument returns error message on failure', () async {
      repository.removeError = Exception('delete failed');

      final message = await controller.removeDocument(item);

      expect(message, 'Could not remove this document.');
    });
  });
}
