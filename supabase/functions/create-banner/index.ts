import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

console.log('🎯 create-banner function loaded');

serve(async (req) => {
  try {
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

    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Get request body
    const {
      title,
      description,
      image_url,
      link_url,
      position,
      is_active = true,
    } = await req.json();

    console.log('📝 Creating banner:', {
      title,
      description,
      image_url,
      link_url,
      position,
      is_active,
    });

    // Validate required fields
    if (!title || !image_url || !position) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({
          error: 'عنوان، لینک تصویر و موقعیت نمایش الزامی هستند',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate position is positive integer
    if (!Number.isInteger(position) || position <= 0) {
      console.error('❌ Invalid position');
      return new Response(
        JSON.stringify({
          error: 'موقعیت نمایش باید عدد صحیح مثبت باشد',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Insert banner
    const { data: banner, error: insertError } = await supabaseClient
      .from('banners')
      .insert({
        title,
        description,
        image_url,
        link_url,
        position,
        is_active,
      })
      .select()
      .single();

    if (insertError) {
      console.error('❌ Insert error:', insertError);
      return new Response(
        JSON.stringify({
          error: `خطا در ذخیره بنر: ${insertError.message}`,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Increment change_count for banners
    const { error: changeCountError } = await supabaseClient.rpc('increment_change_count', {
      table_name: 'banners',
      grade_id: null, // banners is not grade-specific
    });

    if (changeCountError) {
      console.error('❌ Change count error:', changeCountError);
      // Don't fail the request for this, just log it
    } else {
      console.log('✅ Change count incremented for banners');
    }

    console.log('✅ Banner created successfully:', banner.id);

    return new Response(
      JSON.stringify({
        message: 'بنر با موفقیت ایجاد شد',
        banner_id: banner.id,
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
