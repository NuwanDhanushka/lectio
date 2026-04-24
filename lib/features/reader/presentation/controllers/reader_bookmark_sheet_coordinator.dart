import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../domain/document_bookmark.dart';
import '../../domain/reader_page_analysis.dart';
import '../widgets/bookmark_ui.dart';
import 'reader_session_controller.dart';

typedef ReaderBookmarkToggle = Future<void> Function();
typedef ReaderBookmarkEdit = Future<void> Function(DocumentBookmark bookmark);
typedef ReaderBookmarkRemove = Future<List<DocumentBookmark>> Function(
  DocumentBookmark bookmark,
);

class ReaderBookmarkSheetCoordinator {
  const ReaderBookmarkSheetCoordinator();

  Future<void> showBookmarksSheet({
    required BuildContext context,
    required int currentPage,
    required int? currentSentenceIndex,
    required List<DocumentBookmark> Function() getBookmarks,
    required ReaderBookmarkToggle onToggleCurrentPage,
    required Future<void> Function(DocumentBookmark bookmark) onOpenBookmark,
    required ReaderBookmarkRemove onRemoveBookmark,
    required ReaderBookmarkEdit onEditBookmark,
  }) async {
    var sheetIsOpen = true;
    final sheetFuture = showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BookmarksSheet(
              currentPage: currentPage,
              currentSentenceIndex: currentSentenceIndex,
              bookmarks: getBookmarks(),
              onToggleCurrentPage: () async {
                await onToggleCurrentPage();
                if (context.mounted && sheetIsOpen) {
                  setModalState(() {});
                }
              },
              onOpenBookmark: (bookmark) async {
                Navigator.of(context).pop();
                await onOpenBookmark(bookmark);
              },
              onRemoveBookmark: (bookmark) async {
                await onRemoveBookmark(bookmark);
                if (context.mounted && sheetIsOpen) {
                  setModalState(() {});
                }
              },
              onEditBookmark: (bookmark) async {
                await onEditBookmark(bookmark);
                if (context.mounted && sheetIsOpen) {
                  setModalState(() {});
                }
              },
            );
          },
        );
      },
    );

    await sheetFuture.whenComplete(() {
      sheetIsOpen = false;
    });
  }

  Future<void> openBookmark({
    required DocumentBookmark bookmark,
    required bool Function() isMounted,
    required PdfViewerController controller,
    required ReaderSessionController sessionController,
    required Future<List<PdfSpeechSegment>> Function()
        ensureSpeechSegmentsForCurrentPage,
    required void Function() invalidatePdfViewerSafely,
    required Future<void> Function() autoScrollToSelectedSentence,
  }) async {
    await controller.goToPage(pageNumber: bookmark.pageNumber);
    if (!isMounted() || bookmark.sentenceIndex == null) {
      return;
    }

    sessionController.setCurrentPage(bookmark.pageNumber);
    final segments = await ensureSpeechSegmentsForCurrentPage();
    if (!isMounted() ||
        bookmark.sentenceIndex! < 0 ||
        bookmark.sentenceIndex! >= segments.length) {
      return;
    }

    sessionController.setSelectedSentenceIndex(bookmark.sentenceIndex);
    invalidatePdfViewerSafely();
    await autoScrollToSelectedSentence();
  }
}
