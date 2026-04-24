import 'package:flutter/material.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../../notebook/domain/document_note.dart';
import '../../../offline_ai/data/offline_ai_inference_service.dart';
import '../../../offline_ai/data/offline_ai_model_service.dart';
import '../../../offline_ai/presentation/ai_sheets.dart';

typedef ReaderOutlineTitleLoader = Future<String> Function(int pageNumber);
typedef ReaderNotebookSheetOpener = Future<void> Function(LibraryItem item);
typedef ReaderPageTextLoader = Future<String> Function();
typedef ReaderMessageCallback = void Function(String message);

class ReaderAiCoordinator {
  const ReaderAiCoordinator();

  Future<void> showPageSummarySheet({
    required BuildContext context,
    required LibraryItem? item,
    required LibraryRepository? repository,
    required bool viewerReady,
    required bool hasPdfDocument,
    required int currentPage,
    required ReaderPageTextLoader loadCurrentPageText,
    required ReaderOutlineTitleLoader loadOutlineTitle,
    required OfflineAiModelService aiModelService,
    required ReaderMessageCallback showMessage,
  }) async {
    if (item == null || !viewerReady || !hasPdfDocument) {
      showMessage('The PDF is still loading. Try again in a moment.');
      return;
    }

    final pageText = await loadCurrentPageText();
    if (pageText.trim().isEmpty) {
      showMessage(
        'No readable text was found on page $currentPage. This page may be scanned as an image.',
      );
      return;
    }

    await aiModelService.ensureInitialized();

    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PageSummarySheet(
          item: item,
          repository: repository,
          pageNumber: currentPage,
          pageText: pageText,
          outlineTitleFuture: loadOutlineTitle(currentPage),
          aiModelState: aiModelService.state,
        );
      },
    );
  }

  Future<void> showReaderAiActionsSheet({
    required BuildContext context,
    required LibraryItem? item,
    required LibraryRepository? repository,
    required String selectedSentenceText,
    required Future<void> Function() onSummarizePage,
    required Future<void> Function(String sentenceText) onExplainSentence,
    required ReaderNotebookSheetOpener openNotebookSheet,
    required OfflineAiModelService aiModelService,
  }) async {
    await aiModelService.ensureInitialized();

    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ReaderAiActionsSheet(
          hasSelectedSentence: selectedSentenceText.isNotEmpty,
          isModelReady: aiModelService.state.isReady,
          hasNotebook: item != null && repository != null,
          onSummarizePage: () async {
            Navigator.of(context).pop();
            await onSummarizePage();
          },
          onExplainSentence: () async {
            Navigator.of(context).pop();
            await onExplainSentence(selectedSentenceText);
          },
          onOpenNotebook: item == null || repository == null
              ? null
              : () async {
                  Navigator.of(context).pop();
                  await openNotebookSheet(item);
                },
        );
      },
    );
  }

  Future<void> showSentenceExplanationSheet({
    required BuildContext context,
    required String sentenceText,
    required LibraryItem? item,
    required LibraryRepository? repository,
    required int currentPage,
    required int? sentenceIndex,
    required ReaderOutlineTitleLoader loadOutlineTitle,
    required OfflineAiModelService aiModelService,
    required ReaderMessageCallback showMessage,
  }) async {
    if (sentenceText.trim().isEmpty) {
      showMessage('Tap a sentence first, then ask Lectio to explain it.');
      return;
    }

    await aiModelService.ensureInitialized();

    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AiStreamingResponseSheet(
          title: 'Sentence explanation',
          readyLabel: '${aiModelService.state.selectedModel.name} ready',
          loadingLabel: 'Explaining offline...',
          writingTitle: 'Explanation is writing...',
          doneTitle: 'Explanation',
          icon: Icons.psychology_alt_rounded,
          item: item,
          repository: repository,
          noteKind: DocumentNoteKind.explanation,
          pageNumber: currentPage,
          sentenceIndex: sentenceIndex,
          sentenceText: sentenceText,
          outlineTitleFuture: loadOutlineTitle(currentPage),
          aiModelState: aiModelService.state,
          streamBuilder: (modelState) =>
              OfflineAiInferenceService.instance.streamSentenceExplanation(
            modelState: modelState,
            sentenceText: sentenceText,
          ),
        );
      },
    );
  }
}
