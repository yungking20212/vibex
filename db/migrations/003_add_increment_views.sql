-- Migration: add increment_views RPC
-- Run in Supabase SQL Editor or via migration runner

CREATE OR REPLACE FUNCTION increment_views(video_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE videos
    SET views = views + 1
    WHERE id = video_id;
END;
$$ LANGUAGE plpgsql;
