import 'package:flutter/material.dart';
import '../../theme/color_schemes.dart'; // اضافه کردن import برای AppColors

/// A reusable Persian numeric keypad for phone input.
/// Emits pressed digits via [onKeyTap], backspace via [onBackspace],
/// and optional submit via [onSubmit].
class PhoneKeypad extends StatelessWidget {
  final VoidCallback? onSubmit;
  final void Function(String digit) onKeyTap;
  final VoidCallback onBackspace;

  const PhoneKeypad({
    super.key,
    required this.onKeyTap,
    required this.onBackspace,
    this.onSubmit,
  });

  static const List<String> _digits = ['۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color keyBg = isDark ? AppColorSchemes.deepSlateBlue : AppColorSchemes.white; // رنگ پس‌زمینه دکمه‌ها
    final Color keyFg = isDark ? AppColorSchemes.white : AppColorSchemes.textPrimary; // رنگ متن

    Widget buildKey(Widget child, {VoidCallback? onTap}) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: keyBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      );
    }

    return Container(
      color: isDark ? AppColorSchemes.deepSlateBlue : AppColorSchemes.backgroundLight, // رنگ پس‌زمینه کل ویجت
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            for (int row = 0; row < 3; row++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  children: [
                    for (int col = 0; col < 3; col++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildKey(
                            Text(
                              _digits[row * 3 + (2 - col)],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: keyFg,
                                fontFamily: 'IRANSansXFaNum',
                              ),
                            ),
                            onTap: () => onKeyTap(_digits[row * 3 + (2 - col)]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: buildKey(
                        Transform.flip(
                          flipX: true, // جهت راست به چپ
                          child: Icon(
                            Icons.backspace_rounded, 
                            color: keyFg,
                          ),
                        ),
                        onTap: onBackspace,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: buildKey(
                        Text(
                          '۰',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: keyFg,
                            fontFamily: 'IRANSansXFaNum',
                          ),
                        ),
                        onTap: () => onKeyTap('۰'),
                      ),
                    ),
                  ),
                  // Removed submit button - only backspace and 0 remain
                  const Expanded(child: SizedBox()), // Empty space for layout balance
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


