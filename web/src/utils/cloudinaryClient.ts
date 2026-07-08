import { supabase } from 'src/boot/supabase';

export type CloudinaryUploadResult = { secureUrl: string; deleteToken?: string | undefined };

const THRIFT_FOLDER_PREFIXES = ['thrift-inventory-images/', 'thrift_stocks/', 'thrift-stocks/'];

export function getThriftCloudinaryRootFolder(): string {
  const configured =
    import.meta.env.VITE_CLOUDINARY_THRIFT_FOLDER || process.env.VITE_CLOUDINARY_THRIFT_FOLDER;
  const root = (configured as string | undefined)?.trim() || 'thrift-inventory-images';
  return root.replace(/^\/+|\/+$/g, '');
}

export const DEFAULT_THRIFT_CLOUDINARY_FOLDER = getThriftCloudinaryRootFolder();

export function buildThriftShipmentCloudinaryFolder(
  shipmentId: number,
  baseFolder = getThriftCloudinaryRootFolder(),
): string {
  return `${baseFolder}/shipment-${shipmentId}`;
}

export function resolveThriftCloudinaryFolder(options?: {
  shipmentId?: number | null;
  folder?: string;
}): string {
  const base = options?.folder?.trim() || getThriftCloudinaryRootFolder();
  if (options?.shipmentId && options.shipmentId > 0) {
    return buildThriftShipmentCloudinaryFolder(options.shipmentId, base);
  }
  return base;
}

export function buildThriftStockImageFileName(barcode: string): string {
  const safe = barcode.trim().replace(/[^\w.-]+/g, '_');
  const base = safe || 'stock-image';
  return base.toLowerCase().endsWith('.jpg') || base.toLowerCase().endsWith('.jpeg')
    ? base
    : `${base}.jpg`;
}

export function buildThriftStockImagePublicId(barcode: string): string {
  return buildThriftStockImageFileName(barcode).replace(/\.(jpe?g)$/i, '');
}

export function buildThriftShipmentCloudinarySubfolder(shipmentId: number): string {
  return `shipment-${shipmentId}`;
}

export function buildThriftStockCloudinaryPublicId(barcode: string, shipmentId: number): string {
  const imageId = buildThriftStockImagePublicId(barcode);
  return `${buildThriftShipmentCloudinarySubfolder(shipmentId)}/${imageId}`;
}

export function buildThriftShipmentCloudinaryUploadTarget(
  shipmentId: number,
  barcode: string,
  baseFolder = getThriftCloudinaryRootFolder(),
): {
  publicId: string;
  shipmentFolder: string;
} {
  const shipmentSegment = buildThriftShipmentCloudinarySubfolder(shipmentId);
  const imageId = buildThriftStockImagePublicId(barcode);

  return {
    publicId: imageId,
    shipmentFolder: `${baseFolder}/${shipmentSegment}`,
  };
}

export type CloudinaryUploadOptions = {
  publicId?: string;
  publicIdPrefix?: string;
  assetFolder?: string;
  shipmentFolder?: string;
};

function getCloudinaryConfig() {
  const cloudName =
    import.meta.env.VITE_CLOUDINARY_CLOUD_NAME || process.env.VITE_CLOUDINARY_CLOUD_NAME;
  const uploadPreset =
    import.meta.env.VITE_CLOUDINARY_UPLOAD_PRESET || process.env.VITE_CLOUDINARY_UPLOAD_PRESET;

  return { cloudName, uploadPreset };
}

function resizeImage(
  fileOrBlob: File | Blob,
  maxWidth = 1200,
  maxHeight = 1200,
  quality = 0.85,
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(fileOrBlob);
    reader.onload = (event) => {
      const img = new Image();
      img.src = event.target?.result as string;
      img.onload = () => {
        let width = img.width;
        let height = img.height;

        if (width > height) {
          if (width > maxWidth) {
            height = Math.round((height * maxWidth) / width);
            width = maxWidth;
          }
        } else if (height > maxHeight) {
          width = Math.round((width * maxHeight) / height);
          height = maxHeight;
        }

        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;

        const ctx = canvas.getContext('2d');
        if (!ctx) {
          reject(new Error('Failed to get 2D context'));
          return;
        }

        ctx.drawImage(img, 0, 0, width, height);
        canvas.toBlob(
          (blob) => {
            if (blob) resolve(blob);
            else reject(new Error('Canvas toBlob failed'));
          },
          'image/jpeg',
          quality,
        );
      };
      img.onerror = () => reject(new Error('Failed to load image into object'));
    };
    reader.onerror = () => reject(new Error('Failed to read file source'));
  });
}

export function isCloudinaryThriftUrl(url: string): boolean {
  const trimmed = url.trim();
  if (!trimmed) return false;

  try {
    const parsed = new URL(trimmed);
    if (parsed.hostname !== 'res.cloudinary.com') return false;
    const path = decodeURIComponent(parsed.pathname);
    return (
      THRIFT_FOLDER_PREFIXES.some((prefix) => path.includes(`/${prefix}`)) ||
      /\/shipment-\d+\//.test(path)
    );
  } catch {
    return false;
  }
}

export async function uploadToCloudinary(
  blob: Blob,
  name: string,
  folder = DEFAULT_THRIFT_CLOUDINARY_FOLDER,
  options?: CloudinaryUploadOptions,
): Promise<CloudinaryUploadResult> {
  const { cloudName, uploadPreset } = getCloudinaryConfig();

  if (!cloudName || !uploadPreset) {
    throw new Error('Cloudinary environment configuration missing.');
  }

  let imageToUpload = blob;
  try {
    imageToUpload = await resizeImage(blob);
  } catch (err) {
    console.warn('Resize failed, uploading original blob instead', err);
  }

  const url = `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`;
  const formData = new FormData();
  formData.append('file', imageToUpload, name);
  formData.append('upload_preset', uploadPreset);
  const shipmentFolder =
    options?.shipmentFolder?.trim() || options?.assetFolder?.trim() || folder?.trim();
  if (shipmentFolder) {
    formData.append('folder', shipmentFolder);
    formData.append('asset_folder', shipmentFolder);
  }
  if (options?.publicIdPrefix?.trim()) {
    formData.append('public_id_prefix', options.publicIdPrefix.trim());
  }
  if (options?.publicId?.trim()) {
    formData.append('public_id', options.publicId.trim());
  }

  const response = await fetch(url, {
    method: 'POST',
    body: formData,
  });

  if (!response.ok) {
    const errObj = await response.json();
    throw new Error(errObj.error?.message || 'Upload HTTP request failed');
  }

  const resData = await response.json();
  return {
    secureUrl: resData.secure_url as string,
    deleteToken: resData.delete_token as string | undefined,
  };
}

export async function deleteCloudinaryByToken(deleteToken: string): Promise<void> {
  if (!deleteToken) return;

  const { cloudName } = getCloudinaryConfig();
  if (!cloudName) return;

  try {
    const response = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/delete_by_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: deleteToken }),
    });
    if (!response.ok) {
      console.warn('Failed to delete image using delete token:', await response.text());
    }
  } catch (err) {
    console.error('Error deleting Cloudinary image by token:', err);
  }
}

export async function deleteCloudinaryImage(imageUrl: string): Promise<void> {
  if (!imageUrl || !isCloudinaryThriftUrl(imageUrl)) return;

  try {
    const { error } = await supabase.functions.invoke('cloudinary-delete', {
      body: { imageUrl },
    });
    if (error) {
      console.warn('Failed to delete Cloudinary image:', error.message);
    }
  } catch (err) {
    console.error('Error invoking cloudinary-delete function:', err);
  }
}

export async function deleteCloudinaryImageStrict(imageUrl: string): Promise<void> {
  const trimmed = imageUrl.trim();
  if (!trimmed) return;

  if (!isCloudinaryThriftUrl(trimmed)) {
    throw new Error('Cannot delete image: not a valid Cloudinary thrift image URL.');
  }

  const { data, error } = await supabase.functions.invoke('cloudinary-delete', {
    body: { imageUrl: trimmed },
  });

  const payload = (data ?? {}) as { error?: string; details?: string; publicId?: string };
  if (error || payload.error) {
    const message =
      payload.details?.trim() ||
      payload.error?.trim() ||
      error?.message ||
      'Cloudinary image delete failed';
    throw new Error(message);
  }
}
