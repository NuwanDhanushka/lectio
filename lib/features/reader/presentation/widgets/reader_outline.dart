import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfOutlineEntry {
  const PdfOutlineEntry({
    required this.title,
    required this.pageNumber,
    this.level = 0,
    this.dest,
    this.range,
  });

  final String title;
  final int pageNumber;
  final int level;
  final PdfDest? dest;
  final PdfPageTextRange? range;
}

List<PdfOutlineEntry> flattenPdfOutlineNodes(
  List<PdfOutlineNode> nodes, {
  int level = 0,
}) {
  final entries = <PdfOutlineEntry>[];
  for (final node in nodes) {
    final dest = node.dest;
    if (dest != null && node.title.trim().isNotEmpty) {
      entries.add(
        PdfOutlineEntry(
          title: node.title.trim(),
          pageNumber: dest.pageNumber,
          level: level,
          dest: dest,
        ),
      );
    }
    entries.addAll(flattenPdfOutlineNodes(node.children, level: level + 1));
  }
  return entries;
}

class PdfOutlineSidebar extends StatefulWidget {
  const PdfOutlineSidebar({
    super.key,
    required this.documentTitle,
    required this.documentFileName,
    required this.entriesFuture,
    required this.collapsedIndexes,
    required this.onCollapsedIndexesChanged,
    required this.onOpenEntry,
  });

  final String documentTitle;
  final String documentFileName;
  final Future<List<PdfOutlineEntry>> entriesFuture;
  final Set<int> collapsedIndexes;
  final ValueChanged<Set<int>> onCollapsedIndexesChanged;
  final Future<void> Function(PdfOutlineEntry entry) onOpenEntry;

  @override
  State<PdfOutlineSidebar> createState() => _PdfOutlineSidebarState();
}

class _PdfOutlineSidebarState extends State<PdfOutlineSidebar> {
  final ScrollController _scrollController = ScrollController();
  late final Set<int> _collapsedOutlineIndexes =
      Set<int>.of(widget.collapsedIndexes);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasChildren(List<PdfOutlineEntry> entries, int index) {
    return index + 1 < entries.length &&
        entries[index + 1].level > entries[index].level;
  }

  List<_VisiblePdfOutlineEntry> _visibleEntries(List<PdfOutlineEntry> entries) {
    final visibleEntries = <_VisiblePdfOutlineEntry>[];
    final collapsedLevels = <int>[];

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      while (
          collapsedLevels.isNotEmpty && entry.level <= collapsedLevels.last) {
        collapsedLevels.removeLast();
      }

      if (collapsedLevels.isEmpty) {
        visibleEntries.add(
          _VisiblePdfOutlineEntry(
            entry: entry,
            sourceIndex: index,
            hasChildren: _hasChildren(entries, index),
          ),
        );
      }

      if (_collapsedOutlineIndexes.contains(index)) {
        collapsedLevels.add(entry.level);
      }
    }

    return visibleEntries;
  }

  void _setSectionExpanded({
    required int sourceIndex,
    required bool isExpanded,
  }) {
    setState(() {
      if (isExpanded) {
        _collapsedOutlineIndexes.add(sourceIndex);
      } else {
        _collapsedOutlineIndexes.remove(sourceIndex);
      }
      widget.onCollapsedIndexesChanged(Set<int>.of(_collapsedOutlineIndexes));
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.84).clamp(304.0, 386.0);
    final fileName = widget.documentFileName.trim();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        right: false,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: width,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFF),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 28,
                  offset: Offset(12, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT DOCUMENT',
                              style: TextStyle(
                                color: Color(0xFF7B8190),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.documentTitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF202430),
                                fontSize: 25,
                                height: 1.08,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (fileName.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6E7482),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close outline',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF5D6372),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8ECF5)),
                Expanded(
                  child: FutureBuilder<List<PdfOutlineEntry>>(
                    future: widget.entriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final entries =
                          snapshot.data ?? const <PdfOutlineEntry>[];
                      if (entries.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(22, 24, 22, 0),
                          child: Text(
                            'No outline or chapter-like headings were found in this PDF.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: Color(0xFF6F7585),
                            ),
                          ),
                        );
                      }

                      final visibleEntries = _visibleEntries(entries);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 18),
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          radius: const Radius.circular(999),
                          thickness: 3,
                          interactive: true,
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                            itemCount: visibleEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final visibleEntry = visibleEntries[index];
                              final entry = visibleEntry.entry;
                              final level = entry.level.clamp(0, 4);
                              final isTopLevel = level == 0;
                              final isExpanded = !_collapsedOutlineIndexes
                                  .contains(visibleEntry.sourceIndex);
                              final color = isTopLevel
                                  ? const Color(0xFF2F5BEA)
                                  : const Color(0xFF5F6572);

                              return Material(
                                color: isTopLevel
                                    ? const Color(0xFFFFFFFF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () =>
                                      unawaited(widget.onOpenEntry(entry)),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      10 + (level * 18).toDouble(),
                                      isTopLevel ? 13 : 10,
                                      12,
                                      isTopLevel ? 13 : 10,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: visibleEntry.hasChildren
                                              ? IconButton(
                                                  tooltip: isExpanded
                                                      ? 'Collapse section'
                                                      : 'Expand section',
                                                  onPressed: () {
                                                    _setSectionExpanded(
                                                      sourceIndex: visibleEntry
                                                          .sourceIndex,
                                                      isExpanded: isExpanded,
                                                    );
                                                  },
                                                  icon: Icon(
                                                    isExpanded
                                                        ? Icons
                                                            .expand_more_rounded
                                                        : Icons
                                                            .chevron_right_rounded,
                                                  ),
                                                  iconSize: 22,
                                                  padding: EdgeInsets.zero,
                                                  color: color,
                                                )
                                              : Icon(
                                                  isTopLevel
                                                      ? Icons
                                                          .format_list_bulleted_rounded
                                                      : Icons
                                                          .short_text_rounded,
                                                  color: color,
                                                  size: isTopLevel ? 22 : 20,
                                                ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: isTopLevel ? 16 : 14,
                                              height: 1.2,
                                              fontWeight: isTopLevel
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${entry.pageNumber}',
                                          style: TextStyle(
                                            color: isTopLevel
                                                ? const Color(0xFF4465E8)
                                                : const Color(0xFF8A909D),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisiblePdfOutlineEntry {
  const _VisiblePdfOutlineEntry({
    required this.entry,
    required this.sourceIndex,
    required this.hasChildren,
  });

  final PdfOutlineEntry entry;
  final int sourceIndex;
  final bool hasChildren;
}
