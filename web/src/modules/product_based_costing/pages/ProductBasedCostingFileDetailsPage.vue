<template>
  <q-page class="q-pa-md costing-details-page">
    <div class="q-gutter-y-md">
      <!-- Loading Skeleton State -->
      <template v-if="isLoading">
        <!-- Header Skeleton -->
        <section class="row items-center justify-between q-col-gutter-md">
          <div class="col">
            <div class="row items-center q-gutter-x-sm">
              <q-skeleton type="QBtn" size="32px" flat />
              <div>
                <q-skeleton type="text" width="130px" height="14px" class="q-mb-xs" />
                <q-skeleton type="text" width="240px" height="32px" />
                <q-skeleton type="text" width="160px" height="14px" class="q-mt-xs" />
              </div>
            </div>
          </div>
          <div class="col-auto row q-gutter-sm items-center">
            <q-skeleton type="QBtn" width="100px" height="36px" />
            <q-skeleton type="QBtn" width="36px" height="36px" />
          </div>
        </section>

        <!-- Workflow Strip Skeleton -->
        <q-card flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-grow row items-center q-gutter-xs">
              <q-skeleton v-for="n in 6" :key="n" type="QBtn" width="90px" height="28px" />
            </div>
            <div class="col-auto">
              <q-skeleton type="QBtn" width="80px" height="28px" />
            </div>
          </div>
        </q-card>

        <!-- Table Skeleton -->
        <q-markup-table flat bordered class="costing-items-surface">
          <thead>
            <tr>
              <th style="width: 40px"><q-skeleton type="QCheckbox" /></th>
              <th><q-skeleton type="text" width="40px" /></th>
              <th><q-skeleton type="text" width="60px" /></th>
              <th><q-skeleton type="text" width="140px" /></th>
              <th><q-skeleton type="text" width="80px" /></th>
              <th class="text-right"><q-skeleton type="text" width="70px" /></th>
              <th class="text-right"><q-skeleton type="text" width="80px" /></th>
              <th class="text-right"><q-skeleton type="text" width="90px" /></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="n in 5" :key="n">
              <td><q-skeleton type="QCheckbox" /></td>
              <td><q-skeleton type="text" width="20px" /></td>
              <td><q-skeleton type="QAvatar" size="32px" square class="rounded-borders" /></td>
              <td><q-skeleton type="text" width="85%" /></td>
              <td><q-skeleton type="text" width="70%" /></td>
              <td class="text-right"><q-skeleton type="text" width="60px" class="q-ml-auto" /></td>
              <td class="text-right"><q-skeleton type="text" width="70px" class="q-ml-auto" /></td>
              <td class="text-right"><q-skeleton type="text" width="80px" class="q-ml-auto" /></td>
            </tr>
          </tbody>
        </q-markup-table>
      </template>

      <!-- Loaded Content State -->
      <template v-else>
        <section class="row items-center justify-between q-col-gutter-md">
          <div class="col">
            <div class="row items-center q-gutter-x-sm">
              <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="goBack" />
              <div>
                <div class="text-overline text-primary">Product Based Costing</div>
                <div class="row items-center q-gutter-x-xs">
                  <template v-if="isEditingName">
                    <q-input
                      ref="nameInputRef"
                      v-model="editingNameValue"
                      dense
                      outlined
                      autofocus
                      class="text-h5 text-weight-bold name-inline-input"
                      style="min-width: 220px; max-width: 380px;"
                      :loading="savingName"
                      @blur="saveInlineName"
                      @keyup.enter="saveInlineName"
                      @keyup.esc="cancelInlineName"
                    />
                  </template>
                  <template v-else>
                    <h1
                      class="text-h5 text-weight-bold q-my-none cursor-pointer name-inline-edit row items-center q-gutter-x-xs"
                      title="Click to edit name"
                      @click="startInlineNameEdit"
                    >
                      <span>{{ file?.name ?? 'Costing File' }}</span>
                      <q-icon name="ph ph-pencil-simple" size="18px" class="q-ml-xs edit-icon text-grey-6" />
                    </h1>
                  </template>

                </div>
                <div class="row items-center q-gutter-x-xs q-mt-xs text-body2 text-grey-7">
                  <span>Created for</span>
                  <q-select
                    v-model="selectedBillingProfile"
                    :options="billingProfileOptions"
                    option-label="name"
                    option-value="id"
                    dense
                    borderless
                    use-input
                    hide-dropdown-icon
                    input-debounce="300"
                    :loading="loadingProfiles || savingBillingProfile"
                    class="billing-profile-select-pill"
                    @filter="filterBillingProfiles"
                    @update:model-value="onInlineBillingProfileChange"
                  >
                    <template #selected>
                      <div
                        class="row items-center text-primary text-weight-bold cursor-pointer profile-picker-chip"
                        title="Click to change billing profile"
                      >
                        <q-icon name="ph ph-user-circle" size="16px" class="q-mr-xs" />
                        <span>{{ selectedBillingProfile?.name ?? 'Select Billing Profile' }}</span>
                        <q-icon name="ph ph-caret-down" size="14px" class="q-ml-xs text-primary" />
                      </div>
                    </template>

                    <template #option="scope">
                      <q-item v-bind="scope.itemProps" dense class="rounded-borders q-my-xs">
                        <q-item-section avatar style="min-width: 28px">
                          <q-icon name="ph ph-user text-primary" size="16px" />
                        </q-item-section>
                        <q-item-section>
                          <q-item-label class="text-weight-medium">{{ scope.opt.name }}</q-item-label>
                          <q-item-label v-if="scope.opt.email" caption class="text-grey-6">{{ scope.opt.email }}</q-item-label>
                        </q-item-section>
                      </q-item>
                    </template>

                    <template #no-option>
                      <q-item dense>
                        <q-item-section class="text-grey caption">No billing profiles found</q-item-section>
                      </q-item>
                    </template>
                  </q-select>
                </div>
              </div>
            </div>
          </div>
          <div class="col-auto row q-gutter-sm items-center">
            <q-btn
              v-if="file?.billing_profile_id"
              outline
              color="primary"
              no-caps
              icon="ph ph-tray"
              label="Backlog"
              :loading="backlog.loading.value"
              @click="openBacklogDrawer"
            >
              <q-badge
                v-if="backlog.items.value.length > 0"
                color="orange-9"
                floating
                rounded
              >
                {{ backlog.items.value.length }}
              </q-badge>
            </q-btn>
            <q-btn
              color="primary"
              unelevated
              no-caps
              label="Add Item"
              @click="openCreateDialog"
            />
            <q-btn flat dense icon="ph ph-dots-three-vertical" aria-label="Actions">
              <q-menu style="min-width: 200px">
                <q-list dense>
                  <q-item clickable v-close-popup @click="openEditFileDialog">
                    <q-item-section avatar>
                      <q-icon name="ph ph-pencil-simple" />
                    </q-item-section>
                    <q-item-section>Edit File Details</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="openBulkPaste">
                    <q-item-section avatar>
                      <q-icon name="ph ph-clipboard" />
                    </q-item-section>
                    <q-item-section>Bulk Paste</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="openCatalogDialog">
                    <q-item-section avatar>
                      <q-icon name="ph ph-shopping-cart" />
                    </q-item-section>
                    <q-item-section>Add from Catalog</q-item-section>
                  </q-item>
                  <q-item clickable>
                    <q-item-section avatar>
                      <q-icon name="ph ph-columns" />
                    </q-item-section>
                    <q-item-section>Columns</q-item-section>
                    <q-item-section side>
                      <q-icon name="ph ph-caret-right" />
                    </q-item-section>
                    <q-menu anchor="top end" self="top start">
                      <q-list style="min-width: 240px">
                        <q-item>
                          <q-item-section>
                            <div class="text-subtitle2">Show Columns</div>
                          </q-item-section>
                        </q-item>
                        <q-item clickable>
                          <q-item-section>
                            <q-checkbox
                              v-model="allSelectableColumnsSelected"
                              label="Select / Deselect All"
                            />
                          </q-item-section>
                        </q-item>
                        <q-item>
                          <q-item-section>
                            <q-option-group
                              v-model="visibleColumns"
                              type="checkbox"
                              :options="columnSelectorOptions"
                            />
                          </q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-item>
                  <q-separator />
                  <q-item clickable v-close-popup @click="openPreviewAndPrint">
                    <q-item-section avatar>
                      <q-icon name="ph ph-eye" />
                    </q-item-section>
                    <q-item-section>Preview & Print</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="downloadExcel">
                    <q-item-section avatar>
                      <q-icon name="ph ph-table" />
                    </q-item-section>
                    <q-item-section>Download Excel</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </div>
        </section>

        <q-card v-if="file" flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-grow row items-center q-gutter-xs status-workflow-row">
              <template v-for="(st, idx) in workflowStatuses" :key="st">
                <q-btn
                  :color="status === st ? getStatusColor(st) : isPassedStatus(st) ? 'grey-5' : 'grey-3'"
                  :text-color="status === st ? 'white' : isPassedStatus(st) ? 'grey-9' : 'grey-7'"
                  :outline="status !== st"
                  :unelevated="status === st"
                  dense
                  no-caps
                  class="q-px-md text-caption text-weight-bold"
                  :loading="updatingStatus && targetUpdatingStatus === st"
                  :disable="updatingStatus && targetUpdatingStatus !== st"
                  @click="onUpdateStatus(st)"
                >
                  <q-icon
                    v-if="status === st"
                    name="ph ph-check-circle"
                    size="14px"
                    class="q-mr-xs"
                  />
                  {{ formatStatusLabel(st) }}
                </q-btn>
                <q-icon
                  v-if="idx < workflowStatuses.length - 1"
                  name="ph ph-caret-right"
                  color="grey-5"
                  size="18px"
                  class="status-workflow-chevron"
                />
              </template>
              <q-separator vertical class="q-mx-sm status-workflow-sep" />
              <q-btn
                :color="status === 'cancelled' ? 'negative' : 'grey-3'"
                :text-color="status === 'cancelled' ? 'white' : 'grey-7'"
                :outline="status !== 'cancelled'"
                :unelevated="status === 'cancelled'"
                dense
                no-caps
                class="q-px-md text-caption text-weight-bold"
                :loading="updatingStatus && targetUpdatingStatus === 'cancelled'"
                :disable="updatingStatus && targetUpdatingStatus !== 'cancelled'"
                @click="onUpdateStatus('cancelled')"
              >
                <q-icon
                  v-if="status === 'cancelled'"
                  name="ph ph-x-circle"
                  size="14px"
                  class="q-mr-xs"
                />
                Cancelled
              </q-btn>
            </div>

            <div class="col-auto row items-center q-gutter-sm">
              <div v-if="!ratesExpanded" class="text-caption text-grey-7 rates-summary">
                {{ ratesSummary }}
              </div>
              <q-btn
                flat
                dense
                no-caps
                color="primary"
                :icon="ratesExpanded ? 'ph ph-caret-up' : 'ph ph-sliders-horizontal'"
                :label="ratesExpanded ? 'Hide Rates' : 'Rates'"
                class="q-px-sm rounded-borders"
                @click="ratesExpanded = !ratesExpanded"
              />
            </div>
          </div>

          <div v-if="ratesExpanded" class="row items-end q-col-gutter-sm q-mt-sm">
            <div class="col-12 col-sm-6 col-md-3">
              <q-input
                v-model.number="conversion_rate"
                dense
                outlined
                type="number"
                class="soft-input"
                label="Conversion Rate"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-3">
              <q-input
                v-model.number="cargo_rate_kg_gbp"
                dense
                outlined
                type="number"
                class="soft-input"
                label="Cargo Rate (kg/GBP)"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-3">
              <q-input
                v-model.number="profit_rate"
                dense
                outlined
                type="number"
                class="soft-input"
                label="Profit Rate"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-3">
              <q-btn
                color="primary"
                unelevated
                no-caps
                dense
                class="full-width"
                label="Save Rates"
                @click="onRateSave"
              />
            </div>
          </div>
        </q-card>

        <div v-if="!file" class="text-negative">File not found.</div>
        <q-card v-else flat bordered class="q-pa-none costing-items-surface">
          <ProductBasedCostingItemsTable
            :items="costingItems"
            :cargo-rate="cargoRateValue"
            :conversion-rate="conversionRateValue"
            :profit-rate="profitRateValue"
            :status="file?.status ?? 'pending'"
            :shipped-item-ids="shippedItemIds"
            :visible-columns="visibleColumns"
            @edit="onEdit"
            @delete="onDelete"
            @row-change="onRowChange"
            @product-weight-change="onProductWeightChange"
            @package-weight-change="onPackageWeightChange"
            @bulk-delete="onBulkDelete"
            @update:visible-columns="onVisibleColumnsUpdate"
          />
        </q-card>
        <div v-if="costingItems.length" class="q-mt-lg">
          <div class="text-subtitle1 text-weight-bold q-mb-sm text-grey-9 row items-center">
            <q-icon name="ph ph-chart-line-up" class="q-mr-xs text-primary" size="20px" />
            Summary Metrics & Cost Breakdown
          </div>

          <div class="row q-col-gutter-md">
            <!-- Goods Cost Card -->
            <div class="col-12 col-md-6">
              <q-card flat bordered class="q-pa-md fill-height card-hover metric-card bg-surface-subtle">
                <div class="row items-center q-mb-md">
                  <div class="metric-icon-badge bg-primary-subtle text-primary q-mr-sm">
                    <q-icon name="ph ph-package" size="18px" />
                  </div>
                  <div class="text-subtitle2 text-weight-bold text-primary">Goods Cost Summary</div>
                </div>
                <div class="q-gutter-y-sm">
                  <div class="row justify-between items-center">
                    <span class="text-caption text-grey-7">Total Quantity</span>
                    <span class="text-body2 text-weight-bold text-grey-9">{{ summaryMetrics.totalQuantity.toLocaleString() }} pcs</span>
                  </div>
                  <q-separator light />
                  <div class="row justify-between items-center">
                    <span class="text-caption text-grey-7">Total Purchase Price (GBP)</span>
                    <span class="text-body2 text-weight-bold text-grey-9">£ {{ formatMoney(summaryMetrics.goodsCostGbp) }}</span>
                  </div>
                  <q-separator light />
                  <div class="row justify-between items-center">
                    <span class="text-caption text-grey-7">Conversion Rate</span>
                    <span class="text-body2 text-weight-medium text-grey-8">{{ conversionRateValue }}</span>
                  </div>
                  <q-separator light />
                  <div class="row justify-between items-center">
                    <span class="text-caption text-weight-medium text-grey-9">Goods Cost (BDT)</span>
                    <span class="text-subtitle2 text-weight-bold text-primary">৳ {{ formatMoney(summaryMetrics.goodsCostBdt) }}</span>
                  </div>
                </div>
              </q-card>
            </div>

            <!-- Cargo Cost Card -->
            <div class="col-12 col-md-6">
              <q-card flat bordered class="q-pa-md fill-height card-hover metric-card bg-surface-subtle">
                <div class="row items-center q-mb-md">
                  <div class="metric-icon-badge bg-teal-subtle text-teal-9 q-mr-sm">
                    <q-icon name="ph ph-truck" size="18px" />
                  </div>
                  <div class="text-subtitle2 text-weight-bold text-teal-9">Cargo Cost Summary</div>
                </div>
                <div class="q-gutter-y-sm">
                  <div class="row justify-between items-center">
                    <span class="text-caption text-grey-7">Cargo Weight (KG)</span>
                    <span class="text-body2 text-weight-bold text-grey-9">{{ summaryMetrics.cargoWeightKg.toFixed(2) }} kg</span>
                  </div>
                  <q-separator light />
                  <div class="row justify-between items-center">
                    <span class="text-caption text-grey-7">Cargo Cost (GBP)</span>
                    <span class="text-body2 text-weight-bold text-grey-9">£ {{ formatMoney(summaryMetrics.cargoCostGbp) }}</span>
                  </div>
                  <q-separator light />
                  <div class="row justify-between items-center">
                    <span class="text-caption text-grey-7">Cargo Conversion Rate</span>
                    <span class="text-body2 text-weight-medium text-grey-8">{{ conversionRateValue }}</span>
                  </div>
                  <q-separator light />
                  <div class="row justify-between items-center">
                    <span class="text-caption text-weight-medium text-grey-9">Cargo Cost (BDT)</span>
                    <span class="text-subtitle2 text-weight-bold text-teal-9">৳ {{ formatMoney(summaryMetrics.cargoCostBdt) }}</span>
                  </div>
                </div>
              </q-card>
            </div>

            <!-- Total Cost Summary Card -->
            <div class="col-12">
              <q-card flat bordered class="q-pa-md total-landed-cost-card">
                <div class="row items-center justify-between q-col-gutter-sm">
                  <div class="col-12 col-sm-auto row items-center">
                    <div class="metric-icon-badge bg-primary-subtle text-primary q-mr-sm">
                      <q-icon name="ph ph-coins" size="20px" />
                    </div>
                    <div>
                      <div class="text-caption text-uppercase text-weight-bold text-grey-7">Total Landed Cost</div>
                      <div class="text-subtitle2 text-weight-bold text-grey-9">Goods Cost (BDT) + Cargo Cost (BDT)</div>
                    </div>
                  </div>
                  <div class="col-12 col-sm-auto text-right">
                    <div class="text-h6 text-weight-bolder text-primary">
                      ৳ {{ formatMoney(summaryMetrics.totalCostBdt) }}
                    </div>
                  </div>
                </div>
              </q-card>
            </div>
          </div>
        </div>

        <PbcBacklogSuggestDrawer
          v-model="showBacklogDrawer"
          :items="backlog.items.value"
          :loading="backlog.loading.value"
          :adding="backlog.saving.value"
          @add="handleConsumeBacklog"
        />

        <ProductBasedCostingFileDialog
          v-model="showFileDialog"
          :data="editFormData"
          @submit="handleUpdateFileDialog"
        />

        <ProductBasedCostingItemAddDialog
          v-model="showItemDialog"
          :product-based-costing-file-id="fileId"
          :item-data="selectedItem"
          :default-vendor-code="file?.vendor_code ?? null"
          :default-market-code="file?.market_code ?? null"
          @created="handleCreated"
          @updated="handleUpdated"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue';
import ProductBasedCostingItemAddDialog from '../components/ProductBasedCostingItemAddDialog.vue';
import PbcBacklogSuggestDrawer from '../components/PbcBacklogSuggestDrawer.vue';
import AddCostingItemsDrawer from '../components/AddCostingItemsDrawer.vue';
import BulkPasteCostingItemsDialog from '../components/BulkPasteCostingItemsDialog.vue';
import ProductBasedCostingPreviewColumnSelectorDialog from '../components/ProductBasedCostingPreviewColumnSelectorDialog.vue';
import ProductBasedCostingItemsTable from '../components/ProductBasedCostingItemsTable.vue';
import { useProductStore } from 'src/modules/products/stores/productStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import {
  billingProfileRepository,
  type BillingProfile,
} from 'src/modules/sales_invoice/repositories/billingProfileRepository';
import { useBillingProfilesQuery } from 'src/modules/sales_invoice/composables/useBillingProfileQuery';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { useProductBasedCostingFileDetailQuery } from '../composables/useProductBasedCostingFileDetailQuery';
import { useProductBasedCostingItemsQuery } from '../composables/useProductBasedCostingItemsQuery';
import { useUpdateProductBasedCostingFileMutation } from '../composables/useProductBasedCostingFileMutations';
import {
  useDeleteProductBasedCostingItemMutation,
  useDeleteProductBasedCostingItemsBulkMutation,
  useUpdateProductBasedCostingItemMutation,
  useUpdateProductBasedCostingItemsByFileIdMutation,
  useRecalculateOfferPricesMutation,
} from '../composables/useProductBasedCostingItemMutations';
import type { ProductBasedCostingItem } from '../types';
import { toNumberSafe } from '../utils/pricing';
import { buildCostingExcelWorkbook } from '../utils/buildCostingExcelWorkbook';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';
import { usePbcBacklog } from '../composables/usePbcBacklog';

const productStore = useProductStore();
const tenantStore = useTenantStore();
const queryClient = useQueryClient();
const backlog = usePbcBacklog();
const showBacklogDrawer = ref(false);
const showFileDialog = ref(false);
const isEditingName = ref(false);
const editingNameValue = ref('');
const savingName = ref(false);
const nameInputRef = ref<HTMLInputElement | { focus: () => void; select: () => void } | null>(null);

const selectedBillingProfile = ref<BillingProfile | null>(null);
const savingBillingProfile = ref(false);
const $q = useQuasar();

const route = useRoute();
const router = useRouter();

const fileId = computed(() => {
  const parsed = Number(route.params.id);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
});

// Queries
const {
  data: file,
  isLoading: isLoadingFile,
} = useProductBasedCostingFileDetailQuery(fileId);

const {
  data: costingItemsData,
  isLoading: isLoadingItems,
} = useProductBasedCostingItemsQuery(fileId);

const isLoading = computed(() => isLoadingFile.value || isLoadingItems.value);
const costingItems = computed(() => costingItemsData.value ?? []);

// Mutations
const updateFileMutation = useUpdateProductBasedCostingFileMutation();
const updateItemMutation = useUpdateProductBasedCostingItemMutation();
const deleteItemMutation = useDeleteProductBasedCostingItemMutation();
const deleteItemsBulkMutation = useDeleteProductBasedCostingItemsBulkMutation();
const updateItemsByFileIdMutation = useUpdateProductBasedCostingItemsByFileIdMutation();
const recalculateOfferPricesMutation = useRecalculateOfferPricesMutation();

const editFormData = computed(() => {
  if (!file.value) return null;
  return {
    id: file.value.id,
    name: file.value.name ?? '',
    order_for: file.value.order_for ?? '',
    billing_profile_id: file.value.billing_profile_id ?? null,
    note: file.value.note ?? '',
    vendor_code: file.value.vendor_code ?? null,
    market_code: file.value.market_code ?? null,
  };
});

function openEditFileDialog() {
  showFileDialog.value = true;
}

function startInlineNameEdit() {
  editingNameValue.value = file.value?.name ?? '';
  isEditingName.value = true;
  void nextTick(() => {
    if (nameInputRef.value && 'focus' in nameInputRef.value) {
      nameInputRef.value.focus();
    }
  });
}

function cancelInlineName() {
  isEditingName.value = false;
  editingNameValue.value = '';
}

async function saveInlineName() {
  if (!isEditingName.value || savingName.value) return;

  const trimmed = editingNameValue.value.trim();
  const currentName = file.value?.name ?? '';

  if (!trimmed || trimmed === currentName) {
    cancelInlineName();
    return;
  }

  if (!fileId.value) {
    cancelInlineName();
    return;
  }

  savingName.value = true;
  try {
    await updateFileMutation.mutateAsync({
      id: fileId.value,
      name: trimmed,
    });
    isEditingName.value = false;
  } finally {
    savingName.value = false;
  }
}

const tenantIdRef = computed(() => tenantStore.selectedTenant?.id);
const { data: billingProfilesResult, isLoading: loadingProfiles } = useBillingProfilesQuery(tenantIdRef);

const allBillingProfiles = computed(() => billingProfilesResult.value?.data ?? []);
const billingProfileOptions = ref<BillingProfile[]>([]);

watch(
  allBillingProfiles,
  (profiles) => {
    billingProfileOptions.value = profiles;
    syncSelectedBillingProfile();
  },
  { immediate: true },
);

function syncSelectedBillingProfile() {
  if (file.value?.billing_profile_id) {
    const found = allBillingProfiles.value.find((p) => p.id === file.value?.billing_profile_id);
    if (found) {
      selectedBillingProfile.value = found;
      return;
    }
  }
  selectedBillingProfile.value = null;
}

function filterBillingProfiles(val: string, update: (fn: () => void) => void) {
  update(() => {
    if (!val.trim()) {
      billingProfileOptions.value = allBillingProfiles.value;
    } else {
      const needle = val.toLowerCase();
      billingProfileOptions.value = allBillingProfiles.value.filter(
        (p) =>
          p.name.toLowerCase().includes(needle) ||
          (p.email && p.email.toLowerCase().includes(needle)),
      );
    }
  });
}

async function onInlineBillingProfileChange(val: BillingProfile | null) {
  if (!fileId.value || savingBillingProfile.value) return;

  const newProfileId = val?.id ?? null;
  const newOrderFor = val?.name ?? file.value?.order_for ?? '';

  if (
    newProfileId === file.value?.billing_profile_id &&
    newOrderFor === file.value?.order_for
  ) {
    return;
  }

  savingBillingProfile.value = true;
  try {
    await updateFileMutation.mutateAsync({
      id: fileId.value,
      billing_profile_id: newProfileId,
      order_for: newOrderFor,
    });
    syncSelectedBillingProfile();
    refreshBacklog();
  } finally {
    savingBillingProfile.value = false;
  }
}

async function handleUpdateFileDialog(payload: {
  id: number | null;
  name: string;
  order_for: string;
  billing_profile_id: number | null;
  note: string;
  vendor_code: string | null;
  market_code: string | null;
}) {
  if (!payload.id) return;
  await updateFileMutation.mutateAsync({
    id: payload.id,
    name: payload.name,
    order_for: payload.order_for,
    billing_profile_id: payload.billing_profile_id,
    note: payload.note,
    vendor_code: payload.vendor_code,
    market_code: payload.market_code,
  });
  showFileDialog.value = false;
  refreshBacklog();
}

const cargo_rate_kg_gbp = ref<number | null>(null);
const conversion_rate = ref<number | null>(null);
const profit_rate = ref<number | null>(null);
const ratesExpanded = ref(false);
const status = ref<string>('pending');
const updatingStatus = ref(false);
const targetUpdatingStatus = ref<string | null>(null);
const shippedItemIds = ref<number[]>([]);

watch(
  file,
  (newFile) => {
    if (newFile) {
      cargo_rate_kg_gbp.value = newFile.cargo_rate_kg_gbp ?? null;
      conversion_rate.value = newFile.conversion_rate ?? null;
      profit_rate.value = newFile.profit_rate ?? null;
      status.value = newFile.status || 'pending';
      syncSelectedBillingProfile();
    }
  },
  { immediate: true },
);

const alwaysVisibleColumns = ['select', 'sl', 'image', 'name'];
const allColumnNames = [
  'select',
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'qty',
  'confirmedQty',
  'orderedQty',
  'deliveredQty',
  'barcodeText',
  'website',
  'priceGbp',
  'totalPurchasePriceGbp',
  'productWeight',
  'packageWeight',
  'totalWeight',
  'cargoRate',
  'cargoCostGbp',
  'totalCostGbp',
  'rowTotalCostGbp',
  'costBdt',
  'totalCostBdt',
  'offerPriceBdt',
  'totalBdt',
  'profitPerUnitBdt',
  'profitBdt',
  'profitRate',
  'status',
  'action',
];
const { visibleColumns } = useMembershipColumnPreference({
  preferenceKey: 'ui.productBasedCosting.fileDetailsVisibleColumns',
  allColumnNames,
  alwaysVisibleColumns,
  defaultVisibleColumns: allColumnNames,
});
const columnSelectorOptions = [
  { label: 'Brand', value: 'brand' },
  { label: 'Note', value: 'note' },
  { label: 'Qty', value: 'qty' },
  { label: 'Confirmed Qty', value: 'confirmedQty' },
  { label: 'Ordered Qty', value: 'orderedQty' },
  { label: 'Delivered Qty', value: 'deliveredQty' },
  { label: 'Barcode / Code / Product ID', value: 'barcodeText' },
  { label: 'Website', value: 'website' },
  { label: 'Price (GBP)/Unit', value: 'priceGbp' },
  { label: 'Total Purchase Price (GBP)', value: 'totalPurchasePriceGbp' },
  { label: 'Product Wt (g/Unit)', value: 'productWeight' },
  { label: 'Package Wt (g/Unit)', value: 'packageWeight' },
  { label: 'Total Wt (g/Unit)', value: 'totalWeight' },
  { label: 'Cargo Rate', value: 'cargoRate' },
  { label: 'Cargo Cost (GBP/Unit)', value: 'cargoCostGbp' },
  { label: 'Total Cost (GBP/Unit)', value: 'totalCostGbp' },
  { label: 'Row Total Cost (GBP)', value: 'rowTotalCostGbp' },
  { label: 'Cost (BDT/Unit)', value: 'costBdt' },
  { label: 'Row Total Cost (BDT)', value: 'totalCostBdt' },
  { label: 'Offer Price (BDT/Unit)', value: 'offerPriceBdt' },
  { label: 'Row Offer Total (BDT)', value: 'totalBdt' },
  { label: 'Profit (BDT/Unit)', value: 'profitPerUnitBdt' },
  { label: 'Row Total Profit (BDT)', value: 'profitBdt' },
  { label: 'Profit Rate (%)', value: 'profitRate' },
  { label: 'Status', value: 'status' },
  { label: 'Action', value: 'action' },
];
const selectableColumnValues = columnSelectorOptions.map((option) => option.value);
const allSelectableColumnsSelected = computed({
  get: () => selectableColumnValues.every((value) => visibleColumns.value.includes(value)),
  set: (checked: boolean) => {
    visibleColumns.value = checked
      ? [...alwaysVisibleColumns, ...selectableColumnValues]
      : [...alwaysVisibleColumns];
  },
});
const onVisibleColumnsUpdate = (columns: string[]) => {
  visibleColumns.value = columns;
};
const cargoRateValue = computed(() => cargo_rate_kg_gbp.value ?? 0);
const conversionRateValue = computed(() => conversion_rate.value ?? 140);
const profitRateValue = computed(() => profit_rate.value ?? 25);
const ratesSummary = computed(
  () =>
    `Conv ${conversionRateValue.value} · Cargo ${cargoRateValue.value} · Profit ${profitRateValue.value}%`,
);

const formatMoney = (val: number) =>
  val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const summaryMetrics = computed(() => {
  const items = costingItems.value;
  let totalQuantity = 0;
  let goodsCostGbp = 0;
  let cargoWeightGrams = 0;
  let cargoCostGbp = 0;

  for (const item of items) {
    const qty = toNumberSafe(item.quantity);
    const priceGbp = toNumberSafe(item.price_gbp);
    const prodWt = toNumberSafe(item.product_weight);
    const pkgWt = toNumberSafe(item.package_weight);
    const totalWtPerUnit = prodWt + pkgWt;

    totalQuantity += qty;
    goodsCostGbp += priceGbp * qty;
    cargoWeightGrams += totalWtPerUnit * qty;
    cargoCostGbp += ((totalWtPerUnit / 1000) * cargoRateValue.value) * qty;
  }

  const cargoWeightKg = cargoWeightGrams / 1000;
  const rate = conversionRateValue.value;
  const goodsCostBdt = goodsCostGbp * rate;
  const cargoCostBdt = cargoCostGbp * rate;
  const totalCostBdt = goodsCostBdt + cargoCostBdt;

  return {
    totalQuantity,
    goodsCostGbp,
    goodsCostBdt,
    cargoWeightKg,
    cargoCostGbp,
    cargoCostBdt,
    totalCostBdt,
  };
});

const onStatusChange = async () => {
  if (!fileId.value) {
    return;
  }

  await updateFileMutation.mutateAsync({
    id: fileId.value,
    status: status.value,
  });

  visibleColumns.value = getDefaultVisibleColumnsForStatus(status.value);

  if (status.value === 'confirmed' && costingItems.value.length > 0) {
    await updateItemsByFileIdMutation.mutateAsync({
      fileId: fileId.value,
      payload: {
        confirmed_quantity: 0,
        status: 'rejected',
      },
    });
  }

  if (status.value === 'offered') {
    await recalculateAndPersistOfferPrices();
  }
};

const workflowStatuses = [
  'pending',
  'offered',
  'confirmed',
  'placing_order',
  'ready_for_shipment',
  'invoicing',
  'delivered',
] as const;

const formatStatusLabel = (value: string) =>
  value.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());

const isPassedStatus = (st: string) => {
  if (status.value === 'cancelled') {
    return false;
  }
  const currentIdx = workflowStatuses.indexOf(status.value as (typeof workflowStatuses)[number]);
  const targetIdx = workflowStatuses.indexOf(st as (typeof workflowStatuses)[number]);
  return currentIdx > -1 && targetIdx > -1 && targetIdx < currentIdx;
};

const getDefaultVisibleColumnsForStatus = (fileStatus: string): string[] => {
  const baseCols = ['select', 'sl', 'image', 'name'];
  switch (fileStatus) {
    case 'confirmed':
      return [...baseCols, 'qty', 'confirmedQty', 'status', 'action'];
    case 'placing_order':
      return [...baseCols, 'confirmedQty', 'orderedQty', 'barcodeText', 'status', 'action'];
    case 'invoicing':
      return [
        ...baseCols,
        'confirmedQty',
        'orderedQty',
        'deliveredQty',
        'barcodeText',
        'priceGbp',
        'costBdt',
        'status',
        'action',
      ];
    case 'delivered':
      return [...allColumnNames];
    default:
      return [...allColumnNames];
  }
};

const getStatusColor = (st: string) => {
  switch (st) {
    case 'pending':
      return 'orange-8';
    case 'offered':
      return 'blue-8';
    case 'confirmed':
      return 'blue-9';
    case 'placing_order':
      return 'indigo-8';
    case 'ready_for_shipment':
      return 'green-8';
    case 'invoicing':
      return 'purple-8';
    case 'delivered':
      return 'teal-9';
    case 'cancelled':
      return 'negative';
    default:
      return 'primary';
  }
};

const onUpdateStatus = async (nextStatus: string) => {
  if (status.value === nextStatus || updatingStatus.value) {
    return;
  }
  updatingStatus.value = true;
  targetUpdatingStatus.value = nextStatus;
  try {
    status.value = nextStatus;
    await onStatusChange();
  } finally {
    updatingStatus.value = false;
    targetUpdatingStatus.value = null;
  }
};

const recalculateAndPersistOfferPrices = async () => {
  if (!fileId.value) {
    return;
  }

  await recalculateOfferPricesMutation.mutateAsync(fileId.value);
};

const refreshBacklog = () => {
  const tenantId = tenantStore.selectedTenant?.id;
  const profileId = file.value?.billing_profile_id;
  if (tenantId && profileId) {
    void backlog.fetchBacklogItems(tenantId, profileId);
  }
};

const openBacklogDrawer = () => {
  refreshBacklog();
  showBacklogDrawer.value = true;
};

const handleConsumeBacklog = async (backlogIds: number[]) => {
  if (!fileId.value) return;
  const addedIds = await backlog.consumeBacklogItems(fileId.value, backlogIds);
  if (addedIds.length > 0) {
    void queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
    });
    refreshBacklog();
    showBacklogDrawer.value = false;
  }
};

const handleCreated = async () => {
  if (!fileId.value) {
    return;
  }

  void queryClient.invalidateQueries({
    queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
  });
  refreshBacklog();
};

const onEdit = (item: ProductBasedCostingItem) => {
  console.log('edit', item);
  openEditDialog(item);
};

const onDelete = async (item: ProductBasedCostingItem) => {
  console.log('delete', item);
  await deleteItemMutation.mutateAsync(item.id);
};

const onBulkDelete = async (ids: number[]) => {
  if (!ids.length || !fileId.value) {
    return;
  }

  await deleteItemsBulkMutation.mutateAsync({
    fileId: fileId.value,
    ids,
  });
  refreshBacklog();
};

type RowChangePayload = {
  item: ProductBasedCostingItem;
  row: unknown;
  field:
    | 'quantity'
    | 'offer_price'
    | 'status'
    | 'note'
    | 'delivered_quantity'
    | 'confirmed_quantity'
    | 'ordered_quantity'
    | 'product_weight'
    | 'package_weight';
};

type WeightChangePayload = {
  item: ProductBasedCostingItem;
  row: unknown;
  field: 'product_weight' | 'package_weight';
};

const onRowChange = async (payload: RowChangePayload) => {
  await updateItemMutation.mutateAsync(payload.item);
  console.log('Row changed:', payload);
};

const showItemDialog = ref(false);
const selectedItem = ref<ProductBasedCostingItem | null>(null);

const openCreateDialog = () => {
  console.log('Opening create dialog');
  selectedItem.value = null;
  showItemDialog.value = true;
};

const openCatalogDialog = () => {
  if (!fileId.value) return;

  $q.dialog({
    component: AddCostingItemsDrawer,
    componentProps: { fileId: fileId.value },
  }).onOk(() => {
    void queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
    });
    refreshBacklog();
  });
};

const openBulkPaste = () => {
  if (!costingItems.value.length) {
    $q.notify({ type: 'warning', message: 'No costing items to update.' });
    return;
  }

  $q.dialog({
    component: BulkPasteCostingItemsDialog,
  });
};

const openPreviewAndPrint = () => {
  if (!fileId.value) {
    return;
  }

  $q.dialog({
    component: ProductBasedCostingPreviewColumnSelectorDialog,
  }).onOk((res: { visibleColumns?: string[] }) => {
    if (!fileId.value) {
      return;
    }
    const cols = res?.visibleColumns ?? [];
    const previewRoute = router.resolve({
      name: 'product-based-costing-file-preview-page',
      params: { id: fileId.value },
      ...(cols.length ? { query: { cols: cols.join(',') } } : {}),
    });

    window.open(previewRoute.href, '_blank', 'noopener');
  });
};

const safeNamePart = (value: string) =>
  value.replace(/[^a-z0-9-_]+/gi, '_').replace(/^_+|_+$/g, '');

const downloadExcel = async () => {
  if (!file.value) {
    $q.notify({ type: 'warning', message: 'No costing file selected.' });
    return;
  }

  const loading = $q.loading.show({ message: 'Generating Excel...' });

  try {
    const workbook = await buildCostingExcelWorkbook({
      file: file.value,
      items: costingItems.value,
    });

    const buffer = await workbook.xlsx.writeBuffer();
    const blob = new Blob([buffer], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    const fileTitle = safeNamePart(file.value.name ?? `costing_file_${file.value.id}`);
    anchor.href = url;
    anchor.download = `${fileTitle || `costing_file_${file.value.id}`}.xlsx`;
    anchor.click();
    URL.revokeObjectURL(url);
  } catch (error) {
    $q.notify({
      type: 'negative',
      message: error instanceof Error ? error.message : 'Failed to generate Excel.',
    });
  } finally {
    loading();
  }
};

const openEditDialog = (item: ProductBasedCostingItem) => {
  selectedItem.value = item;
  showItemDialog.value = true;
};

const handleUpdated = () => {
  return;
};

const onRateSave = async () => {
  if (!file.value || !fileId.value) {
    return;
  }

  console.log('Saving rates:', {
    conversion_rate: conversion_rate.value,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value,
    profit_rate: profit_rate.value,
  });
  const payload = {
    id: file.value.id,
    conversion_rate: conversion_rate.value || 0,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value || 0,
    profit_rate: profit_rate.value || 0,
  };

  await updateFileMutation.mutateAsync(payload);
  await recalculateAndPersistOfferPrices();
  ratesExpanded.value = false;
};

const onProductWeightChange = async (payload: WeightChangePayload) => {
  console.log('Product weight changed:', payload.item.product_id);
  if (payload.item.product_id) {
    await productStore.updateProduct({
      id: payload.item.product_id,
      product_weight: payload.item.product_weight,
    });
  }
  await updateItemMutation.mutateAsync({
    id: payload.item.id,
    product_weight: payload.item.product_weight,
    offer_price: payload.item.offer_price,
  });
};

const onPackageWeightChange = async (payload: WeightChangePayload) => {
  console.log('Package weight changed:', payload);
  if (payload.item.product_id) {
    await productStore.updateProduct({
      id: payload.item.product_id,
      package_weight: payload.item.package_weight,
    });
  }
  await updateItemMutation.mutateAsync({
    id: payload.item.id,
    package_weight: payload.item.package_weight,
    offer_price: payload.item.offer_price,
  });
};

const goBack = () => {
  void router.push({ name: 'product-based-costing-page' });
};
</script>

<style scoped lang="scss">
.costing-details-page {
  background: transparent;
}

.costing-items-surface {
  overflow: hidden;
}

.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}

.status-workflow-row {
  flex-wrap: wrap;
  row-gap: 8px;
}

.status-workflow-sep {
  align-self: stretch;
  min-height: 24px;
}

.rates-summary {
  white-space: nowrap;
}

.metric-card {
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
  border-radius: 10px;

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(15, 23, 42, 0.05);
  }
}

.metric-icon-badge {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.bg-surface-subtle {
  background: var(--bw-theme-surface-subtle, rgba(248, 250, 252, 0.7));
}

.bg-primary-subtle {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.1);
}

.bg-teal-subtle {
  background: rgba(13, 148, 136, 0.1);
}

.total-landed-cost-card {
  border-radius: 10px;
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.04);
  border-color: rgba(var(--q-primary-rgb, 15, 98, 254), 0.15);
}

@media (max-width: 599px) {
  .status-workflow-chevron,
  .status-workflow-sep {
    display: none;
  }

  .rates-summary {
    white-space: normal;
  }
}

.name-inline-edit {
  border-bottom: 1px dashed transparent;
  transition: all 0.2s ease;
  border-radius: 4px;
  padding: 2px 4px;
}

.name-inline-edit:hover {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.06);
  border-bottom-color: var(--q-primary);
}

.profile-picker-chip {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.08);
  padding: 2px 10px;
  border-radius: 12px;
  transition: all 0.2s ease;
  border: 1px solid rgba(var(--q-primary-rgb, 15, 98, 254), 0.2);
}

.profile-picker-chip:hover {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.15);
  border-color: var(--q-primary);
}
</style>
