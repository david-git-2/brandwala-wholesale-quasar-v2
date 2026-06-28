import JSZip from 'jszip'
import { supabase } from 'src/boot/supabase'

type ShipmentImageRow = {
  stockId: number
  barcode: string
  imageUrl: string
}

type StockImageRow = {
  id: number
  image_url: string
  is_primary: boolean
}

type StockRow = {
  id: number
  barcode: string
  thrift_stock_images: StockImageRow[] | null
}

export type ShipmentImageDownloadResult = {
  downloaded: number
  failed: number
  total: number
  errors: Array<{ stockId: number; barcode: string; message: string }>
  message?: string
  folderName: string
}

export class ShipmentDownloadCancelledError extends Error {
  constructor() {
    super('Download cancelled')
    this.name = 'ShipmentDownloadCancelledError'
  }
}

export type ShipmentDownloadProgress = {
  phase: 'listing' | 'downloading' | 'zipping' | 'done'
  current: number
  total: number
  currentBarcode?: string
}

export type ShipmentDownloadOptions = {
  onProgress?: (p: ShipmentDownloadProgress) => void
  signal?: AbortSignal
}

function buildImageFileName(barcode: string, stockId: number): string {
  const safe = barcode.trim().replace(/[^\w.-]+/g, '_')
  const base = safe || `stock-${stockId}`
  return base.toLowerCase().endsWith('.jpg') || base.toLowerCase().endsWith('.jpeg')
    ? base
    : `${base}.jpg`
}

function isAllowedCloudinaryUrl(imageUrl: string): boolean {
  try {
    const parsed = new URL(imageUrl.trim())
    return parsed.hostname === 'res.cloudinary.com' || parsed.hostname.endsWith('.cloudinary.com')
  } catch {
    return false
  }
}

function buildShipmentFolderName(shipmentId: number): string {
  return `shipment-${shipmentId}`
}

async function listShipmentImages(
  tenantId: number,
  shipmentId: number,
): Promise<ShipmentImageRow[]> {
  const { data, error } = await supabase
    .from('thrift_stocks')
    .select(`
      id,
      barcode,
      thrift_stock_images (
        id,
        image_url,
        is_primary
      )
    `)
    .eq('tenant_id', tenantId)
    .eq('shipment_id', shipmentId)

  if (error) throw error

  const rows: ShipmentImageRow[] = []

  for (const stock of (data || []) as StockRow[]) {
    const images = stock.thrift_stock_images
    const primary = images?.find((img) => img.is_primary) || images?.[0]
    const imageUrl = primary?.image_url?.trim()

    if (!imageUrl) continue

    rows.push({
      stockId: stock.id,
      barcode: stock.barcode?.trim() || '',
      imageUrl,
    })
  }

  return rows
}

async function fetchImageBlob(imageUrl: string, signal?: AbortSignal): Promise<Blob> {
  const response = await fetch(imageUrl, { signal: signal as any })
  if (!response.ok) {
    throw new Error(`Failed to download image (${response.status})`)
  }
  return response.blob()
}

function supportsDirectoryPicker(): boolean {
  return typeof window !== 'undefined' && 'showDirectoryPicker' in window
}

async function pickDownloadDirectory(): Promise<FileSystemDirectoryHandle> {
  const pickerWindow = window as unknown as {
    showDirectoryPicker: (options: { mode: 'readwrite' | 'read' }) => Promise<FileSystemDirectoryHandle>
  }

  try {
    return await pickerWindow.showDirectoryPicker({ mode: 'readwrite' })
  } catch (err) {
    if (err instanceof DOMException && err.name === 'AbortError') {
      throw new ShipmentDownloadCancelledError()
    }
    throw err
  }
}

async function writeBlobToDirectory(
  rootDir: FileSystemDirectoryHandle,
  folderName: string,
  fileName: string,
  blob: Blob,
): Promise<void> {
  const shipmentDir = await rootDir.getDirectoryHandle(folderName, { create: true })
  const fileHandle = await shipmentDir.getFileHandle(fileName, { create: true })
  const writable = await fileHandle.createWritable()
  await writable.write(blob)
  await writable.close()
}

function triggerBrowserDownload(blob: Blob, fileName: string): void {
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = fileName
  anchor.style.display = 'none'
  document.body.appendChild(anchor)
  anchor.click()
  document.body.removeChild(anchor)
  URL.revokeObjectURL(url)
}

async function downloadAsZipFolder(
  folderName: string,
  files: Array<{ fileName: string; blob: Blob }>,
  onProgress?: (p: ShipmentDownloadProgress) => void,
  totalCount: number = 0,
): Promise<void> {
  const zip = new JSZip()
  const folder = zip.folder(folderName)
  if (!folder) {
    throw new Error('Could not create download folder')
  }

  for (const file of files) {
    folder.file(file.fileName, file.blob)
  }

  onProgress?.({ phase: 'zipping', current: totalCount, total: totalCount })
  const zipBlob = await zip.generateAsync({ type: 'blob' })
  triggerBrowserDownload(zipBlob, `${folderName}.zip`)
}

export async function downloadShipmentImagesToDevice(
  tenantId: number,
  shipmentId: number,
  options?: ShipmentDownloadOptions,
): Promise<ShipmentImageDownloadResult> {
  const signal = options?.signal
  if (signal?.aborted) throw new ShipmentDownloadCancelledError()

  options?.onProgress?.({ phase: 'listing', current: 0, total: 0 })
  const images = await listShipmentImages(tenantId, shipmentId)
  const folderName = buildShipmentFolderName(shipmentId)

  if (images.length === 0) {
    options?.onProgress?.({ phase: 'done', current: 0, total: 0 })
    return {
      downloaded: 0,
      failed: 0,
      total: 0,
      errors: [],
      folderName,
      message: 'No images found for this shipment',
    }
  }

  if (signal?.aborted) throw new ShipmentDownloadCancelledError()

  const useDirectoryPicker = supportsDirectoryPicker()
  const rootDir = useDirectoryPicker ? await pickDownloadDirectory() : null

  let downloaded = 0
  const errors: ShipmentImageDownloadResult['errors'] = []
  const zipFiles: Array<{ fileName: string; blob: Blob }> = []

  options?.onProgress?.({ phase: 'downloading', current: 0, total: images.length })

  let i = 0
  for (const row of images) {
    if (signal?.aborted) throw new ShipmentDownloadCancelledError()
    options?.onProgress?.({
      phase: 'downloading',
      current: i,
      total: images.length,
      currentBarcode: row.barcode || `ID: ${row.stockId}`,
    })

    if (!isAllowedCloudinaryUrl(row.imageUrl)) {
      errors.push({
        stockId: row.stockId,
        barcode: row.barcode,
        message: 'Image URL is not a Cloudinary URL',
      })
      i++
      continue
    }

    try {
      const blob = await fetchImageBlob(row.imageUrl, signal)
      const fileName = buildImageFileName(row.barcode, row.stockId)

      if (rootDir) {
        await writeBlobToDirectory(rootDir, folderName, fileName, blob)
      } else {
        zipFiles.push({ fileName, blob })
      }

      downloaded += 1
    } catch (err) {
      if (err instanceof DOMException && err.name === 'AbortError') {
        throw new ShipmentDownloadCancelledError()
      }
      errors.push({
        stockId: row.stockId,
        barcode: row.barcode,
        message: err instanceof Error ? err.message : 'Download failed',
      })
    }
    i++
  }

  if (signal?.aborted) throw new ShipmentDownloadCancelledError()

  if (!rootDir && zipFiles.length > 0) {
    await downloadAsZipFolder(folderName, zipFiles, options?.onProgress, images.length)
  }

  options?.onProgress?.({ phase: 'done', current: downloaded, total: images.length })

  return {
    downloaded,
    failed: errors.length,
    total: images.length,
    errors,
    folderName,
    message:
      downloaded === images.length
        ? rootDir
          ? `Saved ${downloaded} image(s) to folder "${folderName}"`
          : `Downloaded ${downloaded} image(s) as ${folderName}.zip`
        : `Downloaded ${downloaded} of ${images.length} image(s)`,
  }
}
