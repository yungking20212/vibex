import { VercelRequest, VercelResponse } from '@vercel/node'
import { createClient } from '@supabase/supabase-js'

// Minimal serverless upload proxy for Vercel (raw bytes + x-object-path header)
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' })
    return
  }

  const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL
  const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SERVICE_ROLE
  const BUCKET = process.env.SUPABASE_UPLOAD_BUCKET || process.env.UPLOAD_BUCKET || 'videos'

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
    res.status(500).json({ error: 'server misconfigured - missing SUPABASE_URL or SUPABASE_SERVICE_ROLE' })
    return
  }

  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE)

  try {
    // Expect raw bytes with x-object-path header (our iOS client posts this way)
    const objectPath = req.headers['x-object-path'] as string | undefined
    const contentType = (req.headers['content-type'] as string) || 'application/octet-stream'

    if (!objectPath) {
      res.status(400).json({ error: 'missing x-object-path header' })
      return
    }

    // Read raw body as Buffer
    const chunks: Buffer[] = []
    for await (const chunk of req) {
      chunks.push(Buffer.from(chunk))
    }
    const body = Buffer.concat(chunks)

    const { data, error } = await serviceClient.storage.from(BUCKET).upload(objectPath, body, { upsert: false, contentType })
    if (error) {
      console.error('storage.upload error', error)
      res.status(500).json({ error: error.message })
      return
    }

    // Attempt to create a signed URL
    try {
      const { data: signedGet, error: getErr } = await serviceClient.storage.from(BUCKET).createSignedUrl(objectPath, 60 * 60)
      if (getErr) console.warn('createSignedUrl error', getErr)
      res.status(200).json({ objectPath, publicUrl: signedGet?.signedURL ?? `${BUCKET}/${objectPath}` })
      return
    } catch (e) {
      console.warn('createSignedUrl thrown', e)
      res.status(200).json({ objectPath, publicUrl: `${BUCKET}/${objectPath}` })
      return
    }
  } catch (err: any) {
    console.error('upload proxy error', err)
    res.status(500).json({ error: String(err) })
  }
}
