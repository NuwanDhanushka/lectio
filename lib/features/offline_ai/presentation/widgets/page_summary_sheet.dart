import 'dart:async';

import 'package:flutter/material.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../../notebook/domain/document_note.dart';
import '../../data/offline_ai_inference_service.dart';
import '../../data/offline_ai_model_service.dart';
import 'ai_response_cards.dart';

class PageSummarySheet extends StatefulWidget {
  const PageSummarySheet({
    super.key,
    required this.item,
    required this.repository,
    required this.pageNumber,
    required this.pageText,
    required this.outlineTitleFuture,
    required this.aiModelState,
  });

  final LibraryItem item;
  final LibraryRepository? repository;
  final int pageNumber;
  final String pageText;
  final Future<String> outlineTitleFuture;
  final OfflineAiModelState aiModelState;

  @override
  State<PageSummarySheet> createState() => _PageSummarySheetState();
}

class _PageSummarySheetState extends State<PageSummarySheet> {
  StreamSubscription<String>? _summarySubscription;
  String _summaryText = '';
  String? _summaryError;
  bool _isSummarizing = false;
  bool _isCachedSummary = false;
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    if (widget.aiModelState.isReady) {
      _loadCachedSummary();
    }
  }

  @override
  void dispose() {
    _summarySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedSummary() async {
    final cached = await widget.repository?.fetchPageSummary(
      item: widget.item,
      pageNumber: widget.pageNumber,
    );
    if (!mounted) {
      return;
    }
    if (cached != null && cached.summary.trim().isNotEmpty) {
      setState(() {
        _summaryText = cached.summary;
        _isCachedSummary = true;
      });
      return;
    }

    _startSummaryStream();
  }

  Future<void> _regenerateSummary() async {
    await widget.repository?.removePageSummary(
      item: widget.item,
      pageNumber: widget.pageNumber,
    );
    if (!mounted) {
      return;
    }
    _startSummaryStream(force: true);
  }

  void _startSummaryStream({bool force = false}) {
    if (_isSummarizing && !force) {
      return;
    }

    _summarySubscription?.cancel();
    setState(() {
      _isSummarizing = true;
      _isCachedSummary = false;
      _summaryText = '';
      _summaryError = null;
    });
    _summarySubscription = OfflineAiInferenceService.instance
        .streamPageSummary(
      modelState: widget.aiModelState,
      pageText: widget.pageText,
    )
        .listen(
      (summary) {
        if (!mounted) {
          return;
        }
        setState(() {
          _summaryText = summary;
          _summaryError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _summaryError = error.toString();
          _isSummarizing = false;
        });
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        final finalSummary = _summaryText.trim();
        if (finalSummary.isNotEmpty) {
          unawaited(
            widget.repository?.savePageSummary(
              item: widget.item,
              pageNumber: widget.pageNumber,
              summary: finalSummary,
            ),
          );
        }
        setState(() {
          _isSummarizing = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isModelReady = widget.aiModelState.isReady;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page ${widget.pageNumber} summary',
                        style: const TextStyle(
                          color: Color(0xFF202430),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _summaryStatusLabel(isModelReady),
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
                  tooltip: 'Close summary',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!isModelReady)
              SummaryMessageCard(
                icon: Icons.cloud_download_outlined,
                title: 'Download the AI model first',
                message:
                    'Go to Settings and download ${widget.aiModelState.selectedModel.name}. After that, summaries will run offline on this device.',
              )
            else if (_summaryError != null)
              SummaryMessageCard(
                icon: Icons.error_outline_rounded,
                title: 'Could not summarize this page',
                message: _summaryError!,
              )
            else if (_summaryText.isEmpty)
              const SummaryLoadingCard()
            else
              SummaryMessageCard(
                icon: Icons.notes_rounded,
                title: _isSummarizing
                    ? 'Summary is writing...'
                    : _isCachedSummary
                        ? 'Saved summary'
                        : 'Summary',
                message: _summaryText,
                isStreaming: _isSummarizing,
                actionLabel: _isSummarizing ? null : 'Regenerate',
                onActionPressed: _isSummarizing ? null : _regenerateSummary,
                secondaryActionLabel:
                    _isSummarizing || widget.repository == null
                        ? null
                        : 'Save to Notebook',
                onSecondaryActionPressed:
                    _isSummarizing || widget.repository == null
                        ? null
                        : _saveSummaryToNotebook,
                isSecondaryActionBusy: _isSavingNote,
              ),
          ],
        ),
      ),
    );
  }

  String _summaryStatusLabel(bool isModelReady) {
    if (!isModelReady) {
      return 'Offline AI model required';
    }
    if (_isCachedSummary) {
      return 'Saved offline summary';
    }
    return '${widget.aiModelState.selectedModel.name} ready';
  }

  Future<void> _saveSummaryToNotebook() async {
    final repository = widget.repository;
    final summary = _summaryText.trim();
    if (repository == null || summary.isEmpty || _isSavingNote) {
      return;
    }

    setState(() {
      _isSavingNote = true;
    });
    final outlineTitle = await widget.outlineTitleFuture;
    final note = await repository.addDocumentNote(
      item: widget.item,
      kind: DocumentNoteKind.summary,
      pageNumber: widget.pageNumber,
      outlineTitle: outlineTitle,
      title: 'Page ${widget.pageNumber} summary',
      body: summary,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingNote = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          note == null
              ? 'Could not save note.'
              : 'Saved summary to this book notebook.',
        ),
      ),
    );
  }
}
