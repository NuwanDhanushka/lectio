import 'dart:async';

import 'package:flutter/material.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../../notebook/domain/document_note.dart';
import '../../data/offline_ai_model_service.dart';
import 'ai_response_cards.dart';

class AiStreamingResponseSheet extends StatefulWidget {
  const AiStreamingResponseSheet({
    super.key,
    required this.title,
    required this.readyLabel,
    required this.loadingLabel,
    required this.writingTitle,
    required this.doneTitle,
    required this.icon,
    required this.item,
    required this.repository,
    required this.noteKind,
    required this.pageNumber,
    required this.outlineTitleFuture,
    required this.aiModelState,
    required this.streamBuilder,
    this.sentenceIndex,
    this.sentenceText = '',
  });

  final String title;
  final String readyLabel;
  final String loadingLabel;
  final String writingTitle;
  final String doneTitle;
  final IconData icon;
  final LibraryItem? item;
  final LibraryRepository? repository;
  final DocumentNoteKind noteKind;
  final int pageNumber;
  final Future<String> outlineTitleFuture;
  final OfflineAiModelState aiModelState;
  final Stream<String> Function(OfflineAiModelState modelState) streamBuilder;
  final int? sentenceIndex;
  final String sentenceText;

  @override
  State<AiStreamingResponseSheet> createState() =>
      _AiStreamingResponseSheetState();
}

class _AiStreamingResponseSheetState extends State<AiStreamingResponseSheet> {
  StreamSubscription<String>? _subscription;
  String _responseText = '';
  String? _error;
  bool _isStreaming = false;
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    if (widget.aiModelState.isReady) {
      _startStream();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startStream() {
    setState(() {
      _isStreaming = true;
      _responseText = '';
      _error = null;
    });
    _subscription = widget.streamBuilder(widget.aiModelState).listen(
      (response) {
        if (!mounted) {
          return;
        }
        setState(() {
          _responseText = response;
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = error.toString();
          _isStreaming = false;
        });
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isStreaming = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AiResponseSheetFrame(
      title: widget.title,
      subtitle: widget.aiModelState.isReady
          ? widget.readyLabel
          : 'Offline AI model required',
      icon: widget.icon,
      child: !widget.aiModelState.isReady
          ? SummaryMessageCard(
              icon: Icons.cloud_download_outlined,
              title: 'Download the AI model first',
              message:
                  'Go to Settings and download ${widget.aiModelState.selectedModel.name}. After that, explanations will run offline on this device.',
            )
          : _error != null
              ? SummaryMessageCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not explain this sentence',
                  message: _error!,
                )
              : _responseText.isEmpty
                  ? SummaryLoadingCard(label: widget.loadingLabel)
                  : SummaryMessageCard(
                      icon: Icons.notes_rounded,
                      title:
                          _isStreaming ? widget.writingTitle : widget.doneTitle,
                      message: _responseText,
                      isStreaming: _isStreaming,
                      secondaryActionLabel:
                          _isStreaming || widget.repository == null
                              ? null
                              : 'Save to Notebook',
                      onSecondaryActionPressed:
                          _isStreaming || widget.repository == null
                              ? null
                              : _saveResponseToNotebook,
                      isSecondaryActionBusy: _isSavingNote,
                    ),
    );
  }

  Future<void> _saveResponseToNotebook() async {
    final repository = widget.repository;
    final item = widget.item;
    final body = _responseText.trim();
    if (repository == null || item == null || body.isEmpty || _isSavingNote) {
      return;
    }

    setState(() {
      _isSavingNote = true;
    });
    final outlineTitle = await widget.outlineTitleFuture;
    final note = await repository.addDocumentNote(
      item: item,
      kind: widget.noteKind,
      pageNumber: widget.pageNumber,
      sentenceIndex: widget.sentenceIndex,
      sentenceText: widget.sentenceText,
      outlineTitle: outlineTitle,
      title: widget.doneTitle,
      body: body,
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
              : 'Saved explanation to this book notebook.',
        ),
      ),
    );
  }
}
