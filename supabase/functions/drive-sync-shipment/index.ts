import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  assertRootFolderOnSharedDrive,
  authenticateRequest,
  CORS_HEADERS,
  formatDriveApiError,
  getAllowedThriftFolder,
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

const CLOUDINARY_HOST = 'res.cloudinary.com'

type PendingStockImage = {
  stock_id: number
  barcode: string
  image_id: number
  image_url: string
}

type SyncError = {
  stockId: number
  barcode: string
  message: string
}

function isAllowedCloudinaryUrl(imageUrl: string): boolean {
  try {
    const parsed = new URL(imageUrl.trim())
    return parsed.hostname === CLOUDINARY_HOST || parsed.hostname.endsWith('.cloudinary.com')
  } catch {
    return false
  }
}

function buildDriveFileName(barcode: string): string {
  const safe = barcode.trim().replace(/[^\w.-]+/g, '_')
  if (!safe) return 'stock-image.jpg'
  return safe.toLowerCase().endsWith('.jpg') || safe.toLowerCase().endsWith('.jpeg')
    ? safe
    : `${safe}.jpg`
}

function buildShipmentDriveFolderPath(shipmentId: number): string {
  return `${getAllowedThriftFolder()}/shipment-${shipmentId}`
}

async function assertTenantAccess(
  supabase: SupabaseClient,
  tenantId: number,
  userEmail: string,
): Promise<Response | null> {
  const { data, error } = await supabase
    .from('memberships')
    .select('id')
    .eq('tenant_id', tenantId)
    .ilike('email', userEmail.trim())
    .eq('is_active', true)
    .in('role', ['admin', 'staff'])
    .maybeSingle()

  if (error) {
    console.error('Membership check failed:', error)
    return jsonResponse({ error: 'Authorization check failed' }, 500)
  }

  if (!data) {
    return jsonResponse({ error: 'Not authorized for this tenant' }, 403)
  }

  return null
}

async function listPendingShipmentImages(
  supabase: SupabaseClient,
  tenantId: number,
  shipmentId: number,
): Promise<PendingStockImage[]> {
  const { data: shipment, error: shipmentError } = await supabase
    .from('thrift_shipments')
    .select('id')
    .eq('id', shipmentId)
    .eq('tenant_id', tenantId)
    .maybeSingle()

  if (shipmentError) throw shipmentError
  if (!shipment) {
    throw new Error('Shipment not found')
  }

  const { data, error } = await supabase
    .from('thrift_stocks')
    .select(`
      id,
      barcode,
      thrift_stock_images (
        id,
        image_url,
        drive_file_id,
        is_primary
      )
    `)
    .eq('tenant_id', tenantId)
    .eq('shipment_id', shipmentId)

  if (error) throw error

  const rows: PendingStockImage[] = []

  for (const stock of data || []) {
    const images = stock.thrift_stock_images as Array<{
      id: number
      image_url: string
      drive_file_id: string | null
      is_primary: boolean
    }> | null

    const primary = images?.find((img) => img.is_primary) || images?.[0]
    const imageUrl = primary?.image_url?.trim()
    const barcode = typeof stock.barcode === 'string' ? stock.barcode.trim() : ''

    if (!primary?.id || !imageUrl || primary.drive_file_id) continue

    rows.push({
      stock_id: stock.id as number,
      barcode,
      image_id: primary.id,
      image_url: imageUrl,
    })
  }

  return rows
}

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

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const authHeader = request.headers.get('Authorization')

  if (!supabaseUrl || !supabaseAnonKey || !authHeader) {
    return jsonResponse({ error: 'Server configuration missing' }, 500)
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  })

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser()

  if (userError || !user?.email) {
    return jsonResponse({ error: 'Unauthorized' }, 401)
  }

  let payload: { tenantId?: number; shipmentId?: number }
  try {
    payload = await request.json()
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400)
  }

  const tenantId = Number(payload.tenantId)
  const shipmentId = Number(payload.shipmentId)

  if (!Number.isFinite(tenantId) || tenantId <= 0) {
    return jsonResponse({ error: 'tenantId is required' }, 400)
  }

  if (!Number.isFinite(shipmentId) || shipmentId <= 0) {
    return jsonResponse({ error: 'shipmentId is required' }, 400)
  }

  const tenantAccessError = await assertTenantAccess(supabase, tenantId, user.email)
  if (tenantAccessError) return tenantAccessError

  const folderPath = buildShipmentDriveFolderPath(shipmentId)
  const folderSegments = parseAndValidateThriftFolderPath(folderPath)
  if (!folderSegments) {
    return jsonResponse({ error: 'Invalid shipment folder path' }, 400)
  }

  let pending: PendingStockImage[]
  try {
    pending = await listPendingShipmentImages(supabase, tenantId, shipmentId)
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Failed to load shipment images'
    return jsonResponse({ error: message }, 400)
  }

  if (pending.length === 0) {
    return jsonResponse({
      synced: 0,
      failed: 0,
      total: 0,
      errors: [],
      message: 'No images pending Drive sync for this shipment',
    })
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

    let synced = 0
    const errors: SyncError[] = []

    for (const row of pending) {
      if (!isAllowedCloudinaryUrl(row.image_url)) {
        errors.push({
          stockId: row.stock_id,
          barcode: row.barcode,
          message: 'Image URL is not a Cloudinary URL',
        })
        continue
      }

      try {
        const imageResponse = await fetch(row.image_url)
        if (!imageResponse.ok) {
          throw new Error(`Failed to download image (${imageResponse.status})`)
        }

        const fileBytes = new Uint8Array(await imageResponse.arrayBuffer())
        const mimeType = imageResponse.headers.get('content-type') || 'image/jpeg'
        const fileName = buildDriveFileName(row.barcode || `stock-${row.stock_id}`)

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

        const { error: updateError } = await supabase
          .from('thrift_stock_images')
          .update({ drive_file_id: uploaded.fileId })
          .eq('id', row.image_id)
          .eq('stock_id', row.stock_id)
          .is('drive_file_id', null)

        if (updateError) {
          throw new Error(updateError.message || 'Failed to save drive_file_id')
        }

        synced += 1
      } catch (err) {
        const message = err instanceof Error ? formatDriveApiError(err.message) : 'Sync failed'
        errors.push({
          stockId: row.stock_id,
          barcode: row.barcode,
          message,
        })
      }
    }

    return jsonResponse({
      synced,
      failed: errors.length,
      total: pending.length,
      errors,
      folderPath,
      message: synced === pending.length
        ? `Synced ${synced} image(s) to Google Drive`
        : `Synced ${synced} of ${pending.length} image(s)`,
    })
  } catch (err) {
    console.error('drive-sync-shipment error:', err)
    const message = err instanceof Error ? formatDriveApiError(err.message) : 'Drive sync failed'
    return jsonResponse({ error: message }, 502)
  }
})
