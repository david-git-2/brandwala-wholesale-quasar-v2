import { computed, reactive, ref, type MaybeRefOrGetter } from 'vue';
import { showErrorNotification } from 'src/utils/appFeedback';
import type { BatchCodeItem, BatchCodePasteRow } from '../repositories/batchCodeRepository';
import { defaultExpireFromManufacturing, toDisplayDate, toIsoDate } from '../utils/batchCodeExpiry';
import { useBatchCodeItemMutations } from './useBatchCodeMutations';
import { useBatchCodeItemsQuery } from './useBatchCodeQueries';

export type BatchGridRowRef =
  | { kind: 'saved'; id: number }
  | { kind: 'draft' };

export type BatchCodePasteField =
  | 'barcode'
  | 'product_code'
  | 'batch_id'
  | 'manufacturing_date'
  | 'expire_date';

type DraftRow = {
  barcode: string;
  product_code: string;
  batch_id: string;
  manufacturing_date: string;
  expire_date: string;
};

type SavedRowDraft = Partial<DraftRow>;

export const BATCH_CODE_FIELD_LABELS: Record<BatchCodePasteField, string> = {
  barcode: 'Barcode',
  product_code: 'Product code',
  batch_id: 'Batch ID',
  manufacturing_date: 'Mfg date',
  expire_date: 'Expire date',
};

export const BATCH_CODE_PASTE_FIELDS: BatchCodePasteField[] = [
  'barcode',
  'product_code',
  'batch_id',
  'manufacturing_date',
  'expire_date',
];

export const parseBatchCodePasteMatrix = (text: string): string[][] =>
  text
    .split(/\r?\n/)
    .map((line) => line.split('\t').map((cell) => cell.trim()))
    .filter((cols) => cols.some((cell) => cell !== ''));

export const parseBatchCodeColumnPaste = (text: string): string[] =>
  text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line !== '');

export const columnPasteToMatrix = (lines: string[]): string[][] =>
  lines.map((line) => [line]);

const emptyDraft = (): DraftRow => ({
  barcode: '',
  product_code: '',
  batch_id: '',
  manufacturing_date: '',
  expire_date: '',
});

const hasAnyContent = (row: DraftRow | SavedRowDraft): boolean =>
  Boolean(
    row.barcode?.trim() ||
      row.product_code?.trim() ||
      row.batch_id?.trim() ||
      row.manufacturing_date?.trim() ||
      row.expire_date?.trim(),
  );

const DATE_FIELDS: (keyof DraftRow)[] = ['manufacturing_date', 'expire_date'];

const normalizePayload = (row: DraftRow | SavedRowDraft) => {
  const manufacturingDate = toIsoDate(row.manufacturing_date);
  let expireDate = toIsoDate(row.expire_date);
  if (manufacturingDate && !expireDate) {
    expireDate = defaultExpireFromManufacturing(manufacturingDate) || null;
  }
  return {
    barcode: row.barcode?.trim() || null,
    product_code: row.product_code?.trim() || null,
    batch_id: row.batch_id?.trim() || null,
    manufacturing_date: manufacturingDate,
    expire_date: expireDate,
  };
};

export function useShipmentBatchCodeGrid(listId: MaybeRefOrGetter<number>) {
  const savingRowKey = ref<string | null>(null);
  const draftRow = reactive<DraftRow>(emptyDraft());
  const savedRowDrafts = reactive<Record<number, SavedRowDraft>>({});

  const itemsQuery = useBatchCodeItemsQuery(listId);
  const loading = computed(
    () => itemsQuery.isPending.value && itemsQuery.isFetching.value,
  );
  const {
    createItemMutation,
    updateItemMutation,
    deleteItemMutation,
    deleteItemsMutation,
    pasteItemsMutation,
  } = useBatchCodeItemMutations(listId);

  const savedRows = computed(() => itemsQuery.data.value ?? []);
  const itemCount = computed(() => savedRows.value.length);

  const getSavedItem = (id: number) => savedRows.value.find((row) => row.id === id);

  const getField = (row: BatchGridRowRef, field: keyof DraftRow): string => {
    if (row.kind === 'draft') return draftRow[field];
    const draft = savedRowDrafts[row.id]?.[field];
    if (draft !== undefined) return draft;
    const saved = getSavedItem(row.id);
    const value = saved?.[field];
    if (DATE_FIELDS.includes(field)) return toDisplayDate(value ?? '');
    return value ?? '';
  };

  const setField = (row: BatchGridRowRef, field: keyof DraftRow, value: string | number | null) => {
    const next = value === null || value === undefined ? '' : String(value);
    if (row.kind === 'draft') {
      draftRow[field] = next;
      return;
    }
    if (!savedRowDrafts[row.id]) savedRowDrafts[row.id] = {};
    savedRowDrafts[row.id][field] = next;
  };

  const clearSavedRowDraft = (id: number) => {
    delete savedRowDrafts[id];
  };

  const commitRow = async (row: BatchGridRowRef) => {
    if (row.kind === 'draft') {
      await commitDraftRow();
      return;
    }
    await commitSavedRow(row.id);
  };

  const commitDraftRow = async () => {
    if (!hasAnyContent(draftRow)) return;

    savingRowKey.value = 'draft';
    try {
      const payload = normalizePayload(draftRow);
      await createItemMutation.mutateAsync(payload);
      Object.assign(draftRow, emptyDraft());
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to add batch line.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const commitSavedRow = async (id: number) => {
    const saved = getSavedItem(id);
    if (!saved) return;

    const draft = savedRowDrafts[id] ?? {};
    const merged: SavedRowDraft = {
      barcode: draft.barcode ?? saved.barcode ?? '',
      product_code: draft.product_code ?? saved.product_code ?? '',
      batch_id: draft.batch_id ?? saved.batch_id ?? '',
      manufacturing_date: draft.manufacturing_date ?? saved.manufacturing_date ?? '',
      expire_date: draft.expire_date ?? saved.expire_date ?? '',
    };

    const next = normalizePayload(merged);
    const unchanged =
      (saved.barcode ?? null) === next.barcode &&
      (saved.product_code ?? null) === next.product_code &&
      (saved.batch_id ?? null) === next.batch_id &&
      (saved.manufacturing_date ?? null) === next.manufacturing_date &&
      (saved.expire_date ?? null) === next.expire_date;

    if (unchanged) {
      clearSavedRowDraft(id);
      return;
    }

    savingRowKey.value = `saved-${id}`;
    try {
      await updateItemMutation.mutateAsync({ id, payload: next });
      clearSavedRowDraft(id);
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to update batch line.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const matrixToPasteRows = (
    startFieldIndex: number,
    matrix: string[][],
  ): BatchCodePasteRow[] =>
    matrix.map((rowCells) => {
      const row: BatchCodePasteRow = {};
      rowCells.forEach((cell, colOffset) => {
        const field = BATCH_CODE_PASTE_FIELDS[startFieldIndex + colOffset];
        if (field) {
          row[field] = DATE_FIELDS.includes(field) ? toIsoDate(cell) : cell;
        }
      });
      return row;
    });

  const pasteColumn = async (
    startRowIndex: number,
    field: BatchCodePasteField,
    lines: string[],
  ): Promise<void> => {
    const fieldIndex = BATCH_CODE_PASTE_FIELDS.indexOf(field);
    if (fieldIndex < 0 || lines.length === 0) return;
    await pasteGrid(startRowIndex, fieldIndex, columnPasteToMatrix(lines));
  };

  const pasteGrid = async (
    startRowIndex: number,
    startFieldIndex: number,
    matrix: string[][],
  ): Promise<void> => {
    if (matrix.length === 0 || savingRowKey.value === 'paste') return;

    savingRowKey.value = 'paste';
    try {
      const rows = matrixToPasteRows(startFieldIndex, matrix);
      await pasteItemsMutation.mutateAsync({ startRowIndex, rows });
      Object.keys(savedRowDrafts).forEach((key) => {
        delete savedRowDrafts[Number(key)];
      });
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to paste batch lines.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const addLineFromDialog = async (
    payload: Omit<BatchCodeItem, 'id' | 'list_id' | 'created_at' | 'updated_at'>,
  ) => {
    savingRowKey.value = 'add';
    try {
      await createItemMutation.mutateAsync(payload);
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to add batch line.');
      throw error;
    } finally {
      savingRowKey.value = null;
    }
  };

  const deleteRow = async (id: number) => {
    savingRowKey.value = `saved-${id}`;
    try {
      await deleteItemMutation.mutateAsync(id);
      clearSavedRowDraft(id);
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to delete batch line.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const getIsArrived = (id: number): boolean => getSavedItem(id)?.is_arrived ?? false;

  const toggleArrived = async (id: number, value: boolean) => {
    const saved = getSavedItem(id);
    if (!saved || saved.is_arrived === value) return;

    savingRowKey.value = `saved-${id}`;
    try {
      await updateItemMutation.mutateAsync({ id, payload: { is_arrived: value } });
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to update arrived.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const deleteRows = async (ids: number[]) => {
    if (ids.length === 0) return;
    savingRowKey.value = 'bulk-delete';
    try {
      await deleteItemsMutation.mutateAsync(ids);
      ids.forEach((id) => clearSavedRowDraft(id));
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to delete batch lines.');
      throw error;
    } finally {
      savingRowKey.value = null;
    }
  };

  const isRowSaving = (row: BatchGridRowRef): boolean => {
    if (row.kind === 'draft') return savingRowKey.value === 'draft';
    return savingRowKey.value === `saved-${row.id}`;
  };

  const isAddingRow = computed(
    () => savingRowKey.value === 'add' || createItemMutation.isPending.value,
  );
  const isPasting = computed(
    () => savingRowKey.value === 'paste' || pasteItemsMutation.isPending.value,
  );
  const isBulkDeleting = computed(
    () => savingRowKey.value === 'bulk-delete' || deleteItemsMutation.isPending.value,
  );

  return {
    loading,
    savedRows,
    itemCount,
    getField,
    setField,
    commitRow,
    pasteGrid,
    pasteColumn,
    addLineFromDialog,
    deleteRow,
    deleteRows,
    getIsArrived,
    toggleArrived,
    isRowSaving,
    isAddingRow,
    isPasting,
    isBulkDeleting,
  };
}
