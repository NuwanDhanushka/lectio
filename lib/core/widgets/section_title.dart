import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    required this.actionLabel,
    this.isCompactLabel = false,
  });

  final String title;
  final String actionLabel;
  final bool isCompactLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: isCompactLabel
                ? const TextStyle(
                    letterSpacing: 1.3,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  )
                : const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4C587C),
                  ),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            actionLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4361EE),
            ),
          ),
        ),
      ],
    );
  }
}
