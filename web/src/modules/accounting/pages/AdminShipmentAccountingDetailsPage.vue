<template>
  <q-page class="q-pa-xs q-sm-pa-md shipment-accounting-details-page">
    <PageInitialLoader v-if="shipmentStore.loading" />

    <template v-else>
      <q-banner
        v-if="shipmentStore.error"
        class="bg-red-1 text-negative q-mb-md"
        rounded
      >
        {{ shipmentStore.error }}
      </q-banner>

      <template v-if="shipmentStore.selectedShipment">
        <!-- ── Hero Header ─────────────────────────────────── -->
        <q-card flat class="q-mb-sm q-sm-mb-md floating-surface hero-surface shadow-1">
          <q-card-section class="q-py-sm">
            <div class="row items-center justify-between q-col-gutter-sm">
              <div class="col-12 col-sm">
                <div class="row items-center q-gutter-sm">
                  <q-badge color="primary" outline class="text-weight-medium">
                    #{{ shipmentStore.selectedShipment.tenant_shipment_id ?? shipmentStore.selectedShipment.id }}
                  </q-badge>
                  <div class="text-subtitle1 text-weight-bold">
                    {{ shipmentStore.selectedShipment.name }}
                  </div>
                </div>
                <div class="text-caption text-grey-8 q-mt-xs">
                  {{ shipmentStore.shipmentItems.length }} item{{ shipmentStore.shipmentItems.length !== 1 ? 's' : '' }} in shipment
                </div>
              </div>
              <div class="col-12 col-sm-auto row items-center justify-start justify-sm-end q-gutter-sm">
                <!-- Summary view mode toggle -->
                <q-btn-toggle
                  v-model="summaryViewMode"
                  dense
                  no-caps
                  unelevated
                  toggle-color="primary"
                  color="grey-2"
                  text-color="grey-8"
                  size="sm"
                  :options="[
                    { label: 'Cards', value: 'regular', icon: 'grid_view' },
                    { label: 'Charts', value: 'chart', icon: 'analytics' }
                  ]"
                  class="pill-btn text-caption"
                  style="border: 1px solid rgba(0, 0, 0, 0.05); padding: 2px;"
                />

                <q-chip
                  dense
                  square
                  :style="statusChipStyle(shipmentStore.selectedShipment.status)"
                  class="accounting-status-chip q-px-md q-py-sm"
                >
                  <span
                    class="status-chip-dot"
                    :style="{ backgroundColor: statusDotColor(shipmentStore.selectedShipment.status) }"
                  />
                  {{ shipmentStore.selectedShipment.status }}
                </q-chip>
              </div>
            </div>
          </q-card-section>
        </q-card>

        <!-- ── Error Banner ─────────────────────────────────── -->
        <q-banner v-if="accountingError" class="bg-red-1 text-negative q-mb-sm" rounded>
          {{ accountingError }}
        </q-banner>

        <template v-if="summaryViewMode === 'regular'">
          <!-- ── Cost Side Summary ────────────────────────────── -->
          <q-card flat class="q-mb-sm q-sm-mb-md floating-surface shadow-1">
            <q-card-section class="q-pb-xs">
              <div class="text-subtitle2 text-weight-bold q-mb-sm section-label">
                Shipment Cost Summary
              </div>
              <div class="row q-col-gutter-md">
                <div class="col-6 col-sm-3">
                  <div class="stat-card">
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Total Landed Cost</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Total Landed Cost</div>
                              <div class="text-body2">This is the full landed cost of the shipment.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: sum of each shipment row's received total cost.
                              </div>
                              <div class="text-body2 text-weight-medium">
                                {{ formatFixed2(totalReceivedCostBdt) }} BDT
                              </div>
                              <div class="text-body2 text-grey-8">
                                Breakdown: row received cost = cost per unit x received quantity.
                              </div>
                              <div class="text-body2 text-weight-medium">
                                Value: {{ formatFixed2(totalReceivedCostBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div class="stat-value">{{ formatFixed2(totalReceivedCostBdt) }}</div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
                <div class="col-6 col-sm-3">
                  <div class="stat-card stat-card--negative">
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Damage and Theft Loss Value</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Damage and Theft Loss Value</div>
                              <div class="text-body2">Cost of stock lost before it could be sold.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: sum of each row's loss total.
                              </div>
                              <div class="text-body2 text-grey-8">
                                row loss total = cost per unit x (damaged quantity + stolen quantity)
                              </div>
                              <div class="text-body2 text-weight-medium">
                                Value: {{ formatFixed2(totalLossBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div class="stat-value text-negative">{{ formatFixed2(totalLossBdt) }}</div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
                <div class="col-6 col-sm-3">
                  <div class="stat-card">
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Usable Stock</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Usable Stock</div>
                              <div class="text-body2">This is the stock value still available to sell.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: Total Shipment Cost - Damage and Theft Loss
                              </div>
                              <div class="text-body2 text-weight-medium">
                                {{ formatFixed2(totalReceivedCostBdt) }} - {{ formatFixed2(totalLossBdt) }} = {{ formatFixed2(usableCostBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div class="stat-value">{{ formatFixed2(usableCostBdt) }}</div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
                <div class="col-6 col-sm-3">
                  <div class="stat-card">
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Cost of Sold Stock</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Cost of Sold Stock</div>
                              <div class="text-body2">This is the cost tied to items already sold on invoices.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: sum of total_cost_amount from shipment invoice accounting entries.
                              </div>
                              <div class="text-body2 text-grey-8">
                                More simply: add up the COGS from every linked invoice line.
                              </div>
                              <div class="text-body2 text-weight-medium">
                                Value: {{ formatFixed2(totalInvoiceCogsBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div class="stat-value">{{ formatFixed2(totalInvoiceCogsBdt) }}</div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
              </div>
            </q-card-section>
          </q-card>

          <!-- ── Earning Side Summary ─────────────────────────── -->
          <q-card flat class="q-mb-sm q-sm-mb-md floating-surface shadow-1">
            <q-card-section class="q-pb-xs">
              <div class="text-subtitle2 text-weight-bold q-mb-sm section-label">
                Sales Summary
              </div>
              <div class="row q-col-gutter-sm">
                <div class="col-6 col-sm-4 col-md">
                  <div class="stat-card">
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Total Invoice Sales</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Total Invoice Sales</div>
                              <div class="text-body2">Total sales value from invoices linked to this shipment.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: sum of total_sell_amount from shipment invoice accounting entries.
                              </div>
                              <div class="text-body2 text-grey-8">
                                More simply: add up the selling amount from every linked invoice line.
                              </div>
                              <div class="text-body2 text-weight-medium">
                                Value: {{ formatFixed2(totalInvoiceRevenueBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div class="stat-value">{{ formatFixed2(totalInvoiceRevenueBdt) }}</div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
                <div class="col-6 col-sm-4 col-md">
                  <div class="stat-card" :class="totalRealizedProfitBdt >= 0 ? 'stat-card--positive' : 'stat-card--negative'">
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Realized Gross Profit</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Realized Gross Profit</div>
                              <div class="text-body2">This is the realized gross profit from sold invoice entries.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: sum of gross_profit_amount from shipment invoice accounting entries.
                              </div>
                              <div class="text-body2 text-grey-8">
                                Per line: gross profit = total sell amount - total cost amount.
                              </div>
                              <div class="text-body2 text-grey-8">
                                {{ formatFixed2(totalInvoiceRevenueBdt) }} - {{ formatFixed2(totalInvoiceCogsBdt) }} = {{ formatFixed2(totalRealizedProfitBdt) }} BDT
                              </div>
                              <div class="text-body2 text-weight-medium">
                                Value: {{ formatFixed2(totalRealizedProfitBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div class="stat-value" :class="totalRealizedProfitBdt >= 0 ? 'text-positive' : 'text-negative'">
                      {{ formatFixed2(totalRealizedProfitBdt) }}
                    </div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
                <div class="col-6 col-sm-4 col-md">
                  <div class="stat-card stat-card--primary">
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Payments Received</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Payments Received</div>
                              <div class="text-body2">How much customers have paid against invoices linked to this shipment.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: summed paid amount from the related invoices.
                              </div>
                              <div class="text-body2 text-grey-8">
                                This is cash collected so far, not the invoice total.
                              </div>
                              <div class="text-body2 text-weight-medium">
                                Value: {{ formatFixed2(totalInvoicePaidBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div class="stat-value text-primary">{{ formatFixed2(totalInvoicePaidBdt) }}</div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
                <div class="col-6 col-sm-6 col-md">
                  <div class="stat-card">
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Remaining Unsold Stock Value</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Remaining Unsold Stock Value</div>
                              <div class="text-body2">This is the value of unsold stock that remains in inventory.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: Unsold Inventory Cost - Cost of Sold Items
                              </div>
                              <div class="text-body2 text-grey-8">
                                {{ formatFixed2(usableCostBdt) }} - {{ formatFixed2(totalInvoiceCogsBdt) }}
                              </div>
                              <div class="text-body2 text-weight-medium">
                                {{ formatFixed2(usableCostBdt) }} - {{ formatFixed2(totalInvoiceCogsBdt) }} = {{ formatFixed2(remainingInventoryCostBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div class="stat-value">{{ formatFixed2(remainingInventoryCostBdt) }}</div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
                <div class="col-6 col-sm-6 col-md">
                  <div
                    class="stat-card"
                    :class="profitLossVsShipmentCostBdt >= 0 ? 'stat-card--positive' : 'stat-card--negative'"
                  >
                    <div class="row items-start justify-between no-wrap q-gutter-xs">
                      <div class="stat-label">Revenue Minus Total Cost</div>
                      <q-btn flat round dense size="sm" icon="info" class="metric-info-btn">
                        <q-menu anchor="top right" self="top left">
                          <q-card style="min-width: 280px; max-width: 360px">
                            <q-card-section class="q-gutter-xs">
                              <div class="text-subtitle2 text-weight-bold">Revenue Minus Total Cost</div>
                              <div class="text-body2">This compares total invoice revenue against the shipment’s landed cost.</div>
                              <div class="text-body2 text-grey-8">
                                Formula: Invoice Revenue - Total Shipment Cost
                              </div>
                              <div class="text-body2 text-grey-8">
                                {{ formatFixed2(totalInvoiceRevenueBdt) }} - {{ formatFixed2(totalReceivedCostBdt) }}
                              </div>
                              <div class="text-body2 text-weight-medium">
                                {{ formatFixed2(totalInvoiceRevenueBdt) }} - {{ formatFixed2(totalReceivedCostBdt) }} = {{ formatFixed2(profitLossVsShipmentCostBdt) }} BDT
                              </div>
                            </q-card-section>
                          </q-card>
                        </q-menu>
                      </q-btn>
                    </div>
                    <div
                      class="stat-value"
                      :class="profitLossVsShipmentCostBdt >= 0 ? 'text-positive' : 'text-negative'"
                    >
                      {{ formatFixed2(profitLossVsShipmentCostBdt) }}
                    </div>
                    <div class="stat-unit">BDT</div>
                  </div>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </template>

        <template v-else-if="summaryViewMode === 'chart'">
          <!-- ── Visual Analytics Summary ─────────────────────── -->
          <q-card flat class="q-mb-sm q-sm-mb-md floating-surface shadow-1">
            <q-card-section class="q-pb-md">
              <div class="text-subtitle2 text-weight-bold q-mb-md section-label">
                Shipment Visual Analytics
              </div>

              <div class="row q-col-gutter-lg">
                <!-- Left column: Circular margin and rate indicators -->
                <div class="col-12 col-md-6">
                  <div class="row q-col-gutter-md justify-around text-center">
                    
                    <!-- Gross Profit Margin Gauge -->
                    <div class="col-6 col-sm-4">
                      <div class="flex flex-center flex-column q-pa-sm">
                        <q-circular-progress
                          show-value
                          class="text-weight-bold text-positive q-my-xs"
                          :value="grossProfitMarginPercent"
                          size="90px"
                          :thickness="0.16"
                          color="positive"
                          track-color="grey-2"
                        >
                          {{ grossProfitMarginPercent }}%
                        </q-circular-progress>
                        <div class="text-caption text-weight-bold text-grey-9 q-mt-sm">Gross Profit Margin</div>
                        <div class="text-grey-6 text-weight-medium" style="font-size: 10px;">
                          Margin on Sales
                        </div>
                      </div>
                    </div>

                    <!-- Damage & Loss Rate Gauge -->
                    <div class="col-6 col-sm-4">
                      <div class="flex flex-center flex-column q-pa-sm">
                        <q-circular-progress
                          show-value
                          class="text-weight-bold text-negative q-my-xs"
                          :value="lossRatePercent"
                          size="90px"
                          :thickness="0.16"
                          color="negative"
                          track-color="grey-2"
                        >
                          {{ lossRatePercent }}%
                        </q-circular-progress>
                        <div class="text-caption text-weight-bold text-grey-9 q-mt-sm">Loss Value Rate</div>
                        <div class="text-grey-6 text-weight-medium" style="font-size: 10px;">
                          Loss of Landed Cost
                        </div>
                      </div>
                    </div>

                    <!-- Stock Sold Ratio Gauge -->
                    <div class="col-6 col-sm-4">
                      <div class="flex flex-center flex-column q-pa-sm">
                        <q-circular-progress
                          show-value
                          class="text-weight-bold text-primary q-my-xs"
                          :value="soldQuantityRatioPercent"
                          size="90px"
                          :thickness="0.16"
                          color="primary"
                          track-color="grey-2"
                        >
                          {{ soldQuantityRatioPercent }}%
                        </q-circular-progress>
                        <div class="text-caption text-weight-bold text-grey-9 q-mt-sm">Stock Sold Ratio</div>
                        <div class="text-grey-6 text-weight-medium" style="font-size: 10px;">
                          Sold Qty / Usable Qty
                        </div>
                      </div>
                    </div>

                  </div>
                </div>

                <!-- Right column: Linear progress charts -->
                <div class="col-12 col-md-6 flex flex-column justify-between q-gutter-y-md">
                  
                  <!-- Revenue Recovery Progress -->
                  <div>
                    <div class="row justify-between items-center q-mb-xs">
                      <span class="text-caption text-weight-bold text-grey-9">Landed Cost Recovery</span>
                      <span class="text-caption text-weight-bold" :class="revenueRecoveryRatePercent >= 100 ? 'text-positive' : 'text-primary'">
                        {{ revenueRecoveryRatePercent }}% Recovered
                      </span>
                    </div>
                    <q-linear-progress
                      :value="Math.min(1, (revenueRecoveryRatePercent / 100))"
                      :color="revenueRecoveryRatePercent >= 100 ? 'positive' : 'primary'"
                      track-color="grey-2"
                      rounded
                      size="12px"
                    />
                    <div class="row justify-between text-caption q-mt-xs text-grey-8" style="font-size: 11px">
                      <span>Landed Cost: <strong>{{ formatFixed2(totalReceivedCostBdt) }}</strong> BDT</span>
                      <span>Sales Revenue: <strong>{{ formatFixed2(totalInvoiceRevenueBdt) }}</strong> BDT</span>
                    </div>
                  </div>

                  <!-- Cash Collection Rate -->
                  <div>
                    <div class="row justify-between items-center q-mb-xs">
                      <span class="text-caption text-weight-bold text-grey-9">Cash Collection Progress</span>
                      <span class="text-caption text-weight-bold text-indigo">
                        {{ cashCollectionRatePercent }}% Paid
                      </span>
                    </div>
                    <q-linear-progress
                      :value="cashCollectionRatePercent / 100"
                      color="indigo"
                      track-color="grey-2"
                      rounded
                      size="12px"
                    />
                    <div class="row justify-between text-caption q-mt-xs text-grey-8" style="font-size: 11px">
                      <span>Collected Cash: <strong>{{ formatFixed2(totalInvoicePaidBdt) }}</strong> BDT</span>
                      <span>Total Invoiced: <strong>{{ formatFixed2(totalInvoiceRevenueBdt) }}</strong> BDT</span>
                    </div>
                  </div>

                  <!-- Usable Stock Utilization -->
                  <div>
                    <div class="row justify-between items-center q-mb-xs">
                      <span class="text-caption text-weight-bold text-grey-9">Usable Stock Sold (COGS)</span>
                      <span class="text-caption text-weight-bold text-teal">
                        {{ inventoryRealizedPercent }}% Sold
                      </span>
                    </div>
                    <q-linear-progress
                      :value="inventoryRealizedPercent / 100"
                      color="teal"
                      track-color="grey-2"
                      rounded
                      size="12px"
                    />
                    <div class="row justify-between text-caption q-mt-xs text-grey-8" style="font-size: 11px">
                      <span>COGS: <strong>{{ formatFixed2(totalInvoiceCogsBdt) }}</strong> BDT</span>
                      <span>Usable Value: <strong>{{ formatFixed2(usableCostBdt) }}</strong> BDT</span>
                    </div>
                  </div>

                </div>
              </div>
            </q-card-section>
          </q-card>
        </template>

        <!-- ── Tabbed Tables ─────────────────────────────────── -->
        <q-card flat class="q-mb-sm q-sm-mb-md floating-surface shadow-1">
          <!-- Tab bar -->
          <q-tabs
            v-model="activeTab"
            dense
            no-caps
            align="left"
            class="table-tabs"
            indicator-color="primary"
            active-color="primary"
          >
            <q-tab name="breakdown" label="Shipment Cost Breakdown" />
            <q-tab name="entries">
              <span>Invoice Accounting Entries</span>
              <q-badge
                v-if="shipmentAccountingEntries.length"
                color="primary"
                floating
                rounded
                class="q-ml-sm"
                style="position: relative; top: unset; right: unset;"
              >
                {{ shipmentAccountingEntries.length }}
              </q-badge>
            </q-tab>
          </q-tabs>

          <q-separator />

          <q-tab-panels v-model="activeTab" animated keep-alive>
            <!-- ── Breakdown panel ── -->
            <q-tab-panel name="breakdown" class="q-pa-none">
              <div class="shipment-table-wrap">
                <q-markup-table flat wrap-cells class="shipment-breakdown-table">
                  <thead>
                    <tr>
                      <th class="text-left sticky-col sticky-col-sl">SL</th>
                      <th class="text-left sticky-col sticky-col-img">Image</th>
                      <th class="text-left sticky-col sticky-col-name">Name</th>
                      <th class="text-right">Cost/Unit (BDT)</th>
                      <th class="text-right">Qty</th>
                      <th class="text-right">Qty Total (BDT)</th>
                      <th class="text-right">Received Total (BDT)</th>
                      <th class="text-right">Loss Total (BDT)</th>
                      <th class="text-right">Received</th>
                      <th class="text-right">Damaged</th>
                      <th class="text-right">Stolen</th>
                      <th class="text-right">Usable</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-if="!shipmentStore.shipmentItems.length">
                      <td colspan="12" class="text-center text-grey-7 q-pa-lg">
                        No shipment items found.
                      </td>
                    </tr>
                    <tr v-for="(item, index) in shipmentRows" :key="item.id" class="breakdown-row">
                      <td class="sticky-col sticky-col-sl text-grey-7">{{ Number(index) + 1 }}</td>
                      <td class="sticky-col sticky-col-img">
                        <q-avatar rounded size="40px" class="bg-grey-2">
                          <img
                            :src="item.image_url || fallbackImageUrl"
                            alt="product image"
                            class="fit"
                          />
                        </q-avatar>
                      </td>
                      <td class="sticky-col sticky-col-name text-weight-medium">{{ item.name ?? '-' }}</td>
                      <td class="text-right">{{ formatFixed2(item.costPerUnitBdt) }}</td>
                      <td class="text-right">{{ item.quantity }}</td>
                      <td class="text-right">{{ formatFixed2(item.quantityTotalBdt) }}</td>
                      <td class="text-right">{{ formatFixed2(item.receivedTotalBdt) }}</td>
                      <td class="text-right text-negative">{{ formatFixed2(item.lossTotalBdt) }}</td>
                      <td class="text-right">{{ item.received_quantity }}</td>
                      <td class="text-right text-orange-9">{{ item.damaged_quantity }}</td>
                      <td class="text-right text-negative">{{ item.stolen_quantity }}</td>
                      <td class="text-right text-positive text-weight-medium">{{ item.usableQuantity }}</td>
                    </tr>
                    <tr v-if="shipmentRows.length" class="totals-row">
                      <td colspan="5" class="text-right text-weight-bold">Total</td>
                      <td class="text-right text-weight-bold">{{ formatFixed2(totalQuantityCostBdt) }}</td>
                      <td class="text-right text-weight-bold">{{ formatFixed2(totalReceivedCostBdt) }}</td>
                      <td class="text-right text-weight-bold text-negative">{{ formatFixed2(totalLossBdt) }}</td>
                      <td colspan="4"></td>
                    </tr>
                  </tbody>
                </q-markup-table>
              </div>
            </q-tab-panel>

            <!-- ── Invoice entries panel (grouped + expandable) ── -->
            <q-tab-panel name="entries" class="q-pa-none">
              <div class="shipment-table-wrap">
                <q-markup-table flat wrap-cells class="invoice-entries-table">
                  <thead>
                    <tr>
                      <th style="width: 32px"></th>
                      <th class="text-left">Invoice</th>
                      <th class="text-left">Type</th>
                      <th class="text-left">Latest Entry</th>
                      <th class="text-right">Items</th>
                      <th class="text-right">Total Qty</th>
                      <th class="text-right">COGS (BDT)</th>
                      <th class="text-right">Revenue (BDT)</th>
                      <th class="text-right">Gross Profit (BDT)</th>
                      <th class="text-left">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <!-- Loading -->
                    <tr v-if="accountingLoading">
                      <td colspan="10" class="text-center text-grey-7 q-pa-lg">
                        <q-spinner color="primary" size="24px" /><br />
                        Loading accounting entries…
                      </td>
                    </tr>

                    <!-- Empty -->
                    <tr v-else-if="!groupedInvoiceEntries.length">
                      <td colspan="10" class="text-center text-grey-7 q-pa-lg">
                        No invoice accounting entries for this shipment.
                      </td>
                    </tr>

                    <!-- Invoice groups -->
                    <template
                      v-for="group in groupedInvoiceEntries"
                      :key="group.invoiceKey"
                    >
                      <!-- ── Parent row (invoice summary) ── -->
                      <tr
                        class="invoice-group-row"
                        :class="{ 'invoice-group-row--expanded': expandedInvoices.has(group.invoiceKey) }"
                        @click="toggleInvoice(group.invoiceKey)"
                      >
                        <td class="text-center expand-toggle-cell">
                          <q-icon
                            :name="expandedInvoices.has(group.invoiceKey) ? 'expand_more' : 'chevron_right'"
                            size="18px"
                            class="text-grey-6"
                          />
                        </td>
                        <td>
                          <span class="text-weight-bold">
                            {{ group.invoice_id ? `#${group.invoice_id}` : 'No Invoice' }}
                          </span>
                        </td>
                        <td>
                          <q-badge
                            outline
                            :color="group.type === 'commerce' ? 'indigo' : 'primary'"
                            class="text-capitalize"
                            style="font-size: 10px"
                          >
                            {{ group.type ?? 'normal' }}
                          </q-badge>
                        </td>
                        <td class="text-grey-8">{{ group.latestDate }}</td>
                        <td class="text-right text-grey-7">{{ group.entries.length }}</td>
                        <td class="text-right text-weight-medium">{{ group.totalQty }}</td>
                        <td class="text-right">{{ formatFixed2(group.totalCogs) }}</td>
                        <td class="text-right">{{ formatFixed2(group.totalRevenue) }}</td>
                        <td
                          class="text-right text-weight-medium"
                          :class="group.totalProfit >= 0 ? 'text-positive' : 'text-negative'"
                        >
                          {{ formatFixed2(group.totalProfit) }}
                        </td>
                        <td>
                          <span
                            class="invoice-status-chip"
                            :class="`invoice-status-chip--${(group.dominantStatus ?? 'unknown').toLowerCase()}`"
                          >
                            <span class="status-chip-dot" :style="{ backgroundColor: invoiceStatusDotColor(group.dominantStatus) }" />
                            {{ group.dominantStatus }}
                          </span>
                        </td>
                      </tr>

                      <!-- ── Child rows (line items) ── -->
                      <template v-if="expandedInvoices.has(group.invoiceKey)">
                        <!-- child header -->
                        <tr class="child-header-row">
                          <td></td>
                          <td class="text-caption text-grey-6">Entry ID</td>
                          <td class="text-caption text-grey-6">Entry Date</td>
                          <td class="text-caption text-grey-6">Note</td>
                          <td></td>
                          <td class="text-right text-caption text-grey-6">Qty</td>
                          <td class="text-right text-caption text-grey-6">COGS</td>
                          <td class="text-right text-caption text-grey-6">Revenue</td>
                          <td class="text-right text-caption text-grey-6">Gross Profit</td>
                          <td class="text-caption text-grey-6">Status</td>
                        </tr>
                        <tr
                          v-for="row in group.entries"
                          :key="row.id"
                          class="child-row"
                        >
                          <td></td>
                          <td class="text-grey-7" style="font-size: 11px">#{{ row.id }}</td>
                          <td class="text-grey-8">{{ row.entry_date ?? '-' }}</td>
                          <td class="text-grey-7" style="font-size: 11px; max-width: 160px; word-break: break-word;">
                            <span :class="{ 'text-weight-bold text-indigo': !row.inventory_item_id }">
                              {{ row.note ?? '-' }}
                            </span>
                          </td>
                          <td></td>
                          <td class="text-right">{{ row.quantity }}</td>
                          <td class="text-right">{{ formatFixed2(row.total_cost_amount) }}</td>
                          <td class="text-right">{{ formatFixed2(row.total_sell_amount) }}</td>
                          <td
                            class="text-right"
                            :class="Number(row.gross_profit_amount ?? 0) >= 0 ? 'text-positive' : 'text-negative'"
                          >
                            {{ formatFixed2(row.gross_profit_amount) }}
                          </td>
                          <td>
                            <span
                              class="invoice-status-chip invoice-status-chip--sm"
                              :class="`invoice-status-chip--${(row.status ?? 'unknown').toLowerCase()}`"
                            >
                              <span class="status-chip-dot" :style="{ backgroundColor: invoiceStatusDotColor(row.status) }" />
                              {{ row.status }}
                            </span>
                          </td>
                        </tr>
                      </template>
                    </template>

                    <!-- Grand total row -->
                    <tr
                      v-if="!accountingLoading && shipmentAccountingEntries.length"
                      class="totals-row"
                    >
                      <td colspan="5" class="text-right text-weight-bold">Grand Total</td>
                      <td class="text-right text-weight-bold">{{ totalSoldQuantity }}</td>
                      <td class="text-right text-weight-bold">{{ formatFixed2(totalInvoiceCogsBdt) }}</td>
                      <td class="text-right text-weight-bold">{{ formatFixed2(totalInvoiceRevenueBdt) }}</td>
                      <td
                        class="text-right text-weight-bold"
                        :class="totalRealizedProfitBdt >= 0 ? 'text-positive' : 'text-negative'"
                      >
                        {{ formatFixed2(totalRealizedProfitBdt) }}
                      </td>
                      <td></td>
                    </tr>
                  </tbody>
                </q-markup-table>
              </div>
            </q-tab-panel>
          </q-tab-panels>
        </q-card>
      </template>

      <div v-else class="text-grey-7 q-pa-lg text-center">
        <q-icon name="search_off" size="48px" class="text-grey-4 q-mb-md" /><br />
        Shipment not found.
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import { supabase } from 'src/boot/supabase'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { accountingService } from 'src/modules/accounting/services/accountingService'
import type { InventoryAccountingEntry } from 'src/modules/accounting/types'
import { useInvoiceStore } from 'src/modules/invoice/stores/invoiceStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { calculateCostBdt } from 'src/modules/shipment/utils/costing'
import { formatAmountBdt } from 'src/utils/currency'

import { getReceivedQty, getDamagedQty, getStolenQty } from 'src/modules/shipment/utils/splits'

const route = useRoute()

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const invoiceStore = useInvoiceStore()
const shipmentAccountingEntries = ref<InventoryAccountingEntry[]>([])
const accountingLoading = ref(false)
const accountingError = ref<string | null>(null)
const shipmentInvoicePaidById = ref<Record<string, number>>({})
const fallbackImageUrl = 'https://placehold.co/44x44?text=No+Image'
const activeTab = ref<'breakdown' | 'entries'>('breakdown')
const expandedInvoices = ref<Set<string>>(new Set())
const summaryViewMode = ref<'regular' | 'chart'>('regular')

const grossProfitMarginPercent = computed(() => {
  if (!totalInvoiceRevenueBdt.value) return 0
  const val = (totalRealizedProfitBdt.value / totalInvoiceRevenueBdt.value) * 100
  return Math.max(0, Math.round(val))
})

const lossRatePercent = computed(() => {
  if (!totalReceivedCostBdt.value) return 0
  const val = (totalLossBdt.value / totalReceivedCostBdt.value) * 100
  return Math.max(0, Math.round(val))
})

const soldQuantityRatioPercent = computed(() => {
  const totalUsableQty = shipmentRows.value.reduce((sum, item) => sum + item.usableQuantity, 0)
  if (!totalUsableQty) return 0
  const val = (totalSoldQuantity.value / totalUsableQty) * 100
  return Math.min(100, Math.max(0, Math.round(val)))
})

const revenueRecoveryRatePercent = computed(() => {
  if (!totalReceivedCostBdt.value) return 0
  const val = (totalInvoiceRevenueBdt.value / totalReceivedCostBdt.value) * 100
  return Math.max(0, Math.round(val))
})

const cashCollectionRatePercent = computed(() => {
  if (!totalInvoiceRevenueBdt.value) return 0
  const val = (totalInvoicePaidBdt.value / totalInvoiceRevenueBdt.value) * 100
  return Math.min(100, Math.max(0, Math.round(val)))
})

const inventoryRealizedPercent = computed(() => {
  if (!usableCostBdt.value) return 0
  const val = (totalInvoiceCogsBdt.value / usableCostBdt.value) * 100
  return Math.min(100, Math.max(0, Math.round(val)))
})


const toggleInvoice = (key: string) => {
  const next = new Set(expandedInvoices.value)
  if (next.has(key)) {
    next.delete(key)
  } else {
    next.add(key)
  }
  expandedInvoices.value = next
}

// Group flat entries by invoice_id+type so each invoice is one parent row
const groupedInvoiceEntries = computed(() => {
  const map = new Map<string, InventoryAccountingEntry[]>()
  for (const entry of shipmentAccountingEntries.value) {
    const key = `${entry.invoice_id ?? 'none'}_${entry.type ?? 'normal'}`
    if (!map.has(key)) map.set(key, [])
    map.get(key)!.push(entry)
  }
  return Array.from(map.entries()).map(([invoiceKey, entries]) => {
    const first = entries[0]!
    const totalQty = entries.reduce((s, e) => s + Number(e.quantity ?? 0), 0)
    const totalCogs = entries.reduce((s, e) => s + Number(e.total_cost_amount ?? 0), 0)
    const totalRevenue = entries.reduce((s, e) => s + Number(e.total_sell_amount ?? 0), 0)
    const totalProfit = entries.reduce((s, e) => s + Number(e.gross_profit_amount ?? 0), 0)
    const dominantStatus = entries.some((e) => e.status === 'due') ? 'due' : 'paid'
    const latestDate = entries
      .map((e) => e.entry_date ?? '')
      .filter(Boolean)
      .sort()
      .at(-1) ?? '-'
    return {
      invoiceKey,
      invoice_id: first.invoice_id,
      type: first.type,
      entries,
      totalQty,
      totalCogs,
      totalRevenue,
      totalProfit,
      dominantStatus,
      latestDate,
    }
  })
})

const shipmentId = computed(() => {
  const parsed = Number(route.params.id)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
})

const shipmentRows = computed(() => {
  const shipment = shipmentStore.selectedShipment
  return (shipmentStore.shipmentItems ?? []).map((item) => {
    const costPerUnitBdt = shipment && !shipment.is_gbp
      ? Number(item.cost_bdt ?? 0)
      : calculateCostBdt({
          productWeight: item.product_weight,
          packageWeight: item.package_weight,
          cargoRate: shipment?.cargo_rate,
          priceGbp: item.price_gbp,
          transactionRate: shipment?.transaction_rate,
          productConversionRate: shipment?.product_conversion_rate,
          cargoConversionRate: shipment?.cargo_conversion_rate,
        })
    const recQty = getReceivedQty(item)
    const damQty = getDamagedQty(item)
    const stQty = getStolenQty(item)
    return {
      ...item,
      costPerUnitBdt,
      quantityTotalBdt: costPerUnitBdt * Number(item.quantity ?? 0),
      receivedTotalBdt: costPerUnitBdt * recQty,
      lossTotalBdt: costPerUnitBdt * (stQty + damQty),
      usableQuantity: Math.max(0, recQty - stQty - damQty),
      received_quantity: recQty,
      damaged_quantity: damQty,
      stolen_quantity: stQty,
    }
  })
})

const totalQuantityCostBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.quantityTotalBdt, 0),
)

const totalReceivedCostBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.receivedTotalBdt, 0),
)

const totalLossBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.lossTotalBdt, 0),
)

const usableCostBdt = computed(() => Math.max(0, totalReceivedCostBdt.value - totalLossBdt.value))

const totalInvoiceRevenueBdt = computed(() =>
  shipmentAccountingEntries.value.reduce((sum, row) => sum + Number(row.total_sell_amount ?? 0), 0),
)

const totalInvoiceCogsBdt = computed(() =>
  shipmentAccountingEntries.value.reduce((sum, row) => sum + Number(row.total_cost_amount ?? 0), 0),
)

const totalRealizedProfitBdt = computed(() =>
  shipmentAccountingEntries.value.reduce((sum, row) => sum + Number(row.gross_profit_amount ?? 0), 0),
)

const totalSoldQuantity = computed(() =>
  shipmentAccountingEntries.value.reduce((sum, row) => sum + Number(row.quantity ?? 0), 0),
)
const totalInvoicePaidBdt = computed(() =>
  Object.values(shipmentInvoicePaidById.value).reduce((sum: number, value) => sum + Number(value ?? 0), 0),
)

const remainingInventoryCostBdt = computed(() =>
  Math.max(0, usableCostBdt.value - totalInvoiceCogsBdt.value),
)

const profitLossVsShipmentCostBdt = computed(
  () => totalInvoiceRevenueBdt.value - totalReceivedCostBdt.value,
)

const formatFixed2 = (value: number | null | undefined) => formatAmountBdt(value)

// ── Status chip helpers ──────────────────────────────────────
const statusChipStyle = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase()
  if (value === 'pending') return { backgroundColor: '#efd399', color: '#6a4a14', border: '1px solid #d8b672' }
  if (value === 'active') return { backgroundColor: '#c3e8d2', color: '#1f5d3c', border: '1px solid #9fd4b7' }
  if (value === 'completed') return { backgroundColor: '#e0f2f1', color: '#00695c', border: '1px solid #b2dfdb' }
  if (value === 'cancelled') return { backgroundColor: '#f2c7d0', color: '#6f2b3a', border: '1px solid #e3a6b3' }
  return { backgroundColor: '#dbe5f3', color: '#3b4b66', border: '1px solid #b9c8dd' }
}

const statusDotColor = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase()
  if (value === 'pending') return '#9a6a24'
  if (value === 'active') return '#2f8b5d'
  if (value === 'completed') return '#009688'
  if (value === 'cancelled') return '#a64c62'
  return '#66758c'
}

const invoiceStatusDotColor = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase()
  if (value === 'paid') return '#2f8b5d'
  if (value === 'partial') return '#9a6a24'
  if (value === 'unpaid') return '#a64c62'
  return '#66758c'
}

// ── Data fetching ────────────────────────────────────────────
const fetchDetails = async () => {
  if (!shipmentId.value) {
    return
  }
  await Promise.all([shipmentStore.fetchShipmentById(shipmentId.value), fetchAccountingEntries()])
}

const fetchAccountingEntries = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) {
    shipmentAccountingEntries.value = []
    return
  }

  accountingLoading.value = true
  accountingError.value = null

  try {
    const result = await accountingService.listInventoryAccountingEntries({
      tenant_id: tenantId,
      filters: { shipment_id: shipmentId.value },
      operators: { shipment_id: 'eq' },
      page: 1,
      page_size: 1000,
      sortBy: 'id',
      sortOrder: 'desc',
    })

    if (!result.success) {
      accountingError.value = result.error ?? 'Failed to load shipment accounting entries.'
      shipmentAccountingEntries.value = []
      return
    }

    shipmentAccountingEntries.value = result.data?.data ?? []
    await fetchShipmentInvoicePaidAmounts()
  } finally {
    accountingLoading.value = false
  }
}

const fetchShipmentInvoicePaidAmounts = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    shipmentInvoicePaidById.value = {}
    return
  }

  const normalInvoiceIds = Array.from(
    new Set(
      shipmentAccountingEntries.value
        .filter((row) => row.type === 'normal')
        .map((row) => Number(row.invoice_id))
        .filter((id) => Number.isFinite(id) && id > 0),
    ),
  )

  const commerceInvoiceIds = Array.from(
    new Set(
      shipmentAccountingEntries.value
        .filter((row) => row.type === 'commerce')
        .map((row) => Number(row.invoice_id))
        .filter((id) => Number.isFinite(id) && id > 0),
    ),
  )

  const paidAmounts: Record<string, number> = {}

  if (normalInvoiceIds.length > 0) {
    const invoicesResult = await invoiceStore.fetchInvoices({
      tenant_id: tenantId,
      filters: { id: normalInvoiceIds },
      operators: { id: 'in' },
      page: 1,
      page_size: Math.max(normalInvoiceIds.length, 100),
      sortBy: 'id',
      sortOrder: 'asc',
    })
    if (invoicesResult.success) {
      ;(invoiceStore.invoices ?? []).forEach((invoice) => {
        paidAmounts[`normal_${invoice.id}`] = Number(invoice.paid_amount ?? 0)
      })
    }
  }

  if (commerceInvoiceIds.length > 0) {
    const { data: commerceInvoices, error: commerceErr } = await supabase
      .from('commerce_invoices')
      .select('id, amount_paid')
      .in('id', commerceInvoiceIds)
    if (!commerceErr && commerceInvoices) {
      commerceInvoices.forEach((invoice) => {
        paidAmounts[`commerce_${invoice.id}`] = Number(invoice.amount_paid ?? 0)
      })
    }
  }

  shipmentInvoicePaidById.value = paidAmounts
}



onMounted(() => {
  void fetchDetails()
})

watch(
  () => route.params.id,
  () => {
    void fetchDetails()
  },
)
</script>

<style scoped>
.shipment-accounting-details-page {
  background: transparent;
}

/* ── Floating surface ── */
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

/* ── Tab bar ── */
.table-tabs {
  padding: 0 4px;
}

.table-tabs :deep(.q-tab) {
  font-size: 13px;
  font-weight: 500;
  padding: 0 16px;
  min-height: 40px;
  color: #555e72;
}

.table-tabs :deep(.q-tab--active) {
  color: var(--q-primary);
  font-weight: 600;
}

.table-tabs :deep(.q-tab__indicator) {
  height: 2px;
  border-radius: 2px 2px 0 0;
}

/* ── Section label ── */
.section-label {
  color: #22385a;
  display: flex;
  align-items: center;
}

/* ── Stat cards ── */
.stat-card {
  background: rgba(248, 250, 254, 0.9);
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 10px;
  padding: 12px 14px 10px;
  margin-bottom: 12px;
  transition: box-shadow 0.15s;
}

.stat-card:hover {
  box-shadow: 0 2px 12px rgba(34, 56, 101, 0.08);
}

.stat-card--negative {
  border-left: 3px solid #e53935;
  background: rgba(253, 245, 245, 0.9);
}

.stat-card--positive {
  border-left: 3px solid #2e7d32;
  background: rgba(244, 251, 246, 0.9);
}

.stat-card--primary {
  border-left: 3px solid var(--q-primary, #1976d2);
  background: rgba(245, 249, 255, 0.9);
}

.stat-label {
  font-size: 11px;
  font-weight: 500;
  color: #555e72;
  letter-spacing: 0.01em;
  margin-bottom: 4px;
  line-height: 1.35;
}

.stat-value {
  font-size: 18px;
  font-weight: 700;
  color: #1a2642;
  line-height: 1.2;
  letter-spacing: -0.01em;
}

.stat-unit {
  font-size: 10px;
  color: #8896aa;
  margin-top: 2px;
}

.stat-help {
  margin-top: 6px;
  font-size: 11px;
  line-height: 1.35;
  color: #6b7689;
}

.metric-info-btn {
  color: #6b7689;
  margin-top: -2px;
}

/* ── Status chip ── */
.accounting-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  font-size: 12px;
  letter-spacing: 0.01em;
  text-transform: capitalize;
}

.status-chip-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: 999px;
  margin-right: 6px;
  flex-shrink: 0;
}

/* ── Invoice status chip ── */
.invoice-status-chip {
  display: inline-flex;
  align-items: center;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
  text-transform: capitalize;
  background: rgba(34, 56, 101, 0.06);
  color: #3b4b66;
}

.invoice-status-chip--paid { background: #e8f5e9; color: #2e7d32; }
.invoice-status-chip--partial { background: #fff8e1; color: #6a4a14; }
.invoice-status-chip--unpaid { background: #fdecea; color: #c62828; }

/* ── Tables ── */
.shipment-table-wrap {
  overflow-x: auto;
  overflow-y: auto;
  max-height: calc(100vh - 340px);
}

.shipment-breakdown-table :deep(th),
.invoice-entries-table :deep(th) {
  background: color-mix(in srgb, #f7f9fc 96%, rgba(34, 56, 101, 0.04) 4%);
  font-size: 12px;
  font-weight: 600;
  color: #3b4b66;
  padding: 10px 12px;
  white-space: nowrap;
  position: sticky;
  top: 0;
  z-index: 2;
  border-bottom: 1px solid rgba(34, 56, 101, 0.1);
}

.shipment-breakdown-table :deep(td),
.invoice-entries-table :deep(td) {
  padding: 8px 12px;
  font-size: 13px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.05);
  vertical-align: middle;
}

/* Sticky columns */
.sticky-col {
  position: sticky !important;
  z-index: 3;
  background: inherit;
}

.sticky-col-sl {
  left: 0;
  min-width: 40px;
  width: 40px;
}

.sticky-col-img {
  left: 40px;
  min-width: 60px;
  width: 60px;
}

.sticky-col-name {
  left: 100px;
  min-width: 160px;
  max-width: 200px;
}

/* Sticky header cells need higher z-index */
thead .sticky-col {
  z-index: 4;
}

.breakdown-row:hover :deep(td),
.breakdown-row:hover td {
  background: rgba(34, 56, 101, 0.03);
}

.totals-row td {
  background: rgba(248, 250, 254, 0.95) !important;
  border-top: 2px solid rgba(34, 56, 101, 0.12);
  font-size: 13px;
}

/* ── Mobile compact ── */
@media (max-width: 599px) {
  .shipment-table-wrap {
    max-height: calc(100vh - 260px);
  }

  .stat-card {
    padding: 10px 10px 8px;
    margin-bottom: 8px;
  }

  .stat-value {
    font-size: 15px;
  }
}
</style>
