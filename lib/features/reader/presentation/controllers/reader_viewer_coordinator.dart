import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'reader_playback_coordinator.dart';
import 'reader_progress_coordinator.dart';
import 'reader_session_controller.dart';

class ReaderViewerCoordinator {
  const ReaderViewerCoordinator();

  void handleViewerReady({
    required PdfDocument document,
    required PdfViewerController controller,
    required bool Function() isMounted,
    required ReaderSessionController sessionController,
    required Future<void> Function() loadBookmarks,
    required Future<void> Function() restoreSavedReadingPosition,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) {
        return;
      }

      sessionController.setViewerReady(
        document: document,
        pageCount: controller.pageCount,
        currentPage: controller.pageNumber ?? 1,
      );
      unawaited(loadBookmarks());
      unawaited(restoreSavedReadingPosition());
    });
  }

  void handlePageChanged({
    required int? pageNumber,
    required bool Function() isMounted,
    required ReaderSessionController sessionController,
    required ReaderPlaybackCoordinator playbackCoordinator,
    required ReaderProgressCoordinator readingProgress,
    required Future<void> Function({required int pageNumber})
        persistReadingProgress,
    required Future<void> Function() ensureSpeechSegmentsForCurrentPage,
  }) {
    if (pageNumber == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) {
        return;
      }

      sessionController.clearCurrentPageSelection(currentPage: pageNumber);
      playbackCoordinator.clearCurrentPageSpeechSegments();
      if (!readingProgress.isRestoringSavedPage) {
        unawaited(persistReadingProgress(pageNumber: pageNumber));
      }
      unawaited(ensureSpeechSegmentsForCurrentPage());
    });
  }

  void handleReaderScrollChanged({
    required bool viewerReady,
    required PdfViewerController controller,
    required ReaderSessionController sessionController,
    required void Function(bool visible) setBottomNavVisible,
  }) {
    if (!viewerReady || !controller.isReady) {
      return;
    }

    final visibleTop = controller.visibleRect.top;
    final previousTop = sessionController.updateVisibleRectTop(visibleTop);
    if (previousTop == null) {
      return;
    }

    final delta = visibleTop - previousTop;
    const threshold = 14.0;
    if (delta > threshold) {
      setBottomNavVisible(false);
    } else if (delta < -threshold) {
      setBottomNavVisible(true);
    }
  }
}
