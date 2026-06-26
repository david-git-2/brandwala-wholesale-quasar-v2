import {
  authenticateRequest,
  CORS_HEADERS,
  deleteDriveFileById,
  formatDriveApiError,
  getAllowedThriftFolder,
  getRootFolderId,
  isDriveUploadConfigured,
  isFileUnderFolder,
  jsonResponse,
  resolveDriveAccessToken,
  resolveOrCreateSubfolder,
} from '../_shared/googleDrive.ts'

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { status: 200, headers: CORS_HEADERS })
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  const authErrorResponse = await authenticateRequest(request)
  if (authErrorResponse) return authErrorResponse

  const rootFolderId = getRootFolderId()

  if (!isDriveUploadConfigured() || !rootFolderId) {
    return jsonResponse({ error: 'Google Drive server configuration missing' }, 500)
  }

  let payload: { fileId?: string }
  try {
    payload = await request.json()
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400)
  }

  const fileId = payload.fileId?.trim()
  if (!fileId) {
    return jsonResponse({ error: 'fileId is required' }, 400)
  }

  try {
    const accessToken = await resolveDriveAccessToken()
    const thriftFolderId = await resolveOrCreateSubfolder(
      accessToken,
      rootFolderId,
      getAllowedThriftFolder(),
    )

    const allowed = await isFileUnderFolder(accessToken, fileId, thriftFolderId)
    if (!allowed) {
      return jsonResponse({ error: 'Invalid or disallowed Drive file id' }, 400)
    }

    await deleteDriveFileById(accessToken, fileId)
    return jsonResponse({ success: true })
  } catch (err) {
    console.error('Drive delete error:', err)
    return jsonResponse(
      {
        error: 'Failed to delete image from Google Drive',
        details: formatDriveApiError((err as Error).message),
      },
      502,
    )
  }
})
