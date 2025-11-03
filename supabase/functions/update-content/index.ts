import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface UpdateContentInput {
  lesson_video_id: number;
  updates: {
    aparat_url?: string;
    duration_sec?: number;
    tags?: string[];
    prereq_lesson_id?: number | null;
    active?: boolean;
    content_status?: 'draft' | 'published' | 'archived';
    teacher_name?: string;
    style?: 'note' | 'book' | 'sample';
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const input: UpdateContentInput = await req.json();
    
    if (!input.lesson_video_id || !input.updates) {
      return new Response(
        JSON.stringify({ error: "lesson_video_id و updates الزامی است" }),
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

    // Check if lesson_video exists
    const { data: existingVideo, error: checkError } = await supabase
      .from('lesson_videos')
      .select('id, teacher_id, lesson_id')
      .eq('id', input.lesson_video_id)
      .single();

    if (checkError || !existingVideo) {
      return new Response(
        JSON.stringify({ error: "ویدیو یافت نشد" }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Prepare updates for lesson_videos table
    const videoUpdates: any = {
      updated_at: new Date().toISOString()
    };

    // Handle teacher_name update (need to find/create teacher)
    if (input.updates.teacher_name) {
      let { data: teacher, error: teacherError } = await supabase
        .from('teachers')
        .select('id')
        .eq('name', input.updates.teacher_name)
        .single();

      if (teacherError && teacherError.code === 'PGRST116') {
        // Teacher doesn't exist, create it
        const { data: newTeacher, error: createTeacherError } = await supabase
          .from('teachers')
          .insert({ name: input.updates.teacher_name })
          .select('id')
          .single();

        if (createTeacherError) throw new Error(`خطا در ایجاد استاد: ${createTeacherError.message}`);
        teacher = newTeacher;
      } else if (teacherError) {
        throw new Error(`خطا در یافتن استاد: ${teacherError.message}`);
      }

      videoUpdates.teacher_id = teacher.id;
    }

    // Handle other video updates
    if (input.updates.aparat_url !== undefined) videoUpdates.aparat_url = input.updates.aparat_url;
    if (input.updates.duration_sec !== undefined) videoUpdates.duration_sec = input.updates.duration_sec;
    if (input.updates.tags !== undefined) videoUpdates.tags = input.updates.tags;
    if (input.updates.prereq_lesson_id !== undefined) videoUpdates.prereq_lesson_id = input.updates.prereq_lesson_id;
    if (input.updates.active !== undefined) videoUpdates.active = input.updates.active;
    if (input.updates.content_status !== undefined) videoUpdates.content_status = input.updates.content_status;
    if (input.updates.style !== undefined) videoUpdates.style = input.updates.style;

    // Update lesson_videos
    const { data: updatedVideo, error: updateError } = await supabase
      .from('lesson_videos')
      .update(videoUpdates)
      .eq('id', input.lesson_video_id)
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
      .single();

    if (updateError) {
      throw new Error(`خطا در به‌روزرسانی ویدیو: ${updateError.message}`);
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "ویدیو با موفقیت به‌روزرسانی شد",
        data: updatedVideo
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("Error in update-content function:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
