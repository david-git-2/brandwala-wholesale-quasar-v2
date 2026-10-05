<template>
  <div class="column full-height no-wrap min-height-0 shipment-local-costs-panel">
    <div class="column q-gutter-y-md shrink-0">
      <q-banner dense rounded class="bg-blue-1 text-blue-10">
        Labor, van, packing, and other local spend. These do not change landed unit cost. They reduce shipment profit later.
      </q-banner>

      <q-banner v-if="!canEdit" dense rounded class="bg-grey-2 text-grey-9">
        This shipment is read-only. Local costs cannot be changed.
      </q-banner>

      <q-banner v-else-if="hasDirtyDrafts" dense rounded class="bg-amber-1 text-amber-10">
        You have unsaved local cost changes. Save each line or use Save all below.
      </q-banner>
    </div>

    <div v-if="loading" class="col flex flex-center q-pa-lg min-height-0">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else class="col column no-wrap min-height-0 q-gutter-y-md">
      <div class="row items-center justify-between shrink-0">
        <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
          Local cost lines
        </div>
        <div class="row items-center q-gutter-xs">
          <q-btn
            v-if="!localApBill"
            outline
            dense
            no-caps
            size="xs"
            color="primary"
            icon="ph ph-receipt"
            label="Create bill"
            class="q-px-sm rounded-btn text-weight-bold"
            :loading="apSyncing"
            :disable="!!apSyncing"
            @click="syncLocalApBill"
          />
          <template v-else>
            <q-btn
              outline
              dense
              no-caps
              size="xs"
              color="primary"
              icon="ph ph-arrows-clockwise"
              label="Update"
              class="q-px-sm rounded-btn text-weight-bold"
              :loading="apSyncing"
              :disable="!!apSyncing"
              @click="syncLocalApBill"
            />
            <q-btn
              flat
              dense
              no-caps
              size="xs"
              color="primary"
              :label="localApBill.invoice_no"
              class="text-weight-bold"
              @click="openApBill(localApBill.id)"
            />
          </template>
          <q-btn
            outline
            dense
            no-caps
            size="xs"
            color="primary"
            icon="ph ph-plus"
            label="Add line"
            class="q-px-sm rounded-btn text-weight-bold"
            :disable="!canEdit"
            @click="addDraftRow"
          />
        </div>
      </div>

      <div v-if="drafts.length === 0" class="col flex flex-center text-caption text-grey-6 q-py-md text-center min-height-0">
        No local costs yet. Add labor, van, or packing lines here.
      </div>

      <div v-else class="col column no-wrap min-height-0">
        <div class="col overflow-auto column q-gutter-y-sm min-height-0">
          <div
            v-for="(row, idx) in drafts"
            :key="row.localKey"
            class="q-pa-sm bg-grey-1 rounded-borders border-grey column q-gutter-y-sm shrink-0"
          >
            <div class="row items-center justify-between">
              <span class="text-caption text-weight-bold text-grey-8">Line #{{ idx + 1 }}</span>
              <q-btn
                flat
                round
                dense
                size="xs"
                icon="ph ph-trash"
                color="negative"
                :disable="!canEdit || saving"
                @click="removeRow(row)"
              >
                <q-tooltip>Remove line</q-tooltip>
              </q-btn>
            </div>

            <q-input
              v-model="row.description"
              label="Description *"
              dense
              outlined
              class="bg-white"
              :disable="!canEdit"
            />

            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model.number="row.amount"
                  label="Amount *"
                  type="number"
                  min="0"
                  step="0.01"
                  dense
                  outlined
                  class="bg-white font-mono"
                  :prefix="rowCurrencySymbol(row)"
                  :disable="!canEdit"
                />
              </div>
              <div class="col-6">
                <q-select
                  v-model="row.currency_id"
                  :options="currencyOptions"
                  emit-value
                  map-options
                  clearable
                  label="Currency"
                  dense
                  outlined
                  class="bg-white"
                  :disable="!canEdit"
                  :hint="defaultCurrencyHint"
                />
              </div>
            </div>

            <q-select
              v-model="row.section_id"
              :options="sectionOptions"
              emit-value
              map-options
              clearable
              label="Section (optional)"
              dense
              outlined
              class="bg-white"
              placeholder="Whole shipment"
              :disable="!canEdit"
            />

            <div class="row items-center justify-end q-gutter-x-sm q-pt-xs">
              <q-badge v-if="isRowDirty(row)" color="orange-2" text-color="orange-10" label="Unsaved" />
              <q-btn
                unelevated
                dense
                no-caps
                color="primary"
                label="Save line"
                class="text-weight-bold"
                :disable="!canEdit || saving || !isRowDirty(row)"
                :loading="saving && savingRowKey === row.localKey"
                @click="saveRow(row)"
              />
            </div>
          </div>
        </div>

        <div class="column q-gutter-y-sm shrink-0 q-pt-sm">
          <div class="row items-center justify-between q-pa-sm rounded-borders bg-grey-2 text-caption text-weight-medium">
            <span class="text-grey-8">Total (this tab)</span>
            <span class="font-mono text-grey-9">
              {{ formatMoney(defaultCostSymbol, totalAmountInCostCurrency) }}
            </span>
          </div>
          <q-btn
            v-if="canEdit && hasDirtyDrafts"
            unelevated
            no-caps
            color="primary"
            icon="ph ph-floppy-disk"
            label="Save all changes"
            class="full-width text-weight-bold"
            :loading="saving"
            @click="saveAllDirty"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { ShipmentLocalCostDraft } from '../types/shipmentLocalCost';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  listShipmentApBills,
  syncShipmentApBills,
  type ShipmentApBillRow,
} from '../repositories/shipmentApBillsRepository';
import {
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';

const props = defineProps<{
  shipmentId: number;
  defaultCostCurrencyId: number | null;
  defaultCostSymbol: string;
}>();

const shipmentStore = useGlobalShipmentStore();
const authStore = useAuthStore();
const router = useRouter();
const { data: currenciesData } = useGlobalCurrenciesQuery();
const apBills = ref<ShipmentApBillRow[]>([]);
const apSyncing = ref(false);
const localApBill = computed(() => apBills.value.find((b) => b.ap_kind === 'local') ?? null);

const loadApBills = async () => {
  try {
    apBills.value = await listShipmentApBills(props.shipmentId);
  } catch {
    apBills.value = [];
  }
};

const openApBill = (billId: number) => {
  const tenantSlug = authStore.tenantSlug;
  if (!tenantSlug) return;
  void router.push({
    name: 'app-bill-detail-page',
    params: { tenantSlug, billId: String(billId) },
  });
};

const syncLocalApBill = async () => {
  apSyncing.value = true;
  try {
    const existed = Boolean(localApBill.value);
    await syncShipmentApBills(props.shipmentId);
    await loadApBills();
    const linked = localApBill.value;
    if (!linked) {
      showErrorNotification('Add a local cost line first.');
      return;
    }
    showSuccessNotification(
      existed ? `Bill ${linked.invoice_no} updated` : `Bill ${linked.invoice_no} created`,
    );
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Could not create bill');
  } finally {
    apSyncing.value = false;
  }
};

const loading = computed(() => shipmentStore.localCostsLoading);
const saving = computed(() => shipmentStore.localCostsSaving);

const canEdit = computed(() => {
  const s = shipmentStore.currentShipment;
  if (!s || s.id !== props.shipmentId) return false;
  if (s.status === 'cancelled' || s.is_closed === true) return false;
  return true;
});

const currencyOptions = computed(() =>
  (currenciesData.value ?? []).map((c) => ({
    label: `${c.code} (${c.symbol})`,
    value: c.id,
  })),
);

const sectionOptions = computed(() =>
  shipmentStore.currentShipmentSections.map((sec) => ({
    label: sec.title || `Section #${sec.id}`,
    value: sec.id,
  })),
);

const defaultCurrencyHint = computed(() =>
  `Empty uses shipment cost currency (${props.defaultCostSymbol})`,
);

const newLocalKey = () => `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

const drafts = ref<ShipmentLocalCostDraft[]>([]);
const savingRowKey = ref<string | null>(null);

const rowToDraft = (row: {
  id: number;
  description: string;
  amount: number;
  section_id: number | null;
  currency_id: number | null;
}): ShipmentLocalCostDraft => ({
  localKey: `id-${row.id}`,
  id: row.id,
  description: row.description,
  amount: Number(row.amount),
  section_id: row.section_id,
  currency_id: row.currency_id,
});

const isRowDirty = (row: ShipmentLocalCostDraft) => {
  const trimmed = row.description.trim();
  const amount = row.amount;

  if (!row.id) {
    return Boolean(trimmed) || (amount != null && amount !== 0);
  }

  const saved = shipmentStore.currentLocalCosts.find((r) => r.id === row.id);
  if (!saved) return true;

  return (
    trimmed !== saved.description.trim() ||
    Number(amount) !== Number(saved.amount) ||
    (row.section_id ?? null) !== (saved.section_id ?? null) ||
    (row.currency_id ?? null) !== (saved.currency_id ?? null)
  );
};

const hasDirtyDrafts = computed(() => drafts.value.some((row) => isRowDirty(row)));

const syncDraftsFromStore = () => {
  if (saving.value || hasDirtyDrafts.value) return;
  const rows = shipmentStore.currentLocalCosts ?? [];
  drafts.value = rows.length ? rows.map(rowToDraft) : [];
};

watch(
  () => shipmentStore.currentLocalCosts,
  () => syncDraftsFromStore(),
  { immediate: true, deep: true },
);

watch(
  () => props.shipmentId,
  (id) => {
    if (id && !Number.isNaN(id)) {
      void shipmentStore.fetchLocalCosts(id).catch(() => undefined);
      void loadApBills();
    }
  },
  { immediate: true },
);

const emptyDraft = (): ShipmentLocalCostDraft => ({
  localKey: newLocalKey(),
  id: null,
  description: '',
  amount: null,
  section_id: null,
  currency_id: null,
});

const addDraftRow = () => {
  drafts.value.push(emptyDraft());
};

const currencySymbolForId = (currencyId: number | null) => {
  if (!currencyId) return props.defaultCostSymbol;
  const c = (currenciesData.value ?? []).find((x) => x.id === currencyId);
  return c?.symbol ?? props.defaultCostSymbol;
};

const rowCurrencySymbol = (row: ShipmentLocalCostDraft) => currencySymbolForId(row.currency_id);

const formatMoney = (symbol: string, value: number) =>
  `${symbol}${value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

/** Rough sum for display — rows without FX use amount as-is in cost currency. */
const totalAmountInCostCurrency = computed(() =>
  drafts.value.reduce((sum, row) => sum + (Number(row.amount) || 0), 0),
);

const saveRow = async (row: ShipmentLocalCostDraft) => {
  if (!canEdit.value || saving.value) return;
  if (!isRowDirty(row)) return;

  const trimmed = row.description.trim();
  const amount = row.amount;
  if (!trimmed) {
    showErrorNotification('Description is required');
    return;
  }
  if (amount == null || amount < 0) {
    showErrorNotification('Amount must be ≥ 0');
    return;
  }

  savingRowKey.value = row.localKey;
  try {
    const saved = await shipmentStore.saveShipmentLocalCost(props.shipmentId, {
      id: row.id,
      description: trimmed,
      amount: Number(amount),
      section_id: row.section_id,
      currency_id: row.currency_id,
    });
    row.id = saved.id;
    row.localKey = `id-${saved.id}`;
    row.description = saved.description;
    row.amount = Number(saved.amount);
    row.section_id = saved.section_id;
    row.currency_id = saved.currency_id;
    showSuccessNotification('Local cost saved');
    void loadApBills();
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to save local cost');
  } finally {
    savingRowKey.value = null;
  }
};

const saveAllDirty = async () => {
  const dirty = drafts.value.filter((row) => isRowDirty(row));
  for (const row of dirty) {
    await saveRow(row);
  }
};

const removeRow = async (row: ShipmentLocalCostDraft) => {
  if (!canEdit.value) return;
  if (!row.id) {
    drafts.value = drafts.value.filter((d) => d.localKey !== row.localKey);
    return;
  }
  try {
    await shipmentStore.deleteShipmentLocalCost(row.id);
    drafts.value = drafts.value.filter((d) => d.localKey !== row.localKey);
    showSuccessNotification('Local cost removed');
    void loadApBills();
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to remove local cost');
  }
};
</script>
