import 'chapter.dart';

/// مدل فصل از JSON (استاتیک)
/// این مدل برای نمایش فصل‌هایی که در JSON تعریف شده‌اند استفاده می‌شود
class JsonChapter {
  final String chapterId; // شناسه فصل از JSON (مثل "1", "2")
  final String title; // عنوان فصل از JSON
  final String bookId; // شناسه کتاب (مثل "riazi", "olom")
  final int gradeId; // پایه

  JsonChapter({
    required this.chapterId,
    required this.title,
    required this.bookId,
    required this.gradeId,
  });

  /// تبدیل به Chapter قدیمی برای سازگاری (در صورت نیاز)
  /// ⚠️ این متد فقط برای سازگاری است و id و subjectOfferId را null می‌گذارد
  Chapter toLegacyChapter() {
    return Chapter(
      id: int.tryParse(chapterId) ?? 0,
      subjectOfferId: 0,
      chapterOrder: int.tryParse(chapterId) ?? 0,
      title: title,
      chapterImagePath: '',
      active: true,
    );
  }
}

