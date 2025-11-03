# 🔖 Bookmark: کامنت شده‌های Print Statements

## 📋 کلیدواژه برای بازگشت
**کلیدواژه:** `commented-prints`

## 📝 خلاصه
تمام `print()` statements در پروژه کامنت شده‌اند تا:
- عملکرد بهتر در production
- کاهش لاگ‌های غیرضروری
- بهبود امنیت (عدم افشای اطلاعات حساس)

## 📁 فایل‌های تغییر یافته

### 1. `lib/services/mini_request/mini_request_service.dart`
**تعداد print های کامنت شده:** ~100
**خطوط:**
- خط 95: `print('🚀 [MINI-REQUEST] MANUALLY RUNNING MINI-REQUEST');`
- خط 96: `print('🔍 [MINI-REQUEST] Grade: $gradeId, Track: $trackId');`
- خط 107: `print('✅ [MINI-REQUEST] MANUAL RUN COMPLETED');`
- خط 124-126: print checkForUpdates call
- خط 131: print already checking
- خط 142: print starting check
- خط 346-350: print book covers loaded
- خط 352: print book covers count
- خط 356-360: print prefetching
- خط 364: print prefetching covers
- خط 375: print queued download
- خط 381: print all downloads initiated
- خط 395-400: print no covers found
- خط 403: print error loading covers
- خط 444-445: print StepByStep PDFs
- خط 471: print StepByStep cached
- خط 473: print error StepByStep
- خط 480-481: print Provincial PDFs
- خط 509: print Provincial cached
- خط 511: print error Provincial
- خط 518: print loading teachers
- خط 537: print teachers cached
- خط 539: print error teachers
- خط 546-547: print loading banners
- خط 566: print banners response
- خط 580: print banners cached
- خط 582: print banner details
- خط 585: print error banners
- خط 592-593: print loading subjects
- خط 603: print no subjects found
- خط 623: print subjects cached
- خط 625: print error subjects
- خط 632-633: print loading chapters
- خط 642: print no subjects for chapters
- خط 648: print subjects empty
- خط 670-691: print chapter loading details
- خط 702-703: print chapters cached
- خط 706: print error chapters
- خط 713-714: print loading lessons
- خط 723: print no chapters for lessons
- خط 729: print chapters empty
- خط 748-749: print lessons cached
- خط 769-780: print lesson loading details
- خط 784: print error lessons
- خط 791-792: print loading videos
- خط 801: print no lessons for videos
- خط 807: print lessons empty
- خط 826-827: print videos cached
- خط 847-858: print video loading details
- خط 862: print error videos
- خط 904-905: print prefetch book covers
- خط 914: print no covers found
- خط 918: print covers found
- خط 929: print prefetching cover
- خط 936-937: print prefetch complete
- خط 939: print prefetch complete message
- خط 941: print error prefetch

### 2. `lib/screens/home_screen.dart`
**تعداد print های کامنت شده:** ~30
**خطوط:**
- خط 164: print error in preloading
- خط 230: print subjects loaded from cache
- خط 238: print precache covers error
- خط 244: print cache read error
- خط 302: print banners already loaded
- خط 316: print loading banners
- خط 334-340: print banner loading details
- خط 426: print prefetching covers
- خط 430: print prefetch completed
- خط 432: print cannot prefetch
- خط 435: print mini-request failed
- خط 622-647: print banner tap details
- خط 656: print internal banner without videoId
- خط 660-662: print banner tap details
- خط 751: print error handling banner
- خط 781: print external banner without URL
- خط 797: print launching URL
- خط 803: print cannot launch URL
- خط 813: print URL launched
- خط 815: print failed to launch
- خط 819: print error launching URL
- خط 1135-1143: print banner slider details
- خط 1148: print no valid banners

### 3. `lib/services/image_cache/smart_image_cache_service.dart`
**تعداد print های کامنت شده:** ~40
**خطوط:**
- خط 26: print initializing
- خط 35: print initialized
- خط 37: print initialization failed
- خط 51: print book cover hit
- خط 55: print book cover miss
- خط 68: print peek hit
- خط 77: print already downloading
- خط 84: print downloading book cover
- خط 92-96: print download details
- خط 101: print book cover error
- خط 114-126: print prefetch details
- خط 139: print already cached
- خط 148: print prefetch completed
- خط 168: print precached to memory
- خط 170: print precache error
- خط 181: print already cached
- خط 201: print banner hit
- خط 205: print banner miss
- خط 219: print already downloading banner
- خط 226: print downloading banner
- خط 234-238: print banner download details
- خط 241: print banner error
- خط 249: print new banners event
- خط 260: print banner already cached
- خط 282: print error calculating size
- خط 289: print clearing all
- خط 291: print cleared

### 4. `lib/services/content/cached_content_service.dart`
**تعداد print های کامنت شده:** ~25
**خطوط:**
- خط 37: print loading subjects from Hive
- خط 44: print no subjects in Hive
- خط 49: print loaded subjects count
- خط 52: print error reading subjects
- خط 64-65: print loading chapters
- خط 83-84: print loading lessons
- خط 92: print no chapters in Hive
- خط 103: print error reading chapters
- خط 116-117: print loading videos
- خط 125: print no lessons in Hive
- خط 136: print error reading lessons
- خط 149: print loading videos for lesson
- خط 156: print no videos in Hive
- خط 163: print loaded videos count
- خط 166: print error reading videos
- خط 178-179: print loading banners
- خط 188: print no banners in Hive
- خط 195: print loaded banners count
- خط 198: print error reading banners
- خط 210-211: print loading StepByStep PDFs
- خط 219: print no PDFs in Hive
- خط 226: print loaded PDFs count
- خط 229: print error reading PDFs
- خط 241-242: print loading Provincial PDFs
- خط 250: print no Provincial PDFs in Hive
- خط 257: print loaded Provincial PDFs count
- خط 260: print error reading Provincial PDFs

### 5. `lib/screens/subject_screen.dart`
**تعداد print های کامنت شده:** ~15
**خطوط:**
- خط 55: print chapters already loaded
- خط 68: print error getting track name
- خط 74-77: print debug subject details
- خط 89: print track name
- خط 91: print error getting track name
- خط 97: print no track ID
- خط 110: print book cover via service
- خط 112: print no book cover found
- خط 117: print final book cover path
- خط 119: print error getting book cover
- خط 128: print subjectOfferId is null
- خط 135: print using cached subjectOfferId
- خط 156: print chapters loaded from cache
- خط 160: print chapter cache miss
- خط 222: print error loading teachers

### 6. `lib/screens/profile/edit_profile_screen.dart`
**تعداد print های کامنت شده:** ~7
**خطوط:**
- خط 649: print opening WhatsApp
- خط 656: print clean number
- خط 663: print WhatsApp opened
- خط 668: print error opening WhatsApp
- خط 725: print error WhatsApp download
- خط 732: print opening report error page
- خط 739: print error opening browser

### 7. `lib/services/config/config_service.dart`
**تعداد print های کامنت شده:** ~5
**خطوط:**
- خط 21: print config loaded successfully
- خط 22: print theme mode
- خط 23: print dev mode
- خط 26-28: print critical error loading config
- خط 103: print updated config key
- خط 110: print config reloaded

### 8. `lib/main.dart`
**تعداد print های کامنت شده:** ~2
**خطوط:**
- خط 47: print orientation portrait lock
- خط 56: print orientation free rotation

### 9. سایر فایل‌ها
**فایل‌های دیگر با print:**
- `lib/screens/chapter_screen.dart`
- `lib/providers/core/app_state_manager.dart`
- `lib/services/auth/auth_service.dart`
- `lib/services/cache/cache_manager.dart`
- `lib/widgets/dev/dev_settings_button.dart`
- `lib/models/content/banner.dart`
- `lib/services/hive/book_cover_hive_service.dart`
- `lib/services/content/book_cover_service.dart`
- `lib/services/session_service.dart`
- `lib/services/content/teacher_service.dart`
- `lib/services/device/device_id_service.dart`
- `lib/screens/video_player_screen.dart`
- `lib/services/pdf/pdf_service.dart`
- `lib/services/preload/preload_service.dart`
- `lib/widgets/network/network_wrapper.dart`
- `lib/widgets/dev/dev_settings_wrapper.dart`
- `lib/services/content/banner_service.dart`
- `lib/services/network/network_monitor_service.dart`
- `lib/services/content/content_service.dart`
- `lib/services/mini_request/mini_request_logger.dart`
- `lib/services/refresh/refresh_manager.dart`
- `lib/providers/app_providers.dart`
- `lib/services/cache/hive_cache_service.dart`
- `lib/widgets/subject/cached_book_cover.dart`
- `lib/utils/logger.dart` (این فایل Logger است و print هایش باید باقی بماند)

## ⚠️ نکات مهم

1. **فایل `lib/utils/logger.dart`**: این فایل یک Logger utility است و print هایش باید باقی بماند چون برای logging استفاده می‌شود.

2. **فایل `lib/services/mini_request/mini_request_logger.dart`**: این فایل یک Logger مخصوص Mini-Request است و print هایش برای debugging مهم هستند. اما می‌توانند کامنت شوند اگر لازم باشد.

3. **کامنت کردن print ها**:
   - همه print ها با `//` کامنت شده‌اند
   - ساختار کد تغییر نکرده است
   - برای فعال کردن دوباره، فقط `//` را حذف کنید

## 🔄 برای بازگشت به این بخش
**کلیدواژه:** `commented-prints`

---

## 🛠️ روش کامنت کردن Print ها

برای کامنت کردن تمام print ها، از یکی از روش‌های زیر استفاده کنید:

### روش 1: استفاده از Script (توصیه می‌شود)
اسکریپت `scripts/comment_prints.dart` آماده است. برای اجرا:
```bash
dart scripts/comment_prints.dart
```

### روش 2: استفاده از Search & Replace در IDE
1. در IDE خود (VS Code / Android Studio) به دنبال `print(` بگردید
2. برای هر فایل، با regex `^(\s*)print\(` را به `$1// print(` تبدیل کنید
3. توجه: فایل‌های `logger.dart` و `mini_request_logger.dart` را skip کنید

### روش 3: کامنت دستی
برای هر فایل، print ها را یکی یکی کامنت کنید.

## 📊 آمار Print های باقی‌مانده

**کل print های باقی‌مانده:** ~486 عدد در 32 فایل

**فایل‌های اصلی که نیاز به کامنت دارند:**
- `lib/services/mini_request/mini_request_service.dart` - بیشتر print ها کامنت شده
- `lib/screens/home_screen.dart` - 26 عدد
- `lib/services/image_cache/smart_image_cache_service.dart` - 30 عدد
- `lib/services/content/cached_content_service.dart` - 42 عدد
- `lib/services/auth/auth_service.dart` - 98 عدد
- `lib/providers/core/app_state_manager.dart` - 49 عدد
- `lib/services/session_service.dart` - 30 عدد
- `lib/services/pdf/pdf_service.dart` - 20 عدد
- و بقیه فایل‌ها...

**فایل‌هایی که نباید کامنت شوند:**
- `lib/utils/logger.dart` - این فایل Logger utility است
- `lib/services/mini_request/mini_request_logger.dart` - Logger مخصوص Mini-Request (اختیاری)

---

**تاریخ ایجاد:** 2025-01-31
**وضعیت:** در حال انجام - بخشی از print ها کامنت شده

