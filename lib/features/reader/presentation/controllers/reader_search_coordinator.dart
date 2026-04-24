import 'dart:async';

import 'package:pdfrx/pdfrx.dart';

import '../../domain/reader_page_analysis.dart';
import 'reader_pdf_search_controller.dart';
import 'reader_session_controller.dart';

typedef ReaderSpeechSegmentsLoader = Future<List<PdfSpeechSegment>> Function();

class ReaderSearchCoordinator {
  const ReaderSearchCoordinator();

  Future<List<PdfSearchResult>> searchPdf({
    required PdfDocument? document,
    required int pageCount,
    required String query,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (document == null || normalizedQuery.length < 2) {
      return const [];
    }

    final results = <PdfSearchResult>[];
    for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
      final page = await document.pages[pageNumber - 1].ensureLoaded();
      final pageText = await page.loadStructuredText();
      final segments = extractSpeechSegmentsFromPageText(pageText);

      results.addAll(
        searchSpeechSegmentsOnPage(
          pageNumber: pageNumber,
          segments: segments,
          query: normalizedQuery,
        ),
      );
      if (results.length >= 80) {
        return results.take(80).toList(growable: false);
      }
    }

    return results;
  }

  Future<void> openSearchResult({
    required PdfSearchResult result,
    required bool viewerReady,
    required PdfViewerController controller,
    required ReaderPdfSearchController pdfSearchController,
    required ReaderSessionController sessionController,
    required ReaderSpeechSegmentsLoader ensureSpeechSegmentsForCurrentPage,
    required void Function() invalidatePdfViewerSafely,
    required Future<void> Function() autoScrollToSelectedSentence,
    bool updateSearchIndex = true,
  }) async {
    if (!viewerReady) {
      return;
    }

    if (updateSearchIndex) {
      pdfSearchController.syncActiveResult(result);
    }

    await controller.goToPage(pageNumber: result.pageNumber);

    sessionController.setCurrentPage(result.pageNumber);
    sessionController.clearSearchMatchRange();

    final segments = await ensureSpeechSegmentsForCurrentPage();
    if (result.sentenceIndex < 0 || result.sentenceIndex >= segments.length) {
      return;
    }

    sessionController.setSelectedSentenceIndex(result.sentenceIndex);
    sessionController.setSearchMatchRange(
      searchMatchRangeForSegment(
        segment: segments[result.sentenceIndex],
        query: result.query,
      ),
    );
    invalidatePdfViewerSafely();
    unawaited(autoScrollToSelectedSentence());
  }
}
