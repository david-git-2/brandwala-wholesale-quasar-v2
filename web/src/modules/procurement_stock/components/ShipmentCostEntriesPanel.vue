<template>
  <q-card flat bordered class="q-pa-md bg-white text-grey-9">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="text-subtitle1 text-weight-bold text-primary">Cost entries</div>
        <div class="text-caption text-grey-6">
          Enter product and cargo rates. Cargo weight is set on Match invoices.
        </div>
      </div>
      <q-badge v-if="isFinalized" color="orange" outline label="Revision mode" />
    </div>

    <q-banner v-if="isFinalized && canEdit" dense rounded class="bg-orange-1 text-orange-10 q-mb-md">
      Stock is already in. Saving updates item costs only — it does not pay anyone.
    </q-banner>

    <div v-if="loading" class="q-pa-md flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else class="column q-gutter-y-md">
      <!-- Product section -->
      <div class="cost-section" data-test="cost-section-product">
        <div class="row items-center justify-between q-mb-sm">
          <div class="text-subtitle2 text-weight-bold text-grey-8">Product</div>
          <q-btn
            v-if="canEdit"
            flat
            dense
            no-caps
            size="sm"
            color="primary"
            icon="ph ph-plus"
            label="Add rate"
            data-test="cost-entry-add-product"
            @click="addRow('product')"
          />
        </div>
        <div class="column q-gutter-y-sm">
          <div
            v-for="(row, idx) in productRows"
            :key="row.localKey"
            class="cost-entry-row q-pa-sm rounded-borders"
            data-test="cost-entry-row-product"
          >
            <div class="row items-center justify-between q-mb-xs">
              <span class="text-caption text-grey-6">Rate {{ idx + 1 }}</span>
              <q-btn
                v-if="canEdit && productRows.length > 1"
                flat
                dense
                round
                size="sm"
                icon="ph ph-trash"
                color="negative"
                data-test="cost-entry-remove"
                @click="removeRow(row.localKey)"
              >
                <q-tooltip>Remove rate</q-tooltip>
              </q-btn>
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="row.amount"
                  type="number"
                  step="0.01"
                  min="0"
                  label="Amount *"
                  dense
                  outlined
                  class="soft-input"
                  :prefix="purchaseCurrencySymbol"
                  :disable="!canEdit"
                  hint="Purchase currency total for this FX slice"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="row.exchange_rate"
                  type="number"
                  step="0.0001"
                  min="0.0001"
                  label="Exchange rate → BDT *"
                  dense
                  outlined
                  class="soft-input"
                  :disable="!canEdit || isLocalShipment"
                  :hint="isLocalShipment ? 'Forced to 1.00 for local' : 'Rate to base currency'"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-select
                  v-model="row.payment_source"
                  :options="paymentSourceOptions"
                  label="Payment source"
                  dense
                  outlined
                  clearable
                  emit-value
                  map-options
                  class="soft-input"
                  :disable="!canEdit"
                  hint="Settlement intent only"
                />
              </div>
            </div>
            <div class="row q-col-gutter-sm q-mt-sm">
              <div class="col-12 col-sm-4">
                <q-select
                  :model-value="row.entity_type"
                  :options="payeeTypeOptions"
                  label="Payee type"
                  dense
                  outlined
                  clearable
                  emit-value
                  map-options
                  class="soft-input"
                  :disable="!canEdit"
                  hint="Who will be paid (optional)"
                  data-test="cost-entry-payee-type"
                  @update:model-value="(v) => onPayeeTypeChange(row, v)"
                />
              </div>
              <div class="col-12 col-sm-8">
                <q-select
                  v-model="row.entity_id"
                  :options="payeeOptionsFor(row.entity_type)"
                  label="Payee"
                  dense
                  outlined
                  clearable
                  emit-value
                  map-options
                  use-input
                  fill-input
                  hide-selected
                  input-debounce="0"
                  class="soft-input"
                  :disable="!canEdit || !row.entity_type"
                  :loading="payeeLoading"
                  hint="Null = costing only"
                  data-test="cost-entry-payee-id"
                  @filter="(val, update) => filterPayeeOptions(row.entity_type, val, update)"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Cargo section -->
      <div class="cost-section" data-test="cost-section-cargo">
        <div class="row items-center justify-between q-mb-sm">
          <div class="text-subtitle2 text-weight-bold text-grey-8">Cargo</div>
          <q-btn
            v-if="canEdit"
            flat
            dense
            no-caps
            size="sm"
            color="primary"
            icon="ph ph-plus"
            label="Add rate"
            data-test="cost-entry-add-cargo"
            @click="addRow('cargo')"
          />
        </div>

        <div class="row q-col-gutter-sm q-mb-sm items-end">
          <div class="col-12 col-sm-4">
            <q-input
              :model-value="cargoKg > 0 ? cargoKg : null"
              type="number"
              label="Cargo weight (kg)"
              dense
              outlined
              class="soft-input"
              suffix="kg"
              readonly
              hint="Edit on Match invoices"
              data-test="cost-entry-weight"
            />
          </div>
          <div class="col-12 col-sm-4">
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              icon="ph ph-scales"
              label="Edit on Match invoices"
              class="q-mt-xs"
              data-test="cost-go-match-invoices"
              @click="emit('go-match-invoices')"
            />
          </div>
          <div class="col-12 col-sm-4 flex flex-center">
            <div class="text-caption text-grey-6 full-width">
              Per-kg = freight amount ÷ weight (computed per row)
            </div>
          </div>
        </div>

        <div class="column q-gutter-y-sm">
          <div
            v-for="(row, idx) in cargoRows"
            :key="row.localKey"
            class="cost-entry-row q-pa-sm rounded-borders"
            data-test="cost-entry-row-cargo"
          >
            <div class="row items-center justify-between q-mb-xs">
              <span class="text-caption text-grey-6">Rate {{ idx + 1 }}</span>
              <q-btn
                v-if="canEdit && cargoRows.length > 1"
                flat
                dense
                round
                size="sm"
                icon="ph ph-trash"
                color="negative"
                data-test="cost-entry-remove"
                @click="removeRow(row.localKey)"
              >
                <q-tooltip>Remove rate</q-tooltip>
              </q-btn>
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-3">
                <q-input
                  v-model.number="row.amount"
                  type="number"
                  step="0.01"
                  min="0"
                  label="Freight total *"
                  dense
                  outlined
                  class="soft-input"
                  :prefix="purchaseCurrencySymbol"
                  :disable="!canEdit"
                />
              </div>
              <div class="col-12 col-sm-3">
                <q-input
                  :model-value="formatPerKg(row.amount)"
                  label="Per-kg (computed)"
                  dense
                  outlined
                  class="soft-input"
                  :prefix="purchaseCurrencySymbol"
                  readonly
                  :hint="cargoKg > 0 ? 'amount ÷ weight' : 'Set weight on Match invoices'"
                />
              </div>
              <div class="col-12 col-sm-3">
                <q-input
                  v-model.number="row.exchange_rate"
                  type="number"
                  step="0.0001"
                  min="0.0001"
                  label="Exchange rate → BDT *"
                  dense
                  outlined
                  class="soft-input"
                  :disable="!canEdit || isLocalShipment"
                  :hint="isLocalShipment ? 'Forced to 1.00 for local' : undefined"
                />
              </div>
              <div class="col-12 col-sm-3">
                <q-select
                  v-model="row.payment_source"
                  :options="paymentSourceOptions"
                  label="Payment source"
                  dense
                  outlined
                  clearable
                  emit-value
                  map-options
                  class="soft-input"
                  :disable="!canEdit"
                  hint="Settlement intent only"
                />
              </div>
            </div>
            <div class="row q-col-gutter-sm q-mt-sm">
              <div class="col-12 col-sm-4">
                <q-select
                  :model-value="row.entity_type"
                  :options="payeeTypeOptions"
                  label="Payee type"
                  dense
                  outlined
                  clearable
                  emit-value
                  map-options
                  class="soft-input"
                  :disable="!canEdit"
                  hint="Who will be paid (optional)"
                  data-test="cost-entry-payee-type"
                  @update:model-value="(v) => onPayeeTypeChange(row, v)"
                />
              </div>
              <div class="col-12 col-sm-8">
                <q-select
                  v-model="row.entity_id"
                  :options="payeeOptionsFor(row.entity_type)"
                  label="Payee"
                  dense
                  outlined
                  clearable
                  emit-value
                  map-options
                  use-input
                  fill-input
                  hide-selected
                  input-debounce="0"
                  class="soft-input"
                  :disable="!canEdit || !row.entity_type"
                  :loading="payeeLoading"
                  hint="Null = costing only"
                  data-test="cost-entry-payee-id"
                  @filter="(val, update) => filterPayeeOptions(row.entity_type, val, update)"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="text-caption text-grey-5">
        Stub types (duty, insurance, labor, …) are reserved — not shown day one.
      </div>

      <div class="row justify-end q-gutter-sm">
        <q-btn
          v-if="canEdit"
          flat
          no-caps
          color="grey-8"
          label="Reset"
          :disable="saving"
          @click="resetDrafts"
        />
        <q-btn
          v-if="canEdit"
          color="primary"
          unelevated
          no-caps
          :label="isFinalized ? 'Revise & re-stamp' : 'Save cost entries'"
          :loading="saving"
          data-test="cost-entry-save"
          @click="onSave"
        />
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import type {
  CostEntryDraft,
  CostEntriesSavePayload,
  GlobalShipmentCostEntry,
  ShipmentCostPayeeType,
  ShipmentCostPaymentSource,
} from '../types/shipmentCostEntry';
import { showErrorNotification } from 'src/utils/appFeedback';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useCargoCompanyStore } from '../stores/cargoCompanyStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

const props = defineProps<{
  entries: GlobalShipmentCostEntry[];
  loading?: boolean;
  saving?: boolean;
  canEdit: boolean;
  isFinalized: boolean;
  isLocalShipment: boolean;
  /** Initial cargo invoice weight from shipment header */
  cargoKg: number;
  purchaseCurrencySymbol: string;
  costCurrencySymbol: string;
}>();

const emit = defineEmits<{
  save: [payload: CostEntriesSavePayload];
  'go-match-invoices': [];
}>();

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const cargoCompanyStore = useCargoCompanyStore();
const shipmentStore = useGlobalShipmentStore();

const drafts = ref<CostEntryDraft[]>([]);
const payeeLoading = ref(false);
const vendorFilter = ref('');
const cargoFilter = ref('');

const paymentSourceOptions = [
  { label: 'Cash', value: 'cash' as ShipmentCostPaymentSource },
  { label: 'Credit', value: 'credit' as ShipmentCostPaymentSource },
  { label: 'Wallet', value: 'wallet' as ShipmentCostPaymentSource },
];

const payeeTypeOptions = [
  { label: 'Vendor', value: 'vendor' as ShipmentCostPayeeType },
  { label: 'Cargo company', value: 'cargo_company' as ShipmentCostPayeeType },
];

const allVendorOptions = computed(() =>
  vendorStore.items.map((v) => ({ label: `${v.name} (${v.code})`, value: v.id })),
);

const allCargoOptions = computed(() =>
  cargoCompanyStore.items.map((c) => ({ label: c.name, value: c.id })),
);

const filteredVendorOptions = computed(() => {
  const q = vendorFilter.value.trim().toLowerCase();
  if (!q) return allVendorOptions.value;
  return allVendorOptions.value.filter((o) => o.label.toLowerCase().includes(q));
});

const filteredCargoOptions = computed(() => {
  const q = cargoFilter.value.trim().toLowerCase();
  if (!q) return allCargoOptions.value;
  return allCargoOptions.value.filter((o) => o.label.toLowerCase().includes(q));
});

const payeeOptionsFor = (entityType: ShipmentCostPayeeType | null) => {
  if (entityType === 'vendor') return filteredVendorOptions.value;
  if (entityType === 'cargo_company') return filteredCargoOptions.value;
  return [];
};

const filterPayeeOptions = (
  entityType: ShipmentCostPayeeType | null,
  val: string,
  update: (fn: () => void) => void,
) => {
  update(() => {
    if (entityType === 'vendor') vendorFilter.value = val;
    else if (entityType === 'cargo_company') cargoFilter.value = val;
  });
};

const parsePayeeType = (raw: string | null | undefined): ShipmentCostPayeeType | null => {
  if (raw === 'vendor' || raw === 'cargo_company') return raw;
  return null;
};

const productRows = computed(() => drafts.value.filter((d) => d.cost_type === 'product'));
const cargoRows = computed(() => drafts.value.filter((d) => d.cost_type === 'cargo'));

const weightKg = computed(() =>
  props.cargoKg > 0 ? Math.round(props.cargoKg * 100) / 100 : 0,
);

const newLocalKey = () => `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

const emptyRow = (costType: 'product' | 'cargo'): CostEntryDraft => {
  const ship = shipmentStore.currentShipment;
  let entity_type: ShipmentCostPayeeType | null = null;
  let entity_id: number | null = null;
  if (costType === 'product' && ship?.vendor_id) {
    entity_type = 'vendor';
    entity_id = ship.vendor_id;
  } else if (costType === 'cargo' && ship?.cargo_company_id) {
    entity_type = 'cargo_company';
    entity_id = ship.cargo_company_id;
  }
  return {
    localKey: newLocalKey(),
    id: null,
    cost_type: costType,
    amount: 0,
    exchange_rate: 1,
    payment_source: null,
    entity_type,
    entity_id,
    per_kg_rate: null,
  };
};

const onPayeeTypeChange = (row: CostEntryDraft, value: ShipmentCostPayeeType | null) => {
  if ((value as string) === 'shipment') {
    showErrorNotification("Payee cannot be 'shipment'");
    return;
  }
  row.entity_type = value;
  row.entity_id = null;
  vendorFilter.value = '';
  cargoFilter.value = '';
};

const computedPerKg = (amount: number): number | null => {
  const w = weightKg.value;
  const a = Number(amount);
  if (!Number.isFinite(w) || w <= 0 || !Number.isFinite(a)) return null;
  return Math.round((a / w) * 10000) / 10000;
};

const formatPerKg = (amount: number): string => {
  const v = computedPerKg(amount);
  if (v == null) return '—';
  return v.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 });
};

const entryToDraft = (entry: GlobalShipmentCostEntry): CostEntryDraft => ({
  localKey: `id-${entry.id}`,
  id: entry.id,
  cost_type: entry.cost_type,
  amount: Number(entry.amount) || 0,
  exchange_rate: props.isLocalShipment ? 1 : Number(entry.exchange_rate) || 1,
  payment_source: (entry.payment_source as ShipmentCostPaymentSource | null) ?? null,
  entity_type: parsePayeeType(entry.entity_type),
  entity_id: entry.entity_id ?? null,
  per_kg_rate: null,
});

const ensureDayOneShape = (rows: CostEntryDraft[]): CostEntryDraft[] => {
  const next = [...rows];
  if (!next.some((r) => r.cost_type === 'product')) next.push(emptyRow('product'));
  if (!next.some((r) => r.cost_type === 'cargo')) next.push(emptyRow('cargo'));
  return next;
};

const resetDrafts = () => {
  if (!props.entries.length) {
    drafts.value = [emptyRow('product'), emptyRow('cargo')];
    return;
  }
  const mapped = props.entries
    .filter((e) => e.cost_type === 'product' || e.cost_type === 'cargo')
    .map(entryToDraft);
  drafts.value = ensureDayOneShape(mapped);
};

watch(
  () => props.entries,
  () => resetDrafts(),
  { immediate: true, deep: true },
);

watch(
  () => props.isLocalShipment,
  (local) => {
    if (!local) return;
    for (const row of drafts.value) {
      row.exchange_rate = 1;
    }
  },
);

const addRow = (costType: 'product' | 'cargo') => {
  drafts.value.push(emptyRow(costType));
};

const removeRow = (localKey: string) => {
  const row = drafts.value.find((d) => d.localKey === localKey);
  if (!row) return;
  const sameType = drafts.value.filter((d) => d.cost_type === row.cost_type);
  if (sameType.length <= 1) return;
  drafts.value = drafts.value.filter((d) => d.localKey !== localKey);
};

const onSave = () => {
  for (const row of drafts.value) {
    if (row.amount == null || row.amount < 0) {
      showErrorNotification('Amount must be ≥ 0');
      return;
    }
    if (!row.exchange_rate || row.exchange_rate <= 0) {
      showErrorNotification('Exchange rate must be > 0');
      return;
    }
    if (row.entity_type === ('shipment' as ShipmentCostPayeeType)) {
      showErrorNotification("Payee cannot be 'shipment'");
      return;
    }
    if (row.entity_type && row.entity_id == null) {
      showErrorNotification('Select a payee or clear payee type');
      return;
    }
    if (!row.entity_type && row.entity_id != null) {
      showErrorNotification('Payee id requires a payee type');
      return;
    }
  }

  if (!productRows.value.length || !cargoRows.value.length) {
    showErrorNotification('Day one requires at least one product and one cargo rate.');
    return;
  }

  const draftsOut = drafts.value.map((d) => {
    const perKg = d.cost_type === 'cargo' ? computedPerKg(d.amount) : null;
    return {
      ...d,
      exchange_rate: props.isLocalShipment ? 1 : d.exchange_rate,
      per_kg_rate: perKg,
      entity_type: d.entity_type,
      entity_id: d.entity_type ? d.entity_id : null,
    };
  });

  const w = weightKg.value;
  emit('save', {
    drafts: draftsOut,
    // Weight is edited on Match invoices only — pass through current header value
    received_weight: w > 0 ? w : null,
  });
};

onMounted(async () => {
  if (!authStore.tenantId) return;
  payeeLoading.value = true;
  try {
    await Promise.all([
      vendorStore.items.length
        ? Promise.resolve()
        : vendorStore.fetchVendors(authStore.tenantId, true),
      cargoCompanyStore.items.length
        ? Promise.resolve()
        : cargoCompanyStore.fetchCompanies(authStore.tenantId, true),
    ]);
  } catch {
    // Options stay empty; payee can remain null
  } finally {
    payeeLoading.value = false;
  }
});

defineExpose({ resetDrafts });
</script>

<style scoped>
.cost-section {
  padding: 0.75rem;
  border: 1px solid color-mix(in srgb, var(--bw-theme-border, #e0e0e0) 100%, transparent);
  border-radius: 10px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, var(--bw-theme-base, #f5f5f5));
}

.cost-entry-row {
  border: 1px solid color-mix(in srgb, var(--bw-theme-border, #e0e0e0) 80%, transparent);
  background: var(--bw-theme-surface, #fff);
}
</style>
