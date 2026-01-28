-- Migration: maintain follow/like counters and create user_stats view
-- Run in Supabase SQL Editor or via migration runner

-- Function to refresh follower/following counts for affected users
CREATE OR REPLACE FUNCTION refresh_follow_counts() RETURNS TRIGGER AS $$
BEGIN
  -- Update follower count for the user being followed
  UPDATE users
  SET followers_count = (
    SELECT COUNT(*) FROM follows WHERE following_id = NEW.following_id
  )
  WHERE id = NEW.following_id;

  -- Update following count for the follower
  UPDATE users
  SET following_count = (
    SELECT COUNT(*) FROM follows WHERE follower_id = NEW.follower_id
  )
  WHERE id = NEW.follower_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for inserts into follows
DROP TRIGGER IF EXISTS follows_after_insert ON follows;
CREATE TRIGGER follows_after_insert
AFTER INSERT ON follows
FOR EACH ROW EXECUTE FUNCTION refresh_follow_counts();

-- Trigger for deletes from follows: use OLD values
CREATE OR REPLACE FUNCTION refresh_follow_counts_delete() RETURNS TRIGGER AS $$
BEGIN
  UPDATE users
  SET followers_count = (
    SELECT COUNT(*) FROM follows WHERE following_id = OLD.following_id
  )
  WHERE id = OLD.following_id;

  UPDATE users
  SET following_count = (
    SELECT COUNT(*) FROM follows WHERE follower_id = OLD.follower_id
  )
  WHERE id = OLD.follower_id;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS follows_after_delete ON follows;
CREATE TRIGGER follows_after_delete
AFTER DELETE ON follows
FOR EACH ROW EXECUTE FUNCTION refresh_follow_counts_delete();

-- Functions to refresh user likes_count based on likes table (per user)
CREATE OR REPLACE FUNCTION refresh_user_likes_on_insert() RETURNS TRIGGER AS $$
BEGIN
  -- Recompute likes_count for the owner of the liked video
  UPDATE users
  SET likes_count = (
    SELECT COALESCE(SUM(v.likes),0) FROM videos v WHERE v.user_id = (
      SELECT user_id FROM videos WHERE id = NEW.video_id
    )
  )
  WHERE id = (
    SELECT user_id FROM videos WHERE id = NEW.video_id
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_user_likes_on_delete() RETURNS TRIGGER AS $$
BEGIN
  UPDATE users
  SET likes_count = (
    SELECT COALESCE(SUM(v.likes),0) FROM videos v WHERE v.user_id = (
      SELECT user_id FROM videos WHERE id = OLD.video_id
    )
  )
  WHERE id = (
    SELECT user_id FROM videos WHERE id = OLD.video_id
  );

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS likes_after_insert ON likes;
CREATE TRIGGER likes_after_insert
AFTER INSERT ON likes
FOR EACH ROW EXECUTE FUNCTION refresh_user_likes_on_insert();

DROP TRIGGER IF EXISTS likes_after_delete ON likes;
CREATE TRIGGER likes_after_delete
AFTER DELETE ON likes
FOR EACH ROW EXECUTE FUNCTION refresh_user_likes_on_delete();

-- Create a view aggregating user stats (followers, following, likes, total_views)
CREATE OR REPLACE VIEW user_stats AS
SELECT
  u.id AS user_id,
  u.username,
  u.avatar_url,
  u.bio,
  COALESCE(u.followers_count, 0) AS followers_count,
  COALESCE(u.following_count, 0) AS following_count,
  COALESCE(u.likes_count, 0) AS likes_count,
  COALESCE(SUM(v.likes), 0) AS total_video_likes,
  COALESCE(SUM(v.views), 0) AS total_video_views
FROM users u
LEFT JOIN videos v ON v.user_id = u.id
GROUP BY u.id, u.username, u.avatar_url, u.bio, u.followers_count, u.following_count, u.likes_count;

-- Grant select on the view to authenticated role
GRANT SELECT ON user_stats TO authenticated;
