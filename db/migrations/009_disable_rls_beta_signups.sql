-- 009_disable_rls_beta_signups.sql
-- Idempotent migration to disable Row-Level Security for `beta_signups`.

BEGIN;

-- Drop any related policy to avoid conflicts
DROP POLICY IF EXISTS allow_service_role_insert ON public.beta_signups;

-- Disable RLS if enabled
ALTER TABLE IF EXISTS public.beta_signups DISABLE ROW LEVEL SECURITY;

COMMIT;
