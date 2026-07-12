<template>
  <q-page class="q-pa-xs q-sm-pa-sm" style="max-width: 100%; overflow-x: hidden">
    <section class="q-gutter-y-sm" style="width: 100%; min-width: 0; overflow: hidden">
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

      <div
        v-else-if="shipmentStore.currentShipment"
        class="q-gutter-y-md"
        style="min-width: 0; width: 100%"
      >
        <!-- Error banner for actions -->
        <q-banner v-if="shipmentStore.error" class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
        </q-banner>

        <!-- Compact Header & Workflow Status Card -->
        <q-card flat class="q-mb-sm floating-surface hero-surface shadow-1">
          <q-card-section class="q-py-sm">
            <div class="row items-center justify-between q-col-gutter-sm">
              <!-- Left Side: ID, Title, and Subtitle Meta -->
              <div class="col-12 col-sm">
                <div class="row items-center q-gutter-sm">
                  <q-badge color="primary" outline class="text-weight-medium q-px-sm">
                    #{{
                      shipmentStore.currentShipment.tenant_shipment_id ||
                      shipmentStore.currentShipment.id
                    }}
                  </q-badge>
                  <div class="text-subtitle1 text-weight-bold text-grey-9">
                    {{ shipmentStore.currentShipment.name }}
                  </div>
                </div>
                <div
                  class="text-caption text-grey-7 q-mt-xs q-pl-xs row items-center q-gutter-x-sm wrap"
                >
                  <span
                    >Type:
                    <strong class="text-capitalize">{{
                      shipmentStore.currentShipment.type
                    }}</strong></span
                  >
                  <span>|</span>
                  <span
                    >Weight:
                    <strong>{{
                      formatWeightKg(shipmentStore.currentShipment.received_weight)
                    }}</strong></span
                  >
                  <span>|</span>
                  <span
                    >Received Date:
                    <strong>{{ shipmentStore.currentShipment.received_date || '—' }}</strong></span
                  >
                  <span>|</span>
                  <q-chip
                    dense
                    square
                    :color="shipmentStore.currentShipment.stock_ready ? 'green-1' : 'grey-2'"
                    :text-color="shipmentStore.currentShipment.stock_ready ? 'green-9' : 'grey-8'"
                    class="q-ma-none text-weight-bold"
                    style="font-size: 11px"
                  >
                    {{
                      shipmentStore.currentShipment.stock_ready ? 'Stock Ready' : 'Stock Not Ready'
                    }}
                  </q-chip>
                </div>
              </div>

              <!-- Right Side: Workflow & Action Buttons -->
              <div
                class="col-12 col-sm-auto row items-center q-gutter-sm justify-start justify-sm-end q-mt-xs q-mt-sm-none wrap"
              >
                <!-- Workflow Status Selector Chip -->
                <q-chip
                  dense
                  square
                  clickable
                  :style="statusChipStyle(shipmentStore.currentShipment.status)"
                  class="q-px-md q-py-sm text-weight-bold q-ma-none"
                >
                  <span
                    class="status-chip-dot"
                    :style="{
                      backgroundColor: statusDotColor(shipmentStore.currentShipment.status),
                    }"
                  />
                  {{ shipmentStore.currentShipment.status }}
                  <q-icon name="arrow_drop_down" class="q-ml-xs" size="16px" />
                  <q-menu>
                    <q-list dense style="min-width: 180px">
                      <q-item
                        v-for="status in statuses"
                        :key="status"
                        clickable
                        v-close-popup
                        :disable="status === 'Ready Stock' && !isSplitsComplete"
                        @click="changeStatus(status)"
                      >
                        <q-item-section>
                          <div class="row items-center justify-between no-wrap">
                            <span>{{ status }}</span>
                            <q-icon
                              v-if="status === 'Ready Stock' && !isSplitsComplete"
                              name="lock"
                              color="grey-6"
                              size="14px"
                              class="q-ml-xs"
                            >
                              <q-tooltip
                                >Configure splits for all items in 'Warehouse Received'
                                first</q-tooltip
                              >
                            </q-icon>
                          </div>
                        </q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-chip>

                <!-- Edit / Delete flat buttons with icons only -->
                <q-btn
                  color="primary"
                  flat
                  round
                  dense
                  icon="download"
                  @click="downloadExcel"
                >
                  <q-tooltip>Download Excel</q-tooltip>
                </q-btn>
                <q-btn v-if="isEditable" color="secondary" flat round dense icon="edit" @click="openEditShipment">
                  <q-tooltip>Edit Details</q-tooltip>
                </q-btn>
                <q-btn
                  v-if="isEditable"
                  color="negative"
                  flat
                  round
                  dense
                  icon="delete"
                  @click="confirmDeleteShipment"
                >
                  <q-tooltip>Delete Shipment</q-tooltip>
                </q-btn>
              </div>
            </div>
          </q-card-section>
        </q-card>

        <!-- Main Row: Metadata Sidebar left, Line items table right -->
        <div class="row q-col-gutter-md">
          <!-- Left Column: Summary and Costing Rates -->
          <div v-if="isLeftColumnVisible" class="col-12 col-md-3 q-gutter-y-md">
            <!-- Shipment Summary -->
            <q-card flat bordered class="q-pa-md">
              <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">
                Shipment Summary
              </div>
              <q-list dense separator>
                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Display ID</q-item-label>
                    <q-item-label class="text-weight-bold">
                      #{{
                        shipmentStore.currentShipment.tenant_shipment_id ||
                        shipmentStore.currentShipment.id
                      }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Status</q-item-label>
                    <q-item-label>
                      <q-chip
                        square
                        dense
                        :color="statusChipColor(shipmentStore.currentShipment.status)"
                        text-color="white"
                        class="text-weight-bold"
                      >
                        {{ shipmentStore.currentShipment.status }}
                      </q-chip>
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Type</q-item-label>
                    <q-item-label class="text-weight-bold text-capitalize">
                      {{ shipmentStore.currentShipment.type }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Stock Ready</q-item-label>
                    <q-item-label>
                      <q-chip
                        dense
                        square
                        :color="shipmentStore.currentShipment.stock_ready ? 'green-1' : 'grey-2'"
                        :text-color="
                          shipmentStore.currentShipment.stock_ready ? 'green-9' : 'grey-8'
                        "
                      >
                        {{ shipmentStore.currentShipment.stock_ready ? 'Ready' : 'Not Ready' }}
                      </q-chip>
                    </q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card>

            <!-- Rates & Weights -->
            <q-card flat bordered class="q-pa-md">
              <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">
                Rates & Weights
              </div>
              <q-list dense separator>
                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption"
                      >Product Conversion Rate</q-item-label
                    >
                    <q-item-label class="text-weight-bold">
                      {{ shipmentStore.currentShipment.product_conversion_rate }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption"
                      >Cargo Conversion Rate</q-item-label
                    >
                    <q-item-label class="text-weight-bold">
                      {{ shipmentStore.currentShipment.cargo_conversion_rate }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Cargo Rate</q-item-label>
                    <q-item-label class="text-weight-bold">
                      {{ shipmentStore.currentShipment.cargo_rate }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Transaction Rate</q-item-label>
                    <q-item-label class="text-weight-bold">
                      {{
                        totals.transactionRate !== null ? totals.transactionRate.toFixed(4) : '-'
                      }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Received Weight</q-item-label>
                    <q-item-label class="text-weight-bold">
                      {{ formatWeightKg(shipmentStore.currentShipment.received_weight) }}
                    </q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card>
          </div>

          <!-- Right Column: Shipment Line Items -->
          <div class="col-12" :class="isLeftColumnVisible ? 'col-md-9' : 'col-md-12'">
            <q-card flat bordered class="q-pa-none line-items-card">
              <q-card-section class="row items-center justify-between q-pb-none q-pa-md">
                <div class="row items-center">
                  <q-btn
                    flat
                    round
                    dense
                    color="primary"
                    :icon="
                      isLeftColumnVisible
                        ? 'keyboard_double_arrow_left'
                        : 'keyboard_double_arrow_right'
                    "
                    @click="isLeftColumnVisible = !isLeftColumnVisible"
                    class="q-mr-sm"
                  >
                    <q-tooltip>{{
                      isLeftColumnVisible ? 'Collapse Sidebar' : 'Expand Sidebar'
                    }}</q-tooltip>
                  </q-btn>
                  <div class="text-subtitle1 text-weight-bold text-primary">
                    Shipment Line Items
                  </div>
                </div>
                <div class="row items-center q-gutter-x-sm">
                  <q-btn
                    color="primary"
                    outline
                    no-caps
                    size="sm"
                    icon="view_column"
                    dense
                    label="Columns"
                    class="q-px-sm"
                  >
                    <q-menu>
                      <q-list style="min-width: 220px" class="q-py-xs">
                        <q-item>
                          <q-item-section>
                            <div class="text-subtitle2 text-weight-bold text-primary">
                              Show Columns
                            </div>
                          </q-item-section>
                        </q-item>
                        <q-item clickable>
                          <q-item-section>
                            <q-checkbox
                              v-model="allColumnsSelected"
                              label="Select / Deselect All"
                            />
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
                      shipmentStore.currentShipment?.status === 'Warehouse Received' &&
                      !isSplitsComplete
                    "
                    color="green-7"
                    icon="call_split"
                    label="Auto Accept Splits"
                    unelevated
                    dense
                    no-caps
                    class="q-px-md q-mr-sm"
                    :loading="shipmentStore.loading"
                    @click="autoAcceptSplits"
                  />
                  <q-btn
                    v-if="isEditable"
                    color="secondary"
                    icon="content_paste"
                    label="Bulk Paste"
                    unelevated
                    dense
                    no-caps
                    class="q-px-md q-mr-sm"
                    @click="openBulkPaste"
                  />
                  <q-btn
                    v-if="isEditable"
                    color="primary"
                    icon="add_shopping_cart"
                    label="Add Items"
                    unelevated
                    dense
                    no-caps
                    class="q-px-md"
                    @click="openAddItems"
                  />
                </div>
              </q-card-section>

              <ShipmentLineItemsTable
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
          </div>
        </div>

        <!-- Costing / Weight Band Below Table (50/50 split on SM+) -->
        <div class="row q-col-gutter-md q-mt-md">
          <div class="col-12 col-sm-6">
            <!-- Landed Cost Summary Card -->
            <q-card flat bordered class="q-pa-md bg-white text-grey-9 shadow-1">
              <div class="row items-center justify-between q-mb-md">
                <div class="text-subtitle1 text-weight-bold text-primary">Landed Cost Summary</div>
                <q-btn
                  flat
                  round
                  dense
                  icon="edit_note"
                  color="primary"
                  size="sm"
                  @click="openEditRates"
                >
                  <q-tooltip>Edit Rates</q-tooltip>
                </q-btn>
              </div>

              <!-- 1. Shipment totals -->
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

              <!-- 2. Purchase currency -->
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

              <!-- 3 & 4: Only for international -->
              <template v-if="shipmentStore.currentShipment?.type === 'international'">
                <q-separator class="q-my-sm" />

                <!-- 3. Cost currency -->
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

                  <!-- Warning caption if lineLandedCostTotal differs from totalCost -->
                  <div
                    v-if="Math.abs(totals.lineLandedCostTotal - totals.totalCost) > 0.05"
                    class="row items-center q-mt-xs q-px-xs text-amber-9 text-caption text-weight-medium"
                    style="font-size: 11px; line-height: 1.2"
                  >
                    <q-icon name="warning" class="q-mr-xs" size="14px" />
                    <span
                      >Landed cost total ({{ currentCostCurrencySymbol
                      }}{{
                        totals.lineLandedCostTotal.toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })
                      }}) differs from total cost by {{ currentCostCurrencySymbol
                      }}{{ Math.abs(totals.lineLandedCostTotal - totals.totalCost).toFixed(2) }} due
                      to rounding.</span
                    >
                  </div>
                </div>

                <q-separator class="q-my-sm" />

                <!-- 4. Transaction rate (always visible) -->
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

                  <!-- Weight balance status -->
                  <div v-if="hasCargoInvoiceWeight" class="q-mt-xs">
                    <div
                      v-if="Math.abs(totals.packagingWeightKg - totals.cargoWeightKg) > 0.01"
                      class="row items-center justify-center text-amber-9 text-caption text-weight-medium"
                      style="font-size: 11px"
                    >
                      <q-icon name="warning" class="q-mr-xs" size="14px" />
                      <span
                        >Line estimate ({{ totals.packagingWeightKg.toFixed(2) }} kg) differs from
                        invoice ({{ totals.cargoWeightKg.toFixed(2) }} kg) — apply weight
                        balance</span
                      >
                    </div>
                    <div
                      v-else
                      class="row items-center justify-center text-green-9 text-caption text-weight-medium"
                      style="font-size: 11px"
                    >
                      <q-icon name="check_circle" class="q-mr-xs" size="14px" />
                      <span>Line estimate matches invoice weight</span>
                    </div>
                  </div>
                </div>

                <!-- Promoted Receive to Stock button (only for Warehouse Received status) -->
                <q-btn
                  v-if="shipmentStore.currentShipment?.status === 'Warehouse Received'"
                  :color="isSplitsComplete ? 'green-7' : 'grey-5'"
                  :disable="!isSplitsComplete"
                  unelevated
                  class="full-width q-mt-md text-weight-bold text-white"
                  icon="check_circle"
                  label="Receive to Stock"
                  no-caps
                  @click="changeStatus('Ready Stock')"
                >
                  <q-tooltip v-if="!isSplitsComplete">
                    Configure quantity splits for all items in the table first
                  </q-tooltip>
                </q-btn>
              </template>
            </q-card>

            <!-- Stock Splits Summary Card -->
            <q-card
              v-if="shipmentStore.currentShipment?.status === 'Warehouse Received'"
              flat
              bordered
              class="q-pa-md bg-white text-grey-9 shadow-1 q-mt-md"
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
                <!-- Breakdown list -->
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
                  No stock allocations saved yet.
                </div>

                <q-separator class="q-my-sm" />

                <!-- Total -->
                <div
                  class="row justify-between items-center q-py-sm bg-grey-1 q-px-sm rounded-borders"
                >
                  <span class="text-caption text-weight-medium text-grey-8">Total Allocated:</span>
                  <span class="text-subtitle2 text-weight-bolder text-primary">
                    {{ splitsSummary.totalAllocated }} / {{ splitsSummary.totalOrdered }} pcs
                  </span>
                </div>
              </div>
            </q-card>
          </div>

          <div class="col-12 col-sm-6 q-gutter-y-md">
            <!-- Shipment Weight Balance Card -->
            <ShipmentWeightBalanceCard :shipment-id="shipmentId" @applied="loadShipmentDetails" />
            <!-- Shipment Purchase Balance Card -->
            <ShipmentPurchaseBalanceCard :shipment-id="shipmentId" @applied="loadShipmentDetails" />
          </div>
        </div>
      </div>

      <!-- Edit Rates Dialog -->
      <q-dialog v-model="showRatesDialog" persistent>
        <q-card style="width: 750px; max-width: 95vw">
          <q-card-section class="row items-center q-pb-none">
            <div class="text-h6 text-weight-bold text-primary">Edit Shipment Rates</div>
            <q-space />
            <q-btn icon="close" flat round dense v-close-popup />
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
                <div class="text-subtitle2 text-weight-bold text-grey-7">Cargo Rate Calculation</div>
                <div class="text-caption text-grey-6" style="margin-top: -8px; font-size: 11px;">
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
                  :hint="isCargoRateAutoCalculated ? 'Auto-calculated from invoice total ÷ weight' : 'Enter manually or fill invoice total & weight above'"
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
    </section>
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

const isLeftColumnVisible = ref(true);

const shipmentId = Number(route.params.id);
const updatingStatus = ref(false);

const statuses = [
  'Draft',
  'Order Placed',
  'Proforma Generated',
  'Payment Done',
  'Delivery Date Received',
  'Uk Warehouse Delivery Received',
  'Air Shipment Date Set',
  'Airport Arrival',
  'Airport Released',
  'Warehouse Received',
  'Ready Stock',
];

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
  return (
    shipment.status !== 'Ready Stock' &&
    shipment.status !== 'Warehouse Received'
  );
});

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

  if (newStatus === 'Ready Stock') {
    if (!isSplitsComplete.value) {
      showWarningNotification('Please configure quantity splits for all line items first.');
      return;
    }

    $q.dialog({
      title: 'Commit Shipment to Stock',
      message:
        'All item splits are fully configured. Changing status to "Ready Stock" will lock the allocations and commit them to active inventory pools. Continue?',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void (async () => {
        updatingStatus.value = true;
        try {
          const txRate = totals.value.transactionRate;
          const updatePayload: any = {
            status: 'Ready Stock',
            stock_ready: true,
          };
          if (txRate !== null) {
            updatePayload.transaction_rate = txRate;
          }
          await shipmentStore.updateShipment(shipmentId, updatePayload);
          showSuccessNotification('Shipment promoted to Ready Stock successfully.');
          loadShipmentDetails();
        } catch (err: any) {
          showErrorNotification(err.message || 'Failed to promote shipment.');
        } finally {
          updatingStatus.value = false;
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
    const fileTitle = safeNamePart(shipmentStore.currentShipment.name ?? `shipment_${shipmentStore.currentShipment.id}`);
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
        shipmentStore.currentShipment?.status === 'Warehouse Received' ||
        shipmentStore.currentShipment?.status === 'Ready Stock' ||
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

const statusChipColor = (status: string) => {
  switch (status) {
    case 'Draft':
      return 'grey-7';
    case 'Order Placed':
      return 'blue-6';
    case 'Payment Done':
      return 'indigo-6';
    case 'Warehouse Received':
      return 'orange-8';
    case 'Ready Stock':
      return 'green-7';
    default:
      return 'primary';
  }
};

const statusChipStyle = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase();
  switch (value) {
    case 'draft':
      return {
        backgroundColor: '#f3f4f6',
        color: '#374151',
        border: '1px solid #d1d5db',
        borderRadius: '6px',
      };
    case 'order placed':
      return {
        backgroundColor: '#eff6ff',
        color: '#1d4ed8',
        border: '1px solid #bfdbfe',
        borderRadius: '6px',
      };
    case 'proforma generated':
      return {
        backgroundColor: '#f0fdf4',
        color: '#15803d',
        border: '1px solid #bbf7d0',
        borderRadius: '6px',
      };
    case 'payment done':
      return {
        backgroundColor: '#faf5ff',
        color: '#7e22ce',
        border: '1px solid #e9d5ff',
        borderRadius: '6px',
      };
    case 'delivery date received':
      return {
        backgroundColor: '#fdf2f8',
        color: '#be185d',
        border: '1px solid #fbcfe8',
        borderRadius: '6px',
      };
    case 'uk warehouse delivery received':
      return {
        backgroundColor: '#fff7ed',
        color: '#c2410c',
        border: '1px solid #ffedd5',
        borderRadius: '6px',
      };
    case 'air shipment date set':
      return {
        backgroundColor: '#ecfdf5',
        color: '#047857',
        border: '1px solid #a7f3d0',
        borderRadius: '6px',
      };
    case 'airport arrival':
      return {
        backgroundColor: '#f0fdfa',
        color: '#0f766e',
        border: '1px solid #99f6e4',
        borderRadius: '6px',
      };
    case 'airport released':
      return {
        backgroundColor: '#f5f3ff',
        color: '#6d28d9',
        border: '1px solid #ddd6fe',
        borderRadius: '6px',
      };
    case 'warehouse received':
      return {
        backgroundColor: '#fffbeb',
        color: '#b45309',
        border: '1px solid #fde68a',
        borderRadius: '6px',
      };
    case 'ready stock':
      return {
        backgroundColor: '#f0fdf4',
        color: '#166534',
        border: '1px solid #bbf7d0',
        borderRadius: '6px',
      };
    default:
      return {
        backgroundColor: '#f9fafb',
        color: '#1f2937',
        border: '1px solid #e5e7eb',
        borderRadius: '6px',
      };
  }
};

const statusDotColor = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase();
  switch (value) {
    case 'draft':
      return '#4b5563';
    case 'order placed':
      return '#2563eb';
    case 'proforma generated':
      return '#16a34a';
    case 'payment done':
      return '#9333ea';
    case 'delivery date received':
      return '#db2777';
    case 'uk warehouse delivery received':
      return '#ea580c';
    case 'air shipment date set':
      return '#059669';
    case 'airport arrival':
      return '#0d9488';
    case 'airport released':
      return '#7c3aed';
    case 'warehouse received':
      return '#d97706';
    case 'ready stock':
      return '#15803d';
    default:
      return '#9ca3af';
  }
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
