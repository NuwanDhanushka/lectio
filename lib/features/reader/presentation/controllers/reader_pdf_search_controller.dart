import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/reader_page_analysis.dart';

typedef ReaderPdfSearchRunner = Future<List<PdfSearchResult>> Function(
  String query,
);
typedef ReaderPdfSearchOpener = Future<void> Function(
  PdfSearchResult result, {
  bool updateSearchIndex,
});

class ReaderPdfSearchController extends ChangeNotifier {
  ReaderPdfSearchController();

  final TextEditingController textController = TextEditingController();

  Timer? _debounce;
  List<PdfSearchResult> _results = const [];
  int _activeResultIndex = -1;
  bool _isVisible = false;
  bool _isSearching = false;

  List<PdfSearchResult> get results => _results;
  int get activeResultIndex => _activeResultIndex;
  bool get isVisible => _isVisible;
  bool get isSearching => _isSearching;

  void reset() {
    _debounce?.cancel();
    _results = const [];
    _activeResultIndex = -1;
    _isVisible = false;
    _isSearching = false;
    textController.clear();
    notifyListeners();
  }

  void show() {
    if (_isVisible) {
      return;
    }
    _isVisible = true;
    notifyListeners();
  }

  void close({VoidCallback? onCleared}) {
    _debounce?.cancel();
    _isVisible = false;
    _isSearching = false;
    _results = const [];
    _activeResultIndex = -1;
    textController.clear();
    notifyListeners();
    onCleared?.call();
  }

  void scheduleSearch(
    String query, {
    required ReaderPdfSearchRunner search,
    required ReaderPdfSearchOpener openResult,
    VoidCallback? onCleared,
  }) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(
        runSearch(
          query,
          search: search,
          openResult: openResult,
          onCleared: onCleared,
        ),
      );
    });
  }

  Future<void> runSearch(
    String query, {
    required ReaderPdfSearchRunner search,
    required ReaderPdfSearchOpener openResult,
    VoidCallback? onCleared,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      _results = const [];
      _activeResultIndex = -1;
      _isSearching = false;
      notifyListeners();
      onCleared?.call();
      return;
    }

    _isSearching = true;
    notifyListeners();

    final results = await search(normalizedQuery);
    if (textController.text.trim() != normalizedQuery) {
      return;
    }

    _results = results;
    _activeResultIndex = results.isEmpty ? -1 : 0;
    _isSearching = false;
    notifyListeners();

    if (results.isNotEmpty) {
      await openResult(results.first, updateSearchIndex: false);
    } else {
      onCleared?.call();
    }
  }

  Future<void> openPrevious({
    required ReaderPdfSearchOpener openResult,
  }) async {
    if (_results.isEmpty) {
      return;
    }

    final nextIndex = _activeResultIndex <= 0
        ? _results.length - 1
        : _activeResultIndex - 1;
    _activeResultIndex = nextIndex;
    notifyListeners();
    await openResult(_results[nextIndex], updateSearchIndex: false);
  }

  Future<void> openNext({
    required ReaderPdfSearchOpener openResult,
  }) async {
    if (_results.isEmpty) {
      return;
    }

    final nextIndex = (_activeResultIndex + 1) % _results.length;
    _activeResultIndex = nextIndex;
    notifyListeners();
    await openResult(_results[nextIndex], updateSearchIndex: false);
  }

  void syncActiveResult(PdfSearchResult result) {
    final index = _results.indexWhere(
      (candidate) =>
          candidate.pageNumber == result.pageNumber &&
          candidate.sentenceIndex == result.sentenceIndex &&
          candidate.query == result.query,
    );
    if (index < 0 || index == _activeResultIndex) {
      return;
    }
    _activeResultIndex = index;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    textController.dispose();
    super.dispose();
  }
}
