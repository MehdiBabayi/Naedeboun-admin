import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

console.log('🎯 delete-content function loaded');

interface DeleteContentInput {
  video_id: number;
}

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Get request body
    const { video_id }: DeleteContentInput = await req.json();

    console.log('🗑️ Deleting video:', video_id);

    // Validate required fields
    if (!video_id) {
      console.error('❌ Missing video_id');
      return new Response(
        JSON.stringify({
          error: 'video_id الزامی است',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Check if video exists and get grade_id for change count
    const { data: existingVideo, error: checkError } = await supabaseClient
      .from('lesson_videos')
      .select('video_id, grade_id, title')
      .eq('video_id', video_id)
      .single();

    if (checkError || !existingVideo) {
      console.error('❌ Video not found:', checkError);
      return new Response(
        JSON.stringify({
          error: 'ویدیو یافت نشد',
        }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('✅ Video found:', existingVideo.title);

    // Delete video
    const { error: deleteError } = await supabaseClient
      .from('lesson_videos')
      .delete()
      .eq('video_id', video_id);

    if (deleteError) {
      console.error('❌ Delete error:', deleteError);
      return new Response(
        JSON.stringify({
          error: `خطا در حذف ویدیو: ${deleteError.message}`,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Increment change_count for the grade
    const { error: changeCountError } = await supabaseClient.rpc('increment_change_count', {
      table_name: 'lesson_videos',
      grade_id: existingVideo.grade_id,
    });

    if (changeCountError) {
      console.error('❌ Change count error:', changeCountError);
      // Don't fail the request for this, just log it
    } else {
      console.log('✅ Change count incremented for lesson_videos');
    }

    console.log('✅ Video deleted successfully:', video_id);

    return new Response(
      JSON.stringify({
        message: 'ویدیو با موفقیت حذف شد',
        deleted_video_id: video_id,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('💥 Unexpected error:', error);
    return new Response(
      JSON.stringify({
        error: 'خطای غیرمنتظره رخ داد',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }
});

