import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

serve(async (req) => {
  const auth = req.headers.get("authorization") || req.headers.get("Authorization");
  const apiKeyHeader = req.headers.get("apikey");
  if (!auth && !apiKeyHeader) {
    return new Response(JSON.stringify({ code: 401, message: "Missing authorization header" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const text = String(body.text ?? "vibe video");
    const count = Number(body.count ?? 4) || 4;

    const titles = Array.from({ length: count }).map((_, i) => `${text} — Title Idea ${i + 1}`);
    return new Response(JSON.stringify({ titles }), { headers: { "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
