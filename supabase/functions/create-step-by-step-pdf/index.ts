import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface StepByStepPdfInput {
  branch: string; // ابتدایی / متوسطه اول / متوسطه دوم
  grade_name: string; // هفتم، هشتم، ...
  grade_id: number;
  track_id?: number | null;
  subject_name: string;
  subject_id: number;
  level: string; // ابتدایی / متوسط اول / متوسط دوم
  title: string;
  pdf_url: string;
  file_size_mb?: number | null;
  page_count?: number | null;
  active?: boolean;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const input: StepByStepPdfInput = await req.json();
    
    console.log('📚 [CREATE-STEP-BY-STEP] شروع با input:', JSON.stringify(input));

    // Validation
    if (!input.branch || !input.grade_name || !input.grade_id || 
        !input.subject_name || !input.subject_id || 
        !input.level || !input.title || !input.pdf_url) {
      console.error('❌ [CREATE-STEP-BY-STEP] فیلدهای الزامی ناقص است');
      return new Response(
        JSON.stringify({ error: "فیلدهای الزامی: branch, grade_name, grade_id, subject_name, subject_id, level, title, pdf_url" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validation level
    const validLevels = ['ابتدایی', 'متوسط اول', 'متوسط دوم'];
    if (!validLevels.includes(input.level)) {
      console.error('❌ [CREATE-STEP-BY-STEP] level نامعتبر:', input.level);
      return new Response(
        JSON.stringify({ error: `level باید یکی از این مقادیر باشد: ${validLevels.join(', ')}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    
    if (!supabaseUrl || !serviceRoleKey) {
      console.error('❌ [CREATE-STEP-BY-STEP] ENV ناقص است');
      return new Response(
        JSON.stringify({ error: 'ENV ناقص است: SUPABASE_URL یا SUPABASE_SERVICE_ROLE_KEY تنظیم نشده' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // بررسی وجود grade_id
    const { data: gradeCheck, error: gradeCheckError } = await supabase
      .from('grades')
      .select('id')
      .eq('id', input.grade_id)
      .single();

    if (gradeCheckError || !gradeCheck) {
      console.error('❌ [CREATE-STEP-BY-STEP] grade_id یافت نشد:', gradeCheckError?.message);
      return new Response(
        JSON.stringify({ error: `grade_id ${input.grade_id} یافت نشد` }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // بررسی وجود subject_id
    const { data: subjectCheck, error: subjectCheckError } = await supabase
      .from('subjects')
      .select('id')
      .eq('id', input.subject_id)
      .single();

    if (subjectCheckError || !subjectCheck) {
      console.error('❌ [CREATE-STEP-BY-STEP] subject_id یافت نشد:', subjectCheckError?.message);
      return new Response(
        JSON.stringify({ error: `subject_id ${input.subject_id} یافت نشد` }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // بررسی track_id (اگر ارائه شده)
    if (input.track_id != null) {
      const { data: trackCheck, error: trackCheckError } = await supabase
        .from('tracks')
        .select('id')
        .eq('id', input.track_id)
        .single();

      if (trackCheckError || !trackCheck) {
        console.error('❌ [CREATE-STEP-BY-STEP] track_id یافت نشد:', trackCheckError?.message);
        return new Response(
          JSON.stringify({ error: `track_id ${input.track_id} یافت نشد` }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // ایجاد رکورد در step_by_step_pdfs
    const { data: pdfRecord, error: pdfError } = await supabase
      .from('step_by_step_pdfs')
      .insert({
        level: input.level,
        grade_id: input.grade_id,
        track_id: input.track_id || null,
        subject_id: input.subject_id,
        title: input.title,
        pdf_url: input.pdf_url,
        file_size_mb: input.file_size_mb || null,
        page_count: input.page_count || null,
        active: input.active !== false,
      })
      .select('id')
      .single();

    if (pdfError) {
      console.error('❌ [CREATE-STEP-BY-STEP] خطا در ایجاد PDF:', pdfError.message);
      throw new Error(`خطا در ایجاد PDF: ${pdfError.message}`);
    }

    console.log('✅ [CREATE-STEP-BY-STEP] PDF با موفقیت ایجاد شد، ID:', pdfRecord.id);

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "گام‌به‌گام با موفقیت ایجاد شد",
        data: {
          step_by_step_pdf_id: pdfRecord.id,
          grade_id: input.grade_id,
          subject_id: input.subject_id,
        }
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("❌ [CREATE-STEP-BY-STEP] Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

