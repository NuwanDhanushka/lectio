import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../../notebook/domain/document_note.dart';
import '../../../offline_ai/data/offline_ai_model_service.dart';
import '../../../tts/presentation/controllers/sherpa_tts_service.dart';
import '../../domain/document_bookmark.dart';
import '../../domain/reader_page_analysis.dart';
import '../controllers/reader_ai_coordinator.dart';
import '../controllers/reader_bookmark_coordinator.dart';
import '../controllers/reader_bookmark_flow_coordinator.dart';
import '../controllers/reader_bookmark_sheet_coordinator.dart';
import '../controllers/reader_notebook_coordinator.dart';
import '../controllers/reader_outline_coordinator.dart';
import '../controllers/reader_outline_sheet_coordinator.dart';
import '../controllers/reader_playback_coordinator.dart';
import '../controllers/reader_playback_session.dart';
import '../controllers/reader_pdf_search_controller.dart';
import '../controllers/reader_progress_coordinator.dart';
import '../controllers/reader_search_coordinator.dart';
import '../controllers/reader_session_controller.dart';
import '../controllers/reader_viewer_coordinator.dart';
import '../helpers/reader_toolbar_layout.dart';
import '../widgets/reader_chrome.dart';
import '../widgets/reader_outline.dart';
import '../widgets/reader_page_widgets.dart';
import '../widgets/reader_tts_dock.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({
    super.key,
    this.item,
    this.repository,
    this.initialPage,
    this.onBottomNavVisibilityChanged,
    this.onItemUpdated,
  });

  final LibraryItem? item;
  final LibraryRepository? repository;
  final int? initialPage;
  final ValueChanged<bool>? onBottomNavVisibilityChanged;
  final ValueChanged<LibraryItem>? onItemUpdated;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage>
    with SingleTickerProviderStateMixin {
  final PdfViewerController _controller = PdfViewerController();
  final SherpaTtsService _ttsService = SherpaTtsService.instance;
  final OfflineAiModelService _aiModelService = OfflineAiModelService.instance;
  final ReaderAiCoordinator _aiCoordinator = const ReaderAiCoordinator();
  final ReaderBookmarkCoordinator _bookmarkCoordinator =
      const ReaderBookmarkCoordinator();
  final ReaderBookmarkFlowCoordinator _bookmarkFlowCoordinator =
      const ReaderBookmarkFlowCoordinator();
  final ReaderBookmarkSheetCoordinator _bookmarkSheetCoordinator =
      const ReaderBookmarkSheetCoordinator();
  final ReaderNotebookCoordinator _notebookCoordinator =
      const ReaderNotebookCoordinator();
  final ReaderOutlineCoordinator _outlineCoordinator =
      ReaderOutlineCoordinator();
  final ReaderOutlineSheetCoordinator _outlineSheetCoordinator =
      const ReaderOutlineSheetCoordinator();
  final ReaderPlaybackCoordinator _playbackCoordinator =
      ReaderPlaybackCoordinator();
  final ReaderPlaybackSession _playbackSession = const ReaderPlaybackSession();
  final ReaderPdfSearchController _pdfSearchController =
      ReaderPdfSearchController();
  final ReaderProgressCoordinator _readingProgress =
      ReaderProgressCoordinator();
  final ReaderSearchCoordinator _searchCoordinator =
      const ReaderSearchCoordinator();
  final ReaderSessionController _sessionController = ReaderSessionController();
  final ReaderViewerCoordinator _viewerCoordinator =
      const ReaderViewerCoordinator();
  AnimationController? _karaokeProgressController;
  List<DocumentBookmark> _bookmarks = const [];
  final Set<int> _collapsedOutlineIndexes = {};

  @override
  void initState() {
    super.initState();
    _ensureKaraokeProgressController();
    _ttsService.ensureInitialized();
    _aiModelService.ensureInitialized();
    _ttsService.addListener(_handleTtsChanged);
    _pdfSearchController.addListener(_handleSearchChanged);
    _sessionController.addListener(_handleSessionChanged);
    _controller.addListener(_handleReaderScrollChanged);
  }

  @override
  void didUpdateWidget(covariant DetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.filePath != widget.item?.filePath) {
      _ensureKaraokeProgressController().value = 0;
      _sessionController.resetForDocumentChange();
      _pdfSearchController.reset();
      _playbackCoordinator.reset();
      _readingProgress.reset();
      _bookmarks = const [];
      _collapsedOutlineIndexes.clear();
      _outlineCoordinator.reset();
    } else if (oldWidget.initialPage != widget.initialPage &&
        widget.initialPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_restoreSavedReadingPosition());
      });
    }
  }

  @override
  void dispose() {
    _pdfSearchController.removeListener(_handleSearchChanged);
    _sessionController.removeListener(_handleSessionChanged);
    _pdfSearchController.dispose();
    _karaokeProgressController?.dispose();
    _ttsService.removeListener(_handleTtsChanged);
    _controller.removeListener(_handleReaderScrollChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final karaokeProgressController = _ensureKaraokeProgressController();
    final document = widget.item;

    if (document == null) {
      return const ReaderEmptyState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FB),
      body: SafeArea(
        top: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  _readerTopContentInset,
                  12,
                  20,
                ),
                child: ReaderPdfViewerBody(
                  item: document,
                  controller: _controller,
                  activeSpokenRange: activeSpokenRangeForPage(
                    pageNumber: _sessionController.currentPage,
                    spokenRangesPageNumber: _highlightedRangesPageNumber,
                    spokenSentenceRanges: _highlightedSentenceRanges,
                    currentUtteranceIndex: _highlightedSentenceIndex,
                  ),
                  activeSpokenProgressRange: activeSpokenProgressRangeForPage(
                    pageNumber: _sessionController.currentPage,
                    spokenRangesPageNumber:
                        _playbackCoordinator.spokenRangesPageNumber,
                    spokenSentenceRanges:
                        _playbackCoordinator.spokenSentenceRanges,
                    currentUtteranceIndex:
                        _playbackCoordinator.displayedUtteranceIndex,
                    currentUtteranceProgress: karaokeProgressController.value,
                  ),
                  searchMatchRange:
                      _sessionController.searchMatchRange?.pageNumber ==
                              _sessionController.currentPage
                          ? _sessionController.searchMatchRange
                          : null,
                  activeSpokenProgress: karaokeProgressController.value,
                  onDocumentTap: _handleViewerTap,
                  onViewerInteractionChanged: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }

                      setState(() {});
                    });
                  },
                  onViewerReady: _handleViewerReady,
                  onPageChanged: _handlePageChanged,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopChrome(
                isExpanded: _sessionController.isBottomNavVisible,
                isSearchVisible: _pdfSearchController.isVisible,
                documentTitle: document.title,
                documentFileName: document.fileName.isEmpty
                    ? document.format
                    : document.fileName,
                pageLabel: _sessionController.pageCount > 0
                    ? 'PAGE ${_sessionController.currentPage} / ${_sessionController.pageCount}'
                    : 'LOADING',
                canInteract: _sessionController.viewerReady,
                searchController: _pdfSearchController.textController,
                isSearching: _pdfSearchController.isSearching,
                resultCount: _pdfSearchController.results.length,
                activeResultIndex: _pdfSearchController.activeResultIndex,
                onOutlinePressed: _showPdfOutlineSheet,
                onSearchPressed: _showInlinePdfSearch,
                onSearchChanged: _scheduleInlinePdfSearch,
                onSearchSubmitted: (query) =>
                    unawaited(_runInlinePdfSearch(query)),
                onPreviousSearchResult: _goToPreviousPdfSearchResult,
                onNextSearchResult: _goToNextPdfSearchResult,
                onCloseSearch: _closeInlinePdfSearch,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: IgnorePointer(
                ignoring: _pdfSearchController.isVisible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: _pdfSearchController.isVisible ? 0 : 1,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    offset: _pdfSearchController.isVisible
                        ? const Offset(0, 0.16)
                        : Offset.zero,
                    child: ReaderTtsDock(
                      service: _ttsService,
                      isPreparingPlayback:
                          _playbackCoordinator.isPreparingPlayback,
                      onPlayPressed: () async {
                        if (_ttsService.canResume) {
                          await _ttsService.resume();
                          return;
                        }

                        await _speakCurrentContext(document);
                      },
                      onPausePressed: _ttsService.pause,
                      onStopPressed: _ttsService.stop,
                      onPreviousPressed: () =>
                          _ttsService.seekToUtteranceOffset(-1),
                      onNextPressed: () => _ttsService.seekToUtteranceOffset(1),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: 12,
              right: 12,
              bottom: _pdfSearchController.isVisible ? 20 : 176,
              child: Transform.translate(
                offset: _sessionController.toolbarMinimized
                    ? _sessionController.minimizedToolbarOffset
                    : _expandedToolbarOffset,
                child: ReaderToolbar(
                  canInteract: _sessionController.viewerReady,
                  isMinimized: _sessionController.toolbarMinimized,
                  onToggleMinimized: _sessionController.toggleToolbarMinimized,
                  onMinimizedDragUpdate: (delta) {
                    _sessionController.setMinimizedToolbarOffset(
                      _clampedMinimizedToolbarOffset(
                        _sessionController.minimizedToolbarOffset + delta,
                      ),
                    );
                  },
                  zoomLabel: _zoomLabel,
                  onPreviousPage: _goToPreviousPage,
                  onNextPage: _goToNextPage,
                  onZoomOut: _zoomOut,
                  onZoomIn: _zoomIn,
                  onFitPage: _fitPage,
                  isBookmarked: _isCurrentPageBookmarked,
                  onBookmarkPressed: _showBookmarksSheet,
                  onAiPressed: _showReaderAiActionsSheet,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _speakCurrentContext(LibraryItem document) async {
    await _playbackSession.speakCurrentContext(
      document: document,
      ttsService: _ttsService,
      sessionController: _sessionController,
      playbackCoordinator: _playbackCoordinator,
      ensureSpeechSegmentsForCurrentPage: _ensureSpeechSegmentsForCurrentPage,
      karaokeProgressController: _ensureKaraokeProgressController(),
      invalidatePdfViewerSafely: _invalidatePdfViewerSafely,
      autoScrollToActiveSentence: _autoScrollToActiveSentence,
      showMessage: _showReaderMessage,
      refreshUi: _refreshUi,
    );
  }

  void _handleViewerReady(
      PdfDocument document, PdfViewerController controller) {
    _viewerCoordinator.handleViewerReady(
      document: document,
      controller: controller,
      isMounted: () => mounted,
      sessionController: _sessionController,
      loadBookmarks: _loadBookmarks,
      restoreSavedReadingPosition: _restoreSavedReadingPosition,
    );
  }

  void _handlePageChanged(int? pageNumber) {
    _viewerCoordinator.handlePageChanged(
      pageNumber: pageNumber,
      isMounted: () => mounted,
      sessionController: _sessionController,
      playbackCoordinator: _playbackCoordinator,
      readingProgress: _readingProgress,
      persistReadingProgress: _persistReadingProgress,
      ensureSpeechSegmentsForCurrentPage: _ensureSpeechSegmentsForCurrentPage,
    );
  }

  int? get _highlightedRangesPageNumber => _ttsService.isBusy
      ? _playbackCoordinator.highlightedRangesPageNumber(isTtsBusy: true)
      : _playbackCoordinator.highlightedRangesPageNumber(isTtsBusy: false);

  List<PdfPageTextRange> get _highlightedSentenceRanges => _ttsService.isBusy
      ? _playbackCoordinator.highlightedSentenceRanges(isTtsBusy: true)
      : _playbackCoordinator.highlightedSentenceRanges(isTtsBusy: false);

  int get _highlightedSentenceIndex =>
      _playbackCoordinator.highlightedSentenceIndex(
        isTtsBusy: _ttsService.isBusy,
        selectedSentenceIndex: _sessionController.selectedSentenceIndex,
      );

  Future<List<PdfSpeechSegment>> _ensureSpeechSegmentsForCurrentPage() async {
    final requestedPage = _currentPage;
    final speechSegments = await _playbackCoordinator.loadSpeechSegmentsForPage(
      document: _pdfDocument,
      requestedPage: requestedPage,
    );
    if (!mounted || _currentPage != requestedPage) {
      return speechSegments;
    }

    setState(() {
      _playbackCoordinator.cacheSpeechSegmentsForPage(
        requestedPage: requestedPage,
        speechSegments: speechSegments,
        selectedSentenceIndex: _selectedSentenceIndex,
        onSelectedSentenceIndexChanged: (value) {
          _sessionController.setSelectedSentenceIndex(value);
        },
      );
    });
    return speechSegments;
  }

  void _handleViewerTap(PdfViewerGeneralTapHandlerDetails details) {
    if (details.type != PdfViewerGeneralTapType.tap ||
        details.tapOn == PdfViewerPart.background) {
      return;
    }
    unawaited(_selectSentenceAtDocumentPosition(details.documentPosition));
  }

  Future<void> _selectSentenceAtDocumentPosition(
      Offset documentPosition) async {
    final segments = await _ensureSpeechSegmentsForCurrentPage();
    if (!mounted || segments.isEmpty) {
      return;
    }

    final selectedIndex = sentenceIndexForDocumentPosition(
      documentPosition: documentPosition,
      ranges: segments.map((segment) => segment.range).toList(growable: false),
      controller: _controller,
    );
    if (selectedIndex == null) {
      return;
    }

    setState(() {
      _sessionController.setSelectedSentenceIndex(selectedIndex);
    });
    _invalidatePdfViewerSafely();
  }

  void _handleTtsChanged() {
    if (!mounted) {
      return;
    }
    _playbackSession.handleTtsChanged(
      ttsService: _ttsService,
      playbackCoordinator: _playbackCoordinator,
      karaokeProgressController: _ensureKaraokeProgressController(),
      invalidatePdfViewerSafely: _invalidatePdfViewerSafely,
      autoScrollToActiveSentence: _autoScrollToActiveSentence,
      refreshUi: _refreshUi,
    );
  }

  void _showReaderMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }
    _refreshUi();
  }

  PdfDocument? get _pdfDocument => _sessionController.pdfDocument;
  int? get _selectedSentenceIndex => _sessionController.selectedSentenceIndex;
  int get _currentPage => _sessionController.currentPage;
  int get _pageCount => _sessionController.pageCount;
  bool get _viewerReady => _sessionController.viewerReady;
  bool get _isBottomNavVisible => _sessionController.isBottomNavVisible;
  Offset get _minimizedToolbarOffset =>
      _sessionController.minimizedToolbarOffset;

  String get _zoomLabel {
    if (!_viewerReady) {
      return '--';
    }

    return '${(_controller.currentZoom * 100).round()}%';
  }

  double get _readerTopContentInset {
    return ReaderToolbarLayout.topContentInset(
      isBottomNavVisible: _isBottomNavVisible,
      isSearchVisible: _pdfSearchController.isVisible,
    );
  }

  Offset get _expandedToolbarOffset {
    return ReaderToolbarLayout.expandedToolbarOffset(
      minimizedOffset: _minimizedToolbarOffset,
      topLimit: _expandedToolbarTopLimit,
      bottomLimit: _expandedToolbarBottomLimit,
    );
  }

  Offset _clampedMinimizedToolbarOffset(Offset offset) {
    return ReaderToolbarLayout.clampedMinimizedToolbarOffset(
      offset: offset,
      screenSize: MediaQuery.sizeOf(context),
      topPadding: 8,
      safeAreaTop: MediaQuery.paddingOf(context).top,
      isBottomNavVisible: _isBottomNavVisible,
    );
  }

  double get _expandedToolbarTopLimit {
    return ReaderToolbarLayout.expandedToolbarTopLimit(
      screenSize: MediaQuery.sizeOf(context),
      safeAreaTop: MediaQuery.paddingOf(context).top,
      isBottomNavVisible: _isBottomNavVisible,
      topPadding: 8,
    );
  }

  double get _expandedToolbarBottomLimit {
    return ReaderToolbarLayout.expandedToolbarBottomLimit();
  }

  AnimationController _ensureKaraokeProgressController() {
    return _karaokeProgressController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      value: 0,
    )..addListener(() {
        if (!mounted) {
          return;
        }

        setState(() {});
        _invalidatePdfViewerSafely();
      });
  }

  void _invalidatePdfViewerSafely() {
    if (!_viewerReady || !_controller.isReady) {
      return;
    }
    _controller.invalidate();
  }

  void _refreshUi() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleReaderScrollChanged() {
    if (widget.item == null) {
      return;
    }
    _viewerCoordinator.handleReaderScrollChanged(
      viewerReady: _viewerReady,
      controller: _controller,
      sessionController: _sessionController,
      setBottomNavVisible: _setBottomNavVisible,
    );
  }

  void _setBottomNavVisible(bool visible) {
    final changed = _sessionController.setBottomNavVisible(visible);
    if (changed) {
      widget.onBottomNavVisibilityChanged?.call(visible);
    }
  }

  Future<void> _autoScrollToActiveSentence({bool force = false}) async {
    await _playbackSession.autoScrollToActiveSentence(
      viewerReady: _viewerReady,
      controller: _controller,
      playbackCoordinator: _playbackCoordinator,
      force: force,
    );
  }

  Future<void> _autoScrollToSelectedSentence() async {
    await _playbackSession.autoScrollToSelectedSentence(
      viewerReady: _viewerReady,
      controller: _controller,
      playbackCoordinator: _playbackCoordinator,
      currentPage: _currentPage,
      selectedSentenceIndex: _selectedSentenceIndex,
    );
  }

  Future<void> _restoreSavedReadingPosition() async {
    final restoredPage = await _readingProgress.restoreSavedReadingPosition(
      item: widget.item,
      viewerReady: _viewerReady,
      pageCount: _pageCount,
      currentPage: _currentPage,
      initialPage: widget.initialPage,
      controller: _controller,
    );
    if (!mounted || restoredPage == null) {
      return;
    }
    _sessionController.restoreCurrentPage(restoredPage);
  }

  Future<void> _persistReadingProgress({required int pageNumber}) async {
    final savedItem = await _readingProgress.persistReadingProgress(
      pageNumber: pageNumber,
      item: widget.item,
      repository: widget.repository,
      pageCount: _pageCount,
    );
    if (savedItem != null) {
      widget.onItemUpdated?.call(savedItem);
    }
  }

  bool get _isCurrentPageBookmarked => _bookmarks.any((bookmark) =>
      bookmark.pageNumber == _currentPage &&
      bookmark.sentenceIndex == _bookmarkSentenceIndexForCurrentContext);

  int? get _bookmarkSentenceIndexForCurrentContext {
    if (_ttsService.isBusy &&
        _playbackCoordinator.spokenRangesPageNumber == _currentPage) {
      return _playbackCoordinator.displayedUtteranceIndex;
    }
    if (_selectedSentenceIndex != null &&
        _playbackCoordinator.currentPageSpeechSegmentsPageNumber ==
            _currentPage) {
      return _selectedSentenceIndex;
    }
    return null;
  }

  String get _bookmarkSentenceTextForCurrentContext {
    final sentenceIndex = _bookmarkSentenceIndexForCurrentContext;
    if (sentenceIndex == null) {
      return '';
    }
    if (_ttsService.isBusy &&
        _playbackCoordinator.spokenRangesPageNumber == _currentPage &&
        sentenceIndex >= 0 &&
        sentenceIndex < _playbackCoordinator.spokenSentenceRanges.length) {
      return preparePdfPageTextForSpeech(
          _playbackCoordinator.spokenSentenceRanges[sentenceIndex].text);
    }
    if (_playbackCoordinator.currentPageSpeechSegmentsPageNumber ==
            _currentPage &&
        sentenceIndex >= 0 &&
        sentenceIndex < _playbackCoordinator.currentPageSpeechSegments.length) {
      return _playbackCoordinator.currentPageSpeechSegments[sentenceIndex].text;
    }
    return '';
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _bookmarkCoordinator.loadBookmarks(
      item: widget.item,
      repository: widget.repository,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _bookmarks = bookmarks;
    });
  }

  Future<void> _toggleCurrentPageBookmark() async {
    await _bookmarkFlowCoordinator.toggleCurrentPageBookmark(
      context: context,
      item: widget.item,
      repository: widget.repository,
      viewerReady: _viewerReady,
      currentPage: _currentPage,
      sentenceIndex: _bookmarkSentenceIndexForCurrentContext,
      sentenceText: _bookmarkSentenceTextForCurrentContext,
      currentBookmarks: _bookmarks,
      bookmarkCoordinator: _bookmarkCoordinator,
      ensureSpeechSegmentsForCurrentPage: _ensureSpeechSegmentsForCurrentPage,
      isMounted: () => mounted,
      updateBookmarks: _updateBookmarks,
      showMessage: _showReaderMessage,
    );
  }

  Future<void> _editBookmark(DocumentBookmark bookmark) async {
    await _bookmarkFlowCoordinator.editBookmark(
      context: context,
      repository: widget.repository,
      currentBookmarks: _bookmarks,
      bookmark: bookmark,
      bookmarkCoordinator: _bookmarkCoordinator,
      isMounted: () => mounted,
      updateBookmarks: _updateBookmarks,
      showMessage: _showReaderMessage,
    );
  }

  void _updateBookmarks(List<DocumentBookmark> bookmarks) {
    if (!mounted) {
      return;
    }
    setState(() {
      _bookmarks = bookmarks;
    });
  }

  Future<void> _showBookmarksSheet() async {
    await _bookmarkSheetCoordinator.showBookmarksSheet(
      context: context,
      currentPage: _currentPage,
      currentSentenceIndex: _bookmarkSentenceIndexForCurrentContext,
      getBookmarks: () => _bookmarks,
      onToggleCurrentPage: _toggleCurrentPageBookmark,
      onOpenBookmark: _openBookmark,
      onRemoveBookmark: _removeBookmarkFromSheet,
      onEditBookmark: _editBookmark,
    );
  }

  Future<void> _openBookmark(DocumentBookmark bookmark) async {
    await _bookmarkSheetCoordinator.openBookmark(
      bookmark: bookmark,
      isMounted: () => mounted,
      controller: _controller,
      sessionController: _sessionController,
      ensureSpeechSegmentsForCurrentPage: _ensureSpeechSegmentsForCurrentPage,
      invalidatePdfViewerSafely: _invalidatePdfViewerSafely,
      autoScrollToSelectedSentence: _autoScrollToSelectedSentence,
    );
  }

  Future<List<DocumentBookmark>> _removeBookmarkFromSheet(
    DocumentBookmark bookmark,
  ) async {
    final updatedBookmarks = await _bookmarkCoordinator.removeBookmark(
      repository: widget.repository,
      currentBookmarks: _bookmarks,
      bookmark: bookmark,
    );
    if (!mounted) {
      return _bookmarks;
    }

    _updateBookmarks(updatedBookmarks);
    return updatedBookmarks;
  }

  Future<void> _showPageSummarySheet() async {
    await _aiCoordinator.showPageSummarySheet(
      context: context,
      item: widget.item,
      repository: widget.repository,
      viewerReady: _viewerReady,
      hasPdfDocument: _pdfDocument != null,
      currentPage: _currentPage,
      loadCurrentPageText: () async {
        final segments = await _ensureSpeechSegmentsForCurrentPage();
        if (!mounted) {
          return '';
        }

        return segments
            .map((segment) => segment.text.trim())
            .where((text) => text.isNotEmpty)
            .join(' ');
      },
      loadOutlineTitle: _outlineTitleForPage,
      aiModelService: _aiModelService,
      showMessage: _showReaderMessage,
    );
  }

  Future<void> _showReaderAiActionsSheet() async {
    await _aiCoordinator.showReaderAiActionsSheet(
      context: context,
      item: widget.item,
      repository: widget.repository,
      selectedSentenceText: _bookmarkSentenceTextForCurrentContext,
      onSummarizePage: _showPageSummarySheet,
      onExplainSentence: _showSentenceExplanationSheet,
      openNotebookSheet: _showDocumentNotebookSheet,
      aiModelService: _aiModelService,
    );
  }

  Future<void> _showDocumentNotebookSheet(LibraryItem item) async {
    await _notebookCoordinator.showDocumentNotebookSheet(
      context: context,
      item: item,
      repository: widget.repository,
      onOpenNote: _openDocumentNote,
    );
  }

  void _clearSearchMatchOnly() {
    _sessionController.clearSearchMatchRange();
  }

  void _updateReaderSelection(int currentPage, int? selectedSentenceIndex) {
    if (!mounted) {
      return;
    }
    _sessionController.updateReaderSelection(
        currentPage, selectedSentenceIndex);
  }

  void _clearCurrentPageSpeechSegments() {
    if (!mounted) {
      return;
    }
    setState(() {
      _playbackCoordinator.clearCurrentPageSpeechSegments();
    });
  }

  Future<void> _autoScrollToSelectedSentenceAsync() async {
    await _autoScrollToSelectedSentence();
  }

  Future<void> _ensureSpeechSegmentsForCurrentPageAsync() async {
    await _ensureSpeechSegmentsForCurrentPage();
  }

  Future<void> _openDocumentNote(DocumentNote note) async {
    final opened = await _notebookCoordinator.openDocumentNote(
      note: note,
      viewerReady: _viewerReady,
      controller: _controller,
      clearSearchMatch: _clearSearchMatchOnly,
      clearCurrentPageSpeechSegments: _clearCurrentPageSpeechSegments,
      updateReaderSelection: _updateReaderSelection,
      ensureSpeechSegmentsForCurrentPage:
          _ensureSpeechSegmentsForCurrentPageAsync,
      invalidatePdfViewerSafely: _invalidatePdfViewerSafely,
      autoScrollToSelectedSentence: _autoScrollToSelectedSentenceAsync,
    );
    if (!opened || !mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _showSentenceExplanationSheet(String sentenceText) async {
    await _aiCoordinator.showSentenceExplanationSheet(
      context: context,
      sentenceText: sentenceText,
      item: widget.item,
      repository: widget.repository,
      currentPage: _currentPage,
      sentenceIndex: _bookmarkSentenceIndexForCurrentContext,
      loadOutlineTitle: _outlineTitleForPage,
      aiModelService: _aiModelService,
      showMessage: _showReaderMessage,
    );
  }

  void _showInlinePdfSearch() {
    _pdfSearchController.show();
  }

  void _closeInlinePdfSearch() {
    _pdfSearchController.close(
      onCleared: () {
        if (!mounted) {
          return;
        }
        _sessionController.clearSearchMatchRange();
        _invalidatePdfViewerSafely();
      },
    );
  }

  void _clearSearchMatch() {
    if (!mounted) {
      return;
    }
    _sessionController.clearSearchMatchRange();
    _invalidatePdfViewerSafely();
  }

  void _scheduleInlinePdfSearch(String query) {
    _pdfSearchController.scheduleSearch(
      query,
      search: _searchPdf,
      openResult: _openSearchResult,
      onCleared: _clearSearchMatch,
    );
  }

  Future<void> _runInlinePdfSearch(String query) async {
    await _pdfSearchController.runSearch(
      query,
      search: _searchPdf,
      openResult: _openSearchResult,
      onCleared: _clearSearchMatch,
    );
  }

  Future<void> _goToPreviousPdfSearchResult() async {
    await _pdfSearchController.openPrevious(
      openResult: _openSearchResult,
    );
  }

  Future<void> _goToNextPdfSearchResult() async {
    await _pdfSearchController.openNext(
      openResult: _openSearchResult,
    );
  }

  Future<void> _showPdfOutlineSheet() async {
    await _outlineSheetCoordinator.showPdfOutlineSheet(
      context: context,
      viewerReady: _viewerReady,
      pdfDocument: _pdfDocument,
      documentTitle: widget.item?.title ?? 'Current document',
      documentFileName: widget.item?.fileName ?? '',
      collapsedOutlineIndexes: _collapsedOutlineIndexes,
      loadPdfOutlineEntries: _loadPdfOutlineEntries,
      openOutlineEntry: _openOutlineEntry,
      showMessage: _showReaderMessage,
    );
  }

  Future<List<PdfOutlineEntry>> _loadPdfOutlineEntries() async {
    return _outlineCoordinator.loadOutlineEntries(
      document: _pdfDocument,
      pageCount: _pageCount,
    );
  }

  Future<String> _outlineTitleForPage(int pageNumber) async {
    return _outlineCoordinator.outlineTitleForPage(
      pageNumber: pageNumber,
      document: _pdfDocument,
      pageCount: _pageCount,
    );
  }

  Future<void> _openOutlineEntry(PdfOutlineEntry entry) async {
    await _outlineSheetCoordinator.openOutlineEntry(
      entry: entry,
      viewerReady: _viewerReady,
      controller: _controller,
      sessionController: _sessionController,
      invalidatePdfViewerSafely: _invalidatePdfViewerSafely,
    );
  }

  Future<List<PdfSearchResult>> _searchPdf(String query) async {
    return _searchCoordinator.searchPdf(
      document: _pdfDocument,
      pageCount: _pageCount,
      query: query,
    );
  }

  Future<void> _openSearchResult(
    PdfSearchResult result, {
    bool updateSearchIndex = true,
  }) async {
    await _searchCoordinator.openSearchResult(
      result: result,
      viewerReady: _viewerReady,
      controller: _controller,
      pdfSearchController: _pdfSearchController,
      sessionController: _sessionController,
      ensureSpeechSegmentsForCurrentPage: _ensureSpeechSegmentsForCurrentPage,
      invalidatePdfViewerSafely: _invalidatePdfViewerSafely,
      autoScrollToSelectedSentence: _autoScrollToSelectedSentence,
      updateSearchIndex: updateSearchIndex,
    );
    if (!mounted) {
      return;
    }
  }

  Future<void> _goToPreviousPage() async {
    if (!_viewerReady || _currentPage <= 1) {
      return;
    }

    await _controller.goToPage(pageNumber: _currentPage - 1);
  }

  Future<void> _goToNextPage() async {
    if (!_viewerReady || (_pageCount > 0 && _currentPage >= _pageCount)) {
      return;
    }

    await _controller.goToPage(pageNumber: _currentPage + 1);
  }

  Future<void> _zoomIn() async {
    if (!_viewerReady) {
      return;
    }

    await _controller.zoomUp(loop: false);
    setState(() {});
  }

  Future<void> _zoomOut() async {
    if (!_viewerReady) {
      return;
    }

    await _controller.zoomDown(loop: false);
    setState(() {});
  }

  Future<void> _fitPage() async {
    if (!_viewerReady) {
      return;
    }

    await _controller.goTo(
      _controller.calcMatrixForFit(pageNumber: _currentPage),
    );
    setState(() {});
  }
}
