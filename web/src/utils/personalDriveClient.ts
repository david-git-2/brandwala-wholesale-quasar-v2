import type { DriveUploadResult } from './driveClient';
import { getGoogleDriveAccessToken, throwIfGoogleDrivePermissionDenied } from './googleDriveAuth';
import { parseThriftDriveFolderPath } from './googleDrivePath';

const DRIVE_API = 'https://www.googleapis.com/drive/v3';
const DRIVE_UPLOAD_API = 'https://www.googleapis.com/upload/drive/v3/files';
const DRIVE_ROOT_STORAGE_KEY = 'tradeflow_drive_app_root_folder_id';

function getConfiguredRootFolderId(): string | null {
  const folderId = (
    import.meta.env.VITE_GOOGLE_DRIVE_ROOT_FOLDER_ID || process.env.VITE_GOOGLE_DRIVE_ROOT_FOLDER_ID
  )?.trim();

  return folderId || null;
}

function getAppRootFolderName(): string {
  const configured =
    import.meta.env.VITE_GOOGLE_DRIVE_ROOT_FOLDER_NAME ||
    process.env.VITE_GOOGLE_DRIVE_ROOT_FOLDER_NAME;

  return (configured || 'TradeFlow Uploads').trim();
}

function readCachedRootFolderId(): string | null {
  if (typeof window === 'undefined') return null;
  return window.localStorage.getItem(DRIVE_ROOT_STORAGE_KEY)?.trim() || null;
}

function cacheRootFolderId(folderId: string): void {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(DRIVE_ROOT_STORAGE_KEY, folderId);
}

function clearCachedRootFolderId(): void {
  if (typeof window === 'undefined') return;
  window.localStorage.removeItem(DRIVE_ROOT_STORAGE_KEY);
}

async function driveFetch(accessToken: string, url: string, init?: RequestInit): Promise<Response> {
  return fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...(init?.headers || {}),
    },
  });
}

async function listChildFolderByName(
  accessToken: string,
  parentId: string,
  name: string,
): Promise<string | null> {
  const query = [
    "mimeType = 'application/vnd.google-apps.folder'",
    'trashed = false',
    `name = '${name.replace(/'/g, "\\'")}'`,
    `'${parentId}' in parents`,
  ].join(' and ');

  const response = await driveFetch(
    accessToken,
    `${DRIVE_API}/files?${new URLSearchParams({
      q: query,
      fields: 'files(id)',
      pageSize: '1',
    })}`,
  );

  if (!response.ok) {
    const body = await response.text();
    throwIfGoogleDrivePermissionDenied(
      response.status,
      body,
      'Google Drive permission denied while looking up folders',
    );
    throw new Error(`Drive folder lookup failed: ${body}`);
  }

  const payload = (await response.json()) as { files?: Array<{ id?: string }> };
  return payload.files?.[0]?.id || null;
}

async function verifyFolderAccess(accessToken: string, folderId: string): Promise<boolean> {
  const response = await driveFetch(
    accessToken,
    `${DRIVE_API}/files/${encodeURIComponent(folderId)}?${new URLSearchParams({
      fields: 'id',
    })}`,
  );

  if (response.ok) return true;

  const body = await response.text();
  throwIfGoogleDrivePermissionDenied(
    response.status,
    body,
    'Google Drive permission denied while verifying the backup folder',
  );
  return false;
}

async function findAppRootFolderByName(accessToken: string, name: string): Promise<string | null> {
  const query = [
    "mimeType = 'application/vnd.google-apps.folder'",
    'trashed = false',
    `name = '${name.replace(/'/g, "\\'")}'`,
  ].join(' and ');

  const response = await driveFetch(
    accessToken,
    `${DRIVE_API}/files?${new URLSearchParams({
      q: query,
      fields: 'files(id)',
      pageSize: '1',
    })}`,
  );

  if (!response.ok) {
    const body = await response.text();
    throwIfGoogleDrivePermissionDenied(
      response.status,
      body,
      'Google Drive permission denied while locating the backup folder',
    );
    throw new Error(`Drive root folder lookup failed: ${body}`);
  }

  const payload = (await response.json()) as { files?: Array<{ id?: string }> };
  return payload.files?.[0]?.id || null;
}

async function createAppRootFolder(accessToken: string, name: string): Promise<string> {
  const response = await driveFetch(accessToken, `${DRIVE_API}/files`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name,
      mimeType: 'application/vnd.google-apps.folder',
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throwIfGoogleDrivePermissionDenied(
      response.status,
      body,
      'Google Drive permission denied while creating the backup folder',
    );
    throw new Error(`Drive root folder create failed: ${body}`);
  }

  const payload = (await response.json()) as { id?: string };
  if (!payload.id) {
    throw new Error('Drive root folder create returned no id');
  }

  return payload.id;
}

async function resolvePersonalRootFolderId(accessToken: string): Promise<string> {
  const cached = readCachedRootFolderId();
  if (cached && (await verifyFolderAccess(accessToken, cached))) {
    return cached;
  }
  clearCachedRootFolderId();

  const configuredId = getConfiguredRootFolderId();
  if (configuredId && (await verifyFolderAccess(accessToken, configuredId))) {
    cacheRootFolderId(configuredId);
    return configuredId;
  }

  const folderName = getAppRootFolderName();
  const existing = await findAppRootFolderByName(accessToken, folderName);
  if (existing) {
    cacheRootFolderId(existing);
    return existing;
  }

  const created = await createAppRootFolder(accessToken, folderName);
  cacheRootFolderId(created);
  return created;
}

async function createChildFolder(
  accessToken: string,
  parentId: string,
  name: string,
): Promise<string> {
  const response = await driveFetch(accessToken, `${DRIVE_API}/files`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parentId],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throwIfGoogleDrivePermissionDenied(
      response.status,
      body,
      'Google Drive permission denied while creating folders',
    );
    throw new Error(`Drive folder create failed: ${body}`);
  }

  const payload = (await response.json()) as { id?: string };
  if (!payload.id) {
    throw new Error('Drive folder create returned no id');
  }

  return payload.id;
}

async function resolveOrCreateNestedPath(
  accessToken: string,
  rootFolderId: string,
  segments: string[],
): Promise<string> {
  let currentFolderId = rootFolderId;

  for (const segment of segments) {
    const existing = await listChildFolderByName(accessToken, currentFolderId, segment);
    currentFolderId = existing || (await createChildFolder(accessToken, currentFolderId, segment));
  }

  return currentFolderId;
}

async function uploadFileToFolder(
  accessToken: string,
  folderId: string,
  fileName: string,
  mimeType: string,
  fileBytes: Uint8Array,
): Promise<{ fileId: string; webViewLink?: string }> {
  const metadata = JSON.stringify({ name: fileName, parents: [folderId] });
  const boundary = `drive_upload_${crypto.randomUUID()}`;
  const encoder = new TextEncoder();

  const prelude = encoder.encode(
    `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n` +
      `--${boundary}\r\nContent-Type: ${mimeType}\r\n\r\n`,
  );
  const closing = encoder.encode(`\r\n--${boundary}--`);

  const body = new Uint8Array(prelude.length + fileBytes.length + closing.length);
  body.set(prelude, 0);
  body.set(fileBytes, prelude.length);
  body.set(closing, prelude.length + fileBytes.length);

  const response = await fetch(
    `${DRIVE_UPLOAD_API}?${new URLSearchParams({
      uploadType: 'multipart',
      fields: 'id,webViewLink',
    })}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': `multipart/related; boundary=${boundary}`,
      },
      body,
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throwIfGoogleDrivePermissionDenied(
      response.status,
      body,
      'Google Drive permission denied while uploading files',
    );
    throw new Error(`Drive upload failed: ${body}`);
  }

  const payload = (await response.json()) as { id?: string; webViewLink?: string };
  if (!payload.id) {
    throw new Error('Drive upload returned no file id');
  }

  return {
    fileId: payload.id,
    ...(payload.webViewLink ? { webViewLink: payload.webViewLink } : {}),
  };
}

export async function uploadToPersonalDrive(
  blob: Blob,
  fileName: string,
  folderPath: string,
): Promise<DriveUploadResult> {
  const segments = parseThriftDriveFolderPath(folderPath);
  if (!segments) {
    throw new Error('Invalid or disallowed folder path');
  }

  const accessToken = await getGoogleDriveAccessToken();
  const rootFolderId = await resolvePersonalRootFolderId(accessToken);
  const targetFolderId = await resolveOrCreateNestedPath(accessToken, rootFolderId, segments);
  const fileBytes = new Uint8Array(await blob.arrayBuffer());
  const mimeType = blob.type || 'image/jpeg';

  const uploaded = await uploadFileToFolder(
    accessToken,
    targetFolderId,
    fileName,
    mimeType,
    fileBytes,
  );

  return {
    fileId: uploaded.fileId,
    directLink: `https://drive.google.com/uc?id=${uploaded.fileId}`,
    ...(uploaded.webViewLink ? { webViewLink: uploaded.webViewLink } : {}),
  };
}
