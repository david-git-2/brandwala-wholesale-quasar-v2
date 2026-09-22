import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { showErrorNotification } from 'src/utils/appFeedback';
import {
  globalShipmentBoxRepository,
  type GlobalShipmentBox,
} from '../repositories/globalShipmentBoxRepository';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

export type BoxGridRowRef =
  | { kind: 'saved'; id: number }
  | { kind: 'draft' };

type SavedRowDraft = {
  box_number?: string;
  weight_kg?: number | null;
};

const getNextBoxNumber = (boxes: GlobalShipmentBox[]): string => {
  if (!boxes.length) return '1';

  const lastBox = boxes[boxes.length - 1];
  if (!lastBox) return '1';

  const lastNum = lastBox.box_number;
  const match = lastNum.match(/^(.*?)(\d+)$/);
  if (match) {
    const prefix = match[1] ?? '';
    const numStr = match[2] ?? '';
    const num = parseInt(numStr, 10);
    const nextNum = String(num + 1);
    const paddedNum = nextNum.padStart(numStr.length, '0');
    return `${prefix}${paddedNum}`;
  }
  return `${lastNum}-2`;
};

export function useShipmentBoxWeightGrid(shipmentId: number) {
  const shipmentStore = useGlobalShipmentStore();
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();

  const loading = ref(true);
  const savingRowKey = ref<string | null>(null);
  const draftRow = reactive<{ box_number: string; weight_kg: number | null }>({
    box_number: '',
    weight_kg: null,
  });
  const savedRowDrafts = reactive<Record<number, SavedRowDraft>>({});

  const savedRows = computed(() => shipmentStore.currentShipmentBoxes);

  const totalWeightKg = computed(() =>
    savedRows.value.reduce((sum, box) => sum + (box.weight_kg || 0), 0),
  );

  const resolveParentTenantId = (): number => {
    const currentTenant =
      tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === authStore.tenantId);
    const parentTenantId = currentTenant?.parent_id ?? authStore.tenantId;
    if (!parentTenantId) throw new Error('No tenant found');
    return parentTenantId;
  };

  const resetDraftRow = () => {
    draftRow.box_number = getNextBoxNumber(savedRows.value);
    draftRow.weight_kg = null;
  };

  const loadBoxes = async () => {
    loading.value = true;
    try {
      await shipmentStore.fetchShipmentBoxes(shipmentId);
      resetDraftRow();
    } finally {
      loading.value = false;
    }
  };

  onMounted(() => {
    void loadBoxes();
  });

  watch(savedRows, () => {
    if (!draftRow.box_number.trim()) {
      draftRow.box_number = getNextBoxNumber(savedRows.value);
    }
  });

  const getSavedBox = (id: number): GlobalShipmentBox | undefined =>
    savedRows.value.find((box) => box.id === id);

  const getBoxNumber = (row: BoxGridRowRef): string => {
    if (row.kind === 'draft') return draftRow.box_number;
    const draft = savedRowDrafts[row.id]?.box_number;
    if (draft !== undefined) return draft;
    return getSavedBox(row.id)?.box_number ?? '';
  };

  const getWeightKg = (row: BoxGridRowRef): number | null => {
    if (row.kind === 'draft') return draftRow.weight_kg;
    const draft = savedRowDrafts[row.id]?.weight_kg;
    if (draft !== undefined) return draft;
    const saved = getSavedBox(row.id)?.weight_kg;
    return saved ?? null;
  };

  const setBoxNumber = (row: BoxGridRowRef, value: string | number | null) => {
    const next = value === null || value === undefined ? '' : String(value);
    if (row.kind === 'draft') {
      draftRow.box_number = next;
      return;
    }
    if (!savedRowDrafts[row.id]) savedRowDrafts[row.id] = {};
    savedRowDrafts[row.id].box_number = next;
  };

  const setWeightKg = (row: BoxGridRowRef, value: string | number | null) => {
    let parsed: number | null = null;
    if (value !== null && value !== '' && value !== undefined) {
      const num = Number(value);
      if (!Number.isNaN(num)) parsed = num;
    }
    if (row.kind === 'draft') {
      draftRow.weight_kg = parsed;
      return;
    }
    if (!savedRowDrafts[row.id]) savedRowDrafts[row.id] = {};
    savedRowDrafts[row.id].weight_kg = parsed;
  };

  const clearSavedRowDraft = (id: number) => {
    delete savedRowDrafts[id];
  };

  const commitRow = async (row: BoxGridRowRef) => {
    if (row.kind === 'draft') {
      await commitDraftRow();
      return;
    }
    await commitSavedRow(row.id);
  };

  const commitDraftRow = async () => {
    const boxNumber = draftRow.box_number.trim();
    const weightKg = draftRow.weight_kg;
    if (!boxNumber || weightKg === null || weightKg <= 0) return;

    savingRowKey.value = 'draft';
    try {
      await globalShipmentBoxRepository.create({
        parent_tenant_id: resolveParentTenantId(),
        shipment_id: shipmentId,
        box_number: boxNumber,
        weight_kg: weightKg,
      });
      await shipmentStore.fetchShipmentBoxes(shipmentId);
      resetDraftRow();
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to add box.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const commitSavedRow = async (id: number) => {
    const saved = getSavedBox(id);
    if (!saved) return;

    const draft = savedRowDrafts[id];
    const nextBoxNumber = draft?.box_number !== undefined ? draft.box_number.trim() : saved.box_number;
    const nextWeightKg = draft?.weight_kg !== undefined ? draft.weight_kg : saved.weight_kg;

    if (!nextBoxNumber) {
      showErrorNotification('Box number cannot be empty.');
      return;
    }
    if (nextWeightKg === null || nextWeightKg <= 0) {
      showErrorNotification('Weight must be greater than 0.');
      return;
    }

    const boxNumberChanged = nextBoxNumber !== saved.box_number;
    const weightChanged = nextWeightKg !== saved.weight_kg;
    if (!boxNumberChanged && !weightChanged) {
      clearSavedRowDraft(id);
      return;
    }

    savingRowKey.value = `saved-${id}`;
    try {
      const patch: Partial<Pick<GlobalShipmentBox, 'box_number' | 'weight_kg'>> = {};
      if (boxNumberChanged) patch.box_number = nextBoxNumber;
      if (weightChanged) patch.weight_kg = nextWeightKg;
      await globalShipmentBoxRepository.update(id, patch);
      await shipmentStore.fetchShipmentBoxes(shipmentId);
      clearSavedRowDraft(id);
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to update box.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const deleteRow = async (id: number) => {
    savingRowKey.value = `saved-${id}`;
    try {
      await globalShipmentBoxRepository.delete(id);
      clearSavedRowDraft(id);
      await shipmentStore.fetchShipmentBoxes(shipmentId);
      if (!draftRow.box_number.trim()) {
        resetDraftRow();
      }
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to delete box.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const isRowSaving = (row: BoxGridRowRef): boolean => {
    if (row.kind === 'draft') return savingRowKey.value === 'draft';
    return savingRowKey.value === `saved-${row.id}`;
  };

  return {
    loading,
    savingRowKey,
    savedRows,
    draftRow,
    totalWeightKg,
    getBoxNumber,
    getWeightKg,
    setBoxNumber,
    setWeightKg,
    commitRow,
    deleteRow,
    isRowSaving,
  };
}
