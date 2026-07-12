<template>
  <q-card flat bordered class="q-pa-md shipment-purchase-balance-card bg-white">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-subtitle1 text-weight-bold text-primary row items-center q-gutter-xs">
        <q-icon name="payments" size="22px" />
        <span>Shipment Purchase Balance</span>
      </div>
      <q-badge v-if="hasDelta" :color="deltaColor" class="q-py-xs q-px-sm text-weight-bold">
        Delta: {{ purchaseCurrencySymbol }}{{ delta.toFixed(2) }}
      </q-badge>
    </div>

    <!-- Paid Purchase Invoice Total Section -->
    <div class="bg-blue-1 border-light rounded-borders q-pa-sm q-mb-md">
      <div class="text-caption text-weight-bold text-blue-9 q-mb-xs">
        Paid Purchase Invoice Total ({{ purchaseCurrencySymbol }})
      </div>
      <div class="row q-col-gutter-sm items-center">
        <div class="col-8">
          <q-input
            v-model.number="purchaseInvoiceTotal"
            type="number"
            placeholder="e.g. 1500.00"
            outlined
            dense
            bg-color="white"
            class="soft-input"
            step="0.01"
            :prefix="purchaseCurrencySymbol"
          >
            <template v-slot:append>
              <q-btn
                flat
                round
                dense
                icon="save"
                color="blue-9"
                size="sm"
                :loading="savingPurchaseInvoiceTotal"
                @click="savePurchaseInvoiceTotal"
              >
                <q-tooltip>Save Purchase Invoice Total</q-tooltip>
              </q-btn>
            </template>
          </q-input>
        </div>
        <div class="col-4 text-caption text-grey-7 q-pl-xs leading-tight" style="font-size: 10px">
          The exact paid purchase total to the vendor. Click save, then apply balance to distribute across lines.
        </div>
      </div>
    </div>

    <!-- Summary Row -->
    <div class="row q-col-gutter-xs q-mb-md text-center">
      <div class="col-4">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7" style="font-size: 10px">Estimated</div>
          <div class="text-subtitle2 text-weight-bold text-mono text-ellipsis" style="font-size: 12px">
            {{ purchaseCurrencySymbol }}{{ estimated.toFixed(2) }}
          </div>
        </div>
      </div>
      <div class="col-4">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7" style="font-size: 10px">Invoice</div>
          <div class="text-subtitle2 text-weight-bold text-mono text-ellipsis" style="font-size: 12px">
            {{ purchaseCurrencySymbol }}{{ actual.toFixed(2) }}
          </div>
        </div>
      </div>
      <div class="col-4">
        <div :class="`q-pa-xs rounded-borders ${deltaBg}`">
          <div class="text-caption text-grey-7" style="font-size: 10px">Delta</div>
          <div class="text-subtitle2 text-weight-bold text-mono text-ellipsis" style="font-size: 12px">
            {{ delta >= 0 ? '+' : '' }}{{ purchaseCurrencySymbol }}{{ delta.toFixed(2) }}
          </div>
        </div>
      </div>
    </div>

    <!-- Validation Error / Unsaved Banner -->
    <div v-if="validationError || hasUnsavedInvoiceTotal" class="q-mb-md">
      <q-banner
        v-if="hasUnsavedInvoiceTotal"
        dense
        class="bg-amber-1 text-amber-10 rounded-borders q-mb-xs"
        style="font-size: 11px"
      >
        <q-icon name="info" class="q-mr-xs" />
        Unsaved purchase invoice total — click save before applying purchase balance.
      </q-banner>
      <q-banner
        v-if="validationError"
        dense
        class="bg-warning text-black rounded-borders"
        style="font-size: 11px"
      >
        <q-icon name="warning" class="q-mr-xs" />
        {{ validationError }}
      </q-banner>
    </div>

    <!-- Preview Adjustments Trigger -->
    <div v-if="previewItems.length && !validationError" class="q-mb-sm">
      <q-btn
        outline
        color="secondary"
        icon="visibility"
        label="Preview Price Adjustments"
        class="full-width soft-input"
        no-caps
        dense
        @click="showPreviewDialog = true"
      />

      <!-- Preview Dialog -->
      <q-dialog v-model="showPreviewDialog">
        <q-card style="width: 600px; max-width: 90vw">
          <q-card-section class="row items-center q-pb-none">
            <div class="text-subtitle1 text-weight-bold text-primary row items-center q-gutter-xs">
              <q-icon name="payments" size="20px" />
              <span>Preview Price Adjustments</span>
            </div>
            <q-space />
            <q-btn icon="close" flat round dense v-close-popup />
          </q-card-section>

          <q-card-section class="q-pa-md">
            <div style="border: 1px solid rgba(0, 0, 0, 0.08); border-radius: 8px; overflow: hidden">
              <q-markup-table dense flat class="price-preview-table bg-grey-1">
                <thead>
                  <tr>
                    <th class="text-left text-caption">Product</th>
                    <th class="text-right text-caption">Qty</th>
                    <th class="text-right text-caption">Price ({{ purchaseCurrencySymbol }})</th>
                    <th class="text-right text-caption">Delta</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="item in previewItems" :key="item.id">
                    <td class="text-left text-caption text-weight-medium ellipsis" style="max-width: 250px">
                      {{ item.name }}
                    </td>
                    <td class="text-right text-caption text-mono">{{ item.qty }}</td>
                    <td class="text-right text-caption text-mono">
                      {{ item.priceBefore.toFixed(2) }} &rarr;
                      <strong class="text-primary">{{ item.priceAfter.toFixed(6) }}</strong>
                    </td>
                    <td
                      class="text-right text-caption text-mono"
                      :class="item.delta >= 0 ? 'text-negative' : 'text-positive'"
                    >
                      {{ item.delta >= 0 ? '+' : '' }}{{ item.delta.toFixed(6) }}
                    </td>
                  </tr>
                </tbody>
              </q-markup-table>
            </div>
          </q-card-section>

          <q-card-actions align="right" class="bg-grey-1 q-pa-sm">
            <q-btn flat label="Close" color="grey-8" v-close-popup no-caps />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>

    <!-- Apply Action -->
    <q-btn
      color="primary"
      label="Apply Purchase Balance"
      class="full-width pill-btn shadow-1"
      unelevated
      no-caps
      :disable="applyDisabled"
      :loading="applying"
      @click="confirmApply"
    >
      <q-tooltip v-if="applyDisabled">
        {{ applyDisabledReason }}
      </q-tooltip>
    </q-btn>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import { computePurchasePriceAdjustments, calculateEstimatedPurchaseTotal } from '../utils/purchaseBalance';
import {
  showSuccessNotification,
  showErrorNotification,
  showWarningNotification,
} from 'src/utils/appFeedback';

const props = defineProps<{
  shipmentId: number;
}>();

const emit = defineEmits<{
  (e: 'applied'): void;
}>();

const $q = useQuasar();
const shipmentStore = useGlobalShipmentStore();

const showPreviewDialog = ref(false);
const applying = ref(false);
const savingPurchaseInvoiceTotal = ref(false);
const purchaseInvoiceTotal = ref<number | null>(null);
const purchaseCurrencySymbol = ref('£');

const items = computed(() => shipmentStore.currentShipmentItems);

// Estimated total using original prices
const estimated = computed(() => {
  return calculateEstimatedPurchaseTotal(
    items.value.map((item) => ({
      id: item.id,
      name: item.name,
      purchase_price: item.purchase_price || 0,
      ordered_quantity: item.ordered_quantity || 0,
    }))
  );
});

// Watch current shipment's saved invoice total
watch(
  () => shipmentStore.currentShipment?.purchase_invoice_total,
  (newVal) => {
    purchaseInvoiceTotal.value = newVal ?? null;
  },
  { immediate: true },
);

// Load currency symbol
onMounted(async () => {
  try {
    const currencyId = shipmentStore.currentShipment?.shipment_purchase_currency_id;
    if (currencyId) {
      const list = await globalReferenceRepository.listCurrencies();
      const curr = list.find((c) => c.id === currencyId);
      if (curr) {
        purchaseCurrencySymbol.value = curr.symbol;
      }
    }
  } catch (err) {
    console.error('Failed to load currency info', err);
  }
});

const savePurchaseInvoiceTotal = async () => {
  const val = purchaseInvoiceTotal.value;
  if (val === null || val <= 0) {
    showWarningNotification('Purchase Invoice Total must be greater than 0.');
    return;
  }
  const rounded = Math.round(val * 100) / 100;
  savingPurchaseInvoiceTotal.value = true;
  try {
    await shipmentStore.updateShipment(props.shipmentId, { purchase_invoice_total: rounded });
    purchaseInvoiceTotal.value = rounded;
    showSuccessNotification('Purchase Invoice Total updated successfully.');
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to update Purchase Invoice Total.');
  } finally {
    savingPurchaseInvoiceTotal.value = false;
  }
};

const savedInvoiceTotal = computed(() => {
  const t = shipmentStore.currentShipment?.purchase_invoice_total;
  return t != null && t > 0 ? Math.round(t * 100) / 100 : 0;
});

const hasUnsavedInvoiceTotal = computed(() => {
  const saved = shipmentStore.currentShipment?.purchase_invoice_total;
  const draft = purchaseInvoiceTotal.value;
  if (draft === null || draft <= 0) return saved != null && saved > 0;
  const roundedDraft = Math.round(draft * 100) / 100;
  const roundedSaved = saved != null ? Math.round(saved * 100) / 100 : null;
  return roundedSaved === null || roundedDraft !== roundedSaved;
});

const actual = computed(() => savedInvoiceTotal.value);

const delta = computed(() => {
  return actual.value - estimated.value;
});

const hasDelta = computed(() => {
  return actual.value > 0 && Math.abs(delta.value) > 0.001;
});

const deltaColor = computed(() => {
  if (delta.value > 0) return 'negative';
  if (delta.value < 0) return 'positive';
  return 'grey-7';
});

const deltaBg = computed(() => {
  if (delta.value > 0) return 'bg-red-1 text-red-9';
  if (delta.value < 0) return 'bg-green-1 text-green-9';
  return 'bg-grey-2 text-grey-9';
});

// Run adjustments calculation to check for validation errors and drive preview
const adjustments = computed(() => {
  if (actual.value <= 0 || items.value.length === 0) return [];
  try {
    const inputItems = items.value.map((item) => ({
      id: item.id,
      name: item.name,
      purchase_price: item.purchase_price || 0,
      ordered_quantity: item.ordered_quantity || 0,
    }));
    return computePurchasePriceAdjustments(inputItems, actual.value);
  } catch (error) {
    return error as Error;
  }
});

const validationError = computed(() => {
  if (adjustments.value instanceof Error) {
    return adjustments.value.message;
  }
  return null;
});

// Preview line items
const previewItems = computed(() => {
  const adjs = adjustments.value;
  if (adjs instanceof Error || !adjs.length) return [];
  return items.value
    .map((item) => {
      const adj = adjs.find((a) => a.itemId === item.id);
      if (!adj) return null;
      return {
        id: item.id,
        name: item.name,
        qty: item.ordered_quantity,
        priceBefore: item.purchase_price,
        priceAfter: adj.newPurchasePrice,
        delta: adj.perUnitDelta,
      };
    })
    .filter(Boolean) as {
    id: number;
    name: string;
    qty: number;
    priceBefore: number;
    priceAfter: number;
    delta: number;
  }[];
});

// Apply Actions disabled states
const applyDisabled = computed(() => {
  if (savedInvoiceTotal.value <= 0) return true;
  if (hasUnsavedInvoiceTotal.value) return true;
  if (items.value.length === 0) return true;
  if (validationError.value !== null) return true;
  if (Math.abs(delta.value) < 0.001) return true;
  return false;
});

const applyDisabledReason = computed(() => {
  if (savedInvoiceTotal.value <= 0)
    return 'Save Purchase Invoice Total before applying balance';
  if (hasUnsavedInvoiceTotal.value) return 'Save Purchase Invoice Total first — unsaved changes';
  if (items.value.length === 0) return 'No line items to distribute cost to';
  if (validationError.value !== null) return validationError.value;
  if (Math.abs(delta.value) < 0.001) return 'No cost delta to balance';
  return '';
});

// Confirmation Dialog before running Apply
const confirmApply = () => {
  if (applyDisabled.value) return;

  $q.dialog({
    title: 'Apply Purchase Price Balance',
    message: `This will proportionally adjust the purchase prices on ${previewItems.value.length} items to match the paid invoice total of ${purchaseCurrencySymbol.value}${savedInvoiceTotal.value.toFixed(2)}. Continue?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      applying.value = true;
      try {
        await shipmentStore.applyPurchaseBalance(props.shipmentId);
        showSuccessNotification(
          'Purchase price balance successfully distributed and applied across lines.',
        );
        emit('applied');
      } catch (error: unknown) {
        showErrorNotification((error as Error).message || 'Failed to apply purchase balance.');
      } finally {
        applying.value = false;
      }
    })();
  });
};
</script>

<style scoped>
.shipment-purchase-balance-card {
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}
.border-light {
  border: 1px solid rgba(0, 0, 0, 0.06);
}
.price-preview-table th {
  font-weight: 700;
  color: #555;
  background-color: #f3f3f3;
}
.price-preview-table td {
  padding: 6px 8px;
}
.soft-input {
  border-radius: 8px;
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
