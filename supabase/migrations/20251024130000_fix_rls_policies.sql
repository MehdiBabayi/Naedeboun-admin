-- Migration: Fix RLS Policies for Ban System
-- Created: 2025-10-24 13:00:00

-- حذف policy های قدیمی (اگر وجود دارند)
DROP POLICY IF EXISTS "Service role can manage user_bans" ON user_bans;
DROP POLICY IF EXISTS "Service role can manage otp_rate_limits" ON otp_rate_limits;
DROP POLICY IF EXISTS "Anon can check ban status" ON user_bans;
DROP POLICY IF EXISTS "Anon can check rate limits" ON otp_rate_limits;

-- فعال کردن RLS برای جداول ban system
ALTER TABLE user_bans ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_rate_limits ENABLE ROW LEVEL SECURITY;

-- Policy برای Service Role - فقط Service Role می‌تواند به این جداول دسترسی داشته باشد
CREATE POLICY "Service role can manage user_bans" ON user_bans
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage otp_rate_limits" ON otp_rate_limits  
  FOR ALL USING (auth.role() = 'service_role');

-- Policy برای anon role - فقط خواندن برای بررسی ban status
CREATE POLICY "Anon can check ban status" ON user_bans
  FOR SELECT USING (auth.role() = 'anon');

-- Policy برای anon role - فقط خواندن rate limits
CREATE POLICY "Anon can check rate limits" ON otp_rate_limits  
  FOR SELECT USING (auth.role() = 'anon');

