<template>
  <q-dialog ref="dialogRef" persistent @hide="onDialogHide">
    <q-card class="q-dialog-plugin wholesale-issue-dialog column no-wrap" style="width: 820px; max-width: 95vw; max-height: 90vh">
      <!-- 1. Header -->
      <q-card-section class="row items-center justify-between q-pb-sm bg-grey-1 border-bottom">
        <div class="row items-center q-gutter-xs">
          <q-avatar size="32px" color="positive" text-color="white" icon="ph ph-check-circle" />
          <div class="q-ml-sm">
            <div class="text-subtitle1 text-weight-bold text-grey-9">
              Confirm Stock Deduction & Issue Invoice
            </div>
            <div class="text-caption text-grey-6">
              Invoice #{{ invoiceNo || invoiceId }} • {{ localItems.length }} item{{ localItems.length === 1 ? '' : 's' }}
            </div>
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" class="text-grey-7" v-close-popup />
      </q-card-section>

      <!-- 2. Warning Note Banner -->
      <q-card-section class="q-py-xs q-px-md">
        <q-banner dense rounded class="bg-amber-1 text-amber-10 q-my-xs">
          <template #avatar>
            <q-icon name="ph ph-info" color="amber-9" size="20px" />
          </template>
          <div class="text-caption">
            Review and adjust quantities if needed before issuing. This action will deduct stock from the warehouse and create an official stock movement record.
          </div>
        </q-banner>
      </q-card-section>

      <!-- 3. Line Items Table -->
      <q-card-section class="q-pa-none col scroll">
        <q-markup-table flat dense wrap-cells class="wholesale-issue-table">
          <thead>
            <tr class="bg-grey-2 text-grey-8 text-weight-bold">
              <th class="text-center" style="width: 50px">SL</th>
              <th class="text-center" style="width: 60px">Image</th>
              <th class="text-left">Product Name & Batch</th>
              <th class="text-center" style="width: 120px">Available Stock</th>
              <th class="text-center" style="width: 140px">Issue Quantity</th>
              <th class="text-center" style="width: 140px">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(item, idx) in localItems"
              :key="item.global_stock_id || idx"
              :class="{ 'bg-red-0': item.quantity > item.available_stock || item.quantity <= 0 }"
            >
              <td class="text-center text-grey-7">{{ idx + 1 }}</td>
              
              <!-- Thumbnail -->
              <td class="text-center">
                <div class="product-thumb">
                  <img
                    v-if="item.image_url"
                    :src="item.image_url"
                    alt="thumb"
                    class="product-thumb-img"
                  />
                  <q-icon v-else name="ph ph-package" size="22px" color="grey-5" />
                </div>
              </td>

              <!-- Product Info -->
              <td>
                <div class="text-weight-medium text-grey-9 product-name-wrap">
                  {{ item.name }}
                </div>
                <div v-if="item.shipment_name" class="text-caption text-grey-6 row items-center q-gutter-xxs q-mt-xxs">
                  <q-icon name="ph ph-boat" size="12px" />
                  <span>{{ item.shipment_name }}</span>
                </div>
              </td>

              <!-- Available Stock -->
              <td class="text-center">
                <q-chip
                  dense
                  square
                  size="sm"
                  :color="item.available_stock > 0 ? 'blue-1' : 'grey-2'"
                  :text-color="item.available_stock > 0 ? 'blue-9' : 'grey-8'"
                  class="text-weight-bold"
                >
                  {{ item.available_stock }} in stock
                </q-chip>
              </td>

              <!-- Editable Issue Quantity -->
              <td class="text-center">
                <q-input
                  v-model.number="item.quantity"
                  type="number"
                  outlined
                  dense
                  hide-bottom-space
                  min="1"
                  :max="item.available_stock"
                  class="qty-input"
                  :class="{ 'qty-input-error': item.quantity > item.available_stock || item.quantity <= 0 }"
                />
              </td>

              <!-- Status / Red Warning -->
              <td class="text-center">
                <q-badge
                  v-if="item.quantity > item.available_stock"
                  color="red-1"
                  text-color="red-9"
                  class="text-weight-bold q-pa-xs"
                >
                  <q-icon name="ph ph-warning" size="14px" class="q-mr-xs" />
                  Exceeds by {{ item.quantity - item.available_stock }}
                </q-badge>
                <q-badge
                  v-else-if="item.quantity <= 0"
                  color="red-1"
                  text-color="red-9"
                  class="text-weight-bold q-pa-xs"
                >
                  <q-icon name="ph ph-x-circle" size="14px" class="q-mr-xs" />
                  Must be &gt; 0
                </q-badge>
                <q-badge
                  v-else
                  color="green-1"
                  text-color="green-9"
                  class="text-weight-bold q-pa-xs"
                >
                  <q-icon name="ph ph-check" size="14px" class="q-mr-xs" />
                  Ready
                </q-badge>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card-section>

      <!-- 4. Footer Summary & Action Buttons -->
      <q-card-section class="row items-center justify-between bg-grey-1 border-top q-py-sm">
        <div class="row items-center q-gutter-md">
          <div class="text-caption text-grey-8">
            Total Units to Deduct: <strong class="text-subtitle2 text-primary">{{ totalIssueQuantity }}</strong>
          </div>
          <div v-if="hasInvalidQuantity" class="text-caption text-negative text-weight-bold row items-center q-gutter-xxs">
            <q-icon name="ph ph-warning-circle" size="16px" />
            <span>Fix stock quantity errors to proceed</span>
          </div>
        </div>

        <div class="row items-center q-gutter-sm">
          <q-btn
            flat
            no-caps
            label="Cancel"
            class="text-grey-8"
            v-close-popup
          />
          <q-btn
            unelevated
            color="positive"
            icon="ph ph-check-circle"
            label="Confirm & Issue Invoice"
            no-caps
            class="text-weight-bold q-px-md"
            :disable="hasInvalidQuantity || localItems.length === 0 || isConfirming"
            :loading="isConfirming"
            @click="onConfirm"
          />
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useDialogPluginComponent } from 'quasar';

export interface WholesaleIssueDialogItem {
  id?: number;
  global_stock_id: number;
  name: string;
  image_url: string | null;
  shipment_name?: string;
  available_stock: number;
  quantity: number;
}

const props = defineProps<{
  invoiceId: number;
  invoiceNo: string;
  items: WholesaleIssueDialogItem[];
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

// Clone items to local editable state
const localItems = ref<WholesaleIssueDialogItem[]>(
  props.items.map((item) => ({ ...item })),
);

const isConfirming = ref(false);

const hasInvalidQuantity = computed(() => {
  return localItems.value.some(
    (item) => !item.quantity || item.quantity <= 0 || item.quantity > item.available_stock,
  );
});

const totalIssueQuantity = computed(() => {
  return localItems.value.reduce((sum, item) => sum + (Number(item.quantity) || 0), 0);
});

const onConfirm = () => {
  if (hasInvalidQuantity.value || isConfirming.value) return;
  onDialogOK({
    items: localItems.value,
  });
};
</script>

<style scoped>
.wholesale-issue-dialog {
  border-radius: 12px;
  overflow: hidden;
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.wholesale-issue-table {
  width: 100%;
}

.wholesale-issue-table td {
  padding: 8px 12px;
}

.product-thumb {
  width: 44px;
  height: 44px;
  border-radius: 6px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background-color: #f8fafc;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.product-thumb-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.product-name-wrap {
  white-space: normal;
  word-break: break-word;
  max-width: 280px;
  line-height: 1.3;
}

.qty-input {
  max-width: 100px;
  margin: 0 auto;
}

.qty-input :deep(.q-field__control) {
  height: 34px;
  text-align: center;
  font-weight: bold;
}

.qty-input-error :deep(.q-field__control) {
  border-color: #d32f2f !important;
  background-color: #fff5f5 !important;
}

.bg-red-0 {
  background-color: rgba(254, 226, 226, 0.35);
}
</style>
