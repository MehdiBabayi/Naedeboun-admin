import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface DeleteContentInput {
  lesson_video_id: number;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const input: DeleteContentInput = await req.json();
    
    console.log('🗑️ [DELETE-CONTENT] شروع حذف ویدیو ID:', input.lesson_video_id);

    if (!input.lesson_video_id) {
      console.error('❌ [DELETE-CONTENT] lesson_video_id الزامی است');
      return new Response(
        JSON.stringify({ error: "lesson_video_id الزامی است" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    
    if (!supabaseUrl || !serviceRoleKey) {
      console.error('❌ [DELETE-CONTENT] ENV ناقص است');
      return new Response(
        JSON.stringify({ error: 'ENV ناقص است: SUPABASE_URL یا SUPABASE_SERVICE_ROLE_KEY تنظیم نشده' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // بررسی وجود ویدیو
    const { data: existingVideo, error: checkError } = await supabase
      .from('lesson_videos')
      .select('id, chapter_id, lesson_title, style')
      .eq('id', input.lesson_video_id)
      .single();

    if (checkError || !existingVideo) {
      console.error('❌ [DELETE-CONTENT] ویدیو یافت نشد:', checkError?.message);
      return new Response(
        JSON.stringify({ error: "ویدیو یافت نشد" }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ [DELETE-CONTENT] ویدیو یافت شد:', existingVideo);

    // حذف ویدیو (CASCADE به صورت خودکار وابستگی‌ها را حذف می‌کند)
    const { error: deleteError } = await supabase
      .from('lesson_videos')
      .delete()
      .eq('id', input.lesson_video_id);

    if (deleteError) {
      console.error('❌ [DELETE-CONTENT] خطا در حذف ویدیو:', deleteError.message);
      throw new Error(`خطا در حذف ویدیو: ${deleteError.message}`);
    }

    console.log('✅ [DELETE-CONTENT] ویدیو با موفقیت حذف شد');

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "ویدیو با موفقیت حذف شد",
        data: {
          deleted_video_id: input.lesson_video_id
        }
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("❌ [DELETE-CONTENT] Error in delete-content function:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

