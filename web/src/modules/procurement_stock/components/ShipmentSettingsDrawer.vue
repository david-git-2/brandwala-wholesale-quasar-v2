<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="procurement.shipment-settings-drawer-width"
    :default-width="680"
    :min-width="400"
    :max-width="1200"
    aria-label="Shipment settings"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <div class="column full-height no-wrap overflow-hidden shipment-settings-drawer">
      <!-- Segmented tabs -->
      <TfDrawerSectionTabsHeader
        v-model="activeTab"
        :tabs="settingsTabs"
        ariaLabel="Shipment settings sections"
      >
        <template #trailing>
          <q-btn
            flat
            round
            dense
            icon="ph ph-x"
            color="grey-7"
            aria-label="Close settings"
            class="shipment-settings-drawer__close shrink-0"
            @click="emit('update:modelValue', false)"
          />
        </template>
      </TfDrawerSectionTabsHeader>

      <!-- Tab Panels -->
      <q-tab-panels v-model="activeTab" animated class="col bg-white shipment-settings-drawer-panels">
        <!-- 1. Details Tab Panel -->
        <q-tab-panel name="details" class="bg-white">
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

            <q-separator class="q-my-sm" />

            <!-- Danger Zone / Shipment Actions -->
            <div class="column q-gutter-y-xs">
              <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
                <q-icon name="ph ph-sliders" size="18px" color="primary" />
                <span>Shipment Actions</span>
              </div>
              <div class="text-caption text-grey-6 text-xxs">
                Archive hides from the active list. Delete permanently only after archiving (removes stock; invoices unlink stock).
              </div>
              <div class="row q-gutter-sm q-pt-xs">
                <q-btn
                  v-if="!isCurrentShipmentArchived"
                  outline
                  dense
                  no-caps
                  color="grey-8"
                  icon="ph ph-archive-box"
                  label="Archive"
                  class="col"
                  :loading="archivingLoading"
                  @click="confirmArchiveFromDrawer"
                />
                <q-btn
                  v-else
                  outline
                  dense
                  no-caps
                  color="negative"
                  icon="ph ph-trash"
                  label="Delete permanently"
                  class="col"
                  :loading="deletingLoading"
                  @click="confirmDeleteFromDrawer"
                />
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- 2. Summary Tab Panel -->
        <q-tab-panel name="summary" class="bg-white">
          <div class="column q-gutter-y-md">
            <q-banner v-if="isCostsLockedFlag" dense rounded class="bg-grey-2 text-grey-9">
              Shipment costs are locked. These figures are a snapshot.
            </q-banner>
            <q-banner v-else-if="isStockPostedFlag && canEditCostLines" dense rounded class="bg-orange-1 text-orange-10">
              Stock is in. Changing costs on the Costs tab updates landed cost. Issued invoices keep their snapshot.
            </q-banner>
            <q-banner v-else-if="!hasSummaryCosts" dense rounded class="bg-grey-2 text-grey-8">
              No costs yet. Set freight and product costs on the Costs tab.
            </q-banner>

            <div class="summary-hero q-pa-md rounded-borders">
              <div class="text-xxs text-weight-bold text-grey-6 uppercase" style="letter-spacing: 0.5px">
                Total landed cost
              </div>
              <div class="text-h5 text-weight-bolder font-mono text-primary q-mt-xs">
                {{ formatMoney(currentCostCurrencySymbol, totals.totalCost) }}
              </div>
              <div class="text-caption text-grey-7 q-mt-xs">
                <template v-if="summaryPreviewTransactionRate != null">
                  Line preview rate {{ currentCostCurrencySymbol }}{{ summaryPreviewTransactionRate.toFixed(4) }}
                  / {{ currentPurchaseCurrencySymbol }}
                </template>
                <template v-else>Line preview rate needs product prices and freight</template>
              </div>
            </div>

            <div
              v-if="showPaymentFxSection"
              class="bg-white q-pa-sm rounded-borders border-grey column q-gutter-y-sm"
            >
              <div class="row items-center justify-between">
                <div class="text-xxs text-weight-bold text-grey-6 uppercase" style="letter-spacing: 0.5px">
                  Payment FX (weighted average)
                </div>
                <q-spinner-dots v-if="summaryFinanceLoading" color="primary" size="20px" />
              </div>
              <div class="text-xxs text-grey-7 summary-fx-hint">
                Taka paid ÷ foreign paid on AP bills (weighted).
              </div>
              <div class="summary-fx-grid">
                <div class="summary-fx-card">
                  <div class="summary-fx-card__label">Material</div>
                  <div class="summary-fx-card__rate text-grey-9">
                    <template v-if="materialPaymentFx.hasPayments">
                      {{ currentCostCurrencySymbol }}{{ materialPaymentFx.rate.toFixed(4) }}/{{ currentPurchaseCurrencySymbol }}
                    </template>
                    <template v-else>—</template>
                  </div>
                  <div v-if="materialPaymentFx.hasPayments" class="summary-fx-card__sub">
                    {{ formatMoney(currentCostCurrencySymbol, materialPaymentFx.bdtPaid) }} /
                    {{ formatMoney(currentPurchaseCurrencySymbol, materialPaymentFx.foreignPaid) }}
                  </div>
                </div>
                <div class="summary-fx-card">
                  <div class="summary-fx-card__label">Freight</div>
                  <div class="summary-fx-card__rate text-grey-9">
                    <template v-if="freightPaymentFx.hasPayments">
                      {{ currentCostCurrencySymbol }}{{ freightPaymentFx.rate.toFixed(4) }}/{{ currentPurchaseCurrencySymbol }}
                    </template>
                    <template v-else>—</template>
                  </div>
                  <div v-if="freightPaymentFx.hasPayments" class="summary-fx-card__sub">
                    {{ formatMoney(currentCostCurrencySymbol, freightPaymentFx.bdtPaid) }} /
                    {{ formatMoney(currentPurchaseCurrencySymbol, freightPaymentFx.foreignPaid) }}
                  </div>
                </div>
                <div class="summary-fx-card summary-fx-card--blend">
                  <div class="summary-fx-card__label">Txn blend</div>
                  <div class="summary-fx-card__rate text-primary">
                    <template v-if="paymentTransactionRate != null">
                      {{ currentCostCurrencySymbol }}{{ paymentTransactionRate.toFixed(4) }}/{{ currentPurchaseCurrencySymbol }}
                    </template>
                    <template v-else>—</template>
                  </div>
                  <div v-if="paymentTransactionRate != null" class="summary-fx-card__sub">
                    {{ formatMoney(currentCostCurrencySymbol, paymentBlendBdt) }} /
                    {{ formatMoney(currentPurchaseCurrencySymbol, paymentBlendForeign) }}
                  </div>
                </div>
              </div>
            </div>

            <div class="bg-white rounded-borders border-grey overflow-hidden">
              <div class="summary-cost-row summary-cost-row--head text-xxs text-weight-bold text-grey-6 uppercase">
                <span>Cost file total</span>
                <span class="text-right" />
                <span class="text-right">Amount</span>
              </div>
              <div class="text-xxs text-grey-7 q-px-sm q-pt-sm q-pb-xs">
                Sum of all cost lines on the Costs tab (recorded shipment costs, not cash paid yet).
              </div>
              <div
                v-for="row in costFileBucketRows"
                :key="row.bucket"
                class="summary-cost-row"
              >
                <span class="text-grey-7">{{ row.label }}</span>
                <span />
                <span class="text-right font-mono text-weight-medium text-grey-9">
                  {{ formatMoney(currentCostCurrencySymbol, row.amount) }}
                </span>
              </div>
              <div v-if="costFileBucketRows.length === 0" class="q-pa-sm text-caption text-grey-6">
                No cost lines yet.
              </div>
              <div class="summary-cost-row summary-cost-row--total">
                <span>File total</span>
                <span />
                <span class="text-right font-mono text-primary">
                  {{ formatMoney(currentCostCurrencySymbol, costFileTotal) }}
                </span>
              </div>
            </div>

            <div class="bg-white rounded-borders border-grey overflow-hidden">
              <div class="summary-cost-row summary-cost-row--head text-xxs text-weight-bold text-grey-6 uppercase">
                <span>AP bills</span>
                <span class="text-right">Bill total</span>
                <span class="text-right">Due</span>
              </div>
              <div class="text-xxs text-grey-7 q-px-sm q-pt-sm q-pb-xs">
                One bill per cost bucket after sync. Pay on Bills &amp; Pays to update payment FX above.
              </div>
              <template v-if="summaryFinanceLoading && summaryApBillRows.length === 0">
                <div class="q-pa-md text-center text-caption text-grey-6">Loading bills…</div>
              </template>
              <template v-else-if="summaryApBillRows.length === 0">
                <div class="q-pa-sm text-caption text-grey-6">No AP bills yet. Save costs to sync bills.</div>
              </template>
              <template v-else>
                <div
                  v-for="bill in summaryApBillRows"
                  :key="bill.id"
                  class="summary-ap-bill-row cursor-pointer"
                  role="button"
                  tabindex="0"
                  @click="openApBill(bill.id)"
                  @keyup.enter="openApBill(bill.id)"
                >
                  <div class="column q-gutter-y-2xs min-width-0">
                    <div class="text-caption text-weight-medium text-grey-9 ellipsis">
                      {{ bill.kindLabel }}
                    </div>
                    <div class="text-xxs text-grey-6 ellipsis">
                      {{ bill.invoiceLabel }}
                      <q-chip
                        v-if="bill.statusChip"
                        dense
                        square
                        size="sm"
                        :color="bill.statusChip.color"
                        :text-color="bill.statusChip.textColor"
                        class="q-ml-xs q-ma-none"
                      >
                        {{ bill.statusChip.label }}
                      </q-chip>
                    </div>
                  </div>
                  <span class="text-right font-mono text-caption text-grey-9">
                    {{ formatMoney(currentCostCurrencySymbol, bill.total_amount) }}
                  </span>
                  <span class="text-right font-mono text-caption" :class="displayDueAmount(bill) > 0 ? 'text-orange-9' : 'text-grey-7'">
                    {{ formatMoney(currentCostCurrencySymbol, displayDueAmount(bill)) }}
                  </span>
                </div>
                <div class="summary-ap-bill-row summary-ap-bill-row--total">
                  <span class="text-weight-bold">Bills total</span>
                  <span class="text-right font-mono text-weight-bold">
                    {{ formatMoney(currentCostCurrencySymbol, apBillsGrandTotal) }}
                  </span>
                  <span class="text-right font-mono text-weight-bold text-orange-9">
                    {{ formatMoney(currentCostCurrencySymbol, apBillsDueTotal) }}
                  </span>
                </div>
              </template>
            </div>

            <div class="bg-white q-pa-sm rounded-borders border-grey">
              <div class="text-xxs text-weight-bold text-grey-6 uppercase q-mb-sm" style="letter-spacing: 0.5px">
                Weight
              </div>
              <div class="row q-col-gutter-sm">
                <div class="col-6">
                  <div class="text-xxs text-grey-6">Units</div>
                  <div class="text-caption text-weight-bold font-mono text-grey-9">
                    {{ totals.quantity.toLocaleString() }} pcs
                  </div>
                </div>
                <div class="col-6">
                  <div class="text-xxs text-grey-6">Packaging</div>
                  <div class="text-caption text-weight-bold font-mono text-grey-9">
                    {{ totals.packagingWeightKg.toFixed(2) }} kg
                  </div>
                </div>
                <div class="col-6">
                  <div class="text-xxs text-grey-6">Invoice cargo</div>
                  <div class="text-caption text-weight-bold font-mono text-grey-9">
                    {{ (totals.cargoWeightKg || 0).toFixed(2) }} kg
                  </div>
                  <div class="text-xxs text-grey-5">Used for freight</div>
                </div>
                <div class="col-6">
                  <div class="text-xxs text-grey-6">Box received</div>
                  <div class="text-caption text-weight-bold font-mono text-grey-9">
                    {{ currentShipmentBoxesReceivedTotal.toFixed(2) }} kg
                  </div>
                  <div class="text-xxs text-grey-5">
                    {{ currentShipmentBoxesCount }}
                    {{ currentShipmentBoxesCount === 1 ? 'box' : 'boxes' }}
                  </div>
                </div>
                <div class="col-6">
                  <div class="text-xxs text-grey-6">Box shipping</div>
                  <div class="text-caption text-weight-bold font-mono text-grey-9">
                    {{ currentShipmentBoxesShippingTotal.toFixed(2) }} kg
                  </div>
                </div>
                <div
                  v-if="currentShipmentBoxesCount > 0"
                  class="col-12 q-mt-xs q-pa-sm rounded-borders bg-grey-1 column q-gutter-y-sm"
                >
                  <div>
                    <div class="text-caption text-weight-bold font-mono text-grey-9">
                      {{ boxTotalsNetDiff.formulaLabel }} =
                      {{ boxTotalsNetDiff.signedKgLabel }}
                    </div>
                    <div class="text-xxs text-grey-7 q-mt-2xs">
                      {{ boxTotalsNetDiff.explanation }}
                    </div>
                  </div>
                  <template v-if="invoiceCargoKg > 0">
                    <q-separator />
                    <div class="text-xxs text-weight-bold text-grey-6 uppercase">
                      vs invoice cargo ({{ invoiceCargoKg.toFixed(2) }} kg)
                    </div>
                    <div>
                      <div class="text-caption text-weight-bold font-mono text-grey-9">
                        {{ boxShippingVsInvoice.formulaLabel }} =
                        {{ boxShippingVsInvoice.signedKgLabel }}
                      </div>
                      <div class="text-xxs text-grey-7 q-mt-2xs">
                        {{ boxShippingVsInvoice.explanation }}
                      </div>
                    </div>
                    <div>
                      <div class="text-caption text-weight-bold font-mono text-grey-9">
                        {{ boxReceivedVsInvoice.formulaLabel }} =
                        {{ boxReceivedVsInvoice.signedKgLabel }}
                      </div>
                      <div class="text-xxs text-grey-7 q-mt-2xs">
                        {{ boxReceivedVsInvoice.explanation }}
                      </div>
                    </div>
                  </template>
                </div>
              </div>
              <div
                v-if="weightNeedsAttention"
                class="q-mt-sm text-caption text-orange-9"
              >
                Packaging and invoice cargo weight do not match. Check the Costs tab.
              </div>
            </div>

            <q-banner
              v-if="materialLineListMismatch"
              dense
              rounded
              class="bg-orange-1 text-orange-10"
            >
              Material cost on the Costs tab does not match the line list purchase total.
              Costs {{ formatMoney(currentPurchaseCurrencySymbol, materialCostFileTotal) }}
              · Lines {{ formatMoney(currentPurchaseCurrencySymbol, lineListPurchaseTotal) }}
              · Difference {{ formatSignedMoney(currentPurchaseCurrencySymbol, materialLineListDiff) }}
            </q-banner>

            <div
              v-if="lineListPurchaseTotal > 0 || materialCostFileTotal > 0"
              class="bg-white rounded-borders border-grey overflow-hidden"
            >
              <div class="summary-cost-row summary-cost-row--head text-xxs text-weight-bold text-grey-6 uppercase">
                <span>Purchase totals</span>
                <span />
                <span class="text-right">{{ currentPurchaseCurrencySymbol }}</span>
              </div>
              <div class="text-xxs text-grey-7 q-px-sm q-pt-sm q-pb-xs">
                Line list is sum of purchase price × qty. Material is the product cost on the Costs tab.
              </div>
              <div class="summary-cost-row">
                <span class="text-grey-7">Line list total</span>
                <span />
                <span class="text-right font-mono text-weight-medium text-grey-9">
                  {{ formatMoney(currentPurchaseCurrencySymbol, lineListPurchaseTotal) }}
                </span>
              </div>
              <div class="summary-cost-row">
                <span class="text-grey-7">Material (cost file)</span>
                <span />
                <span
                  class="text-right font-mono text-weight-medium"
                  :class="materialLineListMismatch ? 'text-orange-9' : 'text-grey-9'"
                >
                  {{ formatMoney(currentPurchaseCurrencySymbol, materialCostFileTotal) }}
                </span>
              </div>
            </div>

            <div
              v-if="sectionSummaryRows.length > 0"
              class="bg-white rounded-borders border-grey overflow-hidden"
            >
              <div class="summary-cost-row summary-cost-row--head text-xxs text-weight-bold text-grey-6 uppercase">
                <span>By section</span>
                <span class="text-right">Units</span>
                <span class="text-right">Buy / Landed</span>
              </div>
              <div class="text-xxs text-grey-7 q-px-sm q-pt-sm q-pb-xs">
                Line totals per section (freight allocated by line weight in landed column).
              </div>
              <div
                v-for="row in sectionSummaryRows"
                :key="row.key"
                class="summary-cost-row"
              >
                <span class="column min-width-0">
                  <span class="text-grey-9 text-weight-medium ellipsis">{{ row.title }}</span>
                  <span class="text-xxs text-grey-6">
                    {{ row.itemCount }} {{ row.itemCount === 1 ? 'line' : 'lines' }}
                  </span>
                </span>
                <span class="text-right font-mono text-caption text-grey-9">
                  {{ row.quantity.toLocaleString() }}
                </span>
                <span class="text-right column items-end">
                  <span class="font-mono text-caption text-grey-9">
                    {{ formatMoney(currentPurchaseCurrencySymbol, row.goodsPurchase) }}
                  </span>
                  <span class="font-mono text-caption text-grey-7">
                    {{ formatMoney(currentCostCurrencySymbol, row.goodsLanded) }}
                  </span>
                </span>
              </div>
              <div class="summary-cost-row summary-cost-row--total">
                <span>Shipment total</span>
                <span class="text-right font-mono">
                  {{ sectionSummaryGrand.quantity.toLocaleString() }}
                </span>
                <span class="text-right column items-end">
                  <span class="font-mono">
                    {{ formatMoney(currentPurchaseCurrencySymbol, sectionSummaryGrand.goodsPurchase) }}
                  </span>
                  <span class="font-mono text-primary">
                    {{ formatMoney(currentCostCurrencySymbol, sectionSummaryGrand.goodsLanded) }}
                  </span>
                </span>
              </div>
            </div>

            <div class="bg-white rounded-borders border-grey overflow-hidden">
              <div class="summary-cost-row summary-cost-row--head text-xxs text-weight-bold text-grey-6 uppercase">
                <span>Cost</span>
                <span class="text-right">Buy ({{ currentPurchaseCurrencySymbol }})</span>
                <span class="text-right">Landed ({{ currentCostCurrencySymbol }})</span>
              </div>
              <div class="summary-cost-row">
                <span class="text-grey-7">Product</span>
                <span class="text-right font-mono text-weight-medium text-grey-9">
                  {{ formatMoney(currentPurchaseCurrencySymbol, totals.goodsPurchase) }}
                </span>
                <span class="text-right font-mono text-weight-medium text-grey-9">
                  {{ formatMoney(currentCostCurrencySymbol, totals.goodsCost) }}
                </span>
              </div>
              <div class="summary-cost-row">
                <span class="text-grey-7">Cargo</span>
                <span class="text-right font-mono text-weight-medium text-grey-9">
                  {{ formatMoney(currentPurchaseCurrencySymbol, totals.cargoPurchase) }}
                </span>
                <span class="text-right font-mono text-weight-medium text-grey-9">
                  {{ formatMoney(currentCostCurrencySymbol, totals.cargoCost) }}
                </span>
              </div>
              <div class="summary-courier-row">
                <div class="text-xxs text-weight-bold uppercase" style="letter-spacing: 0.4px">
                  Courier cost in GBP/kg
                </div>
                <div class="text-subtitle1 text-weight-bolder font-mono">
                  <template v-if="courierCostPerKg != null">
                    {{ currentPurchaseCurrencySymbol }}{{ courierCostPerKg.toFixed(4) }}
                    <span class="text-caption text-weight-medium">/ kg</span>
                  </template>
                  <template v-else>—</template>
                </div>
              </div>
              <div class="summary-cost-row summary-cost-row--total">
                <span>Total</span>
                <span class="text-right font-mono">
                  {{ formatMoney(currentPurchaseCurrencySymbol, totals.totalPurchase) }}
                </span>
                <span class="text-right font-mono text-primary">
                  {{ formatMoney(currentCostCurrencySymbol, totals.totalCost) }}
                </span>
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- 3. Costs Tab Panel -->
        <q-tab-panel name="costs" class="bg-white">
          <div class="column q-gutter-y-lg">
            <q-banner v-if="isStockPostedFlag && canEditCostLines" dense rounded class="bg-orange-1 text-orange-10">
              Stock is in. Saving updates landed costs. Invoices already issued keep their cost snapshot.
            </q-banner>
            <q-banner v-if="isCostsLockedFlag" dense rounded class="bg-grey-2 text-grey-9">
              Shipment costs are locked. Costs and weights cannot be changed.
            </q-banner>
            <div class="row items-center justify-between">
              <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
                <q-icon name="ph ph-currency-circle-dollar" size="18px" color="primary" />
                <span>Shipment costs</span>
              </div>
            </div>
            <!-- Total Weight -->
            <div>
              <div class="row items-center justify-between q-mb-xs">
                <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                  Total Weight
                </div>
                <div class="text-caption text-grey-7 font-mono column items-end" style="font-size: 11px">
                  <div v-if="productTotalWeightKg > 0">
                    Lines:
                    <span class="text-weight-bold text-grey-9">{{ productTotalWeightKg.toFixed(2) }} kg</span>
                  </div>
                  <div v-if="currentShipmentBoxesCount > 0">
                    Boxes:
                    <span class="text-weight-bold text-grey-9">
                      {{ currentShipmentBoxesReceivedTotal.toFixed(2) }} recv /
                      {{ currentShipmentBoxesShippingTotal.toFixed(2) }} ship kg
                    </span>
                  </div>
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
                :loading="savingWeight"
                :disable="!canEditCostLines"
                @blur="onTotalWeightBlur"
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

            <div class="column q-gutter-y-sm">
              <div
                class="text-caption text-weight-bold text-grey-7 text-uppercase"
                style="letter-spacing: 0.5px"
              >
                Cost lines
              </div>

              <TfDrawerSectionTabs
                v-model="costBucketFilter"
                :tabs="costBucketSectionTabs"
                ariaLabel="Filter cost lines by bucket"
                count-visibility="positive"
              />

              <div class="row items-center justify-between q-gutter-sm cost-lines-actions q-px-xs">
                <q-btn
                  unelevated
                  no-caps
                  color="primary"
                  icon="ph ph-plus"
                  label="Add cost"
                  size="sm"
                  class="rounded-sq-btn text-weight-bold"
                  :disable="!canEditCostLines"
                  @click="openAddCostDialog"
                />
                <div class="row items-center q-gutter-sm shrink-0">
                  <div
                    class="row items-center q-gutter-xs cost-lines-invoice-status"
                    aria-live="polite"
                  >
                    <span class="text-xxs text-weight-bold text-grey-6 uppercase">Invoice</span>
                    <q-spinner-dots
                      v-if="apBillsLoading"
                      size="14px"
                      color="grey-6"
                    />
                    <template v-else>
                      <span class="text-caption text-weight-medium text-grey-9">
                        {{ activeBucketInvoiceStatus.label }}
                      </span>
                      <q-chip
                        v-if="activeBucketInvoiceStatus.chip"
                        dense
                        square
                        size="sm"
                        :color="activeBucketInvoiceStatus.chip.color"
                        :text-color="activeBucketInvoiceStatus.chip.textColor"
                        class="q-ma-none"
                      >
                        {{ activeBucketInvoiceStatus.chip.label }}
                      </q-chip>
                    </template>
                  </div>
                  <q-btn
                    v-if="canStartMaterialCommercialCredit"
                    outline
                    no-caps
                    color="primary"
                    icon="ph ph-file-minus"
                    size="sm"
                    class="rounded-sq-btn text-weight-bold"
                    label="Commercial credit note"
                    :loading="
                      apBillActionBucket === 'material' && apBillActionKind === 'credit_note'
                    "
                    :disable="apBillsLoading"
                    @click="goToMaterialCommercialCreditNote"
                  >
                    <q-tooltip>
                      Issue an AP credit note on the issued material invoice (shortage / commercial
                      adjustment)
                    </q-tooltip>
                  </q-btn>
                  <q-btn
                    unelevated
                    no-caps
                    color="primary"
                    icon="ph ph-receipt"
                    size="sm"
                    class="rounded-sq-btn text-weight-bold"
                    :label="openBucketBillLabel(costBucketFilter)"
                    :loading="apBillActionBucket === costBucketFilter && apBillActionKind === 'open'"
                    :disable="apBillsLoading || !canUseBucketInvoiceActions"
                    @click="goToBucketBill(costBucketFilter)"
                  >
                    <q-tooltip v-if="!canUseBucketInvoiceActions">
                      Save cost lines with amounts for this bucket first
                    </q-tooltip>
                  </q-btn>
                </div>
              </div>

              <div
                v-if="!hasVisibleCostRows"
                class="text-caption text-grey-6 q-pa-sm rounded-borders bg-grey-1 border-grey"
              >
                No cost lines yet. Use Add cost to record freight, material, customs, and other charges.
              </div>

              <div
                v-else-if="visibleCostRowsInActiveBucket.length === 0"
                class="text-caption text-grey-6 q-pa-sm rounded-borders bg-grey-1 border-grey"
              >
                No lines in this bucket. Add a cost line or pick another bucket.
              </div>

              <div
                v-for="group in costRowDisplayGroups"
                :key="group.bucket"
                class="column q-gutter-y-sm"
              >
                <div
                  v-for="{ row, index: rowIndex, lineNumber } in group.rows"
                  :key="row.localKey"
                  class="q-pa-sm bg-grey-1 rounded-borders border-grey column q-gutter-y-sm"
                >
                <div class="row items-center q-gutter-sm no-wrap">
                  <div class="col-auto cost-line-sl">
                    <span class="text-caption text-weight-bold text-grey-7">{{ lineNumber }}</span>
                  </div>
                  <div class="col min-width-0">
                    <div class="text-caption text-weight-bold text-grey-9">
                      {{ costComponentLabel(row.cost_component) }}
                    </div>
                    <div class="text-caption text-grey-7 font-mono">
                      {{ formatMoney(costRowCurrencySymbol(row), row.amount) }}
                    </div>
                    <div
                      v-if="row.description"
                      class="text-caption text-grey-6 ellipsis"
                    >
                      {{ row.description }}
                    </div>
                  </div>
                  <div class="col-auto row items-center q-gutter-x-xs shrink-0">
                    <q-btn
                      flat
                      round
                      dense
                      size="sm"
                      color="primary"
                      icon="ph ph-pencil-simple"
                      :disable="!canEditCostLines"
                      aria-label="Edit cost line"
                      @click="openEditCostDialog(row)"
                    />
                    <q-btn
                      flat
                      round
                      dense
                      size="sm"
                      color="negative"
                      class="cost-line-delete-btn"
                      :class="{ 'cost-line-delete-btn--holding': deleteHoldKey === row.localKey }"
                      :disable="!canEditCostLines"
                      aria-label="Hold to remove cost line"
                      @click.prevent
                      @mousedown.prevent="startDeleteHold(row.localKey, rowIndex)"
                      @mouseup="cancelDeleteHold"
                      @mouseleave="cancelDeleteHold"
                      @touchstart.prevent="startDeleteHold(row.localKey, rowIndex)"
                      @touchend="cancelDeleteHold"
                      @touchcancel="cancelDeleteHold"
                      @contextmenu.prevent
                    >
                      <q-circular-progress
                        v-if="deleteHoldKey === row.localKey"
                        :value="deleteHoldProgress"
                        size="26px"
                        :thickness="0.22"
                        color="negative"
                        track-color="grey-3"
                        class="cost-line-delete-btn__ring"
                      />
                      <span
                        v-if="deleteHoldKey === row.localKey"
                        class="cost-line-delete-btn__count text-negative text-weight-bold"
                      >
                        {{ deleteHoldSecondsLeft }}
                      </span>
                      <q-icon v-else name="ph ph-trash" size="14px" />
                      <q-tooltip>Hold {{ deleteHoldSecondsTotal }}s to remove</q-tooltip>
                    </q-btn>
                  </div>
                </div>
                </div>
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- 4. Progress Tab Panel -->
        <q-tab-panel name="progress" class="bg-white">
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

        <!-- 6. More Tab Panel -->
        <q-tab-panel name="more" class="bg-white">
          <div class="column q-gutter-y-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
              <q-icon name="ph ph-dots-three-circle" size="18px" color="primary" />
              <span>More tools</span>
            </div>
            <div class="text-caption text-grey-6 text-xxs">
              Open shipment tools on dedicated pages.
            </div>
            <div class="column q-gutter-y-sm">
              <q-btn
                outline
                no-caps
                color="grey-8"
                icon="ph ph-package"
                label="Box Weight"
                class="full-width rounded-sq-btn text-weight-bold"
                @click="goToBoxWeight"
              />
              <q-btn
                outline
                no-caps
                color="grey-8"
                icon="ph ph-barcode"
                label="Batch Code"
                class="full-width rounded-sq-btn text-weight-bold"
                @click="goToBatchCode"
              />
              <q-btn
                v-if="canViewInvestorShipmentShare"
                outline
                no-caps
                color="grey-8"
                icon="ph ph-hand-coins"
                label="Investor investment"
                class="full-width rounded-sq-btn text-weight-bold"
                @click="goToInvestorInvestment"
              />
            </div>
          </div>
        </q-tab-panel>
      </q-tab-panels>
    </div>

    <q-dialog v-model="showAddCostDialog" persistent>
      <q-card style="width: 540px; max-width: 95vw; border-radius: 8px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-primary text-weight-bold">{{ addCostDialogTitle }}</div>
          <q-space />
          <q-btn v-close-popup icon="ph ph-x" flat round dense @click="closeAddCostDialog" />
        </q-card-section>

        <q-card-section class="q-pt-sm q-gutter-y-sm">
          <div class="row q-col-gutter-sm">
            <div class="col-6 col-sm-6">
              <q-select
                v-model="addCostForm.cost_component"
                :options="costComponentOptions"
                emit-value
                map-options
                label="Component"
                dense
                outlined
              />
            </div>
            <div class="col-6 col-sm-6">
              <q-select
                v-model="addCostForm.currency_id"
                :options="addCostCurrencyOptions"
                emit-value
                map-options
                label="Currency *"
                dense
                outlined
                use-input
                input-debounce="150"
                fill-input
                hide-selected
                :error="addCostFormCurrencyError"
                error-message="Currency is required"
                @filter="filterAddCostCurrencies"
              />
            </div>
            <div class="col-6 col-sm-6">
              <q-input
                v-model.number="addCostForm.amount"
                label="Amount *"
                type="number"
                min="0"
                step="0.01"
                dense
                outlined
                autofocus
                placeholder="0.00"
                class="font-mono"
                :prefix="addCostDialogCurrencySymbol"
                :error="addCostFormAmountError"
                error-message="Enter a valid amount"
                @keyup.enter="confirmCostDialog"
              />
            </div>
          </div>

          <q-input
            v-model="addCostForm.description"
            label="Description (optional)"
            dense
            outlined
            placeholder="e.g. Ocean freight, CD/VAT, gate labor"
            @keyup.enter="confirmCostDialog"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat no-caps label="Cancel" color="grey-8" @click="closeAddCostDialog" />
          <q-btn
            unelevated
            no-caps
            color="primary"
            :label="editingCostLocalKey ? 'Save' : 'Add line'"
            class="rounded-sq-btn text-weight-bold"
            :loading="costDialogSaving"
            @click="confirmCostDialog"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import TfDrawerSectionTabsHeader from 'src/components/ui/TfDrawerSectionTabsHeader.vue';
import { ref, computed, watch, unref, onBeforeUnmount } from 'vue';
import { useQuasar } from 'quasar';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { describeBoxTotalsNetDiff, describeBoxVsInvoiceCargo } from '../utils/boxWeightVariance';
import type {
  GlobalShipmentItem,
  ShipmentProgressFlow,
  ShipmentProgressTag,
} from '../repositories/globalShipmentRepository';
import {
  calculateLineLandedCostBdt,
  costingShipmentFromEntries,
  sumProductEntryAmount,
} from 'src/shared/shipment-engine';
import { isShipmentCostsLocked } from '../utils/costEntriesCosting';
import type {
  GlobalShipmentCostBucket,
  GlobalShipmentCostComponent,
  GlobalShipmentCostEntry,
  UpsertShipmentCostEntryPayload,
} from '../types/shipmentCostEntry';
import { DEFAULT_COST_COMPONENT } from '../types/shipmentCostEntry';
import {
  formatGlobalShipmentStatus,
  globalShipmentStatusChipStyle,
} from '../constants/shipmentStatus';
import {
  SHIPMENT_COST_BUCKET_SELECT_OPTIONS,
  SHIPMENT_COST_COMPONENT_SELECT_OPTIONS,
} from '../constants/shipmentCostAxisOptions';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { SHIPMENT_AP_COST_BUCKETS } from '../constants/shipmentApBuckets';
import {
  apBillInvoiceLabel,
  apBillKindLabel,
  apBillStatusChip,
  type ApBillStatusChip,
  billDetailRoute,
  displayDueAmount,
  sumApBillsDue,
  sumApBillsTotal,
} from '../utils/shipmentApBillDisplay';
import { billDetailCommercialCreditRoute } from 'src/modules/bills_pays/utils/billRoutes';
import { shipmentShortageCreditHintBdt } from '../utils/shipmentShortageCreditHint';
import {
  findShipmentApBill,
  shipmentApBillBucket,
  type ShipmentApBillRow,
  type ShipmentApFxSnapshot,
  type ShipmentApKind,
} from '../repositories/shipmentApBillsRepository';

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
  }>(),
  {
    initialTab: 'details',
    progressFlowOptions: () => [],
    progressTagOptions: () => [],
    progressFlowId: null,
    progressTagId: null,
    progressUpdating: false,
    progressTargetId: null,
  },
);

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'update:active-tab', tab: string): void;
  (e: 'update-flow', flowId: number): void;
  (e: 'update-progress', tagId: number | null): void;
}>();

const authStore = useAuthStore();
const { hasModuleAccess } = useModulePermissions();
const canViewInvestorShipmentShare = computed(() =>
  hasModuleAccess('investor_shipment_share', 'view'),
);
const router = useRouter();
const $q = useQuasar();
const shipmentStore = useGlobalShipmentStore();

const isCurrentShipmentArchived = computed(
  () => Boolean(shipmentStore.currentShipment?.is_archived),
);
const activeTab = ref(props.initialTab || 'details');
const settingsTabs = [
  { name: 'details', label: 'Details', icon: 'ph ph-identification-badge' },
  { name: 'summary', label: 'Summary', icon: 'ph ph-chart-pie-slice' },
  { name: 'costs', label: 'Costs', icon: 'ph ph-coins' },
  { name: 'progress', label: 'Progress', icon: 'ph ph-traffic-signal' },
  { name: 'more', label: 'More', icon: 'ph ph-dots-three-outline' },
] as const;
const archivingLoading = ref(false);
const { data: currenciesData } = useGlobalCurrenciesQuery();

const costBucketOptions = SHIPMENT_COST_BUCKET_SELECT_OPTIONS;
const costComponentOptions = SHIPMENT_COST_COMPONENT_SELECT_OPTIONS;

type CostCurrencySelectOption = {
  label: string;
  value: number;
  code: string;
  name: string;
};

const allCurrencyOptions = computed((): CostCurrencySelectOption[] =>
  (currenciesData.value ?? [])
    .filter((c) => c.is_active)
    .map((c) => ({
      label: `${c.code} (${c.symbol}) — ${c.name}`,
      value: c.id,
      code: c.code,
      name: c.name,
    }))
    .sort((a, b) => a.code.localeCompare(b.code)),
);

const addCostCurrencyFilter = ref('');

const addCostCurrencyOptions = computed(() => {
  const needle = addCostCurrencyFilter.value.trim().toLowerCase();
  if (!needle) return allCurrencyOptions.value;
  return allCurrencyOptions.value.filter(
    (o) =>
      o.code.toLowerCase().includes(needle) ||
      o.name.toLowerCase().includes(needle) ||
      o.label.toLowerCase().includes(needle),
  );
});

const filterAddCostCurrencies = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    addCostCurrencyFilter.value = val;
  });
};

const currencySymbolById = computed(() => {
  const map = new Map<number, string>();
  for (const c of currenciesData.value ?? []) {
    map.set(c.id, c.symbol || c.code);
  }
  return map;
});

watch(
  () => [props.modelValue, props.initialTab, props.shipmentId] as const,
  ([isOpen, tab]) => {
    if (isOpen && tab) {
      activeTab.value = tab === 'rates' ? 'costs' : (tab as string);
    }
  },
);

watch(activeTab, (tab) => {
  if (props.modelValue) {
    emit('update:active-tab', tab);
  }
});

const navigateToShipmentPage = (routeName: string) => {
  emit('update:modelValue', false);
  const tenantSlug = authStore.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: routeName,
      params: { tenantSlug, id: props.shipmentId },
    });
    return;
  }
  void router.push({
    name: routeName,
    params: { id: props.shipmentId },
  });
};

const goToBoxWeight = () => {
  navigateToShipmentPage('app-procurement-shipment-box');
};

const goToBatchCode = () => {
  navigateToShipmentPage('app-procurement-shipment-batch-code');
};

const goToInvestorInvestment = () => {
  navigateToShipmentPage('app-procurement-shipment-investor-investment');
};

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
  }).onOk(() => {
    void (async () => {
      archivingLoading.value = true;
      try {
        await shipmentStore.archiveShipment(shipment.id);
        $q.notify({
          type: 'positive',
          message: `Shipment "${shipment.name}" archived successfully.`,
          timeout: 2000,
        });
        emit('update:modelValue', false);
        void router.push({
          name: 'app-procurement-shipment-list',
          params: { tenantSlug: authStore.tenantSlug },
        });
      } catch (err: unknown) {
        $q.notify({
          type: 'negative',
          message: (err as Error).message || 'Failed to archive shipment',
        });
      } finally {
        archivingLoading.value = false;
      }
    })();
  });
};

const deletingLoading = ref(false);

const confirmDeleteFromDrawer = () => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return;
  $q.dialog({
    title: 'Delete Shipment Permanently',
    message: `Delete archived shipment "${shipment.name}" (#${(shipment as any).tenant_shipment_id || shipment.id}) and all warehouse stock? Invoices stay; bill lines will no longer reference that stock.`,
    cancel: {
      flat: true,
      label: 'Cancel',
      noCaps: true,
    },
    ok: {
      unelevated: true,
      color: 'negative',
      label: 'Delete Permanently',
      noCaps: true,
    },
  }).onOk(() => {
    void (async () => {
      deletingLoading.value = true;
      try {
        await shipmentStore.purgeArchivedShipment(shipment.id);
        $q.notify({
          type: 'positive',
          message: `Shipment "${shipment.name}" deleted successfully.`,
          timeout: 2000,
        });
        emit('update:modelValue', false);
        void router.push({
          name: 'app-procurement-shipment-list',
          params: { tenantSlug: authStore.tenantSlug },
        });
      } catch (err: unknown) {
        $q.notify({
          type: 'negative',
          message: (err as Error).message || 'Failed to delete shipment',
        });
      } finally {
        deletingLoading.value = false;
      }
    })();
  });
};

const {
  totals,
  currentShipmentBoxesReceivedTotal,
  currentShipmentBoxesShippingTotal,
  currentShipmentBoxesCount,
  currentPurchaseCurrencySymbol,
  currentCostCurrencySymbol,
  isStockPosted,
  isCostsLocked,
  canEditCosts,
  weightNeedsAttention,
} = props.calculations;

const isCostsLockedFlag = computed(() => Boolean(unref(isCostsLocked)));
const isStockPostedFlag = computed(() => Boolean(unref(isStockPosted)));
const canEditCostsFlag = computed(() => Boolean(unref(canEditCosts)));

/** Plain booleans for Quasar props (nested calculation refs do not always unwrap). */
const canEditCostLines = computed(() => {
  if (isCurrentShipmentArchived.value) return false;
  if (!shipmentStore.currentShipment) return false;
  return canEditCostsFlag.value;
});

const boxTotalsNetDiff = computed(() =>
  describeBoxTotalsNetDiff(
    currentShipmentBoxesReceivedTotal.value,
    currentShipmentBoxesShippingTotal.value,
  ),
);

const invoiceCargoKg = computed(() => {
  const t = totals?.value ?? totals;
  return Number(t?.cargoWeightKg) || 0;
});

const boxShippingVsInvoice = computed(() =>
  describeBoxVsInvoiceCargo(
    'Box shipping',
    currentShipmentBoxesShippingTotal.value,
    invoiceCargoKg.value,
  ),
);

const boxReceivedVsInvoice = computed(() =>
  describeBoxVsInvoiceCargo(
    'Box received',
    currentShipmentBoxesReceivedTotal.value,
    invoiceCargoKg.value,
  ),
);

const formatMoney = (symbol: string, value: number | null | undefined) => {
  const n = Number(value) || 0;
  return `${symbol}${n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
};

const formatSignedMoney = (symbol: string, value: number) => {
  const n = Number(value) || 0;
  const sign = n > 0 ? '+' : n < 0 ? '−' : '';
  return `${sign}${formatMoney(symbol, Math.abs(n))}`;
};

const PURCHASE_TOTAL_TOLERANCE = 0.05;

const lineListPurchaseTotal = computed(() => {
  const t = totals?.value ?? totals;
  return Math.round((Number(t?.goodsPurchase) || 0) * 100) / 100;
});

const materialCostFileTotal = computed(() => {
  let materialBucket = 0;
  for (const entry of shipmentStore.currentCostEntries) {
    if (entry.cost_bucket === 'material') {
      materialBucket += Number(entry.amount) || 0;
    }
  }
  if (materialBucket > 0) {
    return Math.round(materialBucket * 100) / 100;
  }
  return Math.round(sumProductEntryAmount(shipmentStore.currentCostEntries) * 100) / 100;
});

const materialLineListDiff = computed(
  () => Math.round((materialCostFileTotal.value - lineListPurchaseTotal.value) * 100) / 100,
);

const materialLineListMismatch = computed(() => {
  const material = materialCostFileTotal.value;
  const lines = lineListPurchaseTotal.value;
  if (material <= 0) return false;
  return Math.abs(material - lines) > PURCHASE_TOTAL_TOLERANCE;
});

const hasSummaryCosts = computed(() => {
  const t = totals?.value ?? totals;
  return (Number(t?.totalPurchase) || 0) > 0 || (Number(t?.totalCost) || 0) > 0;
});

const summaryPreviewTransactionRate = computed(() => {
  const t = totals?.value ?? totals;
  const rate = t?.transactionRate;
  return rate != null && rate > 0 ? rate : null;
});

const apFxSnapshot = ref<ShipmentApFxSnapshot | null>(null);
const summaryFinanceLoading = ref(false);

const isInternationalShipment = computed(
  () => shipmentStore.currentShipment?.type === 'international',
);

const showPaymentFxSection = computed(() => isInternationalShipment.value);

const materialPaymentFx = computed(() => {
  const m = apFxSnapshot.value?.material;
  const hasPayments = (m?.payment_count ?? 0) > 0;
  return {
    hasPayments,
    rate: m?.conversion_rate ?? shipmentStore.currentShipment?.product_conversion_rate ?? 1,
    bdtPaid: m?.bdt_paid ?? 0,
    foreignPaid: m?.foreign_paid ?? 0,
  };
});

const freightPaymentFx = computed(() => {
  const f = apFxSnapshot.value?.freight;
  const hasPayments = (f?.payment_count ?? 0) > 0;
  return {
    hasPayments,
    rate: f?.conversion_rate ?? shipmentStore.currentShipment?.cargo_conversion_rate ?? 1,
    bdtPaid: f?.bdt_paid ?? 0,
    foreignPaid: f?.foreign_paid ?? 0,
  };
});

const paymentBlendBdt = computed(
  () => (apFxSnapshot.value?.goods_bdt ?? 0) + (apFxSnapshot.value?.freight_bdt ?? 0),
);

const paymentBlendForeign = computed(
  () => (apFxSnapshot.value?.product_foreign ?? 0) + (apFxSnapshot.value?.cargo_foreign ?? 0),
);

const paymentTransactionRate = computed(() => {
  const fromSnapshot = apFxSnapshot.value?.transaction_rate;
  if (fromSnapshot != null && fromSnapshot > 0) return fromSnapshot;
  const fromShipment = shipmentStore.currentShipment?.transaction_rate;
  if (fromShipment != null && fromShipment > 0) return Number(fromShipment);
  if (paymentBlendForeign.value > 0) {
    return paymentBlendBdt.value / paymentBlendForeign.value;
  }
  return null;
});

const costFileBucketRows = computed(() => {
  const sums = new Map<GlobalShipmentCostBucket, number>();
  for (const entry of shipmentStore.currentCostEntries) {
    const bucket = entry.cost_bucket as GlobalShipmentCostBucket;
    sums.set(bucket, (sums.get(bucket) ?? 0) + (Number(entry.amount) || 0));
  }
  return SHIPMENT_AP_COST_BUCKETS.map((bucket) => {
    const amount = sums.get(bucket) ?? 0;
    if (amount <= 0) return null;
    const label = costBucketOptions.find((o) => o.value === bucket)?.label ?? bucket;
    return { bucket, label, amount };
  }).filter((row): row is { bucket: GlobalShipmentCostBucket; label: string; amount: number } =>
    row != null,
  );
});

const costFileTotal = computed(() => {
  let sum = 0;
  for (const entry of shipmentStore.currentCostEntries) {
    sum += Number(entry.amount) || 0;
  }
  return sum;
});

const summaryApBillRows = computed(() => {
  const order = new Map<string, number>();
  SHIPMENT_AP_COST_BUCKETS.forEach((k, i) => order.set(k, i));
  const sorted = [...apBills.value].sort((a, b) => {
    const ak = shipmentApBillBucket(a) ?? '';
    const bk = shipmentApBillBucket(b) ?? '';
    const ai = order.get(ak) ?? 99;
    const bi = order.get(bk) ?? 99;
    return ai - bi;
  });
  return sorted.map((bill) => {
    const statusChip = apBillStatusChip(bill);
    const invoiceLabel = apBillInvoiceLabel(bill);
    return {
      ...bill,
      kindLabel: apBillKindLabel(bill),
      invoiceLabel,
      statusChip,
    };
  });
});

const apBillsGrandTotal = computed(() => sumApBillsTotal(apBills.value));

const apBillsDueTotal = computed(() => sumApBillsDue(apBills.value));

const courierCostPerKg = computed(() => {
  const t = totals?.value ?? totals;
  const kg = t?.cargoWeightKg ?? 0;
  const purchase = t?.cargoPurchase ?? 0;
  if (kg <= 0 || purchase <= 0) return null;
  return Math.round((purchase / kg) * 10000) / 10000;
});

type SectionSummaryRow = {
  key: string;
  title: string;
  itemCount: number;
  quantity: number;
  goodsPurchase: number;
  goodsLanded: number;
};

const effectiveLineSectionId = (
  item: GlobalShipmentItem,
  sections: { id: number }[],
): number | null => {
  const sid = item.section_id ?? null;
  if (sid != null) return sid;
  if (sections.length > 0) return sections[0].id;
  return null;
};

const resolveSummaryLineUnitLandedBdt = (
  item: GlobalShipmentItem,
  allItems: GlobalShipmentItem[],
): number => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) return Number(item.purchase_price) || 0;

  const forCosting = costingShipmentFromEntries(
    shipment,
    shipmentStore.currentCostEntries,
    allItems,
  );

  if (isShipmentCostsLocked(shipment)) {
    const stamped = item.landed_cost_bdt;
    if (stamped != null && Number.isFinite(Number(stamped))) {
      return Number(stamped);
    }
  }

  return calculateLineLandedCostBdt(item, forCosting, allItems);
};

const aggregateSectionSummary = (
  sectionId: number | null,
  title: string,
  items: GlobalShipmentItem[],
  allItems: GlobalShipmentItem[],
): SectionSummaryRow => {
  const matched = items.filter(
    (it) => effectiveLineSectionId(it, shipmentStore.currentShipmentSections ?? []) === sectionId,
  );
  let quantity = 0;
  let goodsPurchase = 0;
  let goodsLanded = 0;
  for (const it of matched) {
    const qty = Number(it.ordered_quantity) || 0;
    quantity += qty;
    goodsPurchase += (Number(it.purchase_price) || 0) * qty;
    goodsLanded += resolveSummaryLineUnitLandedBdt(it, allItems) * qty;
  }
  return {
    key: sectionId == null ? 'main' : String(sectionId),
    title,
    itemCount: matched.length,
    quantity,
    goodsPurchase: Math.round(goodsPurchase * 100) / 100,
    goodsLanded: Math.round(goodsLanded * 100) / 100,
  };
};

const sectionSummaryRows = computed((): SectionSummaryRow[] => {
  const sections = shipmentStore.currentShipmentSections ?? [];
  const items = shipmentStore.currentShipmentItems ?? [];
  if (items.length === 0) return [];

  const rows: SectionSummaryRow[] = [];
  const seen = new Set<number | null>();

  for (const sec of sections) {
    if (seen.has(sec.id)) continue;
    seen.add(sec.id);
    rows.push(
      aggregateSectionSummary(sec.id, sec.title || `Section #${sec.id}`, items, items),
    );
  }

  const hasUnassignedOnly =
    sections.length === 0 && items.every((it) => it.section_id == null);
  if (hasUnassignedOnly) {
    rows.push(aggregateSectionSummary(null, 'Main Order', items, items));
    return rows.filter((r) => r.itemCount > 0);
  }

  const orphanSectionIds = new Set<number>();
  for (const it of items) {
    const sid = it.section_id ?? null;
    if (sid != null && !sections.some((s) => s.id === sid)) {
      orphanSectionIds.add(sid);
    }
  }
  for (const sid of orphanSectionIds) {
    if (seen.has(sid)) continue;
    seen.add(sid);
    rows.push(aggregateSectionSummary(sid, `Section #${sid}`, items, items));
  }

  return rows.filter((r) => r.itemCount > 0);
});

const sectionSummaryGrand = computed(() => {
  const rows = sectionSummaryRows.value;
  return {
    quantity: rows.reduce((s, r) => s + r.quantity, 0),
    goodsPurchase: Math.round(rows.reduce((s, r) => s + r.goodsPurchase, 0) * 100) / 100,
    goodsLanded: Math.round(rows.reduce((s, r) => s + r.goodsLanded, 0) * 100) / 100,
  };
});

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

type ShipmentCostRowDraft = {
  localKey: string;
  dbId: number | null;
  cost_bucket: GlobalShipmentCostBucket;
  cost_component: GlobalShipmentCostComponent;
  currency_id: number | null;
  amount: number | null;
  description: string;
};

const newCostRowKey = () => `cost-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

/** Shipment “buy” currency (purchase), then cost currency fallback — matches AP paper default. */
const defaultCostLineCurrencyId = computed((): number | null => {
  const s = shipmentStore.currentShipment;
  return s?.shipment_purchase_currency_id ?? s?.shipment_cost_currency_id ?? null;
});

const costRowsList = ref<ShipmentCostRowDraft[]>([]);
const costBucketFilter = ref<GlobalShipmentCostBucket>('material');
const savingCosts = ref(false);
const savingWeight = ref(false);

/** Hide header backfill rows with amount 0. */
const isVisibleCostRow = (row: ShipmentCostRowDraft): boolean => {
  if (row.dbId == null) return false;
  const amt = row.amount != null ? Number(row.amount) : NaN;
  return !Number.isNaN(amt) && amt > 0;
};

type AddCostFormDraft = Omit<ShipmentCostRowDraft, 'localKey' | 'dbId' | 'cost_bucket'>;

const showAddCostDialog = ref(false);
const editingCostLocalKey = ref<string | null>(null);
const costDialogSaving = ref(false);
const addCostFormAmountError = ref(false);
const addCostFormCurrencyError = ref(false);
const addCostForm = ref<AddCostFormDraft>({
  cost_component: DEFAULT_COST_COMPONENT,
  currency_id: null,
  amount: null,
  description: '',
});

const costComponentLabel = (component: GlobalShipmentCostComponent): string =>
  costComponentOptions.find((o) => o.value === component)?.label ?? component;

const addCostDialogTitle = computed(() => {
  const bucket =
    (editingCostLocalKey.value
      ? costRowsList.value.find((r) => r.localKey === editingCostLocalKey.value)?.cost_bucket
      : null) ?? costBucketFilter.value;
  const label = costBucketOptions.find((o) => o.value === bucket)?.label ?? bucket;
  return editingCostLocalKey.value ? `Edit cost — ${label}` : `Add cost — ${label}`;
});

const resetAddCostForm = () => {
  addCostForm.value = {
    cost_component: DEFAULT_COST_COMPONENT,
    currency_id: defaultCostLineCurrencyId.value,
    amount: null,
    description: '',
  };
  addCostFormAmountError.value = false;
  addCostFormCurrencyError.value = false;
  addCostCurrencyFilter.value = '';
};

const addCostDialogCurrencySymbol = computed(() =>
  costRowCurrencySymbol({
    localKey: '',
    dbId: null,
    cost_bucket: costBucketFilter.value,
    ...addCostForm.value,
  }),
);

const hasVisibleCostRows = computed(() => costRowsList.value.some(isVisibleCostRow));

const visibleCostRowsInActiveBucket = computed(() =>
  costRowsList.value.filter(
    (row) => row.cost_bucket === costBucketFilter.value && isVisibleCostRow(row),
  ),
);

const costBucketFilterTabs = computed(() =>
  costBucketOptions.map((opt) => ({
    value: opt.value,
    label: opt.label,
    count: costRowsList.value.filter(
      (row) => row.cost_bucket === opt.value && isVisibleCostRow(row),
    ).length,
  })),
);

const costBucketSectionTabs = computed(() =>
  costBucketFilterTabs.value.map((tab) => ({
    name: tab.value,
    label: tab.label,
    count: tab.count,
  })),
);

const costRowDisplayGroups = computed(() => {
  const filter = costBucketFilter.value;

  return [filter]
    .map((bucket) => {
      const bucketLabel =
        costBucketOptions.find((o) => o.value === bucket)?.label ?? bucket;
      const rows = costRowsList.value
        .map((row, index) => ({ row, index }))
        .filter(({ row }) => row.cost_bucket === bucket && isVisibleCostRow(row))
        .map((item, i) => ({ ...item, lineNumber: i + 1 }));
      return { bucket, bucketLabel, rows };
    })
    .filter((g) => g.rows.length > 0);
});

const apBills = ref<ShipmentApBillRow[]>([]);
const apBillsLoading = ref(false);
const apBillActionBucket = ref<ShipmentApKind | null>(null);
const apBillActionKind = ref<'open' | 'credit_note' | null>(null);

const apBillForBucket = (kind: ShipmentApKind) => findShipmentApBill(apBills.value, kind);

const openBucketBillLabel = (kind: ShipmentApKind) => {
  const bill = apBillForBucket(kind);
  if (bill?.invoice_no) return `Open ${bill.invoice_no}`;
  return 'Open invoice';
};

const activeBucketInvoiceStatus = computed(() => {
  const kind = costBucketFilter.value;
  const bill = apBillForBucket(kind);
  if (!bill) {
    const canSync = bucketHasApBillSource(kind);
    return {
      label: canSync ? 'Not synced' : 'No bill',
      chip: canSync
        ? ({ label: 'Pending', color: 'grey-2', textColor: 'grey-8' } satisfies ApBillStatusChip)
        : null,
    };
  }
  if (bill.invoice_status === 'draft') {
    return { label: 'Draft — open bill to issue', chip: null };
  }
  return {
    label: apBillInvoiceLabel(bill),
    chip: apBillStatusChip(bill),
  };
});

/** Saved cost lines or header totals that `sync_shipment_ap_bills` can turn into a bill. */
const bucketHasApBillSource = (bucket: GlobalShipmentCostBucket): boolean => {
  const entries = shipmentStore.currentCostEntries ?? [];
  const hasSavedLines = entries.some(
    (e) =>
      e.cost_bucket === bucket &&
      e.currency_id != null &&
      Number(e.amount) > 0,
  );
  if (hasSavedLines) return true;

  const ship = shipmentStore.currentShipment;
  if (!ship) return false;
  if (bucket === 'material') {
    return Number(ship.purchase_invoice_total) > 0;
  }
  if (bucket === 'freight') {
    return Number(ship.cargo_invoice_total) > 0;
  }
  return false;
};

const canUseBucketInvoiceActions = computed(() => {
  const bucket = costBucketFilter.value;
  if (apBillForBucket(bucket)) return true;
  return bucketHasApBillSource(bucket);
});

const settingsFinanceLoadedForShipmentId = ref<number | null>(null);
const settingsFinanceLoadInFlight = ref(false);
const settingsFinanceRefreshQueued = ref(false);

let settingsFinanceDebounceTimer: ReturnType<typeof setTimeout> | null = null;
let settingsFinanceCooldownUntil = 0;

const refreshSettingsFinanceBundle = async (options?: { force?: boolean }) => {
  const shipmentId = props.shipmentId;
  if (!props.modelValue || !shipmentId || Number.isNaN(shipmentId)) return;
  if (settingsFinanceLoadInFlight.value) {
    if (options?.force) settingsFinanceRefreshQueued.value = true;
    return;
  }
  if (!options?.force && settingsFinanceLoadedForShipmentId.value === shipmentId) return;

  apBillsLoading.value = true;
  summaryFinanceLoading.value = true;
  settingsFinanceLoadInFlight.value = true;
  try {
    const { apBills: bills, apFx } = await shipmentStore.loadSettingsFinanceBundle(shipmentId);
    apBills.value = bills;
    apFxSnapshot.value = apFx;
    settingsFinanceLoadedForShipmentId.value = shipmentId;
    settingsFinanceCooldownUntil = Date.now() + 800;
  } catch (err) {
    console.warn('loadSettingsFinanceBundle failed', err);
    apBills.value = [];
    apFxSnapshot.value = null;
  } finally {
    apBillsLoading.value = false;
    summaryFinanceLoading.value = false;
    settingsFinanceLoadInFlight.value = false;
    if (settingsFinanceRefreshQueued.value) {
      settingsFinanceRefreshQueued.value = false;
      void refreshSettingsFinanceBundle({ force: true });
    }
  }
};

const scheduleSettingsFinanceRefresh = () => {
  if (!props.modelValue || !props.shipmentId || savingCosts.value) return;
  if (settingsFinanceLoadInFlight.value) return;
  if (Date.now() < settingsFinanceCooldownUntil) return;
  if (settingsFinanceDebounceTimer) clearTimeout(settingsFinanceDebounceTimer);
  settingsFinanceDebounceTimer = setTimeout(() => {
    settingsFinanceDebounceTimer = null;
    if (Date.now() < settingsFinanceCooldownUntil) return;
    void refreshSettingsFinanceBundle({ force: true });
  }, 400);
};

watch(
  () => [props.modelValue, props.shipmentId] as const,
  ([open, shipmentId]) => {
    if (!open) {
      settingsFinanceLoadedForShipmentId.value = null;
      return;
    }
    if (!shipmentId) return;
    void refreshSettingsFinanceBundle({ force: true });
  },
);

watch(
  () => shipmentStore.shipmentApBillsSyncGeneration,
  () => {
    if (!props.modelValue) return;
    scheduleSettingsFinanceRefresh();
  },
);

watch(
  () => [
    shipmentStore.currentShipment?.purchase_invoice_total,
    shipmentStore.currentShipment?.cargo_invoice_total,
  ],
  () => scheduleSettingsFinanceRefresh(),
);

const openApBill = (billId: number) => {
  const route = billDetailRoute(billId, authStore.tenantSlug);
  if (route) void router.push(route);
};

const canStartMaterialCommercialCredit = computed(() => {
  if (costBucketFilter.value !== 'material') return false;
  if (!isShipmentCostsLocked(shipmentStore.currentShipment)) return false;
  const bill = apBillForBucket('material');
  return bill?.invoice_status === 'issued';
});

const goToMaterialCommercialCreditNote = async () => {
  apBillActionBucket.value = 'material';
  apBillActionKind.value = 'credit_note';
  try {
    const linked = await ensureBucketApBill('material');
    if (!linked || linked.invoice_status !== 'issued') {
      $q.notify({
        type: 'warning',
        message: 'Issue the material AP invoice after locking costs first.',
        timeout: 2800,
      });
      return;
    }
    const items = shipmentStore.currentShipmentItems ?? [];
    const outcomes = shipmentStore.currentShipmentItemOutcomes ?? [];
    const hint = shipmentShortageCreditHintBdt(items, outcomes);
    const route = billDetailCommercialCreditRoute(linked.id, authStore.tenantSlug ?? undefined, {
      startAdjustment: '1',
      reason: 'Shipment shortage / commercial adjustment',
      ...(hint > 0 ? { suggestedAmount: String(hint) } : {}),
    });
    void router.push(route);
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Could not open bill for credit note',
      timeout: 2800,
    });
  } finally {
    apBillActionBucket.value = null;
    apBillActionKind.value = null;
  }
};

const ensureBucketApBill = async (kind: ShipmentApKind): Promise<ShipmentApBillRow | null> => {
  const linked = findShipmentApBill(apBills.value, kind);
  if (linked) return linked;
  await refreshSettingsFinanceBundle({ force: true });
  return findShipmentApBill(apBills.value, kind);
};

const goToBucketBill = async (kind: ShipmentApKind) => {
  apBillActionBucket.value = kind;
  apBillActionKind.value = 'open';
  try {
    const linked = await ensureBucketApBill(kind);
    if (!linked) {
      $q.notify({
        type: 'warning',
        message: 'No invoice for this bucket yet. Save cost lines with amounts first.',
        timeout: 2500,
      });
      return;
    }
    openApBill(linked.id);
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Could not open invoice',
      timeout: 2500,
    });
  } finally {
    apBillActionBucket.value = null;
    apBillActionKind.value = null;
  }
};

const costRowCurrencySymbol = (row: ShipmentCostRowDraft): string => {
  if (row.currency_id != null) {
    return currencySymbolById.value.get(row.currency_id) ?? currentCostCurrencySymbol.value;
  }
  return currentCostCurrencySymbol.value;
};

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
    void refreshSettingsFinanceBundle({ force: true });

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

type CostEntryRowSource = {
  id: number;
  cost_bucket: GlobalShipmentCostBucket;
  cost_component: GlobalShipmentCostComponent;
  currency_id: number | null;
  amount: number | null;
  description: string | null;
  metadata: Record<string, unknown> | null;
};

const mapEntryToCostRow = (entry: CostEntryRowSource): ShipmentCostRowDraft => {
  const meta = entry.metadata ?? {};
  const legacyNote = typeof meta.note === 'string' ? meta.note : '';
  return {
    localKey: `db_${entry.id}`,
    dbId: entry.id,
    cost_bucket: entry.cost_bucket,
    cost_component: entry.cost_component,
    currency_id: entry.currency_id ?? defaultCostLineCurrencyId.value,
    amount: entry.amount != null ? Number(entry.amount) : null,
    description: entry.description?.trim() || legacyNote,
  };
};

const syncCostsFromStore = () => {
  const entries = shipmentStore.$state.currentCostEntries as unknown as CostEntryRowSource[];
  costRowsList.value = [...entries]
    .map(mapEntryToCostRow)
    .filter(isVisibleCostRow)
    .sort((a, b) => (b.dbId ?? 0) - (a.dbId ?? 0));
};

watch(
  () => shipmentStore.$state.currentShipment?.id,
  () => {
    if (!savingCosts.value) {
      syncCostsFromStore();
    }
  },
  { immediate: true },
);

watch(
  () => shipmentStore.$state.currentCostEntries as unknown as CostEntryRowSource[],
  () => {
    if (!savingCosts.value) {
      syncCostsFromStore();
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

const DELETE_HOLD_MS = 2500;
const deleteHoldSecondsTotal = Math.ceil(DELETE_HOLD_MS / 1000);
const deleteHoldKey = ref<string | null>(null);
const deleteHoldProgress = ref(0);
const deleteHoldTargetIndex = ref<number | null>(null);
let deleteHoldTimer: ReturnType<typeof setInterval> | null = null;
let deleteHoldStartedAt = 0;

const deleteHoldSecondsLeft = computed(() => {
  if (!deleteHoldKey.value) return deleteHoldSecondsTotal;
  const remainingMs = DELETE_HOLD_MS * (1 - deleteHoldProgress.value / 100);
  return Math.max(1, Math.ceil(remainingMs / 1000));
});

const clearDeleteHold = () => {
  if (deleteHoldTimer) {
    clearInterval(deleteHoldTimer);
    deleteHoldTimer = null;
  }
  deleteHoldKey.value = null;
  deleteHoldProgress.value = 0;
  deleteHoldTargetIndex.value = null;
};

const startDeleteHold = (localKey: string, rowIndex: number) => {
  if (!canEditCostLines.value) return;
  clearDeleteHold();
  deleteHoldKey.value = localKey;
  deleteHoldTargetIndex.value = rowIndex;
  deleteHoldStartedAt = Date.now();
  deleteHoldTimer = setInterval(() => {
    const elapsed = Date.now() - deleteHoldStartedAt;
    deleteHoldProgress.value = Math.min(100, (elapsed / DELETE_HOLD_MS) * 100);
    if (elapsed >= DELETE_HOLD_MS) {
      const idx = deleteHoldTargetIndex.value;
      clearDeleteHold();
      if (idx != null) {
        void removeCostRow(idx);
      }
    }
  }, 40);
};

const cancelDeleteHold = () => {
  clearDeleteHold();
};

onBeforeUnmount(() => {
  clearDeleteHold();
  if (settingsFinanceDebounceTimer) clearTimeout(settingsFinanceDebounceTimer);
});

const openAddCostDialog = () => {
  if (!canEditCostLines.value) return;
  editingCostLocalKey.value = null;
  resetAddCostForm();
  showAddCostDialog.value = true;
};

const openEditCostDialog = (row: ShipmentCostRowDraft) => {
  if (!canEditCostLines.value) return;
  editingCostLocalKey.value = row.localKey;
  addCostForm.value = {
    cost_component: row.cost_component,
    currency_id: row.currency_id,
    amount: row.amount,
    description: row.description,
  };
  addCostFormAmountError.value = false;
  addCostFormCurrencyError.value = false;
  showAddCostDialog.value = true;
};

const closeAddCostDialog = () => {
  showAddCostDialog.value = false;
  editingCostLocalKey.value = null;
};

const confirmCostDialog = async () => {
  if (!props.shipmentId || isNaN(props.shipmentId) || costDialogSaving.value) return;
  if (!canEditCostLines.value) return;

  const raw = addCostForm.value.amount;
  const amt = raw != null ? Number(raw) : NaN;
  if (Number.isNaN(amt) || amt < 0) {
    addCostFormAmountError.value = true;
    return;
  }
  addCostFormAmountError.value = false;

  if (addCostForm.value.currency_id == null) {
    addCostFormCurrencyError.value = true;
    return;
  }
  addCostFormCurrencyError.value = false;

  const editingRow = editingCostLocalKey.value
    ? costRowsList.value.find((r) => r.localKey === editingCostLocalKey.value)
    : null;
  const bucket = editingRow?.cost_bucket ?? costBucketFilter.value;
  const roundedAmt = Math.round(amt * 100) / 100;

  const payload: UpsertShipmentCostEntryPayload = {
    shipment_id: props.shipmentId,
    id: editingRow?.dbId ?? null,
    cost_bucket: bucket,
    cost_component: addCostForm.value.cost_component,
    currency_id: addCostForm.value.currency_id,
    amount: roundedAmt,
    description: addCostForm.value.description.trim() || null,
  };

  costDialogSaving.value = true;
  savingCosts.value = true;
  try {
    await shipmentStore.saveCostEntriesBatch(props.shipmentId, [payload], {});
    syncCostsFromStore();
    const wasEdit = editingRow != null;
    closeAddCostDialog();
    $q.notify({
      message: wasEdit ? 'Cost line updated' : 'Cost line added',
      color: 'positive',
      icon: 'ph ph-check-circle',
      timeout: 1000,
    });
  } catch (err: unknown) {
    console.error('Failed to save cost line:', err);
    $q.notify({
      message: 'Failed to save cost line',
      color: 'negative',
      icon: 'ph ph-warning-circle',
      timeout: 1500,
    });
  } finally {
    costDialogSaving.value = false;
    savingCosts.value = false;
  }
};

const removeCostRow = async (index: number) => {
  const removed = costRowsList.value.splice(index, 1)[0];
  if (!removed) return;
  if (removed.dbId) {
    try {
      await shipmentStore.deleteShipmentCostEntry(removed.dbId);
    } catch (err) {
      console.error('Failed to delete cost entry:', err);
      costRowsList.value.splice(index, 0, removed);
      return;
    }
  }
};

const onTotalWeightBlur = () => {
  void saveShipmentWeightIfChanged();
};

const saveShipmentWeightIfChanged = async () => {
  if (!props.shipmentId || isNaN(props.shipmentId) || savingWeight.value) return;
  if (!canEditCostLines.value) return;

  const shipment = shipmentStore.currentShipment;
  const currentWeight = shipment?.total_weight_kg ?? shipment?.received_weight;
  if (totalWeightInput.value === currentWeight) return;

  const nextWeight =
    totalWeightInput.value != null ? Number(totalWeightInput.value) : null;

  savingWeight.value = true;
  try {
    await shipmentStore.saveCostEntriesBatch(props.shipmentId, [], {
      receivedWeight: nextWeight,
      totalWeightKg: nextWeight,
    });
    $q.notify({
      message: 'Weight saved',
      color: 'positive',
      icon: 'ph ph-check-circle',
      timeout: 1000,
    });
  } catch (err: unknown) {
    console.error('Failed to save weight:', err);
    $q.notify({
      message: 'Failed to save weight',
      color: 'negative',
      icon: 'ph ph-warning-circle',
      timeout: 1500,
    });
  } finally {
    savingWeight.value = false;
  }
};

</script>

<style scoped>
.shipment-settings-drawer {
  background: #fff;
  height: 100%;
  min-height: 0;
}

.shipment-settings-drawer__close {
  margin-left: 2px;
}

.cost-line-sl {
  min-width: 1.25rem;
  text-align: center;
  padding-top: 2px;
}

.cost-line-delete-btn {
  width: 28px;
  height: 28px;
  min-height: 28px;
  touch-action: none;
  user-select: none;
}

.cost-line-delete-btn__ring {
  position: absolute;
  inset: 0;
  margin: auto;
}

.cost-line-delete-btn__count {
  position: relative;
  z-index: 1;
  font-size: 11px;
  line-height: 1;
}

.cost-line-delete-btn--holding {
  background: color-mix(in srgb, var(--q-negative) 10%, transparent);
}

.shipment-settings-drawer-panels {
  min-height: 0;
  overflow: hidden;
}

.shipment-settings-drawer-panels :deep(.q-panel-parent) {
  height: 100%;
  min-height: 0;
}

.shipment-settings-drawer-panels :deep(.q-panel.scroll) {
  height: 100%;
  min-height: 0;
}

.shipment-settings-drawer-panels :deep(.q-tab-panel) {
  padding: 12px 14px;
}

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
.summary-hero {
  background: color-mix(in srgb, var(--q-primary) 8%, #fff);
  border: 1px solid #e2e8f0;
}
.summary-cost-row {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr) minmax(0, 1fr);
  gap: 8px;
  align-items: center;
  padding: 10px 12px;
  border-top: 1px solid #e2e8f0;
  font-size: 13px;
}
.summary-cost-row--head {
  border-top: none;
  background: #f8fafc;
  padding: 8px 12px;
}
.summary-cost-row--total {
  background: #f8fafc;
  font-weight: 700;
  color: #1e293b;
}
.summary-courier-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 12px;
  background: #e6f4f1;
  border-top: 1px solid #b8ddd6;
  color: #0f766e;
}
.summary-fx-hint {
  line-height: 1.3;
  margin-bottom: -2px;
}
.summary-fx-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 6px;
  align-items: start;
}
.summary-fx-card {
  padding: 6px 8px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
  min-width: 0;
}
.summary-fx-card__label {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #64748b;
  line-height: 1.2;
}
.summary-fx-card__rate {
  font-family: monospace;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.25;
  margin-top: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.summary-fx-card__sub {
  font-size: 10px;
  line-height: 1.2;
  color: #64748b;
  margin-top: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.summary-fx-card--blend {
  background: color-mix(in srgb, var(--q-primary) 6%, #fff);
  border-color: color-mix(in srgb, var(--q-primary) 22%, #e2e8f0);
}
.summary-ap-bill-row {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr) minmax(0, 1fr);
  gap: 8px;
  align-items: center;
  padding: 10px 12px;
  border-top: 1px solid #e2e8f0;
}
.summary-ap-bill-row--total {
  background: #f8fafc;
  font-size: 13px;
}
.summary-ap-bill-row:hover {
  background: var(--tf-hover-bg);
}
</style>
