import 'package:flutter/material.dart';

class BubbleNavBar extends StatelessWidget {
  // 0: خانه, 1: نمونه سوال, 2: گام به گام, 3: پروفایل
  final int? currentIndex;
  final ValueChanged<int> onTap;
  const BubbleNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary; // از تم مرکزی
    final Color bubble = const Color(0xFFF1EEFF); // پس‌زمینه بیضی انتخاب‌شده

    Widget item({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final bool selected = currentIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTap(index),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: selected
                  ? EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  : EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? bubble : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: primary, size: 30),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
      textScaler: const TextScaler.linear(1.0),
                    style: TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 0, right: 0, top: 12, bottom: 4),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              // ترتیب: خانه، نمونه سوال، گام به گام، پروفایل
              item(index: 0, icon: Icons.home_rounded, label: 'خانه'),
              item(
                index: 1,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'نمونه سوالات',
              ),
              item(
                index: 2,
                icon: Icons.menu_book_outlined,
                label: 'گام به گام',
              ),
              item(
                index: 3,
                icon: Icons.person_outline_rounded,
                label: 'پروفایل',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
