-- 007_allow_service_role_inserts_beta_signups.sql
-- Idempotent migration to enable RLS and add a policy allowing inserts
-- from the Supabase service role for the `beta_signups` table.

BEGIN;

-- Enable row-level security on the table (no-op if already enabled)
ALTER TABLE IF EXISTS public.beta_signups ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if present, then create a policy that allows inserts
-- when the request is authorized with the service_role key. Supabase sets
-- the JWT claim `role` to `service_role` for requests made with the
-- service role key, so we check that value.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'beta_signups' AND policyname = 'allow_service_role_insert'
  ) THEN
    PERFORM pg_catalog.pg_policy_drop('public', 'beta_signups', 'allow_service_role_insert');
  END IF;
EXCEPTION WHEN undefined_table THEN
  -- ignore if pg_policies view not present in older PG versions
  NULL;
END$$;

-- Create the policy (drop-if-exists semantics handled above)
CREATE POLICY allow_service_role_insert
  ON public.beta_signups
  FOR INSERT
  USING ( current_setting('jwt.claims.role', true) = 'service_role' )
  WITH CHECK ( current_setting('jwt.claims.role', true) = 'service_role' );

COMMIT;
