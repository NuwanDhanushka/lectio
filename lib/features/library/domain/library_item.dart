class LibraryItem {
  const LibraryItem({
    this.id,
    required this.title,
    this.fileName = '',
    this.filePath = '',
    this.format = 'PDF',
    this.progress = 0,
    this.fileSizeBytes = 0,
    DateTime? importedAt,
    DateTime? lastAccessedAt,
  })  : _importedAt = importedAt,
        _lastAccessedAt = lastAccessedAt;

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final int? id;
  final String title;
  final String fileName;
  final String filePath;
  final String format;
  final double progress;
  final int fileSizeBytes;
  final DateTime? _importedAt;
  final DateTime? _lastAccessedAt;

  DateTime get importedAt => _importedAt ?? _epoch;
  DateTime get lastAccessedAt => _lastAccessedAt ?? _epoch;
  bool get isPdf => format.toUpperCase() == 'PDF';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'file_name': fileName,
      'file_path': filePath,
      'format': format,
      'progress': progress,
      'file_size_bytes': fileSizeBytes,
      'imported_at': importedAt.toIso8601String(),
      'last_accessed_at': lastAccessedAt.toIso8601String(),
    };
  }

  factory LibraryItem.fromMap(Map<String, Object?> map) {
    return LibraryItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      format: map['format'] as String,
      progress: (map['progress'] as num).toDouble(),
      fileSizeBytes: map['file_size_bytes'] as int,
      importedAt: DateTime.parse(map['imported_at'] as String),
      lastAccessedAt: DateTime.parse(map['last_accessed_at'] as String),
    );
  }
}
