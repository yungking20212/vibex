# 🚀 VibeX Setup Guide

Complete step-by-step instructions to get your VibeX app running with Supabase.

## 📋 Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- A Supabase account and project

---

## Step 1: Install Supabase Swift SDK

### Option A: Swift Package Manager (Recommended)

1. Open your project in Xcode
2. Go to **File → Add Package Dependencies...**
3. In the search bar, enter: `https://github.com/supabase-community/supabase-swift`
4. Select version: **2.0.0** (or latest)
5. Click **Add Package**
6. Make sure all targets are selected (supabase-swift, Auth, Database, Storage, etc.)
7. Click **Add Package** again

### Verify Installation

In your project navigator, you should see **Package Dependencies** with:
- `supabase-swift`
- `Auth`
- `PostgREST`
- `Realtime`
- `Storage`

---

## Step 2: Set Up Supabase Database

### 2.1 Run Database Schema

1. Open your Supabase dashboard: https://jnkzbfqrwkgfiyxvwrug.supabase.co
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the entire contents of `schema.sql` from your project
5. Paste it into the SQL editor
6. Click **Run** (or press Cmd+Enter)

You should see success messages for:
- Tables created (users, videos, comments, likes, follows)
- Indexes created
- Storage buckets created
- RPC functions created
- Row Level Security policies enabled

### 2.2 Verify Tables

1. Go to **Table Editor** in the left sidebar
2. You should see 5 tables:
   - `users`
   - `videos`
   - `comments`
   - `likes`
   - `follows`

### 2.3 Verify Storage Buckets

1. Go to **Storage** in the left sidebar
2. You should see 2 buckets:
   - `videos` (public)
   - `avatars` (public)

---

## Step 3: Configure Authentication

1. Go to **Authentication → Providers** in Supabase dashboard
2. Enable **Email** provider (should be enabled by default)
3. Optional: Configure other providers (Google, Apple, etc.)

### Email Settings

1. Go to **Authentication → Email Templates**
2. Customize your signup confirmation email if needed
3. For development, you can disable email confirmation:
   - Go to **Authentication → Settings**
   - Scroll to **Email Confirm**
   - Toggle off if you want to test without email verification

---

## Step 4: Build and Run

1. In Xcode, select your target device/simulator
2. Press **Cmd+R** or click the **Play** button
3. Wait for the app to build and launch

---

## Step 5: Test the App

### Create Your First Account

1. App should open to the **AuthView**
2. Click **Sign Up** tab
3. Enter:
   - Username: `testuser`
   - Email: `test@example.com`
   - Password: `password123`
4. Click **Create Account**

If successful, you'll be taken to the main feed!

### Test Features

#### Feed Tab
- Should show empty state initially
- Pull down to refresh
- Will show videos once you or others upload some

#### Upload Tab
- Click "Choose Video" button
- Currently shows TODO - implement video picker next

#### Discover Tab
- Shows trending videos by views
- Grid layout with 3 columns

#### Profile Tab
- Shows your username, stats, and videos
- Click logout icon (top right) to sign out

---

## 🐛 Troubleshooting

### Build Errors

**Error: "No such module 'Supabase'"**
- Solution: Make sure you added the package correctly
- Try: File → Packages → Reset Package Caches
- Clean build folder: Shift+Cmd+K

**Error: "Cannot find type 'SupabaseClient'"**
- Solution: Import Supabase at the top of your file
- Add: `import Supabase`

### Runtime Errors

**Error: "Failed to connect to Supabase"**
- Verify your Supabase URL and key in `SupabaseConfig.swift`
- Check your internet connection
- Verify your Supabase project is active

**Error: "Authentication failed"**
- Check if email provider is enabled in Supabase dashboard
- Verify email format is correct
- Check console logs for detailed error messages

**Error: "Database query failed"**
- Verify schema.sql was run successfully
- Check Row Level Security policies are set up
- Look at Supabase logs in dashboard

### Empty Data

**Feed shows "No videos yet"**
- This is normal! No videos have been uploaded yet
- You'll need to implement video upload first
- Or manually insert test data in Supabase Table Editor

**Profile shows 0 followers/following**
- This is normal for new accounts
- Stats will update as users interact

---

## 🎯 Next Steps

### Implement Video Player

```swift
import AVKit

struct VideoPlayerView: View {
    let video: VideoPost
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            // ... rest of overlay
        }
        .onAppear {
            guard let url = URL(string: video.videoURL) else { return }
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
```

### Implement Video Upload

```swift
import PhotosUI

struct UploadView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoData: Data?
    
    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos
        ) {
            Text("Choose Video")
                // ... styling
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    videoData = data
                    // Upload to Supabase
                }
            }
        }
    }
}
```

### Add Comments Sheet

Create a comments bottom sheet that fetches and displays comments for each video.

### Add Search

Implement search functionality in the Discover tab to find users and videos.

### Add Direct Messages

Build a chat feature using Supabase Realtime.

---

## 📊 Monitoring

### Check Supabase Logs

1. Go to **Logs** in Supabase dashboard
2. Select **Postgres Logs** to see database queries
3. Select **API Logs** to see REST API calls
4. Use this to debug issues

### Check Storage Usage

1. Go to **Storage** in Supabase dashboard
2. Monitor file uploads and storage usage
3. Set up storage limits if needed

---

## 🔒 Security Best Practices

### For Production Apps:

1. **Move credentials to environment variables**
   ```swift
   // Don't hardcode in production!
   let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_KEY"]
   ```

2. **Use .gitignore**
   ```
   SupabaseConfig.swift
   .env
   ```

3. **Enable RLS policies** (already done in schema.sql)

4. **Set up storage size limits** in Supabase dashboard

5. **Enable rate limiting** for API calls

6. **Add input validation** on client side

---

## 📱 Testing on Device

1. Connect your iPhone/iPad
2. Select your device in Xcode
3. Build and run
4. May need to enable "Developer Mode" in Settings

---

## 🎉 You're All Set!

Your VibeX app is now connected to Supabase and ready for development!

Questions or issues? Check the Supabase docs: https://supabase.com/docs

Happy coding! 🚀
