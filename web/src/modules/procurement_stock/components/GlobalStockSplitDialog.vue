<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin shadow-2" style="width: 500px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none" style="position: relative">
        <div class="text-h6 text-primary text-weight-bold">
          Split Stock Quantity
        </div>
        <q-btn
          icon="close"
          flat
          round
          dense
          v-close-popup
          style="position: absolute; top: 12px; right: 12px; z-index: 10"
        />
      </q-card-section>

      <q-separator class="q-my-sm" />

      <q-card-section class="q-pa-md scroll" style="max-height: 60vh">
        <q-banner v-if="error" class="bg-negative text-white rounded-borders q-mb-md q-py-sm">
          {{ error }}
        </q-banner>

        <div v-if="loading" class="text-center q-py-xl">
          <q-spinner color="primary" size="2em" />
          <div class="text-grey-6 q-mt-sm">Loading stock details...</div>
        </div>

        <div v-else class="q-gutter-y-md">
          <!-- Item info panel -->
          <div class="row items-center q-col-gutter-sm q-mb-sm bg-grey-1 q-pa-sm rounded-borders">
            <q-avatar rounded size="48px" class="bg-grey-2">
              <img 
                :src="imageUrl || 'https://placehold.co/48x48?text=No+Image'" 
                style="object-fit: cover; width: 100%; height: 100%"
              />
            </q-avatar>
            <div class="col">
              <div class="text-weight-bold text-grey-9" style="word-break: break-word">{{ itemName }}</div>
              <div class="text-caption text-grey-6">
                Code: {{ productCode || '-' }} | Barcode: {{ barcode || '-' }}
              </div>
            </div>
            <div class="text-right">
              <div class="text-caption text-grey-7">Total Allowed</div>
              <div class="text-subtitle1 text-weight-bolder text-primary">
                {{ totalAllowedQty }} pcs
              </div>
            </div>
          </div>

          <!-- Stock Type Input Grid -->
          <div class="q-gutter-y-sm">
            <div
              v-for="t in stockTypeStore.items"
              :key="t.id"
              class="row items-center justify-between no-wrap q-py-sm border-bottom"
            >
              <div class="column text-left">
                <div class="text-subtitle2 text-grey-9 text-weight-bold" style="line-height: 1.1">
                  {{ t.description }}
                </div>
                <div class="text-caption text-grey-6" style="font-size: 11px">
                  {{ t.is_sellable ? 'Sellable Pool' : 'Non-Sellable Pool' }}
                </div>
              </div>
              
              <q-input
                v-if="splits[t.id]"
                :model-value="splits[t.id]?.quantity"
                @update:model-value="(val) => updateSplit(t.id, Number(val) || 0)"
                type="number"
                dense
                outlined
                style="width: 140px"
                min="0"
                class="text-right"
                :rules="[(val) => Number(val) >= 0 || 'Must be >= 0']"
                hide-bottom-space
              />
            </div>
          </div>
        </div>
      </q-card-section>

      <q-separator class="q-my-sm" />

      <q-card-actions align="between" class="q-px-md q-pb-md">
        <div
          class="text-subtitle2 text-weight-bolder"
          :class="isTotalValid ? 'text-positive' : 'text-negative'"
        >
          Allocated: {{ currentAllocatedTotal }} / {{ totalAllowedQty }} pcs
        </div>

        <div class="row q-gutter-sm">
          <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
          <q-btn
            color="primary"
            unelevated
            label="Save Splits"
            :loading="saving"
            :disable="!isTotalValid || loading"
            no-caps
            @click="onSave"
          />
        </div>
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalStockTypeStore } from '../stores/globalStockTypeStore';
import { globalStockRepository } from '../repositories/globalStockRepository';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  shipmentItemId: number;
  itemName: string;
  productCode: string | null;
  barcode: string | null;
  imageUrl: string | null;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const authStore = useAuthStore();
const stockTypeStore = useGlobalStockTypeStore();

const loading = ref(false);
const saving = ref(false);
const error = ref<string | null>(null);
const totalAllowedQty = ref(0);

interface SplitState {
  quantity: number;
  is_usable: boolean;
}

const splits = ref<Record<number, SplitState>>({});

const updateSplit = (id: number, val: number) => {
  if (splits.value[id]) {
    splits.value[id].quantity = val;
  }
};

onMounted(async () => {
  loading.value = true;
  error.value = null;
  try {
    // 1. Fetch all stock types
    await stockTypeStore.fetchStockTypes(authStore.tenantId);
    
    // Initialize empty splits map
    const initialSplits: Record<number, SplitState> = {};
    stockTypeStore.items.forEach((t) => {
      initialSplits[t.id] = { quantity: 0, is_usable: t.is_sellable };
    });

    // 2. Fetch existing stock rows for this shipment item
    const currentStocks = await globalStockRepository.fetchStocksByShipmentItem(props.shipmentItemId);
    
    // 3. Populate existing values
    currentStocks.forEach((s) => {
      const splitItem = initialSplits[s.stock_type_id];
      if (splitItem) {
        splitItem.quantity = s.quantity;
        splitItem.is_usable = s.is_usable;
      }
    });

    splits.value = initialSplits;

    // 4. Set total allowed quantity
    totalAllowedQty.value = currentStocks.reduce((sum, s) => sum + (s.quantity || 0), 0);
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to initialize split dialog';
  } finally {
    loading.value = false;
  }
});

const currentAllocatedTotal = computed(() => {
  return Object.values(splits.value).reduce((sum, split) => sum + (Number(split.quantity) || 0), 0);
});

const isTotalValid = computed(() => {
  return currentAllocatedTotal.value === totalAllowedQty.value && totalAllowedQty.value > 0;
});

const onSave = async () => {
  if (!isTotalValid.value || !authStore.tenantId) return;
  saving.value = true;
  error.value = null;

  try {
    const stockRows = Object.entries(splits.value).map(([typeId, split]) => ({
      parent_tenant_id: authStore.tenantId!,
      shipment_item_id: props.shipmentItemId,
      stock_type_id: Number(typeId),
      quantity: Number(split.quantity) || 0,
      is_usable: split.is_usable,
    }));

    await globalStockRepository.saveStockSplits(stockRows);

    showSuccessNotification('Stock splits updated successfully.');
    onDialogOK();
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to save stock splits.';
    showErrorNotification(error.value);
  } finally {
    saving.value = false;
  }
};
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
</style>
