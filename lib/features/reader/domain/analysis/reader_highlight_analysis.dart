import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'reader_progress_analysis.dart';

List<PdfRect> mergedHighlightRectsForRange(PdfPageTextRange range) {
  final merged = <PdfRect>[];

  for (var i = range.start; i < range.end; i++) {
    final rect = range.pageText.charRects[i];
    if (rect.isEmpty) {
      continue;
    }

    if (merged.isEmpty) {
      merged.add(rect);
      continue;
    }

    final previous = merged.last;
    final baseHeight = rect.height > 0 ? rect.height : previous.height;
    final sameLine = (previous.top - rect.top).abs() <= baseHeight * 0.6 &&
        (previous.bottom - rect.bottom).abs() <= baseHeight * 0.6;
    final gap = rect.left - previous.right;
    final closeGap = gap <= baseHeight * 0.8;

    if (sameLine && closeGap) {
      merged[merged.length - 1] = previous.merge(rect);
    } else {
      merged.add(rect);
    }
  }

  return merged;
}

PdfRect? boundingPdfRectForRange(PdfPageTextRange range) {
  final mergedRects = mergedHighlightRectsForRange(range);
  if (mergedRects.isEmpty) {
    return null;
  }

  var boundingRect = mergedRects.first;
  for (final rect in mergedRects.skip(1)) {
    boundingRect = boundingRect.merge(rect);
  }
  return boundingRect;
}

Rect? documentRectForTextRange({
  required PdfPageTextRange range,
  required PdfViewerController controller,
}) {
  final boundingRect = boundingPdfRectForRange(range);
  if (boundingRect == null || !controller.isReady) {
    return null;
  }

  final pageLayoutRect = controller.layout.pageLayouts[range.pageNumber - 1];
  final page = controller.pages[range.pageNumber - 1];
  final pageRect = boundingRect.toRect(
    page: page,
    scaledPageSize: pageLayoutRect.size,
  );

  return pageRect.translate(pageLayoutRect.left, pageLayoutRect.top);
}

int? sentenceIndexForDocumentPosition({
  required Offset documentPosition,
  required List<PdfPageTextRange> ranges,
  required PdfViewerController controller,
}) {
  final rects = ranges
      .map((range) =>
          documentRectForTextRange(range: range, controller: controller))
      .toList(growable: false);
  return sentenceIndexForDocumentPositionFromRects(
    documentPosition: documentPosition,
    rects: rects,
  );
}

int? sentenceIndexForDocumentPositionFromRects({
  required Offset documentPosition,
  required List<Rect?> rects,
}) {
  if (rects.isEmpty) {
    return null;
  }

  for (var i = 0; i < rects.length; i++) {
    final rect = rects[i];
    if (rect != null && rect.contains(documentPosition)) {
      return i;
    }
  }

  double? bestDistance;
  int? bestIndex;
  for (var i = 0; i < rects.length; i++) {
    final rect = rects[i];
    if (rect == null) {
      continue;
    }
    final dx = documentPosition.dx < rect.left
        ? rect.left - documentPosition.dx
        : documentPosition.dx > rect.right
            ? documentPosition.dx - rect.right
            : 0.0;
    final dy = documentPosition.dy < rect.top
        ? rect.top - documentPosition.dy
        : documentPosition.dy > rect.bottom
            ? documentPosition.dy - rect.bottom
            : 0.0;
    final distance = dx * dx + dy * dy;
    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }

  return bestIndex;
}

PdfRect? partialHighlightRectForRange({
  required PdfPageTextRange range,
  required KaraokeProgressMarker marker,
}) {
  if (marker.partialCharacterProgress <= 0) {
    return null;
  }

  final characterIndex = range.start + marker.spokenLength;
  if (characterIndex < range.start || characterIndex >= range.end) {
    return null;
  }

  final characterRect = range.pageText.charRects[characterIndex];
  if (characterRect.isEmpty) {
    return null;
  }

  final partialWidth =
      characterRect.width * marker.partialCharacterProgress.clamp(0.0, 1.0);
  if (partialWidth <= 0) {
    return null;
  }

  return PdfRect(
    characterRect.left,
    characterRect.top,
    characterRect.left + partialWidth,
    characterRect.bottom,
  );
}
