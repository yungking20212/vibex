import { createClient } from "npm:@supabase/supabase-js@2.33.0";
console.info('vibex-stream function starting');
Deno.serve(async (req)=>{
  try {
    const url = new URL(req.url);
    const params = url.searchParams;
    const model = params.get('model') || 'gpt-4';
    const body = await req.json().catch(()=>({}));
    const messages = body.messages || [
      {
        role: 'user',
        content: body.prompt || 'Hello'
      }
    ];
    const persist = body.persist === true;
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const openaiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openaiKey) return new Response(JSON.stringify({
      error: 'OPENAI_API_KEY not set'
    }), {
      status: 500
    });
    if (persist && (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY)) {
      return new Response(JSON.stringify({
        error: 'Supabase secrets SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY required for persistence'
      }), {
        status: 500
      });
    }
    const encoder = new TextEncoder();
    // Optionally persist conversation start
    let convId = body.conversation_id || null;
    if (persist && !convId) {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      const { data, error } = await supabase.from('vibex_conversations').insert({
        meta: body.meta || {}
      }).select('id').limit(1).single();
      if (error) console.error('insert conv error', error);
      convId = data?.id || null;
    }
    // Call OpenAI via fetch streaming
    const openaiRes = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model,
        messages,
        stream: true
      })
    });
    if (!openaiRes.ok) {
      const text = await openaiRes.text();
      console.error('openai error', text);
      return new Response(JSON.stringify({
        error: text
      }), {
        status: openaiRes.status,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    const reader = openaiRes.body.getReader();
    const stream = new ReadableStream({
      async start (controller) {
        let buffer = '';
        let role = 'assistant';
        try {
          while(true){
            const { done, value } = await reader.read();
            if (done) break;
            const chunk = new TextDecoder().decode(value);
            buffer += chunk;
            // OpenAI streams with lines prefixed by 'data: '
            const parts = buffer.split(/\n\n/);
            buffer = parts.pop() || '';
            for (const part of parts){
              if (!part.startsWith('data:')) continue;
              const payload = part.replace(/^data:\s*/, '');
              if (payload === '[DONE]') continue;
              try {
                const parsed = JSON.parse(payload);
                // navigate to content delta
                const delta = parsed.choices?.[0]?.delta || {};
                const token = delta.content || delta.role || '';
                if (delta.role) role = delta.role;
                if (token) {
                  const out = {
                    role,
                    content: token
                  };
                  controller.enqueue(encoder.encode(`data: ${JSON.stringify(out)}\n\n`));
                  // persist token chunk if requested
                  if (persist && convId) {
                    try {
                      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
                      await supabase.from('vibex_messages').insert({
                        conversation_id: convId,
                        role: role,
                        content: token
                      });
                    } catch (e) {
                      console.error('persist chunk error', e);
                    }
                  }
                }
              } catch (e) {
                console.error('parse chunk error', e);
              }
            }
          }
        } catch (err) {
          controller.enqueue(encoder.encode(`event: error\ndata: ${JSON.stringify({
            error: String(err)
          })}\n\n`));
        } finally{
          controller.close();
        }
      }
    });
    return new Response(stream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        'Connection': 'keep-alive'
      }
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({
      error: String(err)
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
});
