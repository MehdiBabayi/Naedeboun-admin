import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// مدت زمان اعتبار OTP به دقیقه (۱ دقیقه)
const OTP_EXPIRY_MINUTES = 1;

serve(async (req) => {
  // مدیریت CORS برای درخواست‌های OPTIONS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // اجازه درخواست بدون هدر Authorization (ارسال OTP برای کاربرانی که هنوز لاگین نکرده‌اند)
    // ایجاد Supabase client با Service Role برای نوشتن مطمئن در DB
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'ENV ناقص است: SUPABASE_URL یا SUPABASE_SERVICE_ROLE_KEY تنظیم نشده' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { phone, device_id, devMode } = await req.json();
    
    // Validation
    if (!phone) {
      return new Response(
        JSON.stringify({ error: "شماره تلفن الزامی است" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    if (!device_id || device_id.trim() === '') {
      console.log('❌ [SEND-OTP] Missing device_id');
      return new Response(
        JSON.stringify({ error: 'Device ID is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Sending OTP to: ${phone}, DevMode: ${devMode}`);
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
    console.log('🔍 [SEND-OTP] Phone:', normalizedPhone, 'Device:', device_id.substring(0, 8) + '...');

    // ========== 1. چک کردن Ban ==========
    console.log('🔍 [SEND-OTP] Checking ban status...');

    const { data: activeBans } = await supabase
      .from('user_bans')
      .select('*')
      .eq('is_active', true)
      .or(`phone_number.eq.${normalizedPhone},device_id.eq.${device_id}`)
      .limit(1);

    if (activeBans && activeBans.length > 0) {
      const ban = activeBans[0];
      const now = new Date();
      const isExpired = ban.banned_until && new Date(ban.banned_until) <= now;
      
      if (ban.is_permanent || !isExpired) {
        console.log('🚫 [SEND-OTP] User is BANNED:', ban.id);
        
        let errorMessage = 'حساب شما مسدود شده است.';
        if (ban.is_permanent) {
          errorMessage = 'حساب شما به صورت دائم مسدود شده است. لطفاً با پشتیبانی تماس بگیرید.';
        } else if (ban.banned_until) {
          const until = new Date(ban.banned_until);
          const remainingMs = until.getTime() - now.getTime();
          const hours = Math.floor(remainingMs / 3600000);
          const minutes = Math.floor((remainingMs % 3600000) / 60000);
          errorMessage = `شما تا ${hours} ساعت و ${minutes} دقیقه دیگر مسدود هستید. دلیل: ${ban.reason || 'تخلف'}`;
        }
        
        return new Response(
          JSON.stringify({ error: errorMessage }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      } else {
        // Ban منقضی شده
        console.log('🔄 [SEND-OTP] Ban expired, deactivating');
        await supabase
          .from('user_bans')
          .update({ is_active: false, updated_at: new Date().toISOString() })
          .eq('id', ban.id);
      }
    }

    console.log('✅ [SEND-OTP] User is NOT banned');

    // ========== 2. Rate Limiting (Logic صحیح) ==========
    console.log('📊 [SEND-OTP] Checking rate limit...');

    // Cleanup رکوردهای قدیمی (بیش از 1 ساعت)
    const oneHourAgo = new Date(Date.now() - 3600000);
    await supabase
      .from('otp_rate_limits')
      .delete()
      .lt('window_start_at', oneHourAgo.toISOString());

    // SELECT ابتدا - خواندن رکورد فعلی
    const { data: existingLimit } = await supabase
      .from('otp_rate_limits')
      .select('*')
      .eq('phone_number', normalizedPhone)
      .eq('device_id', device_id)
      .maybeSingle();

    const now = new Date();

    if (existingLimit) {
      // رکورد وجود دارد - چک کنیم window منقضی شده یا نه
      const windowStart = new Date(existingLimit.window_start_at);
      const windowAge = now.getTime() - windowStart.getTime();
      
      if (windowAge > 3600000) {
        // Window منقضی شده (بیش از 1 ساعت) - reset
        console.log('🔄 [SEND-OTP] Window expired, resetting');
        await supabase
          .from('otp_rate_limits')
          .update({
            attempt_count: 1,
            window_start_at: now.toISOString(),
            last_attempt_at: now.toISOString()
          })
          .eq('phone_number', normalizedPhone)
          .eq('device_id', device_id);
        
        console.log('✅ [SEND-OTP] Rate limit: 1/5 (reset)');
      } else {
        // Window هنوز فعال - increment
        const newCount = existingLimit.attempt_count + 1;
        console.log(`📈 [SEND-OTP] Attempts: ${newCount}/5`);
        
        if (newCount > 5) {
          // بیش از 5 تلاش - ban
          console.log('🔨 [SEND-OTP] Rate limit EXCEEDED, creating ban...');
          
          await supabase.from('user_bans').insert({
            phone_number: normalizedPhone,
            device_id: device_id,
            ban_type: 'rate_limit',
            reason: 'بیش از 5 درخواست OTP در 1 ساعت',
            banned_by: 'system',
            banned_at: now.toISOString(),
            banned_until: new Date(now.getTime() + 3 * 3600000).toISOString(),
            is_permanent: false,
            is_active: true,
            ip_address: req.headers.get('x-forwarded-for'),
            additional_data: { attempts: newCount }
          });
          
          return new Response(
            JSON.stringify({ 
              error: 'تعداد تلاش بیش از حد مجاز است. شما تا 3 ساعت دیگر مسدود هستید.' 
            }),
            { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        
        // Update attempt count
        await supabase
          .from('otp_rate_limits')
          .update({
            attempt_count: newCount,
            last_attempt_at: now.toISOString()
          })
          .eq('phone_number', normalizedPhone)
          .eq('device_id', device_id);
        
        console.log(`✅ [SEND-OTP] Rate limit: ${newCount}/5`);
      }
    } else {
      // رکورد وجود ندارد - اولین تلاش - INSERT
      console.log('🆕 [SEND-OTP] First attempt, creating record');
      await supabase
        .from('otp_rate_limits')
        .insert({
          phone_number: normalizedPhone,
          device_id: device_id,
          attempt_count: 1,
          window_start_at: now.toISOString(),
          last_attempt_at: now.toISOString()
        });
      
      console.log('✅ [SEND-OTP] Rate limit: 1/5 (new)');
    }

    console.log('✅ [SEND-OTP] Rate limit OK, proceeding with OTP...');

    // تولید کد OTP
    const otpCode = Math.floor(1000 + Math.random() * 9000).toString();
    const expiryTime = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);
    
    // اگر در حالت توسعه هستیم
    if (devMode === true) {
      console.log(`🔧 DEV MODE: Using default OTP 0000 for phone: ${phone}`);
      
      // ذخیره/به‌روزرسانی OTP پیش‌فرض در پایگاه داده (UPSERT روی phone_number)
      const { error: dbError } = await supabase
        .from('otp_codes')
        .upsert(
          {
            phone_number: normalizedPhone,
            otp_code: '0000',
            expires_at: expiryTime.toISOString(),
            created_at: new Date().toISOString(),
          },
          { onConflict: 'phone_number', ignoreDuplicates: false }
        );
    
      if (dbError) {
        throw new Error(`خطا در ذخیره OTP: ${dbError.message}`);
      }
    
      return new Response(
        JSON.stringify({
          success: true,
          message: `کد تأیید پیش‌فرض برای حالت توسعه ارسال شد`,
          code: "0000",
          devMode: true,
          status: "ارسال موفق بود (حالت توسعه)"
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }
    
    // حالت عادی - ارسال SMS واقعی
    // ذخیره/به‌روزرسانی OTP در پایگاه داده با زمان انقضا (UPSERT روی phone_number)
    const { error: dbError } = await supabase
      .from('otp_codes')
      .upsert(
        {
          phone_number: normalizedPhone,
          otp_code: otpCode,
          expires_at: expiryTime.toISOString(),
          created_at: new Date().toISOString(),
        },
        { onConflict: 'phone_number', ignoreDuplicates: false }
      );
    
    if (dbError) {
      throw new Error(`خطا در ذخیره OTP: ${dbError.message}`);
    }
    
    // ارسال SMS با ملی پیامک
    const MELI_PAYAMAK_URL = "https://console.melipayamak.com/api/send/shared/1e86d69e16204bc0bd1649497b2c32ff";
    const body = {
      bodyId: 299528,
      to: normalizedPhone,
      args: [otpCode, OTP_EXPIRY_MINUTES.toString()]
    };
    
    console.log(`Calling MeliPayamak API with OTP: ${otpCode}`);
    
    const response = await fetch(MELI_PAYAMAK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body)
    });
    
    if (!response.ok) {
      throw new Error(`Failed to send SMS. Status: ${response.status}`);
    }
    
    const result = await response.json();
    console.log(`SMS sent successfully. recId: ${result.recId}, status: ${result.status}`);
    
    return new Response(
      JSON.stringify({
        success: true,
        message: `کد تأیید با موفقیت ارسال شد. این کد تا ${OTP_EXPIRY_MINUTES} دقیقه معتبر است.`,
        code: otpCode,
        status: result.status,
        devMode: false
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error("Error in send-otp function:", error);
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});