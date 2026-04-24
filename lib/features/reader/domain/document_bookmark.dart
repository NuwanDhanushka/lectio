class DocumentBookmark {
  const DocumentBookmark({
    this.id,
    required this.documentId,
    required this.pageNumber,
    this.sentenceIndex,
    this.sentenceText = '',
    this.label = '',
    this.note = '',
    required this.createdAt,
  });

  final int? id;
  final int? documentId;
  final int pageNumber;
  final int? sentenceIndex;
  final String sentenceText;
  final String label;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_number': pageNumber,
      'sentence_index': sentenceIndex,
      'sentence_text': sentenceText,
      'label': label,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DocumentBookmark.fromMap(Map<String, Object?> map) {
    return DocumentBookmark(
      id: map['id'] as int?,
      documentId: map['document_id'] as int?,
      pageNumber: map['page_number'] as int,
      sentenceIndex: map['sentence_index'] as int?,
      sentenceText: (map['sentence_text'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
