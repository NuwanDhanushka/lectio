import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../library/domain/library_item.dart';
import '../../../tts/presentation/controllers/sherpa_tts_service.dart';
import '../../domain/reader_page_analysis.dart';
import 'reader_playback_coordinator.dart';
import 'reader_session_controller.dart';

typedef ReaderMessageCallback = void Function(String message);
typedef ReaderUiRefreshCallback = void Function();
typedef ReaderInvalidateCallback = void Function();
typedef ReaderSpeechSegmentsLoader = Future<List<PdfSpeechSegment>> Function();

class ReaderPlaybackSession {
  const ReaderPlaybackSession();

  Future<void> speakCurrentContext({
    required LibraryItem document,
    required SherpaTtsService ttsService,
    required ReaderSessionController sessionController,
    required ReaderPlaybackCoordinator playbackCoordinator,
    required ReaderSpeechSegmentsLoader ensureSpeechSegmentsForCurrentPage,
    required AnimationController karaokeProgressController,
    required ReaderInvalidateCallback invalidatePdfViewerSafely,
    required Future<void> Function({bool force}) autoScrollToActiveSentence,
    required ReaderMessageCallback showMessage,
    required ReaderUiRefreshCallback refreshUi,
  }) async {
    if (!sessionController.viewerReady ||
        !document.isPdf ||
        sessionController.pdfDocument == null) {
      showMessage('The PDF is still loading. Try again in a moment.');
      return;
    }

    playbackCoordinator.markPreparingPlayback();
    refreshUi();

    try {
      final speechSegments = await ensureSpeechSegmentsForCurrentPage();
      if (speechSegments.isEmpty) {
        showMessage(
          'No readable text was found on page ${sessionController.currentPage}. This page may be scanned as an image.',
        );
        return;
      }

      final playbackSegments =
          playbackCoordinator.playbackSegmentsForCurrentPage(
        currentPage: sessionController.currentPage,
        selectedSentenceIndex: sessionController.selectedSentenceIndex,
      );
      playbackCoordinator.beginPlayback(
        currentPage: sessionController.currentPage,
        playbackSegments: playbackSegments,
      );
      refreshUi();

      karaokeProgressController.value = 0;
      invalidatePdfViewerSafely();
      unawaited(autoScrollToActiveSentence(force: true));

      await ttsService.speakSegments(
        playbackSegments.map((segment) => segment.text).toList(growable: false),
      );
    } catch (_) {
      showMessage(
          'Could not read text from page ${sessionController.currentPage}.');
      playbackCoordinator.clearPreparingPlayback();
      refreshUi();
    }
  }

  void handleTtsChanged({
    required SherpaTtsService ttsService,
    required ReaderPlaybackCoordinator playbackCoordinator,
    required AnimationController karaokeProgressController,
    required ReaderInvalidateCallback invalidatePdfViewerSafely,
    required Future<void> Function({bool force}) autoScrollToActiveSentence,
    required ReaderUiRefreshCallback refreshUi,
  }) {
    if (playbackCoordinator.finishPlaybackIfIdle(isBusy: ttsService.isBusy)) {
      karaokeProgressController.stop();
      refreshUi();
      karaokeProgressController.value = 0;
      invalidatePdfViewerSafely();
      return;
    }

    if (playbackCoordinator.syncCurrentUtteranceIndex(
      ttsService.currentUtteranceIndex,
    )) {
      karaokeProgressController.value = 0;
      if (ttsService.status == SherpaTtsStatus.playing) {
        unawaited(autoScrollToActiveSentence(force: false));
      }
    }

    karaokeProgressController.animateTo(
      ttsService.currentUtteranceProgress,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );

    playbackCoordinator.syncPlaybackStatus(
      shouldClearPreparing: ttsService.status == SherpaTtsStatus.playing ||
          ttsService.status == SherpaTtsStatus.paused ||
          ttsService.status == SherpaTtsStatus.error,
    );
    refreshUi();
    invalidatePdfViewerSafely();
  }

  Future<void> autoScrollToActiveSentence({
    required bool viewerReady,
    required PdfViewerController controller,
    required ReaderPlaybackCoordinator playbackCoordinator,
    bool force = false,
  }) async {
    if (!viewerReady ||
        !controller.isReady ||
        !playbackCoordinator.shouldAutoScrollToActiveSentence(force: force)) {
      return;
    }

    final activeRange = playbackCoordinator.activePlaybackRange();
    if (activeRange == null) {
      return;
    }

    final documentRect = documentRectForTextRange(
      range: activeRange,
      controller: controller,
    );
    if (documentRect == null) {
      return;
    }

    final visibleRect = controller.visibleRect;
    final needsScroll = force ||
        !visibleRect.contains(documentRect.topLeft) ||
        !visibleRect.contains(documentRect.bottomRight);
    if (!needsScroll) {
      playbackCoordinator.markAutoScrolledToCurrentUtterance();
      return;
    }

    playbackCoordinator.markAutoScrolledToCurrentUtterance();
    await controller.ensureVisible(
      documentRect,
      duration: const Duration(milliseconds: 260),
      margin: 56,
    );
  }

  Future<void> autoScrollToSelectedSentence({
    required bool viewerReady,
    required PdfViewerController controller,
    required ReaderPlaybackCoordinator playbackCoordinator,
    required int currentPage,
    required int? selectedSentenceIndex,
  }) async {
    if (!viewerReady ||
        !controller.isReady ||
        playbackCoordinator.currentPageSpeechSegmentsPageNumber !=
            currentPage ||
        selectedSentenceIndex == null ||
        selectedSentenceIndex < 0 ||
        selectedSentenceIndex >=
            playbackCoordinator.currentPageSpeechSegments.length) {
      return;
    }

    final selectedRange = playbackCoordinator
        .currentPageSpeechSegments[selectedSentenceIndex].range;
    final documentRect = documentRectForTextRange(
      range: selectedRange,
      controller: controller,
    );
    if (documentRect == null) {
      return;
    }

    await controller.ensureVisible(
      documentRect,
      duration: const Duration(milliseconds: 260),
      margin: 56,
    );
  }
}
