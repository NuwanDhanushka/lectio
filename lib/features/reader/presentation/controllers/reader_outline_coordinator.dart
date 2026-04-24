import 'package:pdfrx/pdfrx.dart';

import '../../domain/reader_page_analysis.dart';
import '../widgets/reader_outline.dart';

class ReaderOutlineCoordinator {
  List<PdfOutlineEntry>? _cachedOutlineEntries;

  List<PdfOutlineEntry>? get cachedOutlineEntries => _cachedOutlineEntries;

  void reset() {
    _cachedOutlineEntries = null;
  }

  Future<List<PdfOutlineEntry>> loadOutlineEntries({
    required PdfDocument? document,
    required int pageCount,
  }) async {
    if (document == null) {
      return const [];
    }
    if (_cachedOutlineEntries != null) {
      return _cachedOutlineEntries!;
    }

    try {
      final outline = await document.loadOutline();
      final builtInEntries = flattenPdfOutlineNodes(outline);
      if (builtInEntries.isNotEmpty) {
        _cachedOutlineEntries = builtInEntries;
        return builtInEntries;
      }
    } catch (_) {
      // Some PDFs expose broken outline metadata. Fall back to detected headings.
    }

    final detectedEntries = await _detectPdfOutlineEntries(
      document: document,
      pageCount: pageCount,
    );
    _cachedOutlineEntries = detectedEntries;
    return detectedEntries;
  }

  Future<String> outlineTitleForPage({
    required int pageNumber,
    required PdfDocument? document,
    required int pageCount,
  }) async {
    final entries = await loadOutlineEntries(
      document: document,
      pageCount: pageCount,
    );
    if (entries.isEmpty) {
      return '';
    }

    PdfOutlineEntry? nearest;
    for (final entry in entries) {
      if (entry.pageNumber > pageNumber) {
        continue;
      }
      if (nearest == null ||
          entry.pageNumber > nearest.pageNumber ||
          (entry.pageNumber == nearest.pageNumber &&
              entry.level >= nearest.level)) {
        nearest = entry;
      }
    }
    return nearest?.title ?? '';
  }

  Future<List<PdfOutlineEntry>> _detectPdfOutlineEntries({
    required PdfDocument document,
    required int pageCount,
  }) async {
    final entries = <PdfOutlineEntry>[];
    final seen = <String>{};

    for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
      final page = await document.pages[pageNumber - 1].ensureLoaded();
      final pageText = await page.loadStructuredText();
      for (final line in extractTextLinesFromPageText(pageText)) {
        final title = preparePdfPageTextForSpeech(line.text);
        if (!isHeadingLikeLine(title)) {
          continue;
        }

        final key = '$pageNumber:${title.toLowerCase()}';
        if (!seen.add(key)) {
          continue;
        }

        entries.add(
          PdfOutlineEntry(
            title: title,
            pageNumber: pageNumber,
            range: PdfPageTextRange(
              pageText: pageText,
              start: line.start,
              end: line.end,
            ),
          ),
        );

        if (entries.length >= 160) {
          return entries;
        }
      }
    }

    return entries;
  }
}
