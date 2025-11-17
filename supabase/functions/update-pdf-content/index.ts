import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

console.log('🎯 update-pdf-content function loaded');

interface UpdatePdfInput {
  pdf_type: 'step_by_step' | 'provincial_sample';
  pdf_id: number;
  updates: {
    // Step by step fields
    grade_id?: number;
    book_id?: string;
    pdf_title?: string;
    author?: string;
    size?: number;
    pdf_url?: string;
    active?: boolean;

    // Provincial sample fields
    type?: 'first_term' | 'second_term' | 'midterm_1' | 'midterm_2';
    year?: number;
    has_answer?: boolean;
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
    const { pdf_type, pdf_id, updates }: UpdatePdfInput = await req.json();

    console.log('🔄 Updating PDF:', { pdf_type, pdf_id });
    console.log('🔄 Updates:', JSON.stringify(updates));

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

    // Prepare update payload based on pdf_type
    const updatePayload: any = {};

    if (pdf_type === 'step_by_step') {
      // Step by step PDF updates
      if (updates.grade_id !== undefined) updatePayload.grade_id = updates.grade_id;
      if (updates.book_id !== undefined) updatePayload.book_id = updates.book_id;
      if (updates.pdf_title !== undefined) updatePayload.pdf_title = updates.pdf_title;
      if (updates.author !== undefined) updatePayload.author = updates.author;
      if (updates.size !== undefined) updatePayload.size = updates.size;
      if (updates.pdf_url !== undefined) updatePayload.pdf_url = updates.pdf_url;
      if (updates.active !== undefined) updatePayload.active = updates.active;
    } else {
      // Provincial sample PDF updates
      if (updates.grade_id !== undefined) updatePayload.grade_id = updates.grade_id;
      if (updates.book_id !== undefined) updatePayload.book_id = updates.book_id;
      if (updates.pdf_title !== undefined) updatePayload.pdf_title = updates.pdf_title;
      if (updates.type !== undefined) updatePayload.type = updates.type;
      if (updates.year !== undefined) updatePayload.year = updates.year;
      if (updates.author !== undefined) updatePayload.author = updates.author;
      if (updates.has_answer !== undefined) updatePayload.has_answer = updates.has_answer;
      if (updates.size !== undefined) updatePayload.size = updates.size;
      if (updates.pdf_url !== undefined) updatePayload.pdf_url = updates.pdf_url;
      if (updates.active !== undefined) updatePayload.active = updates.active;
    }

    // Update PDF
    const { data: updatedPdf, error: updateError } = await supabaseClient
      .from(tableName)
      .update(updatePayload)
      .eq('id', pdf_id)
      .select()
      .single();

    if (updateError) {
      console.error('❌ Update error:', updateError);
      return new Response(
        JSON.stringify({
          error: `خطا در به‌روزرسانی PDF: ${updateError.message}`,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Increment change_count for the grade
    const gradeId = updates.grade_id ?? existingPdf.grade_id;
    if (gradeId) {
      const { error: changeCountError } = await supabaseClient.rpc('increment_change_count', {
        table_name: tableName,
        grade_id: gradeId,
      });

      if (changeCountError) {
        console.error('❌ Change count error:', changeCountError);
        // Don't fail the request for this, just log it
      } else {
        console.log('✅ Change count incremented for', tableName);
      }
    }

    console.log('✅ PDF updated successfully:', updatedPdf.id);

    return new Response(
      JSON.stringify({
        message: 'PDF با موفقیت به‌روزرسانی شد',
        pdf: updatedPdf,
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
