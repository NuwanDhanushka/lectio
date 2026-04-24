import 'dart:async';

import 'package:flutter/material.dart';

class AiResponseSheetFrame extends StatelessWidget {
  const AiResponseSheetFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF202430),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
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
                  tooltip: 'Close AI response',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class SummaryLoadingCard extends StatelessWidget {
  const SummaryLoadingCard({
    super.key,
    this.label = 'Summarizing offline...',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE2F0)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF5368E8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4E5668),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryMessageCard extends StatelessWidget {
  const SummaryMessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.isStreaming = false,
    this.actionLabel,
    this.onActionPressed,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.isSecondaryActionBusy = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isStreaming;
  final String? actionLabel;
  final Future<void> Function()? onActionPressed;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryActionPressed;
  final bool isSecondaryActionBusy;

  @override
  Widget build(BuildContext context) {
    final bulletLines = message
        .split(RegExp(r'\r?\n'))
        .map(cleanSummaryDisplayLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE2F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF5368E8), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF202430),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (actionLabel != null && onActionPressed != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => unawaited(onActionPressed!()),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (bulletLines.length <= 1)
            Text(
              bulletLines.isEmpty ? message : bulletLines.first,
              style: const TextStyle(
                color: Color(0xFF4E5668),
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              children: [
                for (final line in bulletLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 8, right: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF5368E8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(
                              color: Color(0xFF4E5668),
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (secondaryActionLabel != null &&
              onSecondaryActionPressed != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: isSecondaryActionBusy
                    ? null
                    : () => unawaited(onSecondaryActionPressed!()),
                icon: isSecondaryActionBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.note_add_outlined),
                label: Text(secondaryActionLabel!),
              ),
            ),
          ],
          if (isStreaming) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF5368E8),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Generating offline',
                  style: TextStyle(
                    color: Color(0xFF7D8494),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String cleanSummaryDisplayLine(String line) {
  return line
      .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
      .replaceAll(RegExp(r'<think>.*', dotAll: true), '')
      .replaceAll(RegExp(r'^\s*[-*•]+\s*'), '')
      .replaceAll(RegExp(r'^\s*\d+[\.)]\s*'), '')
      .replaceAll('**', '')
      .replaceAll('__', '')
      .trim();
}
