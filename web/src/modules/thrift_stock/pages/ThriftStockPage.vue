<template>
  <q-page class="q-pa-md thrift-stock-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Stock</div>
            <div class="text-caption text-grey-8">Manage bulk and single items, conditions, sizes, and shelf locations</div>
          </div>
          <div class="col-12 col-sm-auto row justify-start justify-sm-end q-mt-xs q-mt-sm-none">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Register Stock"
              @click="openAddDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Table -->
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="stocks"
        :columns="columns"
        row-key="id"
        :loading="loading"
        class="thrift-table"
      >
        <template #body-cell-box="props">
          <q-td :props="props">
            {{ getBoxName(props.row.box_id) }}
          </q-td>
        </template>
        <template #body-cell-product_weight="props">
          <q-td :props="props">
            {{ props.value ? `${props.value} kg` : '—' }}
          </q-td>
        </template>
        <template #body-cell-extra_weight="props">
          <q-td :props="props">
            {{ props.value ? `${props.value} kg` : '—' }}
          </q-td>
        </template>
        <template #body-cell-status="props">
          <q-td :props="props">
            <q-chip
              dense
              square
              :style="statusChipStyle(props.value)"
              class="thrift-status-chip"
            >
              <span class="status-dot" :style="{ backgroundColor: statusDotColor(props.value) }" />
              {{ props.value ?? 'AVAILABLE' }}
            </q-chip>
          </q-td>
        </template>
        <template #body-cell-pricing="props">
          <q-td :props="props">
            <div v-if="props.value" class="text-caption text-black">
              <span class="text-grey-7">Cost:</span> {{ props.value.cost_of_goods_sold }}
              &nbsp;|&nbsp;
              <span class="text-grey-7">Listed:</span> {{ props.value.listed_price }}
            </div>
            <div v-else class="text-grey-5">—</div>
          </q-td>
        </template>
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn flat round dense icon="o_report_problem" size="sm" color="warning" @click.stop="updateStatus(props.row.id, 'DAMAGED')">
              <q-tooltip>Mark Damaged</q-tooltip>
            </q-btn>
            <q-btn flat round dense icon="o_block" size="sm" color="negative" @click.stop="updateStatus(props.row.id, 'STOLEN')">
              <q-tooltip>Mark Stolen</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Register Stock Dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 600px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">Register Thrift Stock</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section>
          <q-form @submit="onSubmit" class="q-gutter-sm q-pt-sm">
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select v-model="form.shipment_id" outlined dense label="Shipment *" :options="shipments"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']" @update:model-value="onShipmentChange" />
              </div>
              <div class="col-12 col-sm-6">
                <q-select v-model="form.box_id" outlined dense label="Box Number/Name" :options="filteredBoxes"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  clearable />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select v-model="form.category_id" outlined dense label="Category *" :options="categories"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']" />
              </div>
              <div class="col-12 col-sm-6">
                <q-select v-model="form.type_id" outlined dense label="Product Style/Type *" :options="types"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']" />
              </div>
            </div>

            <q-input v-model="form.name" outlined dense label="Item Name *" class="soft-input"
              :rules="[val => !!val && val.length > 0 || 'Required']" />

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input v-model="form.brand_name" outlined dense label="Brand Name" class="soft-input" />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model="form.sku" outlined dense label="SKU Code *" class="soft-input"
                  :rules="[val => !!val && val.length > 0 || 'Required']" />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-select v-model="form.section" outlined dense label="Section *" class="soft-input"
                  :options="['MALE', 'FEMALE', 'UNISEX', 'KIDS', 'HOME']"
                  :rules="[val => !!val || 'Required']" />
              </div>
              <div class="col-12 col-sm-4">
                <q-select v-model="form.condition" outlined dense label="Condition *" class="soft-input"
                  :options="['NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR']"
                  :rules="[val => !!val || 'Required']" />
              </div>
              <div class="col-12 col-sm-4">
                <q-select v-model="form.shelf_id" outlined dense label="Shelf *" class="soft-input"
                  :options="shelves" option-value="id" option-label="shelf_code" emit-value map-options
                  :rules="[val => !!val || 'Required']" />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input v-model="form.color" outlined dense label="Color *" class="soft-input"
                  :rules="[val => !!val && val.length > 0 || 'Required']" />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model="form.size" outlined dense label="Size *" class="soft-input"
                  :rules="[val => !!val && val.length > 0 || 'Required']" />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model.number="form.quantity" type="number" outlined dense label="Quantity *" class="soft-input"
                  :rules="[val => val >= 0 || 'Cannot be negative']" />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input v-model.number="form.product_weight" type="number" step="0.001" outlined dense label="Product Weight (kg)" class="soft-input" />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model.number="form.extra_weight" type="number" step="0.001" outlined dense label="Extra Weight (kg)" class="soft-input" />
              </div>
            </div>

            <q-separator class="q-my-xs" />
            <div class="text-caption text-grey-8 q-mb-xs">Pricing</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input v-model.number="pricing.cost_of_goods_sold" type="number" step="0.01" outlined dense label="COGS Cost" class="soft-input" />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model.number="pricing.target_price" type="number" step="0.01" outlined dense label="Target Price" class="soft-input" />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model.number="pricing.listed_price" type="number" step="0.01" outlined dense label="Listed Price" class="soft-input" />
              </div>
            </div>

            <div class="row justify-end q-gutter-sm q-pt-sm">
              <q-btn flat no-caps label="Cancel" v-close-popup />
              <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Stock" type="submit" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftStockStore } from '../stores/thriftStockStore';
import { useThriftCategoryStore } from 'src/modules/thrift_category/stores/thriftCategoryStore';
import { useThriftTypeStore } from 'src/modules/thrift_type/stores/thriftTypeStore';
import { useThriftShelfStore } from 'src/modules/thrift_shelf/stores/thriftShelfStore';
import { useThriftStore } from 'src/modules/thrift/stores/thriftStore';
import { useQuasar, type QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';

const $q = useQuasar();
const authStore = useAuthStore();
const store = useThriftStockStore();
const catStore = useThriftCategoryStore();
const typeStore = useThriftTypeStore();
const shelfStore = useThriftShelfStore();

const dialogOpen = ref(false);

const stocks = computed(() => store.stocks);
const loading = computed(() => store.loading);
const categories = computed(() => catStore.categories);
const types = computed(() => typeStore.types);
const shelves = computed(() => shelfStore.shelves);

const form = ref({
  category_id: null as number | null,
  type_id: null as number | null,
  shipment_id: null as number | null,
  box_id: null as number | null,
  name: '',
  brand_name: '',
  sku: '',
  section: 'UNISEX',
  shelf_id: null as number | null,
  color: '',
  size: '',
  condition: 'EXCELLENT',
  quantity: 1,
  product_weight: 0.25,
  extra_weight: 0,
  note: '',
});

const shipments = ref<any[]>([]);
const thriftStore = useThriftStore();

async function loadShipments() {
  if (!authStore.tenantId) return;
  const { data } = await supabase
    .from('shipments')
    .select('id, name')
    .eq('tenant_id', authStore.tenantId)
    .order('name', { ascending: true });
  shipments.value = data || [];
}

const filteredBoxes = computed(() => {
  if (!form.value.shipment_id) return [];
  return thriftStore.boxes.filter(b => b.shipment_id === form.value.shipment_id);
});

function onShipmentChange() {
  form.value.box_id = null;
}

function getBoxName(boxId: number | undefined) {
  if (!boxId) return '—';
  const bx = thriftStore.boxes.find(b => b.id === boxId);
  return bx ? bx.name : `#${boxId}`;
}

const pricing = ref({
  cost_of_goods_sold: 0,
  target_price: 0,
  listed_price: 0,
});

const columns: QTableColumn[] = [
  { name: 'sku', align: 'left', label: 'SKU', field: 'sku', sortable: true },
  { name: 'name', align: 'left', label: 'Name', field: 'name', sortable: true },
  { name: 'brand_name', align: 'left', label: 'Brand', field: 'brand_name' },
  { name: 'section', align: 'left', label: 'Section', field: 'section' },
  { name: 'size', align: 'left', label: 'Size', field: 'size' },
  { name: 'box', align: 'left', label: 'Box', field: 'box' },
  { name: 'product_weight', align: 'right', label: 'Product Wt', field: 'product_weight' },
  { name: 'extra_weight', align: 'right', label: 'Extra Wt', field: 'extra_weight' },
  { name: 'condition', align: 'left', label: 'Condition', field: 'condition' },
  { name: 'quantity', align: 'right', label: 'Qty', field: 'quantity', sortable: true },
  { name: 'pricing', align: 'left', label: 'Pricing', field: 'pricing' },
  { name: 'status', align: 'center', label: 'Status', field: 'status', sortable: true },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await Promise.all([
      store.loadStocks(authStore.tenantId),
      catStore.loadCategories(authStore.tenantId),
      typeStore.loadTypes(authStore.tenantId),
      shelfStore.loadShelves(authStore.tenantId),
      thriftStore.loadModuleData(authStore.tenantId),
      loadShipments()
    ]);
  }
});

function openAddDialog() {
  form.value = {
    category_id: categories.value[0]?.id || null,
    type_id: types.value[0]?.id || null,
    shipment_id: shipments.value[0]?.id || null,
    box_id: null,
    name: '',
    brand_name: '',
    sku: 'SKU-THRIFT-' + Math.floor(Math.random() * 90000 + 10000),
    section: 'UNISEX',
    shelf_id: shelves.value[0]?.id || null,
    color: '',
    size: '',
    condition: 'EXCELLENT',
    quantity: 1,
    product_weight: 0.25,
    extra_weight: 0,
    note: '',
  };
  pricing.value = { cost_of_goods_sold: 0, target_price: 0, listed_price: 0 };
  dialogOpen.value = true;
}

async function updateStatus(stockId: number, status: string) {
  $q.loading.show();
  try {
    await store.updateStockStatus(stockId, status);
    $q.notify({ type: 'positive', message: `Stock marked as ${status}` });
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Update failed' });
  } finally {
    $q.loading.hide();
  }
}

async function onSubmit() {
  if (!authStore.tenantId) return;
  $q.loading.show();
  try {
    await store.createStock(
      authStore.tenantId,
      form.value.shipment_id!,
      form.value.name,
      form.value.brand_name,
      form.value.category_id!,
      form.value.type_id!,
      form.value.section,
      form.value.shelf_id!,
      form.value.color,
      form.value.size,
      form.value.condition,
      form.value.sku,
      'SINGLE',
      form.value.quantity,
      form.value.box_id || undefined,
      form.value.product_weight || undefined,
      form.value.extra_weight || undefined,
      form.value.note,
      authStore.user?.email || 'admin@brandwala.com',
      pricing.value
    );
    $q.notify({ type: 'positive', message: 'Thrift stock registered successfully' });
    dialogOpen.value = false;
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Saving failed' });
  } finally {
    $q.loading.hide();
  }
}

const normalizeStatus = (status: string | null | undefined) =>
  (status ?? '').trim().toUpperCase() || 'AVAILABLE'

const statusChipStyle = (status: string | null | undefined) => {
  const v = normalizeStatus(status)
  if (v === 'AVAILABLE') return { backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #6ee7b7' }
  if (v === 'OUT_OF_STOCK') return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' }
  if (v === 'DAMAGED') return { backgroundColor: '#fef3c7', color: '#92400e', border: '1px solid #fcd34d' }
  if (v === 'STOLEN') return { backgroundColor: '#fee2e2', color: '#7f1d1d', border: '1px solid #fca5a5' }
  return { backgroundColor: '#e5e7eb', color: '#374151', border: '1px solid #d1d5db' }
}

const statusDotColor = (status: string | null | undefined) => {
  const v = normalizeStatus(status)
  if (v === 'AVAILABLE') return '#059669'
  if (v === 'OUT_OF_STOCK') return '#9ca3af'
  if (v === 'DAMAGED') return '#d97706'
  if (v === 'STOLEN') return '#dc2626'
  return '#9ca3af'
}
</script>

<style scoped>
.thrift-stock-page {
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

.thrift-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>
