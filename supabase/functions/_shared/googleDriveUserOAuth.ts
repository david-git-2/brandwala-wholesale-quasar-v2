const TOKEN_URL = 'https://oauth2.googleapis.com/token'

let cachedUserToken: { token: string; expiresAt: number } | null = null

export function hasUserOAuthConfig(): boolean {
  return Boolean(
    Deno.env.get('GOOGLE_DRIVE_OAUTH_CLIENT_ID')?.trim() &&
      Deno.env.get('GOOGLE_DRIVE_OAUTH_CLIENT_SECRET')?.trim() &&
      Deno.env.get('GOOGLE_DRIVE_REFRESH_TOKEN')?.trim(),
  )
}

export async function getUserOAuthAccessToken(): Promise<string> {
  const clientId = Deno.env.get('GOOGLE_DRIVE_OAUTH_CLIENT_ID')?.trim()
  const clientSecret = Deno.env.get('GOOGLE_DRIVE_OAUTH_CLIENT_SECRET')?.trim()
  const refreshToken = Deno.env.get('GOOGLE_DRIVE_REFRESH_TOKEN')?.trim()

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error(
      'Google Drive user OAuth is not configured (GOOGLE_DRIVE_OAUTH_CLIENT_ID, GOOGLE_DRIVE_OAUTH_CLIENT_SECRET, GOOGLE_DRIVE_REFRESH_TOKEN).',
    )
  }

  const now = Math.floor(Date.now() / 1000)
  if (cachedUserToken && cachedUserToken.expiresAt > now + 60) {
    return cachedUserToken.token
  }

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  })

  const payload = await response.json()
  if (!response.ok) {
    throw new Error(
      payload.error_description || payload.error || 'Failed to refresh Google Drive user token',
    )
  }

  const accessToken = payload.access_token as string | undefined
  if (!accessToken) {
    throw new Error('Google token refresh returned no access_token')
  }

  cachedUserToken = {
    token: accessToken,
    expiresAt: now + Number(payload.expires_in || 3600),
  }

  return accessToken
}
