import { createClient } from '@supabase/supabase-js'
import fs from 'fs'

const SUPABASE_URL = 'https://jnkzbfqrwkgfiyxvwrug.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impua3piZnFyd2tnZml5eHZ3cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NDQ0NDgsImV4cCI6MjA4NDAyMDQ0OH0.20qAetWuXPOeA_fcflj_wdx_-mwKlHIszVvgEwa8sZo'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

async function main() {
  try {
    const data = new TextEncoder().encode('hello from test script')
    const fileName = `test-node-${Date.now()}.txt`
    const path = `test-uploads/${fileName}`

    console.log('Uploading to', path)
    const { data: uploadData, error: uploadError } = await supabase.storage.from('videos').upload(path, data, { contentType: 'text/plain', upsert: false })
    if (uploadError) {
      console.error('Upload error:', uploadError)
      process.exit(1)
    }
    console.log('Upload result:', uploadData)

    const { data: publicUrlData } = supabase.storage.from('videos').getPublicUrl(path)
    console.log('Public URL:', publicUrlData?.publicUrl ?? publicUrlData)
  } catch (e) {
    console.error('Script error:', e)
    process.exit(2)
  }
}

main()
