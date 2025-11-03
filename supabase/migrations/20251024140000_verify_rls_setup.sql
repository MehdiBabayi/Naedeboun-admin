-- Migration: Verify RLS Setup
-- Created: 2025-10-24 14:00:00

-- بررسی وضعیت RLS
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('user_bans', 'otp_rate_limits');

-- بررسی policy های موجود
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename IN ('user_bans', 'otp_rate_limits');

-- اگر RLS فعال نیست، آن را فعال کن
ALTER TABLE user_bans ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_rate_limits ENABLE ROW LEVEL SECURITY;

-- Policy های جدید
CREATE POLICY "Service role full access user_bans" ON user_bans
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access otp_rate_limits" ON otp_rate_limits  
  FOR ALL USING (auth.role() = 'service_role');

-- Policy برای anon role (فقط خواندن)
CREATE POLICY "Anon read user_bans" ON user_bans
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon read otp_rate_limits" ON otp_rate_limits  
  FOR SELECT USING (auth.role() = 'anon');

