<template>
  <div v-if="hasAnyAction" class="thrift-actions">
    <q-btn
      v-if="canCreateSale"
      color="primary"
      unelevated
      no-caps
      icon="ph ph-plus"
      label="New sale"
      :to="saleCreateTo"
    />
    <q-btn
      v-if="canViewSales"
      flat
      no-caps
      color="primary"
      icon="ph ph-receipt"
      label="Sales"
      :to="salesTo"
    />
    <q-btn
      v-if="canViewShipments"
      flat
      no-caps
      color="grey-8"
      icon="ph ph-truck"
      label="Shipments"
      :to="shipmentsTo"
    />
    <q-btn
      v-if="canViewStock"
      flat
      no-caps
      color="grey-8"
      icon="ph ph-package"
      label="Stock"
      :to="stockTo"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { RouteLocationRaw } from 'vue-router';

import { useModulePermissions } from 'src/modules/navigation/modulePermissions';

const props = defineProps<{
  tenantSlug?: string;
}>();

const { hasModuleAccess } = useModulePermissions();

const canCreateSale = computed(() => hasModuleAccess('thrift_sales', 'create'));
const canViewSales = computed(() => hasModuleAccess('thrift_sales', 'view'));
const canViewShipments = computed(() => hasModuleAccess('thrift_shipment', 'view'));
const canViewStock = computed(() => hasModuleAccess('thrift_stock', 'view'));

const hasAnyAction = computed(
  () =>
    canCreateSale.value ||
    canViewSales.value ||
    canViewShipments.value ||
    canViewStock.value,
);

const withSlug = (name: string): RouteLocationRaw => ({
  name,
  params: props.tenantSlug ? { tenantSlug: props.tenantSlug } : {},
});

const saleCreateTo = computed(() => withSlug('thrift-sales-create'));
const salesTo = computed(() => withSlug('thrift-sales-page'));
const shipmentsTo = computed(() => withSlug('thrift-shipments-page'));
const stockTo = computed(() => withSlug('thrift-stock-page'));
</script>

<style scoped>
.thrift-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  align-items: center;
}

.thrift-actions :deep(.q-btn) {
  border-radius: 10px;
  padding: 0 0.95rem;
  min-height: 2.5rem;
  font-weight: 600;
}

@media (max-width: 600px) {
  .thrift-actions {
    flex-direction: column;
    align-items: stretch;
  }

  .thrift-actions :deep(.q-btn) {
    width: 100%;
    justify-content: flex-start;
  }
}
</style>
