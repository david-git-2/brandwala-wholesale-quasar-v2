import { supabase } from 'src/boot/supabase';
import {
  buildThriftShipmentCloudinaryUploadTarget,
  buildThriftStockImageFileName,
  deleteCloudinaryImage,
  deleteCloudinaryImageStrict,
  uploadToCloudinary,
} from './cloudinaryClient';

export type StockImageUploadResult = {
  secureUrl: string;
  deleteToken?: string | undefined;
};

export class StockImageDuplicateError extends Error {
  constructor(barcode: string) {
    super(`An image already exists for barcode ${barcode}. Replace the existing image instead.`);
    this.name = 'StockImageDuplicateError';
  }
}

export type StockImageUploadOptions = {
  barcode: string;
  tenantId?: number;
  stockId?: number;
  shipmentId?: number;
  replaceImageUrl?: string | null;
  cloudinaryFolder?: string;
};

async function assertNoDuplicateStockImage(params: {
  tenantId: number;
  shipmentId: number;
  barcode: string;
  excludeStockId?: number;
}): Promise<void> {
  const normalizedBarcode = params.barcode.trim();
  if (!normalizedBarcode) return;

  let query = supabase
    .from('thrift_stocks')
    .select(
      `
      id,
      thrift_stock_images!inner (
        id,
        image_url
      )
    `,
    )
    .eq('tenant_id', params.tenantId)
    .eq('shipment_id', params.shipmentId)
    .eq('barcode', normalizedBarcode)
    .not('thrift_stock_images.image_url', 'is', null);

  if (params.excludeStockId) {
    query = query.neq('id', params.excludeStockId);
  }

  const { data, error } = await query.limit(1);
  if (error) throw error;

  if ((data || []).length > 0) {
    throw new StockImageDuplicateError(normalizedBarcode);
  }
}

export async function uploadStockImage(
  blob: Blob,
  options: StockImageUploadOptions,
): Promise<StockImageUploadResult> {
  const barcode = options.barcode?.trim();
  if (!barcode) {
    throw new Error('Barcode is required for stock image upload.');
  }

  const replaceImageUrl = options.replaceImageUrl?.trim() || '';
  const isReplace = Boolean(replaceImageUrl);

  if (!isReplace && options.tenantId && options.shipmentId) {
    await assertNoDuplicateStockImage({
      tenantId: options.tenantId,
      shipmentId: options.shipmentId,
      barcode,
      ...(options.stockId ? { excludeStockId: options.stockId } : {}),
    });
  }

  const fileName = buildThriftStockImageFileName(barcode);

  if (!options.shipmentId || options.shipmentId <= 0) {
    throw new Error('Shipment is required to upload a stock image.');
  }

  const uploadTarget = buildThriftShipmentCloudinaryUploadTarget(
    options.shipmentId,
    barcode,
    ...(options.cloudinaryFolder ? [options.cloudinaryFolder] : []),
  );

  if (isReplace) {
    await cleanupStockImageAssets({ imageUrl: replaceImageUrl });
  }

  const cloudinaryResult = await uploadToCloudinary(blob, fileName, uploadTarget.shipmentFolder, {
    publicId: uploadTarget.publicId,
    shipmentFolder: uploadTarget.shipmentFolder,
    assetFolder: uploadTarget.shipmentFolder,
  });

  return {
    secureUrl: cloudinaryResult.secureUrl,
    ...(cloudinaryResult.deleteToken ? { deleteToken: cloudinaryResult.deleteToken } : {}),
  };
}

export async function cleanupStockImageAssets(payload: {
  imageUrl?: string | undefined;
}): Promise<void> {
  if (!payload.imageUrl) return;
  await deleteCloudinaryImage(payload.imageUrl);
}

/** Delete Cloudinary image first; throws if delete fails. Skips when no Cloudinary URL. */
export async function deleteStockCloudinaryImageStrict(imageUrl?: string): Promise<void> {
  const trimmed = imageUrl?.trim();
  if (!trimmed) return;
  await deleteCloudinaryImageStrict(trimmed);
}
