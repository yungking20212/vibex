-- Sample Data for Testing VibeX App
-- Run this AFTER running schema.sql
-- This will create sample users and videos for testing

-- Insert sample users
INSERT INTO users (id, username, email, avatar_url, bio, followers_count, following_count, likes_count, created_at)
VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'alex_vibes', 'alex@example.com', NULL, 'Dance enthusiast 💃', 1250, 320, 15600, NOW() - INTERVAL '30 days'),
    ('550e8400-e29b-41d4-a716-446655440002', 'sarah_music', 'sarah@example.com', NULL, 'Music producer 🎵', 3400, 156, 42000, NOW() - INTERVAL '60 days'),
    ('550e8400-e29b-41d4-a716-446655440003', 'mike_creative', 'mike@example.com', NULL, 'Creative mind ✨', 890, 445, 8900, NOW() - INTERVAL '15 days'),
    ('550e8400-e29b-41d4-a716-446655440004', 'emma_fitness', 'emma@example.com', NULL, 'Fitness coach 💪', 5600, 234, 67000, NOW() - INTERVAL '90 days'),
    ('550e8400-e29b-41d4-a716-446655440005', 'david_chef', 'david@example.com', NULL, 'Cooking with passion 🍳', 2100, 567, 23000, NOW() - INTERVAL '45 days');

-- Insert sample videos
INSERT INTO videos (id, user_id, username, caption, video_url, thumbnail_url, likes, comments, shares, views, created_at)
VALUES
    -- Alex's videos
    (
        '660e8400-e29b-41d4-a716-446655440001',
        '550e8400-e29b-41d4-a716-446655440001',
        '@alex_vibes',
        'New dance routine! 🔥 #dance #vibes',
        'https://example.com/video1.mp4',
        NULL,
        1234,
        89,
        45,
        15600,
        NOW() - INTERVAL '1 days'
    ),
    (
        '660e8400-e29b-41d4-a716-446655440002',
        '550e8400-e29b-41d4-a716-446655440001',
        '@alex_vibes',
        'Behind the scenes of my latest performance ✨',
        'https://example.com/video2.mp4',
        NULL,
        892,
        56,
        23,
        8900,
        NOW() - INTERVAL '3 days'
    ),
    
    -- Sarah's videos
    (
        '660e8400-e29b-41d4-a716-446655440003',
        '550e8400-e29b-41d4-a716-446655440002',
        '@sarah_music',
        'Beat drop incoming! 🎵 #music #producer',
        'https://example.com/video3.mp4',
        NULL,
        5678,
        234,
        156,
        42000,
        NOW() - INTERVAL '2 days'
    ),
    (
        '660e8400-e29b-41d4-a716-446655440004',
        '550e8400-e29b-41d4-a716-446655440002',
        '@sarah_music',
        'How I make beats in my bedroom studio 🎹',
        'https://example.com/video4.mp4',
        NULL,
        3421,
        178,
        89,
        28000,
        NOW() - INTERVAL '5 days'
    ),
    
    -- Mike's videos
    (
        '660e8400-e29b-41d4-a716-446655440005',
        '550e8400-e29b-41d4-a716-446655440003',
        '@mike_creative',
        'Creative process revealed 🎨 #art #creative',
        'https://example.com/video5.mp4',
        NULL,
        2345,
        123,
        67,
        18900,
        NOW() - INTERVAL '1 days'
    ),
    (
        '660e8400-e29b-41d4-a716-446655440006',
        '550e8400-e29b-41d4-a716-446655440003',
        '@mike_creative',
        'Time-lapse of my digital art creation ⏱️',
        'https://example.com/video6.mp4',
        NULL,
        1567,
        89,
        34,
        12000,
        NOW() - INTERVAL '4 days'
    ),
    
    -- Emma's videos
    (
        '660e8400-e29b-41d4-a716-446655440007',
        '550e8400-e29b-41d4-a716-446655440004',
        '@emma_fitness',
        '10-minute morning workout routine! 💪 #fitness #workout',
        'https://example.com/video7.mp4',
        NULL,
        9012,
        456,
        234,
        67000,
        NOW() - INTERVAL '1 days'
    ),
    (
        '660e8400-e29b-41d4-a716-446655440008',
        '550e8400-e29b-41d4-a716-446655440004',
        '@emma_fitness',
        'Abs challenge - can you do all 5 exercises? 🔥',
        'https://example.com/video8.mp4',
        NULL,
        7834,
        389,
        189,
        54000,
        NOW() - INTERVAL '3 days'
    ),
    
    -- David's videos
    (
        '660e8400-e29b-41d4-a716-446655440009',
        '550e8400-e29b-41d4-a716-446655440005',
        '@david_chef',
        'Making the perfect pasta from scratch 🍝 #cooking #chef',
        'https://example.com/video9.mp4',
        NULL,
        4567,
        267,
        123,
        34000,
        NOW() - INTERVAL '2 days'
    ),
    (
        '660e8400-e29b-41d4-a716-446655440010',
        '550e8400-e29b-41d4-a716-446655440005',
        '@david_chef',
        '5-ingredient dessert that will blow your mind! 🍰',
        'https://example.com/video10.mp4',
        NULL,
        3890,
        198,
        87,
        28000,
        NOW() - INTERVAL '6 days'
    );

-- Insert sample comments
INSERT INTO comments (id, video_id, user_id, username, text, likes, created_at)
VALUES
    -- Comments on Alex's dance video
    (
        '770e8400-e29b-41d4-a716-446655440001',
        '660e8400-e29b-41d4-a716-446655440001',
        '550e8400-e29b-41d4-a716-446655440002',
        '@sarah_music',
        'This is amazing! 🔥🔥',
        45,
        NOW() - INTERVAL '12 hours'
    ),
    (
        '770e8400-e29b-41d4-a716-446655440002',
        '660e8400-e29b-41d4-a716-446655440001',
        '550e8400-e29b-41d4-a716-446655440003',
        '@mike_creative',
        'Can you teach me these moves?',
        23,
        NOW() - INTERVAL '8 hours'
    ),
    
    -- Comments on Sarah's music video
    (
        '770e8400-e29b-41d4-a716-446655440003',
        '660e8400-e29b-41d4-a716-446655440003',
        '550e8400-e29b-41d4-a716-446655440001',
        '@alex_vibes',
        'Need to dance to this immediately! 💃',
        67,
        NOW() - INTERVAL '18 hours'
    ),
    (
        '770e8400-e29b-41d4-a716-446655440004',
        '660e8400-e29b-41d4-a716-446655440003',
        '550e8400-e29b-41d4-a716-446655440004',
        '@emma_fitness',
        'Perfect workout music! 🎵',
        34,
        NOW() - INTERVAL '6 hours'
    ),
    
    -- Comments on Emma's fitness video
    (
        '770e8400-e29b-41d4-a716-446655440005',
        '660e8400-e29b-41d4-a716-446655440007',
        '550e8400-e29b-41d4-a716-446655440005',
        '@david_chef',
        'Great routine! Doing this every morning now 💪',
        89,
        NOW() - INTERVAL '5 hours'
    );

-- Insert sample likes
INSERT INTO likes (id, user_id, video_id, created_at)
VALUES
    -- Alex likes Sarah's video
    ('880e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440003', NOW() - INTERVAL '1 days'),
    
    -- Sarah likes Alex's video
    ('880e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '12 hours'),
    
    -- Mike likes Emma's video
    ('880e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440007', NOW() - INTERVAL '6 hours'),
    
    -- Emma likes David's video
    ('880e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440009', NOW() - INTERVAL '8 hours'),
    
    -- David likes Mike's video
    ('880e8400-e29b-41d4-a716-446655440005', '550e8400-e29b-41d4-a716-446655440005', '660e8400-e29b-41d4-a716-446655440005', NOW() - INTERVAL '4 hours');

-- Insert sample follows
INSERT INTO follows (id, follower_id, following_id, created_at)
VALUES
    -- Alex follows Sarah
    ('990e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '20 days'),
    
    -- Sarah follows Alex
    ('990e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '18 days'),
    
    -- Mike follows everyone
    ('990e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '10 days'),
    ('990e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '10 days'),
    ('990e8400-e29b-41d4-a716-446655440005', '550e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440004', NOW() - INTERVAL '10 days'),
    
    -- Emma follows Sarah and David
    ('990e8400-e29b-41d4-a716-446655440006', '550e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '15 days'),
    ('990e8400-e29b-41d4-a716-446655440007', '550e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440005', NOW() - INTERVAL '12 days'),
    
    -- David follows Emma and Alex
    ('990e8400-e29b-41d4-a716-446655440008', '550e8400-e29b-41d4-a716-446655440005', '550e8400-e29b-41d4-a716-446655440004', NOW() - INTERVAL '8 days'),
    ('990e8400-e29b-41d4-a716-446655440009', '550e8400-e29b-41d4-a716-446655440005', '550e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '5 days');

-- Verify the data was inserted
SELECT 'Users inserted:', COUNT(*) FROM users;
SELECT 'Videos inserted:', COUNT(*) FROM videos;
SELECT 'Comments inserted:', COUNT(*) FROM comments;
SELECT 'Likes inserted:', COUNT(*) FROM likes;
SELECT 'Follows inserted:', COUNT(*) FROM follows;
