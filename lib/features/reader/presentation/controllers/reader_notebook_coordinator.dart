import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../../notebook/domain/document_note.dart';
import '../../../notebook/presentation/document_notebook_sheet.dart';

class ReaderNotebookCoordinator {
  const ReaderNotebookCoordinator();

  Future<void> showDocumentNotebookSheet({
    required BuildContext context,
    required LibraryItem item,
    required LibraryRepository? repository,
    required Future<void> Function(DocumentNote note) onOpenNote,
  }) async {
    if (repository == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DocumentNotebookSheet(
          item: item,
          repository: repository,
          onOpenNote: (note) async {
            Navigator.of(context).pop();
            await onOpenNote(note);
          },
        );
      },
    );
  }

  Future<bool> openDocumentNote({
    required DocumentNote note,
    required bool viewerReady,
    required PdfViewerController controller,
    required VoidCallback clearSearchMatch,
    required VoidCallback clearCurrentPageSpeechSegments,
    required void Function(int currentPage, int? selectedSentenceIndex)
        updateReaderSelection,
    required Future<void> Function() ensureSpeechSegmentsForCurrentPage,
    required VoidCallback invalidatePdfViewerSafely,
    required Future<void> Function() autoScrollToSelectedSentence,
  }) async {
    if (!viewerReady) {
      return false;
    }

    clearSearchMatch();
    await controller.goToPage(pageNumber: note.pageNumber);

    clearCurrentPageSpeechSegments();
    updateReaderSelection(note.pageNumber, note.sentenceIndex);

    if (note.sentenceIndex != null) {
      await ensureSpeechSegmentsForCurrentPage();
      invalidatePdfViewerSafely();
      await autoScrollToSelectedSentence();
    }

    return true;
  }
}
