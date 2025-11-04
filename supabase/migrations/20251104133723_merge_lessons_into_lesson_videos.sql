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

