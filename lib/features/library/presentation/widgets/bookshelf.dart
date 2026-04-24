import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../domain/library_item.dart';

class BookShelf extends StatelessWidget {
  const BookShelf({
    super.key,
    required this.items,
    required this.controller,
    required this.onOpenDocument,
  });

  final List<LibraryItem> items;
  final ScrollController controller;
  final ValueChanged<LibraryItem> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2A56), Color(0xFF5368E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5368E8),
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
                  'Your Bookshelf',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white30),
                ),
                child: Text(
                  '${items.length} books',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const _EmptyBookShelf()
          else
            RawScrollbar(
              controller: controller,
              thumbVisibility: true,
              trackVisibility: false,
              interactive: false,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              radius: const Radius.circular(999),
              thickness: 2,
              thumbColor: Colors.white54,
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _BookCoverCard(
                        item: items[index],
                        paletteIndex: index,
                        onTap: () => onOpenDocument(items[index]),
                      ),
                      if (index != items.length - 1) const SizedBox(width: 14),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyBookShelf extends StatelessWidget {
  const _EmptyBookShelf();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D5F5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your library is empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Import a PDF to start building your shelf.',
            style: TextStyle(
              color: Color(0xFFD9E2FF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCoverCard extends StatelessWidget {
  const _BookCoverCard({
    required this.item,
    required this.paletteIndex,
    required this.onTap,
  });

  final LibraryItem item;
  final int paletteIndex;
  final VoidCallback onTap;

  static const _palettes = [
    [Color(0xFFF27E72), Color(0xFFFFD2A1), Color(0xFF284E8F)],
    [Color(0xFF0068C9), Color(0xFF00B0FF), Color(0xFFFFE36E)],
    [Color(0xFFFFFAE8), Color(0xFFFFC9DD), Color(0xFF2F8F88)],
    [Color(0xFF233A5F), Color(0xFF76D7C4), Color(0xFFFFD166)],
    [Color(0xFF6B4DE6), Color(0xFFE1D7FF), Color(0xFFFF9F1C)],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[paletteIndex % _palettes.length];
    final titleWords = item.title.trim().split(RegExp(r'\s+'));
    final shortTitle = titleWords.take(5).join(' ');
    final title = item.title.trim().isEmpty ? item.fileName : item.title.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 112,
          height: 198,
          child: Column(
            children: [
              Container(
                width: 104,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _BookCoverPreview(
                    item: item,
                    palette: palette,
                    fallbackTitle:
                        shortTitle.isEmpty ? item.fileName : shortTitle,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCoverPreview extends StatelessWidget {
  const _BookCoverPreview({
    required this.item,
    required this.palette,
    required this.fallbackTitle,
  });

  final LibraryItem item;
  final List<Color> palette;
  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    if (item.isPdf && item.filePath.isNotEmpty) {
      return PdfDocumentViewBuilder.file(
        item.filePath,
        loadingBuilder: (context) => _GeneratedBookCover(
          item: item,
          palette: palette,
          title: fallbackTitle,
        ),
        errorBuilder: (context, error, stackTrace) => _GeneratedBookCover(
          item: item,
          palette: palette,
          title: fallbackTitle,
        ),
        builder: (context, document) {
          if (document == null) {
            return _GeneratedBookCover(
              item: item,
              palette: palette,
              title: fallbackTitle,
            );
          }

          return PdfPageView(
            document: document,
            pageNumber: 1,
            maximumDpi: 120,
            pageSizeCallback: (biggestSize, page, rotationOverride) =>
                biggestSize,
            alignment: Alignment.center,
            backgroundColor: Colors.white,
            decoration: const BoxDecoration(color: Colors.white),
            decorationBuilder: (context, pageSize, page, pageImage) {
              return Container(
                color: Colors.white,
                child: pageImage == null
                    ? const SizedBox.expand()
                    : FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: pageSize.width,
                          height: pageSize.height,
                          child: pageImage,
                        ),
                      ),
              );
            },
          );
        },
      );
    }

    return _GeneratedBookCover(
      item: item,
      palette: palette,
      title: fallbackTitle,
    );
  }
}

class _GeneratedBookCover extends StatelessWidget {
  const _GeneratedBookCover({
    required this.item,
    required this.palette,
    required this.title,
  });

  final LibraryItem item;
  final List<Color> palette;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Ink(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette[0], palette[1]],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.format.toUpperCase(),
                style: TextStyle(
                  color: palette[2],
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          const Spacer(),
          RichText(
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              text: title,
              style: GoogleFonts.manrope(
                color: palette[2],
                fontSize: 18,
                height: 0.96,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.progress.clamp(0, 1).toDouble(),
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.38),
              color: palette[2],
            ),
          ),
        ],
      ),
    );
  }
}
