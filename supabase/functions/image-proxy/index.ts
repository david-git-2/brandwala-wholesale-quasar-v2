const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, OPTIONS',
  'access-control-allow-headers': '*',
}

const isPrivateHost = (hostname: string) => {
  const value = hostname.trim().toLowerCase()

  if (
    value === 'localhost' ||
    value === '127.0.0.1' ||
    value === '::1' ||
    value.endsWith('.local')
  ) {
    return true
  }

  return (
    value.startsWith('10.') ||
    value.startsWith('192.168.') ||
    value.startsWith('172.16.') ||
    value.startsWith('172.17.') ||
    value.startsWith('172.18.') ||
    value.startsWith('172.19.') ||
    value.startsWith('172.20.') ||
    value.startsWith('172.21.') ||
    value.startsWith('172.22.') ||
    value.startsWith('172.23.') ||
    value.startsWith('172.24.') ||
    value.startsWith('172.25.') ||
    value.startsWith('172.26.') ||
    value.startsWith('172.27.') ||
    value.startsWith('172.28.') ||
    value.startsWith('172.29.') ||
    value.startsWith('172.30.') ||
    value.startsWith('172.31.')
  )
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', {
      status: 200,
      headers: CORS_HEADERS,
    })
  }

  if (request.method !== 'GET') {
    return new Response('Method not allowed', {
      status: 405,
      headers: CORS_HEADERS,
    })
  }

  try {
    const requestUrl = new URL(request.url)
    const rawTarget = requestUrl.searchParams.get('url')

    if (!rawTarget) {
      return new Response('Missing url query parameter', {
        status: 400,
        headers: CORS_HEADERS,
      })
    }

    let targetUrl: URL
    try {
      targetUrl = new URL(rawTarget)
    } catch {
      return new Response('Invalid url query parameter', {
        status: 400,
        headers: CORS_HEADERS,
      })
    }

    if (!['http:', 'https:'].includes(targetUrl.protocol)) {
      return new Response('Unsupported protocol', {
        status: 400,
        headers: CORS_HEADERS,
      })
    }

    if (isPrivateHost(targetUrl.hostname)) {
      return new Response('Private hosts are not allowed', {
        status: 400,
        headers: CORS_HEADERS,
      })
    }

    const upstream = await fetch(targetUrl.toString(), {
      method: 'GET',
      headers: {
        accept: 'image/*,*/*;q=0.8',
      },
    })

    if (!upstream.ok || !upstream.body) {
      return new Response(`Upstream request failed: ${upstream.status}`, {
        status: 502,
        headers: CORS_HEADERS,
      })
    }

    const contentType = upstream.headers.get('content-type') ?? 'application/octet-stream'

    return new Response(upstream.body, {
      status: 200,
      headers: {
        ...CORS_HEADERS,
        'content-type': contentType,
        'cache-control': 'public, max-age=86400',
      },
    })
  } catch {
    return new Response('Unexpected proxy error', {
      status: 500,
      headers: CORS_HEADERS,
    })
  }
})
