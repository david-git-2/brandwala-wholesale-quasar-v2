/** Matches unresolved Excel formula text (see python/pc_excel_spec.py). */
const EXCEL_FORMULA_TEXT_RE =
  /^=|_xlfn\.|\b(?:XLOOKUP|VLOOKUP|HLOOKUP|INDEX|MATCH)\s*\(/i;

export function isExcelFormulaText(value: string | null | undefined): boolean {
  const text = value?.trim();
  if (!text) return false;
  return EXCEL_FORMULA_TEXT_RE.test(text);
}

export function sanitizeExcelCellText(value: string | null | undefined): string | null {
  const text = value?.trim();
  if (!text) return null;
  if (isExcelFormulaText(text)) return null;
  return text;
}
