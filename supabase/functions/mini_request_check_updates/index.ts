// ==========================================
// Mini-Request Check Updates Edge Function
// ==========================================
// Purpose: Count content for a grade/track and update content_counts table
// Returns: Content counts as JSON

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface RequestBody {
  grade: number;
  track?: number | null;
}

interface ContentCounts {
  lesson_videos_count: number;
  step_by_step_pdfs_count: number;
  provincial_sample_pdfs_count: number;
  chapters_count: number;
  subjects_count: number;
  lessons_count: number;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { grade, track }: RequestBody = await req.json();
    
    // Validate grade
    if (!grade || grade < 1 || grade > 12) {
      return new Response(
        JSON.stringify({ error: 'Invalid grade. Must be between 1-12.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Initialize Supabase client with service role
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    console.log(`🔍 [BACKEND] Counting content for grade: ${grade}, track: ${track}`);

    // Step 1: Get subjects with book covers from book_covers table
    let bookCoversQuery = supabase
      .from('book_covers')
      .select('subject_name, subject_path, grade, track')
      .eq('grade', grade);
    
    if (track === null || track === undefined) {
      bookCoversQuery = bookCoversQuery.is('track', null);
    } else {
      bookCoversQuery = bookCoversQuery.eq('track', track);
    }

    const { data: bookCovers, error: bcError } = await bookCoversQuery;
    
    if (bcError) {
      console.error('Error fetching book_covers:', bcError);
      throw bcError;
    }

    console.log(`📚 [BACKEND] Found ${bookCovers?.length || 0} book covers for grade ${grade}, track ${track}`);
    
    // Get subject_offer_ids for this grade/track
    let subjectOffersQuery = supabase
      .from('subject_offers')
      .select('id')
      .eq('grade_id', grade);
    
    if (track === null || track === undefined) {
      subjectOffersQuery = subjectOffersQuery.is('track_id', null);
    } else {
      subjectOffersQuery = subjectOffersQuery.eq('track_id', track);
    }

    const { data: subjectOffers, error: soError } = await subjectOffersQuery;
    
    if (soError) {
      console.error('Error fetching subject_offers:', soError);
      throw soError;
    }

    const subjectOfferIds = (subjectOffers || []).map((so: any) => so.id);
    console.log(`📚 [BACKEND] Found ${subjectOfferIds.length} subject offers`);

    if (subjectOfferIds.length === 0) {
      // No content for this grade/track
      const counts: ContentCounts = {
        lesson_videos_count: 0,
        step_by_step_pdfs_count: 0,
        provincial_sample_pdfs_count: 0,
        chapters_count: 0,
        subjects_count: 0,
        lessons_count: 0,
      };

      // Still update the table
      await supabase
        .from('content_counts')
        .upsert({
          grade,
          track,
          ...counts,
          last_updated: new Date().toISOString(),
        }, {
          onConflict: 'grade,track',
        });

      return new Response(
        JSON.stringify({
          success: true,
          grade,
          track,
          counts,
          timestamp: new Date().toISOString(),
        }),
        { 
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Step 2: Get chapter_ids for these subject_offers
    const { data: chapters, error: chaptersError } = await supabase
      .from('chapters')
      .select('id')
      .in('subject_offer_id', subjectOfferIds);

    if (chaptersError) {
      console.error('Error fetching chapters:', chaptersError);
      throw chaptersError;
    }

    const chapterIds = (chapters || []).map((c: any) => c.id);
    console.log(`📖 [BACKEND] Found ${chapterIds.length} chapters`);

    // Step 3: Get lesson_ids for these chapters
    const { data: lessons, error: lessonsError } = await supabase
      .from('lessons')
      .select('id')
      .in('chapter_id', chapterIds);

    if (lessonsError) {
      console.error('Error fetching lessons:', lessonsError);
      throw lessonsError;
    }

    const lessonIds = (lessons || []).map((l: any) => l.id);
    console.log(`📝 [BACKEND] Found ${lessonIds.length} lessons`);

    // Step 4: Count lesson videos
    let videosCount = 0;
    if (lessonIds.length > 0) {
      const { count, error: videosError } = await supabase
        .from('lesson_videos')
        .select('*', { count: 'exact', head: true })
        .eq('active', true)
        .in('lesson_id', lessonIds);

      if (videosError) {
        console.error('Error counting videos:', videosError);
        throw videosError;
      }

      videosCount = count ?? 0;
    }

    // Step 5: Count step-by-step PDFs
    const { count: stepByStepCount, error: sbsError } = await supabase
      .from('step_by_step_pdfs')
      .select('*', { count: 'exact', head: true })
      .eq('grade_id', grade)
      .eq('active', true);

    if (sbsError) {
      console.error('Error counting step-by-step PDFs:', sbsError);
      throw sbsError;
    }

    // Step 6: Count provincial sample PDFs
    const { count: provincialCount, error: psError } = await supabase
      .from('provincial_sample_pdfs')
      .select('*', { count: 'exact', head: true })
      .eq('grade_id', grade)
      .eq('active', true);

    if (psError) {
      console.error('Error counting provincial PDFs:', psError);
      throw psError;
    }

    const counts: ContentCounts = {
      lesson_videos_count: videosCount,
      step_by_step_pdfs_count: stepByStepCount ?? 0,
      provincial_sample_pdfs_count: provincialCount ?? 0,
      chapters_count: chapterIds.length,
      subjects_count: subjectOfferIds.length,
      lessons_count: lessonIds.length,
    };

    // Update content_counts table
    const { error: upsertError } = await supabase
      .from('content_counts')
      .upsert({
        grade,
        track,
        ...counts,
        last_updated: new Date().toISOString(),
      }, {
        onConflict: 'grade,track',
      });

    if (upsertError) {
      console.error('Error upserting counts:', upsertError);
    }

    console.log(`✅ [BACKEND] Counts for grade ${grade}:`, counts);

    return new Response(
      JSON.stringify({
        success: true,
        grade,
        track,
        counts,
        book_covers: bookCovers || [],
        timestamp: new Date().toISOString(),
      }),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error: any) {
    console.error('❌ [BACKEND] Error in mini_request_check_updates:', error);
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});

