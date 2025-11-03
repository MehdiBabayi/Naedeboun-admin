# 🔖 Bookmark: Mini-Request Lessons & Videos Fix

## 📋 کلیدواژه برای بازگشت
**کلیدواژه:** `mini-request-lessons-videos`

## 📝 خلاصه تغییرات

### مشکل:
- در صفحه Chapter Screen هیچ دیتایی نمایش داده نمی‌شد
- Home, Subject, نمونه سوال استانی و گام به گام درست کار می‌کردند
- اما Chapter Screen خالی بود

### راه حل:
اضافه کردن دانلود **lessons** و **videos** به Mini-Request Service

### تغییرات انجام شده:

#### 1. اضافه شدن Imports
```dart
import '../../models/content/lesson.dart';
import '../../models/content/lesson_video.dart';
```

#### 2. اضافه شدن متد `_loadLessonsMetadata`
- محل: `lib/services/mini_request/mini_request_service.dart`
- خطوط: 710-786
- عملکرد:
  - chapters را از Hive می‌خواند
  - برای هر chapter، lessons را از Supabase دانلود می‌کند
  - در Hive به صورت `{chapterId: [lessons]}` ذخیره می‌کند

#### 3. اضافه شدن متد `_loadVideosMetadata`
- محل: `lib/services/mini_request/mini_request_service.dart`
- خطوط: 788-864
- عملکرد:
  - lessons را از Hive می‌خواند
  - برای هر lesson، videos را از Supabase دانلود می‌کند
  - در Hive به صورت `{lessonId: [videos]}` ذخیره می‌کند

#### 4. فراخوانی در `checkForUpdates`
- بعد از `_loadChaptersMetadata` فراخوانی می‌شوند
- در دو حالت:
  - وقتی محتوای جدیدی پیدا می‌شود (خط 246-249)
  - حتی اگر محتوای جدیدی نباشد (خط 279-282)

## 🔍 فایل‌های تغییر یافته
- `lib/services/mini_request/mini_request_service.dart`

## 📊 ترتیب دانلود در Mini-Request
1. Subjects (از RPC `get_active_subjects_for_user`)
2. Chapters (برای تمام subjects)
3. **Lessons (برای تمام chapters)** ← اضافه شد
4. **Videos (برای تمام lessons)** ← اضافه شد
5. PDFs metadata
6. Banners
7. Teachers

## 🎯 انتظار از نتیجه
- Chapter Screen باید بتواند lessons و videos را از Hive بخواند
- صفحه دیگر نباید خالی باشد

## 🔄 اگر مشکل باقی ماند
- بررسی کن که آیا lessons و videos در Hive ذخیره می‌شوند (لاگ‌ها را چک کن)
- بررسی کن که `CachedContentService.getLessons` و `getLessonVideos` درست کار می‌کنند
- بررسی کن که آیا Mini-Request درست اجرا می‌شود و تمام مراحل را کامل می‌کند

## 📅 تاریخ
- ایجاد: 2025-01-31
- وضعیت: منتظر تست کاربر

---

**برای بازگشت به این بخش، فقط بگو: `mini-request-lessons-videos`**

