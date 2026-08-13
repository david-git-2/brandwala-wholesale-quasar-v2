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
                <div class="text-subtitle1 text-weight-bold ellipsis">
                  {{ shipmentStore.currentShipment.name }}
                </div>
                <div class="text-caption text-grey-7 ellipsis">
                  #{{
                    shipmentStore.currentShipment.tenant_shipment_id ||
                    shipmentStore.currentShipment.id
                  }}
                  ·
                  <span class="text-capitalize">{{ shipmentStore.currentShipment.type }}</span>
                  · {{ formatWeightKg(shipmentStore.currentShipment.received_weight) }}
                  · {{ shipmentStore.currentShipment.received_date || '—' }}
                  ·
                  {{
                    shipmentStore.currentShipment.stock_ready ? 'Stock ready' : 'Stock not ready'
                  }}
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
              color="grey-8"
              icon="ph ph-pencil-simple"
              label="Edit"
              @click="openEditShipment"
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
          @update-status="changeStatus"
        />

        <!-- Next-step banner (only when there is something to do or a lock notice) -->
        <q-banner
          v-if="nextStep"
          dense
          rounded
          class="bg-primary-1 text-primary"
          style="background: var(--bw-theme-primary-soft, #e8f5e9)"
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
                <ShipmentWeightBalanceCard
                  :shipment-id="shipmentId"
                  @applied="loadShipmentDetails"
                />
                <ShipmentPurchaseBalanceCard
                  :shipment-id="shipmentId"
                  @applied="loadShipmentDetails"
                />
              </div>
            </q-tab-panel>

            <!-- Landed cost -->
            <q-tab-panel name="cost" class="q-pa-none">
              <q-card flat bordered class="q-pa-md bg-white text-grey-9">
                <div class="row items-center justify-between q-mb-md">
                  <div class="text-subtitle1 text-weight-bold text-primary">Landed Cost Summary</div>
                  <q-btn
                    v-if="isEditable"
                    flat
                    round
                    dense
                    icon="ph ph-note-pencil"
                    color="primary"
                    size="sm"
                    @click="openEditRates"
                  >
                    <q-tooltip>Edit Rates</q-tooltip>
                  </q-btn>
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
                    v-if="shipmentStore.currentShipment?.cargo_rate > 0"
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
                      v-if="shipmentStore.currentShipment?.cargo_rate > 0"
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
                        !((shipmentStore.currentShipment?.purchase_invoice_total ?? 0) > 0)
                          ? 'No paid invoice total set (optional skip)'
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
                    No stock allocations saved yet. Configure splits on the Items tab.
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
                    Configure quantity splits for all items first
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

      <!-- Edit Rates Dialog -->
      <q-dialog v-model="showRatesDialog" persistent>
        <q-card style="width: 750px; max-width: 95vw">
          <q-card-section class="row items-center q-pb-none">
            <div class="text-h6 text-weight-bold text-primary">Edit Shipment Rates</div>
            <q-space />
            <q-btn icon="ph ph-x" flat round dense v-close-popup />
          </q-card-section>

          <q-separator class="q-my-sm" />

          <q-card-section class="q-pa-md">
            <div class="row q-col-gutter-md">
              <!-- Left Column: Inputs -->
              <div class="col-12 col-sm-6 q-gutter-y-md">
                <div class="text-subtitle2 text-weight-bold text-grey-7">Configuration</div>
                <q-input
                  v-model.number="ratesForm.product_conversion_rate"
                  type="number"
                  step="0.0001"
                  label="Product Conversion Rate *"
                  filled
                  dense
                />
                <q-input
                  v-model.number="ratesForm.cargo_conversion_rate"
                  type="number"
                  step="0.0001"
                  label="Cargo Conversion Rate *"
                  filled
                  dense
                />
                <q-input
                  v-model.number="ratesForm.purchase_invoice_total"
                  type="number"
                  step="0.01"
                  label="Paid Purchase Invoice Total"
                  filled
                  dense
                  :prefix="currentPurchaseCurrencySymbol"
                />

                <q-separator class="q-my-xs" />
                <div class="text-subtitle2 text-weight-bold text-grey-7">
                  Cargo Rate Calculation
                </div>
                <div class="text-caption text-grey-6" style="margin-top: -8px; font-size: 11px">
                  Cargo Rate = Cargo Invoice Total ÷ Cargo Weight (kg)
                </div>

                <q-input
                  v-model.number="ratesForm.cargo_invoice_total"
                  type="number"
                  step="0.01"
                  label="Cargo Invoice Total"
                  filled
                  dense
                  :prefix="currentPurchaseCurrencySymbol"
                />
                <q-input
                  v-model.number="ratesForm.received_weight"
                  type="number"
                  step="0.01"
                  label="Cargo Weight (kg)"
                  filled
                  dense
                  suffix="kg"
                />
                <q-input
                  v-model.number="ratesForm.cargo_rate"
                  type="number"
                  step="0.01"
                  label="Cargo Rate (per kg)"
                  filled
                  dense
                  :readonly="isCargoRateAutoCalculated"
                  :hint="
                    isCargoRateAutoCalculated
                      ? 'Auto-calculated from invoice total ÷ weight'
                      : 'Enter manually or fill invoice total & weight above'
                  "
                  :class="{ 'bg-green-1': isCargoRateAutoCalculated }"
                />
              </div>

              <!-- Right Column: Live Preview Panel -->
              <div class="col-12 col-sm-6">
                <div class="text-subtitle2 text-weight-bold text-grey-7 q-mb-md">Live Preview</div>
                <div
                  class="bg-grey-1 q-pa-sm rounded-borders q-gutter-y-xs text-grey-9 text-caption"
                >
                  <div class="row justify-between">
                    <span>Product Purchase:</span>
                    <span class="text-weight-bold"
                      >{{ currentPurchaseCurrencySymbol
                      }}{{
                        ratesPreview.goodsPurchase.toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })
                      }}</span
                    >
                  </div>
                  <div
                    class="row justify-between"
                    v-if="shipmentStore.currentShipment?.type === 'international'"
                  >
                    <span>Product Converted Cost:</span>
                    <span class="text-weight-bold"
                      >{{ currentCostCurrencySymbol
                      }}{{
                        ratesPreview.goodsCost.toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })
                      }}</span
                    >
                  </div>
                  <q-separator class="q-my-xs" />
                  <div class="row justify-between">
                    <span>{{
                      hasCargoInvoiceWeight ? 'Cargo Invoice Weight:' : 'Cargo Weight:'
                    }}</span>
                    <span class="text-weight-bold"
                      >{{ ratesPreview.cargoWeightKg.toFixed(2) }} kg</span
                    >
                  </div>
                  <div class="row justify-between">
                    <span>Cargo Purchase:</span>
                    <span class="text-weight-bold"
                      >{{ currentPurchaseCurrencySymbol
                      }}{{
                        ratesPreview.cargoPurchase.toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })
                      }}</span
                    >
                  </div>
                  <div
                    class="row justify-between"
                    v-if="shipmentStore.currentShipment?.type === 'international'"
                  >
                    <span>Cargo Converted Cost:</span>
                    <span class="text-weight-bold"
                      >{{ currentCostCurrencySymbol
                      }}{{
                        ratesPreview.cargoCost.toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })
                      }}</span
                    >
                  </div>
                  <q-separator class="q-my-xs" />
                  <div
                    class="row justify-between text-subtitle2 text-weight-bold bg-primary text-white q-pa-xs rounded-borders"
                  >
                    <span>Total Cost:</span>
                    <span
                      >{{
                        shipmentStore.currentShipment?.type === 'international'
                          ? currentCostCurrencySymbol
                          : currentPurchaseCurrencySymbol
                      }}{{
                        ratesPreview.totalCost.toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })
                      }}</span
                    >
                  </div>
                </div>

                <div
                  class="bg-blue-1 text-blue-10 q-pa-sm rounded-borders text-center q-mt-md"
                  v-if="shipmentStore.currentShipment?.type === 'international'"
                >
                  <div
                    class="text-caption text-weight-medium uppercase"
                    style="font-size: 9px; letter-spacing: 0.5px"
                  >
                    Calculated Transaction Rate
                  </div>
                  <div class="text-h6 text-weight-bolder q-my-xs">
                    {{
                      ratesPreview.transactionRate ? ratesPreview.transactionRate.toFixed(4) : '-'
                    }}
                  </div>
                  <div class="text-caption text-blue-8" style="font-size: 10px">
                    Used for per-unit cost conversion
                  </div>
                </div>
              </div>
            </div>
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md bg-grey-1">
            <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
            <q-btn
              color="primary"
              unelevated
              label="Save Rates"
              :loading="savingRates"
              no-caps
              @click="onSaveRates"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { useGlobalStockTypeStore } from '../stores/globalStockTypeStore';
import type { GlobalShipment, GlobalShipmentItem } from '../repositories/globalShipmentRepository';
import ShipmentFormDialog from '../components/ShipmentFormDialog.vue';
import ShipmentItemFormDialog from '../components/ShipmentItemFormDialog.vue';
import AddShipmentItemsDrawer from '../components/AddShipmentItemsDrawer.vue';
import BulkPasteDialog from '../components/BulkPasteDialog.vue';
import ShipmentLineItemsTable, { type ColumnKey } from '../components/ShipmentLineItemsTable.vue';
import ShipmentWeightBalanceCard from '../components/ShipmentWeightBalanceCard.vue';
import ShipmentPurchaseBalanceCard from '../components/ShipmentPurchaseBalanceCard.vue';
import ShipmentStatusWorkflowBar from '../components/ShipmentStatusWorkflowBar.vue';
import { calculateTransactionRate, calculateShipmentCostSummary } from '../utils/landedCost';
import { buildShipmentExcelWorkbook } from '../utils/buildShipmentExcelWorkbook';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import type { GlobalCurrency } from 'src/modules/global_reference/types';
import {
  showSuccessNotification,
  showErrorNotification,
  showWarningNotification,
} from 'src/utils/appFeedback';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const shipmentStore = useGlobalShipmentStore();
const globalStockTypeStore = useGlobalStockTypeStore();

const shipmentId = Number(route.params.id);
const updatingStatus = ref(false);
const targetUpdatingStatus = ref<string | null>(null);
const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('lines');

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
  const stockTypes = globalStockTypeStore.items;

  const breakdown = stockTypes.map((type) => {
    const totalQty = stocks
      .filter((s) => s.stock_type_id === type.id)
      .reduce((sum, s) => sum + (s.quantity || 0), 0);
    return {
      id: type.id,
      description: type.description,
      is_sellable: type.is_sellable,
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

const formatWeightKg = (weight: number | null | undefined): string => {
  if (weight == null || weight <= 0) return '-';
  return `${weight.toFixed(2)} kg`;
};

const hasCargoInvoiceWeight = computed(() => {
  const rw = shipmentStore.currentShipment?.received_weight;
  return rw != null && rw > 0;
});

const authStore = useAuthStore();

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
  return calculateShipmentCostSummary(shipment, items);
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
  const rate = totals.value.transactionRate;
  return {
    ...shipment,
    transaction_rate: rate,
  };
});

const isEditable = computed(() => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return false;
  // §5.1.1 / workflow Stage 2: editable through in_transit; lock after received/cancelled
  return shipment.status !== 'received' && shipment.status !== 'cancelled';
});

const hasLineItems = computed(() => (shipmentStore.currentShipmentItems?.length ?? 0) > 0);

const weightNeedsAttention = computed(() => {
  if (!hasCargoInvoiceWeight.value) return false;
  return Math.abs(totals.value.packagingWeightKg - totals.value.cargoWeightKg) > 0.01;
});

const purchaseNeedsAttention = computed(() => {
  const invoice = shipmentStore.currentShipment?.purchase_invoice_total;
  if (invoice == null || invoice <= 0) return false;
  return Math.abs(invoice - totals.value.goodsPurchase) > 0.05;
});

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
  if (status === 'received' || status === 'cancelled') {
    return {
      message:
        status === 'cancelled' ? 'Shipment cancelled' : 'In stock — editing locked',
      label: null as string | null,
      disabled: true,
      reason:
        status === 'cancelled'
          ? 'This shipment was cancelled.'
          : 'Stock already posted. Use Add to stock tab to rollback if needed.',
      action: null as (() => void) | null,
    };
  }
  if (!hasLineItems.value) {
    return {
      message: 'Add products to this shipment',
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
      message: both
        ? 'Weight and purchase still need matching'
        : weightNeedsAttention.value
          ? "Cargo invoice weight doesn’t match line weights"
          : "Paid invoice total doesn’t match line purchases",
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
        message: 'Split each line into stock types before adding to stock',
        label: 'Configure splits',
        disabled: false,
        reason: '',
        action: () => {
          activeTab.value = 'lines';
        },
      };
    }
    return {
      message: 'Ready to post inventory',
      label: 'Add to stock',
      disabled: false,
      reason: '',
      action: () => {
        activeTab.value = 'receive';
        changeStatus('received');
      },
    };
  }
  return null;
});

const runPrimaryCta = () => {
  nextStep.value?.action?.();
};

const ratesPreview = computed(() => {
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
  const mockShipment = {
    ...shipment,
    product_conversion_rate: ratesForm.value.product_conversion_rate || 0,
    cargo_conversion_rate: ratesForm.value.cargo_conversion_rate || 0,
    cargo_rate: ratesForm.value.cargo_rate || 0,
  };
  return calculateShipmentCostSummary(mockShipment, items);
});

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

watch(
  () => authStore.tenantId,
  (newTenantId) => {
    if (newTenantId && globalStockTypeStore.items.length === 0) {
      void globalStockTypeStore.fetchStockTypes(newTenantId);
    }
  },
  { immediate: true },
);

onMounted(() => {
  loadShipmentDetails();
  void loadCurrencies();
});

const goBack = () => {
  router.back();
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
      title: 'Commit Shipment to Stock',
      message:
        'All item splits are fully configured. Changing status to Received will lock the allocations and commit them to active inventory pools. Continue?',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void (async () => {
        updatingStatus.value = true;
        targetUpdatingStatus.value = 'received';
        try {
          const txRate = totals.value.transactionRate;
          const updatePayload: any = {
            status: 'received',
            stock_ready: true,
          };
          if (txRate !== null) {
            updatePayload.transaction_rate = txRate;
          }
          await shipmentStore.updateShipment(shipmentId, updatePayload);
          showSuccessNotification('Shipment promoted to Received successfully.');
          loadShipmentDetails();
        } catch (err: any) {
          showErrorNotification(err.message || 'Failed to promote shipment.');
        } finally {
          updatingStatus.value = false;
          targetUpdatingStatus.value = null;
        }
      })();
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
        const txRate = totals.value.transactionRate;
        const updatePayload: Partial<
          Omit<GlobalShipment, 'id' | 'created_at' | 'updated_at' | 'parent_tenant_id'>
        > = { status: newStatus };
        if (txRate !== null) {
          updatePayload.transaction_rate = txRate;
        }

        await shipmentStore.updateShipment(shipmentId, updatePayload);
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

const openEditShipment = () => {
  if (!shipmentStore.currentShipment) return;
  $q.dialog({
    component: ShipmentFormDialog,
    componentProps: {
      shipment: shipmentStore.currentShipment,
    },
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

// Rates Dialog Setup
const showRatesDialog = ref(false);
const savingRates = ref(false);
const ratesForm = ref({
  product_conversion_rate: 1.0,
  cargo_conversion_rate: 1.0,
  cargo_rate: 0.0,
  cargo_invoice_total: null as number | null,
  purchase_invoice_total: null as number | null,
  received_weight: null as number | null,
});

const isCargoRateAutoCalculated = computed(() => {
  const t = ratesForm.value.cargo_invoice_total;
  const w = ratesForm.value.received_weight;
  return t != null && t > 0 && w != null && w > 0;
});

// Auto-calculate cargo_rate when both cargo_invoice_total and received_weight are provided
watch(
  () => [ratesForm.value.cargo_invoice_total, ratesForm.value.received_weight],
  ([invoiceTotal, weight]) => {
    if (invoiceTotal != null && invoiceTotal > 0 && weight != null && weight > 0) {
      ratesForm.value.cargo_rate = invoiceTotal / weight;
    }
  },
);

const openEditRates = () => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return;
  ratesForm.value = {
    product_conversion_rate: shipment.product_conversion_rate,
    cargo_conversion_rate: shipment.cargo_conversion_rate,
    cargo_rate: shipment.cargo_rate,
    cargo_invoice_total: shipment.cargo_invoice_total,
    purchase_invoice_total: shipment.purchase_invoice_total,
    received_weight: shipment.received_weight,
  };
  showRatesDialog.value = true;
};

const onSaveRates = async () => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return;
  savingRates.value = true;
  try {
    const items = shipmentStore.currentShipmentItems;
    const mockShipment = {
      ...shipment,
      ...ratesForm.value,
    };
    const txRate = calculateTransactionRate(mockShipment, items);
    const updatePayload = {
      product_conversion_rate: ratesForm.value.product_conversion_rate,
      cargo_conversion_rate: ratesForm.value.cargo_conversion_rate,
      cargo_rate: ratesForm.value.cargo_rate,
      cargo_invoice_total: ratesForm.value.cargo_invoice_total,
      purchase_invoice_total: ratesForm.value.purchase_invoice_total,
      received_weight: ratesForm.value.received_weight,
      transaction_rate: txRate,
    };
    await shipmentStore.updateShipment(shipmentId, updatePayload);
    showSuccessNotification('Conversion and cargo rates updated successfully.');
    showRatesDialog.value = false;
    loadShipmentDetails();
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to update rates.');
  } finally {
    savingRates.value = false;
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
