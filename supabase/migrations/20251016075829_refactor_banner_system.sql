-- اضافه کردن ستون‌های جدید با constraints
ALTER TABLE banners
ADD COLUMN video_id INTEGER,
ADD COLUMN grade_id INTEGER NOT NULL DEFAULT 1,
ADD COLUMN track_id INTEGER;

-- اضافه کردن foreign key constraint
ALTER TABLE banners
ADD CONSTRAINT fk_banners_video_id
FOREIGN KEY (video_id) REFERENCES lesson_videos(id) ON DELETE SET NULL;

-- اضافه کردن index برای performance
CREATE INDEX idx_banners_grade_active ON banners(grade_id, active, display_order);

-- آپدیت بنرهای موجود
UPDATE banners SET grade_id = 1 WHERE grade_id IS NULL;

-- حذف ستون قدیمی (بعد از اطمینان)
ALTER TABLE banners DROP COLUMN video_url;