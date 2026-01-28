import { VercelRequest, VercelResponse } from '@vercel/node'

// Simple beta signup endpoint that inserts into Supabase via REST API.
// Requires environment variables:
// SUPABASE_URL (e.g. https://xyzcompany.supabase.co)
// SUPABASE_SERVICE_ROLE_KEY (service_role key)

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed')
    return
  }

  const { email, name } = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {}
  if (!email || typeof email !== 'string') {
    res.status(400).send('Missing email')
    return
  }

  const supabaseUrl = process.env.SUPABASE_URL
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!supabaseUrl || !serviceKey) {
    res.status(500).send('Supabase env vars not configured')
    return
  }

  // basic email validation
  const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/
  if (!emailRegex.test(email)) {
    res.status(400).send('Invalid email')
    return
  }

  try {
    const payload = { email: email.toLowerCase(), name: name || null, created_at: new Date().toISOString() }
    const r = await fetch(`${supabaseUrl}/rest/v1/beta_signups`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
        'Prefer': 'return=representation'
      },
      body: JSON.stringify(payload)
    })

    const text = await r.text()
    if (!r.ok) {
      res.status(r.status).send(text)
      return
    }

    res.status(200).send('ok')
  } catch (err:any) {
    console.error('beta_signup error', err)
    res.status(500).send(err.message || 'internal error')
  }
}
