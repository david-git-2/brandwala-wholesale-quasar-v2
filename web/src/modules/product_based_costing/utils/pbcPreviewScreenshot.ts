/** Phone-oriented screenshot frame width (logical px). */
export const SCREENSHOT_FRAME_WIDTH_PX = 390;

export const SCREENSHOT_ROWS_PER_PAGE = 6;

/** Fixed width for serial column in screenshot table (single–double digit rows). */
export const SCREENSHOT_SL_COLUMN_WIDTH_PX = 22;

/** Columns users can pick in screenshot preview (fixed order). */
export const PBC_SCREENSHOT_SELECTABLE_COLUMN_KEYS = [
  'sl',
  'image',
  'name',
  'qty',
  'offerPriceBdt',
  'priceGbp',
  'priceGbpWithVat',
] as const;

/** Default column wish list when opening offer screenshot / preview. */
export const DEFAULT_PBC_PREVIEW_SCREENSHOT_COLUMNS = [
  'sl',
  'image',
  'name',
  'offerPriceBdt',
] as const;

export const PREVIEW_IMAGE_SIZE_INCHES_OPTIONS = [0.75, 1, 1.25] as const;

export type PreviewImageSizeInches = (typeof PREVIEW_IMAGE_SIZE_INCHES_OPTIONS)[number];

export function normalizePreviewImageSizeInches(value: unknown): PreviewImageSizeInches {
  const n = Number(value);
  if (n === 0.75) return 0.75;
  if (n === 1.25) return 1.25;
  return 1;
}

/** Column budget for image cell (size + horizontal padding). */
export function screenshotImageColumnWidthPx(imageSizeInches: number): number {
  return Math.ceil(imageSizeInches * 96) + 8;
}

export const SCREENSHOT_COLUMN_MIN_WIDTH_PX: Record<string, number> = {
  sl: SCREENSHOT_SL_COLUMN_WIDTH_PX,
  name: 72,
  qty: 26,
  priceGbp: 44,
  priceGbpWithVat: 48,
  offerPriceBdt: 52,
  brand: 52,
  note: 48,
  confirmedQty: 44,
  barcodeText: 56,
  website: 40,
  totalPurchasePriceGbp: 52,
  productWeight: 48,
  packageWeight: 48,
  totalWeight: 44,
  cargoRate: 44,
  cargoCostGbp: 48,
  totalCostGbp: 48,
  rowTotalCostGbp: 52,
  costBdt: 52,
  totalCostBdt: 52,
  totalBdt: 52,
  profitPerUnitBdt: 48,
  profitBdt: 48,
  profitRate: 44,
  status: 48,
};

const SCREENSHOT_COLUMN_SHRINK_FLOOR_PX: Record<string, number> = {
  sl: SCREENSHOT_SL_COLUMN_WIDTH_PX,
  name: 36,
  qty: 18,
  priceGbp: 34,
  priceGbpWithVat: 36,
  offerPriceBdt: 40,
};

const DEFAULT_SCREENSHOT_COLUMN_MIN_WIDTH_PX = 44;
const DEFAULT_SCREENSHOT_COLUMN_SHRINK_FLOOR_PX = 26;

function minWidthForKey(key: string, imageSizeInches = 1): number {
  if (key === 'sl') {
    return SCREENSHOT_SL_COLUMN_WIDTH_PX;
  }
  if (key === 'image') {
    return screenshotImageColumnWidthPx(imageSizeInches);
  }
  return SCREENSHOT_COLUMN_MIN_WIDTH_PX[key] ?? DEFAULT_SCREENSHOT_COLUMN_MIN_WIDTH_PX;
}

function shrinkFloorForKey(key: string, imageSizeInches = 1): number {
  if (key === 'image') {
    return Math.max(56, Math.floor(screenshotImageColumnWidthPx(imageSizeInches) * 0.72));
  }
  return SCREENSHOT_COLUMN_SHRINK_FLOOR_PX[key] ?? DEFAULT_SCREENSHOT_COLUMN_SHRINK_FLOOR_PX;
}

export function injectVatColumnIntoWishList(wishList: string[]): string[] {
  const keys = wishList.filter((key) => key !== 'priceGbpWithVat');
  const priceIdx = keys.indexOf('priceGbp');
  if (priceIdx >= 0) {
    return [...keys.slice(0, priceIdx + 1), 'priceGbpWithVat', ...keys.slice(priceIdx + 1)];
  }
  return [...keys, 'priceGbpWithVat'];
}

function dedupePreserveOrder(keys: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const key of keys) {
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(key);
  }
  return out;
}

function filterScreenshotSelectableKeys(wishList: string[]): string[] {
  const allowed = new Set(PBC_SCREENSHOT_SELECTABLE_COLUMN_KEYS);
  return dedupePreserveOrder(
    wishList.filter((key) =>
      allowed.has(key as (typeof PBC_SCREENSHOT_SELECTABLE_COLUMN_KEYS)[number]),
    ),
  );
}

/** Resolve screenshot columns; preserves wishList order (scales widths to fit). */
export function fitScreenshotColumnKeys(
  wishList: string[],
  _budgetPx: number,
  includeVatColumn: boolean,
  _imageSizeInches: number = 1,
): string[] {
  let ordered = filterScreenshotSelectableKeys(wishList);
  if (includeVatColumn) {
    if (ordered.includes('priceGbp') && !ordered.includes('priceGbpWithVat')) {
      const priceIdx = ordered.indexOf('priceGbp');
      ordered = [
        ...ordered.slice(0, priceIdx + 1),
        'priceGbpWithVat',
        ...ordered.slice(priceIdx + 1),
      ];
    }
  } else {
    ordered = ordered.filter((key) => key !== 'priceGbpWithVat');
  }
  return ordered;
}

const SCREENSHOT_SHORT_HEADER_LABELS: Record<string, string> = {
  sl: 'SL',
  qty: 'Qty',
  offerPriceBdt: 'Offer',
  totalBdt: 'Total BDT',
  confirmedQty: 'Conf. qty',
  priceGbp: 'GBP',
  priceGbpWithVat: 'GBP+VAT',
  totalPurchasePriceGbp: 'Tot. buy',
  cargoRate: 'Cargo',
  cargoCostGbp: 'Cargo £',
  productWeight: 'Prod. kg',
  packageWeight: 'Pkg. kg',
  totalWeight: 'Tot. kg',
  profitPerUnitBdt: 'Profit',
  profitBdt: 'Tot. profit',
  profitRate: 'Profit %',
  barcodeText: 'Barcode',
};

export function screenshotHeaderLabel(columnKey: string, fullLabel: string): string {
  return SCREENSHOT_SHORT_HEADER_LABELS[columnKey] ?? fullLabel;
}

/** Pixel widths that sum to budgetPx (extra space goes to name; scales down when needed). */
export function computeFixedBudgetColumnWidthsPx(
  columnKeys: string[],
  budgetPx: number,
  getMinWidth: (key: string) => number,
  getShrinkFloor: (key: string) => number,
  pinSlWidth?: number,
  /** When false and mins fit in budget, use min widths only (no stretch to fill). */
  expandToBudget = true,
): Record<string, number> {
  if (!columnKeys.length) return {};

  const result: Record<string, number> = {};
  let minSum = 0;
  for (const key of columnKeys) {
    const w = getMinWidth(key);
    result[key] = w;
    minSum += w;
  }

  if (minSum <= budgetPx) {
    if (columnKeys.includes('sl') && pinSlWidth != null) {
      result.sl = pinSlWidth;
    }
    if (!expandToBudget) {
      return result;
    }
    const nameKey = columnKeys.includes('name') ? 'name' : columnKeys[columnKeys.length - 1];
    result[nameKey] = (result[nameKey] ?? 0) + (budgetPx - minSum);
    if (columnKeys.includes('sl') && pinSlWidth != null) {
      result.sl = pinSlWidth;
    }
    return result;
  }

  const scale = budgetPx / minSum;
  let assigned = 0;
  for (let i = 0; i < columnKeys.length; i++) {
    const key = columnKeys[i];
    const floor = getShrinkFloor(key);
    const w =
      i === columnKeys.length - 1
        ? budgetPx - assigned
        : Math.max(floor, Math.floor(getMinWidth(key) * scale));
    result[key] = w;
    assigned += w;
  }

  const total = columnKeys.reduce((acc, key) => acc + (result[key] ?? 0), 0);
  const delta = budgetPx - total;
  if (delta !== 0) {
    const flexKey = columnKeys.includes('name')
      ? 'name'
      : (columnKeys.find((key) => key !== 'sl' && key !== 'image') ??
        columnKeys[columnKeys.length - 1]);
    result[flexKey] = Math.max(getShrinkFloor(flexKey), (result[flexKey] ?? 0) + delta);
  }

  if (columnKeys.includes('sl') && pinSlWidth != null) {
    result.sl = pinSlWidth;
    const sum = columnKeys.reduce((acc, key) => acc + (result[key] ?? 0), 0);
    const slDelta = budgetPx - sum;
    if (slDelta !== 0 && columnKeys.includes('name')) {
      result.name = Math.max(getShrinkFloor('name'), (result.name ?? 0) + slDelta);
    }
  }

  return result;
}

export function computeScreenshotColumnWidthsPx(
  columnKeys: string[],
  budgetPx: number,
  imageSizeInches: number = 1,
): Record<string, number> {
  return computeFixedBudgetColumnWidthsPx(
    columnKeys,
    budgetPx,
    (key) => minWidthForKey(key, imageSizeInches),
    (key) => shrinkFloorForKey(key, imageSizeInches),
    SCREENSHOT_SL_COLUMN_WIDTH_PX,
  );
}

export function sumPreviewColumnWidthsPx(
  columnKeys: string[],
  widths: Record<string, number>,
): number {
  return columnKeys.reduce((acc, key) => acc + (widths[key] ?? 0), 0);
}

function blobToDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result ?? ''));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

function hideScreenshotLoadingChrome(container: HTMLElement) {
  container.querySelectorAll<HTMLElement>('.smart-image-loading-overlay').forEach((el) => {
    el.style.setProperty('display', 'none', 'important');
  });
  container.querySelectorAll<HTMLElement>('.smart-image__img').forEach((img) => {
    img.classList.remove('smart-image__img--loading');
    img.style.setProperty('filter', 'none', 'important');
    img.style.setProperty('opacity', '1', 'important');
  });
}

function waitForImageElement(img: HTMLImageElement, timeoutMs: number): Promise<void> {
  if (img.complete && img.naturalHeight > 0) {
    return Promise.resolve();
  }
  if (img.complete && img.naturalHeight === 0) {
    return Promise.resolve();
  }

  return new Promise((resolve) => {
    const timer = window.setTimeout(() => resolve(), timeoutMs);
    const done = () => {
      window.clearTimeout(timer);
      resolve();
    };
    img.addEventListener('load', done, { once: true });
    img.addEventListener('error', done, { once: true });
  });
}

/** Wait until preview images are loaded (for html-to-image capture). */
export async function waitForScreenshotImages(
  container: HTMLElement | null | undefined,
  timeoutMs = 25_000,
): Promise<void> {
  if (!container) return;

  const imgs = Array.from(container.querySelectorAll<HTMLImageElement>('img.smart-image__img'));
  if (!imgs.length) return;

  const perImageTimeout = Math.max(4_000, Math.floor(timeoutMs / Math.max(1, imgs.length)));
  await Promise.all(imgs.map((img) => waitForImageElement(img, perImageTimeout)));
  hideScreenshotLoadingChrome(container);
}

/** Inline remote images and strip loading UI so html-to-image captures pixels reliably. */
export async function prepareScreenshotCaptureDom(
  container: HTMLElement | null | undefined,
  timeoutMs = 35_000,
): Promise<void> {
  if (!container) return;

  await waitForScreenshotImages(container, timeoutMs);
  hideScreenshotLoadingChrome(container);

  const imgs = Array.from(container.querySelectorAll<HTMLImageElement>('img.smart-image__img'));
  await Promise.all(
    imgs.map(async (img) => {
      const src = img.currentSrc || img.src;
      if (!src || src.startsWith('data:')) {
        hideScreenshotLoadingChrome(container);
        return;
      }

      try {
        const response = await fetch(src, { mode: 'cors', credentials: 'omit' });
        if (!response.ok) {
          return;
        }
        const blob = await response.blob();
        const dataUrl = await blobToDataUrl(blob);
        await new Promise<void>((resolve) => {
          const done = () => resolve();
          img.addEventListener('load', done, { once: true });
          img.addEventListener('error', done, { once: true });
          img.src = dataUrl;
          if (img.complete) {
            done();
          }
        });
      } catch {
        await waitForImageElement(img, 5_000);
      } finally {
        hideScreenshotLoadingChrome(container);
      }
    }),
  );

  hideScreenshotLoadingChrome(container);
  await new Promise<void>((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
  });
}

export function fileSafeForExport(value: string): string {
  return (
    String(value || 'costing')
      .trim()
      .replace(/[^a-z0-9_-]+/gi, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '')
      .toLowerCase() || 'costing'
  );
}
