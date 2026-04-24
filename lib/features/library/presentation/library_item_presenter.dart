import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/library_item.dart';

IconData libraryItemIcon(LibraryItem item) {
  switch (item.format) {
    case 'PDF':
      return Icons.description_outlined;
    case 'EPUB':
      return Icons.menu_book_outlined;
    case 'TXT':
      return Icons.notes_rounded;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

String libraryItemAccessLabel(
  LibraryItem item, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
  final accessDay = DateTime(
    item.lastAccessedAt.year,
    item.lastAccessedAt.month,
    item.lastAccessedAt.day,
  );
  final difference = today.difference(accessDay).inDays;

  if (difference == 0) {
    return 'Today';
  }

  if (difference == 1) {
    return 'Yesterday';
  }

  return DateFormat('MMM d, yyyy').format(item.lastAccessedAt);
}
