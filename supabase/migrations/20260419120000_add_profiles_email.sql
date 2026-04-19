-- Add nullable email column for OAuth email capture. Populated during
-- registration when Apple's "Hide My Email" or a missing-email sign-in
-- means supabase.auth.users.email isn't a usable real address.
-- NULL means "no captured email — use auth.users.email as fallback".
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS email TEXT;
