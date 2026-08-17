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
              <div class="col-12 col-sm-6">
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
              <div class="col-12 col-sm-6">
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
              <div class="col-12 col-sm-4">
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
              <div class="col-12 col-sm-4">
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
                  :hint="isLocalShipment ? 'Forced to 1.00 for local' : undefined"
                />
              </div>
            </div>
          </div>
        </div>
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

      <!-- Mounted ShipmentPayeeSettlePanel -->
      <ShipmentPayeeSettlePanel
        v-if="shipmentStore.currentShipment"
        ref="payeeSettlePanelRef"
        :shipment-id="shipmentStore.currentShipment.id"
        :status="shipmentStore.currentShipment.status"
        :vendor-id="shipmentStore.currentShipment.vendor_id"
        :cargo-company-id="shipmentStore.currentShipment.cargo_company_id"
        :vendor-name="vendorPayeeLabel"
        :cargo-company-name="cargoPayeeLabel"
        :vendor-rate="firstProductRate"
        :cargo-rate="firstCargoRate"
        :purchase-currency-symbol="purchaseCurrencySymbol"
        :submitting="paySettling"
        :vendor-product-total="vendorProductTotal"
        :cargo-cost-total="cargoCostTotal"
        :goods-purchase-total="goodsPurchaseTotal"
        @settle="(payload) => emit('settle', payload)"
      />
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
import ShipmentPayeeSettlePanel from './ShipmentPayeeSettlePanel.vue';

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
  goodsPurchaseTotal?: number;
  goodsQuantityTotal?: number;
  paySettling?: boolean;
}>();

const emit = defineEmits<{
  save: [payload: CostEntriesSavePayload];
  settle: [
    payload: {
      entityType: 'vendor' | 'cargo_company';
      entityId: number;
      action: 'pay' | 'record_credit' | 'use_credit';
      amount: number;
      exchangeRate: number;
    },
  ];
  'go-match-invoices': [];
}>();

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const cargoCompanyStore = useCargoCompanyStore();
const shipmentStore = useGlobalShipmentStore();

const drafts = ref<CostEntryDraft[]>([]);
const payeeSettlePanelRef = ref<InstanceType<typeof ShipmentPayeeSettlePanel> | null>(null);

const productRows = computed(() => drafts.value.filter((d) => d.cost_type === 'product'));
const cargoRows = computed(() => drafts.value.filter((d) => d.cost_type === 'cargo'));

const vendorProductTotal = computed(() =>
  productRows.value.reduce((sum, r) => sum + (Number(r.amount) || 0), 0),
);

const cargoCostTotal = computed(() =>
  cargoRows.value.reduce((sum, r) => sum + (Number(r.amount) || 0), 0),
);

const firstProductRate = computed(() => {
  const p = productRows.value[0];
  return p ? Number(p.exchange_rate) || 1.0 : 1.0;
});

const firstCargoRate = computed(() => {
  const c = cargoRows.value[0];
  return c ? Number(c.exchange_rate) || 1.0 : 1.0;
});

const vendorPayeeLabel = computed(() => {
  const vendorId = shipmentStore.currentShipment?.vendor_id;
  if (!vendorId) return 'Vendor';
  const match = vendorStore.items.find((v) => v.id === vendorId);
  return match ? `${match.name} (${match.code})` : `Vendor #${vendorId}`;
});

const cargoPayeeLabel = computed(() => {
  const cargoId = shipmentStore.currentShipment?.cargo_company_id;
  if (!cargoId) return 'Cargo Agent';
  const match = cargoCompanyStore.items.find((c) => c.id === cargoId);
  return match ? match.name : `Cargo Agent #${cargoId}`;
});

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
  payment_source: null,
  entity_type: entry.cost_type === 'product' ? 'vendor' : 'cargo_company',
  entity_id: entry.cost_type === 'product'
    ? (shipmentStore.currentShipment?.vendor_id ?? null)
    : (shipmentStore.currentShipment?.cargo_company_id ?? null),
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
  }

  if (!productRows.value.length || !cargoRows.value.length) {
    showErrorNotification('Day one requires at least one product and one cargo rate.');
    return;
  }

  const draftsOut = drafts.value.map((d) => {
    const perKg = d.cost_type === 'cargo' ? computedPerKg(d.amount) : null;
    const isProduct = d.cost_type === 'product';
    const entType = isProduct ? 'vendor' : 'cargo_company';
    const entId = isProduct
      ? (shipmentStore.currentShipment?.vendor_id ?? null)
      : (shipmentStore.currentShipment?.cargo_company_id ?? null);
    return {
      ...d,
      exchange_rate: props.isLocalShipment ? 1 : d.exchange_rate,
      per_kg_rate: perKg,
      payment_source: null,
      entity_type: entType as ShipmentCostPayeeType,
      entity_id: entId,
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
    // ignore
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
