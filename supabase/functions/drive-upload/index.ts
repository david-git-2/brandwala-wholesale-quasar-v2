import {
  authenticateRequest,
  assertRootFolderOnSharedDrive,
  CORS_HEADERS,
  formatDriveApiError,
  getDriveAuthMode,
  getRootFolderId,
  isDriveUploadConfigured,
  jsonResponse,
  makeDriveFilePublic,
  parseAndValidateThriftFolderPath,
  resolveDriveAccessToken,
  resolveOrCreateNestedPath,
  shouldMakeUploadedFilesPublic,
  uploadFileToDrive,
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

  let formData: FormData
  try {
    formData = await request.formData()
  } catch {
    return jsonResponse({ error: 'Invalid multipart form data' }, 400)
  }

  const fileEntry = formData.get('file')
  const fileName = formData.get('fileName')?.toString().trim() || 'image.jpg'
  const folderPath = formData.get('folderPath')?.toString().trim() || ''
  const folderSegments = parseAndValidateThriftFolderPath(folderPath)

  if (!(fileEntry instanceof File)) {
    return jsonResponse({ error: 'file is required' }, 400)
  }

  if (!folderSegments) {
    return jsonResponse({ error: 'Invalid or disallowed folder path' }, 400)
  }

  try {
    const accessToken = await resolveDriveAccessToken()

    if (getDriveAuthMode() === 'service_account') {
      await assertRootFolderOnSharedDrive(accessToken, rootFolderId)
    }

    const targetFolderId = await resolveOrCreateNestedPath(
      accessToken,
      rootFolderId,
      folderSegments,
    )
    const fileBytes = new Uint8Array(await fileEntry.arrayBuffer())
    const mimeType = fileEntry.type || 'image/jpeg'

    const uploaded = await uploadFileToDrive(
      accessToken,
      targetFolderId,
      fileName,
      mimeType,
      fileBytes,
    )

    if (shouldMakeUploadedFilesPublic()) {
      await makeDriveFilePublic(accessToken, uploaded.fileId)
    }

    return jsonResponse({
      fileId: uploaded.fileId,
      directLink: `https://drive.google.com/uc?id=${uploaded.fileId}`,
      webViewLink: uploaded.webViewLink || `https://drive.google.com/file/d/${uploaded.fileId}/view`,
    })
  } catch (err) {
    console.error('Drive upload error:', err)
    const message = formatDriveApiError((err as Error).message)
    return jsonResponse(
      { error: 'Failed to upload image to Google Drive', details: message },
      502,
    )
  }
})
