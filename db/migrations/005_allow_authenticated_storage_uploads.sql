-- Migration: allow authenticated users to insert into the `videos` storage bucket
-- NOTE: Run this in Supabase SQL editor or via psql connected to your DB. Review before applying.

-- Allow authenticated users to INSERT objects into the 'videos' bucket
-- For INSERT, Postgres only allows a WITH CHECK expression (no USING clause).
-- Drop existing policies if present to allow re-running this migration safely
DROP POLICY IF EXISTS allow_authenticated_insert_videos ON storage.objects;
DROP POLICY IF EXISTS allow_select_videos ON storage.objects;
DROP POLICY IF EXISTS allow_owner_update_delete ON storage.objects;

CREATE POLICY allow_authenticated_insert_videos ON storage.objects
  FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated' AND
    bucket_id = 'videos'
  );

-- Allow anyone (or authenticated users) to SELECT objects in the 'videos' bucket
-- Adjust auth.role() check as needed. This allows reads (list/get) for that bucket.
CREATE POLICY allow_select_videos ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'videos'
  );

-- Optional: allow owners to UPDATE or DELETE their own objects
-- Create separate policies for UPDATE and DELETE (Postgres does not accept comma-separated actions)
CREATE POLICY allow_owner_update ON storage.objects
  FOR UPDATE
  USING (
    auth.uid() = owner
  )
  WITH CHECK (
    auth.uid() = owner
  );

CREATE POLICY allow_owner_delete ON storage.objects
  FOR DELETE
  USING (
    auth.uid() = owner
  );

-- If you have an existing conflicting policy, you may need to DROP it first.
-- Example: DROP POLICY IF EXISTS "policy_name" ON storage.objects;

-- IMPORTANT: Review these policies with your security model. Using
-- `bucket_id = 'videos'` scopes policies to that bucket. Do NOT grant
-- overly-broad privileges in production. Consider using signed URLs
-- or server-side upload endpoints (service role key) for stricter control.
