import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.isVisible = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: isVisible ? 120 : 0,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: isVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: isVisible ? Offset.zero : const Offset(0, 1.15),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: isVisible ? 1 : 0,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x10151D36),
                        blurRadius: 22,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        onTap: () => onTap(0),
                        icon: Icons.library_books_outlined,
                        label: 'LIBRARY',
                        isSelected: selectedIndex == 0,
                      ),
                      _NavItem(
                        onTap: () => onTap(1),
                        icon: Icons.menu_book_outlined,
                        label: 'READING',
                        isSelected: selectedIndex == 1,
                      ),
                      _NavItem(
                        onTap: () => onTap(2),
                        icon: Icons.bar_chart_rounded,
                        label: 'ACTIVITY',
                        isSelected: selectedIndex == 2,
                      ),
                      _NavItem(
                        onTap: () => onTap(3),
                        icon: Icons.settings_outlined,
                        label: 'SETTINGS',
                        isSelected: selectedIndex == 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color:
                isSelected ? const Color(0xFF2C66F0) : const Color(0xFF565C69),
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: isSelected
                  ? const Color(0xFF2C66F0)
                  : const Color(0xFF707481),
            ),
          ),
        ],
      ),
    );

    if (!isSelected) {
      return child;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C66F0), width: 2),
      ),
      child: child,
    );
  }
}
