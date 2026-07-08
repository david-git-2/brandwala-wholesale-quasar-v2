const SHIPMENT_FOLDER_PATTERN = /^shipment-\d+$/;

export function getThriftDriveBaseFolder(): string {
  return (
    import.meta.env.VITE_GOOGLE_DRIVE_THRIFT_FOLDER ||
    process.env.VITE_GOOGLE_DRIVE_THRIFT_FOLDER ||
    'thrift'
  );
}

export function parseThriftDriveFolderPath(folderPath: string): string[] | null {
  const baseFolder = getThriftDriveBaseFolder();
  const segments = folderPath
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean);

  if (segments.length === 0) return null;
  if (segments[0] !== baseFolder) return null;

  if (segments.length === 1) return segments;

  if (segments.length === 2 && SHIPMENT_FOLDER_PATTERN.test(segments[1]!)) {
    return segments;
  }

  return null;
}
