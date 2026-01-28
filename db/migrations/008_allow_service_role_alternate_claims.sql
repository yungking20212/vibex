-- 008_allow_service_role_alternate_claims.sql
-- Add fallback checks for service_role JWT claim locations used by Supabase.

BEGIN;

-- Ensure previous policy is removed safely
DROP POLICY IF EXISTS allow_service_role_insert ON public.beta_signups;

-- Create a policy that allows INSERT when either common JWT claim
-- locations indicate the request is from the service_role key.
CREATE POLICY allow_service_role_insert
  ON public.beta_signups
  FOR INSERT
  WITH CHECK (
    current_setting('jwt.claims.role', true) = 'service_role'
    OR current_setting('request.jwt.claims.role', true) = 'service_role'
  );

COMMIT;
