<template>
  <q-page class="shipment-overview-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Scrollable Page Body -->
    <div class="col scroll q-pb-xl">
      <!-- Header Section: Name & Metadata Chips -->
      <div class="q-px-md q-pt-md">
      <div class="row items-center q-gutter-x-sm no-wrap">
        <q-btn
          flat
          round
          dense
          icon="ph ph-arrow-left"
          color="grey-8"
          size="md"
          aria-label="Go Back"
          @click="goBack"
        >
          <q-tooltip>Back to shipments</q-tooltip>
        </q-btn>

        <template v-if="editingName">
          <q-input
            ref="nameEditInputRef"
            v-model="shipmentName"
            dense
            outlined
            hide-bottom-space
            class="shipment-name-input text-h4 text-weight-bolder col-grow"
            style="max-width: 500px;"
            @keyup.enter="commitNameEdit"
            @keyup.escape="cancelNameEdit"
            @blur="commitNameEdit"
          />
        </template>
        <template v-else>
          <div
            class="text-h4 text-weight-bolder text-grey-9 cursor-pointer row items-center q-gutter-x-sm name-display"
            @click="startNameEdit"
          >
            <span>{{ shipmentName }}</span>
            <q-icon name="edit" size="20px" color="grey-6" class="edit-icon" />
          </div>
        </template>
      </div>

      <!-- Metadata Chips with Tap-to-Change Menus -->
      <div class="row items-center q-gutter-xs q-mt-xs">
        <!-- Type Chip -->
        <q-chip
          clickable
          :label="currentTypeLabel"
          icon-right="arrow_drop_down"
        >
          <q-menu auto-close>
            <q-list dense style="min-width: 140px">
              <q-item
                v-for="opt in typeOptions"
                :key="opt.value"
                clickable
                :active="shipmentStore.currentShipment?.type === opt.value"
                @click="saveInlineType(opt.value)"
              >
                <q-item-section class="text-capitalize">{{ opt.label }}</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-chip>

        <!-- Vendor Chip -->
        <q-chip
          clickable
          :label="currentVendorLabel"
          icon-right="arrow_drop_down"
        >
          <q-menu auto-close @before-show="ensureVendorsLoaded">
            <q-list dense style="min-width: 180px; max-height: 280px" class="scroll">
              <q-item v-if="loadingVendors" dense>
                <q-item-section class="text-grey-6">Loading vendors…</q-item-section>
              </q-item>
              <q-item
                v-for="opt in vendorOptions"
                :key="opt.value"
                clickable
                :active="shipmentStore.currentShipment?.vendor_id === opt.value"
                @click="saveInlineVendor(opt.value)"
              >
                <q-item-section>{{ opt.label }}</q-item-section>
              </q-item>
              <q-item v-if="!loadingVendors && !vendorOptions.length" dense>
                <q-item-section class="text-grey-6">No vendors</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-chip>

        <!-- Cargo Chip -->
        <q-chip
          clickable
          :label="currentCargoLabel"
          icon-right="arrow_drop_down"
        >
          <q-menu auto-close @before-show="ensureCargoLoaded">
            <q-list dense style="min-width: 180px; max-height: 280px" class="scroll">
              <q-item v-if="loadingCargo" dense>
                <q-item-section class="text-grey-6">Loading cargo…</q-item-section>
              </q-item>
              <q-item
                v-if="shipmentStore.currentShipment?.cargo_company_id"
                clickable
                @click="saveInlineCargo(null)"
              >
                <q-item-section class="text-grey-7">Clear</q-item-section>
              </q-item>
              <q-item
                v-for="opt in cargoOptions"
                :key="opt.value"
                clickable
                :active="shipmentStore.currentShipment?.cargo_company_id === opt.value"
                @click="saveInlineCargo(opt.value)"
              >
                <q-item-section>{{ opt.label }}</q-item-section>
              </q-item>
              <q-item v-if="!loadingCargo && !cargoOptions.length" dense>
                <q-item-section class="text-grey-6">No cargo options</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-chip>
      </div>
    </div>

    <!-- Status Workflow Section -->
    <div class="q-px-md q-pt-md">
      <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs" style="letter-spacing: 0.5px">
        Shipment Status & Lifecycle
      </div>
      <ShipmentStatusWorkflowBar
        :status="shipmentStore.currentShipment?.status || dummyStatus"
        :updating="updatingStatus"
        :target-status="targetUpdatingStatus"
        :progress-flow-id="null"
        :progress-tag-id="null"
        :flow-options="[]"
        :progress-options="[]"
        @update-status="changeStatus"
      />
    </div>

    <!-- Progress Tracker Section -->
    <div class="q-px-md q-pt-md">
      <div class="row items-center justify-between q-mb-xs">
        <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
          Shipment Progress
        </div>
        <div class="row items-center q-gutter-x-xs">
          <template v-if="progressFlowOptions.length">
            <span class="text-caption text-grey-6" style="font-size: 11px">Flow:</span>
            <q-select
              :model-value="currentProgressFlowId"
              :options="flowSelectOptions"
              dense
              outlined
              emit-value
              map-options
              options-dense
              hide-bottom-space
              class="progress-flow-select"
              :disable="shipmentStore.progressUpdating"
              @update:model-value="changeFlow"
            />
          </template>

          <q-btn
            flat
            dense
            no-caps
            size="xs"
            color="primary"
            icon="ph ph-sliders"
            label="Manage Flows"
            class="q-px-xs"
            @click="goToFlowSettings"
          >
            <q-tooltip>Configure progress flows and stages</q-tooltip>
          </q-btn>
        </div>
      </div>

      <q-card flat bordered class="bg-white q-pa-md summary-kpi-card">
        <div v-if="!activeFlowStages.length" class="text-caption text-grey-6 text-center q-pa-sm">
          No progress stages defined for this flow.
        </div>
        <template v-else>
          <div class="row items-center justify-between q-mb-sm">
            <div class="row items-center q-gutter-x-sm">
              <q-badge
                :color="currentActiveStage?.color || 'primary'"
                rounded
                class="q-px-sm text-capitalize"
              >
                {{ currentActiveStage?.name || 'Not Started' }}
              </q-badge>
              <span class="text-caption text-grey-7">
                Flow: <strong>{{ currentFlowName }}</strong>
              </span>
            </div>
            <div class="text-caption text-grey-6">
              {{ currentStageIndex >= 0 ? `Stage ${currentStageIndex + 1} of ${activeFlowStages.length}` : 'Pending' }}
              ({{ Math.round(progressPercent * 100) }}%)
            </div>
          </div>

          <!-- Progress Bar -->
          <q-linear-progress
            :value="progressPercent"
            rounded
            size="8px"
            color="primary"
            class="q-mb-md"
            :loading="shipmentStore.progressUpdating"
          />

          <!-- Stepper / Stage Points -->
          <div class="row items-center justify-between text-caption text-grey-8 wrap q-col-gutter-xs">
            <div
              v-for="(stage, sIdx) in activeFlowStages"
              :key="stage.tag_id || sIdx"
              class="column items-center cursor-pointer q-px-xs stage-point"
              :class="{
                'text-positive': currentStageIndex > sIdx,
                'text-primary text-weight-bold': currentStageIndex === sIdx,
                'text-grey-5': currentStageIndex < sIdx
              }"
              @click="changeProgressTag(stage.tag_id)"
            >
              <q-icon
                v-if="currentStageIndex > sIdx"
                name="ph ph-check-circle"
                size="20px"
                color="positive"
              />
              <q-icon
                v-else-if="currentStageIndex === sIdx"
                name="ph ph-radio-button"
                size="20px"
                color="primary"
              />
              <q-icon
                v-else
                name="ph ph-circle"
                size="20px"
                color="grey-4"
              />
              <span class="q-mt-xs text-caption text-center" style="font-size: 11px; max-width: 90px; line-height: 1.1">
                {{ stage.name }}
              </span>
              <q-tooltip>Click to set progress to {{ stage.name }}</q-tooltip>
            </div>
          </div>
        </template>
      </q-card>
    </div>

    <!-- Summary Metrics Section -->
    <div class="q-px-md q-pt-md">
      <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs" style="letter-spacing: 0.5px">
        Financial & Logistics Summary
      </div>
      <div class="row q-col-gutter-sm">
        <!-- 1. Goods Purchase -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="bg-white q-pa-sm summary-kpi-card">
            <div class="text-caption text-grey-7 row items-center justify-between">
              <span>Goods Purchase</span>
              <q-icon name="ph ph-receipt" size="16px" color="primary" />
            </div>
            <div class="text-h6 text-weight-bolder text-grey-9 q-mt-xs">
              {{ currentPurchaseCurrencySymbol }}{{ (summaryKPIs?.goods_purchase_total ?? 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              {{ summaryKPIs?.total_ordered_quantity ?? 0 }} units across {{ summaryKPIs?.total_lines ?? 0 }} lines
            </div>
          </q-card>
        </div>

        <!-- 2. Total Landed Cost -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="bg-white q-pa-sm summary-kpi-card">
            <div class="text-caption text-grey-7 row items-center justify-between">
              <span>Total Landed Cost</span>
              <q-icon name="ph ph-currency-circle-dollar" size="16px" color="positive" />
            </div>
            <div class="text-h6 text-weight-bolder text-positive q-mt-xs">
              {{ currentCostCurrencySymbol }}{{ (summaryKPIs?.total_landed_cost_bdt ?? 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              Avg: {{ currentCostCurrencySymbol }}{{ (summaryKPIs?.avg_cost_per_unit_bdt ?? 0).toFixed(2) }} / unit
            </div>
          </q-card>
        </div>

        <!-- 3. Cargo Weight -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="bg-white q-pa-sm summary-kpi-card">
            <div class="text-caption text-grey-7 row items-center justify-between">
              <span>Cargo Weight</span>
              <q-icon name="ph ph-scales" size="16px" color="indigo-8" />
            </div>
            <div class="text-h6 text-weight-bolder text-grey-9 q-mt-xs">
              {{ (summaryKPIs?.cargo_weight_kg ?? 0).toFixed(2) }} kg
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              Est Pkg: {{ (summaryKPIs?.packaging_weight_kg ?? 0).toFixed(2) }} kg
            </div>
          </q-card>
        </div>

        <!-- 4. Invoice Matched -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="bg-white q-pa-sm summary-kpi-card">
            <div class="text-caption text-grey-7 row items-center justify-between">
              <span>Invoice Matched</span>
              <q-icon
                :name="summaryKPIs?.weight_matched && summaryKPIs?.purchase_matched ? 'ph ph-check-circle' : 'ph ph-warning-circle'"
                size="16px"
                :color="summaryKPIs?.weight_matched && summaryKPIs?.purchase_matched ? 'teal-8' : 'orange-9'"
              />
            </div>
            <div
              class="text-h6 text-weight-bolder q-mt-xs"
              :class="summaryKPIs?.weight_matched && summaryKPIs?.purchase_matched ? 'text-teal-8' : 'text-orange-9'"
            >
              {{ summaryKPIs?.matched_invoices_ratio ?? '0/2' }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              {{ summaryKPIs?.weight_matched && summaryKPIs?.purchase_matched ? 'No discrepancy' : 'Adjustments needed' }}
            </div>
          </q-card>
        </div>
      </div>
    </div>

    <!-- Action Flow & Guidance Stepper -->
    <div class="q-px-md q-pt-md">
      <div class="row items-center justify-between q-mb-xs">
        <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
          Procurement Action Flow & Checklist
        </div>
        <div class="text-caption text-primary text-weight-bold">
          Step {{ currentStepNumber }} of 5: {{ currentStepTitle }}
        </div>
      </div>

      <q-card flat bordered class="bg-white q-pa-md summary-kpi-card">
        <!-- Horizontal Step Indicators -->
        <div class="row items-center justify-between q-mb-md action-steps-row">
          <!-- Step 1: List -->
          <div
            class="action-step-item column items-center cursor-pointer"
            :class="{
              'is-completed text-positive': step1Completed,
              'is-active text-primary text-weight-bold': currentStepNumber === 1,
              'is-pending text-grey-6': currentStepNumber !== 1 && !step1Completed
            }"
            @click="goToListPage"
          >
            <div class="step-circle q-mb-xs row items-center justify-center">
              <q-icon v-if="step1Completed" name="ph ph-check" size="14px" />
              <span v-else>1</span>
            </div>
            <div class="step-label text-center">Add Items</div>
            <div class="step-sub text-grey-6" style="font-size: 10px">Packing list</div>
          </div>

          <div class="step-connector col" :class="{ 'is-active': step1Completed }" />

          <!-- Step 2: Weight & Price in List -->
          <div
            class="action-step-item column items-center cursor-pointer"
            :class="{
              'is-completed text-positive': step2Completed,
              'is-active text-primary text-weight-bold': currentStepNumber === 2,
              'is-pending text-grey-6': currentStepNumber !== 2 && !step2Completed
            }"
            @click="goToListPage"
          >
            <div class="step-circle q-mb-xs row items-center justify-center">
              <q-icon v-if="step2Completed" name="ph ph-check" size="14px" />
              <span v-else>2</span>
            </div>
            <div class="step-label text-center">Item Weights</div>
            <div class="step-sub text-grey-6" style="font-size: 10px">Line weights & prices</div>
          </div>

          <div class="step-connector col" :class="{ 'is-active': step2Completed }" />

          <!-- Step 3: Rates & Cost Entries -->
          <div
            class="action-step-item column items-center cursor-pointer"
            :class="{
              'is-completed text-positive': step3Completed,
              'is-active text-primary text-weight-bold': currentStepNumber === 3,
              'is-pending text-grey-6': currentStepNumber !== 3 && !step3Completed
            }"
            @click="goToRatesPage"
          >
            <div class="step-circle q-mb-xs row items-center justify-center">
              <q-icon v-if="step3Completed" name="ph ph-check" size="14px" />
              <span v-else>3</span>
            </div>
            <div class="step-label text-center">Rates & FX</div>
            <div class="step-sub text-grey-6" style="font-size: 10px">Product & cargo rates</div>
          </div>

          <div class="step-connector col" :class="{ 'is-active': step3Completed }" />

          <!-- Step 4: Invoice Adjustments -->
          <div
            class="action-step-item column items-center cursor-pointer"
            :class="{
              'is-completed text-positive': step4Completed,
              'is-active text-primary text-weight-bold': currentStepNumber === 4,
              'is-pending text-grey-6': currentStepNumber !== 4 && !step4Completed
            }"
            @click="goToAdjustPage"
          >
            <div class="step-circle q-mb-xs row items-center justify-center">
              <q-icon v-if="step4Completed" name="ph ph-check" size="14px" />
              <span v-else>4</span>
            </div>
            <div class="step-label text-center">Match Invoices</div>
            <div class="step-sub text-grey-6" style="font-size: 10px">Weight & purchase balance</div>
          </div>

          <div class="step-connector col" :class="{ 'is-active': step4Completed }" />

          <!-- Step 5: Settle & Receive -->
          <div
            class="action-step-item column items-center cursor-pointer"
            :class="{
              'is-completed text-positive': step5Completed,
              'is-active text-primary text-weight-bold': currentStepNumber === 5,
              'is-pending text-grey-6': currentStepNumber !== 5 && !step5Completed
            }"
            @click="goToSettlePage"
          >
            <div class="step-circle q-mb-xs row items-center justify-center">
              <q-icon v-if="step5Completed" name="ph ph-check" size="14px" />
              <span v-else>5</span>
            </div>
            <div class="step-label text-center">Settle & Credit</div>
            <div class="step-sub text-grey-6" style="font-size: 10px">Pay vendors & agents</div>
          </div>
        </div>

        <!-- Dynamic Action Call-to-Action Box -->
        <div class="bg-grey-1 rounded-borders q-pa-sm row items-center justify-between border-light wrap q-gutter-y-xs">
          <div class="row items-center q-gutter-x-sm min-width-0 col-12 col-md-auto">
            <q-icon :name="currentStepIcon" size="22px" :color="currentStepColor" />
            <div class="min-width-0">
              <div class="text-subtitle2 text-weight-bold text-grey-9">
                {{ currentStepActionTitle }}
              </div>
              <div class="text-caption text-grey-7" style="font-size: 11.5px">
                {{ currentStepDescription }}
              </div>
            </div>
          </div>

          <q-btn
            unelevated
            dense
            no-caps
            size="sm"
            :color="currentStepColor"
            :icon-right="currentStepButtonIcon"
            :label="currentStepButtonLabel"
            class="q-px-md text-weight-bold rounded-btn col-12 col-md-auto"
            @click="handleStepAction"
          />
        </div>
      </q-card>
    </div>

    <!-- Action Modules Section -->
    <div class="q-px-md q-pt-md">
      <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs" style="letter-spacing: 0.5px">
        Modules & Actions
      </div>
      <div class="row q-col-gutter-sm">
        <!-- List Card -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card
            flat
            bordered
            class="cursor-pointer hover-card text-center q-pa-md"
            @click="goToListPage"
          >
            <q-card-section class="column items-center q-pa-none">
              <div class="card-icon-badge bg-blue-1 text-primary q-mb-sm">
                <q-icon name="ph ph-package" size="32px" />
              </div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">List</div>
              <div class="text-caption text-grey-6">Items & Packing List</div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Rates Card -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card
            flat
            bordered
            class="cursor-pointer hover-card text-center q-pa-md"
            @click="goToRatesPage"
          >
            <q-card-section class="column items-center q-pa-none">
              <div class="card-icon-badge bg-emerald-1 text-teal-9 q-mb-sm" style="background-color: #ecfdf5; color: #059669;">
                <q-icon name="ph ph-currency-circle-dollar" size="32px" />
              </div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Rates</div>
              <div class="text-caption text-grey-6">Rates & Cost Entries</div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Adjust Card -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card
            flat
            bordered
            class="cursor-pointer hover-card text-center q-pa-md"
            @click="goToAdjustPage"
          >
            <q-card-section class="column items-center q-pa-none">
              <div class="card-icon-badge bg-purple-1 text-purple-9 q-mb-sm" style="background-color: #f5f3ff; color: #7c3aed;">
                <q-icon name="ph ph-scales" size="32px" />
              </div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Adjust</div>
              <div class="text-caption text-grey-6">Balance & Invoices Match</div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Settle Card -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card
            flat
            bordered
            class="cursor-pointer hover-card text-center q-pa-md"
            @click="goToSettlePage"
          >
            <q-card-section class="column items-center q-pa-none">
              <div class="card-icon-badge bg-amber-1 text-amber-9 q-mb-sm" style="background-color: #fef3c7; color: #d97706;">
                <q-icon name="ph ph-wallet" size="32px" />
              </div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Settle</div>
              <div class="text-caption text-grey-6">Payees & Store Credit</div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, onMounted, watch } from 'vue';
import { QChip, QInput, useQuasar } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { globalShipmentRepository } from '../repositories/globalShipmentRepository';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import ShipmentStatusWorkflowBar from '../components/ShipmentStatusWorkflowBar.vue';
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const vendorStore = useVendorStore();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const dummyStatus = ref<'draft' | 'ordered' | 'shipped' | 'customs' | 'received' | 'cancelled'>('shipped');
const updatingStatus = ref(false);
const targetUpdatingStatus = ref<string | null>(null);

const changeStatus = (newStatus: string) => {
  const current = shipmentStore.currentShipment?.status || dummyStatus.value;
  if (current === newStatus) return;

  $q.dialog({
    title: 'Confirm Status Change',
    message: `Are you sure you want to change the status of this shipment to "${newStatus}"?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      updatingStatus.value = true;
      targetUpdatingStatus.value = newStatus;
      try {
        if (shipmentId && !isNaN(shipmentId)) {
          await shipmentStore.updateShipment(shipmentId, { status: newStatus as any });
          await shipmentStore.fetchShipmentDetails(shipmentId);
        } else {
          dummyStatus.value = newStatus as any;
        }
        showSuccessNotification(`Shipment status updated to: ${newStatus}`);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        showErrorNotification(message || 'Failed to update status');
      } finally {
        updatingStatus.value = false;
        targetUpdatingStatus.value = null;
      }
    })();
  });
};

// Type handling
const typeOptions = [
  { label: 'International', value: 'international' as const },
  { label: 'Local', value: 'local' as const },
  { label: 'Transfer', value: 'transfer' as const },
];

const currentTypeLabel = computed(() => {
  const t = shipmentStore.currentShipment?.type;
  if (!t) return 'Type';
  return t.charAt(0).toUpperCase() + t.slice(1);
});

const saveInlineType = async (typeVal: 'international' | 'local' | 'transfer') => {
  if (!shipmentId) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { type: typeVal });
    showSuccessNotification('Shipment type updated');
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to update shipment type');
  }
};

// Vendor handling
const loadingVendors = ref(false);
const ensureVendorsLoaded = async () => {
  if (authStore.tenantId && vendorStore.items.length === 0) {
    loadingVendors.value = true;
    try {
      await vendorStore.fetchVendors(authStore.tenantId);
    } catch (err) {
      console.error('Failed to load vendors', err);
    } finally {
      loadingVendors.value = false;
    }
  }
};

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({
    label: v.is_default ? `${v.name} (default)` : v.name,
    value: v.id,
  })),
);

const currentVendorLabel = computed(() => {
  const vId = shipmentStore.currentShipment?.vendor_id;
  if (!vId) return 'Select Vendor';
  const found = vendorStore.items.find((v) => v.id === vId);
  return found ? found.name : `Vendor #${vId}`;
});

const saveInlineVendor = async (val: number | null) => {
  if (!shipmentId || val == null) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { vendor_id: val });
    showSuccessNotification('Vendor updated');
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to update vendor');
  }
};

// Cargo handling
const loadingCargo = ref(false);
const cargoCompanies = ref<Array<{ id: number; name: string; code: string }>>([]);

const ensureCargoLoaded = async () => {
  if (authStore.tenantId && cargoCompanies.value.length === 0) {
    loadingCargo.value = true;
    try {
      cargoCompanies.value = await globalShipmentRepository.listCargoCompaniesForTenant(
        authStore.tenantId,
      );
    } catch (err) {
      console.error('Failed to load cargo companies', err);
    } finally {
      loadingCargo.value = false;
    }
  }
};

const cargoOptions = computed(() =>
  cargoCompanies.value.map((c) => ({
    label: `${c.name} (${c.code})`,
    value: c.id,
  })),
);

const currentCargoLabel = computed(() => {
  const cId = shipmentStore.currentShipment?.cargo_company_id;
  if (!cId) return 'Select Cargo';
  const found = cargoCompanies.value.find((c) => c.id === cId);
  return found ? found.name : `Cargo #${cId}`;
});

const saveInlineCargo = async (val: number | null) => {
  if (!shipmentId) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { cargo_company_id: val });
    showSuccessNotification('Cargo vendor updated');
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to update cargo vendor');
  }
};

const shipmentName = ref(shipmentStore.currentShipment?.name || 'SHP-2026-0042 / Summer Collection');
const editingName = ref(false);
const originalName = ref(shipmentName.value);
const nameEditInputRef = ref<InstanceType<typeof QInput> | null>(null);

watch(
  () => shipmentStore.currentShipment,
  (shipment) => {
    if (shipment) {
      if (!editingName.value && shipment.name) {
        shipmentName.value = shipment.name;
      }
      if (shipment.status) {
        dummyStatus.value = shipment.status as any;
      }
    }
  },
  { immediate: true, deep: true },
);

// Summary KPIs handling
const calculations = useInboundShipmentCalculations();
const { currentPurchaseCurrencySymbol, currentCostCurrencySymbol } = calculations;

const summaryKPIs = computed(() => {
  if (shipmentStore.currentShipmentSummary) {
    return shipmentStore.currentShipmentSummary;
  }
  // Fallback to live calculations if summary not yet loaded
  const totals = calculations.totals.value;
  const items = shipmentStore.currentShipmentItems;
  const boxes = shipmentStore.currentShipmentBoxes;
  const totalOrderedQty = items.reduce((sum, it) => sum + (Number(it.ordered_quantity) || 0), 0);
  const totalReceivedQty = items.reduce((sum, it) => sum + (Number(it.received_quantity) || 0), 0);
  const avgCost = totalOrderedQty > 0 ? totals.totalCost / totalOrderedQty : 0;
  
  let matchCount = 0;
  if (!calculations.weightNeedsAttention.value && calculations.hasCargoInvoiceWeight.value) matchCount++;
  if (!calculations.purchaseNeedsAttention.value && calculations.hasProductInvoiceTotal.value) matchCount++;

  return {
    total_lines: items.length,
    total_ordered_quantity: totalOrderedQty,
    total_received_quantity: totalReceivedQty,
    packaging_weight_kg: totals.packagingWeightKg,
    cargo_weight_kg: totals.cargoWeightKg,
    boxes_weight_kg: boxes.reduce((sum, b) => sum + (Number(b.weight_kg) || 0), 0),
    boxes_count: boxes.length,
    purchase_currency_symbol: currentPurchaseCurrencySymbol.value,
    cost_currency_symbol: currentCostCurrencySymbol.value,
    goods_purchase_total: totals.goodsPurchase,
    cargo_purchase_total: totals.cargoPurchase,
    total_purchase_amount: totals.totalPurchase,
    goods_cost_bdt: totals.goodsCost,
    cargo_cost_bdt: totals.cargoCost,
    total_landed_cost_bdt: totals.totalCost,
    avg_cost_per_unit_bdt: avgCost,
    effective_exchange_rate: totals.transactionRate,
    has_cargo_weight: calculations.hasCargoInvoiceWeight.value,
    has_product_invoice: calculations.hasProductInvoiceTotal.value,
    weight_matched: !calculations.weightNeedsAttention.value && calculations.hasCargoInvoiceWeight.value,
    purchase_matched: !calculations.purchaseNeedsAttention.value && calculations.hasProductInvoiceTotal.value,
    weight_delta_kg: Math.abs(totals.packagingWeightKg - totals.cargoWeightKg),
    purchase_delta_amount: 0,
    matched_invoices_ratio: `${matchCount}/2`,
    is_cost_finalized: calculations.isCostFinalized.value,
  };
});

// Step Completion Checks & Flow Logic (v2 Procurement Architecture)
// Step 1: Add Items (packing list exists)
const step1Completed = computed(() => {
  return (shipmentStore.currentShipmentItems?.length ?? 0) > 0;
});

// Step 2: Set weights and prices for items in list
const step2Completed = computed(() => {
  if (!step1Completed.value) return false;
  const items = shipmentStore.currentShipmentItems;
  return items.every((it) => (Number(it.purchase_price) || 0) > 0 && (Number(it.package_weight) || 0) > 0);
});

// Step 3: Rates & Cost Entries configured
const step3Completed = computed(() => {
  const entries = shipmentStore.currentCostEntries;
  if (!entries || entries.length === 0) return false;
  const hasProduct = entries.some((e) => e.cost_type === 'product' && (Number(e.amount) || 0) > 0);
  const hasCargo = entries.some((e) => e.cost_type === 'cargo' && (Number(e.amount) || 0) > 0);
  return hasProduct && (shipmentStore.currentShipment?.type === 'local' || hasCargo);
});

// Step 4: Invoice Adjustments Matched (Weight & Purchase balanced)
const step4Completed = computed(() => {
  const sum = summaryKPIs.value;
  return !!sum?.weight_matched && !!sum?.purchase_matched;
});

// Step 5: Payee Settlement & Receive finalized
const step5Completed = computed(() => {
  return shipmentStore.currentShipment?.status === 'received' || !!shipmentStore.currentShipment?.stock_ready;
});

// Current Active Action Step
const currentStepNumber = computed(() => {
  if (!step1Completed.value) return 1;
  if (!step2Completed.value) return 2;
  if (!step3Completed.value) return 3;
  if (!step4Completed.value) return 4;
  return 5;
});

const currentStepTitle = computed(() => {
  switch (currentStepNumber.value) {
    case 1:
      return 'Add Line Items';
    case 2:
      return 'Set Item Weights & Prices';
    case 3:
      return 'Configure Rates & FX';
    case 4:
      return 'Match Invoices & Adjust';
    case 5:
      return 'Settle Payees & Finalize';
    default:
      return 'Complete';
  }
});

const currentStepActionTitle = computed(() => {
  switch (currentStepNumber.value) {
    case 1:
      return 'Step 1: Build the Shipment Packing List';
    case 2:
      return 'Step 2: Enter Unit Purchase Prices & Package Weights';
    case 3:
      return 'Step 3: Enter Product FX & Cargo Freight Rates';
    case 4:
      return 'Step 4: Reconcile & Balance Cargo/Purchase Invoices';
    case 5:
      return 'Step 5: Settle Payees & Mark Shipment Received';
    default:
      return 'All Procurement Steps Completed';
  }
});

const currentStepDescription = computed(() => {
  switch (currentStepNumber.value) {
    case 1:
      return 'Your shipment has no items yet. Open the List module to add products or paste in bulk from Excel.';
    case 2:
      return 'Some line items are missing purchase prices or package weights. Update them directly in the List table.';
    case 3:
      return 'Configure product conversion rate and cargo freight rate in Rates & Cost Entries to calculate landed costs.';
    case 4:
      return 'Lines differ from your invoice totals. Open Adjust to balance package weight deltas and purchase totals.';
    case 5:
      return 'Shipment is balanced! Pay vendors or cargo agents via store credit, then mark received to post stock.';
    default:
      return 'All items, rates, invoices, and settlements are in sync.';
  }
});

const currentStepColor = computed(() => {
  switch (currentStepNumber.value) {
    case 1:
      return 'primary';
    case 2:
      return 'blue-8';
    case 3:
      return 'teal-8';
    case 4:
      return 'purple-8';
    case 5:
      return 'amber-9';
    default:
      return 'positive';
  }
});

const currentStepIcon = computed(() => {
  switch (currentStepNumber.value) {
    case 1:
      return 'ph ph-package';
    case 2:
      return 'ph ph-scales';
    case 3:
      return 'ph ph-currency-circle-dollar';
    case 4:
      return 'ph ph-sliders';
    case 5:
      return 'ph ph-wallet';
    default:
      return 'ph ph-check-circle';
  }
});

const currentStepButtonLabel = computed(() => {
  switch (currentStepNumber.value) {
    case 1:
      return 'Open List & Add Items';
    case 2:
      return 'Edit Weights in List';
    case 3:
      return 'Set Rates & FX';
    case 4:
      return 'Match Invoices';
    case 5:
      return 'Settle & Receive';
    default:
      return 'View Summary';
  }
});

const currentStepButtonIcon = computed(() => {
  return 'ph ph-arrow-right';
});

const handleStepAction = () => {
  switch (currentStepNumber.value) {
    case 1:
    case 2:
      goToListPage();
      break;
    case 3:
      goToRatesPage();
      break;
    case 4:
      goToAdjustPage();
      break;
    case 5:
      goToSettlePage();
      break;
    default:
      goToListPage();
      break;
  }
};

// Progress Flow & Stages handling
const progressFlowOptions = computed(() =>
  shipmentStore.progressFlows.filter((flow) => flow.is_active !== false),
);

const flowSelectOptions = computed(() =>
  progressFlowOptions.value.map((f) => ({
    label: f.name + (f.is_default ? ' (Default)' : ''),
    value: f.id,
  })),
);

const currentProgressFlowId = computed(() => {
  return (
    shipmentStore.currentShipment?.progress_flow_id ??
    shipmentStore.progressFlows.find((f) => f.is_default)?.id ??
    null
  );
});

const currentFlowName = computed(() => {
  const flow = shipmentStore.progressFlows.find((f) => f.id === currentProgressFlowId.value);
  return flow ? flow.name : 'Standard Flow';
});

const activeFlowStages = computed(() => {
  const fId = currentProgressFlowId.value;
  if (!fId) return [];
  return (shipmentStore.progressStagesByFlow[fId] ?? []).filter((s) => s.is_active !== false);
});

const currentProgressTagId = computed(() => {
  return (
    shipmentStore.currentShipment?.progress_tag_id ??
    shipmentStore.currentShipment?.progress_tag?.id ??
    null
  );
});

const currentStageIndex = computed(() => {
  if (!currentProgressTagId.value) return -1;
  return activeFlowStages.value.findIndex((s) => s.tag_id === currentProgressTagId.value);
});

const currentActiveStage = computed(() => {
  if (currentStageIndex.value < 0) return null;
  return activeFlowStages.value[currentStageIndex.value] ?? null;
});

const progressPercent = computed(() => {
  const total = activeFlowStages.value.length;
  if (total <= 0) return 0;
  if (currentStageIndex.value < 0) return 0;
  return (currentStageIndex.value + 1) / total;
});

const loadProgressData = async () => {
  if (!authStore.tenantId) return;
  try {
    await shipmentStore.loadProgressFlows(authStore.tenantId, true);
    const flowId = currentProgressFlowId.value;
    if (flowId) {
      await shipmentStore.loadProgressFlowStages(flowId, false);
    }
  } catch (err) {
    console.error('Failed to load progress data', err);
  }
};

const changeFlow = async (flowId: number) => {
  if (!shipmentStore.currentShipment || shipmentStore.currentShipment.progress_flow_id === flowId) return;
  try {
    await shipmentStore.setShipmentFlow(shipmentStore.currentShipment.id, flowId);
    await shipmentStore.loadProgressFlowStages(flowId, false);
    showSuccessNotification('Progress flow updated');
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to update progress flow');
  }
};

const changeProgressTag = async (tagId: number | null) => {
  if (!shipmentId || isNaN(shipmentId)) return;
  try {
    await shipmentStore.setProgressTag(shipmentId, tagId);
    showSuccessNotification('Progress stage updated');
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to update progress stage');
  }
};

watch(
  () => currentProgressFlowId.value,
  async (fId) => {
    if (fId && !shipmentStore.progressStagesByFlow[fId]) {
      await shipmentStore.loadProgressFlowStages(fId, false);
    }
  },
);

watch(
  () => authStore.tenantId,
  (tId) => {
    if (tId) {
      ensureVendorsLoaded();
      ensureCargoLoaded();
      loadProgressData();
    }
  },
  { immediate: true },
);

onMounted(async () => {
  ensureVendorsLoaded();
  ensureCargoLoaded();
  loadProgressData();
  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.fetchShipmentDetails(shipmentId);
    } catch (e) {
      // Keep fallback
    }
  }
});

const startNameEdit = () => {
  originalName.value = shipmentName.value;
  editingName.value = true;
  nextTick(() => {
    nameEditInputRef.value?.focus();
    nameEditInputRef.value?.select();
  });
};

const commitNameEdit = async () => {
  const trimmed = shipmentName.value.trim();
  if (!trimmed) {
    shipmentName.value = originalName.value;
    editingName.value = false;
    return;
  }

  editingName.value = false;
  if (trimmed === originalName.value) return;

  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.updateShipment(shipmentId, { name: trimmed });
      showSuccessNotification('Shipment name updated');
    } catch (err: any) {
      shipmentName.value = originalName.value;
      showErrorNotification(err?.message || 'Failed to update shipment name');
    }
  } else {
    // If running standalone without id param, simulate success
    showSuccessNotification('Shipment name updated');
  }
};

const goToListPage = () => {
  const tenantSlug = route.params.tenantSlug;
  const sId = shipmentStore.currentShipment?.id || shipmentId;
  if (!sId) return;

  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-items',
      params: { tenantSlug, id: sId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-items',
      params: { id: sId },
    });
  }
};

const goToRatesPage = () => {
  const tenantSlug = route.params.tenantSlug;
  const sId = shipmentStore.currentShipment?.id || shipmentId;
  if (!sId) return;

  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-rates',
      params: { tenantSlug, id: sId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-rates',
      params: { id: sId },
    });
  }
};

const goToAdjustPage = () => {
  const tenantSlug = route.params.tenantSlug;
  const sId = shipmentStore.currentShipment?.id || shipmentId;
  if (!sId) return;

  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-adjust',
      params: { tenantSlug, id: sId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-adjust',
      params: { id: sId },
    });
  }
};

const goToSettlePage = () => {
  const tenantSlug = route.params.tenantSlug;
  const sId = shipmentStore.currentShipment?.id || shipmentId;
  if (!sId) return;

  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-settle',
      params: { tenantSlug, id: sId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-settle',
      params: { id: sId },
    });
  }
};

const goToFlowSettings = () => {
  const tenantSlug = route.params.tenantSlug;
  const flowId = currentProgressFlowId.value;

  if (flowId) {
    if (tenantSlug) {
      void router.push({
        name: 'app-procurement-shipment-progress-flow',
        params: { tenantSlug, flowId },
      });
    } else {
      void router.push({
        name: 'app-procurement-shipment-progress-flow',
        params: { flowId },
      });
    }
  } else {
    if (tenantSlug) {
      void router.push({
        name: 'app-procurement-shipment-progress-settings',
        params: { tenantSlug },
      });
    } else {
      void router.push({
        name: 'app-procurement-shipment-progress-settings',
      });
    }
  }
};

const goBack = () => {
  router.back();
};
</script>

<style scoped>
.shipment-overview-page .min-width-0 {
  min-width: 0;
}

.name-display:hover .edit-icon {
  color: var(--q-primary) !important;
}

.shipment-name-input :deep(input) {
  font-size: 1.5rem;
  font-weight: 700;
}

.progress-flow-select {
  min-width: 130px;
}

.progress-flow-select :deep(.q-field__control) {
  height: 28px;
  min-height: 28px;
  padding: 0 6px;
  font-size: 12px;
}

.status-bar-card,
.summary-kpi-card,
.hover-card {
  border-radius: 12px;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.card-icon-badge {
  width: 52px;
  height: 52px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.2s ease;
}

.hover-card:hover .card-icon-badge {
  transform: scale(1.08);
}

.hover-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
}

.rates-table {
  border-radius: 0 0 12px 12px;
}

/* Action Stepper Styles */
.action-steps-row {
  position: relative;
}

.action-step-item {
  position: relative;
  z-index: 2;
  flex: 0 0 auto;
}

.step-circle {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  font-size: 11px;
  font-weight: 700;
  background-color: #f1f5f9;
  color: #64748b;
  border: 1px solid #cbd5e1;
  transition: all 0.2s ease;
}

.action-step-item.is-completed .step-circle {
  background-color: #ecfdf5;
  color: #10b981;
  border-color: #10b981;
}

.action-step-item.is-active .step-circle {
  background-color: var(--q-primary);
  color: #ffffff;
  border-color: var(--q-primary);
  box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.2);
}

.step-label {
  font-size: 11.5px;
  white-space: nowrap;
}

.step-connector {
  height: 2px;
  background-color: #e2e8f0;
  margin: 0 4px;
  position: relative;
  top: -10px;
  z-index: 1;
}

.step-connector.is-active {
  background-color: #10b981;
}

.rounded-btn {
  border-radius: 8px;
}
</style>
