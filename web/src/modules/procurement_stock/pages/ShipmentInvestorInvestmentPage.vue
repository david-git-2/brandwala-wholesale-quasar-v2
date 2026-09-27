<template>
  <q-page class="q-pa-md column q-gutter-y-md">
    <div class="row items-start justify-between q-col-gutter-md">
      <div class="row q-col-gutter-lg">
        <div>
          <div class="text-caption text-grey-7">Shipment total (GBP)</div>
          <div class="text-h6 text-weight-bold font-mono">{{ formattedPurchaseTotal }}</div>
        </div>
        <div>
          <div class="text-caption text-grey-7">Shipment total (BDT)</div>
          <div class="text-h6 text-weight-bold font-mono text-primary">{{ formattedBdtTotal }}</div>
        </div>
      </div>
      <q-btn
        color="primary"
        icon="ph ph-plus"
        label="Add investment"
        unelevated
        no-caps
        class="rounded-sq-btn text-weight-bold"
        :disable="capitalStore.saving || !investorOptions.length"
        @click="openAddDialog"
      />
    </div>

    <q-markup-table flat bordered wrap-cells class="bg-white">
      <thead>
        <tr>
          <th class="text-left">Investor</th>
          <th class="text-right">Amount (BDT)</th>
          <th class="text-right">Cost share</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="capitalStore.loadingTransactions">
          <td colspan="3" class="text-center text-grey-7">Loading…</td>
        </tr>
        <tr v-else-if="!capitalStore.shipmentInvestments.length">
          <td colspan="3" class="text-center text-grey-7">No investor allocations yet.</td>
        </tr>
        <tr v-for="row in capitalStore.shipmentInvestments" :key="row.id">
          <td class="text-left">{{ investorNameById(row.investor_id) }}</td>
          <td class="text-right">{{ formatAmount(displayRowAmount(row)) }}</td>
          <td class="text-right">{{ formatPct(row.cost_share_pct) }}</td>
        </tr>
      </tbody>
    </q-markup-table>

    <q-dialog v-model="addDialogOpen" persistent>
      <q-card style="min-width: 400px; max-width: 95vw">
        <q-card-section>
          <div class="text-h6">Add investment</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-select
            v-model="selectedInvestorId"
            outlined
            dense
            emit-value
            map-options
            clearable
            label="Investor"
            :options="investorOptions"
            :loading="capitalStore.loadingInvestors"
            :disable="capitalStore.saving"
          />
          <q-input
            v-model.number="amount"
            outlined
            dense
            type="number"
            min="0"
            step="0.01"
            label="Amount (BDT)"
            :disable="capitalStore.saving"
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" no-caps :disable="capitalStore.saving" @click="closeAddDialog" />
          <q-btn
            color="primary"
            label="Add"
            unelevated
            no-caps
            :loading="capitalStore.saving"
            :disable="!canAdd"
            @click="onAdd"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useInvestorCapitalStore } from 'src/modules/investor_capital/stores/investorCapitalStore';
import { useGlobalShipmentStore } from 'src/modules/procurement_stock/stores/globalShipmentStore';
import { useInboundShipmentCalculations } from 'src/modules/procurement_stock/composables/useInboundShipmentCalculations';
import type { ShipmentInvestment } from 'src/modules/investor_capital/types';
import { formatAmountBdt } from 'src/utils/currency';
import { showErrorNotification } from 'src/utils/appFeedback';

const route = useRoute();
const authStore = useAuthStore();
const capitalStore = useInvestorCapitalStore();
const shipmentStore = useGlobalShipmentStore();
const { totals, currentPurchaseCurrencySymbol } = useInboundShipmentCalculations();

const addDialogOpen = ref(false);
const selectedInvestorId = ref<number | null>(null);
const amount = ref<number | null>(null);

const shipmentId = computed(() => {
  const parsed = Number(route.params.id);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
});

const totalShipmentCostBdt = computed(() => Number(totals.value.totalCost) || 0);

const formatMoney = (symbol: string, value: number | null | undefined) => {
  const n = Number(value) || 0;
  return `${symbol}${n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
};

const formattedPurchaseTotal = computed(() =>
  formatMoney(currentPurchaseCurrencySymbol.value, totals.value.totalPurchase),
);

const formattedBdtTotal = computed(() => `BDT ${formatAmountBdt(totalShipmentCostBdt.value)}`);

const parentRemainderPct = computed(() => {
  const sum = capitalStore.shipmentInvestments.reduce(
    (acc, item) => acc + Number(item.cost_share_pct ?? 0),
    0,
  );
  return Math.max(0, 100 - sum);
});

const allocatedInvestorIds = computed(
  () => new Set(capitalStore.shipmentInvestments.map((row) => row.investor_id)),
);

const investorOptions = computed(() =>
  capitalStore.investors
    .filter((item) => !allocatedInvestorIds.value.has(item.investor_id))
    .map((item) => ({
      label: item.name,
      value: item.investor_id,
    })),
);

const canAdd = computed(() => {
  const amt = Number(amount.value);
  return (
    selectedInvestorId.value != null &&
    selectedInvestorId.value > 0 &&
    Number.isFinite(amt) &&
    amt > 0 &&
    !capitalStore.saving
  );
});

const resetAddForm = () => {
  selectedInvestorId.value = null;
  amount.value = null;
};

const openAddDialog = () => {
  resetAddForm();
  addDialogOpen.value = true;
};

const closeAddDialog = () => {
  addDialogOpen.value = false;
  resetAddForm();
};

const formatAmount = (value: number | null | undefined) => formatAmountBdt(value);

const formatPct = (value: number | null | undefined) => {
  const n = Number(value ?? 0);
  return `${n.toFixed(2)}%`;
};

const investorNameById = (investorId: number) =>
  capitalStore.investors.find((item) => item.investor_id === investorId)?.name ?? `#${investorId}`;

const displayRowAmount = (row: ShipmentInvestment) => {
  const invested = Number(row.invested_amount ?? 0);
  const allocated = Number(row.allocated_cost ?? 0);
  if (invested > 0) return invested;
  if (allocated > 0) return allocated;
  const pct = Number(row.cost_share_pct ?? 0);
  if (totalShipmentCostBdt.value > 0 && pct > 0) {
    return (totalShipmentCostBdt.value * pct) / 100;
  }
  return 0;
};

const onAdd = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId || !shipmentId.value) {
    showErrorNotification('Tenant or shipment is missing.');
    return;
  }

  const investorId = selectedInvestorId.value;
  const amt = Number(amount.value);
  if (!investorId || !Number.isFinite(amt) || amt <= 0) {
    showErrorNotification('Choose an investor and enter a positive amount.');
    return;
  }

  if (totalShipmentCostBdt.value <= 0) {
    showErrorNotification('Shipment cost is not available yet. Add line items and costing first.');
    return;
  }

  const costSharePct = Number(((amt / totalShipmentCostBdt.value) * 100).toFixed(4));
  if (costSharePct <= 0) {
    showErrorNotification('Amount is too small for this shipment cost.');
    return;
  }
  if (costSharePct > parentRemainderPct.value) {
    showErrorNotification(
      `Amount exceeds remaining share (${parentRemainderPct.value.toFixed(2)}% left on this shipment).`,
    );
    return;
  }

  const result = await capitalStore.upsertShipmentInvestment({
    tenant_id: tenantId,
    global_shipment_id: shipmentId.value,
    investor_id: investorId,
    cost_share_pct: costSharePct,
  });

  if (result?.success) {
    closeAddDialog();
  }
};

const load = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId || !shipmentId.value) return;

  await Promise.all([
    shipmentStore.fetchShipmentDetails(shipmentId.value),
    capitalStore.fetchInvestorsByTenant(tenantId),
    capitalStore.fetchShipmentInvestmentsByShipment(tenantId, shipmentId.value),
  ]);
};

onMounted(() => {
  void load();
});
</script>
