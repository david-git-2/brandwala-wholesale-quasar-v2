import type { BatchCodePasteRow } from '../repositories/batchCodeRepository';
import { toIsoDate } from './batchCodeExpiry';

export const BATCH_CODE_CSV_HEADERS = [
  'barcode',
  'product_code',
  'batch_id',
  'manufacturing_date',
  'expire_date',
] as const;

export const BATCH_CODE_SAMPLE_FILENAME = 'batch-code-import-sample.csv';

const normalizeHeader = (cell: string): string =>
  cell.trim().toLowerCase().replace(/\s+/g, '_');

/** Split one CSV line; supports double-quoted fields with commas. */
export const splitCsvLine = (line: string): string[] => {
  const cells: string[] = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (line[i + 1] === '"') {
          current += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        current += ch;
      }
      continue;
    }
    if (ch === '"') {
      inQuotes = true;
      continue;
    }
    if (ch === ',') {
      cells.push(current);
      current = '';
      continue;
    }
    current += ch;
  }
  cells.push(current);
  return cells.map((c) => c.trim());
};

export const buildBatchCodeSampleCsv = (): string => {
  const header = BATCH_CODE_CSV_HEADERS.join(',');
  const example = ['8901234567890', 'SKU-001', 'BATCH-A1', '6/27/2026', ''].join(',');
  return `${header}\n${example}\n`;
};

const rowHasContent = (row: BatchCodePasteRow): boolean =>
  Boolean(
    row.barcode?.trim() ||
      row.product_code?.trim() ||
      row.batch_id?.trim() ||
      row.manufacturing_date?.trim() ||
      row.expire_date?.trim(),
  );

export const parseBatchCodeCsv = (text: string): BatchCodePasteRow[] => {
  const raw = text.replace(/^\uFEFF/, '').trim();
  if (!raw) {
    throw new Error('The file is empty.');
  }

  const lines = raw.split(/\r?\n/).filter((line) => line.trim() !== '');
  if (lines.length < 2) {
    throw new Error('Add at least one data row below the header.');
  }

  const headerCells = splitCsvLine(lines[0]).map(normalizeHeader);
  const indexByField = new Map<string, number>();
  headerCells.forEach((name, index) => {
    if (name) indexByField.set(name, index);
  });

  const missing = BATCH_CODE_CSV_HEADERS.filter((h) => !indexByField.has(h));
  if (missing.length > 0) {
    throw new Error(`Missing columns: ${missing.join(', ')}`);
  }

  const rows: BatchCodePasteRow[] = [];

  for (let lineIndex = 1; lineIndex < lines.length; lineIndex += 1) {
    const cells = splitCsvLine(lines[lineIndex]);
    const pick = (field: typeof BATCH_CODE_CSV_HEADERS[number]): string => {
      const idx = indexByField.get(field);
      if (idx === undefined) return '';
      return cells[idx]?.trim() ?? '';
    };

    const mfgRaw = pick('manufacturing_date');
    const expRaw = pick('expire_date');
    const row: BatchCodePasteRow = {
      barcode: pick('barcode') || null,
      product_code: pick('product_code') || null,
      batch_id: pick('batch_id') || null,
      manufacturing_date: mfgRaw ? toIsoDate(mfgRaw) : null,
      expire_date: expRaw ? toIsoDate(expRaw) : null,
    };

    if (mfgRaw && !row.manufacturing_date) {
      throw new Error(`Row ${lineIndex + 1}: invalid manufacturing_date "${mfgRaw}"`);
    }
    if (expRaw && !row.expire_date) {
      throw new Error(`Row ${lineIndex + 1}: invalid expire_date "${expRaw}"`);
    }

    if (rowHasContent(row)) {
      rows.push(row);
    }
  }

  if (rows.length === 0) {
    throw new Error('No data rows found.');
  }

  return rows;
};

export const batchCodePasteRowsToMatrix = (rows: BatchCodePasteRow[]): string[][] =>
  rows.map((row) =>
    BATCH_CODE_CSV_HEADERS.map((field) => {
      const value = row[field];
      return value == null ? '' : String(value);
    }),
  );

export const downloadBatchCodeSampleCsv = (): void => {
  const blob = new Blob([buildBatchCodeSampleCsv()], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.setAttribute('download', BATCH_CODE_SAMPLE_FILENAME);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
};
