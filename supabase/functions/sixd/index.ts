import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

serve(async (req) => {
  // Allow POST to enqueue a job and GET to check status.
  const auth = req.headers.get("authorization") || req.headers.get("Authorization");
  const apiKeyHeader = req.headers.get("apikey");
  if (!auth && !apiKeyHeader) {
    return new Response(JSON.stringify({ code: 401, message: "Missing authorization header" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  try {
    const url = new URL(req.url);
    // Status check: GET /sixd/status/:jobId
    if (req.method === "GET") {
      const path = url.pathname;
      // Accept status checks whether path is /sixd/status/<jobId> or contains that suffix
      const normalized = path.replace(/\/+/g, '/');
      const match = normalized.match(/\/sixd\/status\/([^\/\?]+)/);
      if (match) {
        const jobId = match[1];
        const ready = url.searchParams.get('ready');
        if (ready === '1') {
          const resultURL = `https://storage.supabase.co/outputs/${jobId}.mp4`;
          return new Response(JSON.stringify({ jobId, status: 'completed', resultURL }), { headers: { 'Content-Type': 'application/json' } });
        }
        return new Response(JSON.stringify({ jobId, status: 'queued', estimatedSeconds: 12 }), { headers: { 'Content-Type': 'application/json' } });
      }
      return new Response(JSON.stringify({ error: 'not_found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
    }

    if (req.method === 'POST') {
      const body = await req.json().catch(() => ({}));
      const preset = String(body.preset ?? "default");
      const options = body.options ?? {};

      // Simulate creating a job and returning a queued response
      const jobId = `sixd-${crypto.randomUUID()}`;
      const result = {
        jobId,
        status: "queued",
        estimatedSeconds: 20,
        preset,
        options,
      };

      return new Response(JSON.stringify(result), {
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(null, { status: 405 });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
