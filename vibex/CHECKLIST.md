# ✅ VibeX Setup Checklist

Use this checklist to set up your VibeX app step by step!

---

## 📦 Step 1: Install Dependencies

- [ ] Open Xcode
- [ ] Go to **File → Add Package Dependencies**
- [ ] Paste URL: `https://github.com/supabase-community/supabase-swift`
- [ ] Select version: **2.0.0** or higher
- [ ] Click **Add Package**
- [ ] Wait for package to resolve and download
- [ ] Verify packages appear in Project Navigator

**Expected packages:**
- ✓ supabase-swift
- ✓ Auth
- ✓ PostgREST
- ✓ Realtime
- ✓ Storage
- ✓ Functions

---

## 🗄️ Step 2: Set Up Database

### 2.1 Create Tables & Functions

- [ ] Open Supabase dashboard
- [ ] URL: https://jnkzbfqrwkgfiyxvwrug.supabase.co
- [ ] Click **SQL Editor** in sidebar
- [ ] Click **New Query**
- [ ] Copy entire `schema.sql` file
- [ ] Paste into SQL editor
- [ ] Click **Run** (or Cmd+Enter)
- [ ] Verify success message

### 2.2 Verify Tables Created

- [ ] Go to **Table Editor**
- [ ] Confirm 5 tables exist:
  - [ ] users
  - [ ] videos
  - [ ] comments
  - [ ] likes
  - [ ] follows

### 2.3 Verify Storage Buckets

- [ ] Go to **Storage** in sidebar
- [ ] Confirm 2 buckets exist:
  - [ ] videos (public)
  - [ ] avatars (public)

---

## 🎬 Step 3: Add Sample Data (Optional but Recommended)

- [ ] Go back to **SQL Editor**
- [ ] Click **New Query**
- [ ] Copy entire `sample_data.sql` file
- [ ] Paste into SQL editor
- [ ] Click **Run**
- [ ] Verify success message showing counts:
  - [ ] 5 users inserted
  - [ ] 10 videos inserted
  - [ ] 5 comments inserted
  - [ ] 5 likes inserted
  - [ ] 9 follows inserted

---

## 🔐 Step 4: Configure Authentication

- [ ] Go to **Authentication → Providers**
- [ ] Verify **Email** provider is enabled
- [ ] (Optional) Enable other providers:
  - [ ] Google
  - [ ] Apple
  - [ ] GitHub

### For Testing (Optional)

- [ ] Go to **Authentication → Settings**
- [ ] Scroll to **Email Confirm**
- [ ] Toggle OFF to skip email verification during testing
- [ ] **Remember to re-enable for production!**

---

## 🏗️ Step 5: Build the Project

- [ ] In Xcode, select target (iPhone or Simulator)
- [ ] Press **Cmd+B** to build
- [ ] Wait for build to complete
- [ ] Fix any build errors (see troubleshooting below)

### Common Build Errors

**"No such module 'Supabase'"**
- [ ] File → Packages → Reset Package Caches
- [ ] Clean build folder: Shift+Cmd+K
- [ ] Rebuild

**"Cannot find type in scope"**
- [ ] Check all files are included in target
- [ ] Verify file names match imports
- [ ] Clean and rebuild

---

## ▶️ Step 6: Run the App

- [ ] Press **Cmd+R** (or click Play button)
- [ ] Wait for app to launch
- [ ] App should open to AuthView (sign up/in screen)

---

## 🧪 Step 7: Test Authentication

### Create Account

- [ ] Click **Sign Up** tab
- [ ] Enter username: `testuser`
- [ ] Enter email: `test@vibes.com`
- [ ] Enter password: `password123`
- [ ] Click **Create Account**
- [ ] Should navigate to main feed

### Test Sign Out

- [ ] Navigate to **Profile** tab
- [ ] Click sign out icon (top right)
- [ ] Should return to AuthView

### Test Sign In

- [ ] Click **Sign In** tab
- [ ] Enter email: `test@vibes.com`
- [ ] Enter password: `password123`
- [ ] Click **Sign In**
- [ ] Should navigate to main feed

---

## 📱 Step 8: Test Each Feature

### Feed Tab

- [ ] Navigate to **Feed** tab
- [ ] If sample data loaded, should see videos
- [ ] If no sample data, should see "No videos yet"
- [ ] Try swiping up/down (should change videos if multiple exist)

### Upload Tab

- [ ] Navigate to **Upload** tab
- [ ] Should see "Upload Your Vibe" screen
- [ ] Button shows but doesn't work yet (needs implementation)

### Discover Tab

- [ ] Navigate to **Discover** tab
- [ ] Should see grid of videos
- [ ] If sample data loaded, should show thumbnails
- [ ] If no data, shows "No videos to discover yet"

### Profile Tab

- [ ] Navigate to **Profile** tab
- [ ] Should show your username
- [ ] Stats should display (0 initially for new users)
- [ ] If sample data & signed in as sample user, shows their videos
- [ ] Click sign out button to test logout

---

## 🎨 Step 9: Test Interactions

### Test Like Function

- [ ] Go to Feed tab
- [ ] Tap heart icon on a video
- [ ] Heart should turn red
- [ ] Like count should increase
- [ ] Tap again to unlike
- [ ] Heart turns white, count decreases

### Test Pull to Refresh

- [ ] In Feed, pull down from top
- [ ] Should show loading spinner
- [ ] Videos refresh

---

## 🔍 Step 10: Verify in Supabase Dashboard

### Check Authentication

- [ ] Go to **Authentication → Users**
- [ ] Should see your test account listed
- [ ] Verify email address is correct

### Check Database Records

- [ ] Go to **Table Editor → users**
- [ ] Find your user record
- [ ] Verify data is correct

### Check Logs

- [ ] Go to **Logs → Postgres Logs**
- [ ] Should see queries when you interact with app
- [ ] Go to **Logs → API Logs**
- [ ] Should see authentication and data requests

---

## 🐛 Troubleshooting

### App Issues

**App crashes on launch**
- [ ] Check Console for errors
- [ ] Verify Supabase credentials in `SupabaseConfig.swift`
- [ ] Ensure database schema was created successfully

**"Failed to authenticate"**
- [ ] Check Supabase project is active
- [ ] Verify email provider is enabled
- [ ] Check internet connection
- [ ] Look at error in Console logs

**Empty feed/discover**
- [ ] This is normal if no videos uploaded
- [ ] Run `sample_data.sql` to add test videos
- [ ] Or implement upload feature and add videos

**Like button doesn't work**
- [ ] Check Console for error messages
- [ ] Verify RLS policies are set (run schema.sql again)
- [ ] Make sure you're signed in

### Supabase Issues

**Can't access dashboard**
- [ ] Verify URL: https://jnkzbfqrwkgfiyxvwrug.supabase.co
- [ ] Check if logged in to Supabase
- [ ] Try refreshing the page

**Tables don't exist**
- [ ] Re-run `schema.sql`
- [ ] Check for SQL errors in editor
- [ ] Verify you're in correct project

**Storage buckets missing**
- [ ] Run storage portion of `schema.sql` again
- [ ] Or manually create in Storage section
- [ ] Make sure they're set to public

---

## 🎯 Next Steps

After completing setup:

### Immediate (High Priority)

- [ ] Implement AVPlayer for real video playback
- [ ] Add PhotosPicker for video selection
- [ ] Implement video upload functionality
- [ ] Test upload with real video file

### Soon

- [ ] Create comments bottom sheet
- [ ] Add user profile view (other users)
- [ ] Implement search functionality
- [ ] Add follow/unfollow buttons
- [ ] Create notifications

### Later

- [ ] Add video effects/filters
- [ ] Implement camera recording
- [ ] Add sound library
- [ ] Create direct messaging
- [ ] Add analytics tracking

---

## 📚 Documentation Reference

During setup, refer to:

- [ ] **README.md** - Project overview
- [ ] **SETUP_GUIDE.md** - Detailed setup instructions
- [ ] **QUICK_START.md** - Quick reference guide
- [ ] **ARCHITECTURE.md** - System architecture diagrams
- [ ] **schema.sql** - Database structure
- [ ] **sample_data.sql** - Test data

---

## 🎉 Success Criteria

Your setup is complete when:

- [x] App builds without errors
- [x] Can create new account
- [x] Can sign in/out
- [x] Feed displays (empty or with sample data)
- [x] All 4 tabs are accessible
- [x] Profile shows user info
- [x] Can like/unlike videos
- [x] Database records appear in Supabase dashboard
- [x] Authentication works consistently

---

## 📞 Getting Help

If stuck:

1. **Check Console Logs**
   - Look for red error messages
   - Check Supabase connection status

2. **Check Supabase Dashboard Logs**
   - Authentication logs
   - API logs
   - Postgres logs

3. **Verify Configuration**
   - Double-check `SupabaseConfig.swift`
   - Verify URL and key are correct

4. **Start Fresh**
   - Clean build folder (Shift+Cmd+K)
   - Delete app from simulator
   - Rebuild and reinstall

5. **Documentation**
   - Read error messages carefully
   - Check Supabase docs: https://supabase.com/docs
   - Review Swift docs: https://developer.apple.com

---

## 🎊 All Done!

Once all checkboxes are complete, you have a fully functional VibeX app with:

✅ Working authentication
✅ Real-time database
✅ User profiles
✅ Video feed (UI ready)
✅ Social features (likes, comments, follows)
✅ Cloud storage ready

**You're ready to build something amazing!** 🚀

---

**Date Completed**: ________________

**Notes**: 
_________________________________________________
_________________________________________________
_________________________________________________

Built with ❤️ using SwiftUI + Supabase
