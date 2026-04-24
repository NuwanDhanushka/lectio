import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ReaderSessionController extends ChangeNotifier {
  PdfDocument? _pdfDocument;
  PdfPageTextRange? _searchMatchRange;
  int? _selectedSentenceIndex;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _viewerReady = false;
  bool _toolbarMinimized = false;
  double? _lastVisibleRectTop;
  bool _isBottomNavVisible = true;
  Offset _minimizedToolbarOffset = Offset.zero;

  PdfDocument? get pdfDocument => _pdfDocument;
  PdfPageTextRange? get searchMatchRange => _searchMatchRange;
  int? get selectedSentenceIndex => _selectedSentenceIndex;
  int get currentPage => _currentPage;
  int get pageCount => _pageCount;
  bool get viewerReady => _viewerReady;
  bool get toolbarMinimized => _toolbarMinimized;
  double? get lastVisibleRectTop => _lastVisibleRectTop;
  bool get isBottomNavVisible => _isBottomNavVisible;
  Offset get minimizedToolbarOffset => _minimizedToolbarOffset;

  void resetForDocumentChange() {
    _pdfDocument = null;
    _searchMatchRange = null;
    _selectedSentenceIndex = null;
    _currentPage = 1;
    _pageCount = 0;
    _viewerReady = false;
    _lastVisibleRectTop = null;
    _isBottomNavVisible = true;
    notifyListeners();
  }

  void setViewerReady({
    required PdfDocument document,
    required int pageCount,
    required int currentPage,
  }) {
    _pdfDocument = document;
    _viewerReady = true;
    _pageCount = pageCount;
    _currentPage = currentPage;
    notifyListeners();
  }

  void clearCurrentPageSelection({required int currentPage}) {
    _currentPage = currentPage;
    _selectedSentenceIndex = null;
    notifyListeners();
  }

  void restoreCurrentPage(int pageNumber) {
    _currentPage = pageNumber;
    notifyListeners();
  }

  void setCurrentPage(int pageNumber) {
    _currentPage = pageNumber;
    notifyListeners();
  }

  void setSelectedSentenceIndex(int? index) {
    _selectedSentenceIndex = index;
    notifyListeners();
  }

  void setSearchMatchRange(PdfPageTextRange? range) {
    _searchMatchRange = range;
    notifyListeners();
  }

  void clearSearchMatchRange() {
    _searchMatchRange = null;
    notifyListeners();
  }

  void updateReaderSelection(int currentPage, int? selectedSentenceIndex) {
    _currentPage = currentPage;
    _selectedSentenceIndex = selectedSentenceIndex;
    notifyListeners();
  }

  double? updateVisibleRectTop(double visibleTop) {
    final previousTop = _lastVisibleRectTop;
    _lastVisibleRectTop = visibleTop;
    return previousTop;
  }

  bool setBottomNavVisible(bool visible) {
    if (_isBottomNavVisible == visible) {
      return false;
    }
    _isBottomNavVisible = visible;
    notifyListeners();
    return true;
  }

  void toggleToolbarMinimized() {
    _toolbarMinimized = !_toolbarMinimized;
    notifyListeners();
  }

  void setMinimizedToolbarOffset(Offset offset) {
    _minimizedToolbarOffset = offset;
    notifyListeners();
  }
}
