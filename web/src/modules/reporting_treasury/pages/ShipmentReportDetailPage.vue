<template>
  <FinanceReportFrame
    :loading="isLoading"
    :error="error ? (error as Error).message : null"
    @refresh="() => refetch()"
  >
    <template #filters>
      <q-btn
        flat
        dense
        no-caps
        color="primary"
        icon="ph ph-arrow-left"
        label="Back"
        :to="listRoute"
      />
      <span v-if="detail?.header?.shipment_name" class="text-subtitle2 text-weight-bold q-ml-sm ellipsis">
        {{ detail.header.shipment_name }}
      </span>
    </template>

    <template #toolbar-actions>
      <q-btn
        v-if="canOpenProcurement"
        flat
        dense
        no-caps
        size="sm"
        color="grey-8"
        icon="ph ph-package"
        label="Open shipment"
        :to="procurementShipmentRoute"
      />
    </template>

    <div v-if="!isLoading && detail" class="detail-scroll">
      <div class="detail-inner column q-gutter-y-md">
        <ShipmentReportProfitSection
          variant="hero"
          :matrix="matrix"
          :warehouse-value-bdt="qty.warehouse_value_bdt"
        />
        <ShipmentReportSnapshot v-if="detail.header?.shipment_id" :header="detail.header" />
        <ShipmentReportQtySection :qty="qty" :items="pnlItems" />
        <ShipmentReportCostInSection
          :ap-bills="detail.ap_bills"
          :cost-buckets="detail.cost_buckets"
          :exchange-rates="detail.exchange_rates"
          :can-view-bills="canViewBills"
          :bill-route="billRoute"
        />
        <ShipmentReportSalesOutSection
          :customer-bills="detail.customer_bills"
          :sell-lines="detail.sell_lines"
          :unpaid-customers="detail.unpaid_customers"
          :unpaid-total-bdt="matrix.unpaid_total_bdt"
          :can-view-bills="canViewBills"
          :bill-route="billRoute"
        />
      </div>
    </div>
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import ShipmentReportSnapshot from '../components/shipmentReport/ShipmentReportSnapshot.vue';
import ShipmentReportQtySection from '../components/shipmentReport/ShipmentReportQtySection.vue';
import ShipmentReportCostInSection from '../components/shipmentReport/ShipmentReportCostInSection.vue';
import ShipmentReportSalesOutSection from '../components/shipmentReport/ShipmentReportSalesOutSection.vue';
import ShipmentReportProfitSection from '../components/shipmentReport/ShipmentReportProfitSection.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShipmentReportDetail } from '../composables/useShipmentReportDetail';

const route = useRoute();
const authStore = useAuthStore();
const { tenantSlug } = storeToRefs(authStore);

const shipmentId = computed(() => {
  const raw = route.params.shipmentId;
  const n = typeof raw === 'string' ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(n) && n > 0 ? n : null;
});

const { detail, isLoading, error, refetch } = useShipmentReportDetail(shipmentId);

const qty = computed(() => detail.value?.qty_summary ?? {
  should_arrive: 0,
  arrived: 0,
  loss_at_shipment: 0,
  warehouse_stalled: 0,
  warehouse_remaining: 0,
  sold: 0,
  warehouse_value_bdt: 0,
});

const matrix = computed(() => detail.value?.profit_matrix ?? {
  total_cost_bdt: 0,
  total_cost_by_currency: [],
  total_sell_bdt: 0,
  receive_loss_bdt: 0,
  unpaid_total_bdt: 0,
  profit_loss_bdt: 0,
  profit_loss_pct: 0,
});

const pnlItems = computed(() => detail.value?.pnl?.items ?? null);

const listRoute = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/finance/reports/shipment-report`,
);

const procurementShipmentRoute = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/procurement/shipment/${shipmentId.value ?? ''}`,
);

const canViewBills = computed(() =>
  (authStore.access?.effectiveGrants ?? []).some(
    (g) => g.module_key === 'global_invoice' && g.action === 'view',
  ),
);

const canOpenProcurement = computed(() =>
  (authStore.access?.effectiveGrants ?? []).some(
    (g) => g.module_key === 'global_shipment' && g.action === 'view',
  ),
);

function billRoute(billId: number) {
  return `/${tenantSlug.value || 'tenant'}/app/bills/${billId}`;
}
</script>

<style scoped>
.detail-scroll {
  overflow-y: auto;
  max-height: 100%;
}

.detail-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 8px;
  width: 100%;
}
</style>