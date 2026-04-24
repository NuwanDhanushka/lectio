import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/document_note.dart';
import '../document_note_presenter.dart';

enum NotebookExportFormat { pdf, docx }

class NotebookHeader extends StatelessWidget {
  const NotebookHeader({
    super.key,
    required this.canExport,
    required this.isExporting,
    required this.onExport,
    required this.onClose,
  });

  final bool canExport;
  final bool isExporting;
  final ValueChanged<NotebookExportFormat> onExport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F2A56), Color(0xFF5368E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.menu_book_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notebook',
                style: TextStyle(
                  color: Color(0xFF202430),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Saved notes for this book.',
                style: TextStyle(
                  color: Color(0xFF6F7585),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (isExporting)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          PopupMenuButton<NotebookExportFormat>(
            enabled: canExport,
            tooltip: 'Export notebook',
            icon: const Icon(Icons.ios_share_rounded),
            color: Colors.white,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFDCE2F0)),
            ),
            onSelected: onExport,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: NotebookExportFormat.pdf,
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded),
                    SizedBox(width: 10),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: NotebookExportFormat.docx,
                child: Row(
                  children: [
                    Icon(Icons.description_rounded),
                    SizedBox(width: 10),
                    Text('Export as DOCX'),
                  ],
                ),
              ),
            ],
          ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Close notebook',
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class NotebookNotesList extends StatelessWidget {
  const NotebookNotesList({
    super.key,
    required this.isLoading,
    required this.notes,
    required this.filteredNotes,
    required this.onOpenDetails,
  });

  final bool isLoading;
  final List<DocumentNote> notes;
  final List<DocumentNote> filteredNotes;
  final Future<void> Function(DocumentNote note) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const NotebookLoadingCard(label: 'Opening notebook...');
    }
    if (notes.isEmpty) {
      return const NotebookEmptyState();
    }
    if (filteredNotes.isEmpty) {
      return const NotebookEmptyState(
        message: 'No notes match this filter yet.',
      );
    }

    final groups = groupedDocumentNotes(filteredNotes);
    return RawScrollbar(
      thumbVisibility: true,
      radius: const Radius.circular(999),
      thickness: 3,
      thumbColor: const Color(0xFFB8BECC).withValues(alpha: 0.7),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, groupIndex) {
          final group = groups[groupIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.title,
                style: const TextStyle(
                  color: Color(0xFF6F7585),
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final note in group.notes) ...[
                NotebookNoteCard(
                  note: note,
                  onTap: () => onOpenDetails(note),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class NotebookEmptyState extends StatelessWidget {
  const NotebookEmptyState({
    super.key,
    this.message =
        'Save AI summaries or explanations to build this book notebook.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE2F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.note_add_outlined,
            color: Color(0xFF5368E8),
            size: 30,
          ),
          const SizedBox(height: 10),
          const Text(
            'No notes yet',
            style: TextStyle(
              color: Color(0xFF202430),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6F7585),
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class NotebookFilterRow extends StatelessWidget {
  const NotebookFilterRow({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final DocumentNoteKind? activeFilter;
  final ValueChanged<DocumentNoteKind?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <({String label, DocumentNoteKind? kind})>[
      (label: 'All', kind: null),
      (label: 'Summaries', kind: DocumentNoteKind.summary),
      (label: 'Explanations', kind: DocumentNoteKind.explanation),
      (label: 'Questions', kind: DocumentNoteKind.question),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: activeFilter == filter.kind,
              onSelected: (_) => onFilterChanged(filter.kind),
              selectedColor: const Color(0xFFE7ECFF),
              labelStyle: TextStyle(
                color: activeFilter == filter.kind
                    ? const Color(0xFF355BE7)
                    : const Color(0xFF6F7585),
                fontWeight: FontWeight.w800,
              ),
              side: const BorderSide(color: Color(0xFFDCE2F0)),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class NotebookNoteCard extends StatelessWidget {
  const NotebookNoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  final DocumentNote note;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6FF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => unawaited(onTap()),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    documentNoteIcon(note.kind),
                    color: const Color(0xFF5368E8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      documentNoteKindLabel(note.kind),
                      style: const TextStyle(
                        color: Color(0xFF202430),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'Page ${note.pageNumber}',
                    style: const TextStyle(
                      color: Color(0xFF5368E8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF5368E8),
                  ),
                ],
              ),
              if (note.sentenceText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note.sentenceText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7D8494),
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                note.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4E5668),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotebookNoteDetailSheet extends StatelessWidget {
  const NotebookNoteDetailSheet({
    super.key,
    required this.note,
    required this.onGoToSource,
    required this.onCopy,
    required this.onDelete,
  });

  final DocumentNote note;
  final Future<void> Function() onGoToSource;
  final Future<void> Function() onCopy;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFDCE2F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F141D3A),
              blurRadius: 32,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1F2A56), Color(0xFF5368E8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(documentNoteIcon(note.kind), color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentNoteKindLabel(note.kind),
                        style: const TextStyle(
                          color: Color(0xFF202430),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        documentNoteReferenceLabel(note),
                        style: const TextStyle(
                          color: Color(0xFF6F7585),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close note',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.sentenceText.isNotEmpty) ...[
                      const Text(
                        'SOURCE',
                        style: TextStyle(
                          color: Color(0xFF7D8494),
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCE2F0)),
                        ),
                        child: Text(
                          note.sentenceText,
                          style: const TextStyle(
                            color: Color(0xFF4E5668),
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'NOTE',
                      style: TextStyle(
                        color: Color(0xFF7D8494),
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      note.body,
                      style: const TextStyle(
                        color: Color(0xFF202430),
                        fontSize: 15,
                        height: 1.42,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => unawaited(onGoToSource()),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Go to Source'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => unawaited(onCopy()),
                  tooltip: 'Copy note',
                  icon: const Icon(Icons.copy_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => unawaited(onDelete()),
                  tooltip: 'Delete note',
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: const Color(0xFFB23B4A),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NotebookLoadingCard extends StatelessWidget {
  const NotebookLoadingCard({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE2F0)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF5368E8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4E5668),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
