import { supabase } from 'src/boot/supabase';

export type DriveUploadResult = {
  fileId: string;
  directLink: string;
  webViewLink?: string | undefined;
};

export function isDriveUploadEnabled(): boolean {
  const flag = import.meta.env.VITE_GOOGLE_DRIVE_UPLOAD_ENABLED;

  return String(flag).toLowerCase() === 'true';
}

export function getDefaultThriftDriveFolder(): string {
  return import.meta.env.VITE_GOOGLE_DRIVE_THRIFT_FOLDER || 'thrift';
}

export function buildThriftShipmentDriveFolderPath(shipmentId: number): string {
  const baseFolder = getDefaultThriftDriveFolder();
  return `${baseFolder}/shipment-${shipmentId}`;
}

export async function uploadToDrive(
  blob: Blob,
  fileName: string,
  folderPath: string,
): Promise<DriveUploadResult> {
  const formData = new FormData();
  formData.append('file', blob, fileName);
  formData.append('fileName', fileName);
  formData.append('folderPath', folderPath);

  const { data, error } = await supabase.functions.invoke('drive-upload', {
    body: formData,
  });

  if (error) {
    throw new Error(error.message || 'Drive upload failed');
  }

  const payload = data as {
    error?: string;
    details?: string;
    fileId?: string;
    directLink?: string;
    webViewLink?: string;
  };

  if (payload?.error) {
    throw new Error(payload.details || payload.error);
  }

  if (!payload?.fileId || !payload?.directLink) {
    throw new Error('Drive upload returned an invalid response');
  }

  return {
    fileId: payload.fileId,
    directLink: payload.directLink,
    ...(payload.webViewLink ? { webViewLink: payload.webViewLink } : {}),
  };
}

export type DriveSyncShipmentResult = {
  synced: number;
  failed: number;
  total: number;
  errors: Array<{ stockId: number; barcode: string; message: string }>;
  message?: string;
  folderPath?: string;
};

export async function syncShipmentToDrive(
  tenantId: number,
  shipmentId: number,
): Promise<DriveSyncShipmentResult> {
  const { data, error } = await supabase.functions.invoke('drive-sync-shipment', {
    body: { tenantId, shipmentId },
  });

  if (error) {
    throw new Error(error.message || 'Drive sync failed');
  }

  const payload = data as DriveSyncShipmentResult & { error?: string; details?: string };

  if (payload?.error) {
    throw new Error(payload.details || payload.error);
  }

  return payload;
}

export async function deleteDriveFile(fileId: string): Promise<void> {
  if (!fileId?.trim()) return;

  try {
    const { data, error } = await supabase.functions.invoke('drive-delete', {
      body: { fileId },
    });

    if (error) {
      console.warn('Failed to delete Drive image:', error.message);
      return;
    }

    const payload = data as { error?: string; details?: string };
    if (payload?.error) {
      console.warn('Failed to delete Drive image:', payload.details || payload.error);
    }
  } catch (err) {
    console.error('Error invoking drive-delete function:', err);
  }
}
