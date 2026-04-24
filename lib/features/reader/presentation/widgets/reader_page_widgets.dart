import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../library/domain/library_item.dart';
import '../../domain/reader_page_analysis.dart';

class ReaderEmptyState extends StatelessWidget {
  const ReaderEmptyState({super.key});

  static const _illustrationAsset = 'assets/images/no_pdf_open.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _illustrationAsset,
                  width: 260,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF2FA), Color(0xFFDCE4FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(42),
                        border: Border.all(color: const Color(0xFFE3E7F5)),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFF5368E8),
                        size: 76,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Text(
                  'No document open',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF202430),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Select a PDF from your library to start reading.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6F7585),
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class ReaderPdfViewerBody extends StatelessWidget {
  const ReaderPdfViewerBody({
    super.key,
    required this.item,
    required this.controller,
    required this.activeSpokenRange,
    required this.activeSpokenProgressRange,
    required this.searchMatchRange,
    required this.activeSpokenProgress,
    required this.onDocumentTap,
    required this.onViewerInteractionChanged,
    required this.onViewerReady,
    required this.onPageChanged,
  });

  final LibraryItem item;
  final PdfViewerController controller;
  final PdfPageTextRange? activeSpokenRange;
  final PdfPageTextRange? activeSpokenProgressRange;
  final PdfPageTextRange? searchMatchRange;
  final double activeSpokenProgress;
  final ValueChanged<PdfViewerGeneralTapHandlerDetails> onDocumentTap;
  final VoidCallback onViewerInteractionChanged;
  final PdfViewerReadyCallback onViewerReady;
  final PdfPageChangedCallback onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (!item.isPdf) {
      return const ReaderMessage(
        title: 'Preview not available',
        message: 'This reader currently supports PDF files.',
      );
    }

    if (item.filePath.isEmpty) {
      return const ReaderMessage(
        title: 'File missing',
        message: 'This library item does not have a local PDF path yet.',
      );
    }

    final file = File(item.filePath);
    if (!file.existsSync()) {
      return ReaderMessage(
        title: 'PDF not found',
        message: 'The file at "${item.filePath}" is no longer available.',
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD5DBEA)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: PdfViewer.file(
          item.filePath,
          controller: controller,
          params: PdfViewerParams(
            margin: 24,
            backgroundColor: const Color(0xFFE8ECF7),
            pageDropShadow: const BoxShadow(
              color: Color(0x22141D3A),
              blurRadius: 18,
              spreadRadius: 1,
              offset: Offset(0, 10),
            ),
            textSelectionParams: const PdfTextSelectionParams(),
            onGeneralTap: (context, controller, details) {
              if (details.type == PdfViewerGeneralTapType.doubleTap) {
                controller.zoomUp(loop: false).then((_) {
                  onViewerInteractionChanged();
                });
                return true;
              }

              if (details.type == PdfViewerGeneralTapType.tap &&
                  details.tapOn != PdfViewerPart.background) {
                onDocumentTap(details);
                return true;
              }

              return false;
            },
            onInteractionUpdate: (_) => onViewerInteractionChanged(),
            onInteractionEnd: (_) => onViewerInteractionChanged(),
            onViewerReady: onViewerReady,
            onPageChanged: onPageChanged,
            pagePaintCallbacks: [
              (canvas, pageRect, page) {
                final fullHighlight = activeSpokenRange;
                final progressHighlight = activeSpokenProgressRange;
                final searchHighlight = searchMatchRange;
                if (page.pageNumber != fullHighlight?.pageNumber &&
                    page.pageNumber != searchHighlight?.pageNumber) {
                  return;
                }

                final baseFillPaint = Paint()
                  ..color = const Color(0xFF4C63F5).withValues(alpha: 0.10)
                  ..style = PaintingStyle.fill;
                final progressFillPaint = Paint()
                  ..color = const Color(0xFF4C63F5).withValues(alpha: 0.30)
                  ..style = PaintingStyle.fill;
                final strokePaint = Paint()
                  ..color = const Color(0xFF4C63F5).withValues(alpha: 0.45)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2;
                final searchFillPaint = Paint()
                  ..color = const Color(0xFFFFC857).withValues(alpha: 0.45)
                  ..style = PaintingStyle.fill;
                final searchStrokePaint = Paint()
                  ..color = const Color(0xFFE3A400).withValues(alpha: 0.75)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2;

                if (fullHighlight != null &&
                    page.pageNumber == fullHighlight.pageNumber) {
                  for (final pdfRect in mergedHighlightRectsForRange(
                    fullHighlight,
                  )) {
                    final rect = pdfRect.toRectInDocument(
                      page: page,
                      pageRect: pageRect,
                    );
                    final rounded = RRect.fromRectAndRadius(
                      rect.inflate(1.5),
                      const Radius.circular(6),
                    );
                    canvas.drawRRect(rounded, baseFillPaint);
                    canvas.drawRRect(rounded, strokePaint);
                  }
                }

                if (searchHighlight != null &&
                    page.pageNumber == searchHighlight.pageNumber) {
                  for (final pdfRect in mergedHighlightRectsForRange(
                    searchHighlight,
                  )) {
                    final rect = pdfRect.toRectInDocument(
                      page: page,
                      pageRect: pageRect,
                    );
                    final rounded = RRect.fromRectAndRadius(
                      rect.inflate(1.8),
                      const Radius.circular(6),
                    );
                    canvas.drawRRect(rounded, searchFillPaint);
                    canvas.drawRRect(rounded, searchStrokePaint);
                  }
                }

                if (fullHighlight == null || progressHighlight == null) {
                  return;
                }

                for (final pdfRect in mergedHighlightRectsForRange(
                  progressHighlight,
                )) {
                  final rect = pdfRect.toRectInDocument(
                    page: page,
                    pageRect: pageRect,
                  );
                  final rounded = RRect.fromRectAndRadius(
                    rect.inflate(1.2),
                    const Radius.circular(6),
                  );
                  canvas.drawRRect(rounded, progressFillPaint);
                }

                final partialRect = partialHighlightRectForRange(
                  range: fullHighlight,
                  marker: karaokeProgressMarkerForText(
                    text: fullHighlight.text,
                    progress: activeSpokenProgress,
                  ),
                );
                if (partialRect == null) {
                  return;
                }

                final partialDocumentRect = partialRect.toRectInDocument(
                  page: page,
                  pageRect: pageRect,
                );
                final partialRounded = RRect.fromRectAndRadius(
                  partialDocumentRect.inflate(1.2),
                  const Radius.circular(6),
                );
                canvas.drawRRect(partialRounded, progressFillPaint);
              },
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderMessage extends StatelessWidget {
  const ReaderMessage({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDCE2F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 44,
              color: Color(0xFF4C63F5),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202430),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6F7585),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
