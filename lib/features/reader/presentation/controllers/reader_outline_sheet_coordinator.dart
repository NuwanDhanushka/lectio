import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../domain/reader_page_analysis.dart';
import '../widgets/reader_outline.dart';
import 'reader_session_controller.dart';

class ReaderOutlineSheetCoordinator {
  const ReaderOutlineSheetCoordinator();

  Future<void> showPdfOutlineSheet({
    required BuildContext context,
    required bool viewerReady,
    required PdfDocument? pdfDocument,
    required String documentTitle,
    required String documentFileName,
    required Set<int> collapsedOutlineIndexes,
    required Future<List<PdfOutlineEntry>> Function() loadPdfOutlineEntries,
    required Future<void> Function(PdfOutlineEntry entry) openOutlineEntry,
    required void Function(String message) showMessage,
  }) async {
    if (!viewerReady || pdfDocument == null) {
      showMessage('The PDF is still loading. Try again in a moment.');
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close document outline',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PdfOutlineSidebar(
          documentTitle: documentTitle,
          documentFileName: documentFileName,
          entriesFuture: loadPdfOutlineEntries(),
          collapsedIndexes: collapsedOutlineIndexes,
          onCollapsedIndexesChanged: (indexes) {
            collapsedOutlineIndexes
              ..clear()
              ..addAll(indexes);
          },
          onOpenEntry: (entry) async {
            Navigator.of(context).pop();
            await openOutlineEntry(entry);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  Future<void> openOutlineEntry({
    required PdfOutlineEntry entry,
    required bool viewerReady,
    required PdfViewerController controller,
    required ReaderSessionController sessionController,
    required void Function() invalidatePdfViewerSafely,
  }) async {
    if (!viewerReady) {
      return;
    }

    sessionController.clearSearchMatchRange();
    if (entry.dest != null) {
      await controller.goToDest(entry.dest);
    } else {
      await controller.goToPage(pageNumber: entry.pageNumber);
    }

    sessionController.updateReaderSelection(entry.pageNumber, null);
    sessionController.setSearchMatchRange(entry.range);
    invalidatePdfViewerSafely();

    final range = entry.range;
    if (range == null) {
      return;
    }

    final documentRect = documentRectForTextRange(
      range: range,
      controller: controller,
    );
    if (documentRect == null) {
      return;
    }

    await controller.ensureVisible(
      documentRect,
      duration: const Duration(milliseconds: 260),
      margin: 56,
    );
  }
}
