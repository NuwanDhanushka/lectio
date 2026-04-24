import 'package:flutter/material.dart';

class ReaderToolbarLayout {
  const ReaderToolbarLayout._();

  static double topContentInset({
    required bool isBottomNavVisible,
    required bool isSearchVisible,
  }) {
    final baseHeight = isBottomNavVisible ? 92.0 : 50.0;
    return baseHeight + (isSearchVisible ? 62.0 : 0.0);
  }

  static Offset expandedToolbarOffset({
    required Offset minimizedOffset,
    required double topLimit,
    required double bottomLimit,
  }) {
    if (minimizedOffset == Offset.zero) {
      return Offset.zero;
    }

    return Offset(
      0,
      minimizedOffset.dy.clamp(topLimit, bottomLimit),
    );
  }

  static Offset clampedMinimizedToolbarOffset({
    required Offset offset,
    required Size screenSize,
    required double topPadding,
    required double safeAreaTop,
    required bool isBottomNavVisible,
  }) {
    final appBarHeight = isBottomNavVisible ? 72.0 : 34.0;
    final bodyHeight = screenSize.height - safeAreaTop - appBarHeight;
    const toolbarBottom = 176.0;
    const minimizedPillHeight = 46.0;
    final initialPillTop = bodyHeight - toolbarBottom - minimizedPillHeight;
    final topLimit = -initialPillTop + topPadding;
    const audioControllerTopOffset = 170.0;
    const bottomLimit = audioControllerTopOffset - toolbarBottom;
    final leftLimit = -(screenSize.width - 112);
    const rightLimit = 0.0;

    return Offset(
      offset.dx.clamp(leftLimit, rightLimit),
      offset.dy.clamp(topLimit, bottomLimit),
    );
  }

  static double expandedToolbarTopLimit({
    required Size screenSize,
    required double safeAreaTop,
    required bool isBottomNavVisible,
    required double topPadding,
  }) {
    final appBarHeight = isBottomNavVisible ? 72.0 : 34.0;
    final bodyHeight = screenSize.height - safeAreaTop - appBarHeight;
    const toolbarBottom = 176.0;
    const expandedToolbarHeight = 70.0;
    final initialToolbarTop =
        bodyHeight - toolbarBottom - expandedToolbarHeight;
    return -initialToolbarTop + topPadding;
  }

  static double expandedToolbarBottomLimit() {
    const toolbarBottom = 176.0;
    const audioControllerTopOffset = 170.0;
    return audioControllerTopOffset - toolbarBottom;
  }
}
