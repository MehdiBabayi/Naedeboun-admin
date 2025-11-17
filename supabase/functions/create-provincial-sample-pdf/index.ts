import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

console.log('🎯 create-provincial-sample-pdf function loaded');

interface CreateProvincialSamplePdfInput {
  grade_id: number;
  book_id: string;
  pdf_title: string;
  type: 'first_term' | 'second_term' | 'midterm_1' | 'midterm_2';
  year?: number;
  author: string;
  has_answer?: boolean;
  size?: number;
  pdf_url: string;
  active?: boolean;
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
    const {
      grade_id,
      book_id,
      pdf_title,
      type,
      year,
      author,
      has_answer = false,
      size,
      pdf_url,
      active = true,
    }: CreateProvincialSamplePdfInput = await req.json();

    console.log('📝 Creating provincial sample PDF:', {
      grade_id,
      book_id,
      pdf_title,
      type,
      year,
      author,
      has_answer,
      size,
      pdf_url,
      active,
    });

    // Validate required fields
    if (!grade_id || !book_id || !pdf_title || !type || !author || !pdf_url) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({
          error: 'تمام فیلدهای الزامی باید وارد شوند',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate type
    if (!['first_term', 'second_term', 'midterm_1', 'midterm_2'].includes(type)) {
      console.error('❌ Invalid type');
      return new Response(
        JSON.stringify({
          error: 'نوع امتحان باید یکی از مقادیر معتبر باشد',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Insert PDF
    const { data: pdf, error: insertError } = await supabaseClient
      .from('provincial_sample_pdfs')
      .insert({
        grade_id,
        book_id,
        pdf_title,
        type,
        year,
        author,
        has_answer,
        size,
        pdf_url,
        active,
      })
      .select()
      .single();

    if (insertError) {
      console.error('❌ Insert error:', insertError);
      return new Response(
        JSON.stringify({
          error: `خطا در ذخیره PDF: ${insertError.message}`,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Increment change_count for provincial_sample_pdfs
    const { error: changeCountError } = await supabaseClient.rpc('increment_change_count', {
      table_name: 'provincial_sample_pdfs',
      grade_id: grade_id,
    });

    if (changeCountError) {
      console.error('❌ Change count error:', changeCountError);
      // Don't fail the request for this, just log it
    } else {
      console.log('✅ Change count incremented for provincial_sample_pdfs');
    }

    console.log('✅ Provincial sample PDF created successfully:', pdf.id);

    return new Response(
      JSON.stringify({
        message: 'PDF نمونه سوال استانی با موفقیت ایجاد شد',
        pdf_id: pdf.id,
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