import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

console.log('🎯 delete-pdf-content function loaded');

interface DeletePdfInput {
  pdf_type: 'step_by_step' | 'provincial_sample';
  pdf_id: number;
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
    const { pdf_type, pdf_id }: DeletePdfInput = await req.json();

    console.log('🗑️ Deleting PDF:', { pdf_type, pdf_id });

    // Validate required fields
    if (!pdf_type || !pdf_id) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({
          error: 'pdf_type و pdf_id الزامی هستند',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    if (!['step_by_step', 'provincial_sample'].includes(pdf_type)) {
      console.error('❌ Invalid pdf_type');
      return new Response(
        JSON.stringify({
          error: 'pdf_type باید step_by_step یا provincial_sample باشد',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Determine table name
    const tableName = pdf_type === 'step_by_step' ? 'book_answer_pdfs' : 'provincial_sample_pdfs';

    // Check if PDF exists and get grade_id for change count
    const { data: existingPdf, error: checkError } = await supabaseClient
      .from(tableName)
      .select('id, grade_id, pdf_title')
      .eq('id', pdf_id)
      .single();

    if (checkError || !existingPdf) {
      console.error('❌ PDF not found:', checkError);
      return new Response(
        JSON.stringify({
          error: 'PDF یافت نشد',
        }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('✅ PDF found:', existingPdf.pdf_title);

    // Delete PDF
    const { error: deleteError } = await supabaseClient
      .from(tableName)
      .delete()
      .eq('id', pdf_id);

    if (deleteError) {
      console.error('❌ Delete error:', deleteError);
      return new Response(
        JSON.stringify({
          error: `خطا در حذف PDF: ${deleteError.message}`,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Increment change_count for the grade
    const { error: changeCountError } = await supabaseClient.rpc('increment_change_count', {
      table_name: tableName,
      grade_id: existingPdf.grade_id,
    });

    if (changeCountError) {
      console.error('❌ Change count error:', changeCountError);
      // Don't fail the request for this, just log it
    } else {
      console.log('✅ Change count incremented for', tableName);
    }

    console.log('✅ PDF deleted successfully:', pdf_id);

    return new Response(
      JSON.stringify({
        message: 'PDF با موفقیت حذف شد',
        deleted_pdf_id: pdf_id,
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
