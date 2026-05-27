<template>
  <div class="koba-order-items-table">
    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="columns"
      row-key="id"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      class="order-q-table"
    >
      <template #body="{ row }">
        <q-tr :props="{ row }">
          <!-- Select -->
          <q-td key="select" class="col-select text-center">
            <q-checkbox v-model="selectedRowIds" :value="row.id" @update:model-value="onToggleRowSelection(row.id, $event)" />
          </q-td>
          <!-- SL -->
          <q-td key="sl" class="col-sl text-center">{{ row.sl }}</q-td>
          <!-- Image -->
          <q-td key="image" class="col-image text-center">
            <SmartImage :src="row.imageUrl" :alt="row.name" img-class="table-image" fallback-class="table-image-placeholder" />
          </q-td>
          <!-- Name -->
          <q-td key="name" class="col-name">
            <div class="name-cell-content">
              <span class="name-cell-text">{{ row.name }}</span>
            </div>
          </q-td>
          <!-- Brand -->
          <q-td key="brand" class="col-brand">{{ row.brand }}</q-td>
          <!-- Note -->
          <q-td key="note" class="col-note editable-cell">
            <div v-if="row.noteHtml" class="item-note-html" v-html="row.noteHtml"></div>
            <span v-else>-</span>
            <q-popup-edit v-slot="scope" :model-value="row.noteHtml" cover buttons persistent label-set="Save" label-cancel="Cancel" @save="(value) => { row.noteHtml = toText(value, ''); onNoteSave(row); }">
              <q-editor v-model="scope.value" dense flat square min-height="120px" :toolbar="['bold','italic','underline','removeFormat','unordered','ordered','undo','redo']" autofocus />
            </q-popup-edit>
          </q-td>
          <!-- Ordered Qty -->
          <q-td key="qty" class="col-qty text-center editable-cell">
            <div class="editable-value">{{ row.qty }}</div>
          </q-td>
          <!-- Confirmed Qty (admin) -->
          <q-td key="confirmedQty" class="col-confirmed-qty text-center editable-cell" v-if="isAdmin && canEditQuantities && order?.status === 'pending'">
            <div class="editable-value">{{ row.confirmedQty }}</div>
            <q-popup-edit v-slot="scope" :model-value="row.confirmedQty" buttons persistent label-set="Save" label-cancel="Cancel" @save="(value) => { row.confirmedQty = toNumber(value); onConfirmedQtySave(row); }">
              <q-input v-model.number="scope.value" type="number" dense outlined style="width: 80px" />
            </q-popup-edit>
          </q-td>
          <!-- Delivered Qty (admin) -->
          <q-td key="deliveredQty" class="col-delivered-qty text-center editable-cell" v-if="isAdmin && canEditQuantities && order?.status !== 'pending'">
            <div class="editable-value">{{ row.deliveredQty }}</div>
            <q-popup-edit v-slot="scope" :model-value="row.deliveredQty" buttons persistent label-set="Save" label-cancel="Cancel" @save="(value) => { row.deliveredQty = toNumber(value); onDeliveredQtySave(row); }">
              <q-input v-model.number="scope.value" type="number" dense outlined style="width: 80px" :max="row.qty" />
            </q-popup-edit>
          </q-td>
          <!-- Price GBP -->
          <q-td key="priceGbp" class="col-price-gbp text-right">{{ formatNumber(row.priceGbp) }}</q-td>
          <!-- Total -->
          <q-td key="total" class="col-total text-right">{{ formatNumber(row.priceGbp * row.qty) }}</q-td>
        </q-tr>
      </template>
    </q-table>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuasar, type QTableColumn } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { toNumberSafe, toText } from 'src/modules/koba/retail/utils/helpers';

interface KobaOrderItem {
  id: number;
  name: string;
  brand?: string;
  note?: string;
  quantity: number;
  confirmed_quantity?: number | null;
  delivered_quantity?: number | null;
  image_url?: string | null;
  unit_price_gbp?: number | null;
  // Additional fields can be added as needed
}

const props = defineProps<{ items: KobaOrderItem[]; isAdmin: boolean; orderStatus: string }>();
const emit = defineEmits(['refresh']);

const $q = useQuasar();

const selectedRowIds = ref<number[]>([]);

const toNumber = (v: unknown) => toNumberSafe(v);
const toText = (v: unknown, fallback = '-') => typeof v === 'string' ? (v.trim() || fallback) : fallback;
const formatNumber = (v: number | null | undefined) => v == null || isNaN(Number(v)) ? '-' : Number(v).toFixed(2);

const columns = computed<QTableColumn[]>(() => [
  { name: 'select', label: '', field: 'select', align: 'center', style: 'width: 56px; text-align: center;' },
  { name: 'sl', label: 'SL', field: 'sl', align: 'center', style: 'text-align: center;' },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'center', style: 'text-align: center;' },
  { name: 'name', label: 'Name', field: 'name', align: 'left', style: 'text-align: left;' },
  { name: 'brand', label: 'Brand', field: 'brand', align: 'left', style: 'text-align: left;' },
  { name: 'note', label: 'Note', field: 'noteHtml', align: 'left', style: 'text-align: left;' },
  { name: 'qty', label: 'Qty', field: 'qty', align: 'center', style: 'text-align: center;' },
  { name: 'confirmedQty', label: 'Confirmed Qty', field: 'confirmedQty', align: 'center', style: 'text-align: center;' },
  { name: 'deliveredQty', label: 'Delivered Qty', field: 'deliveredQty', align: 'center', style: 'text-align: center;' },
  { name: 'priceGbp', label: 'Price (GBP)', field: 'priceGbp', align: 'center', style: 'text-align: center;' },
  { name: 'total', label: 'Total (GBP)', field: 'total', align: 'center', style: 'text-align: center;' },
]);

const buildRows = (): any[] => {
  return props.items.map((item, index) => ({
    id: item.id,
    sl: index + 1,
    name: item.name,
    brand: item.brand ?? '-',
    noteHtml: item.note ?? '',
    imageUrl: item.image_url ?? null,
    qty: item.quantity,
    confirmedQty: item.confirmed_quantity ?? '-',
    deliveredQty: item.delivered_quantity ?? '-',
    priceGbp: item.unit_price_gbp ?? 0,
    total: (item.unit_price_gbp ?? 0) * item.quantity,
  }));
};

const tableRows = ref<any[]>([]);
watch(() => props.items, () => { tableRows.value = buildRows(); }, { immediate: true, deep: true });

function onToggleRowSelection(rowId: number, checked: boolean) {
  if (checked) {
    if (!selectedRowIds.value.includes(rowId)) selectedRowIds.value.push(rowId);
  } else {
    selectedRowIds.value = selectedRowIds.value.filter(id => id !== rowId);
  }
}

async function onConfirmedQtySave(row: any) {
  // placeholder for API call – emit to parent for handling
  emit('refresh');
  $q.notify({ message: 'Confirmed quantity saved', color: 'positive', icon: 'check', timeout: 1200 });
}

async function onDeliveredQtySave(row: any) {
  emit('refresh');
  $q.notify({ message: 'Delivered quantity saved', color: 'positive', icon: 'check', timeout: 1200 });
}

async function onNoteSave(row: any) {
  emit('refresh');
  $q.notify({ message: 'Note saved', color: 'positive', icon: 'check', timeout: 1200 });
}
</script>

<style scoped>
.koba-order-items-table {
  width: 100%;
}
.order-q-table {
  max-width: 100%;
  height: clamp(400px, calc(100vh - 280px), 82vh);
  background: var(--bw-theme-base, #eef2f5);
}
/* Reuse column width styles similar to costing component */
.col-select { min-width: 56px; width: 56px; max-width: 56px; }
.col-sl { min-width: 60px; width: 60px; max-width: 60px; }
.col-image { min-width: 130px; width: 130px; max-width: 130px; }
.col-name { min-width: 200px; width: 200px; max-width: 200px; }
.col-brand { min-width: 150px; width: 150px; max-width: 150px; }
.col-note { min-width: 260px; width: 260px; max-width: 260px; }
.col-qty, .col-confirmed-qty, .col-delivered-qty { min-width: 100px; width: 100px; max-width: 100px; }
.col-price-gbp, .col-total { min-width: 110px; width: 110px; max-width: 110px; }
.editable-cell { cursor: pointer; }
.editable-value { min-height: 24px; display: flex; align-items: center; justify-content: flex-end; }
</style>
