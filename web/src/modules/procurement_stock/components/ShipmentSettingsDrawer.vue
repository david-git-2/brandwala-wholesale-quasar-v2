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
          <q-tab name="details" label="Details" />
          <q-tab name="summary" label="Summary" />
          <q-tab name="rates" label="Rates" />
          <q-tab name="progress" label="Progress" />
        </q-tabs>
      </div>

      <!-- Tab Panels -->
      <q-tab-panels v-model="activeTab" animated class="col bg-white">
        <!-- 1. Details Tab Panel -->
        <q-tab-panel name="details" class="q-pa-md bg-white">
          <div class="column q-gutter-y-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
              <q-icon name="ph ph-identification-badge" size="18px" color="primary" />
              <span>General Information</span>
            </div>

            <!-- Shipment Name -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Shipment Name</div>
              <q-input
                v-model="drawerShipmentName"
                outlined
                dense
                placeholder="e.g. Inbound Shipment #89 - Summer Collection"
                class="bg-white"
                :loading="updatingName"
                @blur="saveShipmentName"
                @keyup.enter="saveShipmentName"
              >
                <template #prepend>
                  <q-icon name="ph ph-tag" size="18px" color="grey-6" />
                </template>
              </q-input>
            </div>

            <!-- Shipment Type -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Shipment Type</div>
              <q-select
                v-model="drawerShipmentType"
                :options="drawerTypeOptions"
                emit-value
                map-options
                outlined
                dense
                class="bg-white"
                @update:model-value="saveShipmentType"
              >
                <template #prepend>
                  <q-icon name="ph ph-globe" size="18px" color="grey-6" />
                </template>
              </q-select>
            </div>

            <!-- Cargo Company -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Cargo Company</div>
              <q-select
                v-model="drawerCargoId"
                :options="cargoOptions"
                emit-value
                map-options
                outlined
                dense
                clearable
                placeholder="Select Cargo Company"
                class="bg-white"
                @update:model-value="saveShipmentCargo"
              >
                <template #prepend>
                  <q-icon name="ph ph-airplane-tilt" size="18px" color="grey-6" />
                </template>
              </q-select>
            </div>

            <!-- Primary Vendor -->
            <div>
              <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Primary Vendor</div>
              <q-select
                v-model="drawerVendorId"
                :options="vendorOptions"
                emit-value
                map-options
                outlined
                dense
                clearable
                placeholder="Select Primary Vendor"
                class="bg-white"
                @update:model-value="saveShipmentVendor"
              >
                <template #prepend>
                  <q-icon name="ph ph-storefront" size="18px" color="grey-6" />
                </template>
              </q-select>
            </div>

            <q-separator />

            <!-- Tenant Allocation -->
            <div class="column q-gutter-y-sm">
              <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
                <q-icon name="ph ph-buildings" size="18px" color="primary" />
                <span>Tenant Allocation</span>
              </div>
              <div class="text-caption text-grey-6 text-xxs">
                Which company can list and sell stock from this shipment. Leave empty for the parent warehouse pool.
              </div>
              <q-select
                :model-value="selectedChildTenantId"
                :options="childTenantOptions"
                emit-value
                map-options
                outlined
                dense
                clearable
                placeholder="All companies (parent pool)"
                class="bg-white"
                :loading="childTenantsLoading"
                @update:model-value="(val) => emit('update:selectedChildTenantId', val ?? null)"
              >
                <template #prepend>
                  <q-icon name="ph ph-storefront" size="18px" color="grey-6" />
                </template>
              </q-select>
              <div class="row q-gutter-sm">
                <q-btn
                  color="primary"
                  unelevated
                  no-caps
                  dense
                  label="Save allocation"
                  class="col"
                  :loading="assigningChild"
                  @click="emit('save-assign-child')"
                />
                <q-btn
                  flat
                  no-caps
                  dense
                  label="Clear"
                  class="col"
                  :disable="!assignedChildTenantId || assigningChild"
                  :loading="assigningChild"
                  @click="emit('clear-assign-child')"
                />
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- 2. Summary Tab Panel -->
        <q-tab-panel name="summary" class="q-pa-md bg-white">
          <div class="column q-gutter-y-md">
            <div class="row items-center justify-between">
              <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
                <q-icon name="ph ph-receipt" size="18px" color="primary" />
                <span>Landed Cost Summary</span>
              </div>
              <q-chip dense square color="blue-1" text-color="primary" class="text-weight-bold text-xxs q-ma-none">
                Live Calculations
              </q-chip>
            </div>

            <!-- Physical Totals -->
            <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
              <div class="text-xxs text-weight-bold text-grey-6 uppercase q-mb-xs" style="letter-spacing: 0.5px">
                Physical Quantities & Weight
              </div>
              <div class="row justify-between q-py-xs text-caption">
                <span class="text-grey-7">Total Units:</span>
                <span class="text-weight-bold font-mono text-grey-9">
                  {{ totals.quantity.toLocaleString() }} pcs
                </span>
              </div>
              <div class="row justify-between q-py-xs text-caption">
                <span class="text-grey-7">Packaging Weight:</span>
                <span class="text-weight-bold font-mono text-grey-9">
                  {{ totals.packagingWeightKg.toFixed(2) }} kg
                </span>
              </div>
              <div class="row justify-between q-py-xs text-caption">
                <span class="text-grey-7">Invoice Cargo Weight:</span>
                <span class="text-weight-bold font-mono text-primary">
                  {{ (totals.cargoWeightKg || 0).toFixed(2) }} kg
                </span>
              </div>
              <div class="row justify-between q-py-xs text-caption">
                <span class="text-grey-7">Box Weight Sum:</span>
                <span class="text-weight-bold font-mono text-grey-9">
                  {{ currentShipmentBoxesTotal.toFixed(2) }} kg
                </span>
              </div>
            </div>

            <!-- Purchase Currency Breakdown -->
            <div class="q-gutter-y-xs">
              <div class="text-xxs text-weight-bold text-grey-6 uppercase" style="letter-spacing: 0.5px">
                Purchase Currency ({{ currentPurchaseCurrencySymbol }} {{ currentPurchaseCurrency?.code || 'GBP' }})
              </div>
              <div class="row justify-between q-py-xs text-caption">
                <span class="text-grey-7">Product Purchase Cost:</span>
                <span class="text-weight-bold font-mono text-grey-9">
                  {{ currentPurchaseCurrencySymbol }}{{ totals.goodsPurchase.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                </span>
              </div>
              <div class="row justify-between q-py-xs text-caption">
                <span class="text-grey-7">Cargo Freight Cost:</span>
                <span class="text-weight-bold font-mono text-grey-9">
                  {{ currentPurchaseCurrencySymbol }}{{ totals.cargoPurchase.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                </span>
              </div>
              <div class="row justify-between q-py-xs bg-grey-1 q-px-sm rounded-borders text-caption">
                <span class="text-weight-bold text-grey-8">Total Purchase Cost:</span>
                <span class="text-weight-bold font-mono text-primary">
                  {{ currentPurchaseCurrencySymbol }}{{ totals.totalPurchase.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                </span>
              </div>
            </div>

            <q-separator />

            <!-- Landed Cost Breakdown -->
            <div class="q-gutter-y-xs">
              <div class="text-xxs text-weight-bold text-grey-6 uppercase" style="letter-spacing: 0.5px">
                Cost Currency ({{ currentCostCurrencySymbol }} {{ currentCostCurrency?.code || 'BDT' }})
              </div>
              <div class="row justify-between q-py-xs text-caption">
                <span class="text-grey-7">Product Landed Cost:</span>
                <span class="text-weight-bold font-mono text-grey-9">
                  {{ currentCostCurrencySymbol }}{{ totals.goodsCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                </span>
              </div>
              <div class="row justify-between q-py-xs text-caption">
                <span class="text-grey-7">Cargo Landed Cost:</span>
                <span class="text-weight-bold font-mono text-grey-9">
                  {{ currentCostCurrencySymbol }}{{ totals.cargoCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                </span>
              </div>
              <div class="row justify-between items-center q-pa-sm bg-primary text-white rounded-borders">
                <span class="text-subtitle2 text-weight-bold">Total Landed Cost:</span>
                <span class="text-subtitle1 text-weight-bolder font-mono">
                  {{ currentCostCurrencySymbol }}{{ totals.totalCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                </span>
              </div>
            </div>

            <!-- Live Blended Rate -->
            <div class="bg-blue-1 text-blue-10 q-pa-sm rounded-borders text-center border-grey">
              <div class="text-xxs text-weight-bold uppercase" style="letter-spacing: 0.5px">
                Live Blended Transaction Rate
              </div>
              <div class="text-h6 text-weight-bolder font-mono q-my-xs text-primary">
                <template v-if="totals.transactionRate != null">
                  {{ currentCostCurrencySymbol }}{{ totals.transactionRate.toFixed(4) }} / {{ currentPurchaseCurrencySymbol }}
                </template>
                <template v-else>
                  —
                </template>
              </div>
              <div class="text-caption text-blue-9 text-xxs">
                Weighted by product exchange & cargo conversion
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- 3. Rates Tab Panel -->
        <q-tab-panel name="rates" class="q-pa-md bg-white">
          <div class="column q-gutter-y-lg">
            <q-banner v-if="isStockPosted && canEditCosts" dense rounded class="bg-orange-1 text-orange-10">
              Stock is in. Saving updates landed costs. Invoices already issued keep their cost snapshot.
            </q-banner>
            <q-banner v-if="isCostsLocked" dense rounded class="bg-grey-2 text-grey-9">
              Shipment costs are locked. Rates and weights cannot be changed.
            </q-banner>
            <div class="row items-center justify-between">
              <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
                <q-icon name="ph ph-currency-circle-dollar" size="18px" color="primary" />
                <span>Conversion & Freight Rates</span>
              </div>
              <q-chip
                dense
                square
                :color="savingRates ? 'orange-1' : 'green-1'"
                :text-color="savingRates ? 'orange-9' : 'green-9'"
                class="text-weight-bold text-xxs q-ma-none"
              >
                <q-icon :name="savingRates ? 'ph ph-arrows-clockwise' : 'ph ph-cloud-check'" size="12px" class="q-mr-2xs" />
                {{ savingRates ? 'Saving...' : 'Auto-saved' }}
              </q-chip>
            </div>
            <!-- Total Weight -->
            <div>
              <div class="row items-center justify-between q-mb-xs">
                <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                  Total Weight
                </div>
                <div v-if="productTotalWeightKg > 0" class="text-caption text-grey-7 font-mono" style="font-size: 11px">
                  Lines Total: <span class="text-weight-bold text-grey-9">{{ productTotalWeightKg.toFixed(2) }} kg</span>
                </div>
              </div>
              <q-input
                v-model.number="totalWeightInput"
                label="Total Weight"
                type="number"
                outlined
                dense
                placeholder="0.00"
                suffix="kg"
                class="bg-white font-mono"
                :loading="savingRates"
                :disable="!canEditCosts"
                @blur="onRatesBlur"
                @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
              >
                <template #prepend>
                  <q-icon name="ph ph-scales" size="18px" color="grey-6" />
                </template>
              </q-input>

              <!-- Weight Difference Banner / Warning Message with Adjust Button -->
              <div v-if="hasWeightDifference" class="q-mt-xs">
                <div
                  class="row items-center justify-between q-pa-xs q-px-sm rounded-borders text-caption"
                  :class="weightDifferenceKg > 0 ? 'bg-orange-1 text-orange-9 border-orange' : 'bg-blue-1 text-blue-9 border-blue'"
                  style="font-size: 11px; border: 1px solid currentColor"
                >
                  <div class="row items-center q-gutter-x-xs ellipsis col">
                    <q-icon :name="weightDifferenceKg > 0 ? 'ph ph-warning' : 'ph ph-info'" size="14px" />
                    <span class="ellipsis">
                      Difference: <b>{{ weightDifferenceKg > 0 ? `+${weightDifferenceKg.toFixed(2)}` : weightDifferenceKg.toFixed(2) }} kg</b>
                      ({{ (totalWeightInput || 0).toFixed(2) }} vs {{ productTotalWeightKg.toFixed(2) }} kg)
                    </span>
                  </div>

                  <q-btn
                    unelevated
                    dense
                    no-caps
                    size="xs"
                    color="primary"
                    icon="ph ph-scales"
                    label="Adjust"
                    class="q-px-xs rounded-borders text-weight-bold shrink-0 q-ml-xs"
                    :loading="adjustingWeight"
                    @click="adjustWeightDifference"
                  >
                    <q-tooltip>Balance packaging weights across line items to match {{ totalWeightInput }} kg</q-tooltip>
                  </q-btn>
                </div>
              </div>
              <div v-else-if="totalWeightInput != null && totalWeightInput > 0 && productTotalWeightKg > 0" class="q-mt-xs">
                <div class="row items-center q-gutter-x-xs text-caption text-positive q-px-xs" style="font-size: 11px">
                  <q-icon name="ph ph-check-circle" size="14px" />
                  <span>Total weight matches sum of product packaging weights.</span>
                </div>
              </div>
            </div>

            <q-separator />

            <!-- Cargo Rates -->
            <div class="column q-gutter-y-sm">
              <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                Cargo
              </div>

              <div class="q-pa-sm bg-grey-1 rounded-borders border-grey column q-gutter-y-sm">
                <div class="row q-col-gutter-sm">
                  <div class="col-6">
                    <q-input
                      v-model.number="cargoAmountInput"
                      label="Amount"
                      type="number"
                      dense
                      outlined
                      placeholder="0.00"
                      :prefix="currentPurchaseCurrencySymbol"
                      class="bg-white font-mono"
                      :loading="savingRates"
                      :disable="!canEditCosts"
                      @blur="onRatesBlur"
                      @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                    />
                  </div>
                  <div class="col-6">
                    <q-input
                      v-model.number="cargoRateInput"
                      label="Rate"
                      type="number"
                      dense
                      outlined
                      placeholder="0.00"
                      :prefix="currentCostCurrencySymbol"
                      class="bg-white font-mono"
                      :loading="savingRates"
                      :disable="!canEditCosts"
                      @blur="onRatesBlur"
                      @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                    />
                  </div>
                </div>
                <div>
                  <q-input
                    v-model="cargoNoteInput"
                    label="Note"
                    dense
                    outlined
                    placeholder="e.g. Air freight per kg rate & handling charges"
                    class="bg-white"
                    @blur="onRatesBlur"
                    @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                  />
                </div>
              </div>
            </div>

            <q-separator />

            <!-- Product Rates -->
            <div class="column q-gutter-y-sm">
              <div class="row items-center justify-between">
                <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                  Product
                </div>
                <q-btn
                  outline
                  dense
                  no-caps
                  size="xs"
                  color="primary"
                  icon="ph ph-plus"
                  label="Add Rate"
                  class="q-px-sm rounded-btn text-weight-bold"
                  @click="addProductRateRow"
                />
              </div>

              <div class="column q-gutter-y-sm">
                <div
                  v-for="(prodRate, idx) in productRatesList"
                  :key="prodRate.id"
                  class="q-pa-sm bg-grey-1 rounded-borders border-grey column q-gutter-y-sm"
                >
                  <div class="row items-center justify-between">
                    <span class="text-caption text-weight-bold text-grey-8">Rate #{{ idx + 1 }}</span>
                    <q-btn
                      v-if="productRatesList.length > 1"
                      flat
                      round
                      dense
                      size="xs"
                      icon="ph ph-trash"
                      color="negative"
                      @click="removeProductRateRow(idx)"
                    >
                      <q-tooltip>Remove Rate</q-tooltip>
                    </q-btn>
                  </div>

                  <div class="row q-col-gutter-sm">
                    <div class="col-6">
                      <q-input
                        v-model.number="prodRate.amount"
                        label="Amount"
                        type="number"
                        dense
                        outlined
                        placeholder="0.00"
                        :prefix="currentPurchaseCurrencySymbol"
                        class="bg-white font-mono"
                        :loading="savingRates"
                        :disable="!canEditCosts"
                        @blur="onRatesBlur"
                        @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                      />
                    </div>
                    <div class="col-6">
                      <q-input
                        v-model.number="prodRate.rate"
                        label="Rate"
                        type="number"
                        dense
                        outlined
                        placeholder="0.00"
                        :prefix="currentCostCurrencySymbol"
                        class="bg-white font-mono"
                        :loading="savingRates"
                        :disable="!canEditCosts"
                        @blur="onRatesBlur"
                        @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                      />
                    </div>
                  </div>
                  <div>
                    <q-input
                      v-model="prodRate.note"
                      label="Note"
                      dense
                      outlined
                      placeholder="e.g. Bank TT, cash conversion, vendor balance"
                      class="bg-white"
                      @blur="onRatesBlur"
                      @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- 4. Progress Tab Panel -->
        <q-tab-panel name="progress" class="q-pa-md bg-white">
          <div class="column q-gutter-y-lg">
            <div class="column q-gutter-y-sm">
              <div class="row items-center justify-between">
                <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                  Lifecycle Status
                </div>
                <q-chip
                  dense
                  square
                  :color="lifecycleChipStyle.color"
                  :text-color="lifecycleChipStyle.textColor"
                  class="text-weight-bold text-xxs q-ma-none soft-chip"
                >
                  {{ formatGlobalShipmentStatus(drawerShipmentStatus) }}
                </q-chip>
              </div>
              <div class="text-caption text-grey-6 text-xxs">
                Change Draft → In transit → Received using the workflow bar on the main page.
              </div>
            </div>

            <q-separator />

            <div class="column q-gutter-y-sm">
              <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                Progress Tracking
              </div>
              <div class="q-pa-sm bg-grey-1 rounded-borders border-grey column q-gutter-y-sm">
                <q-select
                  :model-value="progressFlowId"
                  :options="flowSelectOptions"
                  label="Progress flow"
                  emit-value
                  map-options
                  outlined
                  dense
                  class="bg-white"
                  :disable="!!progressUpdating"
                  @update:model-value="onFlowSelect"
                />
                <q-select
                  :model-value="progressTagId"
                  :options="progressSelectOptions"
                  label="Current progress stage"
                  emit-value
                  map-options
                  clearable
                  outlined
                  dense
                  class="bg-white"
                  :loading="!!progressUpdating"
                  :disable="!!progressUpdating || progressSelectOptions.length === 0"
                  @update:model-value="onProgressSelect"
                />
                <div class="text-caption text-grey-6 text-xxs">
                  Mid-journey milestones (customs, airport, hub) are progress tags — not lifecycle status.
                </div>
              </div>
            </div>

            <q-separator />

            <!-- Archive -->
            <div class="column q-gutter-y-sm">
              <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                Shipment Lifecycle
              </div>

              <div class="q-pa-sm bg-grey-1 rounded-borders border-grey row items-center justify-between">
                <div>
                  <div class="text-weight-bold text-xs text-grey-9">Archive Shipment</div>
                  <div class="text-caption text-grey-6 text-xxs">
                    Remove this shipment from the active list. Can be restored anytime.
                  </div>
                </div>

                <q-btn
                  unelevated
                  dense
                  no-caps
                  size="sm"
                  color="grey-8"
                  icon="ph ph-archive-box"
                  label="Archive"
                  class="q-px-sm rounded-sq-btn text-weight-bold"
                  style="border-radius: 6px"
                  :loading="archivingLoading"
                  @click="confirmArchiveFromDrawer"
                />
              </div>
            </div>
          </div>
        </q-tab-panel>
      </q-tab-panels>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type {
  ShipmentProgressFlow,
  ShipmentProgressTag,
} from '../repositories/globalShipmentRepository';
import type { UpsertShipmentCostEntryPayload } from '../types/shipmentCostEntry';
import {
  formatGlobalShipmentStatus,
  globalShipmentStatusChipStyle,
} from '../constants/shipmentStatus';

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    shipmentId: number;
    calculations: any;
    cargoOptions: Array<{ label: string; value: number }>;
    vendorOptions: Array<{ label: string; value: number }>;
    initialTab?: string;
    progressFlowOptions?: ShipmentProgressFlow[];
    progressTagOptions?: ShipmentProgressTag[];
    progressFlowId?: number | null;
    progressTagId?: number | null;
    progressUpdating?: boolean;
    progressTargetId?: number | null;
    childTenantOptions?: Array<{ label: string; value: number }>;
    childTenantsLoading?: boolean;
    selectedChildTenantId?: number | null;
    assigningChild?: boolean;
    assignedChildTenantId?: number | null;
  }>(),
  {
    initialTab: 'details',
    progressFlowOptions: () => [],
    progressTagOptions: () => [],
    progressFlowId: null,
    progressTagId: null,
    progressUpdating: false,
    progressTargetId: null,
    childTenantOptions: () => [],
    childTenantsLoading: false,
    selectedChildTenantId: null,
    assigningChild: false,
    assignedChildTenantId: null,
  },
);

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'update-flow', flowId: number): void;
  (e: 'update-progress', tagId: number | null): void;
  (e: 'update:selectedChildTenantId', val: number | null): void;
  (e: 'save-assign-child'): void;
  (e: 'clear-assign-child'): void;
}>();

const authStore = useAuthStore();
const router = useRouter();
const $q = useQuasar();
const shipmentStore = useGlobalShipmentStore();
const activeTab = ref(props.initialTab || 'details');
const archivingLoading = ref(false);

watch(
  () => [props.modelValue, props.initialTab],
  ([isOpen, tab]) => {
    if (isOpen && tab) {
      activeTab.value = tab as string;
    }
  },
);

const confirmArchiveFromDrawer = () => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return;
  $q.dialog({
    title: 'Archive Shipment',
    message: `Are you sure you want to archive "${shipment.name}" (#${(shipment as any).tenant_shipment_id || shipment.id})? It will be moved out of the active shipments list.`,
    cancel: {
      flat: true,
      label: 'Cancel',
      noCaps: true,
    },
    ok: {
      unelevated: true,
      color: 'primary',
      label: 'Archive',
      noCaps: true,
    },
  }).onOk(async () => {
    archivingLoading.value = true;
    try {
      await shipmentStore.archiveShipment(shipment.id);
      $q.notify({
        type: 'positive',
        message: `Shipment "${shipment.name}" archived successfully.`,
        timeout: 2000,
      });
      emit('update:modelValue', false);
      const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : '';
      void router.push(`${tenantPrefix}/app/procurement/shipments`);
    } catch (err: unknown) {
      $q.notify({
        type: 'negative',
        message: (err as Error).message || 'Failed to archive shipment',
      });
    } finally {
      archivingLoading.value = false;
    }
  });
};

const {
  totals,
  currentShipmentBoxesTotal,
  currentPurchaseCurrency,
  currentPurchaseCurrencySymbol,
  currentCostCurrency,
  currentCostCurrencySymbol,
  isStockPosted,
  isCostsLocked,
  canEditCosts,
} = props.calculations;

const drawerTypeOptions = [
  { label: 'International Inbound', value: 'international' },
  { label: 'Local Procurement', value: 'local' },
  { label: 'Warehouse Transfer', value: 'transfer' },
];

const drawerShipmentName = ref('');
const drawerShipmentType = ref<'international' | 'local' | 'transfer'>('international');
const drawerCargoId = ref<number | null>(null);
const drawerVendorId = ref<number | null>(null);
const drawerShipmentStatus = ref('draft');
const updatingName = ref(false);

const totalWeightInput = ref<number | null>(null);
const cargoAmountInput = ref<number | null>(null);
const cargoRateInput = ref<number | null>(null);
const cargoNoteInput = ref('');
const productRatesList = ref<Array<{ id: string; dbId: number | null; amount: number | null; rate: number | null; note: string }>>([]);
const savingRates = ref(false);

const productTotalWeightKg = computed(() => {
  const calcTotals = props.calculations?.totals?.value ?? props.calculations?.totals;
  if (calcTotals?.packagingWeightKg != null && calcTotals.packagingWeightKg > 0) {
    return calcTotals.packagingWeightKg;
  }
  const items = shipmentStore.currentShipmentItems || [];
  let totalGm = 0;
  for (const item of items) {
    const qty = item.ordered_quantity || 0;
    const pkg = Number(item.package_weight) || 0.35;
    const prod = Number(item.product_weight) || 0;
    totalGm += (prod + pkg) * qty;
  }
  return Math.round((totalGm / 1000) * 100) / 100;
});

const weightDifferenceKg = computed(() => {
  if (totalWeightInput.value == null) return 0;
  return Math.round((Number(totalWeightInput.value) - productTotalWeightKg.value) * 100) / 100;
});

const hasWeightDifference = computed(() => {
  return (
    totalWeightInput.value != null &&
    totalWeightInput.value > 0 &&
    productTotalWeightKg.value > 0 &&
    Math.abs(weightDifferenceKg.value) >= 0.01
  );
});

const adjustingWeight = ref(false);

const adjustWeightDifference = async () => {
  if (!props.shipmentId || totalWeightInput.value == null || totalWeightInput.value <= 0) return;
  const items = shipmentStore.currentShipmentItems || [];
  if (items.length === 0) {
    $q.notify({
      type: 'warning',
      message: 'No line items available to distribute weight across.',
    });
    return;
  }

  adjustingWeight.value = true;
  try {
    const targetWeight = Number(totalWeightInput.value);
    // 1. Update shipment received_weight and total_weight_kg
    await shipmentStore.updateShipment(props.shipmentId, {
      total_weight_kg: targetWeight,
      received_weight: targetWeight,
    });

    // 2. Apply weight balance RPC across all items
    await shipmentStore.applyWeightBalance(props.shipmentId);

    // 3. Refresh details
    await shipmentStore.fetchShipmentDetails(props.shipmentId);

    $q.notify({
      type: 'positive',
      icon: 'ph ph-check-circle',
      message: `Packaging weights adjusted across ${items.length} line items to match ${targetWeight} kg.`,
    });
  } catch (err: unknown) {
    console.error('Failed to balance weight:', err);
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Failed to adjust packaging weights.',
    });
  } finally {
    adjustingWeight.value = false;
  }
};

// Sync from store
watch(
  () => shipmentStore.currentShipment,
  (shipment) => {
    if (shipment) {
      if (shipment.name) drawerShipmentName.value = shipment.name;
      if (shipment.type) drawerShipmentType.value = shipment.type;
      if (shipment.status) drawerShipmentStatus.value = shipment.status;
      if (shipment.cargo_company_id) drawerCargoId.value = shipment.cargo_company_id;
      if (shipment.vendor_id) drawerVendorId.value = shipment.vendor_id;
      totalWeightInput.value = shipment.total_weight_kg ?? shipment.received_weight ?? null;
    }
  },
  { immediate: true },
);

const syncRatesFromStore = () => {
  const entries = shipmentStore.currentCostEntries || [];
  const cargoEntry = entries.find(
    (e: any) => e.cost_type === 'cargo' || e.cost_type === 'cargo_cost' || e.cost_type === 'freight',
  );
  if (cargoEntry) {
    cargoAmountInput.value = cargoEntry.amount != null ? Number(cargoEntry.amount) : null;
    cargoRateInput.value = cargoEntry.exchange_rate != null ? Number(cargoEntry.exchange_rate) : null;
    const meta = (cargoEntry.metadata as Record<string, unknown> | null) ?? {};
    cargoNoteInput.value = typeof meta.note === 'string' ? meta.note : '';
  } else {
    cargoAmountInput.value = null;
    cargoRateInput.value = null;
    cargoNoteInput.value = '';
  }

  const prodEntries = entries.filter(
    (e: any) => e.cost_type === 'product' || e.cost_type === 'purchase_order' || e.cost_type === 'product_purchase',
  );
  if (prodEntries.length > 0) {
    productRatesList.value = prodEntries.map((pe: any) => {
      const meta = (pe.metadata as Record<string, unknown> | null) ?? {};
      return {
        id: `db_${pe.id}`,
        dbId: pe.id,
        amount: pe.amount != null ? Number(pe.amount) : null,
        rate: pe.exchange_rate != null ? Number(pe.exchange_rate) : null,
        note: typeof meta.note === 'string' ? meta.note : '',
      };
    });
  } else {
    productRatesList.value = [
      {
        id: 'rate_default',
        dbId: null,
        amount: null,
        rate: null,
        note: '',
      },
    ];
  }
};

watch(
  () => [shipmentStore.currentShipment, shipmentStore.currentCostEntries],
  () => {
    if (!savingRates.value) {
      syncRatesFromStore();
    }
  },
  { immediate: true, deep: true },
);

const saveShipmentName = async () => {
  if (!props.shipmentId || isNaN(props.shipmentId)) return;
  const trimmed = drawerShipmentName.value.trim();
  if (!trimmed || trimmed === shipmentStore.currentShipment?.name) return;

  updatingName.value = true;
  try {
    await shipmentStore.updateShipment(props.shipmentId, { name: trimmed });
  } finally {
    updatingName.value = false;
  }
};

const saveShipmentType = async (val: any) => {
  if (!props.shipmentId || isNaN(props.shipmentId)) return;
  await shipmentStore.updateShipment(props.shipmentId, { type: val });
};

const saveShipmentCargo = async (val: any) => {
  if (!props.shipmentId || isNaN(props.shipmentId)) return;
  await shipmentStore.updateShipment(props.shipmentId, { cargo_company_id: val });
};

const saveShipmentVendor = async (val: any) => {
  if (!props.shipmentId || isNaN(props.shipmentId)) return;
  await shipmentStore.updateShipment(props.shipmentId, { vendor_id: val });
};

const lifecycleChipStyle = computed(() => globalShipmentStatusChipStyle(drawerShipmentStatus.value));

const flowSelectOptions = computed(() =>
  props.progressFlowOptions
    .filter((flow) => flow.is_active !== false)
    .map((flow) => ({ label: flow.name, value: flow.id })),
);

const progressSelectOptions = computed(() =>
  props.progressTagOptions.map((tag) => ({ label: tag.name, value: tag.id })),
);

const onFlowSelect = (value: number | null | undefined) => {
  if (value != null) emit('update-flow', value);
};

const onProgressSelect = (value: number | null | undefined) => {
  emit('update-progress', value ?? null);
};

const addProductRateRow = () => {
  productRatesList.value.push({
    id: `rate_${Date.now()}`,
    dbId: null,
    amount: null,
    rate: null,
    note: '',
  });
};

const removeProductRateRow = async (index: number) => {
  if (productRatesList.value.length > 1) {
    const removed = productRatesList.value.splice(index, 1)[0];
    if (removed && removed.dbId) {
      try {
        await shipmentStore.deleteShipmentCostEntry(removed.dbId);
      } catch (err) {
        console.error('Failed to delete cost entry:', err);
      }
    }
    await saveRates();
  }
};

let ratesDebounceTimer: ReturnType<typeof setTimeout> | null = null;
const debouncedSaveRates = () => {
  if (ratesDebounceTimer) clearTimeout(ratesDebounceTimer);
  ratesDebounceTimer = setTimeout(() => {
    void saveRates();
  }, 600);
};

const onRatesBlur = () => {
  if (ratesDebounceTimer) {
    clearTimeout(ratesDebounceTimer);
    ratesDebounceTimer = null;
  }
  void saveRates();
};

const saveRates = async () => {
  if (!props.shipmentId || isNaN(props.shipmentId) || savingRates.value) return;
  if (!canEditCosts?.value) return;

  savingRates.value = true;
  try {
    const shipment = shipmentStore.currentShipment;
    const purchaseCurrencyId = shipment?.shipment_purchase_currency_id ?? null;
    const currentWeight = shipment?.total_weight_kg ?? shipment?.received_weight;
    const nextWeight =
      totalWeightInput.value != null ? Number(totalWeightInput.value) : null;
    const weightChanged = totalWeightInput.value !== currentWeight;

    const entries = shipmentStore.currentCostEntries || [];
    const cargoEntry = entries.find(
      (e: any) => e.cost_type === 'cargo' || e.cost_type === 'cargo_cost' || e.cost_type === 'freight',
    );

    const batchEntries: UpsertShipmentCostEntryPayload[] = [];

    if (cargoAmountInput.value != null || cargoRateInput.value != null || cargoNoteInput.value) {
      batchEntries.push({
        shipment_id: props.shipmentId,
        id: cargoEntry?.id ?? null,
        cost_type: 'cargo',
        currency_id: purchaseCurrencyId,
        amount: cargoAmountInput.value != null ? Number(cargoAmountInput.value) : 0,
        exchange_rate: cargoRateInput.value != null ? Number(cargoRateInput.value) : 1,
        metadata: { note: cargoNoteInput.value },
      });
    }

    for (const pr of productRatesList.value) {
      if (pr.amount != null || pr.rate != null || pr.note) {
        batchEntries.push({
          shipment_id: props.shipmentId,
          id: pr.dbId ?? null,
          cost_type: 'product',
          currency_id: purchaseCurrencyId,
          amount: pr.amount != null ? Number(pr.amount) : 0,
          exchange_rate: pr.rate != null ? Number(pr.rate) : 1,
          metadata: { note: pr.note },
        });
      }
    }

    await shipmentStore.saveCostEntriesBatch(props.shipmentId, batchEntries, {
      receivedWeight: weightChanged ? nextWeight : undefined,
      totalWeightKg: weightChanged ? nextWeight : undefined,
    });

    syncRatesFromStore();
    $q.notify({
      message: 'Rates and weight saved',
      color: 'positive',
      icon: 'ph ph-check-circle',
      timeout: 1000,
    });
  } catch (err: unknown) {
    console.error('Failed to save rates and weights:', err);
    $q.notify({
      message: 'Failed to save rates',
      color: 'negative',
      icon: 'ph ph-warning-circle',
      timeout: 1500,
    });
  } finally {
    savingRates.value = false;
  }
};
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-grey {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.text-xxs {
  font-size: 11px;
}
.soft-chip {
  border-radius: 6px;
  font-size: 11px;
}
.font-mono {
  font-family: monospace;
}
</style>
