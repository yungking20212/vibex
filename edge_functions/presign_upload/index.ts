// Use explicit deno.land std URL so the Supabase bundler can resolve it
import { serve } from 'https://deno.land/std@0.201.0/http/server.ts'
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm'

// This Edge function acts as an upload proxy: supports multipart/form-data (file + fields)
// and raw byte uploads. It uses the Service Role key to upload to Storage and
// optionally attributes the created video row by forwarding the user's JWT to an anon RPC client
// (if `SUPABASE_ANON_KEY` exists) or by decoding the JWT and passing _user_id to the RPC.

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  // Allow alternate secret names because the supabase CLI rejects env names
  // that start with `SUPABASE_`. Prefer explicit SUPABASE_* names when available,
  // otherwise fall back to shorter secret names the CLI permits.
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || Deno.env.get('PROJECT_URL') || Deno.env.get('SUPABASE_PROJECT_URL')
  const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE') || Deno.env.get('SERVICE_ROLE') || Deno.env.get('SERVICE_ROLE_KEY')
  const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('ANON_KEY') || Deno.env.get('PUBLIC_ANON_KEY')
  const BUCKET = Deno.env.get('SUPABASE_UPLOAD_BUCKET') || Deno.env.get('UPLOAD_BUCKET') || 'videos'

  const contentTypeHeader = req.headers.get('content-type') || ''

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
    return new Response(JSON.stringify({ error: 'server misconfigured - missing SUPABASE_URL or SUPABASE_SERVICE_ROLE (or alternate PROJECT_URL/SERVICE_ROLE)' }), { status: 500 })
  }

  // Create a service-role client for storage operations
  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE)

  try {
    // Support multipart/form-data (file + fields) or raw bytes with x-object-path
    if (contentTypeHeader.includes('multipart/form-data')) {
      const form = await req.formData()
      const file = form.get('file')
      const title = form.get('title')?.toString() || ''
      const description = form.get('description')?.toString() || ''
      const metadata = form.get('metadata') ? JSON.parse(form.get('metadata')!.toString()) : {}
      const bucket = form.get('bucket')?.toString() || BUCKET

      if (!file || !(file instanceof File)) {
        return new Response(JSON.stringify({ error: 'file field is required' }), { status: 400 })
      }

      const arrayBuffer = await (file as File).arrayBuffer()
      const uint8 = new Uint8Array(arrayBuffer)

      const filename = `${Date.now()}_${(file as File).name}`
      const objectPath = filename

      const { error: uploadErr } = await serviceClient.storage.from(bucket).upload(objectPath, uint8, { upsert: false, contentType: (file as File).type || 'application/octet-stream' })
      if (uploadErr) {
        console.error('storage.upload error', uploadErr)
        return new Response(JSON.stringify({ error: uploadErr.message }), { status: 500 })
      }

      const { data: signedGet, error: getErr } = await serviceClient.storage.from(bucket).createSignedUrl(objectPath, 60 * 60)
      if (getErr) {
        console.error('createSignedUrl error', getErr)
      }

      // Attempt to attribute the video to the user: prefer forwarding the user's JWT to an anon RPC client
      const authHeader = req.headers.get('authorization')
      let rpcResult = null

      if (SUPABASE_ANON_KEY && authHeader) {
        const rpcClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader, 'Content-Type': 'application/json' } } })
        const { data: rpcData, error: rpcError } = await rpcClient.rpc('videos_insert', { _title: title, _description: description, _url: signedGet?.signedURL ?? `${bucket}/${objectPath}`, _metadata: metadata }).catch((e) => ({ data: null, error: e }))
        if (rpcError) console.error('rpc error', rpcError)
        rpcResult = rpcData
      } else {
        // Try to decode sub from JWT if present and call RPC with service role by passing user id param (if the RPC supports it)
        let userId: string | undefined = undefined
        if (authHeader && authHeader.startsWith('Bearer ')) {
          try {
            const token = authHeader.split(' ')[1]
            const payload = token.split('.')[1]
            const padded = payload.padEnd(payload.length + (4 - (payload.length % 4)) % 4, '=')
            const decoded = atob(padded.replace(/-/g, '+').replace(/_/g, '/'))
            const obj = JSON.parse(decoded)
            userId = obj.sub
          } catch (e) {
            console.warn('failed to decode JWT for attribution', e)
          }
        }

        try {
          const rpcArgs: Record<string, unknown> = { _title: title, _description: description, _url: signedGet?.signedURL ?? `${bucket}/${objectPath}`, _metadata: metadata }
          if (userId) rpcArgs._user_id = userId
          const { data: rpcData, error: rpcError } = await serviceClient.rpc('videos_insert', rpcArgs as any)
          if (rpcError) console.error('rpc error (service role)', rpcError)
          rpcResult = rpcData
        } catch (e) {
          console.error('rpc call failed (service role)', e)
        }
      }

      return new Response(JSON.stringify({ objectPath, publicUrl: signedGet?.signedURL ?? `${bucket}/${objectPath}`, video: rpcResult }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    } else {
      // Raw bytes flow (backwards-compatible)
      const objectPath = req.headers.get('x-object-path')
      const contentType = req.headers.get('content-type') || 'application/octet-stream'

      if (!objectPath) {
        return new Response(JSON.stringify({ error: 'missing x-object-path header' }), { status: 400 })
      }

      const body = await req.arrayBuffer()
      const uint8 = new Uint8Array(body)

      const { data, error } = await serviceClient.storage.from(BUCKET).upload(objectPath, uint8, { upsert: false, contentType })
      if (error) {
        console.error('storage.upload error', error)
        return new Response(JSON.stringify({ error: error.message }), { status: 500 })
      }

      const { data: signedGet, error: getErr } = await serviceClient.storage.from(BUCKET).createSignedUrl(objectPath, 60 * 60)
      if (getErr) {
        console.error('createSignedUrl error', getErr)
      }

      return new Response(JSON.stringify({ objectPath, publicUrl: signedGet?.signedURL ?? `${BUCKET}/${objectPath}` }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
  } catch (err) {
    console.error('upload proxy error', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
