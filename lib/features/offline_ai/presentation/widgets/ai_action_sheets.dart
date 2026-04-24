import 'dart:async';

import 'package:flutter/material.dart';

class ReaderAiActionsSheet extends StatelessWidget {
  const ReaderAiActionsSheet({
    super.key,
    required this.hasSelectedSentence,
    required this.isModelReady,
    required this.hasNotebook,
    required this.onSummarizePage,
    required this.onExplainSentence,
    required this.onOpenNotebook,
  });

  final bool hasSelectedSentence;
  final bool isModelReady;
  final bool hasNotebook;
  final Future<void> Function() onSummarizePage;
  final Future<void> Function() onExplainSentence;
  final Future<void> Function()? onOpenNotebook;

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
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lectio AI',
                        style: TextStyle(
                          color: Color(0xFF202430),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Private offline reading help.',
                        style: TextStyle(
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
                  tooltip: 'Close AI actions',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _AiActionTile(
              icon: Icons.menu_book_rounded,
              title: 'Open notebook',
              subtitle: hasNotebook
                  ? 'Browse saved notes for this book.'
                  : 'Open a saved document to use notebook notes.',
              onPressed: hasNotebook ? onOpenNotebook : null,
            ),
            const SizedBox(height: 10),
            _AiActionTile(
              icon: Icons.summarize_rounded,
              title: 'Summarize page',
              subtitle: isModelReady
                  ? 'Create or open the saved page summary.'
                  : 'Download the AI model in Settings first.',
              onPressed: isModelReady ? onSummarizePage : null,
            ),
            const SizedBox(height: 10),
            _AiActionTile(
              icon: Icons.psychology_alt_rounded,
              title: 'Explain selected sentence',
              subtitle: !isModelReady
                  ? 'Download the AI model in Settings first.'
                  : hasSelectedSentence
                      ? 'Explain the sentence you tapped.'
                      : 'Tap a sentence in the PDF first.',
              onPressed: isModelReady && hasSelectedSentence
                  ? onExplainSentence
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiActionTile extends StatelessWidget {
  const _AiActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Material(
      color: isEnabled ? const Color(0xFFF4F6FF) : const Color(0xFFF6F7FB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isEnabled ? () => unawaited(onPressed!()) : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isEnabled
                    ? const Color(0xFF5368E8)
                    : const Color(0xFFADB4C4),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isEnabled
                            ? const Color(0xFF202430)
                            : const Color(0xFF8F96A6),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6F7585),
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isEnabled
                    ? const Color(0xFF5368E8)
                    : const Color(0xFFADB4C4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
