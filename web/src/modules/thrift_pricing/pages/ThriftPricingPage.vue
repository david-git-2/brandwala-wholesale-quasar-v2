<template>
  <q-page class="q-pa-md thrift-pricing-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Pricing</div>
            <div class="text-caption text-grey-8">Update Cost of Goods Sold (COGS), listed prices, and target sell values</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Table -->
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="pricings"
        :columns="columns"
        row-key="id"
        :loading="loading"
        class="thrift-table"
      >
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn flat round dense icon="o_edit" size="sm" @click.stop="editPricing(props.row)">
              <q-tooltip>Edit Prices</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Edit Pricing Dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 420px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">Update Pricing</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-pt-md">
          <div class="text-caption text-grey-8 q-mb-md">
            {{ activeRow?.thrift_stocks?.name }} ({{ activeRow?.thrift_stocks?.sku }})
          </div>
          <div class="q-gutter-sm">
            <q-input v-model.number="form.cost" type="number" step="0.01" outlined dense label="Cost of Goods Sold (COGS)" class="soft-input" />
            <q-input v-model.number="form.target" type="number" step="0.01" outlined dense label="Target Price" class="soft-input" />
            <q-input v-model.number="form.listed" type="number" step="0.01" outlined dense label="Listed Price" class="soft-input" />
          </div>
        </q-card-section>
        <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Changes" @click="save" />
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftPricingStore } from '../stores/thriftPricingStore';
import { useQuasar, type QTableColumn } from 'quasar';

const $q = useQuasar();
const authStore = useAuthStore();
const store = useThriftPricingStore();

const dialogOpen = ref(false);
const activeRow = ref<any>(null);

const pricings = computed(() => store.pricings);
const loading = computed(() => store.loading);

const form = ref({ cost: 0, target: 0, listed: 0 });

const columns: QTableColumn[] = [
  { name: 'sku', align: 'left', label: 'SKU', field: (row: any) => row.thrift_stocks?.sku, sortable: true },
  { name: 'name', align: 'left', label: 'Item Name', field: (row: any) => row.thrift_stocks?.name, sortable: true },
  { name: 'cost_of_goods_sold', align: 'right', label: 'COGS', field: 'cost_of_goods_sold', format: (val: any) => `${val}`, sortable: true },
  { name: 'target_price', align: 'right', label: 'Target Price', field: 'target_price', format: (val: any) => `${val}`, sortable: true },
  { name: 'listed_price', align: 'right', label: 'Listed Price', field: 'listed_price', format: (val: any) => `${val}`, sortable: true },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await store.loadPricings(authStore.tenantId);
  }
});

function editPricing(row: any) {
  activeRow.value = row;
  form.value = { cost: row.cost_of_goods_sold, target: row.target_price, listed: row.listed_price };
  dialogOpen.value = true;
}

async function save() {
  if (!activeRow.value) return;
  $q.loading.show();
  try {
    await store.updatePricing(activeRow.value.id, form.value.cost, form.value.target, form.value.listed);
    $q.notify({ type: 'positive', message: 'Pricing updated' });
    dialogOpen.value = false;
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Update failed' });
  } finally {
    $q.loading.hide();
  }
}
</script>

<style scoped>
.thrift-pricing-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}
</style>
