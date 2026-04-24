import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../controllers/profile_activity_controller.dart';
import '../widgets/profile_bookmark_activity.dart';
import '../widgets/profile_notebook_selection.dart';

final profileActivityControllerProvider = ChangeNotifierProvider.autoDispose
    .family<ProfileActivityController, LibraryRepository>((ref, repository) {
  return ProfileActivityController(repository: repository);
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({
    super.key,
    required this.repository,
    required this.onOpenDocument,
  });

  final LibraryRepository repository;
  final void Function(LibraryItem item, {int? initialPage}) onOpenDocument;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(profileActivityControllerProvider(widget.repository)).load();
    });
  }

  Future<void> _copyBookmarksExport() async {
    final message = await ref
        .read(profileActivityControllerProvider(widget.repository))
        .copyBookmarksExport();
    _showMessage(message);
  }

  Future<void> _copyDocumentBookmarksExport(BookmarkDocumentGroup group) async {
    final message = await ref
        .read(profileActivityControllerProvider(widget.repository))
        .copyDocumentBookmarksExport(group);
    _showMessage(message);
  }

  Future<void> _exportDocumentNotebook(
    LibraryItem item,
    NotebookExportFormat format,
  ) async {
    final message = await ref
        .read(profileActivityControllerProvider(widget.repository))
        .exportDocumentNotebook(item, format);
    _showMessage(message);
  }

  Future<void> _exportSelectedNotebooks(NotebookExportFormat format) async {
    final message = await ref
        .read(profileActivityControllerProvider(widget.repository))
        .exportSelectedNotebooks(format);
    _showMessage(message);
  }

  void _showMessage(String? message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        ref.watch(profileActivityControllerProvider(widget.repository));
    final visibleBookmarks = controller.visibleBookmarks;
    final groupedBookmarks = controller.groupedBookmarks;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202430),
                  ),
                ),
              ),
              if (!controller.isLoading && visibleBookmarks.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: _copyBookmarksExport,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Export'),
                ),
              if (!controller.isLoading && controller.notebooks.isNotEmpty) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: controller.toggleNotebookSelectionMode,
                  icon: Icon(
                    controller.isNotebookSelectionMode
                        ? Icons.close_rounded
                        : Icons.checklist_rounded,
                  ),
                  label: Text(
                    controller.isNotebookSelectionMode ? 'Cancel' : 'Notebooks',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Jump back into your saved bookmarks.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6F7585),
            ),
          ),
          const SizedBox(height: 28),
          if (controller.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (controller.isNotebookSelectionMode) ...[
            NotebookSelectionPanel(
              notebooks: controller.notebooks,
              selectedKeys: controller.selectedNotebookKeys,
              isExporting: controller.isExportingSelectedNotebooks,
              onToggleSelectAll: controller.toggleSelectAllNotebooks,
              onToggleNotebook: controller.toggleNotebookSelection,
              onExport: _exportSelectedNotebooks,
            ),
          ] else if (controller.bookmarks.isEmpty)
            const EmptyBookmarksState()
          else ...[
            BookmarkFilterChips(
              selectedFilter: controller.filter,
              onChanged: controller.setFilter,
            ),
            const SizedBox(height: 18),
            if (visibleBookmarks.isEmpty)
              const NoFilteredBookmarksState()
            else
              ...List.generate(groupedBookmarks.length, (sectionIndex) {
                final group = groupedBookmarks[sectionIndex];
                final isLastGroup = sectionIndex == groupedBookmarks.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLastGroup ? 0 : 22),
                  child: BookmarkDocumentSection(
                    group: group,
                    isCollapsed:
                        controller.collapsedDocumentIds.contains(group.item.id),
                    onToggleCollapsed: () =>
                        controller.toggleCollapsedDocument(group.item.id),
                    onExport: () => _copyDocumentBookmarksExport(group),
                    onExportNotebook: (format) => _exportDocumentNotebook(
                      group.item,
                      format,
                    ),
                    isExportingNotebook:
                        controller.exportingNotebookDocumentId == group.item.id,
                    onOpenDocument: widget.onOpenDocument,
                  ),
                );
              }),
          ]
        ],
      ),
    );
  }
}
