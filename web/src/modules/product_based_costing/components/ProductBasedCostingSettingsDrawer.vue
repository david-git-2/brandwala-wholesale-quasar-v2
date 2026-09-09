<template>
  <q-dialog
    :model-value="modelValue"
    position="right"
    transition-show="jump-left"
    transition-hide="jump-right"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <q-card
      class="column no-wrap bg-white q-ma-md rounded-borders-lg overflow-hidden shadow-10"
      style="width: 520px; max-width: 95vw; height: calc(100vh - 32px); border-radius: 16px"
    >
      <!-- Top Tabs Bar -->
      <div class="bg-grey-1 border-bottom q-px-sm">
        <q-tabs
          v-model="activeTab"
          dense
          no-caps
          active-color="primary"
          indicator-color="primary"
          align="justify"
          class="text-grey-7 text-weight-medium"
        >
          <q-tab name="details" label="Details" icon="ph ph-identification-badge" />
          <q-tab name="summary" label="Summary" icon="ph ph-chart-pie-slice" />
          <q-tab name="rates" label="Rates" icon="ph ph-percent" />
          <q-tab name="status" label="Status" icon="ph ph-traffic-signal" />
          <q-tab name="actions" label="Actions" icon="ph ph-dots-three-outline" />
        </q-tabs>
      </div>

      <!-- Tab Panels -->
      <q-tab-panels v-model="activeTab" animated class="col bg-white overflow-auto">
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

            <!-- Billing Profile -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Billing Profile</div>
              <q-select
                v-model="drawerBillingProfileId"
                :options="billingProfileOptions"
                emit-value
                map-options
                outlined
                dense
                clearable
                placeholder="Select Billing Profile"
                class="bg-white"
                @update:model-value="saveBillingProfile"
              >
                <template #prepend>
                  <q-icon name="ph ph-receipt" size="18px" color="grey-6" />
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
          </div>
        </q-tab-panel>

        <!-- 2. Summary Tab Panel -->
        <q-tab-panel name="summary" class="q-pa-md bg-white">
          <div class="column q-gutter-y-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
              <q-icon name="ph ph-chart-pie-slice" size="18px" color="primary" />
              <span>Financial & Weight Summary</span>
            </div>

            <!-- Metrics Cards Grid -->
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <div class="q-pa-sm bg-grey-1 rounded-borders border-grey">
                  <div class="text-caption text-grey-6">Total Items / Qty</div>
                  <div class="text-h6 text-weight-bolder text-grey-9 font-mono">
                    {{ summary.totalQuantity }} pcs
                  </div>
                </div>
              </div>
              <div class="col-6">
                <div class="col q-pa-sm bg-amber-1 rounded-borders border-grey">
                  <div class="text-caption text-amber-10">Goods Cost (GBP)</div>
                  <div class="text-h6 text-weight-bolder text-amber-10 font-mono">
                    £{{ formatMoney(summary.goodsCostGbp) }}
                  </div>
                </div>
              </div>
              <div class="col-6">
                <div class="q-pa-sm bg-purple-1 rounded-borders border-grey">
                  <div class="text-caption text-purple-10">Total Cargo Weight</div>
                  <div class="text-h6 text-weight-bolder text-purple-10 font-mono">
                    {{ summary.cargoWeightKg.toFixed(2) }} kg
                  </div>
                </div>
              </div>
              <div class="col-6">
                <div class="q-pa-sm bg-indigo-1 rounded-borders border-grey">
                  <div class="text-caption text-indigo-10">Total Landed Cost</div>
                  <div class="text-h6 text-weight-bolder text-indigo-10 font-mono">
                    ৳{{ formatMoney(summary.totalCostBdt) }}
                  </div>
                </div>
              </div>
              <div class="col-6">
                <div class="q-pa-sm bg-green-1 rounded-borders border-grey">
                  <div class="text-caption text-green-10">Total Offer Amount</div>
                  <div class="text-h6 text-weight-bolder text-positive font-mono">
                    ৳{{ formatMoney(summary.totalOfferPriceBdt) }}
                  </div>
                </div>
              </div>
              <div class="col-6">
                <div class="q-pa-sm bg-teal-1 rounded-borders border-grey">
                  <div class="text-caption text-teal-10">Projected Profit</div>
                  <div class="text-h6 text-weight-bolder text-teal-9 font-mono">
                    ৳{{ formatMoney(summary.totalProfitBdt) }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- 3. Rates Tab Panel -->
        <q-tab-panel name="rates" class="q-pa-md bg-white">
          <div class="column q-gutter-y-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
              <q-icon name="ph ph-percent" size="18px" color="primary" />
              <span>Conversion & Rate Settings</span>
            </div>

            <!-- FX Rate -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Conversion Rate (GBP → BDT)</div>
              <q-input
                v-model.number="drawerConversionRate"
                type="number"
                prefix="৳"
                outlined
                dense
                class="bg-white font-mono"
              />
            </div>

            <!-- Cargo Rate -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Cargo Rate (GBP/kg)</div>
              <q-input
                v-model.number="drawerCargoRate"
                type="number"
                prefix="£"
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
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  formatMoney,
  normalizePbcFileStatus,
} from '../composables/useProductBasedCostingFileDetailsState';
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
  summary: {
    totalQuantity: number;
    goodsCostGbp: number;
    cargoWeightKg: number;
    totalCostBdt: number;
    totalOfferPriceBdt: number;
    totalProfitBdt: number;
  };
  billingProfiles?: any[];
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
  (e: 'update-rates', payload: { conversion_rate: number; cargo_rate_kg_gbp: number; profit_rate: number }): void;
  (e: 'primary-action', action: StaffPbcPrimaryAction): void;
  (e: 'cancel-file'): void;
  (e: 'override-status'): void;
  (e: 'drawer-action', action: PbcSettingsDrawerAction): void;
}>();

const { t } = useI18n();
const activeTab = ref('details');

const drawerFileName = ref('');
const drawerOrderFor = ref('');
const drawerBillingProfileId = ref<number | null>(null);
const drawerNote = ref('');

const drawerConversionRate = ref(140);
const drawerCargoRate = ref(0);
const drawerProfitRate = ref(25);

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
      drawerBillingProfileId.value = newFile.billing_profile_id ?? null;
      drawerNote.value = newFile.note ?? '';

      drawerConversionRate.value = newFile.conversion_rate ?? 140;
      drawerCargoRate.value = newFile.cargo_rate_kg_gbp ?? 0;
      drawerProfitRate.value = newFile.profit_rate ?? 25;
    }
  },
  { immediate: true },
);

const billingProfileOptions = computed(() => {
  return (props.billingProfiles ?? []).map((bp) => ({
    label: bp.name || `Profile #${bp.id}`,
    value: bp.id,
  }));
});

const statusColor = computed(() => {
  const st = normalizedStatus.value;
  if (st === 'confirmed' || st === 'ready_for_shipment' || st === 'delivered') {
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

function saveBillingProfile(val: number | null) {
  emit('update-file', { billing_profile_id: val });
}

function saveNote() {
  if (drawerNote.value !== props.file?.note) {
    emit('update-file', { note: drawerNote.value });
  }
}

function saveRates() {
  emit('update-rates', {
    conversion_rate: Number(drawerConversionRate.value) || 140,
    cargo_rate_kg_gbp: Number(drawerCargoRate.value) || 0,
    profit_rate: Number(drawerProfitRate.value) || 0,
  });
}

function emitDrawerAction(action: PbcSettingsDrawerAction) {
  emit('drawer-action', action);
  emit('update:modelValue', false);
}
</script>

<style scoped>
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
