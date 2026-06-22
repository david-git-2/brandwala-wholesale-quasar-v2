import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-allow-headers': '*',
}

const THRIFT_FOLDER_PREFIXES = ['thrift_stocks/', 'thrift-stocks/']

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'content-type': 'application/json' },
  })
}

export function parseCloudinaryPublicId(
  imageUrl: string,
  expectedCloudName?: string,
): string | null {
  let parsed: URL
  try {
    parsed = new URL(imageUrl)
  } catch {
    return null
  }

  if (parsed.hostname !== 'res.cloudinary.com') return null

  const match = parsed.pathname.match(/^\/([^/]+)\/image\/upload\/(.+)$/)
  if (!match) return null

  const cloudName = match[1]
  if (expectedCloudName && cloudName !== expectedCloudName) return null

  const segments = match[2].split('/')
  const versionIdx = segments.findIndex((segment) => /^v\d+$/.test(segment))

  let publicIdSegments: string[]
  if (versionIdx !== -1) {
    publicIdSegments = segments.slice(versionIdx + 1)
  } else {
    const folderIdx = segments.findIndex(
      (segment) => segment.startsWith('thrift-stocks') || segment.startsWith('thrift_stocks'),
    )
    publicIdSegments = folderIdx !== -1 ? segments.slice(folderIdx) : segments
  }

  if (publicIdSegments.length === 0) return null

  const lastIdx = publicIdSegments.length - 1
  publicIdSegments[lastIdx] = publicIdSegments[lastIdx].replace(/\.[^.]+$/, '')

  return publicIdSegments.join('/')
}

function isThriftPublicId(publicId: string): boolean {
  return THRIFT_FOLDER_PREFIXES.some((prefix) => publicId.startsWith(prefix))
}

type CloudinaryDestroyResult =
  | { ok: true; result: string }
  | { ok: false; status: number; message: string }

async function destroyCloudinaryImage(
  cloudName: string,
  apiKey: string,
  apiSecret: string,
  publicId: string,
): Promise<CloudinaryDestroyResult> {
  const credentials = btoa(`${apiKey}:${apiSecret}`)
  const body = new URLSearchParams({ public_id: publicId })

  const response = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/destroy`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  })

  const text = await response.text()
  let parsed: { result?: string; error?: { message?: string } } = {}
  try {
    parsed = JSON.parse(text)
  } catch {
    // keep empty parsed object
  }

  if (response.ok) {
    const result = parsed.result ?? 'ok'
    if (result === 'ok' || result === 'not found') {
      return { ok: true, result }
    }
    return {
      ok: false,
      status: response.status,
      message: parsed.error?.message || `Unexpected Cloudinary result: ${result}`,
    }
  }

  return {
    ok: false,
    status: response.status,
    message: parsed.error?.message || text || `HTTP ${response.status}`,
  }
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { status: 200, headers: CORS_HEADERS })
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  const cloudName = Deno.env.get('CLOUDINARY_CLOUD_NAME')?.trim()
  const apiKey = Deno.env.get('CLOUDINARY_API_KEY')?.trim()
  const apiSecret = Deno.env.get('CLOUDINARY_API_SECRET')?.trim()
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

  if (!cloudName || !apiKey || !apiSecret || !supabaseUrl || !supabaseAnonKey) {
    return jsonResponse({ error: 'Server configuration missing' }, 500)
  }

  const authHeader = request.headers.get('Authorization')
  if (!authHeader) {
    return jsonResponse({ error: 'Unauthorized' }, 401)
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  })

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError || !user) {
    return jsonResponse({ error: 'Unauthorized' }, 401)
  }

  let payload: { imageUrl?: string }
  try {
    payload = await request.json()
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400)
  }

  const imageUrl = payload.imageUrl?.trim()
  if (!imageUrl) {
    return jsonResponse({ error: 'imageUrl is required' }, 400)
  }

  const publicId = parseCloudinaryPublicId(imageUrl, cloudName)
  if (!publicId || !isThriftPublicId(publicId)) {
    return jsonResponse({ error: 'Invalid or disallowed Cloudinary image URL' }, 400)
  }

  try {
    const result = await destroyCloudinaryImage(cloudName, apiKey, apiSecret, publicId)

    if (result.ok) {
      return jsonResponse({ success: true, result: result.result })
    }

    console.error('Cloudinary destroy failed:', result.status, result.message, 'publicId:', publicId)
    return jsonResponse(
      {
        error: 'Failed to delete image from Cloudinary',
        details: result.message,
        publicId,
      },
      502,
    )
  } catch (err) {
    console.error('Cloudinary delete error:', err)
    return jsonResponse({ error: 'Unexpected delete error' }, 500)
  }
})
