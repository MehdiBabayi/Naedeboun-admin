import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

console.log('🎯 update-content function loaded');

interface UpdateContentInput {
  video_id: number;
  updates: {
    grade_id?: number;
    book_id?: string;
    chapter_id?: string;
    step_number?: number;
    title?: string;
    type?: 'note' | 'book' | 'exam';
    teacher?: string;
    embed_url?: string | null;
    direct_url?: string | null;
    pdf_url?: string | null;
    thumbnail_url?: string | null;
    duration?: number;
    likes_count?: number;
    views_count?: number;
    active?: boolean;
  };
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
    const { video_id, updates }: UpdateContentInput = await req.json();

    console.log('🔄 Updating video:', video_id);
    console.log('🔄 Updates:', JSON.stringify(updates));

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

    // Check if video exists
    const { data: existingVideo, error: checkError } = await supabaseClient
      .from('lesson_videos')
      .select('video_id, grade_id')
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

    // Prepare update payload
    const updatePayload: any = {};

    if (updates.grade_id !== undefined) updatePayload.grade_id = updates.grade_id;
    if (updates.book_id !== undefined) updatePayload.book_id = updates.book_id;
    if (updates.chapter_id !== undefined) updatePayload.chapter_id = updates.chapter_id;
    if (updates.step_number !== undefined) updatePayload.step_number = updates.step_number;
    if (updates.title !== undefined) updatePayload.title = updates.title;
    if (updates.type !== undefined) updatePayload.type = updates.type;
    if (updates.teacher !== undefined) updatePayload.teacher = updates.teacher;
    if (updates.embed_url !== undefined) updatePayload.embed_url = updates.embed_url;
    if (updates.direct_url !== undefined) updatePayload.direct_url = updates.direct_url;
    if (updates.pdf_url !== undefined) updatePayload.pdf_url = updates.pdf_url;
    if (updates.thumbnail_url !== undefined) updatePayload.thumbnail_url = updates.thumbnail_url;
    if (updates.duration !== undefined) updatePayload.duration = updates.duration;
    if (updates.likes_count !== undefined) updatePayload.likes_count = updates.likes_count;
    if (updates.views_count !== undefined) updatePayload.views_count = updates.views_count;
    if (updates.active !== undefined) updatePayload.active = updates.active;

    // Update video
    const { data: updatedVideo, error: updateError } = await supabaseClient
      .from('lesson_videos')
      .update(updatePayload)
      .eq('video_id', video_id)
      .select()
      .single();

    console.log('🔍 UPDATE result:', { updatedVideo, updateError });

    if (updateError) {
      console.error('❌ Update error:', updateError);
      return new Response(
        JSON.stringify({
          error: `خطا در به‌روزرسانی ویدیو: ${updateError.message}`,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Increment change_count for the grade
    // موقتاً کامنت شده برای تست - اگر خطا رفت، مشکل از RPC است
    const gradeId = updates.grade_id ?? existingVideo.grade_id;
    if (gradeId) {
      // const { error: changeCountError } = await supabaseClient.rpc('increment_change_count', {
      //   table_name: 'lesson_videos',
      //   grade_id: gradeId,
      // });

      // if (changeCountError) {
      //   console.error('❌ Change count error:', changeCountError);
      //   // Don't fail the request for this, just log it
      // } else {
      //   console.log('✅ Change count incremented for lesson_videos');
      // }
      console.log('⚠️ RPC increment_change_count موقتاً غیرفعال است برای تست');
    }

    console.log('✅ Video updated successfully:', updatedVideo.video_id);
    console.log('📦 Final response:', { 
      message: 'ویدیو با موفقیت به‌روزرسانی شد', 
      video: updatedVideo 
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'ویدیو با موفقیت به‌روزرسانی شد',
        video: updatedVideo,
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
