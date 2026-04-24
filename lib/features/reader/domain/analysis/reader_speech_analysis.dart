import 'package:pdfrx/pdfrx.dart';

String preparePdfPageTextForSpeech(String rawText) {
  final collapsed = rawText
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(
        RegExp(r'([a-zA-Z])-\s+([a-zA-Z])'),
        (match) => '${match.group(1)}${match.group(2)}',
      )
      .trim();

  return collapsed;
}

String previewSummaryForPageText(String pageText) {
  final cleanText = preparePdfPageTextForSpeech(pageText);
  if (cleanText.isEmpty) {
    return 'No readable text was found on this page.';
  }

  final sentenceMatches =
      RegExp(r'[^.!?]+(?:[.!?]+|$)').allMatches(cleanText).toList();
  final sentences = sentenceMatches
      .map((match) => match.group(0)?.trim() ?? '')
      .where((sentence) => sentence.length > 24)
      .take(3)
      .toList(growable: false);

  final summaryText = sentences.isEmpty
      ? cleanText
      : sentences.map((sentence) => '• $sentence').join('\n');
  if (summaryText.length <= 520) {
    return summaryText;
  }

  return '${summaryText.substring(0, 520).trimRight()}...';
}

class PdfSpeechSegment {
  const PdfSpeechSegment({
    required this.text,
    required this.range,
  });

  final String text;
  final PdfPageTextRange range;
}

class PageTextLine {
  const PageTextLine({
    required this.start,
    required this.end,
    required this.bounds,
    required this.text,
  });

  final int start;
  final int end;
  final PdfRect bounds;
  final String text;
}

class TextBounds {
  const TextBounds({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;
}

List<PdfSpeechSegment> extractSpeechSegmentsFromPageText(PdfPageText pageText) {
  if (pageText.fragments.isEmpty) {
    return _extractSpeechSegmentsFromPlainText(pageText);
  }

  final lines = extractTextLinesFromPageText(pageText);
  if (lines.isEmpty) {
    return _extractSpeechSegmentsFromPlainText(pageText);
  }

  final segments = <PdfSpeechSegment>[];
  var paragraphStartLine = -1;

  void flushParagraph([int? exclusiveEndLine]) {
    if (paragraphStartLine < 0) {
      return;
    }
    final endLine = exclusiveEndLine ?? lines.length;
    if (endLine <= paragraphStartLine) {
      paragraphStartLine = -1;
      return;
    }

    final start = lines[paragraphStartLine].start;
    final end = lines[endLine - 1].end;
    final paragraphRange = PdfPageTextRange(
      pageText: pageText,
      start: start,
      end: end,
    );
    segments.addAll(_splitRangeIntoSentenceSegments(paragraphRange));
    paragraphStartLine = -1;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmedText = line.text.trim();
    if (trimmedText.isEmpty) {
      flushParagraph(i);
      continue;
    }

    final lineRange = PdfPageTextRange(
      pageText: pageText,
      start: line.start,
      end: line.end,
    );
    final inlineBulletSegments = _splitRangeAroundInlineBullets(lineRange);
    if (inlineBulletSegments.length > 1) {
      flushParagraph(i);
      segments.addAll(inlineBulletSegments);
      continue;
    }

    if (isHeadingLikeLine(trimmedText) || _isBulletLikeLine(trimmedText)) {
      flushParagraph(i);
      segments.addAll(_splitRangeIntoDirectSegment(lineRange));
      continue;
    }

    paragraphStartLine = paragraphStartLine < 0 ? i : paragraphStartLine;
  }

  flushParagraph();
  return segments;
}

List<PageTextLine> extractTextLinesFromPageText(PdfPageText pageText) {
  if (pageText.fragments.isEmpty) {
    return const [];
  }

  final lines = <PageTextLine>[];
  var lineStart = pageText.fragments.first.index;
  var lineEnd = pageText.fragments.first.end;
  var lineBounds = pageText.fragments.first.bounds;

  for (var i = 1; i < pageText.fragments.length; i++) {
    final fragment = pageText.fragments[i];
    if (_isSameVisualLine(lineBounds, fragment.bounds)) {
      lineEnd = fragment.end;
      lineBounds = lineBounds.merge(fragment.bounds);
      continue;
    }

    final bounds = _trimTextBounds(
      pageText.fullText,
      start: lineStart,
      end: lineEnd,
    );
    if (bounds != null) {
      lines.add(
        PageTextLine(
          start: bounds.start,
          end: bounds.end,
          bounds: lineBounds,
          text: pageText.fullText.substring(bounds.start, bounds.end),
        ),
      );
    }

    lineStart = fragment.index;
    lineEnd = fragment.end;
    lineBounds = fragment.bounds;
  }

  final finalBounds = _trimTextBounds(
    pageText.fullText,
    start: lineStart,
    end: lineEnd,
  );
  if (finalBounds != null) {
    lines.add(
      PageTextLine(
        start: finalBounds.start,
        end: finalBounds.end,
        bounds: lineBounds,
        text: pageText.fullText.substring(finalBounds.start, finalBounds.end),
      ),
    );
  }

  return lines;
}

List<TextBounds> splitTextIntoSpeechChunkBounds(
  String text, {
  int minWords = 4,
  int targetWords = 10,
  int maxWords = 14,
}) {
  final normalizedBounds = _trimTextBounds(text, start: 0, end: text.length);
  if (normalizedBounds == null) {
    return const [];
  }

  final wordMatches = RegExp(
    r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*",
  ).allMatches(text, normalizedBounds.start).toList(growable: false);
  if (wordMatches.isEmpty) {
    return [normalizedBounds];
  }

  if (wordMatches.length <= maxWords) {
    return [normalizedBounds];
  }

  final chunks = <TextBounds>[];
  var wordIndex = 0;
  while (wordIndex < wordMatches.length) {
    final lastWordIndex = wordMatches.length - 1;
    final preferredEndIndex =
        (wordIndex + targetWords - 1).clamp(wordIndex, lastWordIndex);
    final minEndIndex =
        (wordIndex + minWords - 1).clamp(wordIndex, lastWordIndex);
    final maxEndIndex =
        (wordIndex + maxWords - 1).clamp(wordIndex, lastWordIndex);
    var chosenEndIndex = maxEndIndex;
    var foundBoundary = false;

    for (var candidate = preferredEndIndex;
        candidate >= minEndIndex;
        candidate--) {
      if (_hasNaturalChunkBoundaryAfterWord(
        text: text,
        currentWord: wordMatches[candidate],
        nextWord: candidate < lastWordIndex ? wordMatches[candidate + 1] : null,
      )) {
        chosenEndIndex = candidate;
        foundBoundary = true;
        break;
      }
    }

    if (!foundBoundary) {
      for (var candidate = preferredEndIndex;
          candidate <= maxEndIndex;
          candidate++) {
        if (_hasNaturalChunkBoundaryAfterWord(
          text: text,
          currentWord: wordMatches[candidate],
          nextWord:
              candidate < lastWordIndex ? wordMatches[candidate + 1] : null,
        )) {
          chosenEndIndex = candidate;
          foundBoundary = true;
          break;
        }
      }
    }

    final remainingWords = lastWordIndex - chosenEndIndex;
    if (remainingWords > 0 && remainingWords < minWords) {
      chosenEndIndex = lastWordIndex - minWords;
    }

    final chunkStart = wordMatches[wordIndex].start;
    final chunkEndSource = chosenEndIndex < lastWordIndex
        ? wordMatches[chosenEndIndex + 1].start
        : normalizedBounds.end;
    final chunkBounds = _trimTextBounds(
      text,
      start: chunkStart,
      end: chunkEndSource,
    );
    if (chunkBounds != null) {
      chunks.add(chunkBounds);
    }

    wordIndex = chosenEndIndex + 1;
  }

  return chunks;
}

bool isHeadingLikeLine(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || _isBulletLikeLine(trimmed)) {
    return false;
  }
  if (trimmed.length > 80) {
    return false;
  }
  if (trimmed.endsWith('.') || trimmed.endsWith('?') || trimmed.endsWith('!')) {
    return false;
  }

  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length > 10) {
    return false;
  }

  final titleCaseWords = words.where((word) {
    final normalized = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (normalized.isEmpty) {
      return false;
    }
    final first = normalized[0];
    return first == first.toUpperCase() && first != first.toLowerCase();
  }).length;

  return titleCaseWords >= (words.length / 2).ceil();
}

List<PdfSpeechSegment> _splitRangeIntoDirectSegment(PdfPageTextRange range) {
  final spokenText = preparePdfPageTextForSpeech(range.text);
  if (spokenText.isEmpty) {
    return const [];
  }

  return [
    PdfSpeechSegment(
      text: spokenText,
      range: range,
    ),
  ];
}

List<PdfSpeechSegment> _extractSpeechSegmentsFromPlainText(
  PdfPageText pageText,
) {
  final matches = RegExp(r'[^.!?]+[.!?]?').allMatches(pageText.fullText);
  final segments = <PdfSpeechSegment>[];

  for (final match in matches) {
    final bounds = _trimTextBounds(
      pageText.fullText,
      start: match.start,
      end: match.end,
    );
    if (bounds == null) {
      continue;
    }

    final spokenText = preparePdfPageTextForSpeech(
      pageText.fullText.substring(bounds.start, bounds.end),
    );
    if (spokenText.isEmpty) {
      continue;
    }

    segments.add(
      PdfSpeechSegment(
        text: spokenText,
        range: PdfPageTextRange(
          pageText: pageText,
          start: bounds.start,
          end: bounds.end,
        ),
      ),
    );
  }

  return segments;
}

bool _isSameVisualLine(PdfRect a, PdfRect b) {
  final referenceHeight = [a.height.abs(), b.height.abs()]
      .where((value) => value > 0)
      .fold<double>(0, (current, value) => current > value ? current : value);
  final tolerance = referenceHeight > 0 ? referenceHeight * 0.55 : 4.0;
  return (a.top - b.top).abs() <= tolerance &&
      (a.bottom - b.bottom).abs() <= tolerance;
}

bool _isBulletLikeLine(String text) {
  final trimmed = text.trimLeft();
  return RegExp(r'^([•●▪◦*]|[-–—]\s+|\d+[.)]\s+|[A-Za-z][.)]\s+)')
      .hasMatch(trimmed);
}

List<PdfSpeechSegment> _splitRangeAroundInlineBullets(PdfPageTextRange range) {
  final bulletMatches = RegExp(r'[•●▪◦*]\s+').allMatches(range.text).toList(
        growable: false,
      );
  if (bulletMatches.isEmpty) {
    return _splitRangeIntoDirectSegment(range);
  }

  final segments = <PdfSpeechSegment>[];
  final introBounds = _trimTextBounds(
    range.pageText.fullText,
    start: range.start,
    end: range.start + bulletMatches.first.start,
  );
  if (introBounds != null) {
    segments.addAll(
      _splitRangeIntoDirectSegment(
        PdfPageTextRange(
          pageText: range.pageText,
          start: introBounds.start,
          end: introBounds.end,
        ),
      ),
    );
  }

  for (var i = 0; i < bulletMatches.length; i++) {
    final bulletStart = range.start + bulletMatches[i].start;
    final bulletEnd = i + 1 < bulletMatches.length
        ? range.start + bulletMatches[i + 1].start
        : range.end;
    final bulletBounds = _trimTextBounds(
      range.pageText.fullText,
      start: bulletStart,
      end: bulletEnd,
    );
    if (bulletBounds == null) {
      continue;
    }

    segments.addAll(
      _splitRangeIntoDirectSegment(
        PdfPageTextRange(
          pageText: range.pageText,
          start: bulletBounds.start,
          end: bulletBounds.end,
        ),
      ),
    );
  }

  return segments;
}

List<PdfSpeechSegment> _splitRangeIntoSentenceSegments(PdfPageTextRange range) {
  final matches = RegExp(r'[^.!?]+[.!?]?').allMatches(range.text);
  final segments = <PdfSpeechSegment>[];

  for (final match in matches) {
    final bounds = _trimTextBounds(
      range.pageText.fullText,
      start: range.start + match.start,
      end: range.start + match.end,
    );
    if (bounds == null) {
      continue;
    }

    final spokenText = preparePdfPageTextForSpeech(
      range.pageText.fullText.substring(bounds.start, bounds.end),
    );
    if (spokenText.isEmpty) {
      continue;
    }

    segments.add(
      PdfSpeechSegment(
        text: spokenText,
        range: PdfPageTextRange(
          pageText: range.pageText,
          start: bounds.start,
          end: bounds.end,
        ),
      ),
    );
  }

  return segments;
}

TextBounds? _trimTextBounds(
  String text, {
  required int start,
  required int end,
}) {
  var trimmedStart = start;
  var trimmedEnd = end;

  while (
      trimmedStart < trimmedEnd && RegExp(r'\s').hasMatch(text[trimmedStart])) {
    trimmedStart++;
  }
  while (trimmedEnd > trimmedStart &&
      RegExp(r'\s').hasMatch(text[trimmedEnd - 1])) {
    trimmedEnd--;
  }

  if (trimmedStart >= trimmedEnd) {
    return null;
  }

  return TextBounds(start: trimmedStart, end: trimmedEnd);
}

bool _hasNaturalChunkBoundaryAfterWord({
  required String text,
  required RegExpMatch currentWord,
  required RegExpMatch? nextWord,
}) {
  final boundaryEnd = nextWord?.start ?? text.length;
  if (boundaryEnd <= currentWord.end) {
    return true;
  }

  final separator = text.substring(currentWord.end, boundaryEnd);
  return RegExp(r'[,:;)\]-]|--|—').hasMatch(separator);
}
