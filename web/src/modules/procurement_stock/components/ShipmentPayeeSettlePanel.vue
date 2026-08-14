<template>
  <q-card flat bordered class="q-pa-md bg-white text-grey-9 rounded-borders" data-test="shipment-payee-settle-panel">
    <div class="row items-center justify-between q-mb-sm">
      <div class="row items-center q-gutter-xs">
        <q-icon name="ph ph-wallet" size="20px" color="primary" />
        <span class="text-subtitle1 text-weight-bold text-primary">Payee Settlement & Store Credit</span>
      </div>
      <q-badge
        :color="isReceived ? 'positive' : 'grey-5'"
        outline
        :label="isReceived ? 'Ready to Settle' : 'Disabled until Received'"
      />
    </div>
    <div class="text-caption text-grey-6 q-mb-md">
      Pay vendors and cargo agents, record store credits for short delivery, or use available credit.
    </div>

    <div class="row q-col-gutter-md">
      <!-- Vendor Card -->
      <div class="col-12 col-md-6">
        <q-card flat bordered class="q-pa-sm bg-grey-1 rounded-borders full-height column justify-between" data-test="settle-card-vendor">
          <div>
            <!-- Header -->
            <div class="row items-center justify-between q-mb-xs">
              <div class="row items-center q-gutter-xs">
                <q-avatar size="24px" color="grey-3" text-color="grey-9" class="text-caption text-weight-bold">
                  V
                </q-avatar>
                <span class="text-subtitle2 text-weight-bold text-grey-9">
                  {{ vendorName || 'Vendor' }}
                </span>
              </div>
              <div class="row items-center q-gutter-xs">
                <q-badge color="blue-1" text-color="blue-9" label="Vendor" />
                <q-chip
                  dense
                  square
                  size="xs"
                  :color="vendorAvailableBdt > 0 ? 'purple-1' : 'grey-3'"
                  :text-color="vendorAvailableBdt > 0 ? 'purple-9' : 'grey-8'"
                  data-test="vendor-available-credit-chip"
                >
                  Credit: ৳ {{ formatNumber(vendorAvailableBdt) }}
                </q-chip>
              </div>
            </div>

            <!-- This-Shipment Summary Pills -->
            <div class="row q-col-gutter-xs q-my-xs text-caption">
              <div class="col-4">
                <div class="q-pa-xs bg-white rounded-borders border-grey text-center">
                  <div class="text-grey-6" style="font-size: 10px">Paid</div>
                  <div class="text-weight-bold text-positive">৳ {{ formatNumber(vendorPaidBdt) }}</div>
                </div>
              </div>
              <div class="col-4">
                <div class="q-pa-xs bg-white rounded-borders border-grey text-center">
                  <div class="text-grey-6" style="font-size: 10px">Credited</div>
                  <div class="text-weight-bold text-warning">৳ {{ formatNumber(vendorCreditedBdt) }}</div>
                </div>
              </div>
              <div class="col-4">
                <div class="q-pa-xs bg-white rounded-borders border-grey text-center">
                  <div class="text-grey-6" style="font-size: 10px">Used</div>
                  <div class="text-weight-bold text-purple">৳ {{ formatNumber(vendorUsedBdt) }}</div>
                </div>
              </div>
            </div>

            <!-- Action Selector Toggle -->
            <div class="q-mt-sm">
              <q-btn-toggle
                v-model="vendorAction"
                spread
                dense
                no-caps
                size="xs"
                toggle-color="primary"
                color="white"
                text-color="grey-9"
                class="border-grey rounded-btn q-mb-sm"
                :options="[
                  { label: 'Pay', value: 'pay' },
                  { label: 'Record Credit', value: 'record_credit' },
                  { label: 'Use Credit', value: 'use_credit', disable: vendorAvailableBdt <= 0 }
                ]"
                @update:model-value="onVendorActionChange"
              />

              <!-- Input Row -->
              <div class="row q-col-gutter-xs items-center">
                <div class="col-7">
                  <q-input
                    v-model.number="vendorAmount"
                    type="number"
                    step="0.01"
                    min="0"
                    :label="vendorActionLabel"
                    dense
                    outlined
                    class="bg-white soft-input"
                    :prefix="purchaseCurrencySymbol"
                    :disable="!isVendorEnabled || submitting"
                    placeholder="0.00"
                    :error="isVendorUseCreditOverCap"
                    :error-message="`Exceeds available credit (Max: ${purchaseCurrencySymbol}${formatNumber(vendorMaxUseCreditAmount)})`"
                    data-test="settle-amount-vendor"
                  />
                </div>
                <div class="col-5 text-right">
                  <div class="text-caption text-grey-6">Exchange Rate</div>
                  <div class="text-caption text-weight-medium">
                    1 : {{ formatRate(vendorRate) }} BDT
                  </div>
                </div>
              </div>

              <!-- Converted preview / hint -->
              <div class="text-caption text-grey-7 q-mt-xs row items-center justify-between">
                <span>
                  Converted: <strong class="text-primary">৳ {{ formatNumber(vendorBdtVal) }}</strong> BDT
                </span>
                <span v-if="vendorAction === 'record_credit' && vendorShortageDefault > 0" class="text-amber-9 text-weight-medium" style="font-size: 11px">
                  Shortage default: {{ purchaseCurrencySymbol }}{{ formatNumber(vendorShortageDefault) }}
                </span>
              </div>
            </div>

            <!-- Recent Events Accordion -->
            <q-expansion-item
              v-if="vendorEvents.length > 0"
              dense
              dense-toggle
              header-class="text-caption text-grey-7 q-px-none"
              class="q-mt-xs"
              :label="`Recent settlement events (${vendorEvents.length})`"
            >
              <q-list dense separator class="bg-white rounded-borders border-grey text-caption">
                <q-item v-for="ev in vendorEvents" :key="ev.id" class="q-py-xs">
                  <q-item-section>
                    <div class="row items-center justify-between">
                      <span class="text-weight-bold text-uppercase" :class="actionColorClass(ev.action)">
                        {{ ev.action }}
                      </span>
                      <span class="text-grey-6" style="font-size: 10px">{{ formatDate(ev.created_at) }}</span>
                    </div>
                    <div class="text-grey-8">
                      {{ purchaseCurrencySymbol }}{{ formatNumber(ev.amount_input) }} @ {{ ev.exchange_rate }} = <strong>৳ {{ formatNumber(ev.base_amount) }}</strong> BDT
                    </div>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-expansion-item>
          </div>

          <!-- Submit Button -->
          <div class="row justify-end q-mt-md q-pt-xs border-top-grey">
            <q-btn
              :color="vendorButtonColor"
              unelevated
              no-caps
              dense
              class="q-px-md rounded-btn"
              :icon="vendorButtonIcon"
              :label="vendorButtonText"
              :disable="!isVendorEnabled || !vendorAmount || vendorAmount <= 0 || isVendorUseCreditOverCap || submitting"
              :loading="submitting && activeSubmittingType === 'vendor'"
              data-test="settle-submit-vendor"
              @click="handleSettle('vendor')"
            >
              <q-tooltip v-if="!isReceived">Shipment must be received before settlement.</q-tooltip>
              <q-tooltip v-else-if="!vendorId">No vendor assigned in header.</q-tooltip>
            </q-btn>
          </div>
        </q-card>
      </div>

      <!-- Cargo Company Card -->
      <div class="col-12 col-md-6">
        <q-card flat bordered class="q-pa-sm bg-grey-1 rounded-borders full-height column justify-between" data-test="settle-card-cargo">
          <div>
            <!-- Header -->
            <div class="row items-center justify-between q-mb-xs">
              <div class="row items-center q-gutter-xs">
                <q-avatar size="24px" color="grey-3" text-color="grey-9" class="text-caption text-weight-bold">
                  C
                </q-avatar>
                <span class="text-subtitle2 text-weight-bold text-grey-9">
                  {{ cargoCompanyName || 'Cargo Company' }}
                </span>
              </div>
              <div class="row items-center q-gutter-xs">
                <q-badge color="teal-1" text-color="teal-9" label="Cargo" />
                <q-chip
                  dense
                  square
                  size="xs"
                  :color="cargoAvailableBdt > 0 ? 'teal-1' : 'grey-3'"
                  :text-color="cargoAvailableBdt > 0 ? 'teal-9' : 'grey-8'"
                  data-test="cargo-available-credit-chip"
                >
                  Credit: ৳ {{ formatNumber(cargoAvailableBdt) }}
                </q-chip>
              </div>
            </div>

            <!-- This-Shipment Summary Pills -->
            <div class="row q-col-gutter-xs q-my-xs text-caption">
              <div class="col-4">
                <div class="q-pa-xs bg-white rounded-borders border-grey text-center">
                  <div class="text-grey-6" style="font-size: 10px">Paid</div>
                  <div class="text-weight-bold text-positive">৳ {{ formatNumber(cargoPaidBdt) }}</div>
                </div>
              </div>
              <div class="col-4">
                <div class="q-pa-xs bg-white rounded-borders border-grey text-center">
                  <div class="text-grey-6" style="font-size: 10px">Credited</div>
                  <div class="text-weight-bold text-warning">৳ {{ formatNumber(cargoCreditedBdt) }}</div>
                </div>
              </div>
              <div class="col-4">
                <div class="q-pa-xs bg-white rounded-borders border-grey text-center">
                  <div class="text-grey-6" style="font-size: 10px">Used</div>
                  <div class="text-weight-bold text-purple">৳ {{ formatNumber(cargoUsedBdt) }}</div>
                </div>
              </div>
            </div>

            <!-- Action Selector Toggle -->
            <div class="q-mt-sm">
              <q-btn-toggle
                v-model="cargoAction"
                spread
                dense
                no-caps
                size="xs"
                toggle-color="teal-9"
                color="white"
                text-color="grey-9"
                class="border-grey rounded-btn q-mb-sm"
                :options="[
                  { label: 'Pay', value: 'pay' },
                  { label: 'Record Credit', value: 'record_credit' },
                  { label: 'Use Credit', value: 'use_credit', disable: cargoAvailableBdt <= 0 }
                ]"
                @update:model-value="onCargoActionChange"
              />

              <!-- Input Row -->
              <div class="row q-col-gutter-xs items-center">
                <div class="col-7">
                  <q-input
                    v-model.number="cargoAmount"
                    type="number"
                    step="0.01"
                    min="0"
                    :label="cargoActionLabel"
                    dense
                    outlined
                    class="bg-white soft-input"
                    :prefix="purchaseCurrencySymbol"
                    :disable="!isCargoEnabled || submitting"
                    placeholder="0.00"
                    :error="isCargoUseCreditOverCap"
                    :error-message="`Exceeds available credit (Max: ${purchaseCurrencySymbol}${formatNumber(cargoMaxUseCreditAmount)})`"
                    data-test="settle-amount-cargo"
                  />
                </div>
                <div class="col-5 text-right">
                  <div class="text-caption text-grey-6">Exchange Rate</div>
                  <div class="text-caption text-weight-medium">
                    1 : {{ formatRate(cargoRate) }} BDT
                  </div>
                </div>
              </div>

              <!-- Converted preview -->
              <div class="text-caption text-grey-7 q-mt-xs">
                Converted: <strong class="text-primary">৳ {{ formatNumber(cargoBdtVal) }}</strong> BDT
              </div>
            </div>

            <!-- Recent Events Accordion -->
            <q-expansion-item
              v-if="cargoEvents.length > 0"
              dense
              dense-toggle
              header-class="text-caption text-grey-7 q-px-none"
              class="q-mt-xs"
              :label="`Recent settlement events (${cargoEvents.length})`"
            >
              <q-list dense separator class="bg-white rounded-borders border-grey text-caption">
                <q-item v-for="ev in cargoEvents" :key="ev.id" class="q-py-xs">
                  <q-item-section>
                    <div class="row items-center justify-between">
                      <span class="text-weight-bold text-uppercase" :class="actionColorClass(ev.action)">
                        {{ ev.action }}
                      </span>
                      <span class="text-grey-6" style="font-size: 10px">{{ formatDate(ev.created_at) }}</span>
                    </div>
                    <div class="text-grey-8">
                      {{ purchaseCurrencySymbol }}{{ formatNumber(ev.amount_input) }} @ {{ ev.exchange_rate }} = <strong>৳ {{ formatNumber(ev.base_amount) }}</strong> BDT
                    </div>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-expansion-item>
          </div>

          <!-- Submit Button -->
          <div class="row justify-end q-mt-md q-pt-xs border-top-grey">
            <q-btn
              :color="cargoButtonColor"
              unelevated
              no-caps
              dense
              class="q-px-md rounded-btn"
              :icon="cargoButtonIcon"
              :label="cargoButtonText"
              :disable="!isCargoEnabled || !cargoAmount || cargoAmount <= 0 || isCargoUseCreditOverCap || submitting"
              :loading="submitting && activeSubmittingType === 'cargo_company'"
              data-test="settle-submit-cargo"
              @click="handleSettle('cargo_company')"
            >
              <q-tooltip v-if="!isReceived">Shipment must be received before settlement.</q-tooltip>
              <q-tooltip v-else-if="!cargoCompanyId">No cargo company assigned in header.</q-tooltip>
            </q-btn>
          </div>
        </q-card>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { requestConfirmation } from 'src/utils/appFeedback';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { ListShipmentPayeeSettlementsResult } from '../repositories/globalShipmentRepository';

const props = defineProps<{
  shipmentId: number;
  status: string;
  vendorId?: number | null;
  cargoCompanyId?: number | null;
  vendorName?: string;
  cargoCompanyName?: string;
  vendorRate?: number;
  cargoRate?: number;
  purchaseCurrencySymbol?: string;
  submitting?: boolean;
  vendorProductTotal?: number;
  goodsPurchaseTotal?: number | undefined;
}>();

const emit = defineEmits<{
  settle: [
    payload: {
      entityType: 'vendor' | 'cargo_company';
      entityId: number;
      action: 'pay' | 'record_credit' | 'use_credit';
      amount: number;
      exchangeRate: number;
    },
  ];
}>();

const shipmentStore = useGlobalShipmentStore();

const vendorAction = ref<'pay' | 'record_credit' | 'use_credit'>('pay');
const cargoAction = ref<'pay' | 'record_credit' | 'use_credit'>('pay');

const vendorAmount = ref<number | null>(null);
const cargoAmount = ref<number | null>(null);

const activeSubmittingType = ref<'vendor' | 'cargo_company' | null>(null);

const settlementsData = ref<ListShipmentPayeeSettlementsResult | null>(null);
const loadingSettlements = ref(false);

const fetchSettlements = async () => {
  if (!props.shipmentId) return;
  loadingSettlements.value = true;
  try {
    settlementsData.value = await shipmentStore.listShipmentPayeeSettlements(props.shipmentId);
  } catch (err) {
    console.error('Failed to load shipment payee settlements:', err);
  } finally {
    loadingSettlements.value = false;
  }
};

onMounted(() => {
  void fetchSettlements();
});

watch(
  () => props.shipmentId,
  () => {
    void fetchSettlements();
  },
);

const isReceived = computed(() => props.status === 'received');
const isVendorEnabled = computed(() => isReceived.value && !!props.vendorId);
const isCargoEnabled = computed(() => isReceived.value && !!props.cargoCompanyId);

const vendorRate = computed(() => props.vendorRate ?? 1.0);
const cargoRate = computed(() => props.cargoRate ?? 1.0);

// Vendor Summary Data
const vendorSummary = computed(() => settlementsData.value?.vendor);
const vendorAvailableBdt = computed(() => vendorSummary.value?.available_bdt ?? 0);
const vendorPaidBdt = computed(() => vendorSummary.value?.paid_bdt ?? 0);
const vendorCreditedBdt = computed(() => vendorSummary.value?.credited_bdt ?? 0);
const vendorUsedBdt = computed(() => vendorSummary.value?.used_bdt ?? 0);
const vendorEvents = computed(() => vendorSummary.value?.recent_events ?? []);

// Cargo Summary Data
const cargoSummary = computed(() => settlementsData.value?.cargo_company);
const cargoAvailableBdt = computed(() => cargoSummary.value?.available_bdt ?? 0);
const cargoPaidBdt = computed(() => cargoSummary.value?.paid_bdt ?? 0);
const cargoCreditedBdt = computed(() => cargoSummary.value?.credited_bdt ?? 0);
const cargoUsedBdt = computed(() => cargoSummary.value?.used_bdt ?? 0);
const cargoEvents = computed(() => cargoSummary.value?.recent_events ?? []);

// Shortage default calculation for vendor record_credit
const vendorShortageDefault = computed(() => {
  const prod = props.vendorProductTotal || 0;
  const goods = props.goodsPurchaseTotal || 0;
  if (prod > goods && goods > 0) {
    return Math.round((prod - goods) * 100) / 100;
  }
  return 0;
});

const onVendorActionChange = (action: 'pay' | 'record_credit' | 'use_credit') => {
  if (action === 'record_credit') {
    vendorAmount.value = vendorShortageDefault.value > 0 ? vendorShortageDefault.value : null;
  } else if (action === 'use_credit') {
    const maxVal = vendorMaxUseCreditAmount.value;
    vendorAmount.value = maxVal > 0 ? maxVal : null;
  } else {
    vendorAmount.value = null;
  }
};

const onCargoActionChange = (action: 'pay' | 'record_credit' | 'use_credit') => {
  if (action === 'use_credit') {
    const maxVal = cargoMaxUseCreditAmount.value;
    cargoAmount.value = maxVal > 0 ? maxVal : null;
  } else {
    cargoAmount.value = null;
  }
};

// Capping & BDT calculations
const vendorBdtVal = computed(() =>
  Math.round((vendorAmount.value || 0) * vendorRate.value * 10000) / 10000,
);

const cargoBdtVal = computed(() =>
  Math.round((cargoAmount.value || 0) * cargoRate.value * 10000) / 10000,
);

const vendorMaxUseCreditAmount = computed(() =>
  vendorRate.value > 0
    ? Math.floor((vendorAvailableBdt.value / vendorRate.value) * 100) / 100
    : 0,
);

const cargoMaxUseCreditAmount = computed(() =>
  cargoRate.value > 0
    ? Math.floor((cargoAvailableBdt.value / cargoRate.value) * 100) / 100
    : 0,
);

const isVendorUseCreditOverCap = computed(() => {
  if (vendorAction.value !== 'use_credit') return false;
  return vendorBdtVal.value > vendorAvailableBdt.value + 0.01;
});

const isCargoUseCreditOverCap = computed(() => {
  if (cargoAction.value !== 'use_credit') return false;
  return cargoBdtVal.value > cargoAvailableBdt.value + 0.01;
});

// UI helpers
const vendorActionLabel = computed(() => {
  if (vendorAction.value === 'pay') return 'Pay amount';
  if (vendorAction.value === 'record_credit') return 'Credit amount';
  return 'Use credit amount';
});

const cargoActionLabel = computed(() => {
  if (cargoAction.value === 'pay') return 'Pay amount';
  if (cargoAction.value === 'record_credit') return 'Credit amount';
  return 'Use credit amount';
});

const vendorButtonText = computed(() => {
  if (vendorAction.value === 'pay') return 'Pay Vendor';
  if (vendorAction.value === 'record_credit') return 'Record Vendor Credit';
  return 'Use Vendor Credit';
});

const cargoButtonText = computed(() => {
  if (cargoAction.value === 'pay') return 'Pay Cargo';
  if (cargoAction.value === 'record_credit') return 'Record Cargo Credit';
  return 'Use Cargo Credit';
});

const vendorButtonColor = computed(() => {
  if (vendorAction.value === 'pay') return 'primary';
  if (vendorAction.value === 'record_credit') return 'warning';
  return 'purple';
});

const cargoButtonColor = computed(() => {
  if (cargoAction.value === 'pay') return 'teal-9';
  if (cargoAction.value === 'record_credit') return 'warning';
  return 'purple';
});

const vendorButtonIcon = computed(() => {
  if (vendorAction.value === 'pay') return 'ph ph-hand-coins';
  if (vendorAction.value === 'record_credit') return 'ph ph-arrow-down-left';
  return 'ph ph-arrow-up-right';
});

const cargoButtonIcon = computed(() => {
  if (cargoAction.value === 'pay') return 'ph ph-hand-coins';
  if (cargoAction.value === 'record_credit') return 'ph ph-arrow-down-left';
  return 'ph ph-arrow-up-right';
});

const formatNumber = (val: number) =>
  (val || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatRate = (val: number) =>
  (val || 1).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 });

const formatDate = (str: string) => {
  if (!str) return '';
  const d = new Date(str);
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
};

const actionColorClass = (action: string) => {
  if (action === 'pay') return 'text-positive';
  if (action === 'record_credit') return 'text-warning';
  if (action === 'use_credit') return 'text-purple';
  return 'text-grey-8';
};

const handleSettle = async (entityType: 'vendor' | 'cargo_company') => {
  const isVendor = entityType === 'vendor';
  const entityId = isVendor ? props.vendorId : props.cargoCompanyId;
  const action = isVendor ? vendorAction.value : cargoAction.value;
  const amount = isVendor ? vendorAmount.value : cargoAmount.value;
  const rate = isVendor ? vendorRate.value : cargoRate.value;
  const payeeName = isVendor
    ? props.vendorName || 'Vendor'
    : props.cargoCompanyName || 'Cargo Company';
  const bdtVal = isVendor ? vendorBdtVal.value : cargoBdtVal.value;

  if (!entityId || !amount || amount <= 0) return;

  let confirmMsg = '';
  let confirmTitle = '';
  const symbol = props.purchaseCurrencySymbol || '';

  if (action === 'pay') {
    confirmTitle = 'Confirm Payment';
    confirmMsg = `Pay ${symbol}${amount} (৳ ${formatNumber(bdtVal)} BDT) to ${payeeName}?`;
  } else if (action === 'record_credit') {
    confirmTitle = 'Confirm Store Credit';
    confirmMsg = `Record ${symbol}${amount} (৳ ${formatNumber(bdtVal)} BDT) store credit for ${payeeName}?`;
  } else {
    confirmTitle = 'Confirm Credit Usage';
    confirmMsg = `Use ${symbol}${amount} (৳ ${formatNumber(bdtVal)} BDT) store credit from ${payeeName} balance?`;
  }

  const ok = await requestConfirmation(confirmMsg, confirmTitle, 'Confirm');
  if (!ok) return;

  activeSubmittingType.value = entityType;
  emit('settle', {
    entityType,
    entityId,
    action,
    amount,
    exchangeRate: rate,
  });
};

const resetInputs = () => {
  vendorAmount.value = null;
  cargoAmount.value = null;
  activeSubmittingType.value = null;
  void fetchSettlements();
};

defineExpose({ resetInputs, fetchSettlements });
</script>

<style scoped>
.rounded-borders {
  border-radius: 10px;
}
.rounded-btn {
  border-radius: 8px;
}
.border-grey {
  border: 1px solid var(--bw-theme-border, #e0e0e0);
}
.border-top-grey {
  border-top: 1px solid var(--bw-theme-border, #e0e0e0);
}
</style>
