import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    const body = await req.json();

    const {
      tool = "Chat",
      message = "",
      memory = {},
      attachments = []
    } = body;

    // 🔒 optional auth check
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401 }
      );
    }

    // 🧠 Build system context
    let systemPrompt = `You are VibeX AI.`;
    if (tool === "AI Clone") {
      systemPrompt += ` You clone the user's video style and generate new content.`;
    }

    if (memory?.savedStyle) {
      systemPrompt += ` Style: ${memory.savedStyle}.`;
    }
    if (memory?.myVoice) {
      systemPrompt += ` Voice: ${memory.myVoice}.`;
    }
    if (memory?.brandTone) {
      systemPrompt += ` Tone: ${memory.brandTone}.`;
    }

    // 🎬 Attachments context
    const attachmentContext = attachments.map((a: any) => {
      return `Attached ${a.type}: ${a.url}`;
    }).join("\n");

    // 🧪 For now, just echo structured response
    // (later you connect OpenAI / Claude / local model here)
    const reply = `
Tool: ${tool}

User message:
${message}

${attachmentContext ? "Attachments:\n" + attachmentContext : ""}

System context:
${systemPrompt}
    `.trim();

    return new Response(
      JSON.stringify({ reply }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500 }
    );
  }
});
