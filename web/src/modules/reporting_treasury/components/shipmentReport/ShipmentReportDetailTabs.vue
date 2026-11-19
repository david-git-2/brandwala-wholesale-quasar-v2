<template>
  <q-card flat bordered class="q-pa-md report-section">
    <TfDrawerSectionTabs v-model="tab" :tabs="tabs" aria-label="Shipment report sections" class="q-mb-md" />
    <ShipmentReportProductsTab v-if="tab === 'products'" :items="detail.pnl?.items" />
    <ShipmentReportCostInSection
      v-else-if="tab === 'costs'"
      embedded
      :ap-bills="detail.ap_bills"
      :cost-buckets="detail.cost_buckets"
      :exchange-rates="detail.exchange_rates"
      :total-cost-bdt="detail.profit_matrix?.total_cost_bdt ?? 0"
      :can-view-bills="canViewBills"
      :bill-route="billRoute"
    />
    <ShipmentReportSalesOutSection
      v-else-if="tab === 'sales'"
      embedded
      :customer-bills="detail.customer_bills"
      :sell-lines="detail.sell_lines"
      :unpaid-customers="detail.unpaid_customers"
      :unpaid-total-bdt="detail.profit_matrix?.unpaid_total_bdt ?? 0"
      :can-view-bills="canViewBills"
      :bill-route="billRoute"
    />
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import type { ShipmentReportDetailPayload } from '../../types/shipmentReportDetailTypes';
import ShipmentReportProductsTab from './ShipmentReportProductsTab.vue';
import ShipmentReportCostInSection from './ShipmentReportCostInSection.vue';
import ShipmentReportSalesOutSection from './ShipmentReportSalesOutSection.vue';

const props = defineProps<{
  detail: ShipmentReportDetailPayload;
  canViewBills: boolean;
  billRoute: (billId: number) => string;
}>();

const tab = ref<'products' | 'costs' | 'sales'>('products');

const tabs = computed(() => [
  {
    name: 'products' as const,
    label: 'Products',
    icon: 'ph ph-package',
    count: props.detail.pnl?.items?.length ?? 0,
  },
  {
    name: 'costs' as const,
    label: 'Costs',
    icon: 'ph ph-coins',
    count: props.detail.cost_buckets?.length ?? 0,
  },
  {
    name: 'sales' as const,
    label: 'Sales',
    icon: 'ph ph-receipt',
    count: props.detail.sell_lines?.length ?? 0,
  },
]);
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}
</style>