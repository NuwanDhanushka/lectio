import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../library/data/library_repository.dart';
import '../../library/domain/library_item.dart';
import '../data/notebook_export_service.dart';
import '../domain/document_note.dart';
import 'document_note_presenter.dart';
import 'widgets/document_notebook_widgets.dart';

export 'document_note_presenter.dart';

class DocumentNotebookSheet extends StatefulWidget {
  const DocumentNotebookSheet({
    super.key,
    required this.item,
    required this.repository,
    required this.onOpenNote,
  });

  final LibraryItem item;
  final LibraryRepository repository;
  final Future<void> Function(DocumentNote note) onOpenNote;

  @override
  State<DocumentNotebookSheet> createState() => _DocumentNotebookSheetState();
}

class _DocumentNotebookSheetState extends State<DocumentNotebookSheet> {
  final NotebookExportService _exportService = const NotebookExportService();
  late Future<List<DocumentNote>> _notesFuture;
  DocumentNoteKind? _activeFilter;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _reloadNotes();
  }

  void _reloadNotes() {
    _notesFuture = widget.repository.fetchDocumentNotes(widget.item);
  }

  Future<void> _copyNote(DocumentNote note) async {
    await Clipboard.setData(
        ClipboardData(text: documentNoteClipboardText(note)));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied note.')),
    );
  }

  Future<void> _deleteNote(DocumentNote note) async {
    await widget.repository.removeDocumentNote(note);
    if (!mounted) {
      return;
    }
    setState(_reloadNotes);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted note.')),
    );
  }

  Future<void> _exportNotebook(
    List<DocumentNote> notes,
    NotebookExportFormat format,
  ) async {
    if (notes.isEmpty || _isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });
    try {
      switch (format) {
        case NotebookExportFormat.pdf:
          await _exportService.shareNotebookPdf(
              item: widget.item, notes: notes);
        case NotebookExportFormat.docx:
          await _exportService.shareNotebookDocx(
            item: widget.item,
            notes: notes,
          );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export notebook.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _showNoteDetails(DocumentNote note) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return NotebookNoteDetailSheet(
          note: note,
          onGoToSource: () async {
            Navigator.of(context).pop();
            Navigator.of(this.context).pop();
            await widget.onOpenNote(note);
          },
          onCopy: () async {
            await _copyNote(note);
          },
          onDelete: () async {
            Navigator.of(context).pop();
            await _deleteNote(note);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.76,
        ),
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
            FutureBuilder<List<DocumentNote>>(
              future: _notesFuture,
              builder: (context, snapshot) {
                final notes = snapshot.data ?? const <DocumentNote>[];
                final filteredNotes = filterDocumentNotes(notes, _activeFilter);
                final isLoading =
                    snapshot.connectionState != ConnectionState.done;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NotebookHeader(
                      canExport: filteredNotes.isNotEmpty && !isLoading,
                      isExporting: _isExporting,
                      onExport: (format) =>
                          _exportNotebook(filteredNotes, format),
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 18),
                    NotebookFilterRow(
                      activeFilter: _activeFilter,
                      onFilterChanged: (filter) {
                        setState(() {
                          _activeFilter = filter;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: NotebookNotesList(
                        isLoading: isLoading,
                        notes: notes,
                        filteredNotes: filteredNotes,
                        onOpenDetails: _showNoteDetails,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
