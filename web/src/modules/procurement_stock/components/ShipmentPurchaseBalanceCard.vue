<template>
  <q-card flat bordered class="q-pa-md shipment-purchase-balance-card bg-white">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-subtitle1 text-weight-bold text-primary row items-center q-gutter-xs">
        <q-icon name="ph ph-money" size="22px" />
        <span>Match paid purchase invoice</span>
      </div>
      <q-badge
        v-if="purchasesMatch"
        color="positive"
        class="q-py-xs q-px-sm text-weight-bold"
      >
        Purchases match invoice
      </q-badge>
      <q-badge v-else-if="hasDelta" :color="deltaColor" class="q-py-xs q-px-sm text-weight-bold">
        Differs by {{ purchaseCurrencySymbol }}{{ Math.abs(delta).toFixed(2) }}
      </q-badge>
    </div>

    <!-- Step 1 -->
    <div class="bg-blue-1 border-light rounded-borders q-pa-sm q-mb-md">
      <div class="text-caption text-weight-bold text-blue-9 q-mb-xs">
        1. Paid purchase invoice total ({{ purchaseCurrencySymbol }})
      </div>
      <div class="text-caption text-grey-7 q-mb-sm" style="font-size: 11px; line-height: 1.3">
        Paid total vs sum of line prices. Save first — apply only redistributes line prices.
      </div>
      <div class="row q-col-gutter-sm items-end">
        <div :class="multiProductRates ? 'col-12 col-sm-6' : 'col-12 col-sm-8'">
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
            :readonly="multiProductRates"
            :disable="multiProductRates"
            :hint="
              multiProductRates
                ? 'Sum of product rates (edit split on Landed cost)'
                : 'Used as product invoice total for costing'
            "
          >
            <template v-slot:append>
              <q-btn
                v-if="!multiProductRates"
                flat
                round
                dense
                icon="ph ph-floppy-disk"
                color="blue-9"
                size="sm"
                :loading="savingPurchaseInvoiceTotal"
                @click="savePurchaseInvoiceTotal"
              >
                <q-tooltip>Save only</q-tooltip>
              </q-btn>
            </template>
          </q-input>
        </div>
        <div v-if="multiProductRates" class="col-12 col-sm-6">
          <q-btn
            color="primary"
            outline
            unelevated
            no-caps
            class="full-width"
            icon="ph ph-arrow-right"
            label="Open Landed cost"
            data-test="purchase-open-landed-cost"
            @click="emit('go-landed-cost')"
          />
        </div>
      </div>
    </div>

    <!-- Step 2 -->
    <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">2. Review the difference</div>
    <div class="text-caption text-grey-7 q-mb-sm" style="font-size: 11px; line-height: 1.3">
      Invoice total vs sum of line purchase prices.
    </div>
    <div class="row q-col-gutter-xs q-mb-md text-center">
      <div class="col-4">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7" style="font-size: 10px">Estimated</div>
          <div
            class="text-subtitle2 text-weight-bold text-mono text-ellipsis"
            style="font-size: 12px"
          >
            {{ purchaseCurrencySymbol }}{{ estimated.toFixed(2) }}
          </div>
        </div>
      </div>
      <div class="col-4">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7" style="font-size: 10px">Invoice</div>
          <div
            class="text-subtitle2 text-weight-bold text-mono text-ellipsis"
            style="font-size: 12px"
          >
            {{ purchaseCurrencySymbol }}{{ actual.toFixed(2) }}
          </div>
        </div>
      </div>
      <div class="col-4">
        <div :class="`q-pa-xs rounded-borders ${deltaBg}`">
          <div class="text-caption text-grey-7" style="font-size: 10px">Delta</div>
          <div
            class="text-subtitle2 text-weight-bold text-mono text-ellipsis"
            style="font-size: 12px"
          >
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
        <q-icon name="ph ph-info" class="q-mr-xs" />
        Unsaved purchase invoice total — click save before applying purchase balance.
      </q-banner>
      <q-banner
        v-if="validationError"
        dense
        class="bg-warning text-black rounded-borders"
        style="font-size: 11px"
      >
        <q-icon name="ph ph-warning" class="q-mr-xs" />
        {{ validationError }}
      </q-banner>
    </div>

    <!-- Step 3 -->
    <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">3. Apply to line items</div>
    <div class="text-caption text-grey-7 q-mb-sm" style="font-size: 11px; line-height: 1.3">
      Spreads the difference across purchase prices on each line.
    </div>
    <div v-if="previewItems.length && !validationError" class="q-mb-sm">
      <q-btn
        outline
        color="secondary"
        icon="ph ph-eye"
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
              <q-icon name="ph ph-money" size="20px" />
              <span>Preview Price Adjustments</span>
            </div>
            <q-space />
            <q-btn icon="ph ph-x" flat round dense v-close-popup />
          </q-card-section>

          <q-card-section class="q-pa-md">
            <div
              style="border: 1px solid rgba(0, 0, 0, 0.08); border-radius: 8px; overflow: hidden"
            >
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
                    <td
                      class="text-left text-caption text-weight-medium ellipsis"
                      style="max-width: 250px"
                    >
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
    <div class="row q-col-gutter-sm">
      <div class="col-12 col-sm-6">
        <q-btn
          outline
          color="primary"
          label="Apply purchase balance"
          class="full-width"
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
      </div>
      <div class="col-12 col-sm-6">
        <q-btn
          color="primary"
          :label="multiProductRates ? 'Apply purchase balance' : 'Save & apply'"
          class="full-width pill-btn shadow-1"
          unelevated
          no-caps
          :disable="saveAndApplyDisabled"
          :loading="savingPurchaseInvoiceTotal || applying"
          @click="saveAndApply"
        >
          <q-tooltip v-if="saveAndApplyDisabled">
            {{ saveAndApplyDisabledReason }}
          </q-tooltip>
        </q-btn>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import {
  computePurchasePriceAdjustments,
  calculateEstimatedPurchaseTotal,
} from '../utils/purchaseBalance';
import { sumProductEntryAmount } from 'src/shared/shipment-engine';
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
  (e: 'go-landed-cost'): void;
}>();

const $q = useQuasar();
const shipmentStore = useGlobalShipmentStore();

const showPreviewDialog = ref(false);
const applying = ref(false);
const savingPurchaseInvoiceTotal = ref(false);
const purchaseInvoiceTotal = ref<number | null>(null);
const purchaseCurrencySymbol = ref('£');

const items = computed(() => shipmentStore.currentShipmentItems);

const productEntryCount = computed(
  () => shipmentStore.currentCostEntries.filter((e: any) => e.cost_type === 'product').length,
);

const multiProductRates = computed(() => productEntryCount.value > 1);

const savedProductInvoiceTotal = computed(() => {
  const fromEntries = sumProductEntryAmount(shipmentStore.currentCostEntries);
  if (fromEntries > 0) return Math.round(fromEntries * 100) / 100;
  return 0;
});

// Estimated total using original prices
const estimated = computed(() => {
  return calculateEstimatedPurchaseTotal(
    items.value.map((item) => ({
      id: item.id,
      name: item.name,
      purchase_price: item.purchase_price || 0,
      ordered_quantity: item.ordered_quantity || 0,
    })),
  );
});

watch(
  savedProductInvoiceTotal,
  (newVal) => {
    purchaseInvoiceTotal.value = newVal > 0 ? newVal : null;
  },
  { immediate: true },
);

// Load currency symbol
onMounted(async () => {
  try {
    if (
      !shipmentStore.currentCostEntries.length &&
      shipmentStore.currentShipment?.id === props.shipmentId
    ) {
      await shipmentStore.fetchCostEntries(props.shipmentId);
    }
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

const savePurchaseInvoiceTotal = async (): Promise<boolean> => {
  if (multiProductRates.value) {
    showWarningNotification('Edit product amounts on Landed cost.');
    return false;
  }
  const val = purchaseInvoiceTotal.value;
  if (val === null || val <= 0) {
    showWarningNotification('Purchase Invoice Total must be greater than 0.');
    return false;
  }
  const rounded = Math.round(val * 100) / 100;
  savingPurchaseInvoiceTotal.value = true;
  try {
    await shipmentStore.savePurchaseInvoiceTotal(props.shipmentId, rounded);
    purchaseInvoiceTotal.value = rounded;
    showSuccessNotification('Purchase invoice total saved.');
    return true;
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to update purchase invoice total.');
    return false;
  } finally {
    savingPurchaseInvoiceTotal.value = false;
  }
};

const savedInvoiceTotal = computed(() => savedProductInvoiceTotal.value);

const hasUnsavedInvoiceTotal = computed(() => {
  if (multiProductRates.value) return false;
  const saved = savedProductInvoiceTotal.value;
  const draft = purchaseInvoiceTotal.value;
  if (draft === null || draft <= 0) return saved > 0;
  const roundedDraft = Math.round(draft * 100) / 100;
  return roundedDraft !== saved;
});

const actual = computed(() => savedInvoiceTotal.value);

const delta = computed(() => {
  return actual.value - estimated.value;
});

const hasDelta = computed(() => {
  return actual.value > 0 && Math.abs(delta.value) > 0.001;
});

const purchasesMatch = computed(() => {
  return actual.value > 0 && Math.abs(delta.value) <= 0.001;
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
  if (savedInvoiceTotal.value <= 0) {
    return multiProductRates.value
      ? 'Set product amounts on Landed cost before applying'
      : 'Save purchase invoice total before applying';
  }
  if (hasUnsavedInvoiceTotal.value) return 'Save purchase invoice total first — unsaved changes';
  if (items.value.length === 0) return 'No line items to distribute cost to';
  if (validationError.value !== null) return validationError.value;
  if (Math.abs(delta.value) < 0.001) return 'Purchases already match';
  return '';
});

const saveAndApplyDisabled = computed(() => {
  if (multiProductRates.value) return applyDisabled.value;
  const draft = purchaseInvoiceTotal.value;
  if (draft === null || draft <= 0) return true;
  if (items.value.length === 0) return true;
  return false;
});

const saveAndApplyDisabledReason = computed(() => {
  if (multiProductRates.value) return applyDisabledReason.value;
  const draft = purchaseInvoiceTotal.value;
  if (draft === null || draft <= 0) return 'Enter a purchase invoice total greater than 0';
  if (items.value.length === 0) return 'No line items to distribute cost to';
  return '';
});

const saveAndApply = async () => {
  if (saveAndApplyDisabled.value) return;
  if (!multiProductRates.value) {
    const saved = await savePurchaseInvoiceTotal();
    if (!saved) return;
  }
  if (applyDisabled.value) {
    if (Math.abs(delta.value) < 0.001) {
      showSuccessNotification('Purchases already match the invoice.');
    }
    return;
  }
  confirmApply();
};

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
