<template>
  <q-page class="q-pa-md shipment-details-page">
    <div class="q-gutter-y-sm">
      <!-- Loading / Error States -->
      <div
        v-if="shipmentStore.loading && !shipmentStore.currentShipment"
        class="text-center q-pa-xl"
      >
        <q-spinner color="primary" size="3em" />
        <div class="text-grey-6 q-mt-md">Loading shipment details...</div>
      </div>

      <div v-else-if="shipmentStore.error && !shipmentStore.currentShipment" class="q-pa-md">
        <q-banner class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
          <template #action>
            <q-btn flat color="white" label="Go Back" @click="goBack" />
          </template>
        </q-banner>
      </div>

      <template v-else-if="shipmentStore.currentShipment">
        <!-- Error banner for actions -->
        <q-banner v-if="shipmentStore.error" class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
        </q-banner>

        <!-- Compact header + status -->
        <ShipmentHeaderBar
          :shipment="shipmentStore.currentShipment"
          :is-editable="isEditable"
          :type-options="typeOptions"
          :vendor-options="vendorOptions"
          :current-vendor-label="currentVendorLabel"
          :loading-vendors="loadingVendors"
          :cargo-options="cargoOptions"
          :current-cargo-label="currentCargoLabel"
          :loading-cargo="loadingCargo"
          @go-back="goBack"
          @update-name="saveInlineName"
          @update-type="saveInlineType"
          @update-vendor="saveInlineVendor"
          @update-cargo="saveInlineCargo"
          @ensure-vendors="ensureVendorsLoaded"
          @ensure-cargo="ensureCargoLoaded"
          @download-excel="downloadExcel"
          @delete-shipment="confirmDeleteShipment"
        />

        <ShipmentStatusWorkflowBar
          :status="shipmentStore.currentShipment.status"
          :updating="updatingStatus"
          :target-status="targetUpdatingStatus"
          :lock-received="!isSplitsComplete"
          :progress-options="shipmentStore.progressTags"
          :progress-tag-id="shipmentStore.currentShipment.progress_tag_id ?? shipmentStore.currentShipment.progress_tag?.id ?? null"
          :progress-updating="shipmentStore.progressUpdating"
          :progress-target-id="progressTargetId"
          :show-next="!!nextStep"
          @update-status="changeStatus"
          @update-progress="changeProgress"
        >
          <template #next>
            <div
              v-if="nextStep"
              class="row items-center justify-between q-gutter-xs wrap full-width"
            >
              <div class="col row items-center q-gutter-xs no-wrap min-width-0">
                <q-icon name="ph ph-arrow-right" color="primary" size="16px" class="shipment-id-prefix" />
                <div class="min-width-0">
                  <div class="text-caption text-weight-medium text-grey-9">{{ nextStep.message }}</div>
                  <div
                    v-if="nextStep.disabled && nextStep.reason"
                    class="text-caption text-grey-7"
                  >
                    {{ nextStep.reason }}
                  </div>
                </div>
              </div>
              <div class="col-auto row items-center q-gutter-xs wrap">
                <q-chip
                  v-if="weightNeedsAttention"
                  dense
                  square
                  size="sm"
                  color="orange-1"
                  text-color="orange-9"
                  label="Weight off"
                />
                <q-chip
                  v-if="purchaseNeedsAttention"
                  dense
                  square
                  size="sm"
                  color="orange-1"
                  text-color="orange-9"
                  label="Purchase off"
                />
                <q-chip
                  v-if="receiveNeedsAttention"
                  dense
                  square
                  size="sm"
                  color="orange-1"
                  text-color="orange-9"
                  label="Splits pending"
                />
                <q-btn
                  v-if="nextStep.label"
                  color="primary"
                  unelevated
                  dense
                  no-caps
                  size="sm"
                  class="q-px-sm"
                  :label="nextStep.label"
                  :disable="nextStep.disabled"
                  @click="runPrimaryCta"
                >
                  <q-tooltip v-if="nextStep.disabled && nextStep.reason">{{
                    nextStep.reason
                  }}</q-tooltip>
                </q-btn>
              </div>
            </div>
          </template>
        </ShipmentStatusWorkflowBar>

        <!-- Received-shipment ops: assign, settle, return -->
        <div
          v-if="shipmentStore.currentShipment.status === 'received'"
          class="column q-gutter-y-md"
        >
          <div ref="assignShopCard">
            <ShipmentAssignShopCard
              v-model="selectedChildTenantId"
              :child-tenant-options="childTenantOptions"
              :child-tenants-loading="childTenantsLoading"
              :assigning-child="assigningChild"
              :assigned-child-tenant-id="shipmentStore.currentShipment.assigned_child_tenant_id"
              @save="saveAssignChild"
              @clear="clearAssignChild"
            />
          </div>

          <div ref="paySettleCard">
            <ShipmentPayCard
              :settleable-entries="settleableEntries"
              :settle-entry-columns="settleEntryColumns"
              :pay-settling="paySettling"
              @pay-all="confirmPaySettleAll"
            />
          </div>

          <ShipmentVendorReturnCard
            v-model:return-outcome="returnOutcome"
            :return-outcome-options="returnOutcomeOptions"
            :return-lines="returnLines"
            :return-line-columns="returnLineColumns"
            :has-return-qty="hasReturnQty"
            :return-submitting="returnSubmitting"
            @submit-return="confirmVendorReturn"
          />
        </div>

        <!-- Tabs + contextual actions on one row -->
        <div>
          <div class="row items-center justify-between no-wrap q-gutter-sm">
            <q-tabs
              v-model="activeTab"
              dense
              align="left"
              active-color="primary"
              indicator-color="primary"
              class="text-grey-8 col-grow"
              no-caps
              narrow-indicator
            >
              <q-tab name="lines" data-test="tab-lines">
                <div class="row items-center no-wrap q-gutter-xs">
                  <span>Items</span>
                  <q-badge v-if="!hasLineItems" color="orange" rounded label="!" />
                </div>
              </q-tab>
              <q-tab name="cost" label="Payment and rates" data-test="tab-cost" />
              <q-tab name="balance" data-test="tab-balance">
                <div class="row items-center no-wrap q-gutter-xs">
                  <span>Match invoices</span>
                  <q-badge v-if="balanceNeedsAttention" color="orange" rounded label="!" />
                </div>
              </q-tab>
              <q-tab v-if="showReceiveTab" name="receive" data-test="tab-receive">
                <div class="row items-center no-wrap q-gutter-xs">
                  <span>Add to stock</span>
                  <q-badge v-if="receiveNeedsAttention" color="orange" rounded label="!" />
                </div>
              </q-tab>
            </q-tabs>

            <div v-if="activeTab === 'lines'" class="col-auto row items-center q-gutter-xs">
              <q-btn-toggle
                v-model="lineItemsViewMode"
                flat
                dense
                no-caps
                size="sm"
                toggle-color="primary"
                color="grey-3"
                text-color="grey-8"
                :options="[
                  { value: 'table', icon: 'ph ph-table' },
                  { value: 'cards', icon: 'ph ph-rows' }
                ]"
                class="q-mr-xs border-grey"
              >
                <template v-slot:table>
                  <q-tooltip>Table View</q-tooltip>
                </template>
                <template v-slot:cards>
                  <q-tooltip>Card List View</q-tooltip>
                </template>
              </q-btn-toggle>
              <q-btn
                color="primary"
                outline
                no-caps
                size="sm"
                icon="ph ph-columns"
                dense
                label="Columns"
                class="q-px-sm"
              >
                <q-menu>
                  <q-list style="min-width: 220px" class="q-py-xs">
                    <q-item>
                      <q-item-section>
                        <div class="text-subtitle2 text-weight-bold text-primary">Show Columns</div>
                      </q-item-section>
                    </q-item>
                    <q-item clickable>
                      <q-item-section>
                        <q-checkbox v-model="allColumnsSelected" label="Select / Deselect All" />
                      </q-item-section>
                    </q-item>
                    <q-separator />
                    <q-item v-for="col in availableColumnOptions" :key="col.value" clickable>
                      <q-item-section>
                        <q-checkbox
                          v-model="visibleColumns"
                          :val="col.value"
                          :label="col.label"
                        />
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
              <q-btn
                v-if="
                  shipmentStore.currentShipment?.status === 'in_transit' && !isSplitsComplete
                "
                color="green-7"
                icon="ph ph-git-fork"
                label="Auto Accept"
                unelevated
                dense
                no-caps
                size="sm"
                :loading="shipmentStore.loading"
                @click="autoAcceptSplits"
              />
              <q-btn
                v-if="isEditable"
                color="secondary"
                icon="ph ph-clipboard"
                label="Paste"
                unelevated
                dense
                no-caps
                size="sm"
                @click="openBulkPaste"
              />
              <q-btn
                v-if="isEditable"
                color="primary"
                icon="ph ph-plus"
                label="Add"
                unelevated
                dense
                no-caps
                size="sm"
                @click="openAddItems"
              />
            </div>
          </div>
          <q-separator />

          <q-tab-panels v-model="activeTab" class="bg-transparent q-pt-sm">
            <!-- Items -->
            <q-tab-panel name="lines" class="q-pa-none">
              <q-card flat bordered class="q-pa-none line-items-card">
                <div
                  v-if="!hasLineItems && !shipmentStore.loading"
                  class="column items-center q-pa-lg text-center"
                >
                  <q-icon name="ph ph-package" size="40px" color="grey-5" />
                  <div class="text-body2 text-grey-7 q-mt-sm q-mb-md">No products yet</div>
                  <q-btn
                    v-if="isEditable"
                    color="primary"
                    unelevated
                    no-caps
                    dense
                    size="sm"
                    icon="ph ph-plus"
                    label="Add items"
                    @click="openAddItems"
                  />
                </div>
                <template v-else>
                  <ShipmentLineItemsTable
                    v-if="lineItemsViewMode === 'table'"
                    :items="shipmentStore.currentShipmentItems"
                    :shipment="shipmentForLiveCosting"
                    :loading="shipmentStore.loading"
                    :visible-columns="visibleColumns"
                    :purchase-currency-symbol="currentPurchaseCurrencySymbol"
                    :cost-currency-symbol="currentCostCurrencySymbol"
                    @edit-details="openEditItem"
                    @delete="confirmDeleteItem"
                  />
                  <ShipmentItemCardGrid
                    v-else
                    :items="shipmentStore.currentShipmentItems"
                    :shipment="shipmentForLiveCosting"
                    :loading="shipmentStore.loading"
                    :purchase-currency-symbol="currentPurchaseCurrencySymbol"
                    :cost-currency-symbol="currentCostCurrencySymbol"
                    @edit-details="openEditItem"
                    @delete="confirmDeleteItem"
                  />
                </template>
              </q-card>
            </q-tab-panel>

            <!-- Payment and rates -->
            <q-tab-panel name="cost" class="q-pa-none">
              <div class="column q-gutter-y-md">
                <q-banner
                  v-if="weightNeedsAttention || purchaseNeedsAttention"
                  dense
                  rounded
                  class="bg-orange-1 text-orange-10"
                >
                  <div class="row items-center justify-between q-gutter-sm">
                    <span>Lines don’t match invoices — open Match invoices to reconcile.</span>
                    <q-btn
                      flat
                      dense
                      no-caps
                      color="orange-10"
                      label="Open Match invoices"
                      @click="activeTab = 'balance'"
                    />
                  </div>
                </q-banner>
                <ShipmentCostEntriesPanel
                  :entries="shipmentStore.currentCostEntries"
                  :loading="shipmentStore.costEntriesLoading"
                  :saving="shipmentStore.costEntriesSaving"
                  :can-edit="canEditCosts"
                  :is-finalized="isCostFinalized"
                  :is-local-shipment="shipmentStore.currentShipment?.type === 'local'"
                  :cargo-kg="totals.cargoWeightKg"
                  :purchase-currency-symbol="currentPurchaseCurrencySymbol"
                  :cost-currency-symbol="currentCostCurrencySymbol"
                  @save="onSaveCostEntries"
                  @go-match-invoices="activeTab = 'balance'"
                />

                <ShipmentLandedCostSummaryCard
                  :totals="totals"
                  :has-cargo-invoice-weight="hasCargoInvoiceWeight"
                  :current-shipment-boxes-total="currentShipmentBoxesTotal"
                  :current-purchase-currency-symbol="currentPurchaseCurrencySymbol"
                  :current-cost-currency-symbol="currentCostCurrencySymbol"
                  :cargo-cost-weight-label="cargoCostWeightLabel"
                  :transaction-rate-weight-label="transactionRateWeightLabel"
                  :shipment-type="shipmentStore.currentShipment?.type"
                />
              </div>
            </q-tab-panel>

            <!-- Match invoices -->
            <q-tab-panel name="balance" class="q-pa-none">
              <div class="column q-gutter-y-md">
                <div>
                  <div class="text-body2 text-grey-8">
                    Compare cargo weight and paid purchase to your lines, then apply to fix lines.
                  </div>
                  <div class="row q-gutter-sm q-mt-sm">
                    <q-chip
                      clickable
                      dense
                      :color="weightNeedsAttention ? 'orange-1' : hasCargoInvoiceWeight ? 'green-1' : 'grey-2'"
                      :text-color="weightNeedsAttention ? 'orange-10' : hasCargoInvoiceWeight ? 'green-9' : 'grey-8'"
                      icon="ph ph-scales"
                      @click="scrollToBalanceCard('weight')"
                    >
                      Weight:
                      {{
                        !hasCargoInvoiceWeight
                          ? 'not set'
                          : weightNeedsAttention
                            ? 'needs fix'
                            : 'matched'
                      }}
                    </q-chip>
                    <q-chip
                      clickable
                      dense
                      :color="purchaseNeedsAttention ? 'orange-1' : hasProductInvoiceTotal ? 'green-1' : 'grey-2'"
                      :text-color="purchaseNeedsAttention ? 'orange-10' : hasProductInvoiceTotal ? 'green-9' : 'grey-8'"
                      icon="ph ph-money"
                      @click="scrollToBalanceCard('purchase')"
                    >
                      Purchase:
                      {{
                        !hasProductInvoiceTotal
                          ? 'not set'
                          : purchaseNeedsAttention
                            ? 'needs fix'
                            : 'matched'
                      }}
                    </q-chip>
                  </div>
                </div>
                <div ref="weightBalanceCardEl">
                  <ShipmentWeightBalanceCard
                    :shipment-id="shipmentId"
                    @applied="loadShipmentDetails"
                  />
                </div>
                <div ref="purchaseBalanceCardEl">
                  <ShipmentPurchaseBalanceCard
                    :shipment-id="shipmentId"
                    @applied="loadShipmentDetails"
                    @go-landed-cost="activeTab = 'cost'"
                  />
                </div>
              </div>
            </q-tab-panel>

            <!-- Add to stock -->
            <q-tab-panel v-if="showReceiveTab" name="receive" class="q-pa-none">
              <ShipmentReceiveTabPanel
                :shipment="shipmentStore.currentShipment"
                :has-line-items="hasLineItems"
                :current-shipment-items-count="shipmentStore.currentShipmentItems.length"
                :has-cargo-invoice-weight="hasCargoInvoiceWeight"
                :weight-needs-attention="weightNeedsAttention"
                :purchase-needs-attention="purchaseNeedsAttention"
                :has-product-cost-entry="hasProductInvoiceTotal"
                :is-splits-complete="isSplitsComplete"
                :splits-summary="splitsSummary"
                :updating-status="updatingStatus"
                @go-tab="(tab) => (activeTab = tab)"
                @change-status="changeStatus"
                @rollback="rollbackShipmentToDraft"
              />
            </q-tab-panel>
          </q-tab-panels>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

// Components
import ShipmentLineItemsTable from '../components/ShipmentLineItemsTable.vue';
import ShipmentItemCardGrid from '../components/ShipmentItemCardGrid.vue';
import ShipmentWeightBalanceCard from '../components/ShipmentWeightBalanceCard.vue';
import ShipmentPurchaseBalanceCard from '../components/ShipmentPurchaseBalanceCard.vue';
import ShipmentStatusWorkflowBar from '../components/ShipmentStatusWorkflowBar.vue';
import ShipmentCostEntriesPanel from '../components/ShipmentCostEntriesPanel.vue';
import ShipmentHeaderBar from '../components/ShipmentHeaderBar.vue';
import ShipmentAssignShopCard from '../components/ShipmentAssignShopCard.vue';
import ShipmentPayCard from '../components/ShipmentPayCard.vue';
import ShipmentVendorReturnCard from '../components/ShipmentVendorReturnCard.vue';
import ShipmentLandedCostSummaryCard from '../components/ShipmentLandedCostSummaryCard.vue';
import ShipmentReceiveTabPanel from '../components/ShipmentReceiveTabPanel.vue';

// Composables
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { useInboundShipmentActions } from '../composables/useInboundShipmentActions';

const route = useRoute();
const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const VIEW_MODE_STORAGE_KEY = 'inbound_shipment_line_items_view_mode';
const lineItemsViewMode = ref<'table' | 'cards'>('table');

onMounted(() => {
  const savedMode = localStorage.getItem(VIEW_MODE_STORAGE_KEY) as 'table' | 'cards' | null;
  if (savedMode && ['table', 'cards'].includes(savedMode)) {
    lineItemsViewMode.value = savedMode;
  }
});

const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('lines');
const weightBalanceCardEl = ref<HTMLElement | null>(null);
const purchaseBalanceCardEl = ref<HTMLElement | null>(null);
const assignShopCard = ref<HTMLElement | null>(null);
const paySettleCard = ref<HTMLElement | null>(null);

const scrollToBalanceCard = (which: 'weight' | 'purchase') => {
  const el = which === 'weight' ? weightBalanceCardEl.value : purchaseBalanceCardEl.value;
  el?.scrollIntoView({ behavior: 'smooth', block: 'start' });
};

// Initialize Composables
const calculations = useInboundShipmentCalculations();
const actions = useInboundShipmentActions({
  shipmentId,
  activeTab,
  calculations,
  assignShopCard,
  paySettleCard,
});

// Destructure for Template Access
const {
  totals,
  cargoCostWeightLabel,
  transactionRateWeightLabel,
  shipmentForLiveCosting,
  currentShipmentBoxesTotal,
  hasCargoInvoiceWeight,
  isEditable,
  isCostFinalized,
  canEditCosts,
  hasLineItems,
  weightNeedsAttention,
  purchaseNeedsAttention,
  hasProductInvoiceTotal,
  balanceNeedsAttention,
  showReceiveTab,
  receiveNeedsAttention,
  isSplitsComplete,
  splitsSummary,
  availableColumnOptions,
  visibleColumns,
  allColumnsSelected,
  currentPurchaseCurrencySymbol,
  currentCostCurrencySymbol,
} = calculations;

const {
  updatingStatus,
  targetUpdatingStatus,
  progressTargetId,
  typeOptions,
  vendorOptions,
  currentVendorLabel,
  loadingVendors,
  cargoOptions,
  currentCargoLabel,
  loadingCargo,
  ensureVendorsLoaded,
  ensureCargoLoaded,
  saveInlineName,
  saveInlineType,
  saveInlineVendor,
  saveInlineCargo,
  childTenantOptions,
  childTenantsLoading,
  selectedChildTenantId,
  assigningChild,
  paySettling,
  returnSubmitting,
  returnOutcome,
  returnOutcomeOptions,
  returnLines,
  settleEntryColumns,
  returnLineColumns,
  settleableEntries,
  hasReturnQty,
  saveAssignChild,
  clearAssignChild,
  confirmPaySettleAll,
  confirmVendorReturn,
  loadShipmentDetails,
  goBack,
  changeProgress,
  changeStatus,
  rollbackShipmentToDraft,
  confirmDeleteShipment,
  nextStep,
  runPrimaryCta,
  downloadExcel,
  openAddItems,
  openBulkPaste,
  autoAcceptSplits,
  openEditItem,
  confirmDeleteItem,
  onSaveCostEntries,
} = actions;

onMounted(() => {
  loadShipmentDetails();
  if (authStore.tenantId) {
    void shipmentStore.ensureProgressTags(authStore.tenantId);
  }
});
</script>

<style scoped>
.shipment-details-page .min-width-0 {
  min-width: 0;
}

.shipment-id-prefix {
  flex-shrink: 0;
}

.line-items-card {
  min-width: 0;
}
</style>
