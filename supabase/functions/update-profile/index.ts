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
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'ENV ناقص است: SUPABASE_URL یا SUPABASE_SERVICE_ROLE_KEY تنظیم نشده' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const { phone, step, payload, devMode } = body as {
      phone: string;
      step: 'step1' | 'step2' | 'completed' | 'update'; // 'update' added
      payload: Record<string, unknown>;
      devMode?: boolean;
    };

    if (!phone || !step || !payload) {
      return new Response(JSON.stringify({ error: 'پارامترهای لازم ناقص است' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const normalizePhone = (raw: string) => {
      let p = raw.trim().replace(/\s+/g, '');
      if (p.startsWith('+')) return p;
      if (p.startsWith('0098')) return '+' + p.slice(2);
      if (p.startsWith('98')) return '+' + p;
      if (p.startsWith('0') && p.length === 11) return '+98' + p.slice(1);
      return p;
    };
    const normalizedPhone = normalizePhone(phone);

    const now = new Date();
    const today = now.toISOString().split('T')[0]; // YYYY-MM-DD format
    
    let updateFields: Record<string, unknown> = { ...payload, last_stage_update: now.toISOString() };

    if (step === 'step1') {
      updateFields['registration_stage'] = 'step2';
      updateFields['step1_completed_at'] = now.toISOString();
    } else if (step === 'step2') {
      updateFields['registration_stage'] = 'completed';
      updateFields['step2_completed_at'] = now.toISOString();
    } else if (step === 'completed') {
      updateFields['registration_stage'] = 'completed';
    } else if (step === 'update') {
      // New 1-hour ban system logic (40 updates per hour max)
      const { data: profileData, error: profileError } = await supabase
        .from('profiles')
        .select('ban_until, update_count_window_start, updates_in_window, last_update_date, updates_today_count')
        .in('phone_number', [normalizedPhone, '0' + normalizedPhone.slice(3)])
        .single();

      if (profileError || !profileData) {
        return new Response(JSON.stringify({ error: 'پروفایل برای بررسی محدودیت یافت نشد' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      const { ban_until, update_count_window_start, updates_in_window } = profileData;
      
      // Constants for new rate limit system
      const MAX_UPDATES_PER_HOUR = 40;
      const BAN_DURATION_MS = 60 * 60 * 1000; // 1 hour in milliseconds
      const WINDOW_DURATION_MS = 60 * 60 * 1000; // 1 hour window

      // Check if user is currently banned
      if (ban_until && new Date(ban_until) > now) {
        const banEndTime = new Date(ban_until);
        const remainingMinutes = Math.ceil((banEndTime.getTime() - now.getTime()) / (1000 * 60));
        return new Response(JSON.stringify({ 
          error: `شما به حد مجاز 40 بار تغییر رسیده‌اید. ${remainingMinutes} دقیقه دیگر می‌توانید دوباره تلاش کنید.` 
        }), { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // Skip rate limit in dev mode
      if (devMode) {
        console.log('Dev mode: Skipping rate limit check');
      } else {
        // Check if window has expired (more than 1 hour ago)
        const windowStart = update_count_window_start ? new Date(update_count_window_start) : null;
        const windowExpired = !windowStart || (now.getTime() - windowStart.getTime()) > WINDOW_DURATION_MS;
        
        if (windowExpired) {
          // Start new window
          updateFields['update_count_window_start'] = now.toISOString();
          updateFields['updates_in_window'] = 1;
          updateFields['ban_until'] = null; // Clear any existing ban
        } else {
          // Within current window
          const currentCount = updates_in_window || 0;
          const newCount = currentCount + 1;
          
          if (newCount >= MAX_UPDATES_PER_HOUR) {
            // User has reached limit - ban for 1 hour
            const banUntil = new Date(now.getTime() + BAN_DURATION_MS);
            updateFields['ban_until'] = banUntil.toISOString();
            updateFields['updates_in_window'] = newCount;
            
            return new Response(JSON.stringify({ 
              error: 'شما 40 بار پایه تحصیلی را تغییر داده‌اید. برای 1 ساعت نمی‌توانید تغییر دهید.' 
            }), { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
          } else {
            // Increment counter
            updateFields['updates_in_window'] = newCount;
          }
        }
      }
      
      // Keep old fields for backward compatibility (will be removed in future)
      const { last_update_date, updates_today_count } = profileData;
      if (last_update_date === today) {
        updateFields['updates_today_count'] = (updates_today_count || 0) + 1;
      } else {
        updateFields['last_update_date'] = today;
        updateFields['updates_today_count'] = 1;
      }
    }

    const { data, error } = await supabase
      .from('profiles')
      .update(updateFields)
      .in('phone_number', [normalizedPhone, '0' + normalizedPhone.slice(3)])
      .select()
      .limit(1);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const profile = Array.isArray(data) && data.length > 0 ? data[0] : null;
    if (!profile) {
      return new Response(JSON.stringify({ error: 'پروفایل یافت نشد' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify({ success: true, user: profile }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});


