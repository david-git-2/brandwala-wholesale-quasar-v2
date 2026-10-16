import { date } from 'quasar';

export type CatalogRefreshLogRow = {
  id: number;
  parent_tenant_id: number;
  source: string;
  event_kind: string;
  source_url: string | null;
  file_name: string | null;
  ran_at: string;
  products_updated: number | null;
  duration_seconds: number | null;
};

/** catalog_refresh_log `source` keys grouped by products.vendor_code */
const VENDOR_CATALOG_SOURCES: Record<string, string[]> = {
  PC: ['pc', 'pc_pricecheck'],
  WTS: ['wts', 'wts_excel'],
  ELF: ['elf'],
  KOBA_RETAIL: ['koba_retail'],
  KOBA_WHOLESALE: ['koba_wholesale'],
};

function sourcesForVendorCode(vendorCode: string): string[] {
  const upper = vendorCode.trim().toUpperCase();
  return VENDOR_CATALOG_SOURCES[upper] ?? [vendorCode.trim().toLowerCase()];
}

function matchingRows(rows: CatalogRefreshLogRow[], vendorCode: string): CatalogRefreshLogRow[] {
  const sources = new Set(sourcesForVendorCode(vendorCode));
  return rows.filter((row) => sources.has(row.source));
}

function pickLatest(rows: CatalogRefreshLogRow[]): CatalogRefreshLogRow | null {
  if (!rows.length) {
    return null;
  }
  return rows.reduce((latest, row) =>
    new Date(row.ran_at).getTime() > new Date(latest.ran_at).getTime() ? row : latest,
  );
}

export type CatalogRefreshDisplay = {
  fileName: string;
  updatedAt: string;
};

/** Prefer latest Excel upload; otherwise latest scrape/sync row for that vendor. */
export function catalogRefreshDisplayForVendor(
  rows: CatalogRefreshLogRow[],
  vendorCode: string,
): CatalogRefreshDisplay | null {
  const scoped = matchingRows(rows, vendorCode);
  if (!scoped.length) {
    return null;
  }

  const latestUpload = pickLatest(
    scoped.filter((row) => row.event_kind === 'upload' && row.file_name),
  );
  const row = latestUpload ?? pickLatest(scoped);
  if (!row) {
    return null;
  }

  const fileName =
    row.file_name?.trim() ||
    (row.event_kind === 'scrape' ? 'Web scrape' : 'Catalog update');

  return {
    fileName,
    updatedAt: date.formatDate(row.ran_at, 'D MMM YYYY'),
  };
}
