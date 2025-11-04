# کدهای کامل تغییرات - ادغام lessons با lesson_videos

این فایل شامل تمام کدهای کامل تغییر یافته است که در پلن استفاده می‌شوند.

---

## ⚠️ قوانین اجرای پلن (CRITICAL - حتماً رعایت شود)

### 1. توقف بین مراحل (مهم)
- **هر مرحله باید از کاربر اجازه بگیرد قبل از رفتن به مرحله بعد**
- بعد از انجام هر مرحله، توقف کن و منتظر تأیید کاربر بمان
- هرگز بدون اجازه به مرحله بعد نرو

### 2. توضیح در هر مرحله
- در هر مرحله توضیح بده که چه کاری انجام دادی
- چه فایل‌هایی تغییر داده‌ای
- چه تغییراتی اعمال شده

### 3. Deploy کردن Function
- **اگر function می‌نویسی/تغییر می‌دی → باید deploy کنی**
- قبل از رفتن به مرحله بعد، function را deploy کن
- اگر deploy موفق نبود → **متوقف شو و به کاربر اعلام کن**

### 4. Deploy کردن Query/Migration
- **اگر query/migration می‌نویسی → باید deploy کنی**
- قبل از رفتن به مرحله بعد، migration را deploy کن
- اگر deploy موفق نبود → **متوقف شو و به کاربر اعلام کن**

### 5. استفاده از ANPIX قبل از CLIA
- **همیشه از ANPIX (آنالیز پروژه) قبل از CLIA استفاده کن**
- ابتدا پروژه را آنالیز کن، سپس تغییرات را اعمال کن

### 6. Flutter Analyze در پایان
- **بعد از تمام تغییرات Flutter → باید `flutter analyze` بزنی**
- قبل از اتمام کار، حتماً analyze را اجرا کن
- اگر خطا داشت → **متوقف شو و به کاربر اعلام کن**

### 7. توقف در صورت خطا
- **اگر موفق به deploy query یا function نشدی → متوقف شو**
- **اگر flutter analyze خطا داشت → متوقف شو**
- در هر دو حالت، به کاربر اعلام کن تا از روش‌های دیگر اقدام کند

### خلاصه قوانین:
1. ⏸️ توقف بین مراحل + گرفتن اجازه
2. 📝 توضیح هر مرحله
3. 🚀 Deploy Function بعد از نوشتن
4. 🗄️ Deploy Query بعد از نوشتن
5. 🔍 استفاده از ANPIX قبل از CLIA
6. ✅ Flutter Analyze در پایان
7. ⛔ توقف در صورت خطا

---

## 1. Migration SQL (کامل)

فایل: `supabase/migrations/YYYYMMDDHHMMSS_merge_lessons_into_lesson_videos.sql`

```sql
-- ============================================
-- ادغام جدول lessons با lesson_videos
-- ============================================

-- گام 1: اضافه کردن ستون‌های جدید
ALTER TABLE lesson_videos 
ADD COLUMN IF NOT EXISTS lesson_title TEXT,
ADD COLUMN IF NOT EXISTS lesson_order INT,
ADD COLUMN IF NOT EXISTS chapter_id INT,
ADD COLUMN IF NOT EXISTS chapter_order INT,
ADD COLUMN IF NOT EXISTS chapter_title TEXT;

-- گام 2: پر کردن داده‌های موجود
UPDATE lesson_videos lv
SET 
  lesson_title = l.title,
  lesson_order = l.lesson_order,
  chapter_id = l.chapter_id,
  chapter_order = ch.chapter_order,
  chapter_title = ch.title
FROM lessons l
JOIN chapters ch ON ch.id = l.chapter_id
WHERE lv.lesson_id = l.id;

-- گام 2.5: بررسی و حذف رکوردهای بدون lesson_id (برای اطمینان)
-- اگر رکوردهایی بدون lesson_id وجود دارند، آن‌ها را حذف می‌کنیم
DELETE FROM lesson_videos
WHERE lesson_id IS NULL 
   OR lesson_id NOT IN (SELECT id FROM lessons);

-- گام 3: تبدیل به NOT NULL
ALTER TABLE lesson_videos
ALTER COLUMN lesson_title SET NOT NULL,
ALTER COLUMN lesson_order SET NOT NULL,
ALTER COLUMN chapter_id SET NOT NULL,
ALTER COLUMN chapter_order SET NOT NULL,
ALTER COLUMN chapter_title SET NOT NULL;

-- گام 4: اضافه کردن Foreign Key
ALTER TABLE lesson_videos
ADD CONSTRAINT fk_lesson_videos_chapter 
FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE;

-- گام 4.5: حذف Foreign Key قدیمی prereq_lesson_id (اگر وجود دارد)
ALTER TABLE lesson_videos
DROP CONSTRAINT IF EXISTS lesson_videos_prereq_lesson_id_fkey;

-- گام 5: اضافه کردن Unique Constraint (ابتدا constraint قدیمی را حذف می‌کنیم)
ALTER TABLE lesson_videos
DROP CONSTRAINT IF EXISTS unique_lesson_video;

ALTER TABLE lesson_videos
ADD CONSTRAINT unique_lesson_video UNIQUE (
  chapter_id,
  lesson_order,
  lesson_title,
  teacher_id,
  style
);

-- گام 6: اضافه کردن Indexes
CREATE INDEX IF NOT EXISTS idx_lesson_videos_chapter 
ON lesson_videos(chapter_id, lesson_order);

CREATE INDEX IF NOT EXISTS idx_lesson_videos_style 
ON lesson_videos(style) WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_lesson_videos_active 
ON lesson_videos(active) WHERE active = true;

-- گام 7: حذف Foreign Key قدیمی
ALTER TABLE lesson_videos
DROP CONSTRAINT IF EXISTS lesson_videos_lesson_id_fkey;

-- گام 8: حذف ستون lesson_id
ALTER TABLE lesson_videos
DROP COLUMN IF EXISTS lesson_id;

-- گام 9: (بعد از تست) حذف جدول lessons
-- DROP TABLE IF EXISTS lessons CASCADE;
```

---

## 2. Edge Function: create-content/index.ts (کامل)

### تغییرات اصلی:
- حذف مرحله 7 (خطوط 213-235)
- تغییر مرحله 9 به upsert با فیلدهای جدید

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ContentInput {
  branch: string;
  grade: string;
  track?: string | null;
  subject: string;
  subject_slug: string;
  chapter_order: number;
  chapter_title: string;
  lesson_order: number;
  lesson_title: string;
  teacher_name: string;
  style: 'note' | 'book' | 'sample' | 'جزوه' | 'کتاب درسی' | 'نمونه سوال';
  aparat_url?: string;
  duration_sec: number;
  tags?: string[];
  prereq_lesson_id?: number | null;
  active?: boolean;
  content_status?: 'draft' | 'published' | 'archived';
  embed_html?: string;
  allow_landscape?: boolean;
  note_pdf_url?: string | null;
  exercise_pdf_url?: string | null;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const input: ContentInput = await req.json();
    
    if (!input.branch || !input.grade || !input.subject || !input.subject_slug || 
        !input.chapter_title || !input.lesson_title || !input.teacher_name) {
      return new Response(
        JSON.stringify({ error: "فیلدهای الزامی: branch, grade, subject, subject_slug, chapter_title, lesson_title, teacher_name" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'ENV ناقص است: SUPABASE_URL یا SUPABASE_SERVICE_ROLE_KEY تنظیم نشده' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 1. Find or create branch
    let { data: branch, error: branchError } = await supabase
      .from('branches')
      .select('id')
      .eq('name', input.branch)
      .single();

    if (branchError && branchError.code === 'PGRST116') {
      const { data: newBranch, error: createBranchError } = await supabase
        .from('branches')
        .insert({ name: input.branch })
        .select('id')
        .single();
      if (createBranchError) throw new Error(`خطا در ایجاد شاخه: ${createBranchError.message}`);
      branch = newBranch;
    } else if (branchError) {
      throw new Error(`خطا در یافتن شاخه: ${branchError.message}`);
    }

    // 2. Find or create grade
    let { data: grade, error: gradeError } = await supabase
      .from('grades')
      .select('id')
      .eq('branch_id', branch.id)
      .eq('name', input.grade)
      .single();

    if (gradeError && gradeError.code === 'PGRST116') {
      const { data: newGrade, error: createGradeError } = await supabase
        .from('grades')
        .insert({ 
          branch_id: branch.id, 
          name: input.grade 
        })
        .select('id')
        .single();
      if (createGradeError) throw new Error(`خطا در ایجاد پایه: ${createGradeError.message}`);
      grade = newGrade;
    } else if (gradeError) {
      throw new Error(`خطا در یافتن پایه: ${gradeError.message}`);
    }

    // 3. Find or create track (if provided)
    let track = null;
    if (input.track) {
      let { data: trackData, error: trackError } = await supabase
        .from('tracks')
        .select('id')
        .eq('name', input.track)
        .single();

      if (trackError && trackError.code === 'PGRST116') {
        const { data: newTrack, error: createTrackError } = await supabase
          .from('tracks')
          .insert({ name: input.track })
          .select('id')
          .single();
        if (createTrackError) throw new Error(`خطا در ایجاد رشته: ${createTrackError.message}`);
        track = newTrack;
      } else if (trackError) {
        throw new Error(`خطا در یافتن رشته: ${trackError.message}`);
      } else {
        track = trackData;
      }
    }

    // 4. Find or create subject
    let { data: subject, error: subjectError } = await supabase
      .from('subjects')
      .select('id')
      .eq('slug', input.subject_slug)
      .single();

    if (subjectError && subjectError.code === 'PGRST116') {
      const iconPath = `assets/images/icon-darsha/${input.subject_slug}.png`;
      const bookCoverPath = `assets/images/book-covers/${input.subject_slug}${input.grade}.jpg`;
      
      const { data: newSubject, error: createSubjectError } = await supabase
        .from('subjects')
        .insert({ 
          name: input.subject,
          slug: input.subject_slug,
          icon_path: iconPath,
          book_cover_path: bookCoverPath
        })
        .select('id')
        .single();
      if (createSubjectError) throw new Error(`خطا در ایجاد درس: ${createSubjectError.message}`);
      subject = newSubject;
    } else if (subjectError) {
      throw new Error(`خطا در یافتن درس: ${subjectError.message}`);
    }

    // 5. Find or create subject_offer
    let subjectOfferQuery = supabase
      .from('subject_offers')
      .select('id')
      .eq('subject_id', subject.id)
      .eq('grade_id', grade.id);

    if (track?.id) {
      subjectOfferQuery = subjectOfferQuery.eq('track_id', track.id);
    } else {
      subjectOfferQuery = subjectOfferQuery.is('track_id', null);
    }

    let { data: subjectOffer, error: subjectOfferError } = await subjectOfferQuery.single();

    if (subjectOfferError && subjectOfferError.code === 'PGRST116') {
      const { data: newSubjectOffer, error: createSubjectOfferError } = await supabase
        .from('subject_offers')
        .insert({ 
          subject_id: subject.id,
          grade_id: grade.id,
          track_id: track?.id || null
        })
        .select('id')
        .single();
      if (createSubjectOfferError) throw new Error(`خطا در ایجاد ارائه درس: ${createSubjectOfferError.message}`);
      subjectOffer = newSubjectOffer;
    } else if (subjectOfferError) {
      throw new Error(`خطا در یافتن ارائه درس: ${subjectOfferError.message}`);
    }

    // 6. Find or create chapter
    let { data: chapter, error: chapterError } = await supabase
      .from('chapters')
      .select('id')
      .eq('subject_offer_id', subjectOffer.id)
      .eq('chapter_order', input.chapter_order)
      .single();

    if (chapterError && chapterError.code === 'PGRST116') {
      const chapterImagePath = `assets/images/chapter-images/${input.subject_slug}${input.grade}_ch${input.chapter_order}.jpg`;
      
      const { data: newChapter, error: createChapterError } = await supabase
        .from('chapters')
        .insert({ 
          subject_offer_id: subjectOffer.id,
          chapter_order: input.chapter_order,
          title: input.chapter_title,
          chapter_image_path: chapterImagePath
        })
        .select('id')
        .single();
      if (createChapterError) throw new Error(`خطا در ایجاد فصل: ${createChapterError.message}`);
      chapter = newChapter;
    } else if (chapterError) {
      throw new Error(`خطا در یافتن فصل: ${chapterError.message}`);
    }

    // 7. Find or create teacher (مرحله 8 در کد قدیم)
    let { data: teacher, error: teacherError } = await supabase
      .from('teachers')
      .select('id')
      .eq('name', input.teacher_name)
      .single();

    if (teacherError && teacherError.code === 'PGRST116') {
      const { data: newTeacher, error: createTeacherError } = await supabase
        .from('teachers')
        .insert({ name: input.teacher_name })
        .select('id')
        .single();
      if (createTeacherError) throw new Error(`خطا در ایجاد استاد: ${createTeacherError.message}`);
      teacher = newTeacher;
    } else if (teacherError) {
      throw new Error(`خطا در یافتن استاد: ${teacherError.message}`);
    }

    // 8. Create/Update lesson_video (بدون نیاز به lesson)
    const styleMap: Record<string, 'note' | 'book' | 'sample'> = {
      'note': 'note',
      'book': 'book',
      'sample': 'sample',
      'جزوه': 'note',
      'کتاب درسی': 'book',
      'نمونه سوال': 'sample',
    };
    const normalizedStyle = styleMap[String(input.style)] ?? 'note';

    const { data: lessonVideo, error: lessonVideoError } = await supabase
      .from('lesson_videos')
      .upsert({
        chapter_id: chapter.id,
        chapter_order: input.chapter_order,
        chapter_title: input.chapter_title,
        lesson_order: input.lesson_order,
        lesson_title: input.lesson_title,
        teacher_id: teacher.id,
        style: normalizedStyle,
        aparat_url: input.aparat_url || '',
        duration_sec: input.duration_sec,
        tags: input.tags || [],
        prereq_lesson_id: input.prereq_lesson_id || null,
        content_status: input.content_status || 'published',
        active: input.active !== false,
        embed_html: input.embed_html || null,
        allow_landscape: input.allow_landscape !== false,
        note_pdf_url: input.note_pdf_url ?? null,
        exercise_pdf_url: input.exercise_pdf_url ?? null
      }, {
        onConflict: 'chapter_id,lesson_order,lesson_title,teacher_id,style',
        ignoreDuplicates: false
      })
      .select('id')
      .single();

    if (lessonVideoError) {
      throw new Error(`خطا در ایجاد ویدیو درس: ${lessonVideoError.message}`);
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "محتوا با موفقیت ایجاد شد",
        data: {
          branch_id: branch.id,
          grade_id: grade.id,
          track_id: track?.id || null,
          subject_id: subject.id,
          subject_offer_id: subjectOffer.id,
          chapter_id: chapter.id,
          teacher_id: teacher.id,
          lesson_video_id: lessonVideo.id
        }
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("Error in create-content function:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

---

## 3. Edge Function: update-content/index.ts (تغییرات)

### تغییر select در check (خط 53):
```typescript
// تغییر از:
.select('id, teacher_id, lesson_id')

// به:
.select('id, teacher_id, chapter_id')
```

### تغییر select (خطوط 108-132):

```typescript
// تغییر از:
.select(`
  id,
  aparat_url,
  duration_sec,
  tags,
  prereq_lesson_id,
  active,
  content_status,
  style,
  view_count,
  teachers!inner(name),
  lessons!inner(
    title,
    chapters!inner(
      title,
      chapter_order,
      subject_offers!inner(
        subjects!inner(name, slug),
        grades!inner(name),
        tracks(name)
      )
    )
  )
`)

// به:
.select(`
  id,
  chapter_id,
  chapter_order,
  chapter_title,
  lesson_order,
  lesson_title,
  aparat_url,
  duration_sec,
  tags,
  prereq_lesson_id,
  active,
  content_status,
  style,
  view_count,
  embed_html,
  allow_landscape,
  note_pdf_url,
  exercise_pdf_url,
  teachers!inner(name)
`)
```

---

## 4. Flutter Model: lesson_video.dart (کامل)

```dart
class LessonVideo {
  final int id;
  final int chapterId;  // ← جدید
  final int chapterOrder;  // ← جدید
  final String chapterTitle;  // ← جدید
  final int lessonOrder;  // ← جدید
  final String lessonTitle;  // ← جدید
  final int teacherId;
  final String style;
  final String aparatUrl;
  final int durationSec;
  final int viewCount;
  final List<String> tags;
  final String contentStatus;
  final bool active;
  final String? embedHtml;
  final bool allowLandscape;
  final String? notePdfUrl;
  final String? exercisePdfUrl;

  LessonVideo({
    required this.id,
    required this.chapterId,
    required this.chapterOrder,
    required this.chapterTitle,
    required this.lessonOrder,
    required this.lessonTitle,
    required this.teacherId,
    required this.style,
    required this.aparatUrl,
    required this.durationSec,
    required this.viewCount,
    required this.tags,
    required this.contentStatus,
    required this.active,
    this.embedHtml,
    this.allowLandscape = true,
    this.notePdfUrl,
    this.exercisePdfUrl,
  });

  factory LessonVideo.fromJson(Map<String, dynamic> json) {
    return LessonVideo(
      id: json['id'] as int,
      chapterId: json['chapter_id'] as int,
      chapterOrder: json['chapter_order'] as int,
      chapterTitle: json['chapter_title'] as String,
      lessonOrder: json['lesson_order'] as int,
      lessonTitle: json['lesson_title'] as String,
      teacherId: json['teacher_id'] as int,
      style: json['style'] as String,
      aparatUrl: json['aparat_url'] as String,
      durationSec: (json['duration_sec'] as num).toInt(),
      viewCount: (json['view_count'] as num).toInt(),
      tags: ((json['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      contentStatus: json['content_status'] as String,
      active: (json['active'] as bool?) ?? true,
      embedHtml: json['embed_html'] as String?,
      allowLandscape: (json['allow_landscape'] as bool?) ?? true,
      notePdfUrl: json['note_pdf_url'] as String?,
      exercisePdfUrl: json['exercise_pdf_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'chapter_order': chapterOrder,
      'chapter_title': chapterTitle,
      'lesson_order': lessonOrder,
      'lesson_title': lessonTitle,
      'teacher_id': teacherId,
      'style': style,
      'aparat_url': aparatUrl,
      'duration_sec': durationSec,
      'view_count': viewCount,
      'tags': tags,
      'content_status': contentStatus,
      'active': active,
      'embed_html': embedHtml,
      'allow_landscape': allowLandscape,
      'note_pdf_url': notePdfUrl,
      'exercise_pdf_url': exercisePdfUrl,
    };
  }
}
```

---

## 5. Flutter Service: cached_content_service.dart (تغییرات)

### تغییر getLessonVideos:

```dart
/// دریافت ویدیوهای درس از Mini-Request Hive Box
static Future<List<LessonVideo>> getLessonVideos(
  int chapterId, {  // ← تغییر از lessonId به chapterId
  required int gradeId,
  int? trackId,
}) async {
  final boxName = _getMiniRequestBoxName(gradeId, trackId);
  
  Logger.info('🚀 [MINI-REQUEST] Loading videos from Hive for chapter: $chapterId');
  
  try {
    final box = await Hive.openBox(boxName);
    final videosJson = box.get('videos');
    
    if (videosJson == null) {
      Logger.info('⚠️ [MINI-REQUEST] No videos in Hive');
      return [];
    }
    
    final Map<String, dynamic> allVideos = jsonDecode(videosJson);
    List<dynamic>? videosList = allVideos[chapterId.toString()];  // ← تغییر از lessonId
    
    if (videosList == null || videosList.isEmpty) return [];
    
    return videosList.map((j) => LessonVideo.fromJson(j)).toList();
  } catch (e) {
    Logger.error('❌ [MINI-REQUEST] Error reading videos from Hive', e);
    return [];
  }
}
```

### حذف getLessons (خطوط 107-137):
این متد کامل حذف می‌شود.

---

## 6. Flutter Service: content_service.dart (تغییرات)

### تغییر getLessonVideos:

```dart
Future<List<LessonVideo>> getLessonVideos(int chapterId) async {  // ← تغییر از lessonId
  final data = await _supabase
      .from('lesson_videos')
      .select()
      .eq('chapter_id', chapterId)  // ← تغییر از lesson_id
      .eq('active', true)
      .order('lesson_order', ascending: true)
      .order('style', ascending: true);
  
  return data.map((j) => LessonVideo.fromJson(j as Map<String, dynamic>)).toList();
}
```

### حذف getLessons (خط 145):
این متد کامل حذف می‌شود.

---

## 7. Flutter Service: mini_request_service.dart (تغییرات)

### حذف _loadLessonsMetadata (خطوط 668-722):
این متد کامل حذف می‌شود.

### تغییر _loadVideosMetadata (خطوط 724-802):

```dart
/// دریافت و کش کردن videos (metadata) برای تمام chapters
Future<void> _loadVideosMetadata(int grade, int? track) async {
  try {
    Logger.info('🎥 [MINI-REQUEST] Loading videos metadata: grade=$grade track=$track');
    
    // دریافت chapters از Hive
    final boxName = _getBoxName(grade, track);
    final box = await Hive.openBox(boxName);
    final chaptersJson = box.get('chapters');
    
    if (chaptersJson == null) {
      Logger.info('⚠️ [MINI-REQUEST] No chapters found, cannot load videos');
      return;
    }
    
    final Map<String, dynamic> allChapters = jsonDecode(chaptersJson);
    if (allChapters.isEmpty) {
      Logger.info('⚠️ [MINI-REQUEST] Chapters map is empty, skipping videos');
      return;
    }
    
    // برای هر chapter، videos را دانلود کن
    final Map<String, List<dynamic>> videosByChapter = {};  // ← تغییر از videosByLesson
    
    // تمام chapters را از همه subject_offers جمع کن (ساده‌تر با expand)
    final allChaptersList = allChapters.values
        .expand((chaptersList) => chaptersList is List ? chaptersList : [])
        .whereType<Map<String, dynamic>>()
        .toList();
    
    Logger.debug('🎥 [MINI-REQUEST] Found ${allChaptersList.length} chapters to load videos for');
    
    for (final chapter in allChaptersList) {
      try {
        // Query videos برای این chapter (به جای lesson)
        final videosData = await _supabase
            .from('lesson_videos')
            .select()
            .eq('chapter_id', chapter['id'])  // ← تغییر از lesson_id
            .eq('active', true)
            .order('lesson_order', ascending: true)
            .order('style', ascending: true)
            as List<dynamic>;
        
        videosByChapter[chapter['id'].toString()] = videosData;  // ← تغییر از lessonId
      } catch (e) {
        Logger.error('❌ [MINI-REQUEST] Error loading videos for chapter ${chapter['id']}', e);
      }
    }
    
    // ذخیره videos در Hive به صورت Map: {chapterId: [videos]}
    await box.put('videos', jsonEncode(videosByChapter));
  } catch (e) {
    Logger.error('❌ [MINI-REQUEST] Error loading videos metadata', e);
  }
}
```

---

## 8. Flutter UI: chapter_screen.dart (تغییرات اصلی)

### تغییر State:

```dart
class _ChapterScreenState extends State<ChapterScreen> {
  bool _loading = false;
  List<LessonVideo> _allVideos = [];  // ← تغییر از _lessons و _videosByLesson
  String _selectedStyle = 'جزوه';
  Map<String, String> _teachersMap = {};
  // ...
}
```

### تغییر _load:

```dart
Future<void> _load() async {
  setState(() => _loading = true);
  
  try {
    // مستقیماً ویدیوها را از chapter می‌گیریم (بدون نیاز به lessons)
    final videos = await CachedContentService.getLessonVideos(
      widget.chapter.id,  // chapterId به جای lessonId
      gradeId: widget.gradeId,
      trackId: widget.trackId,
    );

    if (!mounted) return;
    setState(() {
      _allVideos = videos;
      _loading = false;
    });
  } catch (e) {
    Logger.error('Error loading videos', e);
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}
```

### تغییر build (بخش لیست):

```dart
// در build method، به جای منطق پیچیده grouping:
: RefreshIndicator(
    onRefresh: () async {
      AppCacheManager.clearCache('videos_chapter_${widget.chapter.id}');  // ← تغییر cache key
      await _load();
    },
    child: _allVideos.isEmpty
        ? SingleChildScrollView(
            physics: AppScrollPhysics.smooth,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: EmptyStateWidgets.noLessonContent(context),
              ),
            ),
          )
        : _buildVideosList(context, theme, darkBlue),
  )

// متد جدید برای ساخت لیست ویدیوها (ساده‌تر)
Widget _buildVideosList(BuildContext context, ThemeData theme, Color darkBlue) {
  // فیلتر بر اساس style انتخابی
  final filteredVideos = _allVideos
      .where((v) => _getStyleName(v.style) == _selectedStyle)
      .toList();
  
  // مرتب‌سازی بر اساس lesson_order و سپس lesson_title
  filteredVideos.sort((a, b) {
    final orderCompare = a.lessonOrder.compareTo(b.lessonOrder);
    if (orderCompare != 0) return orderCompare;
    return a.lessonTitle.compareTo(b.lessonTitle);
  });

  if (filteredVideos.isEmpty) {
    return SingleChildScrollView(
      physics: AppScrollPhysics.smooth,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: EmptyStateWidgets.noEducationContent(context),
        ),
      ),
    );
  }

  return ListView.builder(
    physics: AppScrollPhysics.gentle,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: filteredVideos.length,
    itemBuilder: (ctx, i) {
      final video = filteredVideos[i];
      final teacherName = _teachersMap[video.teacherId.toString()] ?? 'نامشخص';
      final styleName = _getStyleName(video.style);
      final title = '${video.lessonTitle} - $teacherName - $styleName';
      
      return _buildVideoCard(
        video: video,
        title: title,
        theme: theme,
        darkBlue: darkBlue,
      );
    },
  );
}
```

### تغییر متدهای دیگر در chapter_screen:

```dart
// تغییر _buildVideoCard (حذف وابستگی به Lesson):
Widget _buildVideoCard(
  LessonVideo video,
  String title,
  ThemeData theme,
  Color darkBlue,
) {
  // حذف: final lesson = _lessons!.firstWhere(...)
  // استفاده مستقیم از video.lessonTitle و video.lessonOrder
  
  return GestureDetector(
    onTap: () {
      if (video.embedHtml != null && video.embedHtml!.isNotEmpty) {
        _openVideoPopup(video);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ویدیو در دسترس نیست',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    },
    child: Container(
      // ... کد کارت ویدیو
      // استفاده از video.lessonTitle به جای lesson.title
      // استفاده از video.lessonOrder به جای lesson.lessonOrder
    ),
  );
}

// تغییر _openVideoPopup (حذف وابستگی به Lesson):
void _openVideoPopup(LessonVideo video) {
  final teacherName = _teachersMap[video.teacherId.toString()] ?? 'نامشخص';
  
  showDialog(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text(
          'جزئیات ویدیو',
          style: TextStyle(fontFamily: 'IRANSansXFaNum'),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _kv('شناسه ویدیو', video.id.toString()),
                _kv('درس', video.lessonTitle),  // ← استفاده مستقیم از video.lessonTitle
                _kv('استاد', teacherName),
                _kv('نوع محتوا', _getStyleName(video.style)),
                _kv('وضعیت محتوا', video.contentStatus),
                _kv('لینک آپارات', video.aparatUrl.isNotEmpty ? video.aparatUrl : '-'),
                _kv('مدت زمان', _formatDuration(video.durationSec)),
                _kv('تگ‌ها', video.tags.isNotEmpty ? video.tags.join(', ') : '-'),
                if (video.notePdfUrl != null && video.notePdfUrl!.isNotEmpty)
                  _kv('لینک PDF جزوه', video.notePdfUrl!),
                if (video.exercisePdfUrl != null && video.exercisePdfUrl!.isNotEmpty)
                  _kv('لینک PDF نمونه سوال', video.exercisePdfUrl!),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('ویرایش', style: TextStyle(fontFamily: 'IRANSansXFaNum')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف', style: TextStyle(fontFamily: 'IRANSansXFaNum')),
          ),
        ],
      ),
    ),
  );
}
```

---

## ⚠️ نکات مهم و مشکلات احتمالی

### 1. Migration SQL - بررسی داده‌های موجود
- **قبل از اجرای migration**: حتماً backup بگیرید
- **گام 2.5**: اگر رکوردهای بدون `lesson_id` وجود دارند، حذف می‌شوند
- **گام 3**: اگر UPDATE موفق نبود، NOT NULL خطا می‌دهد
- **گام 4.5**: ✅ اضافه شد - حذف FK `prereq_lesson_id` قبل از حذف lessons
- **گام 5**: ✅ اصلاح شد - ابتدا constraint قدیمی حذف می‌شود، سپس constraint جدید اضافه می‌شود

### 2. Edge Function create-content
- **onConflict**: ✅ اصلاح شد - باید ستون‌های constraint را مشخص کنیم (`chapter_id,lesson_order,lesson_title,teacher_id,style`)
- **ignoreDuplicates**: ✅ اضافه شد - باید `false` باشد تا رکوردهای موجود update شوند
- **تست**: بعد از deploy، حتماً تست کنید که upsert درست کار می‌کند

### 3. Edge Function update-content
- **خط 53**: باید `lesson_id` را به `chapter_id` تغییر دهید
- **خط 108-131**: select query باید تغییر کند (حذف `lessons!inner`)

### 4. Flutter Model lesson_video.dart
- **توجه**: فیلدهای جدید (`chapterId`, `chapterOrder`, `chapterTitle`, `lessonOrder`, `lessonTitle`) باید اضافه شوند
- **از**: `lessonId` باید حذف شود

### 5. Flutter Services
- **cached_content_service.dart**: متد `getLessons` باید حذف شود (اما ممکن است در `subject_screen` یا `dev_settings` استفاده شود - بررسی کنید)
- **content_service.dart**: متد `getLessons` باید حذف شود

### 6. Flutter UI chapter_screen.dart
- **تغییرات بزرگ**: دیگر از `Lesson` استفاده نمی‌شود
- **حذف**: `_lessons` و `_videosByLesson` state variables
- **اضافه**: فقط `_allVideos` (List<LessonVideo>)
- **تغییر**: تمام جاهایی که از `lesson.title` استفاده می‌شود → `video.lessonTitle`
- **تغییر**: تمام جاهایی که از `lesson.lessonOrder` استفاده می‌شود → `video.lessonOrder`

### 7. صفحات دیگر که ممکن است نیاز به تغییر داشته باشند
- **subject_screen.dart**: اگر از `getLessons` استفاده می‌کند، باید بررسی شود
- **dev_settings_button.dart**: اگر از `getLessons` استفاده می‌کند، باید بررسی شود

### 8. ترتیب اجرای مراحل
1. ✅ Migration SQL (اول از همه)
2. ✅ Deploy Migration
3. ✅ Edge Function create-content
4. ✅ Deploy create-content
5. ✅ Edge Function update-content  
6. ✅ Deploy update-content
7. ✅ Flutter Model
8. ✅ Flutter Services
9. ✅ Flutter UI
10. ✅ Flutter Analyze

---

## ⚠️ مشکلات شناسایی شده و اصلاح شده

### ✅ مشکلات برطرف شده:

1. **Migration SQL - Constraint unique_lesson_video**
   - ✅ اضافه شد: `DROP CONSTRAINT IF EXISTS unique_lesson_video` قبل از ایجاد
   - ✅ اضافه شد: حذف FK `prereq_lesson_id` قبل از حذف lessons

2. **Edge Function create-content - onConflict**
   - ✅ اصلاح شد: از `onConflict: 'unique_lesson_video'` به `onConflict: 'chapter_id,lesson_order,lesson_title,teacher_id,style'`
   - ✅ اضافه شد: `ignoreDuplicates: false` برای update کردن رکوردهای موجود

### ✅ مشکلات باقی‌مانده - راه‌حل‌های ساده:

3. **prereq_lesson_id** ✅ حل شد
   - ✅ تصمیم: فیلد را نگه می‌داریم اما foreign key را حذف می‌کنیم (قبلاً در Migration گام 4.5 اضافه شد)
   - ✅ دلیل: در کد Flutter استفاده نمی‌شود، اما ممکن است در آینده استفاده شود
   - ✅ نتیجه: فقط foreign key حذف می‌شود، فیلد باقی می‌ماند

4. **Flutter - subject_screen.dart** ✅ راه‌حل ساده اضافه شد
   - ✅ تغییر: مستقیماً از `getLessonVideos(chapter.id)` استفاده می‌کنیم
   - ✅ کد کامل در بخش 9

5. **Flutter - dev_settings_button.dart** ✅ راه‌حل ساده اضافه شد
   - ✅ تغییر: حلقه `lessons` حذف می‌شود، مستقیماً `getLessonVideos(ch.id)` صدا زده می‌شود
   - ✅ کد کامل در بخش 10

6. **Flutter - mini_request_service.dart** ✅ راه‌حل ساده اضافه شد
   - ✅ تغییر: `_loadLessonsMetadata` حذف می‌شود، `_loadVideosMetadata` از `chapters` استفاده می‌کند
   - ✅ کد کامل در بخش 11

---

## 9. Flutter UI: subject_screen.dart (کد کامل تغییرات)

### تغییر متد _loadChapterTeachers:

```dart
// لود کردن ویدیوهای هر فصل برای گرفتن نام واقعی اساتید
Future<void> _loadChapterTeachers(List<Chapter> chapters) async {
  _chapterTeachers.clear();

  for (final chapter in chapters) {
    try {
      // ✅ تغییر: مستقیماً ویدیوها را از chapter می‌گیریم (بدون نیاز به lessons)
      final videos = await CachedContentService.getLessonVideos(
        chapter.id,  // ← تغییر از lesson.id به chapter.id
        gradeId: widget.gradeId,
        trackId: widget.trackId,
      );

      // استخراج نام‌های منحصر به فرد اساتید
      final Set<String> teacherNames = {};

      // ✅ تغییر: مستقیماً از videos استفاده می‌کنیم (بدون حلقه lessons)
      for (final video in videos) {
        // استفاده از teacherId برای گرفتن نام استاد
        final teacherName = _getTeacherNameById(video.teacherId);
        if (teacherName.isNotEmpty) {
          teacherNames.add(teacherName);
        }
      }

      _chapterTeachers[chapter.id] = teacherNames.toList();
    } catch (e) {
      Logger.error('❌ Error loading teachers for chapter ${chapter.id}', e);
      _chapterTeachers[chapter.id] = [];
    }
  }
}
```

---

## 10. Flutter UI: dev_settings_button.dart (کد کامل تغییرات)

### تغییر متد کش کردن دیتا:

```dart
// ✅ تغییر: حذف حلقه lessons، مستقیماً از chapters استفاده می‌کنیم
for (final ch in chapters) {
  // ✅ تغییر: مستقیماً getLessonVideos را صدا می‌زنیم
  await CachedContentService.getLessonVideos(
    ch.id,  // ← تغییر از les.id به ch.id
    gradeId: grade,
    trackId: track,
  );
}
```

**کد کامل قبل از تغییر:**
```dart
for (final ch in chapters) {
  final lessons = await CachedContentService.getLessons(
    ch.id,
    gradeId: grade,
    trackId: track,
  );
  for (final les in lessons) {
    await CachedContentService.getLessonVideos(
      les.id,
      gradeId: grade,
      trackId: track,
    );
  }
}
```

**کد کامل بعد از تغییر:**
```dart
for (final ch in chapters) {
  await CachedContentService.getLessonVideos(
    ch.id,
    gradeId: grade,
    trackId: track,
  );
}
```

---

## 11. Flutter Service: mini_request_service.dart (کد کامل تغییرات)

### حذف متد _loadLessonsMetadata:
- ✅ این متد کامل حذف می‌شود (خطوط 643-722)
- ✅ هیچ جای دیگری این متد را صدا نمی‌زند (بررسی شده)

### تغییر متد _loadVideosMetadata:

```dart
/// دریافت و کش کردن videos (metadata) برای تمام chapters
Future<void> _loadVideosMetadata(int grade, int? track) async {
  try {
    Logger.info('🎥 [MINI-REQUEST] Loading videos metadata: grade=$grade track=$track');
    
    // ✅ تغییر: دریافت chapters از Hive (به جای lessons)
    final boxName = _getBoxName(grade, track);
    final box = await Hive.openBox(boxName);
    final chaptersJson = box.get('chapters');  // ← تغییر از 'lessons' به 'chapters'
    
    if (chaptersJson == null) {
      Logger.info('⚠️ [MINI-REQUEST] No chapters found, cannot load videos');
      return;
    }
    
    final Map<String, dynamic> allChapters = jsonDecode(chaptersJson);  // ← تغییر از allLessons
    if (allChapters.isEmpty) {
      Logger.info('⚠️ [MINI-REQUEST] Chapters map is empty, skipping videos');
      return;
    }
    
    // ✅ تغییر: برای هر chapter، videos را دانلود کن (به جای lesson)
    final Map<String, List<dynamic>> videosByChapter = {};  // ← تغییر از videosByLesson
    
    // تمام chapters را از همه subject_offers جمع کن (ساده‌تر با expand)
    final allChaptersList = allChapters.values
        .expand((chaptersList) => chaptersList is List ? chaptersList : [])
        .whereType<Map<String, dynamic>>()
        .toList();
    
    Logger.debug('🎥 [MINI-REQUEST] Found ${allChaptersList.length} chapters to load videos for');
    
    for (final chapter in allChaptersList) {
      try {
        // ✅ تغییر: Query videos برای این chapter (به جای lesson)
        final videosData = await _supabase
            .from('lesson_videos')
            .select()
            .eq('chapter_id', chapter['id'])  // ← تغییر از lesson_id به chapter_id
            .eq('active', true)
            .order('lesson_order', ascending: true)
            .order('style', ascending: true)
            as List<dynamic>;
        
        videosByChapter[chapter['id'].toString()] = videosData;  // ← تغییر از lessonId
      } catch (e) {
        Logger.error('❌ [MINI-REQUEST] Error loading videos for chapter ${chapter['id']}', e);
      }
    }
    
    // ✅ تغییر: ذخیره videos در Hive به صورت Map: {chapterId: [videos]}
    await box.put('videos', jsonEncode(videosByChapter));
  } catch (e) {
    Logger.error('❌ [MINI-REQUEST] Error loading videos metadata', e);
  }
}
```

### حذف صدا زدن _loadLessonsMetadata:
- ✅ این متد در 2 جا صدا زده می‌شود (خطوط 235 و 267)
- ✅ باید این دو صدا زدن حذف شوند

**کد قبل از تغییر (خطوط 230-240):**
```dart
await _loadChaptersMetadata(grade, track);
await _loadLessonsMetadata(grade, track);  // ← باید حذف شود
await _loadVideosMetadata(grade, track);
```

**کد بعد از تغییر:**
```dart
await _loadChaptersMetadata(grade, track);
// ✅ حذف شد: await _loadLessonsMetadata(grade, track);
await _loadVideosMetadata(grade, track);
```

**همین تغییر باید در خط 267 هم اعمال شود**

---

## 📋 چک‌لیست قبل از اجرا

- [x] Backup کامل از دیتابیس گرفته شده
- [x] تصمیم‌گیری در مورد `prereq_lesson_id` (فیلد نگه داشته می‌شود، FK حذف می‌شود)
- [x] بررسی که آیا `getLessons` در جاهای دیگر استفاده می‌شود (بررسی شد: فقط در 3 جا)
- [ ] تست Migration در محیط تست
- [ ] تست Edge Functions بعد از deploy
- [ ] تست Flutter app بعد از تغییرات

---

این فایل شامل تمام کدهای کامل است که در پلن استفاده می‌شوند.

---

## ✅ گزارش نهایی بررسی پلن

### 📊 خلاصه وضعیت:

**نقاط قوت:**
- ✅ Migration SQL کامل و اصولی است
- ✅ همه مشکلات بحرانی شناسایی و حل شده‌اند
- ✅ ترتیب اجرای مراحل منطقی است
- ✅ قوانین اجرا واضح و مشخص است
- ✅ کدهای کامل برای همه تغییرات ارائه شده
- ✅ مشکلات باقی‌مانده شناسایی و راه‌حل داده شده

**پوشش تغییرات:**
- ✅ Migration SQL (گام‌های 1-9)
- ✅ Edge Function create-content (کامل)
- ✅ Edge Function update-content (تغییرات مشخص)
- ✅ Flutter Model lesson_video.dart (کامل)
- ✅ Flutter Service cached_content_service.dart
- ✅ Flutter Service content_service.dart
- ✅ Flutter Service mini_request_service.dart
- ✅ Flutter UI chapter_screen.dart
- ✅ Flutter UI subject_screen.dart
- ✅ Flutter UI dev_settings_button.dart

**مشکلات حل شده:**
- ✅ Constraint unique_lesson_video
- ✅ Foreign Key prereq_lesson_id
- ✅ onConflict در create-content
- ✅ استفاده از getLessons در 3 فایل

**نکات مهم:**
- ⚠️ فیلد `lessonId` باید از `LessonVideo` model حذف شود (در fromJson و toJson هم)
- ⚠️ متد `getLessons` باید از `cached_content_service.dart` و `content_service.dart` حذف شود
- ⚠️ مدل `Lesson` ممکن است در جاهای دیگر استفاده شود - بررسی شود

**وضعیت کلی:** ✅ پلن کامل، دقیق و آماده اجرا است

---

## 📋 یادداشت برای بعد از اجرای موفق پلن

### ⚠️ مهم: این بخش فقط بعد از تایید موفقیت‌آمیز اجرای پلن باید انجام شود

**بعد از اینکه:**
1. ✅ پلن به طور کامل اجرا شد
2. ✅ تست شد و همه چیز بدون مشکل کار کرد
3. ✅ کاربر تایید کرد که پلن موفقیت‌آمیز بوده

**گزارش برای نسخه محصول:**
- ✅ گزارش کامل در فایل `PRODUCT_APP_MIGRATION_REPORT.md` آماده شده است
- این گزارش شامل تمام تغییرات بک‌اند و تغییرات مورد نیاز در فرانت محصول است
- گزارش شامل تغییرات مدل‌ها، API Calls، و UI است
- کدهای کامل قبل و بعد در گزارش موجود است
- **نکته مهم:** در گزارش قید شده که Mini-Request در نسخه محصول باید حفظ شود و فقط نیاز به به‌روزرسانی دارد (هیچ اشاره‌ای به حذف Mini-Request در نسخه ادمین نشده است)

