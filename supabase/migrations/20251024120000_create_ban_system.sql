-- Migration: Create Ban System
-- Created: 2025-10-24 12:00:00

-- جدول اصلی برای ban ها
CREATE TABLE user_bans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  phone_number TEXT,
  device_id TEXT,
  ban_type TEXT NOT NULL CHECK (ban_type IN ('rate_limit', 'manual_admin', 'abuse', 'spam')),
  reason TEXT,
  banned_by TEXT NOT NULL,
  banned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  banned_until TIMESTAMP WITH TIME ZONE,
  is_permanent BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  ip_address TEXT,
  additional_data JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index های ضروری برای user_bans
CREATE INDEX idx_bans_active ON user_bans(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_bans_phone_active ON user_bans(phone_number, is_active);
CREATE INDEX idx_bans_device_active ON user_bans(device_id, is_active);
CREATE INDEX idx_bans_expires ON user_bans(banned_until) WHERE is_active = TRUE;

-- Constraint: حداقل یکی از شناسه‌ها باید پر باشد
ALTER TABLE user_bans ADD CONSTRAINT check_has_identifier 
  CHECK (user_id IS NOT NULL OR phone_number IS NOT NULL OR device_id IS NOT NULL);

-- جدول rate limiting
CREATE TABLE otp_rate_limits (
  phone_number TEXT NOT NULL,
  device_id TEXT NOT NULL,
  attempt_count INTEGER DEFAULT 1,
  window_start_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_attempt_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (phone_number, device_id)
);

CREATE INDEX idx_rate_limit_window ON otp_rate_limits(window_start_at);

-- Function برای auto-update timestamp
CREATE OR REPLACE FUNCTION update_user_bans_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_bans_updated_at
  BEFORE UPDATE ON user_bans
  FOR EACH ROW
  EXECUTE FUNCTION update_user_bans_timestamp();

-- ========== RLS (Row Level Security) ==========
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
