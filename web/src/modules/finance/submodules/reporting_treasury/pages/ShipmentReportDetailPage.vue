<template>
  <FinanceReportFrame
    layout="document"
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
    </template>

    <div v-if="!isLoading && detail" class="column q-gutter-y-md shipment-detail-root">
      <ShipmentReportHeaderStrip
        v-if="detail.header?.shipment_id"
        :header="detail.header"
        :procurement-route="canOpenProcurement ? procurementShipmentRoute : null"
      />
      <ShipmentReportVerdict :verdict="verdict" />
      <ShipmentReportKpiRow
        :primary-kpis="primaryKpis"
        :secondary-kpis="secondaryKpis"
      />
      <ShipmentReportProfitBridge
        :steps="bridgeSteps"
        :total-sell="matrix.total_sell_bdt"
        :total-cost="bridgeTotalCost"
        :gross-cost="matrix.total_cost_bdt"
        :profit="displayProfitBdt"
        :has-vendor-credits="hasVendorCredits"
      />
      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-6">
          <ShipmentReportCostDonut :slices="donutSlices" :total-cost-bdt="matrix.total_cost_bdt" />
        </div>
        <div class="col-12 col-md-6">
          <ShipmentReportPiecesBar
            :segments="pieceSegments"
            :ordered="qty.should_arrive"
            :arrived="qty.arrived"
          />
        </div>
      </div>

      <ShipmentReportDetailTabs
        :detail="detail"
        :can-view-bills="canViewBills"
        :bill-route="billRoute"
      />
    </div>
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import ShipmentReportHeaderStrip from '../components/shipmentReport/ShipmentReportHeaderStrip.vue';
import ShipmentReportVerdict from '../components/shipmentReport/ShipmentReportVerdict.vue';
import ShipmentReportKpiRow from '../components/shipmentReport/ShipmentReportKpiRow.vue';
import ShipmentReportProfitBridge from '../components/shipmentReport/ShipmentReportProfitBridge.vue';
import ShipmentReportCostDonut from '../components/shipmentReport/ShipmentReportCostDonut.vue';
import ShipmentReportPiecesBar from '../components/shipmentReport/ShipmentReportPiecesBar.vue';
import ShipmentReportDetailTabs from '../components/shipmentReport/ShipmentReportDetailTabs.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShipmentReportDetail } from '../composables/useShipmentReportDetail';
import { useShipmentReportView } from '../composables/useShipmentReportView';

const route = useRoute();
const authStore = useAuthStore();
const { tenantSlug } = storeToRefs(authStore);

const shipmentId = computed(() => {
  const raw = route.params.shipmentId;
  const n = typeof raw === 'string' ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(n) && n > 0 ? n : null;
});

const { detail, isLoading, error, refetch } = useShipmentReportDetail(shipmentId);
const {
  verdict,
  primaryKpis,
  secondaryKpis,
  bridgeSteps,
  matrix,
  donutSlices,
  pieceSegments,
  qty,
  bridgeTotalCost,
  displayProfitBdt,
  hasVendorCredits,
} = useShipmentReportView(detail);

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
.shipment-detail-root {
  width: 100%;
}
</style>