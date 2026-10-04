<template>
  <div class="bill-stock-search column no-wrap">
    <q-input
      v-model="searchQuery"
      outlined
      dense
      debounce="300"
      clearable
      placeholder="Search FIFO stock (name, barcode, code)…"
      @update:model-value="runSearch"
    >
      <template #prepend>
        <q-icon name="ph ph-magnifying-glass" size="16px" class="text-slate-400" />
      </template>
    </q-input>

    <div v-if="loading" class="q-pa-md text-center text-grey-7">
      <q-spinner color="primary" size="24px" />
    </div>

    <q-list v-else-if="results.length" bordered separator class="rounded-borders q-mt-xs scroll-area">
      <q-item
        v-for="row in results"
        :key="row.global_stock_id"
        clickable
        :disable="row.available_atp <= 0"
        @click="emit('select', row)"
      >
        <q-item-section avatar>
          <q-avatar rounded size="40px" class="bg-grey-2">
            <img
              :src="row.image_url || 'https://placehold.co/40x40?text=—'"
              alt=""
              style="object-fit: contain"
            />
          </q-avatar>
        </q-item-section>
        <q-item-section>
          <q-item-label class="text-weight-medium">{{ row.name }}</q-item-label>
          <q-item-label caption>
            ATP {{ row.available_atp }}
            <span v-if="row.shipment_name"> · {{ row.shipment_name }}</span>
            <span v-if="row.location_name"> · {{ row.location_name }}</span>
          </q-item-label>
          <q-item-label caption class="text-grey-7">
            Suggested {{ formatAmountBdt(row.suggested_sell_price) }}
            · Cost {{ formatAmountBdt(row.unit_cost_price) }}
          </q-item-label>
        </q-item-section>
        <q-item-section side>
          <q-btn flat round dense icon="ph ph-plus" color="primary" :disable="row.available_atp <= 0" />
        </q-item-section>
      </q-item>
    </q-list>

    <div v-else-if="searchQuery.trim()" class="q-pa-md text-center text-grey-6 text-caption">
      No stock found.
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import {
  invoiceRepository,
  type SalesInvoiceStockItem,
} from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { formatAmountBdt } from 'src/utils/currency';

const props = defineProps<{
  tenantId: number;
}>();

const emit = defineEmits<{
  (e: 'select', row: SalesInvoiceStockItem): void;
}>();

const searchQuery = ref('');
const results = ref<SalesInvoiceStockItem[]>([]);
const loading = ref(false);

const runSearch = async () => {
  const q = searchQuery.value.trim();
  if (!q || !props.tenantId) {
    results.value = [];
    return;
  }
  loading.value = true;
  try {
    results.value = await invoiceRepository.searchSalesInvoiceStock({
      tenantId: props.tenantId,
      search: q,
      limit: 40,
    });
  } catch (err) {
    console.error(err);
    results.value = [];
  } finally {
    loading.value = false;
  }
};

watch(
  () => props.tenantId,
  () => {
    results.value = [];
    searchQuery.value = '';
  },
);
</script>

<style scoped>
.scroll-area {
  max-height: 280px;
  overflow: auto;
}
</style>
