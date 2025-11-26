import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ContentInput {
  grade_id: number;
  book_id: string;
  chapter_id: string;
  step_number: number;
  title: string;
  type: 'note' | 'book' | 'exam';
  teacher: string;
  embed_url?: string;
  direct_url?: string;
  pdf_url?: string;
  duration: number;
  thumbnail_url?: string;
  active?: boolean;
  likes_count?: number;
  views_count?: number;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const input: ContentInput = await req.json();
    
    // ✅ Validation: بررسی فیلدهای الزامی
    if (!input.grade_id || !input.book_id || !input.chapter_id ||
        input.step_number == null || input.step_number < 1 ||
        !input.title || !input.type || !input.teacher ||
        input.duration == null || input.duration <= 0) {
      return new Response(
        JSON.stringify({ error: "فیلدهای الزامی: grade_id, book_id, chapter_id, step_number (>= 1), title, type, teacher, duration (> 0)" }),
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

    // Create/Update lesson_video با فیلدهای جدید
    const { data: lessonVideo, error: lessonVideoError } = await supabase
      .from('lesson_videos')
      .insert({
        grade_id: input.grade_id,
        book_id: input.book_id,
        chapter_id: input.chapter_id,
        step_number: input.step_number,
        title: input.title,
        type: input.type,
        teacher: input.teacher,
        embed_url: input.embed_url || null,
        direct_url: input.direct_url || null,
        pdf_url: input.pdf_url || null,
        duration: input.duration,
        thumbnail_url: input.thumbnail_url || null,
        active: input.active !== false,
        likes_count: input.likes_count ?? 0,
        views_count: input.views_count ?? 0
      })
      .select('video_id')
      .single();

    if (lessonVideoError) {
      throw new Error(`خطا در ایجاد ویدیو درس: ${lessonVideoError.message}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "ویدیو با موفقیت ایجاد شد",
        data: {
          grade_id: input.grade_id,
          book_id: input.book_id,
          chapter_id: input.chapter_id,
          step_number: input.step_number,
          title: input.title,
          type: input.type,
          teacher: input.teacher,
          embed_url: input.embed_url,
          direct_url: input.direct_url,
          pdf_url: input.pdf_url,
          duration: input.duration,
          thumbnail_url: input.thumbnail_url,
          active: input.active !== false,
          video_id: lessonVideo.video_id
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