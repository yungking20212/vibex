# 🏗️ VibeX App Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        VibeX App                            │
│                     (SwiftUI + iOS)                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    App Entry Point                          │
│                                                             │
│  vibexApp.swift                                             │
│  ├─ @StateObject SupabaseService                            │
│  └─ Conditionally shows:                                    │
│      ├─ AuthView (if not authenticated)                     │
│      └─ ContentView (if authenticated)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
    ┌──────────────────────┐   ┌──────────────────────┐
    │     AuthView.swift   │   │  ContentView.swift   │
    │                      │   │                      │
    │  - Sign Up Form      │   │  TabView with 4 tabs │
    │  - Sign In Form      │   │  ├─ FeedView         │
    │  - Input Validation  │   │  ├─ UploadView       │
    │                      │   │  ├─ DiscoverView     │
    └──────────────────────┘   │  └─ ProfileView      │
                               └──────────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
        ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
        │   FeedView       │  │  DiscoverView    │  │  ProfileView     │
        │                  │  │                  │  │                  │
        │ Vertical scroll  │  │ Grid of videos   │  │ User info        │
        │ Video player     │  │ Trending content │  │ User videos      │
        │ Like/Comment UI  │  │ View counts      │  │ Stats display    │
        └──────────────────┘  └──────────────────┘  └──────────────────┘
                    │                     │                     │
                    └─────────────────────┼─────────────────────┘
                                          ▼
                        ┌────────────────────────────────┐
                        │   SupabaseService.swift        │
                        │   (@MainActor ObservableObject)│
                        │                                │
                        │  Published Properties:         │
                        │  ├─ currentUser: User?         │
                        │  └─ isAuthenticated: Bool      │
                        │                                │
                        │  Methods:                      │
                        │  ├─ Authentication             │
                        │  ├─ User Management            │
                        │  ├─ Video Operations           │
                        │  ├─ Likes                      │
                        │  ├─ Comments                   │
                        │  └─ Follows                    │
                        └────────────────────────────────┘
                                          │
                                          ▼
                        ┌────────────────────────────────┐
                        │   SupabaseConfig.swift         │
                        │                                │
                        │  Singleton instance            │
                        │  ├─ Supabase URL               │
                        │  ├─ Supabase Anon Key          │
                        │  └─ SupabaseClient instance    │
                        └────────────────────────────────┘
                                          │
                                          ▼
                        ┌────────────────────────────────┐
                        │     Supabase Backend           │
                        │                                │
                        │  Services:                     │
                        │  ├─ Authentication (Auth)      │
                        │  ├─ Database (PostgreSQL)      │
                        │  └─ Storage (File Storage)     │
                        └────────────────────────────────┘
```

---

## Data Models

```
┌─────────────────────────────────────────────────────────────┐
│                      Models.swift                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  User                          VideoPost                    │
│  ├─ id                         ├─ id                        │
│  ├─ username                   ├─ userId                    │
│  ├─ email                      ├─ username                  │
│  ├─ avatarURL                  ├─ caption                   │
│  ├─ bio                        ├─ videoURL                  │
│  ├─ followersCount             ├─ thumbnailURL              │
│  ├─ followingCount             ├─ likes                     │
│  ├─ likesCount                 ├─ comments                  │
│  └─ createdAt                  ├─ shares                    │
│                                ├─ views                     │
│  Comment                       └─ createdAt                 │
│  ├─ id                                                      │
│  ├─ videoId                    Like                         │
│  ├─ userId                     ├─ id                        │
│  ├─ username                   ├─ userId                    │
│  ├─ text                       ├─ videoId                   │
│  ├─ likes                      └─ createdAt                 │
│  └─ createdAt                                               │
│                                Follow                       │
│                                ├─ id                        │
│                                ├─ followerId                │
│                                ├─ followingId               │
│                                └─ createdAt                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Database Schema (Supabase)

```
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Tables                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  users                        videos                        │
│  ├─ id (UUID, PK)             ├─ id (UUID, PK)             │
│  ├─ username (TEXT)           ├─ user_id (UUID, FK)        │
│  ├─ email (TEXT)              ├─ username (TEXT)           │
│  ├─ avatar_url (TEXT)         ├─ caption (TEXT)            │
│  ├─ bio (TEXT)                ├─ video_url (TEXT)          │
│  ├─ followers_count (INT)     ├─ thumbnail_url (TEXT)      │
│  ├─ following_count (INT)     ├─ likes (INT)               │
│  ├─ likes_count (INT)         ├─ comments (INT)            │
│  └─ created_at (TIMESTAMP)    ├─ shares (INT)              │
│                               ├─ views (INT)               │
│  comments                     └─ created_at (TIMESTAMP)    │
│  ├─ id (UUID, PK)                                          │
│  ├─ video_id (UUID, FK)       likes                        │
│  ├─ user_id (UUID, FK)        ├─ id (UUID, PK)            │
│  ├─ username (TEXT)           ├─ user_id (UUID, FK)        │
│  ├─ text (TEXT)               ├─ video_id (UUID, FK)       │
│  ├─ likes (INT)               └─ created_at (TIMESTAMP)    │
│  └─ created_at (TIMESTAMP)                                 │
│                               follows                       │
│                               ├─ id (UUID, PK)             │
│                               ├─ follower_id (UUID, FK)    │
│                               ├─ following_id (UUID, FK)   │
│                               └─ created_at (TIMESTAMP)    │
└─────────────────────────────────────────────────────────────┘
```

---

## API Flow Examples

### 1. User Sign Up Flow

```
User Input (AuthView)
       ↓
SupabaseService.signUp(email, password, username)
       ↓
Supabase Auth API (create auth user)
       ↓
Supabase Database (insert user profile)
       ↓
Update @Published properties
       ↓
App switches to ContentView
```

### 2. Feed Loading Flow

```
FeedView appears
       ↓
FeedView.task { loadVideos() }
       ↓
SupabaseService.fetchFeed(limit: 20)
       ↓
Supabase Database Query
       ↓
SELECT * FROM videos ORDER BY created_at DESC LIMIT 20
       ↓
Return [VideoPost] array
       ↓
Update @State videos
       ↓
SwiftUI rerenders view
```

### 3. Like Video Flow

```
User taps heart button
       ↓
VideoPlayerView.toggleLike()
       ↓
SupabaseService.likeVideo(videoId)
       ↓
INSERT INTO likes (user_id, video_id)
       ↓
Call RPC function increment_likes(videoId)
       ↓
UPDATE videos SET likes = likes + 1
       ↓
Update local state
       ↓
Heart turns red + count updates
```

### 4. Video Upload Flow (To Implement)

```
User selects video
       ↓
UploadView gets video data
       ↓
SupabaseService.uploadVideo(caption, videoData)
       ↓
Upload file to Supabase Storage
       ↓
Get public URL of uploaded video
       ↓
INSERT video record into database
       ↓
Return VideoPost
       ↓
Navigate to Feed
```

---

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Row Level Security (RLS)                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Users Table                                                │
│  ├─ Read: Everyone (public profiles)                        │
│  └─ Update: Own profile only (auth.uid() = id)             │
│                                                             │
│  Videos Table                                               │
│  ├─ Read: Everyone                                          │
│  ├─ Insert: Own videos only (auth.uid() = user_id)         │
│  ├─ Update: Own videos only                                │
│  └─ Delete: Own videos only                                │
│                                                             │
│  Comments Table                                             │
│  ├─ Read: Everyone                                          │
│  ├─ Insert: Authenticated users only                        │
│  └─ Delete: Own comments only                              │
│                                                             │
│  Likes Table                                                │
│  ├─ Read: Everyone                                          │
│  ├─ Insert: Authenticated users only                        │
│  └─ Delete: Own likes only                                 │
│                                                             │
│  Follows Table                                              │
│  ├─ Read: Everyone                                          │
│  ├─ Insert: Authenticated (as follower)                     │
│  └─ Delete: Own follows only                               │
│                                                             │
│  Storage Policies                                           │
│  ├─ Videos: Upload to own folder only                       │
│  ├─ Avatars: Upload to own folder only                      │
│  └─ Public read access for all files                        │
└─────────────────────────────────────────────────────────────┘
```

---

## State Management

```
┌─────────────────────────────────────────────────────────────┐
│                   App State Flow                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  vibexApp (Root)                                            │
│  └─ @StateObject SupabaseService                            │
│                                                             │
│  SupabaseService (@MainActor ObservableObject)              │
│  ├─ @Published currentUser: User?                           │
│  └─ @Published isAuthenticated: Bool                        │
│                                                             │
│  Views receive via:                                         │
│  ├─ .environmentObject(supabaseService)                     │
│  └─ @EnvironmentObject var service: SupabaseService         │
│                                                             │
│  Local View State:                                          │
│  ├─ FeedView: @State videos: [VideoPost]                    │
│  ├─ DiscoverView: @State discoverVideos: [VideoPost]        │
│  ├─ ProfileView: @State userVideos: [VideoPost]             │
│  └─ VideoPlayerView: @State isLiked: Bool                   │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
vibex/
├── App
│   ├── vibexApp.swift              # App entry point
│   └── ContentView.swift           # Main tab container
│
├── Views
│   ├── AuthView.swift              # Sign up / Sign in
│   ├── FeedView.swift              # Video feed (in ContentView.swift)
│   ├── VideoPlayerView.swift       # Video player (in ContentView.swift)
│   ├── UploadView.swift            # Upload UI (in ContentView.swift)
│   ├── DiscoverView.swift          # Discover grid (in ContentView.swift)
│   └── ProfileView.swift           # User profile (in ContentView.swift)
│
├── Services
│   ├── SupabaseConfig.swift        # Supabase client config
│   └── SupabaseService.swift       # API service layer
│
├── Models
│   └── Models.swift                # Data models
│
├── Database
│   ├── schema.sql                  # Database schema
│   └── sample_data.sql             # Test data
│
└── Documentation
    ├── README.md                   # Project overview
    ├── SETUP_GUIDE.md              # Setup instructions
    ├── QUICK_START.md              # Quick start guide
    └── ARCHITECTURE.md             # This file
```

---

## Technology Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (iOS App)                       │
├─────────────────────────────────────────────────────────────┤
│  Language:        Swift 5.9+                                │
│  UI Framework:    SwiftUI                                   │
│  Minimum iOS:     iOS 17.0                                  │
│  Concurrency:     Swift Concurrency (async/await)           │
│  Video:           AVKit (to be implemented)                 │
│  Photos:          PhotosUI (to be implemented)              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                 Backend (Supabase Services)                 │
├─────────────────────────────────────────────────────────────┤
│  Authentication:  Supabase Auth                             │
│  Database:        PostgreSQL (Supabase hosted)              │
│  Storage:         Supabase Storage (S3-compatible)          │
│  SDK:             supabase-swift 2.0+                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      Dependencies                           │
├─────────────────────────────────────────────────────────────┤
│  supabase-swift   → Authentication, Database, Storage       │
│  ├─ Auth          → User authentication                     │
│  ├─ PostgREST     → Database queries                        │
│  ├─ Realtime      → Real-time subscriptions                 │
│  └─ Storage       → File uploads/downloads                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Design Patterns

### 1. Service Layer Pattern
- `SupabaseService` acts as intermediary between views and backend
- All API calls go through this single service
- Views don't directly interact with Supabase client

### 2. Observable Object Pattern
- `SupabaseService` is `@MainActor` and `ObservableObject`
- Views observe changes via `@Published` properties
- Automatic UI updates when data changes

### 3. Environment Object Pattern
- Service injected at root level
- All child views access via `@EnvironmentObject`
- Single source of truth for app state

### 4. Async/Await Pattern
- All network calls use Swift Concurrency
- Clean, readable asynchronous code
- Proper error handling with try/catch

### 5. Composition Pattern
- Views broken into small, reusable components
- `ActionButton`, `StatView`, etc.
- Easy to maintain and test

---

## Performance Considerations

### Current
- Basic data fetching
- No caching
- No pagination
- No lazy loading

### Recommended Improvements
1. **Implement pagination** for feed loading
2. **Cache user data** to reduce API calls
3. **Preload next video** in feed for smooth scrolling
4. **Lazy load images** with SDWebImage or similar
5. **Optimize video streaming** with HLS
6. **Add background refresh** for new content

---

## Scalability Notes

### Current Capacity
- Suitable for: Small to medium apps
- Users: Up to ~10,000 concurrent
- Videos: Limited by Supabase storage tier

### To Scale Beyond
1. Implement CDN for video delivery
2. Add video transcoding service
3. Implement caching layer (Redis)
4. Use database read replicas
5. Optimize queries with proper indexes
6. Implement rate limiting

---

Built with ❤️ using SwiftUI + Supabase
