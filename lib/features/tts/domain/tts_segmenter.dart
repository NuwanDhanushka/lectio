List<String> splitTextIntoSpeechSegments(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return const [];
  }

  final matches = RegExp(r'[^.!?]+[.!?]?').allMatches(normalized);
  final segments = matches
      .map((match) => match.group(0)!.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  return segments.isEmpty ? [normalized] : segments;
}

List<String> splitTextIntoSpeechChunks(String text) {
  final sentenceSegments = splitTextIntoSpeechSegments(text);
  final chunks = <String>[];

  for (final sentence in sentenceSegments) {
    chunks.addAll(_splitSentenceIntoSpeechChunks(sentence));
  }

  return chunks;
}

List<String> _splitSentenceIntoSpeechChunks(
  String sentence, {
  int minWords = 4,
  int targetWords = 10,
  int maxWords = 14,
}) {
  final normalized = sentence.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return const [];
  }

  final wordMatches = RegExp(
    r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*",
  ).allMatches(normalized).toList(growable: false);
  if (wordMatches.length <= maxWords) {
    return [normalized];
  }

  final chunks = <String>[];
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
      final separatorStart = wordMatches[candidate].end;
      final separatorEnd = candidate < lastWordIndex
          ? wordMatches[candidate + 1].start
          : normalized.length;
      final separator = normalized.substring(separatorStart, separatorEnd);
      if (RegExp(r'[,:;)\]-]|--|—').hasMatch(separator)) {
        chosenEndIndex = candidate;
        foundBoundary = true;
        break;
      }
    }

    if (!foundBoundary) {
      for (var candidate = preferredEndIndex;
          candidate <= maxEndIndex;
          candidate++) {
        final separatorStart = wordMatches[candidate].end;
        final separatorEnd = candidate < lastWordIndex
            ? wordMatches[candidate + 1].start
            : normalized.length;
        final separator = normalized.substring(separatorStart, separatorEnd);
        if (RegExp(r'[,:;)\]-]|--|—').hasMatch(separator)) {
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

    final chunkEnd = chosenEndIndex < lastWordIndex
        ? wordMatches[chosenEndIndex + 1].start
        : normalized.length;
    final chunk =
        normalized.substring(wordMatches[wordIndex].start, chunkEnd).trim();
    if (chunk.isNotEmpty) {
      chunks.add(chunk);
    }

    wordIndex = chosenEndIndex + 1;
  }

  return chunks;
}
