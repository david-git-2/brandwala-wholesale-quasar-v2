<template>
  <div class="catalog-items-table column no-wrap col">
    <div class="row items-center justify-between q-px-md q-py-sm catalog-toolbar border-bottom shrink-0">
      <div class="row items-center q-gutter-sm">
        <q-btn
          v-if="canDeleteLines && (selectedLineIds?.length ?? 0) > 0"
          dense
          outline
          no-caps
          color="negative"
          size="sm"
          icon="ph ph-trash"
          :label="t('shop_admin.remove_selected_lines')"
          @click="emit('remove-selected-lines')"
        />
      </div>
      <q-btn flat round dense size="sm" color="grey-8" icon="ph ph-funnel" aria-label="Quantity filter">
        <q-tooltip>{{ quantityFilterTooltip }}</q-tooltip>
        <q-menu anchor="bottom right" self="top right">
            <q-list dense style="min-width: 168px">
              <q-item
                v-for="opt in quantityFilterOptions"
                :key="opt.value"
                v-close-popup
                clickable
                :active="quantityFilter === opt.value"
                active-class="bg-grey-2 text-weight-medium"
                @click="quantityFilter = opt.value"
              >
                <q-item-section avatar class="catalog-qty-filter-check">
                  <q-icon
                    v-if="quantityFilter === opt.value"
                    name="ph ph-check"
                    size="16px"
                    color="primary"
                  />
                </q-item-section>
                <q-item-section>{{ opt.label }}</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
      </q-btn>
    </div>

    <div
      ref="tableScrollContainerRef"
      class="col overflow-auto hide-native-scrollbar catalog-table-scroll"
      @scroll="onTableScroll"
    >
        <table class="pbc-v2-markup-table bg-white" style="min-width: 1100px; width: 100%">
        <thead>
          <tr class="text-weight-bold catalog-table-header">
            <th
              v-if="canDeleteLines"
              class="text-center sticky-col-select pbc-select-col q-pa-none"
              style="width: 30px; min-width: 30px"
            >
              <q-checkbox
                dense
                size="xs"
                :model-value="allFilteredRowsSelected"
                :disable="filteredRows.length === 0"
                color="primary"
                :aria-label="t('shop_admin.select_lines_hint')"
                @update:model-value="toggleSelectAllFiltered"
              />
            </th>
            <th
              v-if="isColVisible('sl')"
              class="text-center sticky-col-2 pbc-sl-col q-pa-none"
              :class="{ 'sticky-col-2--offset': canDeleteLines }"
              style="width: 36px; min-width: 36px"
            >
              SL
            </th>
            <th v-if="isColVisible('image')" class="text-center pbc-image-col" style="width: 0.85in; min-width: 0.85in">Image</th>
            <th v-if="isColVisible('name')" class="text-left" style="min-width: 180px; width: 180px">Name</th>
            <th
              v-if="isColVisible('qty_confirmed')"
              class="text-center tf-ops-col-tint--qty"
              style="width: 72px; min-width: 72px"
            >
              Confirmed<br />Qty
            </th>
            <th
              v-if="isColVisible('delivery_papers')"
              class="text-left"
              style="min-width: 200px; width: 240px"
            >
              Delivery papers
            </th>
            <th v-if="isColVisible('brand')" class="text-center" style="width: 90px; min-width: 90px">Brand</th>
            <th v-if="isColVisible('note')" class="text-center" style="width: 72px; min-width: 72px">Note</th>
            <th v-if="isColVisible('code_barcode_id')" class="text-left" style="width: 130px; min-width: 130px">Codes</th>
            <th v-if="isColVisible('qty_customer')" class="text-center tf-ops-col-tint--qty" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('qty_customer', 'Qty') }}</span>
            </th>
            <th v-if="isColVisible('purchase_price_unit')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('purchase_price_unit', 'Price') }}</span>
            </th>
            <th v-if="isColVisible('purchase_price_total')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('purchase_price_total', 'Total') }}</span>
            </th>
            <th v-if="isColVisible('product_weight_gm')" class="text-center tf-ops-col-tint--weight" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('product_weight_gm', 'Product Wt') }}</span>
            </th>
            <th v-if="isColVisible('package_weight_gm')" class="text-center tf-ops-col-tint--weight" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('package_weight_gm', 'Pkg Wt') }}</span>
            </th>
            <th v-if="isColVisible('total_weight_gm')" class="text-center tf-ops-col-tint--weight" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('total_weight_gm', 'Total Wt') }}</span>
            </th>
            <th v-if="isColVisible('cargo_rate')" class="text-center" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('cargo_rate', 'Cargo') }}</span>
            </th>
            <th v-if="isColVisible('cargo_cost_unit_purchase')" class="text-center" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('cargo_cost_unit_purchase', 'Cargo Cost') }}</span>
            </th>
            <th v-if="isColVisible('landed_cost_unit_purchase')" class="text-center tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('landed_cost_unit_purchase', 'Cost') }}</span>
            </th>
            <th v-if="isColVisible('landed_cost_row_purchase')" class="text-center tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('landed_cost_row_purchase', 'Row') }}</span>
            </th>
            <th v-if="isColVisible('landed_cost_unit_sell')" class="text-center tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('landed_cost_unit_sell', 'Cost') }}</span>
            </th>
            <th v-if="isColVisible('landed_cost_row_sell')" class="text-center tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('landed_cost_row_sell', 'Row') }}</span>
            </th>
            <th v-if="isColVisible('first_offer_unit')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('first_offer_unit', '1st Offer') }}</span>
            </th>
            <th v-if="isColVisible('first_offer_row')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('first_offer_row', 'Row') }}</span>
            </th>
            <th v-if="isColVisible('first_offer_margin')" class="text-center" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('first_offer_margin', 'Margin') }}</span>
            </th>
            <th v-if="isColVisible('counter_offer_unit')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('counter_offer_unit', 'Counter') }}</span>
            </th>
            <th v-if="isColVisible('counter_offer_row')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('counter_offer_row', 'Row') }}</span>
            </th>
            <th v-if="isColVisible('counter_offer_margin')" class="text-center" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('counter_offer_margin', 'Margin') }}</span>
            </th>
            <th v-if="isColVisible('final_offer_unit')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('final_offer_unit', 'Final') }}</span>
            </th>
            <th v-if="isColVisible('final_offer_row')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('final_offer_row', 'Row') }}</span>
            </th>
            <th v-if="isColVisible('final_offer_margin')" class="text-center" style="width: 56px; min-width: 56px">
              <span class="header-label-wrap">{{ formatTableHeaderLabel('final_offer_margin', 'Margin') }}</span>
            </th>
            <th v-if="isColVisible('status')" class="text-center" style="width: 65px; min-width: 65px">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, rowIndex) in filteredRows" :key="row.id" class="pbc-row">
            <td
              v-if="canDeleteLines"
              class="text-center sticky-col-select pbc-select-col q-pa-none"
              style="width: 30px; min-width: 30px"
              @click.stop
            >
              <q-checkbox
                dense
                size="xs"
                :model-value="isLineSelected(row.id)"
                color="primary"
                :aria-label="t('shop_admin.select_lines_hint')"
                @update:model-value="(v: boolean) => toggleLineSelected(row.id, v)"
              />
            </td>
            <!-- 1. SL -->
            <td
              v-if="isColVisible('sl')"
              class="text-center text-weight-bold sticky-col-2 pbc-sl-col font-mono"
              :class="{ 'sticky-col-2--offset': canDeleteLines }"
              style="width: 36px; min-width: 36px"
            >
              {{ rowIndex + 1 }}
            </td>

            <!-- 2. Image (1 Inch = 96px x 96px) -->
            <td v-if="isColVisible('image')" class="text-center pbc-image-cell" style="width: 0.85in; min-width: 0.85in">
              <SmartImage
                :src="row.image_url"
                :alt="row.name || 'Product image'"
                img-class="pbc-row-img"
                fallback-class="pbc-row-img-placeholder"
              />
            </td>

            <!-- 3. Name (Wrapped) -->
            <td v-if="isColVisible('name')" class="col-name-wrap text-left" style="min-width: 180px; width: 180px">
              <div class="name-cell-wrap row items-start no-wrap q-gutter-x-xs">
                <div class="col name-cell-text text-weight-bold text-grey-9 text-body2">
                  {{ row.name }}
                </div>
                <q-btn
                  flat
                  round
                  dense
                  icon="ph ph-copy"
                  size="xs"
                  color="grey-7"
                  class="col-auto name-copy-btn"
                  @click.stop="handleCopy(row.name, 'Name')"
                >
                  <q-tooltip>Copy Item Name</q-tooltip>
                </q-btn>
              </div>
            </td>

            <td
              v-if="isColVisible('qty_confirmed')"
              class="text-center text-weight-bold font-mono tf-ops-col-tint--qty"
              style="width: 72px; min-width: 72px"
            >
              {{ getConfirmedQty(row) }}
            </td>

            <td v-if="isColVisible('delivery_papers')" class="catalog-dispatch-papers-cell text-left">
              <q-spinner-dots
                v-if="deliveryPaperQtyLoading"
                size="16px"
                color="primary"
              />
              <span v-else-if="deliveryPaperQtyError" class="text-caption text-negative">
                Could not load
              </span>
              <div
                v-else-if="entriesForOrderItem(row.id).length"
                class="column q-gutter-y-xs"
              >
                <button
                  v-for="entry in entriesForOrderItem(row.id)"
                  :key="entry.delivery_paper_id"
                  type="button"
                  class="catalog-dispatch-paper-chip column items-stretch"
                  @click="openDeliveryPaper(entry.delivery_paper_id)"
                >
                  <div class="row items-center no-wrap q-gutter-x-xs catalog-dispatch-paper-chip__head">
                    <span class="font-mono text-caption text-weight-bold">DP-{{ entry.delivery_paper_id }}</span>
                    <TfStatusBadge
                      class="catalog-dispatch-paper-chip__status"
                      :status="entry.paper_status"
                      :label="entry.paper_status"
                    />
                  </div>
                  <div class="row items-center wrap catalog-dispatch-paper-chip__metrics">
                    <span class="catalog-dispatch-paper-chip__metric">
                      <span class="catalog-dispatch-paper-chip__lbl">Pk</span>
                      <span class="catalog-dispatch-paper-chip__val">{{
                        catalogOrderDeliveryPaperPackedDisplay(entry)
                      }}</span>
                    </span>
                    <span class="catalog-dispatch-paper-chip__metric">
                      <span class="catalog-dispatch-paper-chip__lbl">Ac</span>
                      <span class="catalog-dispatch-paper-chip__val">{{ entry.accepted_qty }}</span>
                    </span>
                    <span class="catalog-dispatch-paper-chip__metric">
                      <span class="catalog-dispatch-paper-chip__lbl">Cd</span>
                      <span class="catalog-dispatch-paper-chip__val">{{ entry.conditioned_qty }}</span>
                    </span>
                    <span class="catalog-dispatch-paper-chip__metric">
                      <span class="catalog-dispatch-paper-chip__lbl">Rt</span>
                      <span class="catalog-dispatch-paper-chip__val">{{ entry.rejected_qty }}</span>
                    </span>
                  </div>
                </button>
              </div>
              <span v-else class="text-caption text-grey-6">—</span>
            </td>

            <!-- 4. Brand -->
            <td v-if="isColVisible('brand')" class="text-center col-brand">
              <div class="brand-cell">
                <q-badge outline color="blue-grey-8" class="text-caption font-mono">
                  {{ row.brand || '—' }}
                </q-badge>
              </div>
            </td>

            <!-- 5. Note -->
            <td v-if="isColVisible('note')" class="text-caption text-grey-7 text-center col-info-meta">
              {{ row.note || '—' }}
            </td>

            <!-- 6. Code / Barcode / Product ID -->
            <td v-if="isColVisible('code_barcode_id')" class="col-code-barcode">
              <div class="column q-gutter-y-2xs font-mono text-caption items-center">
                <div
                  v-if="row.barcode"
                  class="row items-center justify-center no-wrap q-gutter-x-xs"
                >
                  <span class="text-weight-medium text-grey-9">
                    <q-icon name="ph ph-barcode" size="14px" /> {{ row.barcode }}
                  </span>
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-copy"
                    size="xs"
                    color="grey-7"
                    class="name-copy-btn"
                    @click.stop="handleCopy(row.barcode, 'Barcode')"
                  >
                    <q-tooltip>Copy Barcode</q-tooltip>
                  </q-btn>
                </div>
                <div
                  v-if="row.sku"
                  class="row items-center justify-center no-wrap q-gutter-x-xs"
                >
                  <span class="text-grey-7">SKU: {{ row.sku }}</span>
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-copy"
                    size="xs"
                    color="grey-7"
                    class="name-copy-btn"
                    @click.stop="handleCopy(row.sku, 'SKU')"
                  >
                    <q-tooltip>Copy SKU</q-tooltip>
                  </q-btn>
                </div>
                <div
                  v-if="row.product_id"
                  class="row items-center justify-center no-wrap q-gutter-x-xs"
                >
                  <span class="text-grey-6 text-2xs">ID: #{{ row.product_id }}</span>
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-copy"
                    size="xs"
                    color="grey-7"
                    class="name-copy-btn"
                    @click.stop="handleCopy(String(row.product_id), 'Product ID')"
                  >
                    <q-tooltip>Copy Product ID</q-tooltip>
                  </q-btn>
                </div>
              </div>
            </td>

            <!-- 7. Qty (Customer) -->
            <td v-if="isColVisible('qty_customer')" class="text-center text-weight-bold font-mono tf-ops-col-tint--qty" style="width: 56px; min-width: 56px">
              {{ row.quantity }}
            </td>

            <!-- 8. Purchase Price Unit -->
            <td v-if="isColVisible('purchase_price_unit')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span
                v-if="isFirstOfferLocked"
                class="font-mono text-weight-bold text-green-10"
              >
                {{ formatAmount(row.cost_price_amount || 0) }}
              </span>
              <q-input
                v-else
                v-model.number="row.cost_price_amount"
                type="number"
                dense
                outlined
                hide-bottom-space
                input-class="text-center font-mono text-weight-bold text-green-10"
                class="inline-edit-input excel-cell-input"
                style="max-width: 56px"
                min="0"
                step="0.01"
                @blur="onItemCostBlur(row)"
                @keyup.enter="blurInput"
              />
            </td>

            <!-- 11. Total Purchase Price -->
            <td v-if="isColVisible('purchase_price_total')" class="text-center font-mono text-weight-bold text-grey-9 tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              {{ formatAmount((row.cost_price_amount || 0) * row.quantity) }}
            </td>

            <!-- 12. Product Weight (gm) -->
            <td v-if="isColVisible('product_weight_gm')" class="text-center font-mono tf-ops-col-tint--weight" style="width: 56px; min-width: 56px">
              <span v-if="isStaffReadOnly" class="font-mono">
                {{ Math.round(row.product_weight_gm ?? getProductWeightGm(row)) }}
              </span>
              <q-input
                v-else
                :model-value="row.product_weight_gm ?? getProductWeightGm(row)"
                type="number"
                dense
                outlined
                hide-bottom-space
                input-class="text-center font-mono"
                class="inline-edit-input excel-cell-input"
                style="max-width: 56px"
                min="0"
                step="1"
                @update:model-value="(val) => { row.product_weight_gm = Number(val) || 0; }"
                @focus="clearZeroOnFocus(row, 'product_weight_gm')"
                @blur="onItemProductWeightBlur(row)"
                @keyup.enter="blurInput"
              />
            </td>

            <!-- 13. Package Weight (gm) -->
            <td v-if="isColVisible('package_weight_gm')" class="text-center font-mono tf-ops-col-tint--weight" style="width: 56px; min-width: 56px">
              <span v-if="isStaffReadOnly" class="font-mono">
                {{ Math.round(row.package_weight_gm ?? getPackageWeightGm(row)) }}
              </span>
              <q-input
                v-else
                :model-value="row.package_weight_gm ?? getPackageWeightGm(row)"
                type="number"
                dense
                outlined
                hide-bottom-space
                input-class="text-center font-mono"
                class="inline-edit-input excel-cell-input"
                style="max-width: 56px"
                min="0"
                step="1"
                @update:model-value="(val) => { row.package_weight_gm = Number(val) || 0; }"
                @focus="clearZeroOnFocus(row, 'package_weight_gm')"
                @blur="onItemPackageWeightBlur(row)"
                @keyup.enter="blurInput"
              />
            </td>

            <!-- 14. Total Weight (gm) -->
            <td v-if="isColVisible('total_weight_gm')" class="text-center font-mono text-caption text-grey-9 tf-ops-col-tint--weight" style="width: 56px; min-width: 56px">
              {{ Math.round(getTotalWeightGm(row)) }} g
            </td>

            <!-- 15. Cargo Rate -->
            <td v-if="isColVisible('cargo_rate')" class="text-center font-mono text-grey-8 text-caption" style="width: 56px; min-width: 56px">
              {{ cargoRate.toFixed(2) }} /kg
            </td>

            <!-- 16. Cargo Cost (Purchase Currency) / Unit -->
            <td v-if="isColVisible('cargo_cost_unit_purchase')" class="text-center font-mono text-weight-medium text-caption" style="width: 56px; min-width: 56px">
              {{ formatAmount(getCargoCostUnitPurchase(row)) }}
            </td>

            <!-- 17. Total Cost (Purchase Cost) / Unit -->
            <td v-if="isColVisible('landed_cost_unit_purchase')" class="text-center font-mono text-weight-bold text-grey-9 tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              {{ formatAmount(getLandedCostUnitPurchase(row)) }}
            </td>

            <!-- 18. Row Total Cost (Purchase) -->
            <td v-if="isColVisible('landed_cost_row_purchase')" class="text-center font-mono text-weight-bold text-grey-9 tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              {{ formatAmount(getLandedCostRowPurchase(row)) }}
            </td>

            <!-- 19. Cost (Selling Currency) / Unit -->
            <td v-if="isColVisible('landed_cost_unit_sell')" class="text-center font-mono text-weight-bold text-grey-9 tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              {{ formatAmount(getLandedCostUnitSell(row)) }}
            </td>

            <!-- 20. Row Total Cost (Selling Currency) -->
            <td v-if="isColVisible('landed_cost_row_sell')" class="text-center font-mono text-weight-bold text-grey-9 tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              {{ formatAmount(getLandedCostRowSell(row)) }}
            </td>

            <!-- 21. First Offer Unit (Selling Currency) -->
            <td v-if="isColVisible('first_offer_unit')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span
                v-if="isFirstOfferLocked"
                class="text-deep-purple-9 text-weight-bold font-mono"
              >
                {{ formatAmount(getFirstOfferUnitAmount(row)) }}
              </span>
              <div v-else class="row items-center justify-center no-wrap q-gutter-x-xs">
                <q-icon
                  v-if="row.is_first_offer_manual"
                  name="ph ph-lock-key"
                  color="amber-8"
                  size="16px"
                  class="q-mr-xs"
                >
                  <q-tooltip>First offer price manually locked — won't auto-recalculate</q-tooltip>
                </q-icon>

                <q-input
                  :model-value="getFirstOfferUnitAmount(row)"
                  type="number"
                  dense
                  outlined
                hide-bottom-space
                  input-class="text-center text-deep-purple-9 text-weight-bold font-mono"
                  class="inline-edit-input excel-cell-input"
                  style="max-width: 96px"
                  min="0"
                  step="1"
                  @update:model-value="(val) => onFirstOfferManualUpdate(row, val)"
                  @blur="onFirstOfferBlur(row)"
                  @keyup.enter="blurInput"
                />

                <q-btn
                  v-if="row.is_first_offer_manual"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-arrows-clockwise"
                  color="grey-7"
                  class="q-ml-xs"
                  @click.stop="onUnlockFirstOffer(row)"
                >
                  <q-tooltip>Unlock & reset to auto price</q-tooltip>
                </q-btn>
              </div>
            </td>

            <!-- 22. First Offer Row Total -->
            <td v-if="isColVisible('first_offer_row')" class="text-center font-mono text-weight-bold text-grey-9 tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              {{ formatAmount(getFirstOfferUnitAmount(row) * row.quantity) }}
            </td>

            <!-- 23. First Offer Margin % -->
            <td v-if="isColVisible('first_offer_margin')" class="text-center font-mono text-weight-bold" style="width: 56px; min-width: 56px" :class="getMarginColorClass(getFirstOfferMargin(row))">
              {{ getFirstOfferMargin(row).toFixed(1) }}%
            </td>

            <!-- 24. Counter Offer Unit -->
            <td v-if="isColVisible('counter_offer_unit')" class="text-center font-mono text-weight-bold text-orange-9 tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              {{ row.customer_offer_amount != null ? formatAmount(row.customer_offer_amount) : '—' }}
            </td>

            <!-- 25. Counter Offer Row Total -->
            <td v-if="isColVisible('counter_offer_row')" class="text-center font-mono text-weight-bold text-orange-8 tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              {{ row.customer_offer_amount != null ? formatAmount(row.customer_offer_amount * row.quantity) : '—' }}
            </td>

            <!-- 26. Counter Offer Margin % -->
            <td v-if="isColVisible('counter_offer_margin')" class="text-center font-mono text-weight-bold" style="width: 56px; min-width: 56px" :class="getMarginColorClass(getCounterOfferMargin(row))">
              {{ row.customer_offer_amount != null ? `${getCounterOfferMargin(row).toFixed(1)}%` : '—' }}
            </td>

            <!-- 27. Final Offer Unit -->
            <td v-if="isColVisible('final_offer_unit')" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <span
                v-if="!isFinalOfferEditable"
                class="text-green-10 text-weight-bold font-mono"
              >
                {{ formatAmount(getFinalOfferUnitAmount(row)) }}
              </span>
              <div v-else class="row items-center justify-center no-wrap q-gutter-x-xs">
                <q-icon
                  v-if="row.is_final_offer_manual"
                  name="ph ph-lock-key"
                  color="amber-8"
                  size="16px"
                  class="q-mr-xs"
                >
                  <q-tooltip>Final offer price manually locked — won't auto-recalculate</q-tooltip>
                </q-icon>

                <q-input
                  :model-value="getFinalOfferUnitAmount(row)"
                  type="number"
                  dense
                  outlined
                hide-bottom-space
                  input-class="text-center text-green-10 text-weight-bold font-mono"
                  class="inline-edit-input excel-cell-input"
                  style="max-width: 96px"
                  min="0"
                  step="1"
                  @update:model-value="(val) => { row.final_price_amount = Number(val) || 0; }"
                  @blur="onFinalOfferBlur(row)"
                  @keyup.enter="blurInput"
                />

                <q-btn
                  v-if="row.is_final_offer_manual"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-arrows-clockwise"
                  color="grey-7"
                  class="q-ml-xs"
                  @click.stop="onUnlockFinalOffer(row)"
                >
                  <q-tooltip>Unlock & reset to auto price</q-tooltip>
                </q-btn>
              </div>
            </td>

            <!-- 28. Final Offer Row Total -->
            <td v-if="isColVisible('final_offer_row')" class="text-center font-mono text-weight-bold text-positive tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              {{ formatAmount(getFinalOfferUnitAmount(row) * row.quantity) }}
            </td>

            <!-- 29. Final Offer Margin % -->
            <td v-if="isColVisible('final_offer_margin')" class="text-center font-mono text-weight-bold" style="width: 56px; min-width: 56px" :class="getMarginColorClass(getFinalOfferMargin(row))">
              {{ `${getFinalOfferMargin(row).toFixed(1)}%` }}
            </td>

            <!-- 30. Status -->
            <td v-if="isColVisible('status')" class="text-center" style="width: 65px; min-width: 65px">
              <q-chip dense outline :color="getItemStatusColor(row)" class="text-caption text-weight-bold status-chip">
                {{ getItemStatusLabel(row) }}
              </q-chip>
            </td>

          </tr>
        </tbody>
      </table>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useQuasar, copyToClipboard } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCatalogOrderDeliveryPaperQtyByItem } from '../composables/useCatalogOrderDeliveryPaperQtyByItem';
import { catalogOrderDeliveryPaperPackedDisplay } from '../types/catalogOrderDeliveryPaperQty';
import type { ShopOrder, ShopOrderItem } from '../types';
import {
  getProductWeightGm as catalogGetProductWeightGm,
  getPackageWeightGm as catalogGetPackageWeightGm,
  getTotalWeightGm as catalogGetTotalWeightGm,
  getCargoCostUnitPurchase as catalogGetCargoCostUnitPurchase,
  getLandedCostUnitPurchase as catalogGetLandedCostUnitPurchase,
  getLandedCostRowPurchase as catalogGetLandedCostRowPurchase,
  getLandedCostUnitSell as catalogGetLandedCostUnitSell,
  getLandedCostRowSell as catalogGetLandedCostRowSell,
  calculateItemFirstOfferPrice,
  getFirstOfferMargin as catalogGetFirstOfferMargin,
  getCounterOfferMargin as catalogGetCounterOfferMargin,
  getFinalOfferUnitAmount as catalogGetFinalOfferUnitAmount,
  getFinalOfferMargin as catalogGetFinalOfferMargin,
} from '../utils/catalogPricingUtils';
import { normalizeCatalogOrderStatus, isCatalogFirstOfferLocked, isCatalogFinalOfferEditable, isCatalogStaffReadOnly, getCatalogItemNegotiationStatusLabel } from '../utils/catalogOrderStatus';

const props = withDefaults(
  defineProps<{
  order: ShopOrder | null;
  items: ShopOrderItem[];
  currencySymbol?: string;
  buyCurrencySymbol?: string;
  visibleColumns?: string[];
  /** Show row checkboxes and header select-all for staff line removal */
  canDeleteLines?: boolean;
  /** Selected order_item ids (v-model) */
  selectedLineIds?: number[];
}>(),
  {
    canDeleteLines: false,
    selectedLineIds: () => [],
  },
);

const emit = defineEmits<{
  (e: 'open-column-selector'): void;
  (e: 'update:visible-columns', columns: string[]): void;
  (e: 'table-scroll'): void;
  (e: 'load-more-items'): void;
  (e: 'remove-selected-lines'): void;
  (e: 'update:selectedLineIds', ids: number[]): void;
  (
    e: 'update-item',
    payload: {
      itemId: number;
      productId: number | null;
      payload: {
        product_weight_gm?: number | null | undefined;
        package_weight_gm?: number | null | undefined;
        weight_kg?: number | null | undefined;
        cost_price_amount?: number | null | undefined;
        staff_offer_amount?: number | null | undefined;
        is_first_offer_manual?: boolean | null | undefined;
        final_price_amount?: number | null | undefined;
        is_final_offer_manual?: boolean | null | undefined;
      };
    },
  ): void;
}>();

const { t } = useI18n();
const $q = useQuasar();
const router = useRouter();
const authStore = useAuthStore();

const DISPATCH_TABLE_COLUMNS = [
  'sl',
  'image',
  'name',
  'qty_confirmed',
  'delivery_papers',
] as const;

function emitItemUpdate(item: ShopOrderItem, payload: Record<string, any>) {
  emit('update-item', {
    itemId: item.id,
    productId: item.product_id ?? null,
    payload,
  });
}

const buyCurrency = computed(() => props.buyCurrencySymbol || '£');
const sellCurrency = computed(() => props.currencySymbol || '৳');

const ALL_COLUMN_NAMES = [
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'code_barcode_id',
  'qty_customer',
  'purchase_price_unit',
  'purchase_price_total',
  'product_weight_gm',
  'package_weight_gm',
  'total_weight_gm',
  'cargo_rate',
  'cargo_cost_unit_purchase',
  'landed_cost_unit_purchase',
  'landed_cost_row_purchase',
  'landed_cost_unit_sell',
  'landed_cost_row_sell',
  'first_offer_unit',
  'first_offer_row',
  'first_offer_margin',
  'counter_offer_unit',
  'counter_offer_row',
  'counter_offer_margin',
  'final_offer_unit',
  'final_offer_row',
  'final_offer_margin',
  'status',
] as const;

const tableScrollContainerRef = ref<HTMLElement | null>(null);

function onTableScroll(event: Event) {
  emit('table-scroll');
  const el = event.target as HTMLElement | null;
  if (!el) return;
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - 240) {
    emit('load-more-items');
  }
}

const defaultVisibleColumns = [
  'sl',
  'image',
  'name',
  'brand',
  'qty_customer',
  'code_barcode_id',
  'purchase_price_unit',
  'purchase_price_total',
  'total_weight_gm',
  'cargo_cost_unit_purchase',
  'landed_cost_unit_purchase',
  'landed_cost_unit_sell',
  'landed_cost_row_sell',
  'first_offer_unit',
  'first_offer_row',
  'first_offer_margin',
  'counter_offer_unit',
  'counter_offer_row',
  'counter_offer_margin',
  'final_offer_unit',
  'final_offer_row',
  'final_offer_margin',
  'status',
];

const LEGACY_COLUMN_MAPPING: Record<string, string[]> = {
  sku: ['code_barcode_id'],
  weight_kg: ['total_weight_gm', 'product_weight_gm'],
  cost_price: ['purchase_price_unit', 'purchase_price_total'],
  list_price: ['purchase_price_unit'],
  profit_base: ['landed_cost_unit_sell'],
  staff_offer: ['first_offer_unit', 'first_offer_row', 'first_offer_margin'],
  customer_offer: ['counter_offer_unit', 'counter_offer_row', 'counter_offer_margin'],
  final_price: ['final_offer_unit', 'final_offer_row', 'final_offer_margin'],
  confirmed_quantity: ['qty_customer'],
  quantity: ['qty_customer'],
};

const validColumnNames = computed(() => [...ALL_COLUMN_NAMES]);

const resolvedVisibleColumns = computed<string[]>(() => {
  if (!props.visibleColumns || !props.visibleColumns.length) {
    return defaultVisibleColumns;
  }

  const mapped = new Set<string>();
  mapped.add('sl');
  mapped.add('image');
  mapped.add('name');
  mapped.add('status');

  props.visibleColumns.forEach((col) => {
    if (validColumnNames.value.includes(col as (typeof ALL_COLUMN_NAMES)[number])) {
      mapped.add(col);
    } else if (LEGACY_COLUMN_MAPPING[col]) {
      LEGACY_COLUMN_MAPPING[col].forEach((c) => mapped.add(c));
    }
  });

  return Array.from(mapped);
});


function isColVisible(colKey: string): boolean {
  if (isDispatchTableView.value) {
    return (DISPATCH_TABLE_COLUMNS as readonly string[]).includes(colKey);
  }
  return resolvedVisibleColumns.value.includes(colKey);
}

function getConfirmedQty(item: ShopOrderItem): number {
  return Math.max(0, Number(item.confirmed_quantity ?? item.quantity ?? 0) || 0);
}

function openDeliveryPaper(paperId: number) {
  const orderId = props.order?.id;
  if (!orderId) return;
  void router.push({
    name: 'app-shop-order-delivery-paper-page',
    params: {
      tenantSlug: authStore.tenantSlug || '',
      id: String(orderId),
      paperId: String(paperId),
    },
  });
}

function formatTableHeaderLabel(colName: string, fallback: string): string {
  const buy = buyCurrency.value;
  const sell = sellCurrency.value;
  const labels: Record<string, string> = {
    qty_customer: 'Qty\n(Customer)',
    code_barcode_id: 'Barcode /\nCode / ID',
    purchase_price_unit: `Price\n(${buy})\n/ Unit`,
    purchase_price_total: `Total\nPurchase\n(${buy})`,
    product_weight_gm: 'Product\nWeight\n(gm)',
    package_weight_gm: 'Package\nWeight\n(gm)',
    total_weight_gm: 'Total\nWeight\n(gm)',
    cargo_rate: `Cargo\nRate\n(${buy}/kg)`,
    cargo_cost_unit_purchase: `Cargo Cost\n(${buy})\n/ Unit`,
    landed_cost_unit_purchase: `Total Cost\n(${buy})`,
    landed_cost_row_purchase: `Row Total\nCost\n(${buy})`,
    landed_cost_unit_sell: `Cost\n(${sell})`,
    landed_cost_row_sell: `Row Total\nCost\n(${sell})`,
    first_offer_unit: `1st Offer\nUnit\n(${sell})`,
    first_offer_row: `Row Total\n1st Offer\n(${sell})`,
    first_offer_margin: 'Profit\nMargin\n%',
    counter_offer_unit: `Counter Offer\n(${sell})\n/ Unit`,
    counter_offer_row: `Row Total\nCounter\n(${sell})`,
    counter_offer_margin: 'Profit\nMargin\n%',
    final_offer_unit: `Final Offer\n(${sell})`,
    final_offer_row: `Row Total\nFinal\n(${sell})`,
    final_offer_margin: 'Profit\nMargin\n%',
  };
  return labels[colName] ?? fallback;
}

const status = computed(() => props.order?.status || 'submitted');
const isDispatchTableView = computed(
  () => normalizeCatalogOrderStatus(status.value) === 'dispatch',
);

const { entriesForOrderItem, isLoading: deliveryPaperQtyLoading, isError: deliveryPaperQtyError } =
  useCatalogOrderDeliveryPaperQtyByItem({
    tenantId: computed(
      () => authStore.selectedTenant?.parent_id ?? authStore.tenantId,
    ),
    orderId: computed(() => props.order?.id ?? null),
    enabled: isDispatchTableView,
  });

const isCostingMode = computed(() => normalizeCatalogOrderStatus(status.value) === 'submitted');
const isFirstOfferLocked = computed(() => isCatalogFirstOfferLocked(status.value));
const isFinalOfferEditable = computed(() => isCatalogFinalOfferEditable(status.value));
const isStaffReadOnly = computed(() => isCatalogStaffReadOnly(status.value));

const FX = computed(() => props.order?.conversion_rate ?? 140);
const cargoRate = computed(() => props.order?.cargo_rate ?? 0);
const profitRate = computed(() => props.order?.first_offer_rate ?? props.order?.profit_rate ?? 25);
const finalOfferRate = computed(() => props.order?.final_offer_rate ?? null);
const profitBasis = computed(() => props.order?.profit_basis || 'total_cost');

// Calculation Helpers
function getProductWeightGm(item: ShopOrderItem): number {
  return catalogGetProductWeightGm(item);
}

function getPackageWeightGm(item: ShopOrderItem): number {
  return catalogGetPackageWeightGm(item, props.order?.package_weight_kg);
}

function getTotalWeightGm(item: ShopOrderItem): number {
  return catalogGetTotalWeightGm(item, props.order?.package_weight_kg);
}

function getCargoCostUnitPurchase(item: ShopOrderItem): number {
  return catalogGetCargoCostUnitPurchase(item, cargoRate.value, props.order?.package_weight_kg);
}

function getLandedCostUnitPurchase(item: ShopOrderItem): number {
  return catalogGetLandedCostUnitPurchase(item, cargoRate.value, props.order?.package_weight_kg);
}

function getLandedCostRowPurchase(item: ShopOrderItem): number {
  return catalogGetLandedCostRowPurchase(item, cargoRate.value, props.order?.package_weight_kg);
}

function getLandedCostUnitSell(item: ShopOrderItem): number {
  return catalogGetLandedCostUnitSell(item, cargoRate.value, FX.value, props.order?.package_weight_kg);
}

function getLandedCostRowSell(item: ShopOrderItem): number {
  return catalogGetLandedCostRowSell(item, cargoRate.value, FX.value, props.order?.package_weight_kg);
}

function getFirstOfferUnitAmount(item: ShopOrderItem): number {
  if (item.is_first_offer_manual) {
    return Number(item.staff_offer_amount || 0);
  }
  const calc = calculateItemOffer(item);
  if (calc > 0) {
    item.staff_offer_amount = calc;
  }
  return Number(item.staff_offer_amount || 0);
}

function getFirstOfferMargin(item: ShopOrderItem): number {
  return catalogGetFirstOfferMargin(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

function getCounterOfferMargin(item: ShopOrderItem): number {
  return catalogGetCounterOfferMargin(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

function getFinalOfferUnitAmount(item: ShopOrderItem): number {
  return catalogGetFinalOfferUnitAmount(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      final_offer_rate: finalOfferRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

function getFinalOfferMargin(item: ShopOrderItem): number {
  return catalogGetFinalOfferMargin(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      final_offer_rate: finalOfferRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

const quantityFilter = ref<'non_zero' | 'zero' | 'all'>('non_zero');

const quantityFilterOptions = [
  { label: 'Has quantity', value: 'non_zero' as const },
  { label: 'Zero quantity', value: 'zero' as const },
  { label: 'All items', value: 'all' as const },
];

const quantityFilterTooltip = computed(() => {
  const opt = quantityFilterOptions.find((o) => o.value === quantityFilter.value);
  return opt ? `Quantity: ${opt.label}` : 'Quantity filter';
});

const getItemLineQuantity = (item: ShopOrderItem): number => Number(item.quantity ?? 0);

const getItemStatusLabel = (item: ShopOrderItem): string => {
  if (props.order?.status === 'confirmed') {
    return getCatalogItemNegotiationStatusLabel(
      getItemLineQuantity(item) > 0 ? 'accepted' : 'rejected',
    );
  }
  return getCatalogItemNegotiationStatusLabel(
    item.negotiation_status || item.customer_decision_status || 'pending',
  );
};

const filteredRows = computed(() => {
  if (quantityFilter.value === 'all') {
    return props.items;
  }
  return props.items.filter((item) => {
    const hasQty = getItemLineQuantity(item) > 0;
    return quantityFilter.value === 'non_zero' ? hasQty : !hasQty;
  });
});

const selectedIdSet = computed(() => new Set(props.selectedLineIds ?? []));

const allFilteredRowsSelected = computed(() => {
  if (!props.canDeleteLines || filteredRows.value.length === 0) return false;
  return filteredRows.value.every((r) => selectedIdSet.value.has(r.id));
});

function isLineSelected(id: number): boolean {
  return selectedIdSet.value.has(id);
}

function toggleLineSelected(id: number, val: boolean) {
  const next = new Set(props.selectedLineIds ?? []);
  if (val) next.add(id);
  else next.delete(id);
  emit('update:selectedLineIds', [...next]);
}

function toggleSelectAllFiltered(val: boolean) {
  const ids = filteredRows.value.map((r) => r.id);
  if (ids.length === 0) return;
  const next = new Set(props.selectedLineIds ?? []);
  if (val) {
    ids.forEach((id) => next.add(id));
  } else {
    ids.forEach((id) => next.delete(id));
  }
  emit('update:selectedLineIds', [...next]);
}

function getMarginColorClass(margin: number): string {
  if (margin >= 20) return 'text-positive';
  if (margin >= 10) return 'text-warning';
  return 'text-negative';
}

function getItemStatusColor(item: ShopOrderItem): string {
  if (props.order?.status === 'confirmed') {
    return getItemLineQuantity(item) > 0 ? 'positive' : 'negative';
  }
  const st = item.negotiation_status || item.customer_decision_status;
  if (st === 'confirmed' || st === 'accepted') return 'positive';
  if (st === 'countered') return 'orange';
  if (st === 'priced') return 'primary';
  if (st === 'final_offered') return 'purple-7';
  return 'grey-7';
}

function calculateItemOffer(item: ShopOrderItem): number {
  return calculateItemFirstOfferPrice(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

function blurInput(event: KeyboardEvent) {
  (event.target as HTMLInputElement | null)?.blur();
}

function clearZeroOnFocus(item: ShopOrderItem, field: 'product_weight_gm' | 'package_weight_gm') {
  const current = Number(item[field] ?? 0);
  if (current !== 0) return;
  (item as any)[field] = null;
}

const firstOfferSaveTimers = new Map<number, ReturnType<typeof setTimeout>>();

function persistFirstOfferManual(item: ShopOrderItem) {
  const newPrice = Math.max(0, Number(item.staff_offer_amount) || 0);
  item.staff_offer_amount = newPrice;
  item.is_first_offer_manual = true;
  emitItemUpdate(item, {
    staff_offer_amount: newPrice,
    is_first_offer_manual: true,
  });
}

function onFirstOfferManualUpdate(item: ShopOrderItem, val: string | number | null) {
  if (isFirstOfferLocked.value) return;
  item.staff_offer_amount = Math.max(0, Number(val) || 0);
  item.is_first_offer_manual = true;

  const pending = firstOfferSaveTimers.get(item.id);
  if (pending) clearTimeout(pending);
  firstOfferSaveTimers.set(
    item.id,
    setTimeout(() => {
      firstOfferSaveTimers.delete(item.id);
      persistFirstOfferManual(item);
    }, 400),
  );
}

function onFirstOfferBlur(item: ShopOrderItem) {
  const pending = firstOfferSaveTimers.get(item.id);
  if (pending) {
    clearTimeout(pending);
    firstOfferSaveTimers.delete(item.id);
  }
  if (!item.is_first_offer_manual) return;
  persistFirstOfferManual(item);
}

function onFinalOfferBlur(item: ShopOrderItem) {
  if (!isFinalOfferEditable.value) return;
  const next = Math.max(0, Number(item.final_price_amount) || 0);
  const auto = catalogGetFinalOfferUnitAmount(
    { ...item, is_final_offer_manual: false, final_price_amount: null },
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      final_offer_rate: finalOfferRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
  if (!item.is_final_offer_manual && next === auto) return;
  onFinalOfferPriceSave(item, next);
}

function onUnlockFirstOffer(item: ShopOrderItem) {
  if (isFirstOfferLocked.value) return;
  const pending = firstOfferSaveTimers.get(item.id);
  if (pending) {
    clearTimeout(pending);
    firstOfferSaveTimers.delete(item.id);
  }
  item.is_first_offer_manual = false;
  const autoOffer = calculateItemOffer(item);
  item.staff_offer_amount = autoOffer;
  emitItemUpdate(item, {
    staff_offer_amount: autoOffer,
    is_first_offer_manual: false,
  });
}

function onFinalOfferPriceSave(item: ShopOrderItem, val: any) {
  if (!isFinalOfferEditable.value) return;
  const newPrice = Number(val) || 0;
  item.final_price_amount = newPrice;
  item.is_final_offer_manual = true;
  emitItemUpdate(item, {
    final_price_amount: newPrice,
    is_final_offer_manual: true,
  });
}

function onUnlockFinalOffer(item: ShopOrderItem) {
  if (!isFinalOfferEditable.value) return;
  item.is_final_offer_manual = false;
  const autoOffer = catalogGetFinalOfferUnitAmount(
    { ...item, is_final_offer_manual: false, final_price_amount: null },
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      final_offer_rate: finalOfferRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
  item.final_price_amount = autoOffer;
  emitItemUpdate(item, {
    final_price_amount: autoOffer,
    is_final_offer_manual: false,
  });
}

function onItemCostBlur(item: ShopOrderItem) {
  if (isFirstOfferLocked.value) return;
  item.cost_price_amount = Math.max(0, Number(item.cost_price_amount) || 0);
  if (isCostingMode.value && !item.is_first_offer_manual) {
    item.staff_offer_amount = calculateItemOffer(item);
  }
  emitItemUpdate(item, { cost_price_amount: item.cost_price_amount, staff_offer_amount: item.staff_offer_amount });
}

function onItemProductWeightBlur(item: ShopOrderItem) {
  if (isStaffReadOnly.value) return;
  const prodGm = Math.max(0, Number(item.product_weight_gm ?? getProductWeightGm(item)) || 0);
  item.product_weight_gm = prodGm;
  const pkgGm = getPackageWeightGm(item);
  item.weight_kg = (prodGm + pkgGm) / 1000;
  if (isCostingMode.value && !item.is_first_offer_manual) {
    item.staff_offer_amount = calculateItemOffer(item);
  }
  emitItemUpdate(item, {
    product_weight_gm: prodGm,
    weight_kg: item.weight_kg,
    staff_offer_amount: item.staff_offer_amount,
  });
}

function onItemPackageWeightBlur(item: ShopOrderItem) {
  if (isStaffReadOnly.value) return;
  const pkgGm = Math.max(0, Number(item.package_weight_gm ?? getPackageWeightGm(item)) || 0);
  item.package_weight_gm = pkgGm;
  const prodGm = getProductWeightGm(item);
  item.weight_kg = (prodGm + pkgGm) / 1000;
  if (isCostingMode.value && !item.is_first_offer_manual) {
    item.staff_offer_amount = calculateItemOffer(item);
  }
  emitItemUpdate(item, {
    package_weight_gm: pkgGm,
    weight_kg: item.weight_kg,
    staff_offer_amount: item.staff_offer_amount,
  });
}

// Totals calculations
const totalQuantity = computed(() => props.items.reduce((sum, i) => sum + (i.quantity || 0), 0));

const totalWeightGm = computed(() => props.items.reduce((sum, i) => sum + (getTotalWeightGm(i) * i.quantity), 0));

const grandTotalPurchasePrice = computed(() => props.items.reduce((sum, i) => sum + ((i.cost_price_amount || 0) * i.quantity), 0));
const grandTotalLandedPurchase = computed(() => props.items.reduce((sum, i) => sum + getLandedCostRowPurchase(i), 0));
const grandTotalLandedSell = computed(() => props.items.reduce((sum, i) => sum + getLandedCostRowSell(i), 0));

const grandTotalFirstOffer = computed(() => props.items.reduce((sum, i) => sum + ((i.staff_offer_amount || 0) * i.quantity), 0));
const overallFirstOfferMargin = computed(() => {
  if (grandTotalLandedSell.value <= 0) return 0;
  return ((grandTotalFirstOffer.value - grandTotalLandedSell.value) / grandTotalLandedSell.value) * 100;
});

const grandTotalCounterOffer = computed(() => props.items.reduce((sum, i) => sum + ((i.customer_offer_amount || 0) * i.quantity), 0));
const overallCounterOfferMargin = computed(() => {
  if (grandTotalLandedSell.value <= 0) return 0;
  return ((grandTotalCounterOffer.value - grandTotalLandedSell.value) / grandTotalLandedSell.value) * 100;
});

const grandTotalFinalOffer = computed(() => props.items.reduce((sum, i) => sum + (getFinalOfferUnitAmount(i) * i.quantity), 0));
const overallFinalOfferMargin = computed(() => {
  if (grandTotalLandedSell.value <= 0) return 0;
  return ((grandTotalFinalOffer.value - grandTotalLandedSell.value) / grandTotalLandedSell.value) * 100;
});

const summaryTotals = computed(() => ({
  totalQuantity: totalQuantity.value,
  totalWeightGm: totalWeightGm.value,
  grandTotalPurchasePrice: grandTotalPurchasePrice.value,
  grandTotalLandedPurchase: grandTotalLandedPurchase.value,
  grandTotalLandedSell: grandTotalLandedSell.value,
  grandTotalFirstOffer: grandTotalFirstOffer.value,
  overallFirstOfferMargin: overallFirstOfferMargin.value,
  grandTotalCounterOffer: grandTotalCounterOffer.value,
  overallCounterOfferMargin: overallCounterOfferMargin.value,
  grandTotalFinalOffer: grandTotalFinalOffer.value,
  overallFinalOfferMargin: overallFinalOfferMargin.value,
}));

function formatAmount(val: number | null | undefined): string {
  if (val == null || Number.isNaN(val)) return '0.00';
  return Number(val).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function handleCopy(text: string, label: string) {
  void copyToClipboard(text);
  $q.notify({ type: 'positive', message: `Copied ${label}`, timeout: 1200 });
}

const itemCount = computed(() => props.items.length);

defineExpose({
  tableScrollContainerRef,
  summaryTotals,
  itemCount,
  buyCurrency,
  sellCurrency,
  FX,
  cargoRate,
});
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid var(--tf-neutral-border);
}

.border-top {
  border-top: 1px solid var(--tf-neutral-border);
}

.catalog-toolbar {
  background-color: var(--tf-neutral-canvas);
}

.catalog-qty-filter-check {
  min-width: 28px;
}

.catalog-qty-filter-check :deep(.q-item__section--avatar) {
  min-width: 28px;
  padding-right: 0;
}

.catalog-items-table .text-grey-6,
.catalog-items-table .text-grey-7,
.catalog-items-table .text-grey-8 {
  color: var(--tf-neutral-muted) !important;
}

.catalog-items-table .text-grey-9 {
  color: var(--tf-neutral-ink) !important;
}

.catalog-table-scroll {
  overflow-x: auto !important;
  overflow-y: auto !important;
  flex: 1 1 0%;
  min-height: 0;
}

.pbc-v2-markup-table {
  border-collapse: collapse;
  background-color: var(--tf-neutral-surface);
  color: var(--tf-neutral-ink);
}

.pbc-v2-markup-table thead tr th {
  position: sticky;
  top: 0;
  z-index: 5;
  background-color: var(--tf-disabled-bg) !important;
  color: var(--tf-neutral-ink) !important;
  border-bottom: 1px solid var(--tf-neutral-border);
  padding: 4px 6px !important;
  font-size: 11px;
}

.pbc-v2-markup-table tbody tr td {
  padding: 3px 4px !important;
  border-bottom: 1px solid var(--tf-neutral-border);
  min-height: 44px;
  height: auto;
  vertical-align: middle;
  font-size: 12px;
}

/* Ops column tints — same pattern as PBC file details v2 */
.pbc-v2-markup-table th.tf-ops-col-tint--price,
.pbc-v2-markup-table td.tf-ops-col-tint--price {
  background-color: var(--tf-ops-hue-price) !important;
  box-shadow: inset 2px 0 0 var(--tf-ops-accent-price);
}

.pbc-v2-markup-table th.tf-ops-col-tint--cost,
.pbc-v2-markup-table td.tf-ops-col-tint--cost {
  background-color: var(--tf-ops-hue-cost) !important;
  box-shadow: inset 2px 0 0 var(--tf-ops-accent-cost);
}

.pbc-v2-markup-table th.tf-ops-col-tint--qty,
.pbc-v2-markup-table td.tf-ops-col-tint--qty {
  background-color: var(--tf-ops-hue-qty) !important;
  box-shadow: inset 2px 0 0 var(--tf-ops-accent-qty);
}

.pbc-v2-markup-table th.tf-ops-col-tint--weight,
.pbc-v2-markup-table td.tf-ops-col-tint--weight {
  background-color: var(--tf-ops-hue-weight) !important;
  box-shadow: inset 2px 0 0 var(--tf-ops-accent-weight);
}

.pbc-row:hover {
  background-color: color-mix(in srgb, var(--tf-neutral-surface) 96%, var(--tf-neutral-ink) 4%) !important;
}

.pbc-row:hover td {
  filter: brightness(0.98);
}

.sticky-col-select {
  position: sticky;
  left: 0;
  z-index: 5;
  background-color: var(--tf-neutral-surface) !important;
  border-right: 1px solid var(--tf-neutral-border);
}

.pbc-v2-markup-table thead tr th.sticky-col-select {
  z-index: 7;
  background-color: var(--tf-disabled-bg) !important;
}

.sticky-col-2 {
  position: sticky;
  left: 0;
  z-index: 4;
  background-color: var(--tf-neutral-surface) !important;
  border-right: 1px solid var(--tf-neutral-border);
}

.sticky-col-2--offset {
  left: 30px;
}

.pbc-v2-markup-table thead tr th.sticky-col-2 {
  z-index: 6;
  background-color: var(--tf-disabled-bg) !important;
}

.pbc-v2-markup-table th.pbc-sl-col,
.pbc-v2-markup-table td.pbc-sl-col {
  width: 36px;
  min-width: 36px;
  max-width: 36px;
  padding: 2px !important;
  box-sizing: border-box;
}

.pbc-v2-markup-table th.pbc-select-col,
.pbc-v2-markup-table td.pbc-select-col {
  width: 30px;
  min-width: 30px;
  max-width: 30px;
  padding: 0 1px !important;
  box-sizing: border-box;
}

.pbc-v2-markup-table .pbc-select-col :deep(.q-checkbox) {
  margin: -2px 0;
}

.pbc-image-cell {
  padding: 2px !important;
  vertical-align: middle;
}

.pbc-row-img {
  width: 0.85in;
  height: 0.85in;
  display: block;
  margin: 0 auto;
  border-radius: 6px;
  border: 1px solid var(--tf-neutral-border);
  background: #fff; /* product photos sit on white in both themes */
  overflow: hidden;
}

.pbc-row-img :deep(.smart-image__img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  object-position: center;
}

.pbc-row-img-placeholder {
  width: 0.85in;
  height: 0.85in;
  display: block;
  margin: 0 auto;
  border-radius: 6px;
  border: 1px dashed var(--tf-neutral-border-strong);
  background-color: var(--tf-neutral-canvas);
  overflow: hidden;
}

.catalog-table-header {
  letter-spacing: 0.02em;
  font-size: 10px;
  line-height: 1.2;
}

.header-label-wrap {
  display: inline-block;
  white-space: pre-line;
  word-break: break-word;
  overflow-wrap: anywhere;
  line-height: 1.2;
  max-width: 100%;
}

:deep(.inline-edit-input .q-field__control) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 4px !important;
}

:deep(.inline-edit-input .q-field__native) {
  padding: 0;
  font-size: 12px;
}

:deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
  transition: all 0.1s ease-in-out;
}

:deep(.excel-cell-input .q-field__control:before),
:deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

:deep(.excel-cell-input:hover .q-field__control),
:deep(.excel-cell-input.q-field--focused .q-field__control) {
  border: 1px solid var(--tf-neutral-border-strong) !important;
  background-color: var(--tf-hover-bg) !important;
  border-radius: 4px !important;
}

:deep(.inline-edit-input input[type='number']::-webkit-outer-spin-button),
:deep(.inline-edit-input input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(.inline-edit-input input[type='number']) {
  -moz-appearance: textfield;
  appearance: textfield;
}

.text-2xs {
  font-size: 10px;
}

.col-name-wrap,
.name-cell-wrap {
  width: 180px !important;
  min-width: 180px !important;
  max-width: 180px !important;
  text-align: left !important;
}

.name-cell-text {
  white-space: normal !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.3;
  font-size: 12px;
  min-width: 0;
}

.name-copy-btn {
  flex-shrink: 0;
  margin-top: 1px;
}

.col-brand {
  width: 90px;
  min-width: 90px;
  max-width: 90px;
  text-align: center !important;
  vertical-align: middle;
}

.brand-cell {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100%;
}

.col-code-barcode {
  width: 130px;
  min-width: 130px;
  max-width: 130px;
  text-align: left !important;
  white-space: normal !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.3;
  vertical-align: top;
}

.col-info-meta {
  width: 72px;
  min-width: 72px;
  max-width: 72px;
  text-align: center !important;
  white-space: normal !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.3;
  vertical-align: top;
}

.status-chip {
  max-width: 100%;
  height: auto;
  min-height: 24px;
}

.status-chip :deep(.q-chip__content) {
  white-space: normal;
  line-height: 1.2;
  text-align: center;
}

.catalog-dispatch-papers-cell {
  min-width: 200px;
  max-width: 300px;
  vertical-align: top;
}

.catalog-dispatch-paper-chip {
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
  background: var(--tf-neutral-surface);
  padding: 6px 8px;
  gap: 4px;
  cursor: pointer;
  text-align: left;
  width: 100%;
  max-width: 100%;
}

.catalog-dispatch-paper-chip__head {
  flex-shrink: 0;
}

.catalog-dispatch-paper-chip__status :deep(.tf-status-badge) {
  padding: 1px 4px;
}

.catalog-dispatch-paper-chip__status :deep(.tf-status-badge span:last-child) {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.catalog-dispatch-paper-chip__metrics {
  gap: 6px 10px;
  line-height: 1.2;
}

.catalog-dispatch-paper-chip__metric {
  display: inline-flex;
  align-items: baseline;
  gap: 3px;
  font-family: ui-monospace, monospace;
  white-space: nowrap;
}

.catalog-dispatch-paper-chip__lbl {
  font-size: 10px;
  font-weight: 600;
  color: var(--tf-neutral-muted, rgba(0, 0, 0, 0.55));
  letter-spacing: 0.02em;
}

.catalog-dispatch-paper-chip__val {
  font-size: 13px;
  font-weight: 700;
  color: var(--tf-neutral-ink, inherit);
}

.catalog-dispatch-paper-chip:hover {
  background: var(--tf-neutral-surface-hover, rgba(0, 0, 0, 0.03));
}
</style>
