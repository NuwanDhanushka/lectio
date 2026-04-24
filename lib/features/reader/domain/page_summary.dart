class PageSummary {
  const PageSummary({
    this.id,
    required this.documentId,
    required this.pageNumber,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int? documentId;
  final int pageNumber;
  final String summary;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_number': pageNumber,
      'summary': summary,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PageSummary.fromMap(Map<String, Object?> map) {
    return PageSummary(
      id: map['id'] as int?,
      documentId: map['document_id'] as int?,
      pageNumber: map['page_number'] as int,
      summary: (map['summary'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
