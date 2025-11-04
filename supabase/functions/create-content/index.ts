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
  aparat_url?: string;  // ← اختیاری کردیم
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
    
    // ✅ Validation: بررسی فیلدهای الزامی (با chapter_order و lesson_order)
    if (!input.branch || !input.grade || !input.subject || !input.subject_slug || 
        !input.chapter_title || input.chapter_order == null || input.chapter_order < 1 ||
        !input.lesson_title || input.lesson_order == null || input.lesson_order < 1 ||
        !input.teacher_name) {
      return new Response(
        JSON.stringify({ error: "فیلدهای الزامی: branch, grade, subject, subject_slug, chapter_title, chapter_order (>= 1), lesson_title, lesson_order (>= 1), teacher_name" }),
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