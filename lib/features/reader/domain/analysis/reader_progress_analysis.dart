import 'package:pdfrx/pdfrx.dart';

import '../document_bookmark.dart';

PdfPageTextRange? activeSpokenRangeForPage({
  required int pageNumber,
  required int? spokenRangesPageNumber,
  required List<PdfPageTextRange> spokenSentenceRanges,
  required int currentUtteranceIndex,
}) {
  if (spokenRangesPageNumber != pageNumber) {
    return null;
  }

  if (currentUtteranceIndex < 0 ||
      currentUtteranceIndex >= spokenSentenceRanges.length) {
    return null;
  }

  return spokenSentenceRanges[currentUtteranceIndex];
}

PdfPageTextRange? activeSpokenProgressRangeForPage({
  required int pageNumber,
  required int? spokenRangesPageNumber,
  required List<PdfPageTextRange> spokenSentenceRanges,
  required int currentUtteranceIndex,
  required double currentUtteranceProgress,
}) {
  final range = activeSpokenRangeForPage(
    pageNumber: pageNumber,
    spokenRangesPageNumber: spokenRangesPageNumber,
    spokenSentenceRanges: spokenSentenceRanges,
    currentUtteranceIndex: currentUtteranceIndex,
  );
  if (range == null) {
    return null;
  }

  final spokenLength = spokenCharacterLengthForProgress(
    text: range.text,
    progress: currentUtteranceProgress,
  ).clamp(0, range.end - range.start);

  if (spokenLength <= 0) {
    return null;
  }

  return PdfPageTextRange(
    pageText: range.pageText,
    start: range.start,
    end: range.start + spokenLength,
  );
}

class KaraokeProgressMarker {
  const KaraokeProgressMarker({
    required this.spokenLength,
    required this.partialCharacterProgress,
  });

  final int spokenLength;
  final double partialCharacterProgress;
}

KaraokeProgressMarker karaokeProgressMarkerForText({
  required String text,
  required double progress,
}) {
  final clampedProgress = progress.clamp(0.0, 1.0);
  if (text.isEmpty) {
    return const KaraokeProgressMarker(
      spokenLength: 0,
      partialCharacterProgress: 0,
    );
  }

  final words = _speechWordSegmentsForText(text);
  if (words.isEmpty) {
    return _characterBasedKaraokeProgressMarker(
      text: text,
      progress: clampedProgress,
    );
  }

  final totalWeight = words.fold<double>(
    0,
    (sum, word) => sum + word.timingWeight,
  );
  if (totalWeight <= 0) {
    return _characterBasedKaraokeProgressMarker(
      text: text,
      progress: clampedProgress,
    );
  }

  final targetWeight = totalWeight * clampedProgress;
  var cumulativeWeight = 0.0;

  for (final word in words) {
    final nextWeight = cumulativeWeight + word.timingWeight;
    if (targetWeight > nextWeight) {
      cumulativeWeight = nextWeight;
      continue;
    }

    final targetWithinWordTiming = targetWeight - cumulativeWeight;
    if (targetWithinWordTiming >= word.spokenWeight) {
      return KaraokeProgressMarker(
        spokenLength: word.end,
        partialCharacterProgress: 0,
      );
    }

    var spokenWeightInWord = 0.0;
    for (var i = word.start; i < word.end; i++) {
      final charWeight = _speechUnitWeightForCodeUnit(text.codeUnitAt(i));
      if (charWeight <= 0) {
        continue;
      }

      final nextSpokenWeight = spokenWeightInWord + charWeight;
      if (targetWithinWordTiming <= nextSpokenWeight) {
        final partialCharacterProgress =
            ((targetWithinWordTiming - spokenWeightInWord) / charWeight)
                .clamp(0.0, 1.0);
        if (partialCharacterProgress >= 0.999) {
          return KaraokeProgressMarker(
            spokenLength: i + 1,
            partialCharacterProgress: 0,
          );
        }

        return KaraokeProgressMarker(
          spokenLength: i,
          partialCharacterProgress: partialCharacterProgress,
        );
      }

      spokenWeightInWord = nextSpokenWeight;
    }

    return KaraokeProgressMarker(
      spokenLength: word.end,
      partialCharacterProgress: 0,
    );
  }

  return KaraokeProgressMarker(
    spokenLength: text.length,
    partialCharacterProgress: 0,
  );
}

int spokenCharacterLengthForProgress({
  required String text,
  required double progress,
}) {
  return karaokeProgressMarkerForText(
    text: text,
    progress: progress,
  ).spokenLength;
}

double storedProgressForPage({
  required int pageNumber,
  required int pageCount,
}) {
  if (pageCount <= 1) {
    return 0;
  }

  final clampedPage = pageNumber.clamp(1, pageCount);
  return (clampedPage - 1) / (pageCount - 1);
}

int compareBookmarks(DocumentBookmark a, DocumentBookmark b) {
  final pageComparison = a.pageNumber.compareTo(b.pageNumber);
  if (pageComparison != 0) {
    return pageComparison;
  }
  return (a.sentenceIndex ?? -1).compareTo(b.sentenceIndex ?? -1);
}

int pageNumberForStoredProgress({
  required double progress,
  required int pageCount,
}) {
  if (pageCount <= 1) {
    return 1;
  }

  final clampedProgress = progress.clamp(0.0, 1.0);
  return ((clampedProgress * (pageCount - 1)).round() + 1).clamp(1, pageCount);
}

KaraokeProgressMarker _characterBasedKaraokeProgressMarker({
  required String text,
  required double progress,
}) {
  final weights = text.codeUnits.map(_speechUnitWeightForCodeUnit).toList(
        growable: false,
      );
  final totalWeight = weights.fold<double>(0, (sum, weight) => sum + weight);
  if (totalWeight <= 0) {
    return const KaraokeProgressMarker(
      spokenLength: 0,
      partialCharacterProgress: 0,
    );
  }

  final targetWeight = totalWeight * progress.clamp(0.0, 1.0);
  var cumulativeWeight = 0.0;
  var lastSpokenNonWhitespace = -1;

  for (var i = 0; i < weights.length; i++) {
    final nextWeight = cumulativeWeight + weights[i];
    final codeUnit = text.codeUnitAt(i);

    if (targetWeight <= nextWeight) {
      if (_isWhitespaceCodeUnit(codeUnit)) {
        return KaraokeProgressMarker(
          spokenLength: lastSpokenNonWhitespace + 1,
          partialCharacterProgress: 0,
        );
      }

      final charWeight = weights[i];
      if (charWeight <= 0) {
        return KaraokeProgressMarker(
          spokenLength: i + 1,
          partialCharacterProgress: 0,
        );
      }

      final partialCharacterProgress =
          ((targetWeight - cumulativeWeight) / charWeight).clamp(0.0, 1.0);
      if (partialCharacterProgress >= 0.999) {
        return KaraokeProgressMarker(
          spokenLength: i + 1,
          partialCharacterProgress: 0,
        );
      }

      return KaraokeProgressMarker(
        spokenLength: i,
        partialCharacterProgress: partialCharacterProgress,
      );
    }

    cumulativeWeight = nextWeight;
    if (!_isWhitespaceCodeUnit(codeUnit)) {
      lastSpokenNonWhitespace = i;
    }
  }

  return KaraokeProgressMarker(
    spokenLength: text.length,
    partialCharacterProgress: 0,
  );
}

class _SpeechWordSegment {
  const _SpeechWordSegment({
    required this.start,
    required this.end,
    required this.spokenWeight,
    required this.timingWeight,
  });

  final int start;
  final int end;
  final double spokenWeight;
  final double timingWeight;
}

List<_SpeechWordSegment> _speechWordSegmentsForText(String text) {
  final matches = RegExp(
    r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*",
  ).allMatches(text).toList(growable: false);
  if (matches.isEmpty) {
    return const [];
  }

  final segments = <_SpeechWordSegment>[];
  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final segmentStart = match.start;
    final segmentEnd =
        matches.length > i + 1 ? matches[i + 1].start : text.length;
    final spokenWeight = _weightForTextSlice(
      text: text,
      start: match.start,
      end: match.end,
    );
    final timingWeight = _weightForTextSlice(
      text: text,
      start: segmentStart,
      end: segmentEnd,
    );

    segments.add(
      _SpeechWordSegment(
        start: match.start,
        end: match.end,
        spokenWeight: spokenWeight,
        timingWeight: timingWeight > 0 ? timingWeight : spokenWeight,
      ),
    );
  }

  return segments;
}

double _weightForTextSlice({
  required String text,
  required int start,
  required int end,
}) {
  var weight = 0.0;
  for (var i = start; i < end; i++) {
    weight += _speechUnitWeightForCodeUnit(text.codeUnitAt(i));
  }
  return weight;
}

double _speechUnitWeightForCodeUnit(int codeUnit) {
  final char = String.fromCharCode(codeUnit);
  if (_isWhitespaceCodeUnit(codeUnit)) {
    return 0.08;
  }
  if (RegExp(r'[,.!?;:]').hasMatch(char)) {
    return 0.22;
  }
  if (RegExp(r'[0-9]').hasMatch(char)) {
    return 0.9;
  }
  return 1.0;
}

bool _isWhitespaceCodeUnit(int codeUnit) {
  return RegExp(r'\s').hasMatch(String.fromCharCode(codeUnit));
}
