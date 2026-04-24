import 'package:pdfrx/pdfrx.dart';

import 'reader_speech_analysis.dart';

class PdfSearchResult {
  const PdfSearchResult({
    required this.pageNumber,
    required this.sentenceIndex,
    required this.query,
    required this.snippet,
  });

  final int pageNumber;
  final int sentenceIndex;
  final String query;
  final String snippet;
}

List<PdfSearchResult> searchSpeechSegmentsOnPage({
  required int pageNumber,
  required List<PdfSpeechSegment> segments,
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.length < 2) {
    return const [];
  }

  return [
    for (var i = 0; i < segments.length; i++)
      if (segments[i].text.toLowerCase().contains(normalizedQuery))
        PdfSearchResult(
          pageNumber: pageNumber,
          sentenceIndex: i,
          query: query.trim(),
          snippet: segments[i].text,
        ),
  ];
}

PdfPageTextRange? searchMatchRangeForSegment({
  required PdfSpeechSegment segment,
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.length < 2) {
    return null;
  }

  final rawText = segment.range.text;
  final rawMatchIndex = rawText.toLowerCase().indexOf(normalizedQuery);
  if (rawMatchIndex >= 0) {
    return PdfPageTextRange(
      pageText: segment.range.pageText,
      start: segment.range.start + rawMatchIndex,
      end: segment.range.start + rawMatchIndex + query.trim().length,
    );
  }

  final segmentMatchIndex = segment.text.toLowerCase().indexOf(normalizedQuery);
  if (segmentMatchIndex < 0) {
    return null;
  }

  final rawStart = rawIndexForPreparedTextOffset(
    rawText: rawText,
    preparedOffset: segmentMatchIndex,
  );
  final rawEnd = rawIndexForPreparedTextOffset(
    rawText: rawText,
    preparedOffset: segmentMatchIndex + query.trim().length,
  );
  if (rawEnd <= rawStart) {
    return null;
  }

  return PdfPageTextRange(
    pageText: segment.range.pageText,
    start: segment.range.start + rawStart,
    end: segment.range.start + rawEnd,
  );
}

int rawIndexForPreparedTextOffset({
  required String rawText,
  required int preparedOffset,
}) {
  var preparedIndex = 0;
  var rawIndex = 0;
  var lastWasWhitespace = false;

  while (rawIndex < rawText.length) {
    final codeUnit = rawText.codeUnitAt(rawIndex);
    final isWhitespace = _isWhitespaceCodeUnit(codeUnit);

    if (isWhitespace) {
      if (!lastWasWhitespace) {
        if (preparedIndex >= preparedOffset) {
          return rawIndex;
        }
        preparedIndex++;
      }
      lastWasWhitespace = true;
      rawIndex++;
      continue;
    }

    lastWasWhitespace = false;
    if (preparedIndex >= preparedOffset) {
      return rawIndex;
    }
    preparedIndex++;
    rawIndex++;
  }

  return rawText.length;
}

bool _isWhitespaceCodeUnit(int codeUnit) {
  return RegExp(r'\s').hasMatch(String.fromCharCode(codeUnit));
}
