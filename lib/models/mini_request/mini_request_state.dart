/// وضعیت Mini-Request System
enum MiniRequestState {
  /// در حالت استراحت
  idle,

  /// در حال چک کردن تعداد محتوا از backend
  checking,

  /// در حال دانلود محتوای جدید
  downloading,

  /// در حال ذخیره‌سازی در Hive
  storing,

  /// عملیات با موفقیت تکمیل شد
  completed,

  /// خطا رخ داده است
  error,
}
