import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/notebook/domain/document_note.dart';
import 'package:lectio/features/reader/presentation/controllers/reader_notebook_coordinator.dart';
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

void main() {
  group('ReaderNotebookCoordinator', () {
    const coordinator = ReaderNotebookCoordinator();
    final note = DocumentNote(
      documentId: 1,
      kind: DocumentNoteKind.summary,
      pageNumber: 4,
      sentenceIndex: 2,
      body: 'Important summary',
      createdAt: DateTime(2024, 1, 1),
    );

    test('openDocumentNote returns false when viewer is not ready', () async {
      final controller = _FakePdfViewerController();

      final opened = await coordinator.openDocumentNote(
        note: note,
        viewerReady: false,
        controller: controller,
        clearSearchMatch: () {},
        clearCurrentPageSpeechSegments: () {},
        updateReaderSelection: (_, __) {},
        ensureSpeechSegmentsForCurrentPage: () async {},
        invalidatePdfViewerSafely: () {},
        autoScrollToSelectedSentence: () async {},
      );

      expect(opened, isFalse);
      expect(controller.lastPageNumber, isNull);
    });

    test('openDocumentNote coordinates page jump and selection updates', () async {
      final controller = _FakePdfViewerController();
      var clearedSearch = false;
      var clearedSegments = false;
      int? updatedPage;
      int? updatedSentence;
      var ensuredSegments = false;
      var invalidated = false;
      var autoScrolled = false;

      final opened = await coordinator.openDocumentNote(
        note: note,
        viewerReady: true,
        controller: controller,
        clearSearchMatch: () {
          clearedSearch = true;
        },
        clearCurrentPageSpeechSegments: () {
          clearedSegments = true;
        },
        updateReaderSelection: (currentPage, selectedSentenceIndex) {
          updatedPage = currentPage;
          updatedSentence = selectedSentenceIndex;
        },
        ensureSpeechSegmentsForCurrentPage: () async {
          ensuredSegments = true;
        },
        invalidatePdfViewerSafely: () {
          invalidated = true;
        },
        autoScrollToSelectedSentence: () async {
          autoScrolled = true;
        },
      );

      expect(opened, isTrue);
      expect(controller.lastPageNumber, 4);
      expect(clearedSearch, isTrue);
      expect(clearedSegments, isTrue);
      expect(updatedPage, 4);
      expect(updatedSentence, 2);
      expect(ensuredSegments, isTrue);
      expect(invalidated, isTrue);
      expect(autoScrolled, isTrue);
    });

    test('openDocumentNote skips sentence-specific follow-up when sentenceIndex is null', () async {
      final controller = _FakePdfViewerController();
      final pageOnlyNote = DocumentNote(
        documentId: 1,
        kind: DocumentNoteKind.summary,
        pageNumber: 6,
        body: 'Page-only note',
        createdAt: DateTime(2024, 1, 1),
      );
      var ensuredSegments = false;
      var invalidated = false;
      var autoScrolled = false;

      final opened = await coordinator.openDocumentNote(
        note: pageOnlyNote,
        viewerReady: true,
        controller: controller,
        clearSearchMatch: () {},
        clearCurrentPageSpeechSegments: () {},
        updateReaderSelection: (_, __) {},
        ensureSpeechSegmentsForCurrentPage: () async {
          ensuredSegments = true;
        },
        invalidatePdfViewerSafely: () {
          invalidated = true;
        },
        autoScrollToSelectedSentence: () async {
          autoScrolled = true;
        },
      );

      expect(opened, isTrue);
      expect(controller.lastPageNumber, 6);
      expect(ensuredSegments, isFalse);
      expect(invalidated, isFalse);
      expect(autoScrolled, isFalse);
    });
  });
}
