-- Add nullable timestamp column to track when a user first completed
-- (or skipped) the dashboard tutorial. NULL means the tour has not been
-- shown / completed yet. A timestamp means the user has seen it.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS tutorial_seen_at TIMESTAMPTZ;
