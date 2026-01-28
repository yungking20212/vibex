import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    // Require that the function has the OpenRouter API key configured in env
    const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY");
    if (!OPENROUTER_API_KEY) {
      return new Response(JSON.stringify({ error: "OpenRouter API key not configured" }), { status: 500 });
    }

    // Forward request body to OpenRouter with streaming enabled
    const body = await req.text();

    const upstream = await fetch("https://api.openrouter.ai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "Accept": "text/event-stream"
      },
      body,
    });

    // Proxy status and headers
    const headers = new Headers();
    // Preserve content-type if present, but default to event-stream for streaming
    const ct = upstream.headers.get("content-type") || "text/event-stream; charset=utf-8";
    headers.set("content-type", ct);

    // Stream the upstream body to the caller
    if (!upstream.body) {
      const text = await upstream.text();
      return new Response(text, { status: upstream.status, headers });
    }

    return new Response(upstream.body, { status: upstream.status, headers });

  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
