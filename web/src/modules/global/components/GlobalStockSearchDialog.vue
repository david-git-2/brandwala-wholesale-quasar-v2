<template>
  <q-dialog v-model="isOpen" backdrop-filter="blur(4px)">
    <q-card class="search-card floating-surface shadow-2">
      <q-card-section class="q-py-md row items-center justify-between">
        <div class="row items-center q-gutter-sm">
          <q-icon name="inventory_2" size="24px" color="primary" />
          <div class="text-h6 text-weight-bold">Search Global Stock</div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-none">
        <NetworkStockSearchPanel
          v-if="contextTenantId"
          mode="search"
          :context-tenant-id="contextTenantId"
          @select="onSelectResult"
        />
      </q-card-section>
    </q-card>
  </q-dialog>

  <GlobalStockDetailsDialog v-model="detailsOpen" :item="selectedItem" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import type { InventoryItemWithStock } from '../types';

import GlobalStockDetailsDialog from './GlobalStockDetailsDialog.vue';
import NetworkStockSearchPanel from 'src/modules/sales_invoice/components/NetworkStockSearchPanel.vue';
import type { StockNetworkRow } from '../types';
import { mapStockNetworkToInventoryView } from '../utils/mapStockNetworkRow';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const authStore = useAuthStore();
const tenantStore = useTenantStore();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const contextTenantId = computed(() => tenantStore.selectedTenantId ?? authStore.tenantId ?? 0);

const detailsOpen = ref(false);
const selectedItem = ref<InventoryItemWithStock | null>(null);

const onSelectResult = (row: StockNetworkRow) => {
  selectedItem.value = mapStockNetworkToInventoryView(row);
  detailsOpen.value = true;
};
</script>

<style scoped>
.search-card {
  width: 90vw;
  max-width: 650px;
  background: rgba(255, 255, 255, 0.94);
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(10px);
}
</style>
