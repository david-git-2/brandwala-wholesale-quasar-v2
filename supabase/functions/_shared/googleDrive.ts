import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts'
import { getUserOAuthAccessToken, hasUserOAuthConfig } from './googleDriveUserOAuth.ts'

export const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-allow-headers': '*',
}

const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive'
const TOKEN_URL = 'https://oauth2.googleapis.com/token'
const DRIVE_API = 'https://www.googleapis.com/drive/v3'
const DRIVE_UPLOAD_API = 'https://www.googleapis.com/upload/drive/v3/files'

function sharedDriveQuery(extra: Record<string, string> = {}): string {
  return new URLSearchParams({
    supportsAllDrives: 'true',
    ...extra,
  }).toString()
}

export type DriveAuthMode = 'service_account' | 'user_oauth'

export function getDriveAuthMode(): DriveAuthMode {
  const explicit = Deno.env.get('GOOGLE_DRIVE_AUTH_MODE')?.trim().toLowerCase()
  if (explicit === 'user_oauth' || explicit === 'service_account') {
    return explicit
  }
  return hasUserOAuthConfig() ? 'user_oauth' : 'service_account'
}

function driveApiQuery(extra: Record<string, string> = {}): string {
  if (getDriveAuthMode() === 'user_oauth') {
    return new URLSearchParams(extra).toString()
  }
  return sharedDriveQuery(extra)
}

function listFoldersQueryExtra(): Record<string, string> {
  if (getDriveAuthMode() === 'user_oauth') return {}
  return {
    includeItemsFromAllDrives: 'true',
    corpora: 'allDrives',
  }
}

export function isDriveUploadConfigured(): boolean {
  if (!getRootFolderId()) return false
  if (getDriveAuthMode() === 'user_oauth') return hasUserOAuthConfig()
  return Boolean(loadServiceAccount())
}

export function shouldMakeUploadedFilesPublic(): boolean {
  const flag = Deno.env.get('GOOGLE_DRIVE_PUBLIC_FILES')?.trim().toLowerCase()
  if (flag === 'false' || flag === '0') return false
  return true
}

export async function resolveDriveAccessToken(): Promise<string> {
  if (getDriveAuthMode() === 'user_oauth') {
    return await getUserOAuthAccessToken()
  }

  const serviceAccount = loadServiceAccount()
  if (!serviceAccount) {
    throw new Error('Google Drive service account is not configured')
  }

  return await getAccessToken(serviceAccount)
}

export async function makeDriveFilePublic(accessToken: string, fileId: string): Promise<void> {
  const response = await fetch(`${DRIVE_API}/files/${encodeURIComponent(fileId)}/permissions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ role: 'reader', type: 'anyone' }),
  })

  if (!response.ok) {
    const text = await response.text()
    if (text.includes('already exists')) return
    console.warn('Could not make Drive file public:', text)
  }
}

export function formatDriveApiError(raw: string): string {
  const sharedDriveHelp =
    'GOOGLE_DRIVE_ROOT_FOLDER_ID must be a folder inside a Google Shared Drive (Workspace), not My Drive. ' +
    'In Drive → Shared drives → add tradeflowbd-drive-uploader@tradeflowbd.iam.gserviceaccount.com as Content manager, ' +
    'create an upload folder there, then run: GOOGLE_DRIVE_ROOT_FOLDER_ID=new_folder_id npm run secrets:drive'

  if (
    raw.includes('storageQuotaExceeded') ||
    raw.includes('Service Accounts do not have storage quota')
  ) {
    return sharedDriveHelp
  }

  const jsonStart = raw.indexOf('{')
  if (jsonStart !== -1) {
    try {
      const parsed = JSON.parse(raw.slice(jsonStart)) as {
        error?: { message?: string; errors?: Array<{ reason?: string }> }
      }
      const message = parsed.error?.message || ''
      const reason = parsed.error?.errors?.[0]?.reason || ''
      if (
        reason === 'storageQuotaExceeded' ||
        message.includes('Service Accounts do not have storage quota')
      ) {
        return sharedDriveHelp
      }
      if (message) return message
    } catch {
      // fall through to raw message
    }
  }

  return raw
}

const SHARED_DRIVE_ROOT_HELP =
  'GOOGLE_DRIVE_ROOT_FOLDER_ID must be a folder inside a Google Shared Drive (Workspace), not My Drive. ' +
  'Add tradeflowbd-drive-uploader@tradeflowbd.iam.gserviceaccount.com as Content manager on the shared drive, ' +
  'then point the secret at a folder inside that shared drive.'

type DriveFileMetadata = {
  id?: string
  name?: string
  driveId?: string
}

export async function assertRootFolderOnSharedDrive(
  accessToken: string,
  rootFolderId: string,
): Promise<void> {
  const response = await fetch(
    `${DRIVE_API}/files/${encodeURIComponent(rootFolderId)}?${sharedDriveQuery({
      fields: 'id,name,driveId',
    })}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  )

  if (!response.ok) {
    throw new Error(
      `Root folder ${rootFolderId} is not accessible to the service account. ${SHARED_DRIVE_ROOT_HELP}`,
    )
  }

  const file = await response.json() as DriveFileMetadata
  if (!file.driveId) {
    throw new Error(SHARED_DRIVE_ROOT_HELP)
  }
}

export type ServiceAccountCredentials = {
  client_email: string
  private_key: string
}

export function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'content-type': 'application/json' },
  })
}

export function loadServiceAccount(): ServiceAccountCredentials | null {
  const raw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')?.trim()
  if (!raw) return null

  try {
    const parsed = JSON.parse(raw) as ServiceAccountCredentials
    if (!parsed.client_email || !parsed.private_key) return null
    return parsed
  } catch {
    return null
  }
}

export function getRootFolderId(): string | null {
  return Deno.env.get('GOOGLE_DRIVE_ROOT_FOLDER_ID')?.trim() || null
}

export function getAllowedThriftFolder(): string {
  return (
    Deno.env.get('GOOGLE_DRIVE_THRIFT_FOLDER')?.trim() ||
    Deno.env.get('VITE_GOOGLE_DRIVE_THRIFT_FOLDER')?.trim() ||
    'thrift'
  )
}

const SHIPMENT_FOLDER_PATTERN = /^shipment-\d+$/

export function parseAndValidateThriftFolderPath(folderPath: string): string[] | null {
  const baseFolder = getAllowedThriftFolder()
  const segments = folderPath
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean)

  if (segments.length === 0) return null
  if (segments[0] !== baseFolder) return null

  if (segments.length === 1) {
    return segments
  }

  if (segments.length === 2 && SHIPMENT_FOLDER_PATTERN.test(segments[1]!)) {
    return segments
  }

  return null
}

export async function resolveOrCreateNestedPath(
  accessToken: string,
  rootFolderId: string,
  segments: string[],
): Promise<string> {
  let currentFolderId = rootFolderId

  for (const segment of segments) {
    currentFolderId = await resolveOrCreateSubfolder(accessToken, currentFolderId, segment)
  }

  return currentFolderId
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')

  const binary = Uint8Array.from(atob(pemContents), (char) => char.charCodeAt(0))

  return crypto.subtle.importKey(
    'pkcs8',
    binary,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null

export async function getAccessToken(creds: ServiceAccountCredentials): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token
  }

  const privateKey = await importPrivateKey(creds.private_key)
  const jwt = await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: creds.client_email,
      scope: DRIVE_SCOPE,
      aud: TOKEN_URL,
      exp: getNumericDate(60 * 60),
      iat: getNumericDate(0),
    },
    privateKey,
  )

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const payload = await response.json()
  if (!response.ok) {
    throw new Error(payload.error_description || payload.error || 'Failed to obtain Google access token')
  }

  cachedAccessToken = {
    token: payload.access_token as string,
    expiresAt: now + Number(payload.expires_in || 3600),
  }

  return cachedAccessToken.token
}

type DriveFile = {
  id?: string
  name?: string
  parents?: string[]
  webViewLink?: string
}

async function driveGetFile(accessToken: string, fileId: string, fields: string): Promise<DriveFile | null> {
  const response = await fetch(
    `${DRIVE_API}/files/${encodeURIComponent(fileId)}?${driveApiQuery({ fields })}`,
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  )

  if (!response.ok) {
    return null
  }

  return await response.json() as DriveFile
}

async function listChildFolderByName(
  accessToken: string,
  parentId: string,
  name: string,
): Promise<string | null> {
  const query = [
    "mimeType = 'application/vnd.google-apps.folder'",
    "trashed = false",
    `name = '${name.replace(/'/g, "\\'")}'`,
    `'${parentId}' in parents`,
  ].join(' and ')

  const url = `${DRIVE_API}/files?${driveApiQuery({
    q: query,
    fields: 'files(id,name)',
    pageSize: '1',
    ...listFoldersQueryExtra(),
  })}`

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  if (!response.ok) {
    throw new Error(formatDriveApiError(`Drive list failed: ${await response.text()}`))
  }

  const payload = await response.json() as { files?: Array<{ id?: string }> }
  return payload.files?.[0]?.id || null
}

async function createChildFolder(
  accessToken: string,
  parentId: string,
  name: string,
): Promise<string> {
  const response = await fetch(`${DRIVE_API}/files?${driveApiQuery()}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      name,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parentId],
    }),
  })

  if (!response.ok) {
    throw new Error(formatDriveApiError(`Drive folder create failed: ${await response.text()}`))
  }

  const payload = await response.json() as { id?: string }
  if (!payload.id) {
    throw new Error('Drive folder create returned no id')
  }

  return payload.id
}

export async function resolveOrCreateSubfolder(
  accessToken: string,
  rootFolderId: string,
  subfolderName: string,
): Promise<string> {
  const existing = await listChildFolderByName(accessToken, rootFolderId, subfolderName)
  if (existing) return existing
  return await createChildFolder(accessToken, rootFolderId, subfolderName)
}

export async function isFileUnderFolder(
  accessToken: string,
  fileId: string,
  allowedFolderId: string,
): Promise<boolean> {
  let currentId: string | undefined = fileId
  const seen = new Set<string>()

  while (currentId && !seen.has(currentId)) {
    if (currentId === allowedFolderId) {
      return true
    }

    seen.add(currentId)
    const file = await driveGetFile(accessToken, currentId, 'id,parents')
    if (!file) return false
    currentId = file.parents?.[0]
  }

  return false
}

export async function uploadFileToDrive(
  accessToken: string,
  folderId: string,
  fileName: string,
  mimeType: string,
  fileBytes: Uint8Array,
): Promise<{ fileId: string; webViewLink?: string }> {
  const metadata = JSON.stringify({ name: fileName, parents: [folderId] })
  const boundary = `drive_upload_${crypto.randomUUID()}`
  const encoder = new TextEncoder()

  const prelude = encoder.encode(
    `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n` +
      `--${boundary}\r\nContent-Type: ${mimeType}\r\n\r\n`,
  )
  const closing = encoder.encode(`\r\n--${boundary}--`)

  const body = new Uint8Array(prelude.length + fileBytes.length + closing.length)
  body.set(prelude, 0)
  body.set(fileBytes, prelude.length)
  body.set(closing, prelude.length + fileBytes.length)

  const response = await fetch(
    `${DRIVE_UPLOAD_API}?${driveApiQuery({
      uploadType: 'multipart',
      fields: 'id,webViewLink',
    })}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': `multipart/related; boundary=${boundary}`,
      },
      body,
    },
  )

  if (!response.ok) {
    throw new Error(formatDriveApiError(`Drive upload failed: ${await response.text()}`))
  }

  const payload = await response.json() as { id?: string; webViewLink?: string }
  if (!payload.id) {
    throw new Error('Drive upload returned no file id')
  }

  return { fileId: payload.id, webViewLink: payload.webViewLink }
}

export async function deleteDriveFileById(accessToken: string, fileId: string): Promise<void> {
  const response = await fetch(
    `${DRIVE_API}/files/${encodeURIComponent(fileId)}?${driveApiQuery()}`,
    {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  )

  if (response.status === 404) {
    return
  }

  if (!response.ok) {
    throw new Error(formatDriveApiError(`Drive delete failed: ${await response.text()}`))
  }
}

export async function authenticateRequest(request: Request): Promise<Response | null> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse({ error: 'Server configuration missing' }, 500)
  }

  const authHeader = request.headers.get('Authorization')
  if (!authHeader) {
    return jsonResponse({ error: 'Unauthorized' }, 401)
  }

  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2')
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

  return null
}
