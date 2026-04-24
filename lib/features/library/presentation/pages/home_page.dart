import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_services_providers.dart';
import '../../../../core/widgets/section_title.dart';
import '../../domain/library_item.dart';
import '../controllers/home_page_controller.dart';
import '../widgets/library_card.dart';
import '../widgets/library_stats_widgets.dart';
import '../widgets/bookshelf.dart';
import '../widgets/home_shell_widgets.dart';

final homePageControllerProvider =
    ChangeNotifierProvider.autoDispose<HomePageController>((ref) {
  return HomePageController(
    repository: ref.watch(libraryRepositoryProvider),
    importService: ref.watch(documentImportServiceProvider),
  );
});

const double _homeHorizontalPadding = 24;
const double _homeTopContentPadding = 86;
const double _homeBottomContentPadding = 28;
const double _homeSectionGap = 24;
const double _homeLargeSectionGap = 32;
const double _homeLabelGap = 12;
const double _homeItemGap = 16;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenDocument,
  });

  final ValueChanged<LibraryItem> onOpenDocument;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _bookShelfScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadLibrary();
    });
  }

  @override
  void dispose() {
    _bookShelfScrollController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final message = await ref.read(homePageControllerProvider).loadLibrary();
    _showMessage(message);
  }

  Future<void> _importDocument() async {
    final message = await ref.read(homePageControllerProvider).importDocument();
    _showMessage(message);
  }

  Future<void> _removeDocument(LibraryItem item) async {
    final message =
        await ref.read(homePageControllerProvider).removeDocument(item);
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
    final controller = ref.watch(homePageControllerProvider);
    final snapshot = controller.snapshot;
    final continueItem = snapshot.recentItems
        .where((item) => item.progress > 0 && item.progress < 1)
        .cast<LibraryItem?>()
        .firstWhere(
          (item) => item != null,
          orElse: () => null,
        );
    final recentListItems = continueItem == null
        ? snapshot.recentItems
        : snapshot.recentItems
            .where((item) => item.id != continueItem.id)
            .toList(growable: false);
    final hasLibraryItems = snapshot.recentItems.isNotEmpty;
    final recentSection = [
      const SectionTitle(
        title: 'Recently Accessed',
        actionLabel: 'View All',
        isCompactLabel: true,
      ),
      const SizedBox(height: _homeLabelGap),
      if (controller.isLoading)
        const HomeLoadingState()
      else if (snapshot.recentItems.isEmpty)
        const EmptyLibraryCard()
      else if (recentListItems.isEmpty)
        const RecentListPlaceholder()
      else
        ...List.generate(recentListItems.length, (index) {
          final item = recentListItems[index];
          final isLast = index == recentListItems.length - 1;

          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : _homeItemGap,
            ),
            child: RecentItemCard(
              item: item,
              isHighlighted: continueItem == null && index == 0,
              onTap: () => widget.onOpenDocument(item),
              onRemove: () => _removeDocument(item),
            ),
          );
        }),
    ];

    return SafeArea(
      child: Stack(
        children: [
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            radius: const Radius.circular(999),
            thickness: 3,
            interactive: true,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ListView(
                controller: _scrollController,
                cacheExtent: 6000,
                padding: const EdgeInsets.fromLTRB(
                  _homeHorizontalPadding,
                  _homeTopContentPadding,
                  _homeHorizontalPadding,
                  _homeBottomContentPadding,
                ),
                children: [
                  if (!hasLibraryItems) ...[
                    ImportCard(
                      isImporting: controller.isImporting,
                      onTap: _importDocument,
                    ),
                    const SizedBox(height: _homeSectionGap),
                  ],
                  if (!controller.isLoading && continueItem != null) ...[
                    const SectionTitle(
                      title: 'Continue Reading',
                      actionLabel: 'Resume',
                      isCompactLabel: true,
                    ),
                    const SizedBox(height: _homeLabelGap),
                    ContinueReadingCard(
                      item: continueItem,
                      onTap: () => widget.onOpenDocument(continueItem),
                    ),
                    const SizedBox(height: _homeSectionGap),
                  ],
                  if (hasLibraryItems && continueItem == null) ...[
                    ...recentSection,
                    const SizedBox(height: _homeSectionGap),
                  ],
                  const HomeSectionLabel('LIBRARY'),
                  const SizedBox(height: _homeLabelGap),
                  BookShelf(
                    items: snapshot.recentItems.take(6).toList(growable: false),
                    controller: _bookShelfScrollController,
                    onOpenDocument: widget.onOpenDocument,
                  ),
                  const SizedBox(height: _homeSectionGap),
                  if (hasLibraryItems && continueItem != null) ...[
                    ImportCard(
                      isImporting: controller.isImporting,
                      onTap: _importDocument,
                    ),
                    const SizedBox(height: _homeLargeSectionGap),
                  ],
                  if (continueItem != null || !hasLibraryItems) ...[
                    ...recentSection,
                  ],
                  if (hasLibraryItems && continueItem == null) ...[
                    const SizedBox(height: _homeSectionGap),
                    ImportCard(
                      isImporting: controller.isImporting,
                      onTap: _importDocument,
                    ),
                  ],
                  const SizedBox(height: _homeSectionGap),
                  StatsGrid(snapshot: snapshot),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                _homeHorizontalPadding,
                18,
                _homeHorizontalPadding,
                14,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF5F6FB).withValues(alpha: 0.92),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const HomeHeader(),
            ),
          ),
        ],
      ),
    );
  }
}
