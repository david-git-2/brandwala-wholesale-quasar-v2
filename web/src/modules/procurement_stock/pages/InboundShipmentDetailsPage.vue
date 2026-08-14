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
        <section class="row items-start justify-between q-col-gutter-sm">
          <div class="col">
            <div class="row items-center no-wrap q-gutter-x-xs">
              <q-btn
                flat
                dense
                round
                icon="ph ph-arrow-left"
                color="grey-7"
                aria-label="Back"
                @click="goBack"
              />
              <div class="min-width-0">
                <!-- Inline Edit Name -->
                <div class="text-subtitle1 text-weight-bold row items-center q-gutter-x-xs">
                  <span class="cursor-pointer" :class="{ 'text-primary': isEditable }">
                    {{ shipmentStore.currentShipment.name }}
                  </span>
                  <q-icon
                    v-if="isEditable"
                    name="ph ph-pencil-simple"
                    size="xs"
                    color="grey-6"
                    class="cursor-pointer"
                  />
                  <q-popup-edit
                    v-if="isEditable"
                    v-model="inlineNameInput"
                    v-slot="scope"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="saveInlineName"
                  >
                    <q-input
                      v-model="scope.value"
                      dense
                      autofocus
                      counter
                      @keyup.enter="scope.set"
                    />
                  </q-popup-edit>
                </div>
                <div class="text-caption text-grey-7">
                  Buy, cost, then receive into the warehouse.
                </div>

                <!-- Chips Row for Type, Vendor & Cargo -->
                <div class="row items-center q-gutter-xs q-mt-xs wrap">
                  <span class="text-caption text-grey-7">
                    #{{
                      shipmentStore.currentShipment.tenant_shipment_id ||
                      shipmentStore.currentShipment.id
                    }}
                  </span>
                  <span class="text-grey-5">·</span>

                  <!-- Interactive Type Chip -->
                  <q-chip
                    clickable
                    outline
                    dense
                    size="sm"
                    color="primary"
                    class="cursor-pointer"
                    :disable="!isEditable"
                  >
                    <q-icon name="ph ph-tag" size="xs" class="q-mr-xs" />
                    <span class="text-capitalize">{{ shipmentStore.currentShipment.type }}</span>
                    <q-icon v-if="isEditable" name="ph ph-caret-down" size="xs" class="q-ml-xs" />
                    <q-menu v-if="isEditable" auto-close>
                      <q-list dense style="min-width: 140px">
                        <q-item
                          v-for="opt in typeOptions"
                          :key="opt.value"
                          clickable
                          :active="shipmentStore.currentShipment.type === opt.value"
                          @click="saveInlineType(opt.value)"
                        >
                          <q-item-section>{{ opt.label }}</q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-chip>

                  <!-- Interactive Vendor Chip -->
                  <q-chip
                    clickable
                    outline
                    dense
                    size="sm"
                    color="teal-8"
                    class="cursor-pointer"
                    :disable="!isEditable"
                  >
                    <q-icon name="ph ph-storefront" size="xs" class="q-mr-xs" />
                    <span>{{ currentVendorLabel }}</span>
                    <q-icon v-if="isEditable" name="ph ph-caret-down" size="xs" class="q-ml-xs" />
                    <q-menu v-if="isEditable" @before-show="ensureVendorsLoaded">
                      <div class="q-pa-sm" style="min-width: 220px">
                        <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">Vendor</div>
                        <q-select
                          :model-value="shipmentStore.currentShipment.vendor_id"
                          :options="vendorOptions"
                          dense
                          outlined
                          emit-value
                          map-options
                          :loading="loadingVendors"
                          @update:model-value="saveInlineVendor"
                        />
                      </div>
                    </q-menu>
                  </q-chip>

                  <!-- Interactive Cargo Vendor Chip -->
                  <q-chip
                    clickable
                    outline
                    dense
                    size="sm"
                    color="indigo-8"
                    class="cursor-pointer"
                    :disable="!isEditable"
                  >
                    <q-icon name="ph ph-truck" size="xs" class="q-mr-xs" />
                    <span>{{ currentCargoLabel }}</span>
                    <q-icon v-if="isEditable" name="ph ph-caret-down" size="xs" class="q-ml-xs" />
                    <q-menu v-if="isEditable" @before-show="ensureCargoLoaded">
                      <div class="q-pa-sm" style="min-width: 220px">
                        <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">Cargo Vendor</div>
                        <q-select
                          :model-value="shipmentStore.currentShipment.cargo_company_id"
                          :options="cargoOptions"
                          dense
                          outlined
                          emit-value
                          map-options
                          clearable
                          :loading="loadingCargo"
                          @update:model-value="saveInlineCargo"
                        />
                      </div>
                    </q-menu>
                  </q-chip>

                  <span class="text-grey-5">·</span>
                  <span class="text-caption text-grey-7">
                    {{ shipmentStore.currentShipment.received_date || '—' }}
                  </span>
                  <template v-if="shipmentStore.currentShipment.progress_tag">
                    <span class="text-grey-5">·</span>
                    <span class="text-caption text-grey-7">
                      {{ shipmentStore.currentShipment.progress_tag.name }}
                    </span>
                  </template>
                </div>
              </div>
            </div>
          </div>
          <div class="col-auto row q-gutter-xs items-center">
            <q-btn
              flat
              dense
              no-caps
              size="sm"
              color="primary"
              icon="ph ph-download-simple"
              label="Excel"
              @click="downloadExcel"
            />
            <q-btn
              v-if="isEditable"
              flat
              dense
              no-caps
              size="sm"
              color="negative"
              icon="ph ph-trash"
              label="Delete"
              @click="confirmDeleteShipment"
            />
          </div>
        </section>

        <ShipmentStatusWorkflowBar
          :status="shipmentStore.currentShipment.status"
          :updating="updatingStatus"
          :target-status="targetUpdatingStatus"
          :lock-received="!isSplitsComplete"
          :progress-options="shipmentStore.progressTags"
          :progress-tag-id="shipmentStore.currentShipment.progress_tag_id ?? shipmentStore.currentShipment.progress_tag?.id ?? null"
          :progress-updating="shipmentStore.progressUpdating"
          :progress-target-id="progressTargetId"
          @update-status="changeStatus"
          @update-progress="changeProgress"
        />

        <!-- Next-step banner (only when there is something to do or a lock notice) -->
        <q-banner
          v-if="nextStep"
          dense
          class="bg-primary-soft text-primary rounded-borders"
        >
          <template #avatar>
            <q-icon name="ph ph-arrow-right" color="primary" />
          </template>
          <div class="row items-center justify-between q-gutter-sm wrap full-width">
            <div class="col">
              <div class="text-body2 text-weight-medium text-grey-9">{{ nextStep.message }}</div>
              <div v-if="nextStep.disabled && nextStep.reason" class="text-caption text-grey-7">
                {{ nextStep.reason }}
              </div>
            </div>
            <div class="col-auto row items-center q-gutter-xs">
              <q-chip
                v-if="weightNeedsAttention"
                dense
                square
                color="orange-1"
                text-color="orange-9"
                label="Weight off"
              />
              <q-chip
                v-if="purchaseNeedsAttention"
                dense
                square
                color="orange-1"
                text-color="orange-9"
                label="Purchase off"
              />
              <q-chip
                v-if="receiveNeedsAttention"
                dense
                square
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
                class="q-px-md"
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
        </q-banner>

        <!-- Received-shipment ops: assign, settle, return -->
        <div
          v-if="shipmentStore.currentShipment.status === 'received'"
          class="column q-gutter-y-md"
        >
          <div ref="assignShopCard">
          <q-card flat bordered class="q-pa-md">
            <div class="text-subtitle1 text-weight-bold text-primary q-mb-xs">
              Assign to shop
            </div>
            <div class="text-caption text-grey-7 q-mb-md">
              Choose which shop can sell this stock.
            </div>
            <div class="row q-col-gutter-sm items-end">
              <div class="col-12 col-sm-8">
                <q-select
                  v-model="selectedChildTenantId"
                  :options="childTenantOptions"
                  label="Shop"
                  dense
                  outlined
                  clearable
                  emit-value
                  map-options
                  :loading="childTenantsLoading"
                />
              </div>
              <div class="col-12 col-sm-4 row q-gutter-sm">
                <q-btn
                  color="primary"
                  unelevated
                  no-caps
                  dense
                  label="Save"
                  class="col"
                  :loading="assigningChild"
                  @click="saveAssignChild"
                />
                <q-btn
                  flat
                  no-caps
                  dense
                  label="Clear"
                  class="col"
                  :disable="!shipmentStore.currentShipment.assigned_child_tenant_id"
                  :loading="assigningChild"
                  @click="clearAssignChild"
                />
              </div>
            </div>
          </q-card>
          </div>

          <div ref="paySettleCard">
          <q-card flat bordered class="q-pa-md">
            <div class="text-subtitle1 text-weight-bold text-primary q-mb-xs">
              Pay
            </div>
            <div class="text-caption text-grey-7 q-mb-md">
              Pay the vendor or cargo company for these costs.
            </div>
            <q-table
              v-if="settleableEntries.length"
              flat
              dense
              :rows="settleableEntries"
              :columns="settleEntryColumns"
              row-key="id"
              hide-pagination
              :rows-per-page-options="[0]"
            >
              <template #body-cell-cost_type="props">
                <q-td :props="props">
                  <span class="text-capitalize">{{ props.row.cost_type }}</span>
                </q-td>
              </template>
              <template #body-cell-amount="props">
                <q-td :props="props" class="text-right">
                  ৳{{ Number(props.row.amount).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
                </q-td>
              </template>
            </q-table>
            <div v-else class="text-body2 text-grey-7 q-mb-md">
              Add who to pay on the Landed cost tab first.
            </div>
            <span>
              <q-btn
                color="secondary"
                unelevated
                no-caps
                icon="ph ph-wallet"
                label="Pay all"
                :disable="!settleableEntries.length"
                :loading="paySettling"
                @click="confirmPaySettleAll"
              />
              <q-tooltip v-if="!settleableEntries.length">
                Add who to pay on the Landed cost tab first.
              </q-tooltip>
            </span>
          </q-card>
          </div>

          <q-card flat bordered class="q-pa-md">
            <div class="text-subtitle1 text-weight-bold text-primary q-mb-xs">
              Vendor return
            </div>
            <div class="text-caption text-grey-7 q-mb-md">
              Send goods back to the vendor.
            </div>
            <div class="row q-col-gutter-sm q-mb-md">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="returnOutcome"
                  :options="returnOutcomeOptions"
                  label="Return outcome"
                  dense
                  outlined
                  emit-value
                  map-options
                />
              </div>
            </div>
            <q-table
              flat
              dense
              :rows="returnLines"
              :columns="returnLineColumns"
              row-key="shipment_item_id"
              hide-pagination
              :rows-per-page-options="[0]"
            >
              <template #body-cell-return_qty="props">
                <q-td :props="props">
                  <q-input
                    v-model.number="props.row.return_qty"
                    type="number"
                    dense
                    outlined
                    min="0"
                    :max="props.row.max_qty"
                    style="max-width: 100px"
                  />
                </q-td>
              </template>
            </q-table>
            <q-btn
              color="negative"
              unelevated
              no-caps
              class="q-mt-md"
              icon="ph ph-arrow-u-up-left"
              label="Submit return"
              :disable="!hasReturnQty"
              :loading="returnSubmitting"
              @click="confirmVendorReturn"
            />
          </q-card>
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
              <q-tab name="balance" data-test="tab-balance">
                <div class="row items-center no-wrap q-gutter-xs">
                  <span>Match invoices</span>
                  <q-badge v-if="balanceNeedsAttention" color="orange" rounded label="!" />
                </div>
              </q-tab>
              <q-tab name="cost" label="Landed cost" data-test="tab-cost" />
              <q-tab v-if="showReceiveTab" name="receive" data-test="tab-receive">
                <div class="row items-center no-wrap q-gutter-xs">
                  <span>Add to stock</span>
                  <q-badge v-if="receiveNeedsAttention" color="orange" rounded label="!" />
                </div>
              </q-tab>
            </q-tabs>

            <div v-if="activeTab === 'lines'" class="col-auto row items-center q-gutter-xs">
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

          <q-tab-panels v-model="activeTab" animated class="bg-transparent q-pt-sm">
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
                <ShipmentLineItemsTable
                  v-else
                  :items="shipmentStore.currentShipmentItems"
                  :shipment="shipmentForLiveCosting"
                  :loading="shipmentStore.loading"
                  :visible-columns="visibleColumns"
                  :purchase-currency-symbol="currentPurchaseCurrencySymbol"
                  :cost-currency-symbol="currentCostCurrencySymbol"
                  @edit-details="openEditItem"
                  @delete="confirmDeleteItem"
                />
              </q-card>
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

            <!-- Landed cost -->
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

                <q-card flat bordered class="q-pa-md bg-white text-grey-9">
                <div class="row items-center justify-between q-mb-md">
                  <div class="text-subtitle1 text-weight-bold text-primary">Landed Cost Summary</div>
                </div>

                <div class="q-mb-md">
                  <div
                    class="text-xs text-weight-bold text-grey-6 uppercase q-mb-xs"
                    style="font-size: 11px; letter-spacing: 0.5px"
                  >
                    Shipment Totals
                  </div>
                  <div class="row justify-between q-py-xs">
                    <span class="text-caption text-grey-7">Total Quantity:</span>
                    <span class="text-subtitle2 text-weight-bold">{{ totals.quantity }} pcs</span>
                  </div>
                  <div class="row justify-between q-py-xs">
                    <span class="text-caption text-grey-7">Packaging Weight:</span>
                    <span class="text-subtitle2 text-weight-bold"
                      >{{ totals.packagingWeightKg.toFixed(2) }} kg</span
                    >
                  </div>
                  <div class="row justify-between q-py-xs" v-if="hasCargoInvoiceWeight">
                    <span class="text-caption text-grey-7">Invoice Weight:</span>
                    <span class="text-subtitle2 text-weight-bold text-primary"
                      >{{ totals.cargoWeightKg.toFixed(2) }} kg</span
                    >
                  </div>
                  <div class="row justify-between q-py-xs">
                    <span class="text-caption text-grey-7">Box Weight Sum:</span>
                    <span class="text-subtitle2 text-weight-bold"
                      >{{ currentShipmentBoxesTotal.toFixed(2) }} kg</span
                    >
                  </div>
                </div>

                <q-separator class="q-my-sm" />

                <div class="q-mb-md">
                  <div
                    class="text-xs text-weight-bold text-grey-6 uppercase q-mb-xs"
                    style="font-size: 11px; letter-spacing: 0.5px"
                  >
                    Purchase Currency ({{ currentPurchaseCurrencySymbol }})
                  </div>
                  <div class="row justify-between q-py-xs">
                    <span class="text-caption text-grey-7">Product Purchase Cost:</span>
                    <span class="text-subtitle2 text-weight-bold">
                      {{ currentPurchaseCurrencySymbol
                      }}{{
                        totals.goodsPurchase.toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })
                      }}
                    </span>
                  </div>
                  <div
                    class="row justify-between q-py-xs"
                    v-if="totals.cargoPurchase > 0"
                  >
                    <span class="text-caption text-grey-7">Cargo Cost:</span>
                    <div class="text-right">
                      <div class="text-subtitle2 text-weight-bold">
                        {{ currentPurchaseCurrencySymbol
                        }}{{
                          totals.cargoPurchase.toLocaleString(undefined, {
                            minimumFractionDigits: 2,
                            maximumFractionDigits: 2,
                          })
                        }}
                      </div>
                      <div class="text-caption text-grey-5" style="font-size: 10px">
                        {{ cargoCostWeightLabel }}
                      </div>
                    </div>
                  </div>
                  <div class="row justify-between q-py-xs bg-grey-1 q-px-sm rounded-borders">
                    <span class="text-caption text-weight-medium text-grey-8"
                      >Total Purchase Cost:</span
                    >
                    <span class="text-subtitle2 text-weight-bold text-primary">
                      {{ currentPurchaseCurrencySymbol
                      }}{{
                        totals.totalPurchase.toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })
                      }}
                    </span>
                  </div>
                </div>

                <template v-if="shipmentStore.currentShipment?.type === 'international'">
                  <q-separator class="q-my-sm" />
                  <div class="q-mb-md">
                    <div
                      class="text-xs text-weight-bold text-grey-6 uppercase q-mb-xs"
                      style="font-size: 11px; letter-spacing: 0.5px"
                    >
                      Cost Currency ({{ currentCostCurrencySymbol }})
                    </div>
                    <div class="row justify-between q-py-xs">
                      <span class="text-caption text-grey-7">Product Cost:</span>
                      <span class="text-subtitle2 text-weight-bold">
                        {{ currentCostCurrencySymbol
                        }}{{
                          totals.goodsCost.toLocaleString(undefined, {
                            minimumFractionDigits: 2,
                            maximumFractionDigits: 2,
                          })
                        }}
                      </span>
                    </div>
                    <div
                      class="row justify-between q-py-xs"
                      v-if="totals.cargoPurchase > 0"
                    >
                      <span class="text-caption text-grey-7">Cargo Cost:</span>
                      <span class="text-subtitle2 text-weight-bold">
                        {{ currentCostCurrencySymbol
                        }}{{
                          totals.cargoCost.toLocaleString(undefined, {
                            minimumFractionDigits: 2,
                            maximumFractionDigits: 2,
                          })
                        }}
                      </span>
                    </div>
                    <div
                      class="row justify-between items-center q-py-sm bg-primary text-white q-px-sm rounded-borders"
                    >
                      <span class="text-subtitle2 text-weight-bold">Total Cost:</span>
                      <span class="text-h6 text-weight-bolder">
                        {{ currentCostCurrencySymbol
                        }}{{
                          totals.totalCost.toLocaleString(undefined, {
                            minimumFractionDigits: 2,
                            maximumFractionDigits: 2,
                          })
                        }}
                      </span>
                    </div>
                  </div>

                  <div class="bg-blue-1 text-blue-10 q-pa-sm rounded-borders text-center">
                    <div
                      class="text-caption text-weight-medium uppercase"
                      style="font-size: 10px; letter-spacing: 0.5px"
                    >
                      Live Blended Transaction Rate
                    </div>
                    <div class="text-h5 text-weight-bolder q-my-xs">
                      {{
                        totals.transactionRate !== null
                          ? `${currentCostCurrencySymbol}${totals.transactionRate.toFixed(4)}`
                          : '-'
                      }}
                    </div>
                    <div class="text-caption text-blue-8" style="font-size: 10px; line-height: 1.2">
                      {{ transactionRateWeightLabel }}
                    </div>
                  </div>
                </template>
              </q-card>
              </div>
            </q-tab-panel>

            <!-- Add to stock -->
            <q-tab-panel v-if="showReceiveTab" name="receive" class="q-pa-none">
              <q-card
                v-if="shipmentStore.currentShipment?.status === 'in_transit'"
                flat
                bordered
                class="q-pa-md bg-white text-grey-9 q-mb-md"
              >
                <div class="text-subtitle1 text-weight-bold text-primary q-mb-sm">Checklist</div>
                <div class="text-caption text-grey-7 q-mb-md">
                  Complete each step before adding this shipment to stock.
                </div>
                <q-list dense separator>
                  <q-item clickable @click="activeTab = 'lines'">
                    <q-item-section avatar>
                      <q-icon
                        :name="hasLineItems ? 'ph ph-check-circle' : 'ph ph-circle'"
                        :color="hasLineItems ? 'positive' : 'grey-5'"
                      />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label>Items added</q-item-label>
                      <q-item-label caption>{{
                        hasLineItems
                          ? `${shipmentStore.currentShipmentItems.length} products`
                          : 'Add products on the Items tab'
                      }}</q-item-label>
                    </q-item-section>
                  </q-item>
                  <q-item clickable @click="activeTab = 'balance'">
                    <q-item-section avatar>
                      <q-icon
                        :name="
                          !hasCargoInvoiceWeight || !weightNeedsAttention
                            ? 'ph ph-check-circle'
                            : 'ph ph-circle'
                        "
                        :color="
                          !hasCargoInvoiceWeight || !weightNeedsAttention ? 'positive' : 'grey-5'
                        "
                      />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label>Weight matched</q-item-label>
                      <q-item-label caption>{{
                        !hasCargoInvoiceWeight
                          ? 'No cargo invoice weight set (optional skip)'
                          : weightNeedsAttention
                            ? 'Invoice weight still differs from line weights'
                            : 'Line weights match cargo invoice'
                      }}</q-item-label>
                    </q-item-section>
                  </q-item>
                  <q-item clickable @click="activeTab = 'balance'">
                    <q-item-section avatar>
                      <q-icon
                        :name="
                          !purchaseNeedsAttention ? 'ph ph-check-circle' : 'ph ph-circle'
                        "
                        :color="!purchaseNeedsAttention ? 'positive' : 'grey-5'"
                      />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label>Purchase matched</q-item-label>
                      <q-item-label caption>{{
                        !(sumProductEntryAmount(shipmentStore.currentCostEntries) > 0)
                          ? 'No product cost entry amount set (optional skip)'
                          : purchaseNeedsAttention
                            ? 'Paid invoice still differs from line purchases'
                            : 'Line purchases match paid invoice'
                      }}</q-item-label>
                    </q-item-section>
                  </q-item>
                  <q-item clickable @click="activeTab = 'lines'">
                    <q-item-section avatar>
                      <q-icon
                        :name="isSplitsComplete ? 'ph ph-check-circle' : 'ph ph-circle'"
                        :color="isSplitsComplete ? 'positive' : 'orange'"
                      />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label>Splits complete</q-item-label>
                      <q-item-label caption>{{
                        isSplitsComplete
                          ? `${splitsSummary.totalAllocated} / ${splitsSummary.totalOrdered} pcs allocated`
                          : 'Configure quantity splits on the Items tab'
                      }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-card>

              <q-card
                v-if="shipmentStore.currentShipment?.status === 'in_transit'"
                flat
                bordered
                class="q-pa-md bg-white text-grey-9 q-mb-md"
              >
                <div class="row items-center justify-between q-mb-md">
                  <div class="text-subtitle1 text-weight-bold text-primary">
                    Quantity Splits Summary
                  </div>
                  <q-chip
                    dense
                    square
                    :color="splitsSummary.isComplete ? 'green-1' : 'orange-1'"
                    :text-color="splitsSummary.isComplete ? 'green-9' : 'orange-9'"
                    class="text-weight-bold"
                  >
                    {{ splitsSummary.isComplete ? 'Complete' : 'Pending Splits' }}
                  </q-chip>
                </div>

                <div class="q-gutter-y-sm">
                  <div
                    v-for="item in splitsSummary.breakdown"
                    :key="item.id"
                    class="row justify-between items-center q-py-xs"
                    style="border-bottom: 1px dashed rgba(0, 0, 0, 0.08)"
                  >
                    <div class="column">
                      <span class="text-subtitle2 text-weight-bold" style="line-height: 1.2">{{
                        item.description
                      }}</span>
                      <span class="text-caption text-grey-6" style="font-size: 11px">
                        {{ item.is_sellable ? 'Sellable Pool' : 'Non-Sellable Pool' }}
                      </span>
                    </div>
                    <div class="text-subtitle2 text-weight-bold text-primary">
                      {{ item.quantity }} pcs
                    </div>
                  </div>

                  <div
                    v-if="splitsSummary.breakdown.length === 0"
                    class="text-center text-grey-6 q-py-md"
                  >
                    No splits yet. Split items on the Items tab first.
                  </div>

                  <q-separator class="q-my-sm" />

                  <div
                    class="row justify-between items-center q-py-sm bg-grey-1 q-px-sm rounded-borders"
                  >
                    <span class="text-caption text-weight-medium text-grey-8">Total Allocated:</span>
                    <span class="text-subtitle2 text-weight-bolder text-primary">
                      {{ splitsSummary.totalAllocated }} / {{ splitsSummary.totalOrdered }} pcs
                    </span>
                  </div>
                </div>

                <q-btn
                  :color="isSplitsComplete ? 'green-7' : 'grey-5'"
                  :disable="!isSplitsComplete"
                  unelevated
                  class="full-width q-mt-md text-weight-bold text-white"
                  icon="ph ph-check-circle"
                  label="Add to stock"
                  no-caps
                  @click="changeStatus('received')"
                >
                  <q-tooltip v-if="!isSplitsComplete">
                    Split every item first
                  </q-tooltip>
                </q-btn>
              </q-card>

              <q-card
                v-if="shipmentStore.currentShipment?.status === 'received'"
                flat
                bordered
                class="q-pa-md"
              >
                <div class="text-subtitle1 text-weight-bold text-primary q-mb-sm">In stock</div>
                <div class="text-body2 text-grey-7 q-mb-md">
                  Stock already posted — editing is locked. Use Rollback only if you need to undo.
                </div>
                <q-btn
                  color="negative"
                  unelevated
                  class="full-width text-weight-bold text-white"
                  icon="ph ph-clock-counter-clockwise"
                  label="Rollback shipment to Draft"
                  no-caps
                  :loading="updatingStatus"
                  @click="rollbackShipmentToDraft"
                />
              </q-card>
            </q-tab-panel>
          </q-tab-panels>
        </div>

      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar, type QTableColumn } from 'quasar';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { globalShipmentRepository } from '../repositories/globalShipmentRepository';
import { tenantRepository } from 'src/modules/tenant/repositories/tenantRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import { STOCK_AVAILABILITY_OPTIONS } from '../constants/stockAvailability';
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';
import type { GlobalShipmentCostEntry } from '../types/shipmentCostEntry';
import ShipmentItemFormDialog from '../components/ShipmentItemFormDialog.vue';
import AddShipmentItemsDrawer from '../components/AddShipmentItemsDrawer.vue';
import BulkPasteDialog from '../components/BulkPasteDialog.vue';
import ShipmentLineItemsTable, { type ColumnKey } from '../components/ShipmentLineItemsTable.vue';
import ShipmentWeightBalanceCard from '../components/ShipmentWeightBalanceCard.vue';
import ShipmentPurchaseBalanceCard from '../components/ShipmentPurchaseBalanceCard.vue';
import ShipmentStatusWorkflowBar from '../components/ShipmentStatusWorkflowBar.vue';
import ShipmentCostEntriesPanel from '../components/ShipmentCostEntriesPanel.vue';
import ReceiveShipmentDialog from '../components/ReceiveShipmentDialog.vue';
import { calculateShipmentCostSummary, costingShipmentFromEntries } from 'src/shared/shipment-engine';
import {
  isShipmentCostFinalized,
  sumProductEntryAmount,
} from '../utils/costEntriesCosting';
import type { CostEntriesSavePayload } from '../types/shipmentCostEntry';
import { buildShipmentExcelWorkbook } from '../utils/buildShipmentExcelWorkbook';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import type { GlobalCurrency } from 'src/modules/global_reference/types';
import {
  showSuccessNotification,
  showErrorNotification,
  showWarningNotification,
  requestConfirmation,
} from 'src/utils/appFeedback';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();
const vendorStore = useVendorStore();
const shipmentStore = useGlobalShipmentStore();

const inlineNameInput = ref('');
watch(
  () => shipmentStore.currentShipment?.name,
  (val) => {
    if (val) inlineNameInput.value = val;
  },
  { immediate: true },
);

const saveInlineName = async (val: string) => {
  if (!shipmentId || !val || !val.trim()) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { name: val.trim() });
    showSuccessNotification('Shipment name updated');
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to update shipment name');
  }
};

const typeOptions = [
  { label: 'International', value: 'international' as const },
  { label: 'Local', value: 'local' as const },
  { label: 'Transfer', value: 'transfer' as const },
];

const saveInlineType = async (typeVal: 'international' | 'local' | 'transfer') => {
  if (!shipmentId) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { type: typeVal });
    showSuccessNotification('Shipment type updated');
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to update shipment type');
  }
};

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

const loadingCargo = ref(false);
const cargoCompanies = ref<Array<{ id: number; name: string; code: string }>>([]);
const ensureCargoLoaded = async () => {
  if (authStore.tenantId && cargoCompanies.value.length === 0) {
    loadingCargo.value = true;
    try {
      cargoCompanies.value = await globalShipmentRepository.listCargoCompaniesForTenant(authStore.tenantId);
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
  if (!cId) return 'Cargo: None';
  const found = cargoCompanies.value.find((c) => c.id === cId);
  return found ? `Cargo: ${found.name}` : `Cargo #${cId}`;
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

onMounted(() => {
  ensureVendorsLoaded();
  ensureCargoLoaded();
});

const parentTenantId = computed(() => authStore.tenantId);
const { data: childTenants, isLoading: childTenantsLoading } = useQuery({
  queryKey: computed(() => procurementStockQueryKeys.childTenants(parentTenantId.value ?? 0)),
  queryFn: async () => {
    const tenants = await tenantRepository.listTenants();
    return tenants.filter((t) => t.parent_id === parentTenantId.value);
  },
  staleTime: 5 * 60 * 1000,
  enabled: computed(() => !!parentTenantId.value),
});
const childTenantOptions = computed(() =>
  (childTenants.value ?? []).map((t) => ({ label: t.name, value: t.id })),
);
const selectedChildTenantId = ref<number | null>(null);
const assigningChild = ref(false);
const paySettling = ref(false);
const returnSubmitting = ref(false);
const returnOutcome = ref<'cash_refund' | 'store_credit'>('store_credit');

interface ReturnLineDraft {
  shipment_item_id: number;
  name: string;
  max_qty: number;
  return_qty: number;
}

const returnLines = ref<ReturnLineDraft[]>([]);

const returnOutcomeOptions = [
  { label: 'Store credit (vendor wallet)', value: 'store_credit' as const },
  { label: 'Cash refund (tenant cash)', value: 'cash_refund' as const },
];

const settleEntryColumns: QTableColumn<GlobalShipmentCostEntry>[] = [
  { name: 'cost_type', label: 'Type', field: 'cost_type', align: 'left' },
  { name: 'amount', label: 'Amount (BDT)', field: 'amount', align: 'right' },
  { name: 'payment_source', label: 'Source', field: 'payment_source', align: 'left' },
  { name: 'entity_type', label: 'Payee', field: 'entity_type', align: 'left' },
];

const returnLineColumns: QTableColumn<ReturnLineDraft>[] = [
  { name: 'name', label: 'Product', field: 'name', align: 'left' },
  { name: 'max_qty', label: 'Ordered', field: 'max_qty', align: 'right' },
  { name: 'return_qty', label: 'Return qty', field: 'return_qty', align: 'right' },
];

watch(
  () => shipmentStore.currentShipment?.assigned_child_tenant_id,
  (id) => {
    selectedChildTenantId.value = id ?? null;
  },
  { immediate: true },
);

watch(
  () => shipmentStore.currentShipmentItems,
  (items) => {
    returnLines.value = (items ?? []).map((item) => ({
      shipment_item_id: item.id,
      name: item.name,
      max_qty: item.ordered_quantity ?? 0,
      return_qty: 0,
    }));
  },
  { immediate: true },
);

const settleableEntries = computed(() =>
  shipmentStore.currentCostEntries.filter(
    (e) =>
      e.payment_source &&
      e.entity_type &&
      (e.entity_type === 'vendor' || e.entity_type === 'cargo_company'),
  ),
);

const hasReturnQty = computed(() => returnLines.value.some((l) => l.return_qty > 0));

const saveAssignChild = async () => {
  if (!authStore.tenantId) return;
  assigningChild.value = true;
  try {
    await shipmentStore.assignShipmentToChild(
      authStore.tenantId,
      selectedChildTenantId.value,
      shipmentId,
    );
    showSuccessNotification('Shop assignment updated');
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to update assignment');
  } finally {
    assigningChild.value = false;
  }
};

const clearAssignChild = async () => {
  selectedChildTenantId.value = null;
  await saveAssignChild();
};

const confirmPaySettleAll = async () => {
  const ok = await requestConfirmation(
    `Pay ${settleableEntries.value.length} cost${settleableEntries.value.length === 1 ? '' : 's'} to the vendor or cargo company?`,
    'Pay costs',
    'Pay',
  );
  if (!ok) return;

  paySettling.value = true;
  try {
    const res = await shipmentStore.paySettleShipmentCosts(shipmentId);
    showSuccessNotification(
      res.wallet_posted
        ? `Settled ${res.settled_entries_count} entries — wallet posted.`
        : `Processed ${res.settled_entries_count} entries.`,
    );
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Settlement failed');
  } finally {
    paySettling.value = false;
  }
};

const confirmVendorReturn = async () => {
  const items = returnLines.value
    .filter((l) => l.return_qty > 0)
    .map((l) => ({ shipment_item_id: l.shipment_item_id, quantity: l.return_qty }));

  const ok = await requestConfirmation(
    `Return ${items.reduce((s, i) => s + i.quantity, 0)} pcs with ${returnOutcome.value === 'store_credit' ? 'store credit' : 'cash refund'}?`,
    'Submit vendor return',
    'Submit return',
  );
  if (!ok) return;

  returnSubmitting.value = true;
  try {
    await shipmentStore.returnShipmentToVendor(shipmentId, items, returnOutcome.value);
    showSuccessNotification('Vendor return submitted');
    returnLines.value = returnLines.value.map((l) => ({ ...l, return_qty: 0 }));
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Vendor return failed');
  } finally {
    returnSubmitting.value = false;
  }
};

const shipmentId = Number(route.params.id);
const updatingStatus = ref(false);
const targetUpdatingStatus = ref<string | null>(null);
const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('lines');
const weightBalanceCardEl = ref<HTMLElement | null>(null);
const purchaseBalanceCardEl = ref<HTMLElement | null>(null);
const assignShopCard = ref<HTMLElement | null>(null);
const paySettleCard = ref<HTMLElement | null>(null);

const scrollToBalanceCard = (which: 'weight' | 'purchase') => {
  const el = which === 'weight' ? weightBalanceCardEl.value : purchaseBalanceCardEl.value;
  el?.scrollIntoView({ behavior: 'smooth', block: 'start' });
};

const isSplitsComplete = computed(() => {
  const items = shipmentStore.currentShipmentItems;
  const stocks = shipmentStore.currentShipmentStocks || [];
  if (!items.length) return false;
  return items.every((item) => {
    const itemStocks = stocks.filter((s) => s.shipment_item_id === item.id);
    const sum = itemStocks.reduce((acc, s) => acc + (s.quantity || 0), 0);
    return sum === item.ordered_quantity;
  });
});

const splitsSummary = computed(() => {
  const stocks = shipmentStore.currentShipmentStocks || [];

  const breakdown = STOCK_AVAILABILITY_OPTIONS.map((opt) => {
    const totalQty = stocks
      .filter((s) => (s.availability || 'sellable') === opt.value)
      .reduce((sum, s) => sum + (s.quantity || 0), 0);
    return {
      id: opt.value,
      description: opt.label,
      is_sellable: opt.value === 'sellable',
      quantity: totalQty,
    };
  });

  const totalAllocated = breakdown.reduce((sum, item) => sum + item.quantity, 0);
  const totalOrdered = shipmentStore.currentShipmentItems.reduce(
    (sum, item) => sum + (item.ordered_quantity || 0),
    0,
  );

  return {
    breakdown: breakdown.filter((item) => item.quantity > 0),
    totalAllocated,
    totalOrdered,
    isComplete: totalAllocated === totalOrdered && totalOrdered > 0,
  };
});

const baseColumnOptions = [
  { label: 'Name', value: 'name' as ColumnKey },
  { label: 'Product ID', value: 'product_id' as ColumnKey },
  { label: 'Barcode', value: 'barcode' as ColumnKey },
  { label: 'Product Code', value: 'product_code' as ColumnKey },
  { label: 'Method', value: 'add_method' as ColumnKey },
  { label: 'Price GBP', value: 'purchase_price' as ColumnKey },
  { label: 'Cost BDT', value: 'cost_bdt' as ColumnKey },
  { label: 'Quantity', value: 'ordered_quantity' as ColumnKey },
  { label: 'Product Wt', value: 'product_weight' as ColumnKey },
  { label: 'Package Wt', value: 'package_weight' as ColumnKey },
  { label: 'Actions', value: 'actions' as ColumnKey },
];

const availableColumnOptions = computed(() => {
  const isIntl = shipmentStore.currentShipment?.type === 'international';
  return baseColumnOptions
    .filter((col) => {
      if (!isIntl) {
        return !['purchase_price', 'product_weight', 'package_weight'].includes(col.value);
      }
      return true;
    })
    .map((col) => {
      if (col.value === 'purchase_price') {
        return { ...col, label: `Price ${currentPurchaseCurrencySymbol.value}` };
      }
      if (col.value === 'cost_bdt') {
        return { ...col, label: `Cost ${currentCostCurrencySymbol.value}` };
      }
      return col;
    });
});

const currentShipmentBoxesTotal = computed(() => {
  return shipmentStore.currentShipmentBoxes.reduce((sum, box) => sum + (box.weight_kg || 0), 0);
});

const shipmentCargoWeightKg = computed(
  () =>
    shipmentStore.currentShipment?.total_weight_kg ??
    shipmentStore.currentShipment?.received_weight ??
    null,
);

const hasCargoInvoiceWeight = computed(() => {
  const rw = shipmentCargoWeightKg.value;
  return rw != null && rw > 0;
});

const progressTargetId = ref<number | null>(null);

const defaultColumns: ColumnKey[] = [
  'name',
  'product_id',
  'barcode',
  'product_code',
  'add_method',
  'purchase_price',
  'cost_bdt',
  'ordered_quantity',
  'product_weight',
  'package_weight',
  'actions',
];

const allColumnNames = baseColumnOptions.map((col) => col.value);
const alwaysVisibleColumns: ColumnKey[] = ['name', 'actions'];

const { visibleColumns } = useMembershipColumnPreference<ColumnKey>({
  preferenceKey: 'ui.procurementShipment.detailsVisibleColumns',
  allColumnNames,
  alwaysVisibleColumns,
  defaultVisibleColumns: defaultColumns,
});

const allColumnsSelected = computed({
  get: () => availableColumnOptions.value.every((col) => visibleColumns.value.includes(col.value)),
  set: (val) => {
    visibleColumns.value = val
      ? availableColumnOptions.value.map((col) => col.value)
      : ['name', 'actions'];
  },
});

const totals = computed(() => {
  const shipment = shipmentStore.currentShipment;
  const items = shipmentStore.currentShipmentItems;
  if (!shipment) {
    return {
      quantity: 0,
      packagingWeightKg: 0,
      cargoWeightKg: 0,
      goodsPurchase: 0,
      cargoPurchase: 0,
      totalPurchase: 0,
      goodsCost: 0,
      cargoCost: 0,
      totalCost: 0,
      transactionRate: null,
      lineLandedCostTotal: 0,
    };
  }
  const forCosting = costingShipmentFromEntries(
    shipment,
    shipmentStore.currentCostEntries,
    items,
  );
  return calculateShipmentCostSummary(forCosting, items);
});

const cargoCostWeightLabel = computed(() => {
  if (hasCargoInvoiceWeight.value) {
    return `Based on ${totals.value.cargoWeightKg.toFixed(2)} kg cargo invoice weight`;
  }
  return `Based on ${totals.value.packagingWeightKg.toFixed(2)} kg estimated packaging weight`;
});

const transactionRateWeightLabel = computed(() => {
  if (totals.value.transactionRate === null) {
    return 'Add line items with prices to calculate';
  }
  if (hasCargoInvoiceWeight.value) {
    return `Based on ${totals.value.cargoWeightKg.toFixed(2)} kg cargo invoice weight · used for per-unit cost conversion`;
  }
  return 'Based on estimated packaging weight · used for per-unit cost conversion';
});

const shipmentForLiveCosting = computed(() => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return null;
  const fromEntries = costingShipmentFromEntries(
    shipment,
    shipmentStore.currentCostEntries,
    shipmentStore.currentShipmentItems,
  );
  return {
    ...shipment,
    ...fromEntries,
  };
});

const isEditable = computed(() => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return false;
  // §5.1.1 / workflow Stage 2: editable through in_transit; lock after received/cancelled
  return shipment.status !== 'received' && shipment.status !== 'cancelled';
});

/** Cost entries: editable pre-finalize; post-finalize uses revision RPC (Stage 4). */
const isCostFinalized = computed(() => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return false;
  return isShipmentCostFinalized(shipment);
});

const canEditCosts = computed(() => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return false;
  if (shipment.status === 'cancelled') return false;
  // Lines lock after received, but Stage 4 still allows cost revision when stock_ready
  return isEditable.value || isCostFinalized.value;
});

const hasLineItems = computed(() => (shipmentStore.currentShipmentItems?.length ?? 0) > 0);

const weightNeedsAttention = computed(() => {
  if (!hasCargoInvoiceWeight.value) return false;
  return Math.abs(totals.value.packagingWeightKg - totals.value.cargoWeightKg) > 0.01;
});

const purchaseNeedsAttention = computed(() => {
  const invoice = sumProductEntryAmount(shipmentStore.currentCostEntries);
  if (invoice <= 0) return false;
  return Math.abs(invoice - totals.value.goodsPurchase) > 0.05;
});

const hasProductInvoiceTotal = computed(
  () => sumProductEntryAmount(shipmentStore.currentCostEntries) > 0,
);

const balanceNeedsAttention = computed(
  () => weightNeedsAttention.value || purchaseNeedsAttention.value,
);

const showReceiveTab = computed(() => {
  const status = shipmentStore.currentShipment?.status;
  return status === 'in_transit' || status === 'received';
});

const receiveNeedsAttention = computed(() => {
  return (
    shipmentStore.currentShipment?.status === 'in_transit' && !isSplitsComplete.value
  );
});

const nextStep = computed(() => {
  const status = shipmentStore.currentShipment?.status;
  if (status === 'cancelled') {
    return {
      message: 'This shipment was cancelled.',
      label: null as string | null,
      disabled: true,
      reason: 'This shipment was cancelled.',
      action: null as (() => void) | null,
    };
  }
  if (status === 'received') {
    const assigned = shipmentStore.currentShipment?.assigned_child_tenant_id;
    if (!assigned && childTenantOptions.value.length > 0) {
      return {
        message: 'Assign to a shop so they can sell it.',
        label: 'Assign',
        disabled: false,
        reason: '',
        action: () => assignShopCard.value?.scrollIntoView({ behavior: 'smooth', block: 'start' }),
      };
    }
    if (settleableEntries.value.length > 0) {
      return {
        message: 'Pay the vendor or cargo company.',
        label: 'Pay',
        disabled: false,
        reason: '',
        action: () => paySettleCard.value?.scrollIntoView({ behavior: 'smooth', block: 'start' }),
      };
    }
    return {
      message: 'Goods are in the warehouse. Assign, pay, or return below if needed.',
      label: null,
      disabled: true,
      reason: '',
      action: null,
    };
  }
  if (!hasLineItems.value) {
    return {
      message: 'Add products, then continue.',
      label: 'Add items',
      disabled: false,
      reason: '',
      action: () => {
        activeTab.value = 'lines';
        openAddItems();
      },
    };
  }
  if (balanceNeedsAttention.value) {
    const both = weightNeedsAttention.value && purchaseNeedsAttention.value;
    return {
      message: 'Cargo weight or purchase total does not match.',
      label: both ? 'Fix balances' : weightNeedsAttention.value ? 'Fix weight' : 'Fix purchase',
      disabled: false,
      reason: '',
      action: () => {
        activeTab.value = 'balance';
      },
    };
  }
  if (status === 'in_transit') {
    if (!isSplitsComplete.value) {
      return {
        message: 'Split each line before receiving.',
        label: 'Configure splits',
        disabled: false,
        reason: '',
        action: () => {
          activeTab.value = 'lines';
        },
      };
    }
    return {
      message: 'Receive into the warehouse.',
      label: 'Add to stock',
      disabled: false,
      reason: '',
      action: () => {
        activeTab.value = 'receive';
        changeStatus('received');
      },
    };
  }
  return {
    message: 'Mark In transit when the goods have left the vendor.',
    label: 'In transit',
    disabled: false,
    reason: '',
    action: () => {
      changeStatus('in_transit');
    },
  };
});

const runPrimaryCta = () => {
  nextStep.value?.action?.();
};

const currenciesList = ref<GlobalCurrency[]>([]);
const loadingCurrencies = ref(false);

const loadCurrencies = async () => {
  loadingCurrencies.value = true;
  try {
    currenciesList.value = await globalReferenceRepository.listCurrencies();
  } catch (err) {
    console.error('Failed to load currencies', err);
  } finally {
    loadingCurrencies.value = false;
  }
};

const currentPurchaseCurrency = computed(() => {
  const currencyId = shipmentStore.currentShipment?.shipment_purchase_currency_id;
  if (!currencyId) return null;
  return currenciesList.value.find((c) => c.id === currencyId) || null;
});

const currentPurchaseCurrencySymbol = computed(() => {
  return currentPurchaseCurrency.value?.symbol || '£';
});

const currentCostCurrency = computed(() => {
  const currencyId = shipmentStore.currentShipment?.shipment_cost_currency_id;
  if (!currencyId) return null;
  return currenciesList.value.find((c) => c.id === currencyId) || null;
});

const currentCostCurrencySymbol = computed(() => {
  return currentCostCurrency.value?.symbol || '৳';
});

const loadShipmentDetails = () => {
  if (!Number.isNaN(shipmentId)) {
    void shipmentStore.fetchShipmentDetails(shipmentId);
  }
};

onMounted(() => {
  loadShipmentDetails();
  void loadCurrencies();
  if (authStore.tenantId) {
    void shipmentStore.ensureProgressTags(authStore.tenantId);
  }
});

const goBack = () => {
  router.back();
};

const changeProgress = async (tagId: number | null) => {
  if (!shipmentStore.currentShipment) return;
  const currentId =
    shipmentStore.currentShipment.progress_tag_id ??
    shipmentStore.currentShipment.progress_tag?.id ??
    null;
  if (currentId === tagId) return;
  progressTargetId.value = tagId;
  try {
    await shipmentStore.setProgressTag(shipmentStore.currentShipment.id, tagId);
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to update progress');
  } finally {
    progressTargetId.value = null;
  }
};

const changeStatus = (newStatus: string) => {
  if (!shipmentStore.currentShipment) return;
  if (shipmentStore.currentShipment.status === newStatus) return;

  if (
    shipmentStore.currentShipment.status === 'received' ||
    shipmentStore.currentShipment.status === 'cancelled'
  ) {
    showWarningNotification(
      shipmentStore.currentShipment.status === 'received'
        ? 'To change status, please use the Rollback option to revert the shipment to Draft.'
        : 'Cancelled shipments cannot change status.',
    );
    return;
  }

  if (newStatus === 'cancelled') {
    $q.dialog({
      title: 'Cancel shipment',
      message: 'Mark this shipment as cancelled? This does not post stock.',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void (async () => {
        updatingStatus.value = true;
        targetUpdatingStatus.value = 'cancelled';
        try {
          await shipmentStore.updateShipment(shipmentId, { status: 'cancelled' });
          showSuccessNotification('Shipment cancelled.');
          loadShipmentDetails();
        } catch (err: any) {
          showErrorNotification(err.message || 'Failed to cancel shipment.');
        } finally {
          updatingStatus.value = false;
          targetUpdatingStatus.value = null;
        }
      })();
    });
    return;
  }

  if (newStatus === 'received') {
    if (!isSplitsComplete.value) {
      showWarningNotification('Please configure quantity splits for all line items first.');
      return;
    }

    $q.dialog({
      component: ReceiveShipmentDialog,
      componentProps: { shipmentId },
    }).onOk(() => {
      void fetchShipmentDetails();
    });
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
        await shipmentStore.updateShipment(shipmentId, { status: newStatus });
        showSuccessNotification(`Shipment status updated to: ${newStatus}`);
        loadShipmentDetails();
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

const rollbackShipmentToDraft = () => {
  if (!shipmentStore.currentShipment) return;

  $q.dialog({
    title: 'Rollback Shipment to Draft',
    message:
      'This will delete all active stock entries and allocations for this shipment. The shipment status will be set back to "Draft". Are you sure you want to proceed?',
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      updatingStatus.value = true;
      targetUpdatingStatus.value = 'draft';
      try {
        await shipmentStore.rollbackShipmentToDraft(shipmentId);
        showSuccessNotification('Shipment successfully rolled back to Draft.');
        loadShipmentDetails();
      } catch (err: any) {
        showErrorNotification(err.message || 'Failed to rollback shipment.');
      } finally {
        updatingStatus.value = false;
        targetUpdatingStatus.value = null;
      }
    })();
  });
};



const confirmDeleteShipment = () => {
  $q.dialog({
    title: 'Confirm Deletion',
    message:
      'Are you sure you want to delete this shipment? All shipment items will be deleted. This action cannot be undone.',
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      try {
        await shipmentStore.deleteShipment(shipmentId);
        showSuccessNotification('Shipment deleted successfully');
        goBack();
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        showErrorNotification(message || 'Failed to delete shipment');
      }
    })();
  });
};

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
      totals: totals.value,
      boxWeightSum: currentShipmentBoxesTotal.value,
      splitsSummary: splitsSummary.value,
      purchaseCurrencySymbol: currentPurchaseCurrencySymbol.value,
      costCurrencySymbol: currentCostCurrencySymbol.value,
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

const openAddItems = () => {
  $q.dialog({
    component: AddShipmentItemsDrawer,
    componentProps: { shipmentId },
  });
};

const openBulkPaste = () => {
  $q.dialog({
    component: BulkPasteDialog,
  }).onOk(() => {
    loadShipmentDetails();
  });
};

const autoAcceptSplits = () => {
  $q.dialog({
    title: 'Auto Accept Quantity Splits',
    message:
      'This will automatically allocate 100% of the ordered quantity to "Standard Sellable" for all pending line items that do not have complete splits configured. Already completed splits will not be overwritten. Continue?',
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      try {
        await shipmentStore.autoAcceptAllSplits(shipmentId);
        showSuccessNotification('All pending splits auto-accepted successfully.');
      } catch (err: any) {
        showErrorNotification(err.message || 'Failed to auto-accept splits.');
      }
    })();
  });
};

const openEditItem = (item: GlobalShipmentItem) => {
  $q.dialog({
    component: ShipmentItemFormDialog,
    componentProps: {
      shipmentId,
      item,
      isReceived:
        shipmentStore.currentShipment?.status === 'in_transit' ||
        shipmentStore.currentShipment?.status === 'received' ||
        shipmentStore.currentShipment?.stock_ready === true,
    },
  });
};

const confirmDeleteItem = (itemId: number) => {
  $q.dialog({
    title: 'Confirm Deletion',
    message: 'Are you sure you want to delete this line item?',
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      try {
        await shipmentStore.deleteShipmentItem(itemId);
        showSuccessNotification('Item deleted successfully');
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        showErrorNotification(message || 'Failed to delete item');
      }
    })();
  });
};

const onSaveCostEntries = async (payload: CostEntriesSavePayload) => {
  try {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return;

    const prevWeight = shipment.received_weight;
    const nextWeight = payload.received_weight;
    const weightChanged =
      (prevWeight == null && nextWeight != null) ||
      (prevWeight != null && nextWeight == null) ||
      (prevWeight != null &&
        nextWeight != null &&
        Math.abs(prevWeight - nextWeight) > 0.0001);

    if (weightChanged) {
      await shipmentStore.updateShipment(shipmentId, {
        received_weight: nextWeight,
      });
    }

    await shipmentStore.saveCostEntries(shipmentId, payload.drafts);
    showSuccessNotification(
      isCostFinalized.value
        ? 'Costs revised and landed costs re-stamped.'
        : 'Cost entries saved.',
    );
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to save cost entries.');
  }
};
</script>

<style scoped>
.shipment-details-page .min-width-0 {
  min-width: 0;
}

.line-items-card {
  min-width: 0;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>
