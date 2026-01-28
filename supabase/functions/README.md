Supabase Edge Functions for vibex

These are minimal Deno-based Edge Functions used for local testing of the AI flows.
NOTE: The project now uses client-side Storage uploads and ordinary REST calls where possible.
Edge Functions that performed storage presigning/uploading have been deprecated and are kept for
reference only; you do not need to deploy them.

Files:
- `suggestCaptions` — returns a JSON { captions: [..] }
- `hashtags` — returns { hashtags: [..] }
- `titleIdeas` — returns { titles: [..] }
- `sixd` — accepts 6D effect requests and returns a jobId/status (queued or completed)
  - Status check: GET /sixd/status/:jobId — demo endpoint. Add `?ready=1` to simulate the job completing and returning a `resultURL`.

Deploy (Supabase CLI required):

```bash
supabase login
supabase link --project-ref jnkzbfqrwkgfiyxvwrug
supabase functions deploy suggestCaptions
supabase functions deploy hashtags
supabase functions deploy titleIdeas
supabase functions deploy sixd
```

Notes:
- If the CLI warns `Docker is not running`, install and start Docker Desktop before deploying functions.
- After deploy, the function URLs will be either:
  - https://<project>.functions.supabase.co/<function>
  - or POST to https://<project>.supabase.co/functions/v1/<function> with `apikey` header

Testing the demo `sixd` flow (example):

```bash
# enqueue a fake job
curl -X POST "https://<project>.functions.supabase.co/sixd" -H "Content-Type: application/json" -H "apikey: <your_api_key>" -d '{"preset":"funny"}'
# poll status (will show queued unless you pass ready=1)
curl "https://<project>.functions.supabase.co/sixd/status/<jobId>?ready=1" -H "apikey: <your_api_key>"
```
