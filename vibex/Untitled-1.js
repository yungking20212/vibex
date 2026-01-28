// supabase/functions/6d/index.ts
import { serve } from "std/server";

serve(async (req) => {
  if (req.method !== "POST") return new Response(null, { status: 405 });

  try {
    const body = await req.json().catch(() => ({}));
    const preset = body.preset ?? "default";
    const options = body.options ?? {};
    // create job in your backend or AI service here.
    // For demo return a fake job id + queued response:
    const jobId = `6d-${crypto.randomUUID()}`;
    const result = {
      jobId,
      status: "queued",
      estimatedSeconds: 30,
      preset,
      options
    };
    return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" }});
  } catch (err) {
    return new Response(JSON.stringify({ error: "server_error", message: String(err) }), { status: 500, headers: { "Content-Type": "application/json" }});
  }
});

print(CacheCleaner.currentCachesSize())
print(CacheCleaner.largestCacheFiles(limit: 20))