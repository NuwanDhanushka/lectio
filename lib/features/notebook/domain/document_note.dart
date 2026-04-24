enum DocumentNoteKind {
  summary,
  explanation,
  question,
}

class DocumentNote {
  const DocumentNote({
    this.id,
    required this.documentId,
    required this.kind,
    required this.pageNumber,
    this.sentenceIndex,
    this.sentenceText = '',
    this.outlineTitle = '',
    this.title = '',
    required this.body,
    required this.createdAt,
  });

  final int? id;
  final int? documentId;
  final DocumentNoteKind kind;
  final int pageNumber;
  final int? sentenceIndex;
  final String sentenceText;
  final String outlineTitle;
  final String title;
  final String body;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'kind': kind.name,
      'page_number': pageNumber,
      'sentence_index': sentenceIndex,
      'sentence_text': sentenceText,
      'outline_title': outlineTitle,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DocumentNote.fromMap(Map<String, Object?> map) {
    return DocumentNote(
      id: map['id'] as int?,
      documentId: map['document_id'] as int?,
      kind: DocumentNoteKind.values.firstWhere(
        (kind) => kind.name == map['kind'],
        orElse: () => DocumentNoteKind.summary,
      ),
      pageNumber: map['page_number'] as int,
      sentenceIndex: map['sentence_index'] as int?,
      sentenceText: (map['sentence_text'] as String?) ?? '',
      outlineTitle: (map['outline_title'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
