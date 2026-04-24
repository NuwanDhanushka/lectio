import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/reader/domain/reader_page_analysis.dart';
import 'package:lectio/features/reader/presentation/controllers/reader_playback_coordinator.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakePdfPageTextRange implements PdfPageTextRange {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PdfSpeechSegment _segment() {
  return PdfSpeechSegment(
    text: 'Sentence text',
    range: _FakePdfPageTextRange(),
  );
}

void main() {
  group('ReaderPlaybackCoordinator', () {
    late ReaderPlaybackCoordinator coordinator;

    setUp(() {
      coordinator = ReaderPlaybackCoordinator();
    });

    test('starts with expected defaults', () {
      expect(coordinator.spokenSentenceRanges, isEmpty);
      expect(coordinator.spokenRangesPageNumber, isNull);
      expect(coordinator.currentPageSpeechSegments, isEmpty);
      expect(coordinator.currentPageSpeechSegmentsPageNumber, isNull);
      expect(coordinator.isPreparingPlayback, isFalse);
      expect(coordinator.displayedUtteranceIndex, 0);
    });

    test('cacheSpeechSegmentsForPage stores current page segments', () {
      final segments = [_segment(), _segment()];
      int? clearedSelection = 1;

      coordinator.cacheSpeechSegmentsForPage(
        requestedPage: 4,
        speechSegments: segments,
        selectedSentenceIndex: 3,
        onSelectedSentenceIndexChanged: (value) {
          clearedSelection = value;
        },
      );

      expect(coordinator.currentPageSpeechSegmentsPageNumber, 4);
      expect(coordinator.currentPageSpeechSegments, segments);
      expect(clearedSelection, isNull);
    });

    test('playbackSegmentsForCurrentPage respects selected sentence', () {
      final first = _segment();
      final second = _segment();
      final third = _segment();

      coordinator.cacheSpeechSegmentsForPage(
        requestedPage: 2,
        speechSegments: [first, second, third],
        selectedSentenceIndex: 1,
        onSelectedSentenceIndexChanged: (_) {},
      );

      final playback = coordinator.playbackSegmentsForCurrentPage(
        currentPage: 2,
        selectedSentenceIndex: 1,
      );

      expect(playback, [second, third]);
    });

    test('beginPlayback populates spoken range state', () {
      final segments = [_segment(), _segment()];

      coordinator.beginPlayback(
        currentPage: 7,
        playbackSegments: segments,
      );

      expect(coordinator.spokenRangesPageNumber, 7);
      expect(coordinator.spokenSentenceRanges, hasLength(2));
      expect(coordinator.displayedUtteranceIndex, 0);
    });

    test('finishPlaybackIfIdle clears spoken state only when idle', () {
      coordinator.beginPlayback(
        currentPage: 5,
        playbackSegments: [_segment()],
      );
      coordinator.markPreparingPlayback();

      expect(coordinator.finishPlaybackIfIdle(isBusy: true), isFalse);
      expect(coordinator.spokenSentenceRanges, isNotEmpty);

      expect(coordinator.finishPlaybackIfIdle(isBusy: false), isTrue);
      expect(coordinator.spokenSentenceRanges, isEmpty);
      expect(coordinator.spokenRangesPageNumber, isNull);
      expect(coordinator.isPreparingPlayback, isFalse);
    });

    test('syncCurrentUtteranceIndex updates only on change', () {
      expect(coordinator.syncCurrentUtteranceIndex(0), isFalse);
      expect(coordinator.syncCurrentUtteranceIndex(2), isTrue);
      expect(coordinator.displayedUtteranceIndex, 2);
    });

    test('auto scroll bookkeeping works for current utterance', () {
      coordinator.beginPlayback(
        currentPage: 1,
        playbackSegments: [_segment(), _segment()],
      );

      expect(coordinator.shouldAutoScrollToActiveSentence(), isTrue);
      coordinator.markAutoScrolledToCurrentUtterance();
      expect(coordinator.shouldAutoScrollToActiveSentence(), isFalse);
      expect(coordinator.shouldAutoScrollToActiveSentence(force: true), isTrue);
      expect(coordinator.activePlaybackRange(), isNotNull);
    });

    test('reset restores defaults', () {
      coordinator.beginPlayback(
        currentPage: 3,
        playbackSegments: [_segment()],
      );
      coordinator.markPreparingPlayback();
      coordinator.clearCurrentPageSpeechSegments();
      coordinator.reset();

      expect(coordinator.spokenSentenceRanges, isEmpty);
      expect(coordinator.currentPageSpeechSegments, isEmpty);
      expect(coordinator.isPreparingPlayback, isFalse);
      expect(coordinator.displayedUtteranceIndex, 0);
    });
  });
}
