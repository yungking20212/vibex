-- Migration: Create storage insert policy for authenticated users
-- This allows authenticated users to INSERT into storage.objects
-- Ensure RLS is enabled on the storage.objects table before adding the policy

-- Enable row level security (harmless if already enabled)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated uploads"
  ON storage.objects
  FOR INSERT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

-- NOTE:
-- Apply this migration with psql or via your Supabase SQL editor.
-- Example:
-- psql "postgres://<user>:<pass>@<host>:5432/postgres" -f db/migrations/001_create_authenticated_uploads_policy.sql
