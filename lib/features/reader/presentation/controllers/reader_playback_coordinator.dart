import 'package:pdfrx/pdfrx.dart';

import '../../domain/reader_page_analysis.dart';

class ReaderPlaybackCoordinator {
  List<PdfPageTextRange> _spokenSentenceRanges = const [];
  int? _spokenRangesPageNumber;
  List<PdfSpeechSegment> _currentPageSpeechSegments = const [];
  int? _currentPageSpeechSegmentsPageNumber;
  bool _isPreparingPlayback = false;
  int _displayedUtteranceIndex = 0;
  int? _lastAutoScrolledUtteranceIndex;

  List<PdfPageTextRange> get spokenSentenceRanges => _spokenSentenceRanges;
  int? get spokenRangesPageNumber => _spokenRangesPageNumber;
  List<PdfSpeechSegment> get currentPageSpeechSegments => _currentPageSpeechSegments;
  int? get currentPageSpeechSegmentsPageNumber => _currentPageSpeechSegmentsPageNumber;
  bool get isPreparingPlayback => _isPreparingPlayback;
  int get displayedUtteranceIndex => _displayedUtteranceIndex;

  void reset() {
    _spokenSentenceRanges = const [];
    _spokenRangesPageNumber = null;
    _currentPageSpeechSegments = const [];
    _currentPageSpeechSegmentsPageNumber = null;
    _isPreparingPlayback = false;
    _displayedUtteranceIndex = 0;
    _lastAutoScrolledUtteranceIndex = null;
  }

  void clearCurrentPageSpeechSegments() {
    _currentPageSpeechSegments = const [];
    _currentPageSpeechSegmentsPageNumber = null;
  }

  void markPreparingPlayback() {
    _isPreparingPlayback = true;
  }

  void clearPreparingPlayback() {
    _isPreparingPlayback = false;
  }

  int? highlightedRangesPageNumber({required bool isTtsBusy}) {
    return isTtsBusy ? _spokenRangesPageNumber : _currentPageSpeechSegmentsPageNumber;
  }

  List<PdfPageTextRange> highlightedSentenceRanges({
    required bool isTtsBusy,
  }) {
    return isTtsBusy
        ? _spokenSentenceRanges
        : _currentPageSpeechSegments
            .map((segment) => segment.range)
            .toList(growable: false);
  }

  int highlightedSentenceIndex({
    required bool isTtsBusy,
    required int? selectedSentenceIndex,
  }) {
    return isTtsBusy ? _displayedUtteranceIndex : (selectedSentenceIndex ?? -1);
  }

  Future<List<PdfSpeechSegment>> loadSpeechSegmentsForPage({
    required PdfDocument? document,
    required int requestedPage,
  }) async {
    if (document == null) {
      return const [];
    }
    if (_currentPageSpeechSegmentsPageNumber == requestedPage &&
        _currentPageSpeechSegments.isNotEmpty) {
      return _currentPageSpeechSegments;
    }

    final page = await document.pages[requestedPage - 1].ensureLoaded();
    final pageText = await page.loadStructuredText();
    return extractSpeechSegmentsFromPageText(pageText);
  }

  void cacheSpeechSegmentsForPage({
    required int requestedPage,
    required List<PdfSpeechSegment> speechSegments,
    required int? selectedSentenceIndex,
    required void Function(int? value) onSelectedSentenceIndexChanged,
  }) {
    _currentPageSpeechSegmentsPageNumber = requestedPage;
    _currentPageSpeechSegments = speechSegments;
    if (selectedSentenceIndex != null &&
        selectedSentenceIndex >= speechSegments.length) {
      onSelectedSentenceIndexChanged(null);
    }
  }

  List<PdfSpeechSegment> playbackSegmentsForCurrentPage({
    required int currentPage,
    required int? selectedSentenceIndex,
  }) {
    final startSentenceIndex = (selectedSentenceIndex != null &&
            _currentPageSpeechSegmentsPageNumber == currentPage)
        ? selectedSentenceIndex.clamp(0, _currentPageSpeechSegments.length - 1)
        : 0;
    return _currentPageSpeechSegments.sublist(startSentenceIndex);
  }

  void beginPlayback({
    required int currentPage,
    required List<PdfSpeechSegment> playbackSegments,
  }) {
    _spokenRangesPageNumber = currentPage;
    _spokenSentenceRanges =
        playbackSegments.map((segment) => segment.range).toList(growable: false);
    _displayedUtteranceIndex = 0;
    _lastAutoScrolledUtteranceIndex = null;
  }

  bool finishPlaybackIfIdle({required bool isBusy}) {
    if (isBusy || _spokenSentenceRanges.isEmpty) {
      return false;
    }
    _isPreparingPlayback = false;
    _spokenSentenceRanges = const [];
    _spokenRangesPageNumber = null;
    _displayedUtteranceIndex = 0;
    _lastAutoScrolledUtteranceIndex = null;
    return true;
  }

  bool syncCurrentUtteranceIndex(int utteranceIndex) {
    if (utteranceIndex == _displayedUtteranceIndex) {
      return false;
    }
    _displayedUtteranceIndex = utteranceIndex;
    return true;
  }

  void syncPlaybackStatus({required bool shouldClearPreparing}) {
    if (shouldClearPreparing) {
      _isPreparingPlayback = false;
    }
  }

  bool shouldAutoScrollToActiveSentence({bool force = false}) {
    if (_spokenSentenceRanges.isEmpty) {
      return false;
    }
    if (_displayedUtteranceIndex < 0 ||
        _displayedUtteranceIndex >= _spokenSentenceRanges.length) {
      return false;
    }
    if (!force && _lastAutoScrolledUtteranceIndex == _displayedUtteranceIndex) {
      return false;
    }
    return true;
  }

  PdfPageTextRange? activePlaybackRange() {
    if (_displayedUtteranceIndex < 0 ||
        _displayedUtteranceIndex >= _spokenSentenceRanges.length) {
      return null;
    }
    return _spokenSentenceRanges[_displayedUtteranceIndex];
  }

  void markAutoScrolledToCurrentUtterance() {
    _lastAutoScrolledUtteranceIndex = _displayedUtteranceIndex;
  }
}
