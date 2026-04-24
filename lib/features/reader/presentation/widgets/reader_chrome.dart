import 'dart:async';

import 'package:flutter/material.dart';

class ReaderToolbar extends StatefulWidget {
  const ReaderToolbar({
    super.key,
    required this.canInteract,
    required this.isMinimized,
    required this.onToggleMinimized,
    required this.onMinimizedDragUpdate,
    required this.zoomLabel,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFitPage,
    required this.isBookmarked,
    required this.onBookmarkPressed,
    required this.onAiPressed,
  });

  final bool canInteract;
  final bool isMinimized;
  final VoidCallback onToggleMinimized;
  final ValueChanged<Offset> onMinimizedDragUpdate;
  final String zoomLabel;
  final Future<void> Function() onPreviousPage;
  final Future<void> Function() onNextPage;
  final Future<void> Function() onZoomOut;
  final Future<void> Function() onZoomIn;
  final Future<void> Function() onFitPage;
  final bool isBookmarked;
  final Future<void> Function() onBookmarkPressed;
  final Future<void> Function() onAiPressed;

  @override
  State<ReaderToolbar> createState() => _ReaderToolbarState();
}

class _ReaderToolbarState extends State<ReaderToolbar> {
  final ScrollController _horizontalScrollController = ScrollController();
  Timer? _scrollbarHintTimer;
  bool _showHorizontalScrollbar = true;

  @override
  void initState() {
    super.initState();
    _scheduleScrollbarHintHide();
  }

  @override
  void dispose() {
    _scrollbarHintTimer?.cancel();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMinimized && !widget.isMinimized) {
      _showScrollbarHint();
    }
  }

  void _scheduleScrollbarHintHide() {
    _scrollbarHintTimer?.cancel();
    _scrollbarHintTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted || !_showHorizontalScrollbar) {
        return;
      }
      setState(() {
        _showHorizontalScrollbar = false;
      });
    });
  }

  void _showScrollbarHint() {
    if (!mounted) {
      return;
    }
    if (_showHorizontalScrollbar) {
      _scheduleScrollbarHintHide();
      return;
    }

    setState(() {
      _showHorizontalScrollbar = true;
    });
    _scheduleScrollbarHintHide();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMinimized) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: widget.onToggleMinimized,
          onPanUpdate: (details) => widget.onMinimizedDragUpdate(details.delta),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFDCE2F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D141D3A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.zoomLabel,
                  style: const TextStyle(
                    color: Color(0xFF355BE7),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 20,
                  color: Color(0xFF355BE7),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final toolbarItems = [
      _ToolbarSlot(
        child: _ToolbarButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous page',
          onPressed: widget.canInteract ? widget.onPreviousPage : null,
        ),
      ),
      _ToolbarSlot(
        child: _ToolbarButton(
          icon: Icons.remove_rounded,
          tooltip: 'Zoom out',
          onPressed: widget.canInteract ? widget.onZoomOut : null,
        ),
      ),
      _ToolbarSlot(
        child: _ReaderChip(label: widget.zoomLabel),
      ),
      _ToolbarSlot(
        child: IconButton(
          onPressed: widget.canInteract ? () => widget.onFitPage() : null,
          tooltip: 'Fit page',
          icon: const Icon(Icons.fit_screen_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFEFF2FA),
            foregroundColor: const Color(0xFF355BE7),
            disabledForegroundColor: const Color(0xFF9DA5B8),
            disabledBackgroundColor: const Color(0xFFF3F5FA),
          ),
        ),
      ),
      _ToolbarSlot(
        child: _ToolbarButton(
          icon: Icons.add_rounded,
          tooltip: 'Zoom in',
          onPressed: widget.canInteract ? widget.onZoomIn : null,
        ),
      ),
      _ToolbarSlot(
        child: _ToolbarButton(
          icon: widget.isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          tooltip: 'Bookmarks',
          onPressed: widget.canInteract ? widget.onBookmarkPressed : null,
        ),
      ),
      _ToolbarSlot(
        child: _ToolbarButton(
          icon: Icons.auto_awesome_rounded,
          tooltip: 'AI actions',
          onPressed: widget.canInteract ? widget.onAiPressed : null,
        ),
      ),
      _ToolbarSlot(
        child: _ToolbarButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next page',
          onPressed: widget.canInteract ? widget.onNextPage : null,
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE2F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D141D3A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.horizontal) {
                  _showScrollbarHint();
                }
                return false;
              },
              child: RawScrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: _showHorizontalScrollbar,
                trackVisibility: false,
                interactive: false,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                radius: const Radius.circular(999),
                thickness: 2,
                thumbColor: const Color(0xFFB8BECC).withValues(alpha: 0.62),
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < toolbarItems.length; i++) ...[
                        toolbarItems[i].child,
                        if (i != toolbarItems.length - 1)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ToolbarButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'Minimize toolbar',
            onPressed: () async {
              widget.onToggleMinimized();
            },
          ),
        ],
      ),
    );
  }
}

class ReaderTopChrome extends StatelessWidget {
  const ReaderTopChrome({
    super.key,
    required this.isExpanded,
    required this.isSearchVisible,
    required this.documentTitle,
    required this.documentFileName,
    required this.pageLabel,
    required this.canInteract,
    required this.searchController,
    required this.isSearching,
    required this.resultCount,
    required this.activeResultIndex,
    required this.onOutlinePressed,
    required this.onSearchPressed,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onPreviousSearchResult,
    required this.onNextSearchResult,
    required this.onCloseSearch,
  });

  final bool isExpanded;
  final bool isSearchVisible;
  final String documentTitle;
  final String documentFileName;
  final String pageLabel;
  final bool canInteract;
  final TextEditingController searchController;
  final bool isSearching;
  final int resultCount;
  final int activeResultIndex;
  final VoidCallback onOutlinePressed;
  final VoidCallback onSearchPressed;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onPreviousSearchResult;
  final VoidCallback onNextSearchResult;
  final VoidCallback onCloseSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F6FB),
      padding: EdgeInsets.fromLTRB(22, isExpanded ? 8 : 2, 22, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: 1,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: documentTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF202430),
                            ),
                          ),
                          TextSpan(
                            text: ' - $documentFileName',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF202430),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (isExpanded) const SizedBox(height: 4),
          SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ReaderHeaderIconButton(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'Document outline',
                    onPressed: canInteract ? onOutlinePressed : null,
                  ),
                ),
                _ReaderHeaderCounter(label: pageLabel),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ReaderHeaderIconButton(
                    icon: Icons.search_rounded,
                    tooltip: 'Search PDF',
                    onPressed: canInteract ? onSearchPressed : null,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, -0.16),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
              child: isSearchVisible
                  ? Padding(
                      key: const ValueKey('pdf-search-bar'),
                      padding: const EdgeInsets.only(top: 10),
                      child: _InlinePdfSearchBar(
                        controller: searchController,
                        isSearching: isSearching,
                        resultCount: resultCount,
                        activeResultIndex: activeResultIndex,
                        onChanged: onSearchChanged,
                        onSubmitted: onSearchSubmitted,
                        onPrevious: onPreviousSearchResult,
                        onNext: onNextSearchResult,
                        onClose: onCloseSearch,
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('pdf-search-hidden'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarSlot extends StatelessWidget {
  const _ToolbarSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final action = onPressed;

    return IconButton(
      onPressed: action == null ? null : () => action(),
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFEFF2FA),
        foregroundColor: const Color(0xFF355BE7),
        disabledForegroundColor: const Color(0xFF9DA5B8),
        disabledBackgroundColor: const Color(0xFFF3F5FA),
      ),
    );
  }
}

class _ReaderChip extends StatelessWidget {
  const _ReaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7DDED)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF355BE7),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReaderHeaderCounter extends StatelessWidget {
  const _ReaderHeaderCounter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF6F7585),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ReaderHeaderIconButton extends StatelessWidget {
  const _ReaderHeaderIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
        iconSize: 18,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFEFF2FA),
          foregroundColor: const Color(0xFF355BE7),
          disabledForegroundColor: const Color(0xFF9DA5B8),
          disabledBackgroundColor: const Color(0xFFF3F5FA),
        ),
      ),
    );
  }
}

class _InlinePdfSearchBar extends StatelessWidget {
  const _InlinePdfSearchBar({
    required this.controller,
    required this.isSearching,
    required this.resultCount,
    required this.activeResultIndex,
    required this.onChanged,
    required this.onSubmitted,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final bool isSearching;
  final int resultCount;
  final int activeResultIndex;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasResults = resultCount > 0;
    final resultLabel = isSearching
        ? '...'
        : hasResults
            ? '${activeResultIndex + 1}/$resultCount'
            : '0/0';

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE2F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D141D3A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(
            Icons.search_rounded,
            size: 18,
            color: Color(0xFF6F7585),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search in PDF',
                hintStyle: TextStyle(color: Color(0xFF9AA2B4)),
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              resultLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6F7585),
              ),
            ),
          ),
          IconButton(
            onPressed: hasResults ? onPrevious : null,
            tooltip: 'Previous result',
            icon: const Icon(Icons.keyboard_arrow_left_rounded),
          ),
          IconButton(
            onPressed: hasResults ? onNext : null,
            tooltip: 'Next result',
            icon: const Icon(Icons.keyboard_arrow_right_rounded),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close search',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
