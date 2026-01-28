-- 007_allow_service_role_inserts_beta_signups.sql
-- Idempotent migration to enable RLS and add a policy allowing inserts
-- from the Supabase service role for the `beta_signups` table.

BEGIN;

-- Enable row-level security on the table (no-op if already enabled)
ALTER TABLE IF EXISTS public.beta_signups ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if present, then create a policy that allows inserts
-- when the request is authorized with the service_role key.
DROP POLICY IF EXISTS allow_service_role_insert ON public.beta_signups;

-- For INSERT policies, PostgreSQL only accepts a WITH CHECK expression.
-- Allow inserts where the JWT claim `role` equals `service_role`.
CREATE POLICY allow_service_role_insert
  ON public.beta_signups
  FOR INSERT
  WITH CHECK ( current_setting('jwt.claims.role', true) = 'service_role' );

COMMIT;
