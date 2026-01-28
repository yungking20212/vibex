Vercel setup for VibeX

Overview
- This project contains an iOS app in `vibex/` and several server helpers (Edge/Functions) in `edge_functions/` and `functions/`.
- Use Vercel for hosting Edge Functions / minimal server endpoints (e.g. presign_upload) and static web frontends if present.

Prerequisites
- Node.js (>=18)
- Vercel CLI (`npm i -g vercel` or `brew install vercel`)
- A Vercel account

Quick Start (CLI)
1. Install Vercel CLI and login

```bash
# global install
npm install -g vercel
# or (macOS)
brew tap vercel/tap && brew install vercel

# login
vercel login
```

2. From project root, link to a Vercel project (or create one)

```bash
cd /path/to/vibex
vercel link
# choose an existing project or create new
```

3. Set environment variables in Vercel (recommended: use the dashboard or CLI)

Required env vars (example names used by app):
- `SUPABASE_URL` — e.g. https://your-project.supabase.co
- `SUPABASE_ANON_KEY` — anon/public key (for client-side usage)
- `SUPABASE_SERVICE_ROLE_KEY` — service role key (if server functions need elevated access)

Use the CLI to set them for a given environment (production/staging):

```bash
vercel env add SUPABASE_URL production
vercel env add SUPABASE_ANON_KEY production
vercel env add SUPABASE_SERVICE_ROLE_KEY production
```

4. Deploy

If you have serverless functions under an `api/` folder, Vercel will auto-detect them. For this repo you can:
- Move or copy specific server endpoints you want hosted into an `api/` directory at repo root (e.g. `api/presign_upload.ts`).
- Then run:

```bash
vercel --prod
```

Notes & Tips
- Vercel Edge Runtime has special APIs. If your `edge_functions/` use Deno-specific APIs, port to the Vercel Edge Runtime or host them as Node serverless functions.
- Keep secrets out of source; use `vercel env` or the dashboard.
- You can create environment-specific builds and preview deployments via `vercel --prebuilt` and `vercel --prod`.

Files added to repo:
- `.vercelignore` — patterns to skip (iOS build artifacts)
- `.env.example` — example env var names
- `vercel-setup.md` — this guide

If you want, I can:
- Add a sample `api/presign_upload.ts` wrapper that forwards to `edge_functions/presign_upload/index.ts` logic (requires adapting Deno code to Vercel runtime).
- Run `vercel link` interactively if you want me to attempt linking here.
