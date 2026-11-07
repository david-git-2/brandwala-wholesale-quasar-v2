import { ref, computed, nextTick, type Ref } from 'vue';
import { copyToClipboard, useQuasar } from 'quasar';
import type { ManualCatalogLineItem } from './useManualCatalogOrder';

export type ManualCatalogBulkPasteValueField =
  | 'cost_price_amount'
  | 'quantity'
  | 'sell_price_amount';

export type ManualCatalogBulkPasteColumnMode = ManualCatalogBulkPasteValueField | 'all';

const ALL_VALUE_FIELDS: ManualCatalogBulkPasteValueField[] = [
  'cost_price_amount',
  'quantity',
  'sell_price_amount',
];

type BulkPasteGridRow = {
  rowKey: string;
  barcode: string;
  product_code: string;
  cost_price_amount: string;
  quantity: string;
  sell_price_amount: string;
};

export function useManualCatalogOrderBulkPaste(options: {
  items: Ref<ManualCatalogLineItem[]>;
}) {
  const $q = useQuasar();
  const showBulkPasteDialog = ref(false);
  const bulkPasteField = ref<ManualCatalogBulkPasteColumnMode>('all');
  const bulkPasteRows = ref<BulkPasteGridRow[]>([]);
  const bulkPasteFocus = ref({ row: 0, col: 0 });
  const bulkPasteSaving = ref(false);

  const bulkPasteTargetItems = computed(() => options.items.value);

  const bulkPasteGridColumns = computed((): Array<
    'barcode' | 'product_code' | ManualCatalogBulkPasteValueField
  > => {
    if (bulkPasteField.value === 'all') {
      return ['barcode', 'product_code', ...ALL_VALUE_FIELDS];
    }
    return ['barcode', 'product_code', bulkPasteField.value];
  });

  const bulkPasteFieldOptions = computed(() => {
    const optionsList: { label: string; value: ManualCatalogBulkPasteColumnMode }[] = [
      { label: 'All columns', value: 'all' },
      { label: 'Price (GBP)', value: 'cost_price_amount' },
      { label: 'Quantity', value: 'quantity' },
      { label: 'Sell price', value: 'sell_price_amount' },
    ];
    return optionsList;
  });

  const bulkPasteFieldLabel = computed(() => {
    if (bulkPasteField.value === 'all') return 'Values';
    return bulkPasteColumnLabel(bulkPasteField.value);
  });

  function bulkPasteColumnLabel(col: string): string {
    switch (col) {
      case 'barcode':
        return 'Barcode';
      case 'product_code':
        return 'Product code';
      case 'cost_price_amount':
        return 'Price (GBP)';
      case 'quantity':
        return 'Quantity';
      case 'sell_price_amount':
        return 'Sell';
      default:
        return col;
    }
  }

  function bulkPasteCellValue(row: BulkPasteGridRow, col: string): string {
    if (col === 'barcode' || col === 'product_code') {
      return row[col];
    }
    return row[col as ManualCatalogBulkPasteValueField] ?? '';
  }

  function onBulkPasteCellInput(row: BulkPasteGridRow, col: string, event: Event) {
    const value = (event.target as HTMLInputElement).value;
    if (col === 'barcode') row.barcode = value;
    else if (col === 'product_code') row.product_code = value;
    else row[col as ManualCatalogBulkPasteValueField] = value;
  }

  const emptyBulkPasteRow = (index: number): BulkPasteGridRow => ({
    rowKey: `empty-${index}`,
    barcode: '',
    product_code: '',
    cost_price_amount: '',
    quantity: '',
    sell_price_amount: '',
  });

  function openBulkPasteDialog(field: ManualCatalogBulkPasteColumnMode = 'all') {
    bulkPasteField.value = field;
    bulkPasteSaving.value = false;
    bulkPasteRows.value = Array.from({ length: 16 }, (_, i) => emptyBulkPasteRow(i));
    bulkPasteFocus.value = { row: 0, col: 0 };
    showBulkPasteDialog.value = true;
    void nextTick(() => {
      const el = document.querySelector(
        '.manual-catalog-bulk-paste-cell[data-row="0"][data-col="0"]',
      ) as HTMLInputElement | null;
      el?.focus();
    });
  }

  function onBulkPasteCellFocus(row: number, col: number) {
    bulkPasteFocus.value = { row, col };
  }

  const looksLikePasteHeader = (cols: string[]): boolean => {
    const joined = cols.join(' ').toLowerCase();
    return (
      joined.includes('barcode') ||
      joined.includes('product code') ||
      joined.includes('product_code') ||
      joined.includes('quantity') ||
      joined.includes('price') ||
      joined.includes('sell')
    );
  };

  function onBulkPasteGridPaste(event: ClipboardEvent) {
    const text = event.clipboardData?.getData('text/plain');
    if (!text) return;
    event.preventDefault();

    let pasted = text
      .split(/\r?\n/)
      .map((line) => line.split('\t').map((cell) => cell.trim()))
      .filter((cols) => cols.some((cell) => cell !== ''));
    if (pasted.length === 0) return;
    if (pasted[0] && looksLikePasteHeader(pasted[0])) {
      pasted = pasted.slice(1);
    }
    if (pasted.length === 0) return;

    const startRow = bulkPasteFocus.value.row;
    const startCol = bulkPasteFocus.value.col;
    const rows = [...bulkPasteRows.value];

    pasted.forEach((cols, rOffset) => {
      const rowIdx = startRow + rOffset;
      while (rowIdx >= rows.length) {
        rows.push(emptyBulkPasteRow(rows.length));
      }
      const row = rows[rowIdx];
      if (!row) return;
      const colsKeys = bulkPasteGridColumns.value;
      cols.forEach((cell, cOffset) => {
        if (!cell.trim()) return;
        const colIdx = startCol + cOffset;
        const key = colsKeys[colIdx];
        if (!key) return;
        if (key === 'barcode') row.barcode = cell;
        else if (key === 'product_code') row.product_code = cell;
        else row[key] = cell;
      });
    });

    bulkPasteRows.value = rows;
  }

  function copyBulkPasteProductNames() {
    const names = bulkPasteTargetItems.value
      .map((it) => (it.name || '').trim())
      .filter((name) => name.length > 0);
    if (names.length === 0) {
      $q.notify({
        type: 'warning',
        message: 'No product names on this order.',
        position: 'bottom',
      });
      return;
    }
    void copyToClipboard(names.join('\n')).then(() => {
      $q.notify({
        type: 'positive',
        message: `Copied ${names.length} product name${names.length === 1 ? '' : 's'}.`,
        position: 'bottom',
        timeout: 1500,
      });
    });
  }

  const normalizeKey = (value: string | null | undefined) =>
    (value || '').trim().replace(/^['`]+/, '').replace(/\s+/g, '').toLowerCase();

  function normalizePasteNumber(
    valueField: ManualCatalogBulkPasteValueField,
    raw: string,
  ): number | null {
    if (!raw.trim()) return null;
    const val = Number(raw.replace(/[^0-9.-]/g, ''));
    if (Number.isNaN(val)) return null;
    if (valueField === 'cost_price_amount' || valueField === 'sell_price_amount') {
      return Number(val.toFixed(2));
    }
    if (valueField === 'quantity') return Math.max(1, Math.round(val));
    return val;
  }

  function applyBulkPaste(): { count: number; skipped: number } {
    const field = bulkPasteField.value;
    const items = options.items.value;
    let count = 0;
    let skipped = 0;
    const usedIds = new Set<string>();

    const itemCodes = (it: ManualCatalogLineItem) => ({
      barcode: normalizeKey(it.product_barcode),
      product_code: normalizeKey(it.product_code),
    });

    const findMatches = (rowBarcode: string, rowCode: string) =>
      items.filter((it) => {
        const codes = itemCodes(it);
        if (rowBarcode && rowCode) {
          return codes.barcode === rowBarcode && codes.product_code === rowCode;
        }
        if (rowBarcode) return codes.barcode === rowBarcode;
        if (rowCode) return codes.product_code === rowCode;
        return false;
      });

    const activeValueFields =
      field === 'all' ? ALL_VALUE_FIELDS : [field as ManualCatalogBulkPasteValueField];

    const rowHasPasteValues = (row: BulkPasteGridRow): boolean =>
      activeValueFields.some((f) => normalizePasteNumber(f, row[f]) !== null);

    const applyPartialToLine = (line: ManualCatalogLineItem, row: BulkPasteGridRow) => {
      for (const f of activeValueFields) {
        const normalized = normalizePasteNumber(f, row[f]);
        if (normalized === null) continue;
        if (f === 'quantity') line.quantity = normalized;
        else if (f === 'cost_price_amount') line.cost_price_amount = normalized;
        else if (f === 'sell_price_amount') line.sell_price_amount = normalized;
      }
    };

    const dataRows = bulkPasteRows.value.filter((row) => rowHasPasteValues(row));
    const pasteHasKeys = dataRows.some(
      (row) => normalizeKey(row.barcode) || normalizeKey(row.product_code),
    );

    if (pasteHasKeys) {
      for (const row of dataRows) {
        const barcode = normalizeKey(row.barcode);
        const productCode = normalizeKey(row.product_code);
        if (!barcode && !productCode) {
          skipped++;
          continue;
        }
        const hits = findMatches(barcode, productCode).filter((it) => !usedIds.has(it.localId));
        if (hits.length !== 1) {
          skipped++;
          continue;
        }
        const target = hits[0]!;
        usedIds.add(target.localId);
        applyPartialToLine(target, row);
        count++;
      }
    } else {
      dataRows.forEach((row, i) => {
        const targetItem = items[i];
        if (!targetItem) {
          skipped++;
          return;
        }
        if (usedIds.has(targetItem.localId)) {
          skipped++;
          return;
        }
        usedIds.add(targetItem.localId);
        applyPartialToLine(targetItem, row);
        count++;
      });
    }

    return { count, skipped };
  }

  async function applyBulkPasteAndClose() {
    bulkPasteSaving.value = true;
    try {
      const { count, skipped } = applyBulkPaste();
      if (count === 0) {
        $q.notify({
          message: skipped > 0 ? `No rows updated (${skipped} unmatched)` : 'No values to apply',
          color: 'warning',
          icon: 'ph ph-warning-circle',
          position: 'bottom',
          timeout: 2000,
        });
        return;
      }
      $q.notify({
        message: `Updated ${count} line${count === 1 ? '' : 's'}${skipped ? ` (${skipped} skipped)` : ''}`,
        color: 'positive',
        icon: 'ph ph-check-circle',
        position: 'bottom',
        timeout: 1500,
      });
      showBulkPasteDialog.value = false;
    } finally {
      bulkPasteSaving.value = false;
    }
  }

  return {
    showBulkPasteDialog,
    bulkPasteField,
    bulkPasteRows,
    bulkPasteGridColumns,
    bulkPasteColumnLabel,
    bulkPasteCellValue,
    onBulkPasteCellInput,
    onBulkPasteCellFocus,
    onBulkPasteGridPaste,
    bulkPasteFieldOptions,
    bulkPasteFieldLabel,
    bulkPasteTargetItems,
    bulkPasteSaving,
    applyBulkPaste: applyBulkPasteAndClose,
    openBulkPasteDialog,
    copyBulkPasteProductNames,
  };
}
