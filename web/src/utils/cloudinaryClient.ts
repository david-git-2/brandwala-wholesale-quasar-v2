import { supabase } from 'src/boot/supabase'

export type CloudinaryUploadResult = { secureUrl: string; deleteToken?: string | undefined }

const THRIFT_FOLDER_PREFIXES = ['thrift_stocks/', 'thrift-stocks/']

function getCloudinaryConfig() {
  const cloudName =
    import.meta.env.VITE_CLOUDINARY_CLOUD_NAME ||
    process.env.VITE_CLOUDINARY_CLOUD_NAME
  const uploadPreset =
    import.meta.env.VITE_CLOUDINARY_UPLOAD_PRESET ||
    process.env.VITE_CLOUDINARY_UPLOAD_PRESET

  return { cloudName, uploadPreset }
}

function resizeImage(
  fileOrBlob: File | Blob,
  maxWidth = 1200,
  maxHeight = 1200,
  quality = 0.85,
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.readAsDataURL(fileOrBlob)
    reader.onload = (event) => {
      const img = new Image()
      img.src = event.target?.result as string
      img.onload = () => {
        let width = img.width
        let height = img.height

        if (width > height) {
          if (width > maxWidth) {
            height = Math.round((height * maxWidth) / width)
            width = maxWidth
          }
        } else if (height > maxHeight) {
          width = Math.round((width * maxHeight) / height)
          height = maxHeight
        }

        const canvas = document.createElement('canvas')
        canvas.width = width
        canvas.height = height

        const ctx = canvas.getContext('2d')
        if (!ctx) {
          reject(new Error('Failed to get 2D context'))
          return
        }

        ctx.drawImage(img, 0, 0, width, height)
        canvas.toBlob(
          (blob) => {
            if (blob) resolve(blob)
            else reject(new Error('Canvas toBlob failed'))
          },
          'image/jpeg',
          quality,
        )
      }
      img.onerror = () => reject(new Error('Failed to load image into object'))
    }
    reader.onerror = () => reject(new Error('Failed to read file source'))
  })
}

export function isCloudinaryThriftUrl(url: string): boolean {
  const trimmed = url.trim()
  if (!trimmed) return false

  try {
    const parsed = new URL(trimmed)
    if (parsed.hostname !== 'res.cloudinary.com') return false
    const path = decodeURIComponent(parsed.pathname)
    return THRIFT_FOLDER_PREFIXES.some((prefix) => path.includes(`/${prefix}`))
  } catch {
    return false
  }
}

export async function uploadToCloudinary(
  blob: Blob,
  name: string,
  folder = 'thrift-stocks',
): Promise<CloudinaryUploadResult> {
  const { cloudName, uploadPreset } = getCloudinaryConfig()

  if (!cloudName || !uploadPreset) {
    throw new Error('Cloudinary environment configuration missing.')
  }

  let imageToUpload = blob
  try {
    imageToUpload = await resizeImage(blob)
  } catch (err) {
    console.warn('Resize failed, uploading original blob instead', err)
  }

  const url = `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`
  const formData = new FormData()
  formData.append('file', imageToUpload, name)
  formData.append('upload_preset', uploadPreset)
  if (folder) {
    formData.append('folder', folder)
  }

  const response = await fetch(url, {
    method: 'POST',
    body: formData,
  })

  if (!response.ok) {
    const errObj = await response.json()
    throw new Error(errObj.error?.message || 'Upload HTTP request failed')
  }

  const resData = await response.json()
  return {
    secureUrl: resData.secure_url as string,
    deleteToken: resData.delete_token as string | undefined,
  }
}

export async function deleteCloudinaryByToken(deleteToken: string): Promise<void> {
  if (!deleteToken) return

  const { cloudName } = getCloudinaryConfig()
  if (!cloudName) return

  try {
    const response = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/delete_by_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: deleteToken }),
    })
    if (!response.ok) {
      console.warn('Failed to delete image using delete token:', await response.text())
    }
  } catch (err) {
    console.error('Error deleting Cloudinary image by token:', err)
  }
}

export async function deleteCloudinaryImage(imageUrl: string): Promise<void> {
  if (!imageUrl || !isCloudinaryThriftUrl(imageUrl)) return

  try {
    const { error } = await supabase.functions.invoke('cloudinary-delete', {
      body: { imageUrl },
    })
    if (error) {
      console.warn('Failed to delete Cloudinary image:', error.message)
    }
  } catch (err) {
    console.error('Error invoking cloudinary-delete function:', err)
  }
}
