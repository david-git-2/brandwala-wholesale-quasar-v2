<template>
  <q-page class="q-pa-md shipment-overview-page">
    <div class="q-gutter-y-md">
      <!-- Header Section: Title, Action, & Metadata Chips -->
      <div>
        <div class="row items-center q-gutter-x-sm no-wrap">
          <template v-if="editingName">
            <q-input
              ref="nameEditInputRef"
              v-model="shipmentName"
              autofocus
              dense
              outlined
              hide-bottom-space
              class="shipment-name-input text-h4 text-weight-bolder col-grow bg-white"
              style="max-width: 500px;"
              @keyup.enter="commitNameEdit"
              @keyup.escape="cancelNameEdit"
              @blur="commitNameEdit"
            />
          </template>
          <template v-else>
            <div
              class="text-h4 text-weight-bolder text-grey-9 cursor-pointer row items-center q-gutter-x-sm name-display"
              role="button"
              tabindex="0"
              @click="startNameEdit"
              @keyup.enter="startNameEdit"
            >
              <span>{{ shipmentName }}</span>
              <q-icon name="edit" size="20px" color="grey-6" class="edit-icon" />
            </div>
          </template>

          <q-space />

          <q-btn
            flat
            dense
            no-caps
            size="sm"
            color="primary"
            icon="ph ph-download-simple"
            label="Excel"
            :disable="!shipmentStore.currentShipment"
            @click="downloadExcel"
          >
            <q-tooltip>Download shipment Excel</q-tooltip>
          </q-btn>
        </div>

        <!-- Metadata Chips Row -->
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

          <!-- Shop / Assigned Tenant Chip -->
          <q-chip
            clickable
            :label="currentShopLabel"
            icon-right="arrow_drop_down"
            :color="shipmentStore.currentShipment?.assigned_child_tenant_id ? 'primary' : undefined"
            :text-color="shipmentStore.currentShipment?.assigned_child_tenant_id ? 'white' : undefined"
            :outline="!shipmentStore.currentShipment?.assigned_child_tenant_id"
          >
            <q-menu auto-close>
              <q-list dense style="min-width: 220px; max-height: 300px" class="scroll">
                <q-item-label header class="text-caption text-weight-bold text-grey-8 q-py-xs">
                  Assign Shop (Listing Permission)
                </q-item-label>

                <div
                  v-if="shipmentStore.currentShipment?.status !== 'received'"
                  class="q-px-sm q-py-xs bg-amber-1 text-amber-10 text-caption rounded-borders q-mx-xs q-mb-xs"
                >
                  <q-icon name="ph ph-info" size="14px" class="q-mr-xs" />
                  Shipment must be received into stock before shop assignment.
                </div>

                <q-item v-if="loadingChildTenants" dense>
                  <q-item-section class="text-grey-6">Loading shops…</q-item-section>
                </q-item>

                <!-- Clear / Unassign -->
                <q-item
                  v-if="shipmentStore.currentShipment?.assigned_child_tenant_id"
                  clickable
                  :disable="shipmentStore.currentShipment?.status !== 'received' || savingShop"
                  @click="saveInlineShop(null)"
                >
                  <q-item-section avatar style="min-width: 28px">
                    <q-icon name="ph ph-x-circle" size="16px" color="grey-6" />
                  </q-item-section>
                  <q-item-section class="text-grey-7">Unassign (Clear)</q-item-section>
                </q-item>

                <!-- Child / Sister Tenants -->
                <q-item
                  v-for="opt in childTenantOptions"
                  :key="opt.value"
                  clickable
                  :active="shipmentStore.currentShipment?.assigned_child_tenant_id === opt.value"
                  :disable="shipmentStore.currentShipment?.status !== 'received' || savingShop"
                  @click="saveInlineShop(opt.value)"
                >
                  <q-item-section avatar style="min-width: 28px">
                    <q-icon
                      :name="shipmentStore.currentShipment?.assigned_child_tenant_id === opt.value ? 'ph ph-check-circle' : 'ph ph-storefront'"
                      size="16px"
                      :color="shipmentStore.currentShipment?.assigned_child_tenant_id === opt.value ? 'primary' : 'grey-6'"
                    />
                  </q-item-section>
                  <q-item-section>{{ opt.label }}</q-item-section>
                </q-item>

                <q-item v-if="!loadingChildTenants && !childTenantOptions.length" dense>
                  <q-item-section class="text-grey-6">No sister shops available</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-chip>
        </div>
      </div>

      <!-- Status Workflow Section -->
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

      <!-- Progress Tracker Section -->
      <div>
        <div class="row items-center justify-between q-mb-xs">
          <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
            Shipment Progress
          </div>
          <div class="row items-center q-gutter-x-sm no-wrap">
            <template v-if="progressFlowOptions.length">
              <span class="text-caption text-weight-medium text-grey-7">Flow:</span>
              <q-select
                :model-value="currentProgressFlowId"
                :options="flowSelectOptions"
                dense
                outlined
                bg-color="white"
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
              size="sm"
              color="primary"
              icon="ph ph-sliders"
              label="Manage"
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

      <!-- Sections & Invoices Section -->
      <div>
        <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs" style="letter-spacing: 0.5px">
          Vendor Sections & Invoices
        </div>
        <ShipmentSectionsCard
          :shipment-id="shipmentId"
          :loading="shipmentStore.loading"
          :is-editable="isEditable"
        />
      </div>

      <!-- Summary Metrics Section -->
      <div>
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
      <div>
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

            <!-- Step 3: Rates & Adjustments -->
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
              <div class="step-label text-center">Rates & Adjust</div>
              <div class="step-sub text-grey-6" style="font-size: 10px">Rates, weights & invoices</div>
            </div>

            <div class="step-connector col" :class="{ 'is-active': step3Completed }" />

            <!-- Step 4: Receive Stock -->
            <div
              class="action-step-item column items-center cursor-pointer"
              :class="{
                'is-completed text-positive': step4Completed,
                'is-active text-primary text-weight-bold': currentStepNumber === 4,
                'is-pending text-grey-6': currentStepNumber !== 4 && !step4Completed
              }"
              @click="goToReceivePage"
            >
              <div class="step-circle q-mb-xs row items-center justify-center">
                <q-icon v-if="step4Completed" name="ph ph-check" size="14px" />
                <span v-else>4</span>
              </div>
              <div class="step-label text-center">Receive Stock</div>
              <div class="step-sub text-grey-6" style="font-size: 10px">Putaway & finalize inventory</div>
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
      <div>
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

          <!-- Rates & Adjust Card -->
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
                <div class="text-subtitle1 text-weight-bold text-grey-9">Rates & Adjust</div>
                <div class="text-caption text-grey-6">Rates, Weights & Invoices</div>
              </q-card-section>
            </q-card>
          </div>

          <!-- Receive Card -->
          <div class="col-12 col-sm-6 col-md-3">
            <q-card
              flat
              bordered
              class="cursor-pointer hover-card text-center q-pa-md"
              @click="goToReceivePage"
            >
              <q-card-section class="column items-center q-pa-none">
                <div class="card-icon-badge bg-indigo-1 text-indigo-9 q-mb-sm" style="background-color: #e0e7ff; color: #3730a3;">
                  <q-icon name="ph ph-warehouse" size="32px" />
                </div>
                <div class="text-subtitle1 text-weight-bold text-grey-9">Receive</div>
                <div class="text-caption text-grey-6">Receive & Putaway Stock</div>
              </q-card-section>
            </q-card>
          </div>

          <!-- Shop Allocation Card -->
          <div class="col-12 col-sm-6 col-md-3">
            <q-card
              flat
              bordered
              class="cursor-pointer hover-card text-center q-pa-md"
              @click="openAllocationDialog"
            >
              <q-card-section class="column items-center q-pa-none">
                <div class="card-icon-badge bg-purple-1 text-purple-9 q-mb-sm" style="background-color: #f3e8ff; color: #7e22ce;">
                  <q-icon name="ph ph-storefront" size="32px" />
                </div>
                <div class="text-subtitle1 text-weight-bold text-grey-9">Shop Allocation</div>
                <div class="text-caption text-grey-6">
                  {{ shipmentStore.currentShipment?.assigned_child_tenant_id ? 'Assigned to shop' : 'Listing permission & ATP' }}
                </div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>
    </div>

    <!-- Allocation Details & Mechanism Dialog -->
    <q-dialog v-model="showAllocationDialog" persistent>
      <q-card style="width: 580px; max-width: 95vw; border-radius: 12px">
        <q-card-section class="row items-center justify-between border-bottom q-pb-sm">
          <div class="row items-center q-gutter-x-sm">
            <div class="card-icon-badge bg-primary text-white row items-center justify-center" style="width: 32px; height: 32px; border-radius: 8px">
              <q-icon name="ph ph-storefront" size="18px" />
            </div>
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Shop Allocation & Listing</div>
              <div class="text-caption text-grey-6">Shipment-to-Shop batch permission & live ATP</div>
            </div>
          </div>
          <q-btn v-close-popup icon="ph ph-x" flat round dense color="grey-7" />
        </q-card-section>

        <q-card-section class="q-pt-md">
          <!-- Architecture Mechanism Banner -->
          <div class="bg-blue-1 text-primary q-pa-sm rounded-borders q-mb-md border-light text-caption" style="line-height: 1.4">
            <div class="text-weight-bold row items-center q-gutter-x-xs q-mb-xs">
              <q-icon name="ph ph-info" size="16px" />
              <span>How Stock Allocation Works (v2 Architecture)</span>
            </div>
            <div>
              Physical stock is held centrally in the warehouse (<code>global_stocks</code>). Assigning this received shipment gives the selected shop permission to list and sell items. The shop sells in real-time from shared Available-to-Promise (ATP) stock without duplicate inventory rows.
            </div>
          </div>

          <!-- Current Shipment Status Alert if not received -->
          <q-banner
            v-if="shipmentStore.currentShipment?.status !== 'received'"
            class="bg-amber-1 text-amber-10 rounded-borders q-mb-md q-py-xs"
            dense
            rounded
          >
            <template #avatar>
              <q-icon name="ph ph-warning" size="20px" />
            </template>
            <span class="text-caption text-weight-medium">
              Shipment status is currently <strong>{{ shipmentStore.currentShipment?.status }}</strong>. Physical stock must be checked in and received into the warehouse before it can be assigned to a shop.
            </span>
          </q-banner>

          <!-- Current Assignment Form -->
          <div class="q-mb-md">
            <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Assigned Sister Concern / Shop</div>
            <div class="row q-col-gutter-sm items-center">
              <div class="col">
                <q-select
                  v-model="selectedDialogShopId"
                  :options="childTenantOptions"
                  dense
                  outlined
                  emit-value
                  map-options
                  clearable
                  options-dense
                  :loading="loadingChildTenants"
                  placeholder="Select shop or keep unassigned"
                  :disable="shipmentStore.currentShipment?.status !== 'received' || savingShop"
                />
              </div>
              <div class="col-auto row q-gutter-xs">
                <q-btn
                  color="primary"
                  unelevated
                  dense
                  no-caps
                  label="Save Assign"
                  class="q-px-sm"
                  style="border-radius: 8px"
                  :loading="savingShop"
                  :disable="shipmentStore.currentShipment?.status !== 'received'"
                  @click="saveInlineShop(selectedDialogShopId)"
                />
                <q-btn
                  flat
                  dense
                  no-caps
                  label="Clear"
                  color="grey-7"
                  class="q-px-sm"
                  style="border-radius: 8px"
                  :loading="savingShop"
                  :disable="!shipmentStore.currentShipment?.assigned_child_tenant_id || shipmentStore.currentShipment?.status !== 'received'"
                  @click="saveInlineShop(null); selectedDialogShopId = null"
                />
              </div>
            </div>
          </div>

          <!-- Live Stock & ATP Summary for this batch -->
          <div class="bg-grey-1 rounded-borders q-pa-sm border-light q-mb-md">
            <div class="text-caption text-weight-bold text-grey-7 q-mb-xs text-uppercase" style="font-size: 10.5px">
              Batch Stock Summary
            </div>
            <div class="row text-center q-col-gutter-xs">
              <div class="col-4">
                <div class="text-caption text-grey-6">Ordered Qty</div>
                <div class="text-weight-bold text-grey-9">{{ summaryKPIs?.total_ordered_quantity ?? 0 }} pcs</div>
              </div>
              <div class="col-4">
                <div class="text-caption text-grey-6">Received Qty</div>
                <div class="text-weight-bold text-positive">{{ summaryKPIs?.total_received_quantity ?? 0 }} pcs</div>
              </div>
              <div class="col-4">
                <div class="text-caption text-grey-6">Active Shop</div>
                <div class="text-weight-bold text-primary">
                  {{ shipmentStore.currentShipment?.assigned_child_tenant_id ? currentShopLabel.replace('Shop: ', '') : 'None (Unassigned)' }}
                </div>
              </div>
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="between" class="bg-grey-1 q-pa-sm border-top">
          <q-btn
            flat
            no-caps
            dense
            color="primary"
            icon="ph ph-arrow-square-out"
            label="Open Location Stock View"
            class="q-px-xs"
            @click="goToChildStockPage"
          />
          <q-btn
            v-close-popup
            unelevated
            dense
            no-caps
            label="Close"
            color="grey-8"
            class="q-px-md"
            style="border-radius: 8px"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, onMounted, watch } from 'vue';
import { QChip, QInput, useQuasar } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { showSuccessNotification, showErrorNotification, showWarningNotification } from 'src/utils/appFeedback';
import ShipmentStatusWorkflowBar from '../components/ShipmentStatusWorkflowBar.vue';
import ShipmentSectionsCard from '../components/ShipmentSectionsCard.vue';
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { buildShipmentExcelWorkbook } from '../utils/buildShipmentExcelWorkbook';
import {
  useCargoCompaniesQuery,
  useChildTenantsQuery,
  useShipmentProgressFlowsQuery,
  useShipmentProgressFlowStagesQuery,
} from '../composables/useProcurementStockQuery';

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

const goToReceivePage = () => {
  const tenantSlug = route.params.tenantSlug;
  const sId = shipmentStore.currentShipment?.id || shipmentId;
  if (!sId) return;

  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-receive',
      params: { tenantSlug, id: sId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-receive',
      params: { id: sId },
    });
  }
};

const changeStatus = (newStatus: string) => {
  const current = shipmentStore.currentShipment?.status || dummyStatus.value;
  if (current === newStatus) return;

  if (current === 'cancelled') {
    showWarningNotification('Cancelled shipments cannot change status.');
    return;
  }

  if (newStatus === 'received') {
    goToReceivePage();
    return;
  }

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

// Cargo handling (Cached with TanStack Query - 20m)
const currentTenantId = computed(() => authStore.tenantId);
const { data: cargoData, isLoading: loadingCargo } = useCargoCompaniesQuery(currentTenantId);

const cargoCompanies = computed(() => cargoData.value ?? []);

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

// Shop / Sister Tenant handling (Cached with TanStack Query - 20m)
const { data: childTenantsData, isLoading: loadingChildTenants } = useChildTenantsQuery(currentTenantId);

const childTenants = computed(() => childTenantsData.value ?? []);

const childTenantOptions = computed(() => {
  const current = authStore.selectedTenant;
  const opts: Array<{ label: string; value: number }> = [];
  if (current?.id) {
    opts.push({ label: `${current.name} (Main Warehouse / Self)`, value: current.id });
  }
  for (const t of childTenants.value) {
    if (t.id === current?.id) continue;
    opts.push({ label: t.name, value: t.id });
  }
  return opts;
});

const currentShopLabel = computed(() => {
  const sId = shipmentStore.currentShipment?.assigned_child_tenant_id;
  if (!sId) return 'Select Shop (Unassigned)';
  if (sId === authStore.tenantId) {
    return `Shop: ${authStore.selectedTenant?.name || 'Main Warehouse'} (Self)`;
  }
  const found = childTenants.value.find((t) => t.id === sId);
  return found ? `Shop: ${found.name}` : `Shop #${sId}`;
});

const savingShop = ref(false);
const saveInlineShop = async (val: number | null) => {
  if (!shipmentId) return;
  if (shipmentStore.currentShipment?.status !== 'received') {
    showWarningNotification('Shipment must be received into warehouse stock before assigning to a shop.');
    return;
  }
  savingShop.value = true;
  try {
    if (authStore.tenantId) {
      await shipmentStore.assignShipmentToChild(authStore.tenantId, val, shipmentId);
      showSuccessNotification(val ? 'Shipment assigned to shop' : 'Shop assignment cleared');
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to update shop assignment');
  } finally {
    savingShop.value = false;
  }
};

// Shop Allocation Details Dialog
const showAllocationDialog = ref(false);
const selectedDialogShopId = ref<number | null>(null);

const openAllocationDialog = () => {
  selectedDialogShopId.value = shipmentStore.currentShipment?.assigned_child_tenant_id ?? null;
  showAllocationDialog.value = true;
};

const goToChildStockPage = () => {
  showAllocationDialog.value = false;
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-child-stock',
      params: { tenantSlug },
    });
  } else {
    void router.push({
      name: 'app-procurement-child-stock',
    });
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
const { currentPurchaseCurrencySymbol, currentCostCurrencySymbol, isEditable } = calculations;

const safeNamePart = (value: string) =>
  value.replace(/[^a-z0-9-_]+/gi, '_').replace(/^_+|_+$/g, '');

const downloadExcel = async () => {
  if (!shipmentStore.currentShipment) {
    showWarningNotification('No shipment loaded.');
    return;
  }

  const loading = $q.loading.show({ message: 'Generating Excel...' });

  try {
    const workbook = await buildShipmentExcelWorkbook({
      shipment: shipmentStore.currentShipment,
      items: shipmentStore.currentShipmentItems ?? [],
      totals: calculations.totals.value,
      boxWeightSum: calculations.currentShipmentBoxesTotal.value,
      splitsSummary: calculations.splitsSummary.value,
      purchaseCurrencySymbol: calculations.currentPurchaseCurrencySymbol.value,
      costCurrencySymbol: calculations.currentCostCurrencySymbol.value,
    });

    const buffer = await workbook.xlsx.writeBuffer();
    const blob = new Blob([buffer], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    const fileTitle = safeNamePart(
      shipmentStore.currentShipment.name ?? `shipment_${shipmentStore.currentShipment.id}`,
    );
    anchor.href = url;
    anchor.download = `${fileTitle || `shipment_${shipmentStore.currentShipment.id}`}.xlsx`;
    anchor.click();
    URL.revokeObjectURL(url);
  } catch (error) {
    showErrorNotification(error instanceof Error ? error.message : 'Failed to generate Excel.');
  } finally {
    loading();
  }
};

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

// Step 3: Rates & Adjustments configured & balanced
const step3Completed = computed(() => {
  const entries = shipmentStore.currentCostEntries;
  if (!entries || entries.length === 0) return false;
  const hasProduct = entries.some((e) => e.cost_type === 'product' && (Number(e.amount) || 0) > 0);
  const hasCargo = entries.some((e) => e.cost_type === 'cargo' && (Number(e.amount) || 0) > 0);
  const ratesConfigured = hasProduct && (shipmentStore.currentShipment?.type === 'local' || hasCargo);
  const sum = summaryKPIs.value;
  const invoicesBalanced = (sum?.weight_matched ?? false) || !calculations.hasCargoInvoiceWeight.value;
  return ratesConfigured && invoicesBalanced;
});

// Step 4: Payee Settlement & Receive finalized
const step4Completed = computed(() => {
  return shipmentStore.currentShipment?.status === 'received' || !!shipmentStore.currentShipment?.stock_ready;
});

// Current Active Action Step
const currentStepNumber = computed(() => {
  if (!step1Completed.value) return 1;
  if (!step2Completed.value) return 2;
  if (!step3Completed.value) return 3;
  return 4;
});

const currentStepTitle = computed(() => {
  switch (currentStepNumber.value) {
    case 1:
      return 'Add Line Items';
    case 2:
      return 'Set Item Weights & Prices';
    case 3:
      return 'Rates & Adjust';
    case 4:
      return 'Receive Stock & Finalize';
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
      return 'Step 3: Configure Rates, Weights & Section Invoices';
    case 4:
      return 'Step 4: Receive Goods into Warehouse Stock';
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
      return 'Configure product and cargo rates, distribute cargo weight, and balance section supplier invoices.';
    case 4:
      return 'Rates and invoices are balanced! Open Receive to check in items and add quantities into warehouse inventory.';
    default:
      return 'All items, rates, and inventory movements are in sync.';
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
      return 'indigo-8';
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
      return 'ph ph-warehouse';
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
      return 'Set Rates & Adjust';
    case 4:
      return 'Receive Stock';
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
      goToReceivePage();
      break;
    default:
      goToListPage();
      break;
  }
};

// Progress Flows (Cached for 1 hour via TanStack Query)
const { data: flowsData } = useShipmentProgressFlowsQuery(currentTenantId);
const progressFlowOptions = computed(() =>
  (flowsData.value ?? shipmentStore.progressFlows).filter((flow) => flow.is_active !== false),
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
    progressFlowOptions.value.find((f) => f.is_default)?.id ??
    null
  );
});

const currentFlowName = computed(() => {
  const flow = progressFlowOptions.value.find((f) => f.id === currentProgressFlowId.value);
  return flow ? flow.name : 'Standard Flow';
});

// Progress Flow Stages (Cached for 1 hour via TanStack Query)
const { data: flowStagesData } = useShipmentProgressFlowStagesQuery(currentProgressFlowId);

const activeFlowStages = computed(() => {
  const fId = currentProgressFlowId.value;
  if (!fId) return [];
  if (flowStagesData.value?.length) {
    return flowStagesData.value.filter((s) => s.is_active !== false);
  }
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

const changeFlow = async (flowId: number) => {
  if (!shipmentStore.currentShipment || shipmentStore.currentShipment.progress_flow_id === flowId) return;
  try {
    await shipmentStore.setShipmentFlow(shipmentStore.currentShipment.id, flowId);
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

onMounted(async () => {
  void ensureVendorsLoaded();
  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.fetchShipmentDetails(shipmentId);
    } catch {
      // Keep fallback
    }
  }
});

const startNameEdit = () => {
  originalName.value = shipmentName.value;
  editingName.value = true;
  void nextTick(() => {
    nameEditInputRef.value?.focus();
    nameEditInputRef.value?.select();
  });
};

const cancelNameEdit = () => {
  shipmentName.value = originalName.value;
  editingName.value = false;
};

const commitNameEdit = async () => {
  if (!editingName.value) return;
  const trimmed = shipmentName.value.trim();
  if (!trimmed) {
    shipmentName.value = originalName.value;
    editingName.value = false;
    return;
  }

  const prev = originalName.value;
  editingName.value = false;
  if (trimmed === prev) return;

  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.updateShipment(shipmentId, { name: trimmed });
      originalName.value = trimmed;
      showSuccessNotification('Shipment name updated');
    } catch (err: any) {
      shipmentName.value = prev;
      showErrorNotification(err?.message || 'Failed to update shipment name');
    }
  } else {
    originalName.value = trimmed;
    showSuccessNotification('Shipment name updated');
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
  min-width: 160px;
}

.progress-flow-select :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
  padding: 0 8px;
  font-size: 13px;
  border-radius: 8px;
}

.progress-flow-select :deep(.q-field__native) {
  padding: 0;
  min-height: 32px;
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
