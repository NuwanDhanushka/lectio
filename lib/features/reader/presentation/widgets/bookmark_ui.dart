import 'package:flutter/material.dart';

import '../../domain/document_bookmark.dart';

class BookmarkDetails {
  const BookmarkDetails({
    required this.label,
    required this.note,
  });

  final String label;
  final String note;
}

class BookmarkDetailsDialog extends StatefulWidget {
  const BookmarkDetailsDialog({
    super.key,
    required this.pageNumber,
    required this.initialLabel,
    required this.initialNote,
    required this.sentenceText,
  });

  final int pageNumber;
  final String initialLabel;
  final String initialNote;
  final String sentenceText;

  @override
  State<BookmarkDetailsDialog> createState() => _BookmarkDetailsDialogState();
}

class _BookmarkDetailsDialogState extends State<BookmarkDetailsDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel);
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bookmark Page ${widget.pageNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.sentenceText.isNotEmpty) ...[
              const Text(
                'Sentence',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6F7585),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.sentenceText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF202430),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _labelController,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Optional short title',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Add what you want to remember',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            BookmarkDetails(
              label: _labelController.text.trim(),
              note: _noteController.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class BookmarksSheet extends StatelessWidget {
  const BookmarksSheet({
    super.key,
    required this.currentPage,
    required this.currentSentenceIndex,
    required this.bookmarks,
    required this.onToggleCurrentPage,
    required this.onOpenBookmark,
    required this.onRemoveBookmark,
    required this.onEditBookmark,
  });

  final int currentPage;
  final int? currentSentenceIndex;
  final List<DocumentBookmark> bookmarks;
  final Future<void> Function() onToggleCurrentPage;
  final Future<void> Function(DocumentBookmark bookmark) onOpenBookmark;
  final Future<void> Function(DocumentBookmark bookmark) onRemoveBookmark;
  final Future<void> Function(DocumentBookmark bookmark) onEditBookmark;

  @override
  Widget build(BuildContext context) {
    final isCurrentPageBookmarked = bookmarks.any((bookmark) =>
        bookmark.pageNumber == currentPage &&
        bookmark.sentenceIndex == currentSentenceIndex);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DFEC),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bookmarks',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202430),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => onToggleCurrentPage(),
                  icon: Icon(
                    isCurrentPageBookmarked
                        ? Icons.bookmark_remove_rounded
                        : Icons.bookmark_add_rounded,
                  ),
                  label: Text(
                    isCurrentPageBookmarked
                        ? 'Remove Bookmark'
                        : 'Save Bookmark',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (bookmarks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No bookmarks yet. Save the current page to come back later.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6F7585),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: bookmarks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bookmark = bookmarks[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        bookmark.pageNumber == currentPage
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: const Color(0xFF355BE7),
                      ),
                      title: Text(
                        bookmark.label.isEmpty
                            ? 'Page ${bookmark.pageNumber}'
                            : bookmark.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202430),
                        ),
                      ),
                      subtitle: Text(
                        bookmarkSubtitle(bookmark, currentPage),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onOpenBookmark(bookmark),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => onEditBookmark(bookmark),
                            tooltip: 'Edit bookmark',
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => onRemoveBookmark(bookmark),
                            tooltip: 'Remove bookmark',
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String bookmarkSubtitle(DocumentBookmark bookmark, int currentPage) {
  final parts = <String>[
    'Page ${bookmark.pageNumber}',
    if (bookmark.sentenceIndex != null)
      'Sentence ${bookmark.sentenceIndex! + 1}',
    if (bookmark.pageNumber == currentPage) 'Current page',
    if (bookmark.sentenceText.isNotEmpty) '"${bookmark.sentenceText}"',
    if (bookmark.note.isNotEmpty) bookmark.note,
  ];
  return parts.join(' • ');
}
