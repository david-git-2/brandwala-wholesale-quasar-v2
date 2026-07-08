import { supabase } from 'src/boot/supabase';
import { GoogleDriveAuthRequiredError } from './googleDriveAuth';
import { buildThriftShipmentDriveFolderPath, type DriveSyncShipmentResult } from './driveClient';
import { uploadToPersonalDrive } from './personalDriveClient';

type PendingStockImage = {
  stockId: number;
  barcode: string;
  imageId: number;
  imageUrl: string;
};

type StockImageRow = {
  id: number;
  image_url: string;
  drive_file_id: string | null;
  is_primary: boolean;
};

type StockRow = {
  id: number;
  barcode: string;
  thrift_stock_images: StockImageRow[] | null;
};

function buildDriveFileName(barcode: string, stockId: number): string {
  const safe = barcode.trim().replace(/[^\w.-]+/g, '_');
  const base = safe || `stock-${stockId}`;
  return base.toLowerCase().endsWith('.jpg') || base.toLowerCase().endsWith('.jpeg')
    ? base
    : `${base}.jpg`;
}

function isAllowedCloudinaryUrl(imageUrl: string): boolean {
  try {
    const parsed = new URL(imageUrl.trim());
    return parsed.hostname === 'res.cloudinary.com' || parsed.hostname.endsWith('.cloudinary.com');
  } catch {
    return false;
  }
}

async function listPendingShipmentImages(
  tenantId: number,
  shipmentId: number,
): Promise<PendingStockImage[]> {
  const { data, error } = await supabase
    .from('thrift_stocks')
    .select(
      `
      id,
      barcode,
      thrift_stock_images (
        id,
        image_url,
        drive_file_id,
        is_primary
      )
    `,
    )
    .eq('tenant_id', tenantId)
    .eq('shipment_id', shipmentId);

  if (error) throw error;

  const rows: PendingStockImage[] = [];

  for (const stock of (data || []) as StockRow[]) {
    const images = stock.thrift_stock_images;
    const primary = images?.find((img) => img.is_primary) || images?.[0];
    const imageUrl = primary?.image_url?.trim();

    if (!primary?.id || !imageUrl || primary.drive_file_id) continue;

    rows.push({
      stockId: stock.id,
      barcode: stock.barcode?.trim() || '',
      imageId: primary.id,
      imageUrl,
    });
  }

  return rows;
}

export async function syncShipmentToDriveFromSession(
  tenantId: number,
  shipmentId: number,
): Promise<DriveSyncShipmentResult> {
  const pending = await listPendingShipmentImages(tenantId, shipmentId);
  const folderPath = buildThriftShipmentDriveFolderPath(shipmentId);

  if (pending.length === 0) {
    return {
      synced: 0,
      failed: 0,
      total: 0,
      errors: [],
      message: 'No images pending Drive sync for this shipment',
      folderPath,
    };
  }

  let synced = 0;
  const errors: DriveSyncShipmentResult['errors'] = [];

  for (const row of pending) {
    if (!isAllowedCloudinaryUrl(row.imageUrl)) {
      errors.push({
        stockId: row.stockId,
        barcode: row.barcode,
        message: 'Image URL is not a Cloudinary URL',
      });
      continue;
    }

    try {
      const imageResponse = await fetch(row.imageUrl);
      if (!imageResponse.ok) {
        throw new Error(`Failed to download image (${imageResponse.status})`);
      }

      const blob = await imageResponse.blob();
      const fileName = buildDriveFileName(row.barcode, row.stockId);
      const uploaded = await uploadToPersonalDrive(blob, fileName, folderPath);

      const { error: updateError } = await supabase
        .from('thrift_stock_images')
        .update({ drive_file_id: uploaded.fileId })
        .eq('id', row.imageId)
        .eq('stock_id', row.stockId)
        .is('drive_file_id', null);

      if (updateError) {
        throw new Error(updateError.message || 'Failed to save drive_file_id');
      }

      synced += 1;
    } catch (err) {
      if (err instanceof GoogleDriveAuthRequiredError) {
        throw err;
      }

      errors.push({
        stockId: row.stockId,
        barcode: row.barcode,
        message: err instanceof Error ? err.message : 'Sync failed',
      });
    }
  }

  return {
    synced,
    failed: errors.length,
    total: pending.length,
    errors,
    folderPath,
    message:
      synced === pending.length
        ? `Synced ${synced} image(s) to Google Drive`
        : `Synced ${synced} of ${pending.length} image(s)`,
  };
}
