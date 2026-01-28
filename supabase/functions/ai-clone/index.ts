import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

console.log('Deploying ai-clone with caller auth')

Deno.serve(async (req: Request) => {
  try {
    if (req.method === 'OPTIONS') return new Response(null, { status: 204 });

    const authHeader = req.headers.get('authorization') || '';
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    if (!supabaseUrl) return new Response(JSON.stringify({ error: 'SUPABASE_URL not set' }), { status: 500 });

    // Create per-request client using caller auth to respect RLS
    const client = createClient(supabaseUrl, '', { global: { headers: { authorization: authHeader } } });

    const body = await req.json();
    const { table, id, columns, clones = 3, output_type = 'script', save_to_feed = false } = body;
    if (!table || !id) return new Response(JSON.stringify({ error: 'Missing table or id' }), { status: 400 });
    if (![2,3,4,5].includes(clones)) return new Response(JSON.stringify({ error: 'clones must be 2,3,4,or 5' }), { status: 400 });

    const selectCols = Array.isArray(columns) && columns.length ? columns.join(',') : '*';
    const { data: row, error: fetchErr } = await client.from(table).select(selectCols).eq('id', id).limit(1).single();
    if (fetchErr) return new Response(JSON.stringify({ error: fetchErr.message }), { status: 400 });
    if (!row) return new Response(JSON.stringify({ error: 'Row not found' }), { status: 404 });

    const rowText = JSON.stringify(row);
    const promptBase = `Given the following user profile JSON, generate ${clones} distinct creative "clones" (short persona variants) and for each produce a ${output_type} suitable for a short social media movie. For each clone return: name (one short alias), 3-4 bullet point persona traits, and a ${output_type} (~120-220 words). Use plain English.`;
    const fullPrompt = `${promptBase}\n\nUser profile:\n${rowText}`;

    // Helper to call AI: prefer Supabase.ai if available on globalThis, else fallback to OpenAI
    async function callAI(prompt: string) {
      if ((globalThis as any).Supabase?.ai) {
        const session = new (globalThis as any).Supabase.ai.Session('gpt-4o-mini');
        const result = await session.run({ messages: [{ role: 'user', content: prompt }] }, { stream: false, timeout: 60 });
        return result?.output ?? result;
      }
      const apiKey = Deno.env.get('OPENAI_API_KEY');
      if (!apiKey) throw new Error('No AI provider configured');
      const res = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({ model: 'gpt-3.5-turbo', messages: [{ role: 'user', content: prompt }], max_tokens: 700 }),
      });
      if (!res.ok) throw new Error(`AI provider error: ${res.status}`);
      const j = await res.json();
      return j.choices?.[0]?.message?.content ?? JSON.stringify(j);
    }

    const aiOutput = await callAI(fullPrompt);

    // Parse AI output conservatively: store raw output and also split into items by numbered list or separators
    const raw = typeof aiOutput === 'string' ? aiOutput : JSON.stringify(aiOutput);
    const items = raw.split(/\n\n(?=\d+\.|-\s)/).slice(0, clones).map((s, i) => ({ index: i+1, text: s.trim() }));

    let insertResults = null;
    if (save_to_feed) {
      // Insert into posts table as calling user. Expect RLS to map user from auth. Use client created with caller auth.
      const now = new Date().toISOString();
      const toInsert = items.map(it => ({ content: it.text, metadata: { source_table: table, source_id: id, clone_index: it.index, output_type }, created_at: now }));
      const { data: insData, error: insErr } = await client.from('posts').insert(toInsert).select();
      insertResults = { data: insData, error: insErr ? insErr.message : null };
    }

    return new Response(JSON.stringify({ row, raw_ai: raw, items, insertResults }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
