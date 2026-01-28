-- 006_create_beta_signups.sql
-- Idempotent migration to create a beta_signups table for storing beta email requests.

BEGIN;

-- Ensure pgcrypto is available for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create table if not exists
CREATE TABLE IF NOT EXISTS public.beta_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Grant minimal privileges to authenticated role if desired (optional)
-- Uncomment and adjust if you have an "authenticated" role to allow inserts via server functions
-- GRANT INSERT ON public.beta_signups TO authenticated;

COMMIT;
