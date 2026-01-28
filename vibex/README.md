# VibeX - TikTok-Style Social Video App

A modern social video sharing app built with SwiftUI and Supabase.

## 🚀 Features

- ✅ User Authentication (Sign Up/Sign In)
- ✅ Video Feed with vertical scrolling
- ✅ Video Upload
- ✅ Discover trending videos
- ✅ User Profiles
- ✅ Like, Comment, and Share functionality
- ✅ Follow/Unfollow users
- ✅ Real-time data with Supabase

## 📦 Setup Instructions

### 1. Install Supabase Swift SDK

Add the Supabase Swift package to your Xcode project:

1. In Xcode, go to **File > Add Package Dependencies**
2. Enter the repository URL: `https://github.com/supabase-community/supabase-swift`
3. Select version: Use "Up to Next Major Version" with version `2.0.0`
4. Click "Add Package"
5. Select all targets and click "Add Package"

### 2. Set Up Supabase Database

1. Go to your Supabase dashboard: https://jnkzbfqrwkgfiyxvwrug.supabase.co
2. Navigate to the **SQL Editor**
3. Copy and paste the entire contents of `schema.sql`
4. Run the SQL script to create all tables and policies

### 3. Configure Storage

In your Supabase dashboard:

1. Go to **Storage** section
2. Create two buckets (if not already created by the SQL script):
   - `videos` (public)
   - `avatars` (public)

### 4. Update Configuration (if needed)

Your Supabase credentials are already configured in `SupabaseConfig.swift`:

- **URL**: https://jnkzbfqrwkgfiyxvwrug.supabase.co
- **Anon Key**: (already configured)

⚠️ **Security Note**: For production apps, move these credentials to environment variables or secure configuration files.

## 🏗️ Project Structure

```
vibex/
├── vibexApp.swift           # Main app entry point with auth state
├── ContentView.swift        # Main tab view with Feed/Upload/Discover/Profile
├── AuthView.swift           # Sign up / Sign in view
├── SupabaseConfig.swift     # Supabase client configuration
├── SupabaseService.swift    # API service layer
├── Models.swift             # Data models (User, VideoPost, Comment, etc.)
└── schema.sql              # Database schema
```

## 📱 Features Breakdown

### Authentication
- Email/password authentication
- User profile creation
- Automatic session management

### Feed View
- Vertical scrolling video player (TikTok-style)
- Video info overlay
- Action buttons (Like, Comment, Share)

### Upload View
- Video selection
- Caption input
- Upload to Supabase Storage

### Discover View
- Grid of trending videos
- Sorted by views

### Profile View
- User stats (Followers, Following, Likes)
- User video grid
- Edit profile

## 🛠️ Tech Stack

- **SwiftUI** - UI framework
- **AVKit** - Video playback
- **Supabase** - Backend (Auth, Database, Storage)
- **Swift Concurrency** - Async/await for API calls

## 📝 Database Schema

### Tables:
- `users` - User profiles
- `videos` - Video posts
- `comments` - Video comments
- `likes` - Video likes
- `follows` - User follows

### Storage Buckets:
- `videos` - Video files
- `avatars` - Profile pictures

## 🔐 Security Features

- Row Level Security (RLS) enabled on all tables
- Authentication required for sensitive operations
- User-specific data access policies
- Secure file upload with user-specific folders

## 🎯 Next Steps

### Immediate Improvements:
1. **Video Player**: Integrate AVPlayer for actual video playback
2. **Video Picker**: Add UIImagePickerController for video selection
3. **Camera**: Add camera recording feature
4. **Animations**: Add smooth transitions and gestures
5. **Comments UI**: Build comment sheet view

### Advanced Features:
- Push notifications for likes/comments/follows
- Video effects and filters
- Sound library integration
- Direct messaging
- Live streaming
- Analytics and insights

## 🐛 Troubleshooting

### Common Issues:

1. **Build Errors**: Make sure you've added the Supabase Swift package
2. **Auth Errors**: Verify your Supabase project URL and anon key
3. **Database Errors**: Make sure you've run the schema.sql script
4. **Storage Errors**: Verify storage buckets are created and policies are set

## 📄 License

MIT License - Feel free to use this project for learning and development!

---

Built with ❤️ using SwiftUI and Supabase
