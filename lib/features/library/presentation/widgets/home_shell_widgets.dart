import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecentListPlaceholder extends StatelessWidget {
  const RecentListPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Text(
        'Your current book is ready above. Import another document or reopen it to keep going.',
        style: TextStyle(
          fontSize: 15,
          color: Color(0xFF6F7585),
        ),
      ),
    );
  }
}

class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            letterSpacing: 1.3,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Lectio',
          style: GoogleFonts.manrope(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: const Color(0xFF202430),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search_rounded),
          color: const Color(0xFF4C63F5),
          iconSize: 29,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class HomeLoadingState extends StatelessWidget {
  const HomeLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
