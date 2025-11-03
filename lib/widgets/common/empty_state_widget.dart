import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: padding ?? const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // آیکون اصلی با پس‌زمینه دایره‌ای
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: (iconColor ?? colorScheme.primary).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: iconColor ?? colorScheme.primary,
            ),
          ),

          const SizedBox(height: 18),

          // عنوان اصلی
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontFamily: 'IRANSansXFaNum',
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 9),

          // زیرعنوان
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
              fontFamily: 'IRANSansXFaNum',
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 23),

          // دکمه تزئینی (اختیاری)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'به زودی...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget های آماده برای استفاده در صفحات مختلف
class EmptyStateWidgets {
  static Widget noEducationContent(BuildContext context) {
    return EmptyStateWidget(
      title: 'در حال حاضر آموزشی منتشر نشده است',
      subtitle: 'محتوای آموزشی این بخش به زودی منتشر خواهد شد\nلطفاً صبر کنید',
      icon: Icons.school_rounded,
    );
  }

  static Widget noProvincialSamples(BuildContext context) {
    return EmptyStateWidget(
      title: 'نمونه سوالات این پایه به زودی اضافه خواهد شد',
      subtitle: '', // متن خالی
      icon: Icons.quiz_rounded,
    );
  }

  static Widget noStepByStepContent(BuildContext context) {
    return EmptyStateWidget(
      title: 'گام به گام‌های دروس این پایه به زودی اضافه خواهد شد',
      subtitle: '', // متن خالی
      icon: Icons.school_outlined,
    );
  }

  static Widget noChapterContent(BuildContext context) {
    return EmptyStateWidget(
      title: 'محتوای این فصل موجود نیست',
      subtitle: 'آموزش‌های این فصل به زودی منتشر خواهد شد',
      icon: Icons.menu_book_rounded,
    );
  }

  static Widget noLessonContent(BuildContext context) {
    return EmptyStateWidget(
      title: 'درس موجود نیست',
      subtitle: 'محتوای این درس به زودی منتشر خواهد شد',
      icon: Icons.play_lesson_rounded,
    );
  }

  static Widget noVideoContent(BuildContext context) {
    return EmptyStateWidget(
      title: 'ویدیو موجود نیست',
      subtitle: 'ویدیوهای آموزشی این بخش به زودی منتشر خواهد شد',
      icon: Icons.video_library_rounded,
    );
  }

  static Widget noPdfContent(BuildContext context) {
    return EmptyStateWidget(
      title: 'فایل PDF موجود نیست',
      subtitle: 'فایل‌های PDF این بخش به زودی منتشر خواهد شد',
      icon: Icons.picture_as_pdf_rounded,
    );
  }

  static Widget noGradeContent(BuildContext context) {
    return EmptyStateWidget(
      title: 'محتوایی برای این پایه موجود نیست',
      subtitle: 'لطفاً پایه دیگری را انتخاب کنید',
      icon: Icons.school_outlined,
    );
  }
}
