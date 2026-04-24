import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/reader/presentation/controllers/reader_session_controller.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakePdfDocument implements PdfDocument {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePdfPageTextRange implements PdfPageTextRange {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ReaderSessionController', () {
    test('starts with expected defaults', () {
      final controller = ReaderSessionController();

      expect(controller.pdfDocument, isNull);
      expect(controller.searchMatchRange, isNull);
      expect(controller.selectedSentenceIndex, isNull);
      expect(controller.currentPage, 1);
      expect(controller.pageCount, 0);
      expect(controller.viewerReady, isFalse);
      expect(controller.toolbarMinimized, isFalse);
      expect(controller.lastVisibleRectTop, isNull);
      expect(controller.isBottomNavVisible, isTrue);
      expect(controller.minimizedToolbarOffset, Offset.zero);
    });

    test('setViewerReady updates document state', () {
      final controller = ReaderSessionController();
      final document = _FakePdfDocument();

      controller.setViewerReady(
        document: document,
        pageCount: 24,
        currentPage: 7,
      );

      expect(controller.pdfDocument, same(document));
      expect(controller.viewerReady, isTrue);
      expect(controller.pageCount, 24);
      expect(controller.currentPage, 7);
    });

    test('resetForDocumentChange restores reader defaults', () {
      final controller = ReaderSessionController();

      controller.setViewerReady(
        document: _FakePdfDocument(),
        pageCount: 10,
        currentPage: 4,
      );
      controller.setSelectedSentenceIndex(3);
      controller.setSearchMatchRange(_FakePdfPageTextRange());
      controller.toggleToolbarMinimized();
      controller.setBottomNavVisible(false);
      controller.setMinimizedToolbarOffset(const Offset(12, 24));
      controller.updateVisibleRectTop(88);

      controller.resetForDocumentChange();

      expect(controller.pdfDocument, isNull);
      expect(controller.searchMatchRange, isNull);
      expect(controller.selectedSentenceIndex, isNull);
      expect(controller.currentPage, 1);
      expect(controller.pageCount, 0);
      expect(controller.viewerReady, isFalse);
      expect(controller.lastVisibleRectTop, isNull);
      expect(controller.isBottomNavVisible, isTrue);
    });

    test('setBottomNavVisible reports whether state changed', () {
      final controller = ReaderSessionController();

      expect(controller.setBottomNavVisible(true), isFalse);
      expect(controller.setBottomNavVisible(false), isTrue);
      expect(controller.isBottomNavVisible, isFalse);
      expect(controller.setBottomNavVisible(false), isFalse);
    });

    test('updates selection, search range, and toolbar state', () {
      final controller = ReaderSessionController();
      final range = _FakePdfPageTextRange();

      controller.updateReaderSelection(9, 2);
      controller.setSearchMatchRange(range);
      controller.toggleToolbarMinimized();
      controller.setMinimizedToolbarOffset(const Offset(5, 10));

      expect(controller.currentPage, 9);
      expect(controller.selectedSentenceIndex, 2);
      expect(controller.searchMatchRange, same(range));
      expect(controller.toolbarMinimized, isTrue);
      expect(controller.minimizedToolbarOffset, const Offset(5, 10));
    });

    test('updateVisibleRectTop returns previous value', () {
      final controller = ReaderSessionController();

      expect(controller.updateVisibleRectTop(100), isNull);
      expect(controller.updateVisibleRectTop(140), 100);
      expect(controller.lastVisibleRectTop, 140);
    });
  });
}
