export type ExcelImageExtension = 'jpeg' | 'png' | 'gif';

export type ExcelEmbeddedImage = {
  buffer: ArrayBuffer;
  extension: ExcelImageExtension;
  width: number;
  height: number;
};

export const EXCEL_IMAGE_HEIGHT_INCHES = 0.95;
export const EXCEL_IMAGE_HEIGHT_PX = Math.round(EXCEL_IMAGE_HEIGHT_INCHES * 96);
export const EXCEL_IMAGE_ROW_HEIGHT_PT = 100;

const getDriveFileId = (url: string) => {
  const byQuery = url.match(/[?&]id=([^&]+)/);
  const byPath = url.match(/\/file\/d\/([^/]+)/);
  return byQuery?.[1] || byPath?.[1] || null;
};

const toDirectGoogleImageUrl = (url: string) => {
  const fileId = getDriveFileId(url);
  if (!fileId) return url;
  return `https://lh3.googleusercontent.com/d/${fileId}`;
};

const toProxyImageUrl = (url: string) => {
  const trimmed = url.trim();
  if (!trimmed || trimmed.startsWith('data:')) return trimmed;

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return trimmed;
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    return trimmed;
  }

  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined;
  if (!supabaseUrl) return trimmed;

  return `${supabaseUrl}/functions/v1/image-proxy?url=${encodeURIComponent(trimmed)}`;
};

const resolveExcelImageFetchUrls = (url: string | null | undefined): string[] => {
  if (!url?.trim()) return [];

  const original = url.trim();
  const direct = toDirectGoogleImageUrl(original);
  const proxied = toProxyImageUrl(direct || original);

  return [...new Set([proxied, direct, original].filter(Boolean))];
};

const getImageExtension = (blob: Blob, url: string): ExcelImageExtension => {
  if (blob.type.includes('png')) return 'png';
  if (blob.type.includes('gif')) return 'gif';
  if (/\.png(\?|$)/i.test(url)) return 'png';
  if (/\.gif(\?|$)/i.test(url)) return 'gif';
  return 'jpeg';
};

const loadImageDimensions = (blob: Blob): Promise<{ width: number; height: number }> =>
  new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(blob);
    const img = new Image();

    img.onload = () => {
      resolve({ width: img.naturalWidth, height: img.naturalHeight });
      URL.revokeObjectURL(objectUrl);
    };

    img.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error('Failed to load image dimensions'));
    };

    img.src = objectUrl;
  });

export const getExcelImageWidthPx = (naturalWidth: number, naturalHeight: number) => {
  if (!naturalWidth || !naturalHeight) return EXCEL_IMAGE_HEIGHT_PX;
  return (naturalWidth / naturalHeight) * EXCEL_IMAGE_HEIGHT_PX;
};

const EXCEL_EMU_PER_PIXEL = 9525;
const CELL_IMAGE_PAD_PX = 8;

/** Excel column width (character units) → interior width in px (Calibri 11). */
export const excelColumnWidthCharsToPixels = (width: number) =>
  Math.max(0, Math.round(width * 7 + 5));

export const excelRowHeightPtToPixels = (heightPt: number) => heightPt * (96 / 72);

export type CenteredExcelWorksheetImageAnchor = {
  col: number;
  /** 0-based row index */
  row: number;
  columnWidthChars: number;
  rowHeightPt: number;
  imageWidthPx: number;
  imageHeightPx: number;
};

/** Place image centered in a single cell (row height must match rowHeightPt). */
export function addCenteredWorksheetImage(
  worksheet: {
    addImage: (imageId: number, range: object) => void;
    getRow: (rowNumber: number) => { height?: number };
  },
  imageId: number,
  anchor: CenteredExcelWorksheetImageAnchor,
): void {
  worksheet.getRow(anchor.row + 1).height = anchor.rowHeightPt;

  const cellWidthPx = excelColumnWidthCharsToPixels(anchor.columnWidthChars);
  const cellHeightPx = excelRowHeightPtToPixels(anchor.rowHeightPt);
  const maxWidthPx = Math.max(1, cellWidthPx - CELL_IMAGE_PAD_PX * 2);
  const maxHeightPx = Math.max(1, cellHeightPx - CELL_IMAGE_PAD_PX * 2);
  const scale = Math.min(
    1,
    maxWidthPx / Math.max(1, anchor.imageWidthPx),
    maxHeightPx / Math.max(1, anchor.imageHeightPx),
  );
  const imageWidthPx = anchor.imageWidthPx * scale;
  const imageHeightPx = anchor.imageHeightPx * scale;
  const colOffEmu = Math.round(Math.max(0, (cellWidthPx - imageWidthPx) / 2) * EXCEL_EMU_PER_PIXEL);
  const rowOffEmu = Math.round(
    Math.max(0, (cellHeightPx - imageHeightPx) / 2) * EXCEL_EMU_PER_PIXEL,
  );

  // ExcelJS ignores tl.colOff / tl.rowOff; native* offsets are EMUs Excel actually uses.
  worksheet.addImage(imageId, {
    tl: {
      nativeCol: anchor.col,
      nativeColOff: colOffEmu,
      nativeRow: anchor.row,
      nativeRowOff: rowOffEmu,
    },
    ext: { width: imageWidthPx, height: imageHeightPx },
    editAs: 'oneCell',
  });
}

export const pixelsToExcelColumnWidth = (px: number) => Math.max(10, px / 7 + 2);

export async function fetchImageForExcel(
  imageUrl: string | null | undefined,
): Promise<ExcelEmbeddedImage | null> {
  const candidates = resolveExcelImageFetchUrls(imageUrl);

  for (const candidate of candidates) {
    try {
      const response = await fetch(candidate, { referrerPolicy: 'no-referrer' });
      if (!response.ok) continue;

      const blob = await response.blob();
      if (!blob.size) continue;

      const { width, height } = await loadImageDimensions(blob);
      const buffer = await blob.arrayBuffer();

      return {
        buffer,
        extension: getImageExtension(blob, candidate),
        width,
        height,
      };
    } catch {
      continue;
    }
  }

  return null;
}
