import 'package:flutter/foundation.dart';

import '../../features/library/domain/library_item.dart';

class AppShellState {
  const AppShellState({
    this.selectedIndex = 0,
    this.selectedItem,
    this.initialReaderPage,
    this.isBottomNavVisible = true,
  });

  final int selectedIndex;
  final LibraryItem? selectedItem;
  final int? initialReaderPage;
  final bool isBottomNavVisible;

  AppShellState copyWith({
    int? selectedIndex,
    LibraryItem? selectedItem,
    bool clearSelectedItem = false,
    int? initialReaderPage,
    bool clearInitialReaderPage = false,
    bool? isBottomNavVisible,
  }) {
    return AppShellState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      selectedItem:
          clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
      initialReaderPage: clearInitialReaderPage
          ? null
          : (initialReaderPage ?? this.initialReaderPage),
      isBottomNavVisible: isBottomNavVisible ?? this.isBottomNavVisible,
    );
  }
}

class AppShellController extends ChangeNotifier {
  AppShellState _state = const AppShellState();

  AppShellState get state => _state;

  void openReaderFor(LibraryItem item, {int? initialPage}) {
    _state = _state.copyWith(
      selectedIndex: 1,
      selectedItem: item,
      initialReaderPage: initialPage,
      clearInitialReaderPage: initialPage == null,
      isBottomNavVisible: true,
    );
    notifyListeners();
  }

  void updateSelectedItem(LibraryItem item) {
    _state = _state.copyWith(selectedItem: item);
    notifyListeners();
  }

  void setBottomNavVisible(bool visible) {
    if (_state.selectedIndex != 1 || _state.isBottomNavVisible == visible) {
      return;
    }

    _state = _state.copyWith(isBottomNavVisible: visible);
    notifyListeners();
  }

  void selectIndex(int index) {
    _state = _state.copyWith(
      selectedIndex: index,
      isBottomNavVisible: true,
      clearInitialReaderPage: index != 1,
    );
    notifyListeners();
  }
}
