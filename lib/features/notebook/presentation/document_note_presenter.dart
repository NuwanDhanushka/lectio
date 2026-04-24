import 'package:flutter/material.dart';

import '../domain/document_note.dart';

class DocumentNoteGroup {
  const DocumentNoteGroup({
    required this.title,
    required this.notes,
  });

  final String title;
  final List<DocumentNote> notes;
}

List<DocumentNote> filterDocumentNotes(
  List<DocumentNote> notes,
  DocumentNoteKind? filter,
) {
  if (filter == null) {
    return notes;
  }
  return notes.where((note) => note.kind == filter).toList(growable: false);
}

List<DocumentNoteGroup> groupedDocumentNotes(List<DocumentNote> notes) {
  final groups = <String, List<DocumentNote>>{};
  for (final note in notes) {
    final title = note.outlineTitle.trim().isEmpty
        ? 'Unsectioned Notes'
        : note.outlineTitle;
    groups.putIfAbsent(title, () => []).add(note);
  }

  return groups.entries
      .map(
        (entry) => DocumentNoteGroup(
          title: entry.key,
          notes: entry.value,
        ),
      )
      .toList(growable: false);
}

String documentNoteKindLabel(DocumentNoteKind kind) {
  return switch (kind) {
    DocumentNoteKind.summary => 'Summary',
    DocumentNoteKind.explanation => 'Explanation',
    DocumentNoteKind.question => 'Question',
  };
}

IconData documentNoteIcon(DocumentNoteKind kind) {
  return switch (kind) {
    DocumentNoteKind.summary => Icons.summarize_rounded,
    DocumentNoteKind.explanation => Icons.psychology_alt_rounded,
    DocumentNoteKind.question => Icons.help_outline_rounded,
  };
}

String documentNoteClipboardText(DocumentNote note) {
  final buffer = StringBuffer()
    ..writeln(documentNoteKindLabel(note.kind))
    ..writeln('Page ${note.pageNumber}');
  if (note.outlineTitle.isNotEmpty) {
    buffer.writeln(note.outlineTitle);
  }
  if (note.sentenceText.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Source:')
      ..writeln(note.sentenceText);
  }
  buffer
    ..writeln()
    ..writeln(note.body);
  return buffer.toString().trim();
}

String documentNoteReferenceLabel(DocumentNote note) {
  final parts = <String>[
    if (note.outlineTitle.isNotEmpty) note.outlineTitle,
    'Page ${note.pageNumber}',
    if (note.sentenceIndex != null) 'Sentence ${note.sentenceIndex! + 1}',
  ];
  return parts.join(' • ');
}
