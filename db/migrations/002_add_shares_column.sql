-- Migration: add shares column to videos table (if missing)
-- Run this in Supabase SQL Editor or include in your migration runner.

ALTER TABLE videos
ADD COLUMN IF NOT EXISTS shares INTEGER DEFAULT 0;

-- Backfill existing rows if you want to ensure non-null values
UPDATE videos
SET shares = 0
WHERE shares IS NULL;
