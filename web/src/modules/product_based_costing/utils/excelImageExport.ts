export type ExcelImageExtension = 'jpeg' | 'png' | 'gif'

export type ExcelEmbeddedImage = {
  buffer: ArrayBuffer
  extension: ExcelImageExtension
  width: number
  height: number
}

export const EXCEL_IMAGE_HEIGHT_INCHES = 0.95
export const EXCEL_IMAGE_HEIGHT_PX = Math.round(EXCEL_IMAGE_HEIGHT_INCHES * 96)
export const EXCEL_IMAGE_ROW_HEIGHT_PT = 100

const getDriveFileId = (url: string) => {
  const byQuery = url.match(/[?&]id=([^&]+)/)
  const byPath = url.match(/\/file\/d\/([^/]+)/)
  return byQuery?.[1] || byPath?.[1] || null
}

const toDirectGoogleImageUrl = (url: string) => {
  const fileId = getDriveFileId(url)
  if (!fileId) return url
  return `https://lh3.googleusercontent.com/d/${fileId}`
}

const toProxyImageUrl = (url: string) => {
  const trimmed = url.trim()
  if (!trimmed || trimmed.startsWith('data:')) return trimmed

  let parsed: URL
  try {
    parsed = new URL(trimmed)
  } catch {
    return trimmed
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    return trimmed
  }

  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined
  if (!supabaseUrl) return trimmed

  return `${supabaseUrl}/functions/v1/image-proxy?url=${encodeURIComponent(trimmed)}`
}

const resolveExcelImageFetchUrls = (url: string | null | undefined): string[] => {
  if (!url?.trim()) return []

  const original = url.trim()
  const direct = toDirectGoogleImageUrl(original)
  const proxied = toProxyImageUrl(direct || original)

  return [...new Set([proxied, direct, original].filter(Boolean))]
}

const getImageExtension = (blob: Blob, url: string): ExcelImageExtension => {
  if (blob.type.includes('png')) return 'png'
  if (blob.type.includes('gif')) return 'gif'
  if (/\.png(\?|$)/i.test(url)) return 'png'
  if (/\.gif(\?|$)/i.test(url)) return 'gif'
  return 'jpeg'
}

const loadImageDimensions = (blob: Blob): Promise<{ width: number; height: number }> =>
  new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(blob)
    const img = new Image()

    img.onload = () => {
      resolve({ width: img.naturalWidth, height: img.naturalHeight })
      URL.revokeObjectURL(objectUrl)
    }

    img.onerror = () => {
      URL.revokeObjectURL(objectUrl)
      reject(new Error('Failed to load image dimensions'))
    }

    img.src = objectUrl
  })

export const getExcelImageWidthPx = (naturalWidth: number, naturalHeight: number) => {
  if (!naturalWidth || !naturalHeight) return EXCEL_IMAGE_HEIGHT_PX
  return (naturalWidth / naturalHeight) * EXCEL_IMAGE_HEIGHT_PX
}

export const pixelsToExcelColumnWidth = (px: number) => Math.max(10, px / 7 + 2)

export async function fetchImageForExcel(
  imageUrl: string | null | undefined,
): Promise<ExcelEmbeddedImage | null> {
  const candidates = resolveExcelImageFetchUrls(imageUrl)

  for (const candidate of candidates) {
    try {
      const response = await fetch(candidate, { referrerPolicy: 'no-referrer' })
      if (!response.ok) continue

      const blob = await response.blob()
      if (!blob.size) continue

      const { width, height } = await loadImageDimensions(blob)
      const buffer = await blob.arrayBuffer()

      return {
        buffer,
        extension: getImageExtension(blob, candidate),
        width,
        height,
      }
    } catch {
      continue
    }
  }

  return null
}
