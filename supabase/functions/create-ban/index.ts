import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, serviceRoleKey);
    
    const body = await req.json();
    
    console.log('🔨 [CREATE-BAN] Request received');
    
    // Validation
    if (!body.user_id && !body.phone_number && !body.device_id) {
      console.log('❌ [CREATE-BAN] No identifier provided');
      return new Response(
        JSON.stringify({ error: 'حداقل یکی از شناسه‌ها الزامی است' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    if (!body.banned_by) {
      console.log('❌ [CREATE-BAN] banned_by is required');
      return new Response(
        JSON.stringify({ error: 'banned_by الزامی است' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const now = new Date();
    const bannedUntil = body.duration_hours 
      ? new Date(now.getTime() + body.duration_hours * 3600000)
      : null;

    console.log('🔨 [CREATE-BAN] Creating ban:', {
      user_id: body.user_id || 'N/A',
      phone: body.phone_number || 'N/A',
      device: body.device_id ? body.device_id.substring(0, 8) + '...' : 'N/A',
      duration: body.duration_hours ? `${body.duration_hours}h` : 'permanent'
    });

    const { data, error } = await supabase
      .from('user_bans')
      .insert({
        user_id: body.user_id || null,
        phone_number: body.phone_number || null,
        device_id: body.device_id || null,
        ban_type: body.ban_type || 'manual_admin',
        reason: body.reason || 'مسدود شده توسط ادمین',
        banned_by: body.banned_by,
        banned_at: now.toISOString(),
        banned_until: bannedUntil?.toISOString() || null,
        is_permanent: !body.duration_hours,
        is_active: true,
        ip_address: body.ip_address || null,
        additional_data: body.additional_data || null
      })
      .select()
      .single();

    if (error) {
      console.error('❌ [CREATE-BAN] Database error:', error);
      throw error;
    }

    console.log('✅ [CREATE-BAN] Ban created successfully:', data.id);

    return new Response(
      JSON.stringify({ success: true, ban: data }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('❌ [CREATE-BAN] Error:', error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

