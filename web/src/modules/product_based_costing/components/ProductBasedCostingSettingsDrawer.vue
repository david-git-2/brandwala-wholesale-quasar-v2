<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="product_based_costing.settings-drawer-width"
    :default-width="520"
    :min-width="360"
    :max-width="960"
    aria-label="Costing file settings"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <div class="column full-height no-wrap overflow-hidden pbc-settings-drawer">
      <div class="pbc-settings-drawer__header bg-grey-1 border-bottom row items-center no-wrap q-gutter-x-xs q-px-sm q-py-xs">
        <q-tabs
          v-model="activeTab"
          dense
          no-caps
          active-color="primary"
          indicator-color="primary"
          align="left"
          class="col min-width-0 text-grey-7 text-weight-medium pbc-settings-drawer__tabs"
        >
          <q-tab name="details" label="Details" icon="ph ph-identification-badge" />
          <q-tab name="summary" label="Summary" icon="ph ph-chart-pie-slice" />
          <q-tab name="rates" label="Rates" icon="ph ph-percent" />
          <q-tab name="status" label="Status" icon="ph ph-traffic-signal" />
          <q-tab name="actions" label="Actions" icon="ph ph-dots-three-outline" />
        </q-tabs>
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          color="grey-7"
          aria-label="Close settings"
          class="pbc-settings-drawer__close shrink-0"
          @click="emit('update:modelValue', false)"
        />
      </div>

      <q-tab-panels v-model="activeTab" animated class="col bg-white pbc-settings-drawer-panels">
        <!-- 1. Details Tab Panel -->
        <q-tab-panel name="details" class="q-pa-md bg-white">
          <div class="column q-gutter-y-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
              <q-icon name="ph ph-identification-badge" size="18px" color="primary" />
              <span>General Information</span>
            </div>

            <!-- File Name -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Quote / File Name</div>
              <q-input
                v-model="drawerFileName"
                outlined
                dense
                placeholder="e.g. PBC-001 - Winter Catalog"
                class="bg-white"
                :loading="updatingFile"
                @blur="saveFileName"
                @keyup.enter="saveFileName"
              >
                <template #prepend>
                  <q-icon name="ph ph-tag" size="18px" color="grey-6" />
                </template>
              </q-input>
            </div>

            <!-- Customer / Order For -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Customer Name (Order For)</div>
              <q-input
                v-model="drawerOrderFor"
                outlined
                dense
                placeholder="e.g. Acme Wholesale Ltd."
                class="bg-white"
                :loading="updatingFile"
                @blur="saveOrderFor"
                @keyup.enter="saveOrderFor"
              >
                <template #prepend>
                  <q-icon name="ph ph-user" size="18px" color="grey-6" />
                </template>
              </q-input>
            </div>

            <!-- Customer -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">
                {{ $t('product_based_costing.customer') }}
              </div>
              <q-select
                v-model="drawerCustomerGroupId"
                :options="customerGroupOptions"
                emit-value
                map-options
                outlined
                dense
                clearable
                :placeholder="$t('product_based_costing.customer')"
                class="bg-white"
                @update:model-value="saveCustomerGroup"
              >
                <template #prepend>
                  <q-icon name="ph ph-users-three" size="18px" color="grey-6" />
                </template>
              </q-select>
            </div>

            <!-- Notes -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Internal Notes</div>
              <q-input
                v-model="drawerNote"
                type="textarea"
                rows="3"
                outlined
                dense
                placeholder="Add file notes or instructions..."
                class="bg-white"
                @blur="saveNote"
              />
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">
                  {{ $t('product_based_costing.buy_currency_label') }}
                </div>
                <q-select
                  v-model="drawerBuyCurrencyId"
                  :options="currencyOptions"
                  outlined
                  dense
                  emit-value
                  map-options
                  :loading="loadingCurrencies"
                  class="bg-white"
                  @update:model-value="saveCurrencies"
                />
              </div>
              <div class="col-12 col-sm-6">
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">
                  {{ $t('product_based_costing.sell_currency_label') }}
                </div>
                <q-select
                  v-model="drawerSellCurrencyId"
                  :options="currencyOptions"
                  outlined
                  dense
                  emit-value
                  map-options
                  :loading="loadingCurrencies"
                  class="bg-white"
                  @update:model-value="saveCurrencies"
                />
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- 2. Summary Tab Panel -->
        <q-tab-panel name="summary" class="q-pa-sm bg-white">
          <ProductBasedCostingFileSummaryPanel
            :summary-metrics="summaryMetrics"
            :conversion-rate="conversionRate"
            :cargo-rate="cargoRate"
            :profit-rate="profitRate"
            :vat-rate="vatRate"
            :offer-pricing-mode="offerPricingMode"
            :buy-currency-code="drawerBuyCurrencyCode"
            :sell-currency-code="drawerSellCurrencyCode"
            :file-meta="summaryFileMeta"
            show-file-meta
          />
        </q-tab-panel>

        <!-- 3. Rates Tab Panel -->
        <q-tab-panel name="rates" class="q-pa-md bg-white">
          <div class="column q-gutter-y-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
              <q-icon name="ph ph-percent" size="18px" color="primary" />
              <span>Conversion & Rate Settings</span>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">
                  {{ $t('product_based_costing.buy_currency_label') }}
                </div>
                <q-select
                  v-model="drawerBuyCurrencyId"
                  :options="currencyOptions"
                  outlined
                  dense
                  emit-value
                  map-options
                  :loading="loadingCurrencies"
                  class="bg-white"
                />
              </div>
              <div class="col-12 col-sm-6">
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">
                  {{ $t('product_based_costing.sell_currency_label') }}
                </div>
                <q-select
                  v-model="drawerSellCurrencyId"
                  :options="currencyOptions"
                  outlined
                  dense
                  emit-value
                  map-options
                  :loading="loadingCurrencies"
                  class="bg-white"
                />
              </div>
            </div>

            <!-- FX Rate -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">
                {{ $t('product_based_costing.conversion_rate_fx_label', { sell: sellMark, buy: buyMark }) }}
              </div>
              <q-input
                v-model.number="drawerConversionRate"
                type="number"
                :prefix="sellMark"
                outlined
                dense
                class="bg-white font-mono"
              />
            </div>

            <!-- Cargo Rate -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">
                {{ $t('product_based_costing.cargo_rate_per_kg_label', { buy: buyMark }) }}
              </div>
              <q-input
                v-model.number="drawerCargoRate"
                type="number"
                :prefix="buyMark"
                suffix="/kg"
                outlined
                dense
                class="bg-white font-mono"
              />
            </div>

            <!-- Profit Rate -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Default Profit Markup (%)</div>
              <q-input
                v-model.number="drawerProfitRate"
                type="number"
                suffix="%"
                outlined
                dense
                class="bg-white font-mono"
              />
            </div>

            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Offer price mode</div>
              <q-select
                v-model="drawerOfferPricingMode"
                :options="offerPricingModeOptions"
                emit-value
                map-options
                outlined
                dense
                class="bg-white"
              />
            </div>

            <div v-if="drawerOfferPricingMode === 'gbp_vat_then_profit'">
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">VAT on £ price (%)</div>
              <q-input
                v-model.number="drawerVatRate"
                type="number"
                suffix="%"
                outlined
                dense
                class="bg-white font-mono"
              />
            </div>

            <!-- Save Rates Button -->
            <div class="q-pt-sm">
              <q-btn
                unelevated
                color="primary"
                icon="ph ph-check"
                label="Save Rate Changes"
                class="full-width rounded-sq-btn text-weight-bold"
                style="border-radius: 8px"
                :loading="updatingRates"
                @click="saveRates"
              />
            </div>
          </div>
        </q-tab-panel>

        <!-- 4. Status Tab Panel -->
        <q-tab-panel name="status" class="q-pa-md bg-white">
          <div class="column q-gutter-y-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
              <q-icon name="ph ph-traffic-signal" size="18px" color="primary" />
              <span>{{ $t('product_based_costing.status') }}</span>
            </div>

            <ProductBasedCostingProgressBar :status="normalizedStatus" />

            <div class="q-pa-sm bg-grey-1 rounded-borders border-grey row items-center justify-between">
              <div>
                <div class="text-caption text-grey-6">{{ $t('product_based_costing.status') }}</div>
                <div class="text-weight-bold text-subtitle2">
                  {{ currentStatusLabel }}
                </div>
              </div>
              <q-badge
                rounded
                dense
                class="text-weight-bold text-capitalize q-px-sm q-py-2xs text-caption"
                :color="statusColor.color"
                :text-color="statusColor.textColor"
              >
                {{ currentStatusLabel }}
              </q-badge>
            </div>

            <ProductBasedCostingStaffActions
              :status="normalizedStatus"
              :show-cancel="showCancel"
              :is-primary-loading="isPrimaryLoading"
              :is-cancelling="isCancelling"
              :primary-disabled="primaryDisabled"
              :primary-disabled-reason="primaryDisabledReason"
              class="settings-staff-actions"
              @primary-action="emit('primary-action', $event)"
              @cancel-file="emit('cancel-file')"
            />

            <q-btn
              flat
              no-caps
              color="grey-8"
              icon="ph ph-arrows-clockwise"
              :label="$t('product_based_costing.override_status')"
              class="rounded-sq-btn text-weight-medium"
              style="border-radius: 8px"
              @click="emit('override-status')"
            />
          </div>
        </q-tab-panel>

        <!-- 5. Actions Tab Panel -->
        <q-tab-panel name="actions" class="q-pa-md bg-white">
          <div class="column q-gutter-y-sm">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs q-mb-sm">
              <q-icon name="ph ph-dots-three-outline" size="18px" color="primary" />
              <span>File Actions</span>
            </div>

            <q-btn
              flat
              no-caps
              align="left"
              icon="ph ph-pencil-simple"
              :label="$t('product_based_costing.edit_file_details')"
              class="rounded-sq-btn action-list-btn"
              @click="emitDrawerAction('edit-file')"
            />
            <q-btn
              flat
              no-caps
              align="left"
              icon="ph ph-file-pdf"
              :label="$t('product_based_costing.offer_pdf_screenshot')"
              class="rounded-sq-btn action-list-btn"
              :disable="!canOpenOfferPdf"
              @click="emitDrawerAction('offer-pdf')"
            />
            <q-btn
              flat
              no-caps
              align="left"
              icon="ph ph-table"
              :label="$t('product_based_costing.download_excel')"
              class="rounded-sq-btn action-list-btn"
              @click="emitDrawerAction('download-excel')"
            />
          </div>
        </q-tab-panel>
      </q-tab-panels>
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { normalizePbcFileStatus } from '../composables/useProductBasedCostingFileDetailsState';
import {
  pbcCurrencyMark,
  pbcFileBuyCurrencyCode,
  pbcFileSellCurrencyCode,
} from '../utils/pbcFileCurrencies';
import type { PbcFileSummaryMetrics } from '../composables/usePbcFileSummaryMetrics';
import ProductBasedCostingFileSummaryPanel, {
  type PbcSummaryFileMeta,
} from './ProductBasedCostingFileSummaryPanel.vue';
import type { StaffPbcPrimaryAction } from '../utils/pbcFileStatus';
import ProductBasedCostingProgressBar from './ProductBasedCostingProgressBar.vue';
import ProductBasedCostingStaffActions from './ProductBasedCostingStaffActions.vue';

export type PbcSettingsDrawerAction =
  | 'edit-file'
  | 'offer-pdf'
  | 'download-excel';

const props = defineProps<{
  modelValue: boolean;
  file: any;
  summaryMetrics: PbcFileSummaryMetrics;
  conversionRate: number;
  cargoRate: number;
  profitRate: number;
  vatRate: number;
  offerPricingMode: string;
  summaryFileMeta?: PbcSummaryFileMeta | null;
  customers?: Array<{ customer_group_id: number; group_name: string }>;
  status?: string;
  showCancel?: boolean;
  isPrimaryLoading?: boolean;
  isCancelling?: boolean;
  primaryDisabled?: boolean;
  primaryDisabledReason?: string;
  initialTab?: string;
  canOpenOfferPdf?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'update-file', payload: Record<string, any>): void;
  (e: 'update-rates', payload: {
    conversion_rate: number;
    cargo_rate_kg_gbp: number;
    profit_rate: number;
    vat_rate: number;
    offer_pricing_mode: string;
    buy_currency_id: number;
    sell_currency_id: number;
  }): void;
  (e: 'primary-action', action: StaffPbcPrimaryAction): void;
  (e: 'cancel-file'): void;
  (e: 'override-status'): void;
  (e: 'drawer-action', action: PbcSettingsDrawerAction): void;
}>();

const { t } = useI18n();
const activeTab = ref('details');

const drawerFileName = ref('');
const drawerOrderFor = ref('');
const drawerCustomerGroupId = ref<number | null>(null);
const drawerNote = ref('');

const drawerConversionRate = ref(140);
const drawerCargoRate = ref(0);
const drawerProfitRate = ref(25);
const drawerVatRate = ref(0);
const drawerOfferPricingMode = ref('landed_cost_plus');
const drawerBuyCurrencyId = ref<number | null>(null);
const drawerSellCurrencyId = ref<number | null>(null);

const { data: currenciesData, isLoading: loadingCurrencies } = useGlobalCurrenciesQuery();

const currencyOptions = computed(() =>
  (currenciesData.value ?? []).map((c) => ({
    label: `${c.code} (${c.symbol}) - ${c.name}`,
    value: c.id,
  })),
);

const drawerBuyCurrencyCode = computed(() =>
  pbcFileBuyCurrencyCode({
    buy_currency_id: drawerBuyCurrencyId.value,
    buy_currency_code:
      currenciesData.value?.find((c) => c.id === drawerBuyCurrencyId.value)?.code ?? null,
  }),
);

const drawerSellCurrencyCode = computed(() =>
  pbcFileSellCurrencyCode({
    sell_currency_id: drawerSellCurrencyId.value,
    sell_currency_code:
      currenciesData.value?.find((c) => c.id === drawerSellCurrencyId.value)?.code ?? null,
  }),
);

const buyMark = computed(() => pbcCurrencyMark(drawerBuyCurrencyCode.value));
const sellMark = computed(() => pbcCurrencyMark(drawerSellCurrencyCode.value));

const offerPricingModeOptions = [
  { label: 'Cost + profit', value: 'landed_cost_plus' },
  { label: 'VAT then profit on £', value: 'gbp_vat_then_profit' },
];

const updatingFile = ref(false);
const updatingRates = ref(false);

const normalizedStatus = computed(() =>
  normalizePbcFileStatus(props.status ?? props.file?.status ?? 'pending'),
);

const currentStatusLabel = computed(() =>
  t(`product_based_costing.status_${normalizedStatus.value}`),
);

watch(
  () => props.modelValue,
  (open) => {
    if (open && props.initialTab) {
      activeTab.value = props.initialTab;
    }
  },
);

watch(
  () => props.file,
  (newFile) => {
    if (newFile) {
      drawerFileName.value = newFile.name ?? '';
      drawerOrderFor.value = newFile.order_for ?? '';
      drawerCustomerGroupId.value = newFile.customer_group_id ?? null;
      drawerNote.value = newFile.note ?? '';

      drawerConversionRate.value = newFile.conversion_rate ?? 140;
      drawerCargoRate.value = newFile.cargo_rate_kg_gbp ?? 0;
      drawerProfitRate.value = newFile.profit_rate ?? 25;
      drawerVatRate.value = newFile.vat_rate ?? 0;
      drawerOfferPricingMode.value =
        newFile.offer_pricing_mode === 'gbp_vat_then_profit'
          ? 'gbp_vat_then_profit'
          : 'landed_cost_plus';
      drawerBuyCurrencyId.value = newFile.buy_currency_id ?? null;
      drawerSellCurrencyId.value = newFile.sell_currency_id ?? null;
    }
  },
  { immediate: true },
);

const customerGroupOptions = computed(() => {
  return (props.customers ?? []).map((row) => ({
    label: row.group_name || `Group #${row.customer_group_id}`,
    value: row.customer_group_id,
  }));
});

const statusColor = computed(() => {
  const st = normalizedStatus.value;
  if (st === 'confirmed' || st === 'packed' || st === 'delivered') {
    return { color: 'green-1', textColor: 'green-9' };
  }
  if (st === 'offered' || st === 'procuring') {
    return { color: 'blue-1', textColor: 'blue-9' };
  }
  if (st === 'cancelled') {
    return { color: 'red-1', textColor: 'red-9' };
  }
  return { color: 'orange-1', textColor: 'orange-9' };
});

function saveFileName() {
  if (drawerFileName.value.trim() && drawerFileName.value !== props.file?.name) {
    emit('update-file', { name: drawerFileName.value.trim() });
  }
}

function saveOrderFor() {
  if (drawerOrderFor.value !== props.file?.order_for) {
    emit('update-file', { order_for: drawerOrderFor.value.trim() });
  }
}

function saveCustomerGroup(val: number | null) {
  emit('update-file', { customer_group_id: val });
}

function saveNote() {
  if (drawerNote.value !== props.file?.note) {
    emit('update-file', { note: drawerNote.value });
  }
}

function saveCurrencies() {
  if (drawerBuyCurrencyId.value == null || drawerSellCurrencyId.value == null) {
    return;
  }
  const buyChanged = drawerBuyCurrencyId.value !== (props.file?.buy_currency_id ?? null);
  const sellChanged = drawerSellCurrencyId.value !== (props.file?.sell_currency_id ?? null);
  if (!buyChanged && !sellChanged) {
    return;
  }
  emit('update-file', {
    buy_currency_id: drawerBuyCurrencyId.value,
    sell_currency_id: drawerSellCurrencyId.value,
  });
}

function saveRates() {
  if (drawerBuyCurrencyId.value == null || drawerSellCurrencyId.value == null) {
    return;
  }
  emit('update-rates', {
    conversion_rate: Number(drawerConversionRate.value) || 140,
    cargo_rate_kg_gbp: Number(drawerCargoRate.value) || 0,
    profit_rate: Number(drawerProfitRate.value) || 0,
    vat_rate: Number(drawerVatRate.value) || 0,
    offer_pricing_mode: drawerOfferPricingMode.value,
    buy_currency_id: drawerBuyCurrencyId.value,
    sell_currency_id: drawerSellCurrencyId.value,
  });
}

function emitDrawerAction(action: PbcSettingsDrawerAction) {
  emit('drawer-action', action);
  emit('update:modelValue', false);
}
</script>

<style scoped>
.pbc-settings-drawer {
  background: #fff;
  height: 100%;
  min-height: 0;
}

.pbc-settings-drawer__close {
  margin-left: 2px;
}

.pbc-settings-drawer__tabs :deep(.q-tabs__content) {
  overflow-x: auto;
  scrollbar-width: thin;
}

.pbc-settings-drawer-panels {
  min-height: 0;
  overflow: hidden;
}

.pbc-settings-drawer-panels :deep(.q-panel-parent) {
  height: 100%;
  min-height: 0;
}

.pbc-settings-drawer-panels :deep(.q-panel.scroll) {
  height: 100%;
  min-height: 0;
}

.rounded-sq-btn {
  border-radius: 8px !important;
}
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
.border-grey {
  border: 1px solid rgba(0, 0, 0, 0.1);
}
.settings-staff-actions :deep(.pbc-staff-actions) {
  position: static;
  margin: 0;
  border-radius: 8px;
  box-shadow: none;
}
.settings-staff-actions :deep(.pbc-staff-actions__inner) {
  padding: 8px 0;
  flex-wrap: wrap;
}
.action-list-btn {
  justify-content: flex-start;
  width: 100%;
  border-radius: 8px !important;
}
</style>
