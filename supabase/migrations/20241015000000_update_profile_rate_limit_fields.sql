-- Migration: Update Profile Rate Limit Fields
-- Date: 2024-10-15
-- Purpose: Change from daily limit (5/day) to 1-hour ban system (40/hour)

-- Add new columns for 1-hour ban system
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS ban_until timestamptz,
  ADD COLUMN IF NOT EXISTS update_count_window_start timestamptz,
  ADD COLUMN IF NOT EXISTS updates_in_window integer DEFAULT 0;

-- Create index for performance on ban_until lookups
CREATE INDEX IF NOT EXISTS idx_profiles_ban_until ON profiles(ban_until) WHERE ban_until IS NOT NULL;

-- Create index for performance on window_start lookups  
CREATE INDEX IF NOT EXISTS idx_profiles_window_start ON profiles(update_count_window_start) WHERE update_count_window_start IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN profiles.ban_until IS 'Timestamp when user ban expires (NULL = not banned)';
COMMENT ON COLUMN profiles.update_count_window_start IS 'Start of current 1-hour counting window';
COMMENT ON COLUMN profiles.updates_in_window IS 'Number of updates in current 1-hour window (max 40)';

-- Note: We keep last_update_date and updates_today_count for backward compatibility
-- They can be removed in a future migration after confirming new system works

