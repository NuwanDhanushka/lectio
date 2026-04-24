import 'package:flutter/material.dart';

import '../../../library/data/library_repository.dart';
import 'profile_bookmark_activity.dart';

class NotebookSelectionPanel extends StatelessWidget {
  const NotebookSelectionPanel({
    super.key,
    required this.notebooks,
    required this.selectedKeys,
    required this.isExporting,
    required this.onToggleSelectAll,
    required this.onToggleNotebook,
    required this.onExport,
  });

  final List<DocumentNotebookSnapshotEntry> notebooks;
  final Set<int> selectedKeys;
  final bool isExporting;
  final VoidCallback onToggleSelectAll;
  final ValueChanged<DocumentNotebookSnapshotEntry> onToggleNotebook;
  final ValueChanged<NotebookExportFormat> onExport;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        notebooks.isNotEmpty && selectedKeys.length == notebooks.length;
    final selectedCount = selectedKeys.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F2A56), Color(0xFF5368E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F243C9F),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Export notebooks',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onToggleSelectAll,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      allSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                    ),
                    label: Text(allSelected ? 'Unselect all' : 'Select all'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$selectedCount of ${notebooks.length} selected',
                style: const TextStyle(
                  color: Color(0xCCDDE4FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: selectedCount == 0 || isExporting
                          ? null
                          : () => onExport(NotebookExportFormat.pdf),
                      icon: isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('PDF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: selectedCount == 0 || isExporting
                          ? null
                          : () => onExport(NotebookExportFormat.docx),
                      icon: const Icon(Icons.description_rounded),
                      label: const Text('DOCX'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...notebooks.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NotebookSelectionCard(
              entry: entry,
              isSelected:
                  selectedKeys.contains(notebookSelectionKey(entry.item)),
              onTap: () => onToggleNotebook(entry),
            ),
          ),
        ),
      ],
    );
  }
}

class NotebookSelectionCard extends StatelessWidget {
  const NotebookSelectionCard({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final DocumentNotebookSnapshotEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF5368E8)
                  : const Color(0xFFE4E8F2),
              width: isSelected ? 1.4 : 1,
            ),
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
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: const Color(0xFF5368E8),
              ),
              const SizedBox(width: 8),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF355BE7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF202430),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.notes.length} note${entry.notes.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF6F7585),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
