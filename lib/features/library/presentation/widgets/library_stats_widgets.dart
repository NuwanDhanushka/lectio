import 'package:flutter/material.dart';

import '../../data/library_repository.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.footnote,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String footnote;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              color: Color(0xFF687087),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2433),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  footnote,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5F6881),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StorageCard extends StatelessWidget {
  const StorageCard({
    super.key,
    required this.totalBytes,
    required this.usageFraction,
  });

  final int totalBytes;
  final double usageFraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE4FF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SPACE USED',
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              color: Color(0xFF5E6882),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatStorageValue(totalBytes),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2433),
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  _formatStorageUnit(totalBytes),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2433),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 38),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: usageFraction,
              minHeight: 5,
              backgroundColor: const Color(0xFFEEF2FF),
              color: const Color(0xFF3C4C76),
            ),
          ),
        ],
      ),
    );
  }
}

class StatsGrid extends StatelessWidget {
  const StatsGrid({
    super.key,
    required this.snapshot,
  });

  final LibrarySnapshot snapshot;

  static const _softStorageLimitBytes = 5 * 1024 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    final usageFraction =
        (snapshot.totalBytes / _softStorageLimitBytes).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'ITEMS',
            value: '${snapshot.totalItems}',
            footnote: _updatedLabel(snapshot.lastSyncedAt),
            icon: Icons.history_rounded,
            backgroundColor: Colors.white,
            accentColor: const Color(0xFF4B587B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StorageCard(
            totalBytes: snapshot.totalBytes,
            usageFraction: usageFraction,
          ),
        ),
      ],
    );
  }
}

class ImportCard extends StatelessWidget {
  const ImportCard({
    super.key,
    required this.onTap,
    required this.isImporting,
  });

  final VoidCallback onTap;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isImporting ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF4357E7), Color(0xFF6272EE)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22435AE8),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const _ImportIcon(),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import New Document',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isImporting
                          ? 'Importing your file...'
                          : 'PDF, EPUB, or Text Files',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFFDCE0FF),
                      ),
                    ),
                  ],
                ),
              ),
              if (isImporting)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white70,
                  size: 32,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyLibraryCard extends StatelessWidget {
  const EmptyLibraryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your library is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF202430),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Import a PDF, EPUB, or text file to see it appear here.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6F7585),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportIcon extends StatelessWidget {
  const _ImportIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: CircleAvatar(
          radius: 13,
          backgroundColor: Colors.white,
          child: Icon(
            Icons.add_rounded,
            color: Color(0xFF4C63F5),
            size: 20,
          ),
        ),
      ),
    );
  }
}

String _updatedLabel(DateTime? syncedAt) {
  if (syncedAt == null) {
    return 'No sync yet';
  }

  final difference = DateTime.now().difference(syncedAt);

  if (difference.inMinutes < 1) {
    return 'Updated just now';
  }

  if (difference.inHours < 1) {
    return 'Updated ${difference.inMinutes}m ago';
  }

  if (difference.inDays < 1) {
    return 'Updated ${difference.inHours}h ago';
  }

  return 'Updated ${difference.inDays}d ago';
}

String _formatStorageValue(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
  }

  if (bytes >= 1024 * 1024) {
    return (bytes / (1024 * 1024)).toStringAsFixed(1);
  }

  if (bytes >= 1024) {
    return (bytes / 1024).toStringAsFixed(1);
  }

  return '$bytes';
}

String _formatStorageUnit(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return 'GB';
  }

  if (bytes >= 1024 * 1024) {
    return 'MB';
  }

  if (bytes >= 1024) {
    return 'KB';
  }

  return 'B';
}
