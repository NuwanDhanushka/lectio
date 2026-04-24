import 'package:flutter/material.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../../notebook/domain/document_note.dart';

enum NotebookExportFormat { pdf, docx }

enum ActivityBookmarkFilter {
  all('All'),
  notes('Notes'),
  sentences('Sentences'),
  pages('Pages');

  const ActivityBookmarkFilter(this.label);

  final String label;
}

class BookmarkDocumentGroup {
  const BookmarkDocumentGroup({
    required this.item,
    required this.entries,
  });

  final LibraryItem item;
  final List<BookmarkSnapshotEntry> entries;
}

class BookmarkFilterChips extends StatelessWidget {
  const BookmarkFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
  });

  final ActivityBookmarkFilter selectedFilter;
  final ValueChanged<ActivityBookmarkFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in ActivityBookmarkFilter.values) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: selectedFilter == filter,
              onSelected: (_) => onChanged(filter),
            ),
            if (filter != ActivityBookmarkFilter.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class BookmarkDocumentSection extends StatelessWidget {
  const BookmarkDocumentSection({
    super.key,
    required this.group,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onExport,
    required this.onExportNotebook,
    required this.isExportingNotebook,
    required this.onOpenDocument,
  });

  final BookmarkDocumentGroup group;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onExport;
  final ValueChanged<NotebookExportFormat> onExportNotebook;
  final bool isExportingNotebook;
  final void Function(LibraryItem item, {int? initialPage}) onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final firstBookmark = group.entries.first.bookmark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202430),
                  ),
                ),
              ),
              Text(
                '${group.entries.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C8393),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => onOpenDocument(
                  group.item,
                  initialPage: firstBookmark.pageNumber,
                ),
                tooltip: 'Open first bookmark',
                icon: const Icon(Icons.open_in_new_rounded),
              ),
              IconButton(
                onPressed: onExport,
                tooltip: 'Export this document',
                icon: const Icon(Icons.ios_share_rounded),
              ),
              if (isExportingNotebook)
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
                  tooltip: 'Export notebook',
                  icon: const Icon(Icons.menu_book_rounded),
                  color: Colors.white,
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFDCE2F0)),
                  ),
                  onSelected: onExportNotebook,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: NotebookExportFormat.pdf,
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded),
                          SizedBox(width: 10),
                          Text('Notebook PDF'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: NotebookExportFormat.docx,
                      child: Row(
                        children: [
                          Icon(Icons.description_rounded),
                          SizedBox(width: 10),
                          Text('Notebook DOCX'),
                        ],
                      ),
                    ),
                  ],
                ),
              IconButton(
                onPressed: onToggleCollapsed,
                tooltip: isCollapsed ? 'Expand document' : 'Collapse document',
                icon: Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                ),
              ),
            ],
          ),
        ),
        if (!isCollapsed)
          ...List.generate(group.entries.length, (index) {
            final entry = group.entries[index];
            final isLast = index == group.entries.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: BookmarkActivityCard(
                entry: entry,
                onTap: () => onOpenDocument(
                  entry.item,
                  initialPage: entry.bookmark.pageNumber,
                ),
              ),
            );
          }),
      ],
    );
  }
}

class BookmarkActivityCard extends StatelessWidget {
  const BookmarkActivityCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final BookmarkSnapshotEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D141D3A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.bookmark_rounded,
                  color: Color(0xFF355BE7),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202430),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.bookmark.label.isEmpty
                          ? 'Page ${entry.bookmark.pageNumber}'
                          : entry.bookmark.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF355BE7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.item.fileName} • Page ${entry.bookmark.pageNumber}'
                      '${entry.bookmark.sentenceIndex == null ? '' : ' • Sentence ${entry.bookmark.sentenceIndex! + 1}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6F7585),
                      ),
                    ),
                    if (entry.bookmark.sentenceText.isNotEmpty ||
                        entry.bookmark.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.bookmark.note.isNotEmpty
                            ? entry.bookmark.note
                            : entry.bookmark.sentenceText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7C8393),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF8C94A8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyBookmarksState extends StatelessWidget {
  const EmptyBookmarksState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 36,
            color: Color(0xFF355BE7),
          ),
          SizedBox(height: 14),
          Text(
            'No bookmarks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF202430),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Save pages in the reader to build a quick list of places you want to revisit.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6F7585),
            ),
          ),
        ],
      ),
    );
  }
}

class NoFilteredBookmarksState extends StatelessWidget {
  const NoFilteredBookmarksState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Text(
        'No bookmarks match this filter.',
        style: TextStyle(
          fontSize: 15,
          color: Color(0xFF6F7585),
        ),
      ),
    );
  }
}

List<BookmarkDocumentGroup> groupBookmarksByDocument(
  List<BookmarkSnapshotEntry> entries,
) {
  final groupsByDocument = <int?, List<BookmarkSnapshotEntry>>{};
  for (final entry in entries) {
    groupsByDocument.putIfAbsent(entry.item.id, () => []).add(entry);
  }

  return [
    for (final groupEntries in groupsByDocument.values)
      BookmarkDocumentGroup(
        item: groupEntries.first.item,
        entries: groupEntries,
      ),
  ];
}

String exportBookmarksAsMarkdown(List<BookmarkSnapshotEntry> entries) {
  if (entries.isEmpty) {
    return '# Lectio Bookmarks\n\nNo bookmarks exported.';
  }

  final grouped = <int?, List<BookmarkSnapshotEntry>>{};
  for (final entry in entries) {
    grouped.putIfAbsent(entry.item.id, () => []).add(entry);
  }

  final buffer = StringBuffer('# Lectio Bookmarks\n');
  for (final documentEntries in grouped.values) {
    final item = documentEntries.first.item;
    buffer
      ..writeln()
      ..writeln('## ${item.title}')
      ..writeln()
      ..writeln('_${item.fileName}_')
      ..writeln();

    for (final entry in documentEntries) {
      final bookmark = entry.bookmark;
      final sentenceLabel = bookmark.sentenceIndex == null
          ? ''
          : ', sentence ${bookmark.sentenceIndex! + 1}';
      final title = bookmark.label.isEmpty
          ? 'Page ${bookmark.pageNumber}$sentenceLabel'
          : bookmark.label;

      buffer
        ..writeln('### $title')
        ..writeln()
        ..writeln('- Page: ${bookmark.pageNumber}$sentenceLabel');

      if (bookmark.sentenceText.isNotEmpty) {
        buffer
          ..writeln('- Passage:')
          ..writeln('  > ${bookmark.sentenceText}');
      }

      if (bookmark.note.isNotEmpty) {
        buffer
          ..writeln('- Note:')
          ..writeln('  ${bookmark.note}');
      }

      buffer.writeln();
    }
  }

  return buffer.toString().trimRight();
}

int notebookSelectionKey(LibraryItem item) {
  return item.id ?? Object.hash(item.title, item.filePath);
}

List<DocumentNote> notesForSelectedNotebookExport(
  List<DocumentNotebookSnapshotEntry> notebooks,
) {
  return [
    for (final notebook in notebooks)
      for (final note in notebook.notes)
        DocumentNote(
          id: note.id,
          documentId: note.documentId,
          kind: note.kind,
          pageNumber: note.pageNumber,
          sentenceIndex: note.sentenceIndex,
          sentenceText: note.sentenceText,
          outlineTitle: note.outlineTitle.trim().isEmpty
              ? notebook.item.title
              : '${notebook.item.title} / ${note.outlineTitle}',
          title: note.title,
          body: note.body,
          createdAt: note.createdAt,
        ),
  ];
}
