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
    const { phone, otp } = await req.json();
    if (!phone || !otp) {
      return new Response(
        JSON.stringify({ error: "شماره تلفن و کد OTP الزامی است" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Normalize phone to E.164 (Iran): +98XXXXXXXXXX
    const normalizePhone = (raw: string) => {
      let p = raw.trim().replace(/\s+/g, '');
      if (p.startsWith('+')) return p;
      if (p.startsWith('0098')) return '+' + p.slice(2);
      if (p.startsWith('98')) return '+' + p;
      if (p.startsWith('0') && p.length === 11) return '+98' + p.slice(1);
      return p; // fallback
    };
    const normalizedPhone = normalizePhone(phone);
    // Build candidate formats to be robust against legacy rows
    const phoneCandidates = new Set<string>([normalizedPhone]);
    if (phone.startsWith('0') && phone.length === 11) phoneCandidates.add(phone);
    if (normalizedPhone.startsWith('+98')) phoneCandidates.add('0' + normalizedPhone.slice(3));

    // استفاده از Service Role برای دور زدن RLS در فانکشن و اعمال منطق سروری
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'ENV ناقص است: SUPABASE_URL یا SUPABASE_SERVICE_ROLE_KEY تنظیم نشده' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // آخرین OTP معتبر را بررسی کن
    const { data: rows, error: otpError } = await supabase
      .from('otp_codes')
      .select()
      .in('phone_number', Array.from(phoneCandidates))
      .eq('otp_code', otp)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1);

    if (otpError) {
      throw new Error(`خطا در بررسی OTP: ${otpError.message}`);
    }

    if (!rows || rows.length === 0) {
      return new Response(
        JSON.stringify({ error: "کد تأیید نامعتبر یا منقضی شده است" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // پاکسازی OTP مصرف شده (همه‌ی رکوردهای مطابق)
    await supabase
      .from('otp_codes')
      .delete()
      .in('phone_number', Array.from(phoneCandidates))
      .eq('otp_code', otp);

    // پروفایل موجود را حفظ کن؛ اگر نبود، ایجاد کن
    const now = new Date().toISOString();
    const { data: existingProfiles, error: fetchProfileErr } = await supabase
      .from('profiles')
      .select()
      .in('phone_number', Array.from(phoneCandidates))
      .order('created_at', { ascending: false })
      .limit(1);

    if (fetchProfileErr) {
      throw new Error(`خطا در خواندن پروفایل: ${fetchProfileErr.message}`);
    }

    let profile = existingProfiles && existingProfiles.length > 0 ? existingProfiles[0] : null;

    if (!profile) {
      const userId = crypto.randomUUID();
      const { data: inserted, error: insertErr } = await supabase
        .from('profiles')
        .insert({
          user_id: userId,
          phone_number: normalizedPhone,
          user_role: 'student',
          registration_stage: 'step1',
          created_at: now,
          last_stage_update: now,
        })
        .select()
        .limit(1);

      if (insertErr) {
        throw new Error(`خطا در ایجاد پروفایل: ${insertErr.message}`);
      }

      profile = inserted && inserted.length > 0 ? inserted[0] : null;
    }

    return new Response(
      JSON.stringify({ success: true, user: profile }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});