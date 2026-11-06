import { ref, computed, nextTick, type Ref } from 'vue';
import { copyToClipboard, useQuasar } from 'quasar';
import type { ShopOrder, ShopOrderItem } from '../types';
import {
  calculateItemFirstOfferPrice,
  getPackageWeightGm as catalogGetPackageWeightGm,
  getProductWeightGm as catalogGetProductWeightGm,
} from '../utils/catalogPricingUtils';
import {
  isCatalogFirstOfferLocked,
  isCatalogStaffReadOnly,
  normalizeCatalogOrderStatus,
} from '../utils/catalogOrderStatus';
import type { CatalogOrderItemStaffUpdatePayload } from '../repositories/shopOrderRepository';

export type CatalogBulkPasteValueField =
  | 'cost_price_amount'
  | 'quantity'
  | 'product_weight_gm'
  | 'package_weight_gm';

export type CatalogBulkPasteColumnMode = CatalogBulkPasteValueField | 'all';

const ALL_VALUE_FIELDS: CatalogBulkPasteValueField[] = [
  'cost_price_amount',
  'quantity',
  'product_weight_gm',
  'package_weight_gm',
];

const WEIGHT_ONLY_FIELDS: CatalogBulkPasteValueField[] = [
  'product_weight_gm',
  'package_weight_gm',
];

type BulkPasteGridRow = {
  rowKey: string;
  barcode: string;
  product_code: string;
  cost_price_amount: string;
  quantity: string;
  product_weight_gm: string;
  package_weight_gm: string;
};

export type CatalogBulkPasteUpdate = {
  item_id: number;
  payload: CatalogOrderItemStaffUpdatePayload;
};

export function useCatalogOrderBulkPaste(options: {
  order: Ref<ShopOrder | null>;
  items: Ref<ShopOrderItem[]>;
  loadAllItemsForPaste: () => Promise<ShopOrderItem[]>;
  saveUpdates: (updates: CatalogBulkPasteUpdate[]) => Promise<void>;
}) {
  const $q = useQuasar();
  const showBulkPasteDialog = ref(false);
  const bulkPasteField = ref<CatalogBulkPasteColumnMode>('all');
  const bulkPasteSaving = ref(false);
  const bulkPasteRows = ref<BulkPasteGridRow[]>([]);
  const bulkPasteFocus = ref({ row: 0, col: 0 });
  const pasteMatchItems = ref<ShopOrderItem[] | null>(null);
  const pasteMatchOrderId = ref<number | null>(null);

  const orderStatus = computed(() => options.order.value?.status ?? 'submitted');
  const isFirstOfferLocked = computed(() => isCatalogFirstOfferLocked(orderStatus.value));
  const isStaffReadOnly = computed(() => isCatalogStaffReadOnly(orderStatus.value));
  const isCostingMode = computed(() => normalizeCatalogOrderStatus(orderStatus.value) === 'submitted');

  const canBulkPaste = computed(() => !isStaffReadOnly.value);

  const bulkPasteTargetItems = computed(
    () => pasteMatchItems.value ?? options.items.value,
  );

  async function ensurePasteMatchItems(): Promise<ShopOrderItem[]> {
    const orderId = options.order.value?.id ?? null;
    if (
      orderId != null &&
      pasteMatchOrderId.value === orderId &&
      pasteMatchItems.value !== null
    ) {
      return pasteMatchItems.value;
    }
    const loaded = await options.loadAllItemsForPaste();
    pasteMatchItems.value = loaded;
    pasteMatchOrderId.value = orderId;
    return loaded;
  }

  const allowedValueFields = computed((): CatalogBulkPasteValueField[] => {
    if (isFirstOfferLocked.value) return WEIGHT_ONLY_FIELDS;
    return ALL_VALUE_FIELDS;
  });

  const bulkPasteGridColumns = computed((): Array<'barcode' | 'product_code' | CatalogBulkPasteValueField> => {
    if (bulkPasteField.value === 'all') {
      return ['barcode', 'product_code', ...allowedValueFields.value];
    }
    return ['barcode', 'product_code', bulkPasteField.value];
  });

  const bulkPasteFieldOptions = computed(() => {
    const fields = allowedValueFields.value;
    const options: { label: string; value: CatalogBulkPasteColumnMode }[] = [];
    if (fields.length > 1) {
      options.push({ label: 'All columns', value: 'all' });
    }
    for (const f of fields) {
      options.push({ label: bulkPasteColumnLabel(f), value: f });
    }
    return options;
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
        return 'Price';
      case 'quantity':
        return 'Quantity';
      case 'product_weight_gm':
        return 'Product weight';
      case 'package_weight_gm':
        return 'Package weight';
      default:
        return col;
    }
  }

  function bulkPasteCellValue(row: BulkPasteGridRow, col: string): string {
    if (col === 'barcode' || col === 'product_code') {
      return row[col];
    }
    return row[col as CatalogBulkPasteValueField] ?? '';
  }

  function onBulkPasteCellInput(row: BulkPasteGridRow, col: string, event: Event) {
    const value = (event.target as HTMLInputElement).value;
    if (col === 'barcode') row.barcode = value;
    else if (col === 'product_code') row.product_code = value;
    else row[col as CatalogBulkPasteValueField] = value;
  }

  const emptyBulkPasteRow = (index: number): BulkPasteGridRow => ({
    rowKey: `empty-${index}`,
    barcode: '',
    product_code: '',
    cost_price_amount: '',
    quantity: '',
    product_weight_gm: '',
    package_weight_gm: '',
  });

  function openBulkPasteDialog(field: CatalogBulkPasteColumnMode = 'all') {
    if (!canBulkPaste.value) return;
    const allowed = bulkPasteFieldOptions.value.map((opt) => opt.value);
    if (allowed.length === 0) return;
    const defaultField = allowed.includes('all') ? 'all' : allowed[0]!;
    bulkPasteField.value = allowed.includes(field) ? field : defaultField;
    bulkPasteSaving.value = false;
    bulkPasteRows.value = Array.from({ length: 16 }, (_, i) => emptyBulkPasteRow(i));
    bulkPasteFocus.value = { row: 0, col: 0 };
    pasteMatchItems.value = null;
    pasteMatchOrderId.value = null;
    showBulkPasteDialog.value = true;
    void ensurePasteMatchItems().catch((err: unknown) => {
      console.error('Failed to load order lines for bulk paste:', err);
      $q.notify({
        message: `Could not load all order lines: ${(err as Error)?.message || 'error'}`,
        color: 'negative',
        icon: 'ph ph-warning-circle',
        position: 'bottom',
        timeout: 2500,
      });
    });
    void nextTick(() => {
      const el = document.querySelector(
        '.catalog-bulk-paste-cell[data-row="0"][data-col="0"]',
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
      joined.includes('package weight') ||
      joined.includes('product weight')
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
    valueField: CatalogBulkPasteValueField,
    raw: string,
  ): number | null {
    if (!raw.trim()) return null;
    const val = Number(raw.replace(/[^0-9.-]/g, ''));
    if (Number.isNaN(val)) return null;
    if (valueField === 'cost_price_amount') return Number(val.toFixed(2));
    if (valueField === 'quantity') return Math.max(0, Math.round(val));
    if (valueField === 'product_weight_gm' || valueField === 'package_weight_gm') {
      return Math.max(0, Math.round(val));
    }
    return val;
  }

  function orderRatesForCalc() {
    const order = options.order.value;
    return {
      conversion_rate: order?.conversion_rate ?? 140,
      cargo_rate: order?.cargo_rate ?? 0,
      first_offer_rate: order?.first_offer_rate ?? order?.profit_rate ?? 25,
      profit_basis: order?.profit_basis || 'total_cost',
    };
  }

  function buildStaffPayload(
    item: ShopOrderItem,
    partial: CatalogOrderItemStaffUpdatePayload,
  ): CatalogOrderItemStaffUpdatePayload {
    const payload: CatalogOrderItemStaffUpdatePayload = { ...partial };
    const order = options.order.value;
    const pkgDefault = order?.package_weight_kg;

    const prodGm =
      payload.product_weight_gm ??
      item.product_weight_gm ??
      catalogGetProductWeightGm(item);
    const pkgGm =
      payload.package_weight_gm ??
      item.package_weight_gm ??
      catalogGetPackageWeightGm(item, pkgDefault);

    if (payload.product_weight_gm != null || payload.package_weight_gm != null) {
      payload.weight_kg = (Number(prodGm) + Number(pkgGm)) / 1000;
    }

    if (isCostingMode.value && !item.is_first_offer_manual) {
      const merged: ShopOrderItem = {
        ...item,
        cost_price_amount:
          payload.cost_price_amount ?? item.cost_price_amount ?? 0,
        product_weight_gm: prodGm,
        package_weight_gm: pkgGm,
      };
      payload.staff_offer_amount = calculateItemFirstOfferPrice(
        merged,
        orderRatesForCalc(),
        pkgDefault,
      );
    }

    return payload;
  }

  async function applyBulkPaste() {
    const field = bulkPasteField.value;
    const updates: CatalogBulkPasteUpdate[] = [];
    let count = 0;
    let skipped = 0;
    const usedIds = new Set<number>();

    bulkPasteSaving.value = true;
    let items: ShopOrderItem[];
    try {
      items = await ensurePasteMatchItems();
    } catch (err: unknown) {
      bulkPasteSaving.value = false;
      console.error('Failed to load order lines for bulk paste:', err);
      $q.notify({
        message: `Could not load all order lines: ${(err as Error)?.message || 'error'}`,
        color: 'negative',
        icon: 'ph ph-warning-circle',
        position: 'bottom',
        timeout: 2500,
      });
      return;
    }

    const itemCodes = (it: ShopOrderItem) => ({
      barcode: normalizeKey(it.barcode),
      product_code: normalizeKey(it.sku),
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
      field === 'all' ? allowedValueFields.value : [field as CatalogBulkPasteValueField];

    const rowHasPasteValues = (row: BulkPasteGridRow): boolean =>
      activeValueFields.some((f) => normalizePasteNumber(f, row[f]) !== null);

    const buildPartialFromRow = (
      row: BulkPasteGridRow,
    ): CatalogOrderItemStaffUpdatePayload => {
      const payload: CatalogOrderItemStaffUpdatePayload = {};
      for (const f of activeValueFields) {
        const normalized = normalizePasteNumber(f, row[f]);
        if (normalized !== null) payload[f] = normalized;
      }
      return payload;
    };

    const pushUpdate = (targetItem: ShopOrderItem, partial: CatalogOrderItemStaffUpdatePayload) => {
      if (usedIds.has(targetItem.id)) return false;
      if (Object.keys(partial).length === 0) return false;
      usedIds.add(targetItem.id);
      const payload = buildStaffPayload(targetItem, partial);
      updates.push({ item_id: targetItem.id, payload });
      count++;
      return true;
    };

    const dataRows = bulkPasteRows.value.filter((row) => rowHasPasteValues(row));
    const pasteHasKeys = dataRows.some(
      (row) => normalizeKey(row.barcode) || normalizeKey(row.product_code),
    );

    if (pasteHasKeys) {
      for (const row of dataRows) {
        const partial = buildPartialFromRow(row);
        if (Object.keys(partial).length === 0) continue;
        const barcode = normalizeKey(row.barcode);
        const productCode = normalizeKey(row.product_code);
        if (!barcode && !productCode) {
          skipped++;
          continue;
        }
        const hits = findMatches(barcode, productCode).filter((it) => !usedIds.has(it.id));
        if (hits.length !== 1) {
          skipped++;
          continue;
        }
        if (!pushUpdate(hits[0]!, partial)) skipped++;
      }
    } else {
      dataRows.forEach((row, i) => {
        const partial = buildPartialFromRow(row);
        const targetItem = items[i];
        if (!targetItem || Object.keys(partial).length === 0) {
          skipped++;
          return;
        }
        if (!pushUpdate(targetItem, partial)) skipped++;
      });
    }

    if (updates.length === 0) {
      bulkPasteSaving.value = false;
      $q.notify({
        message: skipped > 0 ? `No rows updated (${skipped} unmatched)` : 'No values to apply',
        color: 'warning',
        icon: 'ph ph-warning-circle',
        position: 'bottom',
        timeout: 2000,
      });
      return;
    }

    try {
      await options.saveUpdates(updates);
      $q.notify({
        message: `Successfully pasted and saved ${count} line update(s)${
          skipped ? ` (${skipped} unmatched)` : ''
        }`,
        color: 'positive',
        icon: 'ph ph-check-circle',
        position: 'bottom',
        timeout: 1500,
      });
      showBulkPasteDialog.value = false;
    } catch (err: unknown) {
      console.error('Failed to bulk save pasted catalog values:', err);
      $q.notify({
        message: `Failed to save: ${(err as Error)?.message || 'error'}`,
        color: 'negative',
        icon: 'ph ph-warning-circle',
        position: 'bottom',
        timeout: 2500,
      });
    } finally {
      bulkPasteSaving.value = false;
    }
  }

  return {
    showBulkPasteDialog,
    bulkPasteField,
    bulkPasteRows,
    bulkPasteFocus,
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
    applyBulkPaste,
    openBulkPasteDialog,
    copyBulkPasteProductNames,
    canBulkPaste,
  };
}
