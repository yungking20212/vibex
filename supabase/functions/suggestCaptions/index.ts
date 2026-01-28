import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

serve(async (req) => {
  // Allow requests authenticated either by Authorization header (Bearer) or by apikey header (for testing).
  const auth = req.headers.get("authorization") || req.headers.get("Authorization");
  const apiKeyHeader = req.headers.get("apikey");
  if (!auth && !apiKeyHeader) {
    return new Response(JSON.stringify({ code: 401, message: "Missing authorization header" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const prompt = body.prompt ?? "vibe video";
    const count = Number(body.count ?? 3) || 3;

    const captions = Array.from({ length: count }).map((_, i) => `Caption ${i + 1}: ${prompt}`);
    return new Response(JSON.stringify({ captions }), { headers: { "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
