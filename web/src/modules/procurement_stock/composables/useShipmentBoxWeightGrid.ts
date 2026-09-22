import { computed, onMounted, reactive, ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { showErrorNotification } from 'src/utils/appFeedback';
import {
  globalShipmentBoxRepository,
  type GlobalShipmentBox,
} from '../repositories/globalShipmentBoxRepository';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { getCargoWeightKg } from 'src/shared/shipment-engine';
import {
  boxWeightDiffKg,
  boxWeightVarianceStatus,
  describeBoxVsInvoiceCargo,
  type BoxWeightVarianceStatus,
} from '../utils/boxWeightVariance';
import { sumBoxReceivedWeightKg, sumBoxShippingWeightKg } from '../utils/weightBalance';

export type BoxGridRowRef = { kind: 'saved'; id: number };

type SavedRowDraft = {
  box_number?: string;
  received_weight?: number | null;
  shipping_weight?: number | null;
};

type WeightField = 'received_weight' | 'shipping_weight';

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

const toWeight = (value: number | null | undefined): number => {
  if (value === null || value === undefined || Number.isNaN(value)) return 0;
  return value;
};

export function useShipmentBoxWeightGrid(shipmentId: number) {
  const shipmentStore = useGlobalShipmentStore();
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();

  const loading = ref(true);
  const showAddDialog = ref(false);
  const savingAdd = ref(false);
  const savingRowKey = ref<string | null>(null);
  const addForm = reactive<{
    box_number: string;
    received_weight: number | null;
    shipping_weight: number | null;
  }>({
    box_number: '',
    received_weight: null,
    shipping_weight: null,
  });
  const savedRowDrafts = reactive<Record<number, SavedRowDraft>>({});

  const savedRows = computed(() => shipmentStore.currentShipmentBoxes);

  const totalReceivedKg = computed(() => sumBoxReceivedWeightKg(savedRows.value));
  const totalShippingKg = computed(() => sumBoxShippingWeightKg(savedRows.value));
  const invoiceCargoKg = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return 0;
    return getCargoWeightKg(shipment, shipmentStore.currentShipmentItems);
  });

  const boxShippingVsInvoice = computed(() =>
    describeBoxVsInvoiceCargo('Box shipping', totalShippingKg.value, invoiceCargoKg.value),
  );

  const boxReceivedVsInvoice = computed(() =>
    describeBoxVsInvoiceCargo('Box received', totalReceivedKg.value, invoiceCargoKg.value),
  );

  const resolveParentTenantId = (): number => {
    const currentTenant =
      tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === authStore.tenantId);
    const parentTenantId = currentTenant?.parent_id ?? authStore.tenantId;
    if (!parentTenantId) throw new Error('No tenant found');
    return parentTenantId;
  };

  const resetAddForm = () => {
    addForm.box_number = getNextBoxNumber(savedRows.value);
    addForm.received_weight = null;
    addForm.shipping_weight = null;
  };

  const loadBoxes = async () => {
    loading.value = true;
    try {
      if (!shipmentStore.currentShipment || shipmentStore.currentShipment.id !== shipmentId) {
        await shipmentStore.fetchShipmentDetails(shipmentId);
      } else {
        await shipmentStore.fetchShipmentBoxes(shipmentId);
      }
    } finally {
      loading.value = false;
    }
  };

  onMounted(() => {
    void loadBoxes();
  });

  const openAddDialog = () => {
    resetAddForm();
    showAddDialog.value = true;
  };

  const closeAddDialog = () => {
    showAddDialog.value = false;
  };

  const getSavedBox = (id: number): GlobalShipmentBox | undefined =>
    savedRows.value.find((box) => box.id === id);

  const getBoxNumber = (row: BoxGridRowRef): string => {
    const draft = savedRowDrafts[row.id]?.box_number;
    if (draft !== undefined) return draft;
    return getSavedBox(row.id)?.box_number ?? '';
  };

  const getWeight = (row: BoxGridRowRef, field: WeightField): number | null => {
    const draft = savedRowDrafts[row.id]?.[field];
    if (draft !== undefined) return draft;
    const saved = getSavedBox(row.id)?.[field];
    return saved ?? null;
  };

  const setBoxNumber = (row: BoxGridRowRef, value: string | number | null) => {
    const next = value === null || value === undefined ? '' : String(value);
    if (!savedRowDrafts[row.id]) savedRowDrafts[row.id] = {};
    savedRowDrafts[row.id].box_number = next;
  };

  const setWeight = (row: BoxGridRowRef, field: WeightField, value: string | number | null) => {
    let parsed: number | null = null;
    if (value !== null && value !== '' && value !== undefined) {
      const num = Number(value);
      if (!Number.isNaN(num)) parsed = num;
    }
    if (!savedRowDrafts[row.id]) savedRowDrafts[row.id] = {};
    savedRowDrafts[row.id][field] = parsed;
  };

  const rowVariance = (
    row: BoxGridRowRef,
  ): { diff: number | null; status: BoxWeightVarianceStatus | null } => {
    const received = getWeight(row, 'received_weight');
    const shipping = getWeight(row, 'shipping_weight');
    if (received === null || shipping === null) return { diff: null, status: null };
    return {
      diff: boxWeightDiffKg(received, shipping),
      status: boxWeightVarianceStatus(received, shipping),
    };
  };

  const clearSavedRowDraft = (id: number) => {
    delete savedRowDrafts[id];
  };

  const saveAddBox = async () => {
    savingAdd.value = true;
    try {
      await globalShipmentBoxRepository.create({
        parent_tenant_id: resolveParentTenantId(),
        shipment_id: shipmentId,
        box_number: addForm.box_number.trim(),
        received_weight: toWeight(addForm.received_weight),
        shipping_weight: toWeight(addForm.shipping_weight),
      });
      await shipmentStore.fetchShipmentBoxes(shipmentId);
      showAddDialog.value = false;
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to add box.');
    } finally {
      savingAdd.value = false;
    }
  };

  const commitSavedRow = async (id: number) => {
    const saved = getSavedBox(id);
    if (!saved) return;

    const draft = savedRowDrafts[id];
    const nextBoxNumber =
      draft?.box_number !== undefined ? draft.box_number.trim() : saved.box_number;
    const nextReceived =
      draft?.received_weight !== undefined ? draft.received_weight : saved.received_weight;
    const nextShipping =
      draft?.shipping_weight !== undefined ? draft.shipping_weight : saved.shipping_weight;

    const receivedNorm = toWeight(nextReceived);
    const shippingNorm = toWeight(nextShipping);

    const boxNumberChanged = nextBoxNumber !== saved.box_number;
    const receivedChanged = receivedNorm !== saved.received_weight;
    const shippingChanged = shippingNorm !== saved.shipping_weight;
    if (!boxNumberChanged && !receivedChanged && !shippingChanged) {
      clearSavedRowDraft(id);
      return;
    }

    savingRowKey.value = `saved-${id}`;
    try {
      const patch: Partial<
        Pick<GlobalShipmentBox, 'box_number' | 'received_weight' | 'shipping_weight'>
      > = {};
      if (boxNumberChanged) patch.box_number = nextBoxNumber;
      if (receivedChanged) patch.received_weight = receivedNorm;
      if (shippingChanged) patch.shipping_weight = shippingNorm;
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
    } catch (error: unknown) {
      showErrorNotification((error as Error).message || 'Failed to delete box.');
    } finally {
      savingRowKey.value = null;
    }
  };

  const isRowSaving = (row: BoxGridRowRef): boolean => savingRowKey.value === `saved-${row.id}`;

  return {
    loading,
    showAddDialog,
    savingAdd,
    addForm,
    savedRows,
    totalReceivedKg,
    totalShippingKg,
    invoiceCargoKg,
    boxShippingVsInvoice,
    boxReceivedVsInvoice,
    getBoxNumber,
    getWeight,
    setBoxNumber,
    setWeight,
    rowVariance,
    openAddDialog,
    closeAddDialog,
    saveAddBox,
    commitSavedRow,
    deleteRow,
    isRowSaving,
  };
}
