<template>
  <q-page class="pbc-file-details-v2-page bg-grey-1 column no-wrap">
    <!-- Top Sticky Header Section: Compact Title, Status Badge, Rates Summary & Actions -->
    <div class="pbc-v2-top-section bg-white border-bottom shrink-0 shadow-xs column no-wrap">
      <div class="pbc-v2-top-section__main row items-center justify-between no-wrap">
        <!-- Left: Back Button, Code, Name -->
        <div class="row items-center q-gutter-x-xs no-wrap ellipsis min-width-0 col-auto">
          <TfBtn
            variant="icon"
            icon="ph ph-arrow-left"
            color="grey-8"
            @click="goBackToList"
          >
            <q-tooltip :delay="400">{{ $t('product_based_costing.go_back') }}</q-tooltip>
          </TfBtn>

          <span class="pbc-v2-top-section__code text-subtitle2 text-weight-bolder text-grey-8 font-mono bg-grey-2 q-px-xs rounded-borders">
            PBC-{{ fileId }}
          </span>

          <span class="text-grey-4">·</span>

          <!-- Inline Name Edit -->
          <div v-if="isEditingName" class="row items-center no-wrap">
            <q-input
              ref="nameInputRef"
              v-model="editingNameValue"
              dense
              outlined
              hide-bottom-space
              autofocus
              class="name-inline-input"
              style="min-width: 180px; max-width: 260px"
              :loading="savingName"
              @blur="saveInlineName"
              @keyup.enter="saveInlineName"
              @keyup.esc="cancelInlineName"
            />
          </div>
          <div
            v-else
            class="pbc-v2-top-section__title text-subtitle1 text-weight-bolder text-grey-9 ellipsis cursor-pointer name-inline-title row items-center q-gutter-x-2xs no-wrap"
            :title="$t('product_based_costing.click_to_edit_name')"
            @click="startInlineNameEdit"
          >
            <span class="ellipsis">{{ file?.name || $t('product_based_costing.costing_file_default') }}</span>
            <q-icon name="ph ph-pencil-simple" size="12px" class="text-grey-6 edit-icon" />
          </div>

        </div>

        <!-- Center / Rates Bar Quick Summary -->
        <div class="row items-center q-gutter-x-sm no-wrap q-mx-sm">
          <div class="rates-pill row items-center q-gutter-x-xs q-px-sm q-py-2xs bg-grey-2 rounded-borders text-caption text-grey-8 font-mono">
            <span><strong>FX:</strong> {{ sellMark }}{{ conversionRateValue }}</span>
            <span class="text-grey-4">|</span>
            <span><strong>Cargo:</strong> {{ buyMark }}{{ cargoRateValue }}/kg</span>
            <span class="text-grey-4">|</span>
            <span><strong>Profit:</strong> {{ profitRateValue }}%</span>
            <span class="text-grey-4">|</span>
            <span><strong>Offer:</strong> {{ offerPricingModeValue === 'gbp_vat_then_profit' ? 'VAT then £' : 'On cost' }}</span>
            <template v-if="offerPricingModeValue === 'gbp_vat_then_profit'">
              <span class="text-grey-4">|</span>
              <span><strong>VAT:</strong> {{ vatRateValue }}%</span>
            </template>
            <q-btn
              flat
              round
              dense
              size="xs"
              icon="ph ph-sliders-horizontal"
              color="primary"
              class="q-ml-2xs"
              @click="toggleRatesEditor"
            >
              <q-tooltip>Edit rates (FX, Cargo, Profit)</q-tooltip>
            </q-btn>
          </div>
        </div>

        <!-- Right Header Action Controls -->
        <div class="row items-center q-gutter-x-xs no-wrap col-auto">
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrows-clockwise"
            class="text-grey-7"
            :loading="isRefreshing"
            :aria-label="$t('common.refresh', 'Refresh')"
            data-test="pbc-file-refresh"
            @click="refresh()"
          >
            <q-tooltip :delay="400">{{ $t('common.refresh', 'Refresh') }}</q-tooltip>
          </q-btn>

          <!-- Add Products Button -->
          <TfBtn
            variant="primary"
            icon="ph ph-plus"
            :label="$t('product_based_costing.add_products')"
            class="q-px-sm rounded-sq-btn text-weight-bold"
            style="border-radius: 8px"
            @click="openCatalogDialog"
          />

          <!-- Backlog Auto-Suggest Button -->
          <TfBtn
            v-if="availableBacklogItems.length"
            variant="secondary"
            color="orange-9"
            icon="ph ph-tray"
            :label="`Backlog (${availableBacklogItems.length})`"
            class="q-px-sm rounded-sq-btn text-weight-bold bg-orange-1"
            style="border-radius: 8px"
            @click="openBacklogDrawer"
          >
            <q-tooltip :delay="400">Review open unfulfilled demand backlog for this customer</q-tooltip>
          </TfBtn>

          <q-btn-toggle
            v-model="itemsView"
            dense
            unelevated
            no-caps
            size="sm"
            toggle-color="primary"
            color="white"
            text-color="primary"
            class="pbc-items-view-toggle border-grey rounded-sq-btn"
            :options="[
              { icon: 'ph ph-rows', value: 'table' },
              { icon: 'ph ph-squares-four', value: 'card' },
            ]"
          />

          <!-- Columns Menu -->
          <TfBtn
            variant="tertiary"
            color="grey-8"
            class="rounded-sq-btn text-weight-bold q-px-sm border-grey"
            icon="ph ph-columns"
            :label="$t('product_based_costing.columns')"
            style="border-radius: 8px"
          >
            <q-menu :auto-close="false">
              <q-list style="min-width: 240px; max-height: 400px" class="q-pa-xs">
                <q-item class="q-pb-none">
                  <q-item-section>
                    <div class="text-subtitle2 text-weight-bold text-primary">{{ $t('product_based_costing.show_columns') }}</div>
                    <q-input
                      v-model="columnSearchQuery"
                      dense
                      outlined
                      :placeholder="$t('product_based_costing.search_columns')"
                      clearable
                      class="q-mt-xs"
                      @click.stop
                    >
                      <template #prepend>
                        <q-icon name="ph ph-magnifying-glass" size="14px" />
                      </template>
                    </q-input>
                  </q-item-section>
                </q-item>
                <q-item clickable class="q-py-xs" @click.stop>
                  <q-item-section>
                    <q-checkbox
                      v-model="allSelectableColumnsSelected"
                      :label="$t('product_based_costing.select_deselect_all')"
                      @click.stop
                    />
                  </q-item-section>
                </q-item>
                <q-separator class="q-my-xs" />
                <q-item class="q-py-none">
                  <q-item-section>
                    <div
                      v-if="!filteredColumnOptions.length"
                      class="text-caption text-grey-6 q-pa-sm"
                    >
                      {{ $t('product_based_costing.no_matching_columns') }}
                    </div>
                    <q-option-group
                      v-else
                      v-model="localVisibleColumns"
                      type="checkbox"
                      :options="filteredColumnOptions"
                    />
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </TfBtn>

          <q-btn
            unelevated
            round
            dense
            color="grey-2"
            text-color="grey-9"
            icon="ph ph-gear"
            size="sm"
            class="border-grey pbc-v2-header-settings-btn"
            @click="openSettingsDrawer()"
          >
            <q-tooltip>File Settings</q-tooltip>
          </q-btn>

        </div>
      </div>

      <div class="pbc-v2-top-section__sub row items-center q-gutter-x-sm no-wrap wrap">
        <ProductBasedCostingStatusWorkflowBar
          class="pbc-v2-header-workflow col-grow"
          :status="status"
          :updating="updatingStatus"
          :target-status="targetUpdatingStatus"
          @update-status="onWorkflowStatusClick"
        />
        <span
          v-if="file?.order_for"
          class="text-caption text-grey-6 ellipsis text-weight-medium col-auto"
        >
          {{ file.order_for }}
        </span>
      </div>

      <!-- Expandable Inline Rates Editor Bar -->
      <div v-if="ratesExpanded" class="pbc-rates-editor">
        <div class="pbc-rates-editor__grid">
          <div class="pbc-rates-group">
            <div class="pbc-rates-group__title">{{ $t('product_based_costing.currencies_section') }}</div>
            <div class="row q-col-gutter-sm q-mb-sm">
              <div class="col-6">
                <q-select
                  v-model="localRates.buy_currency_id"
                  :options="currencyOptions"
                  dense
                  outlined
                  emit-value
                  map-options
                  :loading="loadingCurrencies"
                  :label="$t('product_based_costing.buy_currency_label')"
                  hide-bottom-space
                />
              </div>
              <div class="col-6">
                <q-select
                  v-model="localRates.sell_currency_id"
                  :options="currencyOptions"
                  dense
                  outlined
                  emit-value
                  map-options
                  :loading="loadingCurrencies"
                  :label="$t('product_based_costing.sell_currency_label')"
                  hide-bottom-space
                />
              </div>
            </div>
          </div>

          <div class="pbc-rates-group">
            <div class="pbc-rates-group__title">Landed cost</div>
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model.number="localRates.conversion_rate"
                  dense
                  outlined
                  type="number"
                  :prefix="editorSellMark"
                  :label="$t('product_based_costing.conversion_rate_fx_short', editorCurrencyI18n)"
                  hide-bottom-space
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model.number="localRates.cargo_rate_kg_gbp"
                  dense
                  outlined
                  type="number"
                  :prefix="editorBuyMark"
                  suffix="/kg"
                  :label="$t('product_based_costing.cargo_rate_label')"
                  hide-bottom-space
                />
              </div>
            </div>
          </div>

          <div class="pbc-rates-group">
            <div class="pbc-rates-group__title">Offer price</div>
            <q-btn-toggle
              v-model="localRates.offer_pricing_mode"
              unelevated
              no-caps
              dense
              spread
              toggle-color="primary"
              class="pbc-rates-mode-toggle q-mb-xs"
              :options="offerPricingModeOptions"
            />
            <div class="text-caption text-grey-7 q-mb-sm">
              {{
                localRates.offer_pricing_mode === 'gbp_vat_then_profit'
                  ? 'VAT on the £ web price, then cargo, FX, and profit like cost-plus.'
                  : 'Profit is added on landed cost in ৳.'
              }}
            </div>
            <div class="row q-col-gutter-sm">
              <div :class="localRates.offer_pricing_mode === 'gbp_vat_then_profit' ? 'col-6' : 'col-12'">
                <q-input
                  v-model.number="localRates.profit_rate"
                  dense
                  outlined
                  type="number"
                  suffix="%"
                  label="Profit"
                  hide-bottom-space
                />
              </div>
              <div v-if="localRates.offer_pricing_mode === 'gbp_vat_then_profit'" class="col-6">
                <q-input
                  v-model.number="localRates.vat_rate"
                  dense
                  outlined
                  type="number"
                  suffix="%"
                  label="VAT"
                  hide-bottom-space
                />
              </div>
            </div>
          </div>

          <div class="pbc-rates-editor__actions">
            <TfBtn
              variant="tertiary"
              size="md"
              label="Cancel"
              class="rounded-sq-btn"
              style="border-radius: 8px"
              @click="cancelRatesEdit"
            />
            <TfBtn
              variant="primary"
              size="md"
              label="Save"
              class="rounded-sq-btn q-px-md"
              style="border-radius: 8px"
              :loading="savingRates"
              @click="handleSaveRates"
            />
          </div>
        </div>
      </div>
    </div>



    <!-- Active Selection Action Banner Row -->
    <div
      v-if="selectedRowIds.length > 0"
      class="pbc-selection-banner-row bg-blue-1 border-bottom q-px-md q-py-xs row items-center justify-between no-wrap shrink-0 animate-fade"
      style="min-height: 36px"
    >
      <div class="row items-center q-gutter-x-sm">
        <q-icon name="ph ph-check-square" size="16px" color="primary" />
        <span class="text-caption text-weight-bold text-primary font-mono">
          {{ selectedRowIds.length }} item<span v-if="selectedRowIds.length > 1">s</span> selected
        </span>
        <q-btn
          flat
          dense
          no-caps
          size="xs"
          label="Deselect All"
          color="grey-7"
          class="q-px-xs rounded-borders"
          @click="selectedRowIds = []"
        />
      </div>

      <div class="row items-center q-gutter-x-xs no-wrap">
        <!-- Single Item Actions -->
        <template v-if="selectedRowIds.length === 1">
          <q-btn
            unelevated
            dense
            no-caps
            size="xs"
            color="primary"
            icon="ph ph-pencil-simple"
            label="Edit Selected"
            class="rounded-sq-btn q-px-sm text-weight-bold"
            style="border-radius: 6px"
            @click="editSingleSelectedItem"
          />
          <q-btn
            outline
            dense
            no-caps
            size="xs"
            color="negative"
            icon="ph ph-trash"
            label="Delete"
            class="rounded-sq-btn q-px-sm text-weight-bold"
            style="border-radius: 6px"
            @click="deleteSingleSelectedItem"
          />
        </template>

        <!-- Bulk Selection Actions -->
        <template v-else>
          <q-btn
            unelevated
            dense
            no-caps
            size="xs"
            color="negative"
            icon="ph ph-trash"
            :label="`Bulk Delete (${selectedRowIds.length})`"
            class="rounded-sq-btn q-px-sm text-weight-bold"
            style="border-radius: 6px"
            @click="bulkDeleteSelectedItems"
          />
        </template>
      </div>
    </div>

    <!-- Middle Scrollable Table Section -->
    <div
      ref="tableScrollContainerRef"
      class="pbc-v2-middle-section col overflow-auto q-pa-none hide-native-scrollbar"
      :class="itemsView === 'table' ? 'bg-white' : 'bg-grey-1'"
      style="overflow-x: auto !important; overflow-y: auto !important; flex: 1 1 0%; min-height: 0"
      @scroll="onTableScroll"
    >
      <table
        v-if="itemsView === 'table'"
        class="pbc-v2-markup-table bg-white"
        style="min-width: 1080px; width: 100%"
      >
        <thead>
          <tr class="bg-grey-2 text-grey-9 text-weight-bold" style="font-size: 11px">
            <!-- Row Selection Header -->
            <th class="text-center pbc-select-col sticky-col">
              <q-checkbox
                :model-value="isAllRowsSelected"
                dense
                size="xs"
                @update:model-value="toggleSelectAllRows"
              />
            </th>

            <!-- Serial # / Position -->
            <th v-if="visibleColumnMap.sl" class="text-center pbc-sl-col sticky-col-2">
              SL
            </th>

            <!-- Image -->
            <th v-if="visibleColumnMap.image" class="text-center pbc-image-col" style="width: 0.85in; min-width: 0.85in">
              Image
            </th>

            <!-- Product Name -->
            <th v-if="visibleColumnMap.name" class="text-left" style="min-width: 120px; width: 120px; max-width: 120px; white-space: normal">
              <div class="row items-center no-wrap q-gutter-x-2xs">
                <span>Name</span>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  :disable="!tableRows.length"
                  @click.stop="copyAllLineNames"
                >
                  <q-tooltip>Copy all names</q-tooltip>
                </q-btn>
              </div>
            </th>

            <!-- Brand -->
            <th v-if="visibleColumnMap.brand" class="text-left" style="width: 80px; min-width: 80px">
              Brand
            </th>

            <!-- Note -->
            <th v-if="visibleColumnMap.note" class="text-left" style="width: 100px; min-width: 100px">
              Note
            </th>

            <!-- Qty -->
            <th v-if="visibleColumnMap.qty" class="text-center tf-ops-col-tint--qty" style="width: 56px; min-width: 56px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <span>Qty</span>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('quantity')"
                >
                  <q-tooltip>Bulk Paste Quantity</q-tooltip>
                </q-btn>
              </div>
            </th>

            <!-- Confirmed Qty -->
            <th v-if="visibleColumnMap.confirmedQty" class="text-center tf-ops-col-tint--qty" style="width: 56px; min-width: 56px">
              Conf. Qty
            </th>

            <!-- Barcode / Code / ID -->
            <th v-if="visibleColumnMap.barcodeText" class="text-left" style="width: 115px; min-width: 115px">
              Codes
            </th>

            <!-- Website -->
            <th v-if="visibleColumnMap.website" class="text-center" style="width: 50px; min-width: 50px">
              Link
            </th>

            <!-- Purchase Price GBP -->
            <th v-if="visibleColumnMap.priceGbp" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <span>{{ $t('product_based_costing.table_col_priceGbp', currencyI18n) }}</span>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('price_gbp')"
                >
                  <q-tooltip>Bulk Paste Price</q-tooltip>
                </q-btn>
              </div>
            </th>

            <!-- Price with VAT (VAT-then-£ mode) -->
            <th
              v-if="showPriceGbpWithVatColumn && visibleColumnMap.priceGbpWithVat"
              class="text-center tf-ops-col-tint--price"
              style="width: 56px; min-width: 56px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px"
            >
              {{ $t('product_based_costing.table_col_priceGbpWithVat', currencyI18n) }}
            </th>

            <!-- Total Purchase GBP -->
            <th v-if="visibleColumnMap.totalPurchasePriceGbp" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
              {{ $t('product_based_costing.table_col_totalPurchasePriceGbp', currencyI18n) }}
            </th>

            <!-- Product Wt (g) -->
            <th v-if="visibleColumnMap.productWeight" class="text-center" style="width: 56px; min-width: 56px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <div>
                  <div>Product</div>
                  <div>Weight</div>
                </div>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('product_weight')"
                >
                  <q-tooltip>Bulk Paste Product Weight</q-tooltip>
                </q-btn>
              </div>
            </th>

            <!-- Package Wt (g) -->
            <th v-if="visibleColumnMap.packageWeight" class="text-center tf-ops-col-tint--weight" style="width: 56px; min-width: 56px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <div>
                  <div>Package</div>
                  <div>Weight</div>
                </div>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('package_weight')"
                >
                  <q-tooltip>Bulk Paste Package Weight</q-tooltip>
                </q-btn>
              </div>
            </th>

            <!-- Total Wt (g) -->
            <th v-if="visibleColumnMap.totalWeight" class="text-center tf-ops-col-tint--weight" style="width: 56px; min-width: 56px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
              <div>Total</div>
              <div>Weight</div>
            </th>

            <!-- Cargo Rate -->
            <th v-if="visibleColumnMap.cargoRate" class="text-center" style="width: 56px; min-width: 56px">
              Cargo Rate
            </th>

            <!-- Cargo Cost GBP -->
            <th v-if="visibleColumnMap.cargoCostGbp" class="text-center" style="width: 56px; min-width: 56px">
              {{ $t('product_based_costing.table_col_cargoCostGbp', currencyI18n) }}
            </th>

            <!-- Total Cost GBP/Unit -->
            <th v-if="visibleColumnMap.totalCostGbp" class="text-center tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              {{ $t('product_based_costing.table_col_totalCostGbp', currencyI18n) }}
            </th>

            <!-- Row Total Cost GBP -->
            <th v-if="visibleColumnMap.rowTotalCostGbp" class="text-center tf-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              {{ $t('product_based_costing.table_col_rowTotalCostGbp', currencyI18n) }}
            </th>

            <!-- Cost BDT -->
            <th v-if="visibleColumnMap.costBdt" class="text-center tf-ops-col-tint--cost" style="width: 60px; min-width: 60px">
              {{ $t('product_based_costing.table_col_costBdt', currencyI18n) }}
            </th>

            <!-- Row Total Cost BDT -->
            <th v-if="visibleColumnMap.totalCostBdt" class="text-center tf-ops-col-tint--cost" style="width: 60px; min-width: 60px">
              {{ $t('product_based_costing.table_col_totalCostBdt', currencyI18n) }}
            </th>

            <!-- Offer Price BDT -->
            <th v-if="visibleColumnMap.offerPriceBdt" class="text-center tf-ops-col-tint--price" style="width: 84px; min-width: 84px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <span>{{ $t('product_based_costing.table_col_offerPriceBdt', currencyI18n) }}</span>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('offer_price')"
                >
                  <q-tooltip>Bulk Paste Offer Price (manual)</q-tooltip>
                </q-btn>
              </div>
            </th>

            <!-- Total Offer BDT -->
            <th v-if="visibleColumnMap.totalBdt" class="text-center tf-ops-col-tint--price" style="width: 64px; min-width: 64px">
              Tot Offer
            </th>

            <!-- Profit Per Unit BDT -->
            <th v-if="visibleColumnMap.profitPerUnitBdt" class="text-center text-teal-9" style="width: 56px; min-width: 56px">
              Profit/U
            </th>

            <!-- Row Total Profit BDT -->
            <th v-if="visibleColumnMap.profitBdt" class="text-center text-teal-9" style="width: 56px; min-width: 56px">
              Profit
            </th>

            <!-- Profit Rate % -->
            <th v-if="visibleColumnMap.profitRate" class="text-center" style="width: 50px; min-width: 50px">
              Profit %
            </th>

            <!-- Status -->
            <th v-if="visibleColumnMap.status" class="text-center" style="width: 65px; min-width: 65px">
              Status
            </th>
          </tr>
        </thead>

        <tbody>
          <!-- Loading State -->
          <tr v-if="isLoading">
            <td colspan="20" class="text-center q-py-xl">
              <TfSkeletonRows :rows="6" :cols="6" height="18px" />
            </td>
          </tr>

          <!-- Line Items List Rows -->
          <template v-else-if="tableRows.length">
            <tr
              v-for="(row, idx) in tableRows"
              :key="row.id"
              class="pbc-row transition-all"
              :class="{
                'bg-amber-0': row.status === 'pending',
                'bg-blue-0': row.status === 'offered',
                'bg-green-0': row.status === 'accepted' || row.status === 'confirmed',
                'pbc-row-selected': selectedRowIds.includes(row.id),
              }"
            >
              <!-- Checkbox -->
              <td class="text-center pbc-select-col sticky-col">
                <q-checkbox
                  :model-value="selectedRowIds.includes(row.id)"
                  dense
                  size="xs"
                  @update:model-value="(checked) => toggleRowSelection(row.id, checked)"
                />
              </td>

              <!-- Serial / Reorder -->
              <td
                v-if="visibleColumnMap.sl"
                class="text-center pbc-sl-col sticky-col-2 sl-reorder-cell"
                @click.stop
              >
                <div class="row items-center justify-center no-wrap">
                  <q-input
                    :model-value="idx + 1"
                    type="number"
                    min="1"
                    :max="totalItemsCount || tableRows.length"
                    dense
                    outlined
                    hide-bottom-space
                    class="inline-edit-input excel-cell-input"
                    style="max-width: 32px"
                    input-class="text-center text-weight-bold font-mono"
                    @change="(e: Event) => onSlPositionChange(idx, e)"
                    @keyup.enter="(e: Event) => (e.target as HTMLElement)?.blur()"
                  />
                </div>
              </td>

              <!-- Product Image -->
              <td v-if="visibleColumnMap.image" class="text-center pbc-image-cell" style="width: 0.85in; min-width: 0.85in">
                <SmartImage
                  :src="row.imageUrl"
                  :alt="row.name || 'Product Image'"
                  img-class="pbc-row-img"
                  fallback-class="pbc-row-img-placeholder"
                />
              </td>

              <!-- Product Details (Name, Barcode, Note) -->
              <td v-if="visibleColumnMap.name" class="text-left" style="width: 120px; min-width: 120px; max-width: 120px; white-space: normal !important; word-break: break-word">
                <div class="text-weight-bold text-grey-9 hover-underline cursor-pointer" style="font-size: 13px; line-height: 1.35; word-break: break-word; white-space: normal" @click="onEdit(row.raw)">
                  {{ row.name }}
                </div>
              </td>

              <!-- Brand -->
              <td v-if="visibleColumnMap.brand" class="text-left text-caption text-grey-8" style="width: 80px; min-width: 80px">
                {{ row.brand || '-' }}
              </td>

              <!-- Note (Inline Edit) -->
              <td v-if="visibleColumnMap.note" class="text-left" style="width: 100px; min-width: 100px">
                <q-input
                  :model-value="getDraftValue(row, 'note')"
                  dense
                  outlined
                  hide-bottom-space
                  class="inline-edit-input excel-cell-input"
                  input-class="text-caption"
                  :placeholder="$t('product_based_costing.note')"
                  @update:model-value="(val) => setDraftValue(row, 'note', val)"
                  @blur="saveDraftValue(row, 'note')"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
              </td>

              <!-- Qty (Inline Edit) -->
              <td v-if="visibleColumnMap.qty" class="text-center tf-ops-col-tint--qty" style="width: 56px; min-width: 56px">
                <div class="row justify-center">
                  <q-input
                    :model-value="getDraftValue(row, 'quantity')"
                    type="number"
                    min="1"
                    step="1"
                    dense
                    outlined
                    hide-bottom-space
                    class="inline-edit-input excel-cell-input"
                    style="max-width: 50px"
                    input-class="text-center text-weight-bold"
                    @update:model-value="(val) => setDraftValue(row, 'quantity', val)"
                    @blur="saveDraftValue(row, 'quantity')"
                    @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                  />
                </div>
              </td>

              <!-- Confirmed Qty (Inline Edit) -->
              <td v-if="visibleColumnMap.confirmedQty" class="text-center tf-ops-col-tint--qty" style="width: 56px; min-width: 56px">
                <div class="row justify-center">
                  <q-input
                    :model-value="getDraftValue(row, 'confirmed_quantity')"
                    type="number"
                    min="0"
                    step="1"
                    dense
                    outlined
                    hide-bottom-space
                    class="inline-edit-input excel-cell-input"
                    style="max-width: 50px"
                    input-class="text-center text-weight-bold text-teal-10"
                    @update:model-value="(val) => setDraftValue(row, 'confirmed_quantity', val)"
                    @blur="saveDraftValue(row, 'confirmed_quantity')"
                    @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                  />
                </div>
              </td>

              <!-- Barcode / Code / ID -->
              <td v-if="visibleColumnMap.barcodeText" class="font-mono text-caption" style="width: 115px; min-width: 115px">
                <div class="column q-gutter-y-2xs" style="line-height: 1.1">
                  <div v-if="row.product_code" class="row items-center no-wrap q-gutter-x-2xs">
                    <div class="ellipsis col min-width-0">
                      <span class="text-grey-6 text-uppercase" style="font-size: 8px">C: </span>
                      <b class="text-dark" style="font-size: 10px">{{ row.product_code }}</b>
                    </div>
                    <q-btn
                      flat
                      round
                      dense
                      size="xs"
                      icon="ph ph-copy"
                      color="grey-6"
                      class="shrink-0"
                      @click="handleCopyCode(row.product_code, $t('product_based_costing.code'))"
                    >
                      <q-tooltip>{{ $t('product_based_costing.copy_code') }}</q-tooltip>
                    </q-btn>
                  </div>
                  <div v-if="row.barcode" class="row items-center no-wrap q-gutter-x-2xs">
                    <div class="ellipsis col min-width-0">
                      <span class="text-grey-6 text-uppercase" style="font-size: 8px">B: </span>
                      <span class="text-grey-9" style="font-size: 10px">{{ row.barcode }}</span>
                    </div>
                    <q-btn
                      flat
                      round
                      dense
                      size="xs"
                      icon="ph ph-copy"
                      color="grey-6"
                      class="shrink-0"
                      @click="handleCopyCode(row.barcode, $t('product_based_costing.barcode'))"
                    >
                      <q-tooltip>{{ $t('product_based_costing.copy_barcode') }}</q-tooltip>
                    </q-btn>
                  </div>
                </div>
              </td>

              <!-- Website -->
              <td v-if="visibleColumnMap.website" class="text-center" style="width: 50px; min-width: 50px">
                <a
                  v-if="row.website"
                  :href="row.website"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-primary text-caption text-weight-medium"
                >
                  {{ $t('product_based_costing.open') || 'Link' }}
                </a>
                <span v-else class="text-grey-5">-</span>
              </td>

              <!-- Purchase Price GBP (Inline Edit) -->
              <td v-if="visibleColumnMap.priceGbp" class="text-center tf-ops-col-tint--price" style="width: 56px; min-width: 56px">
                <div class="row justify-center">
                  <q-input
                    :model-value="getDraftValue(row, 'price_gbp')"
                    type="number"
                    step="0.01"
                    dense
                    outlined
                    hide-bottom-space
                    class="inline-edit-input excel-cell-input"
                    style="max-width: 50px"
                    input-class="text-center text-weight-bold"
                    @update:model-value="(val) => setDraftValue(row, 'price_gbp', val)"
                    @blur="saveDraftValue(row, 'price_gbp', { decimals: 2 })"
                    @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                  />
                </div>
                <div class="text-caption text-grey-7 text-weight-normal q-mt-2xs" style="font-size: 9px">
                  T: {{ formatMoney(row.totalPurchasePriceGbp) }}
                </div>
              </td>

              <!-- Price with VAT GBP -->
              <td
                v-if="showPriceGbpWithVatColumn && visibleColumnMap.priceGbpWithVat"
                class="text-center tf-ops-col-tint--price font-mono text-caption text-grey-9"
                style="width: 56px; min-width: 56px"
              >
                {{ formatMoney(row.priceGbpWithVat) }}
              </td>

              <!-- Total Purchase Price GBP -->
              <td v-if="visibleColumnMap.totalPurchasePriceGbp" class="text-center tf-ops-col-tint--price font-mono text-caption text-grey-9" style="width: 56px; min-width: 56px">
                {{ formatMoney(row.totalPurchasePriceGbp) }}
              </td>

              <!-- Product Wt (g) (Inline Edit) -->
              <td v-if="visibleColumnMap.productWeight" class="text-center font-mono text-grey-8" style="width: 56px; min-width: 56px">
                <div class="row justify-center">
                  <q-input
                    :model-value="getDraftValue(row, 'product_weight')"
                    type="number"
                    step="1"
                    dense
                    outlined
                    hide-bottom-space
                    class="inline-edit-input excel-cell-input"
                    style="max-width: 50px"
                    input-class="text-center font-mono"
                    @update:model-value="(val) => setDraftValue(row, 'product_weight', val)"
                    @blur="saveDraftValue(row, 'product_weight')"
                    @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                  />
                </div>
              </td>

              <!-- Package Wt (g) (Inline Edit) -->
              <td v-if="visibleColumnMap.packageWeight" class="text-center tf-ops-col-tint--weight font-mono text-grey-8" style="width: 56px; min-width: 56px">
                <div class="row justify-center">
                  <q-input
                    :model-value="getDraftValue(row, 'package_weight')"
                    type="number"
                    step="1"
                    dense
                    outlined
                    hide-bottom-space
                    class="inline-edit-input excel-cell-input"
                    style="max-width: 50px"
                    input-class="text-center font-mono"
                    @update:model-value="(val) => setDraftValue(row, 'package_weight', val)"
                    @blur="saveDraftValue(row, 'package_weight')"
                    @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                  />
                </div>
              </td>

              <!-- Total Wt (g) -->
              <td v-if="visibleColumnMap.totalWeight" class="text-center tf-ops-col-tint--weight font-mono text-caption text-grey-9" style="width: 56px; min-width: 56px">
                {{ row.totalWeight }}g
              </td>

              <!-- Cargo Rate -->
              <td v-if="visibleColumnMap.cargoRate" class="text-center font-mono text-caption text-grey-8" style="width: 56px; min-width: 56px">
                {{ formatMoney(row.cargoRate) }}
              </td>

              <!-- Cargo Cost GBP -->
              <td v-if="visibleColumnMap.cargoCostGbp" class="text-center font-mono text-caption text-grey-8" style="width: 56px; min-width: 56px">
                {{ formatMoney(row.cargoCostGbp) }}
              </td>

              <!-- Total Cost GBP -->
              <td v-if="visibleColumnMap.totalCostGbp" class="text-center tf-ops-col-tint--cost font-mono text-caption text-grey-9" style="width: 56px; min-width: 56px">
                {{ formatMoney(row.totalCostGbp) }}
              </td>

              <!-- Row Total Cost GBP -->
              <td v-if="visibleColumnMap.rowTotalCostGbp" class="text-center tf-ops-col-tint--cost font-mono text-caption text-grey-9" style="width: 56px; min-width: 56px">
                {{ formatMoney(row.rowTotalCostGbp) }}
              </td>

              <!-- Cost BDT -->
              <td v-if="visibleColumnMap.costBdt" class="text-center tf-ops-col-tint--cost font-mono text-weight-bold text-grey-9" style="width: 60px; min-width: 60px">
                <span class="pbc-cost-bdt-cell">
                  {{ formatMoney(row.costBdt) }}
                  <q-tooltip
                    anchor="top middle"
                    self="bottom middle"
                    :offset="[0, 6]"
                    class="pbc-cost-bdt-tooltip"
                  >
                    <pre class="pbc-cost-bdt-tooltip__pre">{{ formatCostBdtUnitBreakdown(row) }}</pre>
                  </q-tooltip>
                </span>
              </td>

              <!-- Row Total Cost BDT -->
              <td v-if="visibleColumnMap.totalCostBdt" class="text-center tf-ops-col-tint--cost font-mono text-caption text-grey-9" style="width: 60px; min-width: 60px">
                {{ formatMoney(row.totalCostBdt) }}
              </td>

              <!-- Offer Price BDT (Inline Edit) -->
              <td v-if="visibleColumnMap.offerPriceBdt" class="text-center tf-ops-col-tint--price" style="width: 84px; min-width: 84px">
                <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                  <q-icon
                    v-if="row.isOfferPriceManual"
                    name="ph ph-lock-key"
                    color="amber-8"
                    size="14px"
                  >
                    <q-tooltip>{{ $t('product_based_costing.offer_locked_tooltip') }}</q-tooltip>
                  </q-icon>

                  <span :class="{ 'pbc-cost-bdt-cell': !row.isOfferPriceManual }">
                    <q-input
                      :model-value="getDraftValue(row, 'offer_price')"
                      type="number"
                      step="1"
                      dense
                      outlined
                      hide-bottom-space
                      class="inline-edit-input excel-cell-input"
                      style="max-width: 58px"
                      input-class="text-center text-weight-bold text-positive"
                      @update:model-value="(val) => setDraftValue(row, 'offer_price', val)"
                      @blur="saveDraftValue(row, 'offer_price', { decimals: 0 })"
                      @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                    />
                    <q-tooltip
                      v-if="!row.isOfferPriceManual"
                      anchor="top middle"
                      self="bottom middle"
                      :offset="[0, 6]"
                      :delay="400"
                      class="pbc-cost-bdt-tooltip"
                    >
                      <pre class="pbc-cost-bdt-tooltip__pre">{{ formatOfferPriceBdtBreakdown(row) }}</pre>
                    </q-tooltip>
                  </span>

                  <q-btn
                    v-if="row.isOfferPriceManual"
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-arrows-clockwise"
                    color="grey-7"
                    :aria-label="$t('product_based_costing.unlock_offer_price')"
                    @click.stop="unlockOfferPrice(row)"
                  >
                    <q-tooltip>{{ $t('product_based_costing.unlock_offer_price_tooltip') }}</q-tooltip>
                  </q-btn>
                </div>
              </td>

              <!-- Total Offer BDT -->
              <td v-if="visibleColumnMap.totalBdt" class="text-center tf-ops-col-tint--price font-mono text-weight-bold text-positive" style="width: 64px; min-width: 64px">
                {{ formatMoney(row.totalBdt) }}
              </td>

              <!-- Profit Per Unit BDT -->
              <td v-if="visibleColumnMap.profitPerUnitBdt" class="text-center font-mono text-caption text-teal-9 text-weight-bold" style="width: 56px; min-width: 56px">
                {{ formatMoney(row.profitPerUnitBdt) }}
              </td>

              <!-- Row Total Profit BDT -->
              <td v-if="visibleColumnMap.profitBdt" class="text-center font-mono text-caption text-teal-9 text-weight-bold" style="width: 56px; min-width: 56px">
                {{ formatMoney(row.profitBdt) }}
              </td>

              <!-- Profit Rate % -->
              <td v-if="visibleColumnMap.profitRate" class="text-center font-mono text-caption text-grey-8" style="width: 50px; min-width: 50px">
                {{ row.profitRate.toFixed(2) }}%
              </td>

              <!-- Status -->
              <td v-if="visibleColumnMap.status" class="text-center" style="width: 65px; min-width: 65px">
                <q-badge
                  rounded
                  dense
                  class="text-weight-bold text-capitalize text-caption q-px-xs"
                  :color="getItemStatusBadge(row.status).color"
                  :text-color="getItemStatusBadge(row.status).textColor"
                >
                  {{ row.status || 'pending' }}
                </q-badge>
              </td>
            </tr>

            <tr v-if="isFetchingMoreItems">
              <td colspan="20" class="text-center q-py-sm">
                <q-spinner-dots color="primary" size="28px" />
                <div class="text-caption text-grey-6 q-mt-xs">Loading more items...</div>
              </td>
            </tr>
          </template>

          <!-- Empty State -->
          <tr v-else-if="!isLoading">
            <td colspan="20" class="text-center q-py-xl text-grey-6">
              <div class="column items-center justify-center q-py-lg">
                <q-icon name="ph ph-calculator" size="48px" class="text-grey-4 q-mb-sm" />
                <div class="text-subtitle1 text-weight-bold text-grey-8">No costing line items in this file</div>
                <div class="text-caption text-grey-6 q-mb-md">
                  Add products from catalog or pull from demand backlog to build this quote.
                </div>
                <div class="row q-gutter-sm">
                  <q-btn
                    outline
                    color="primary"
                    icon="ph ph-squares-four"
                    :label="$t('product_based_costing.browse_catalog')"
                    no-caps
                    class="rounded-sq-btn"
                    style="border-radius: 8px"
                    @click="openAddProductCartPage"
                  />
                  <q-btn
                    color="primary"
                    icon="ph ph-plus"
                    :label="$t('product_based_costing.add_products')"
                    unelevated
                    no-caps
                    class="rounded-sq-btn"
                    style="border-radius: 8px"
                    @click="openCatalogDialog"
                  />
                  <q-btn
                    v-if="availableBacklogItems.length"
                    color="orange-9"
                    icon="ph ph-tray"
                    label="Add from Backlog"
                    outline
                    no-caps
                    class="rounded-sq-btn"
                    style="border-radius: 8px"
                    @click="openBacklogDrawer"
                  />
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <div v-else-if="isLoading" class="q-pa-md">
        <TfSkeletonRows :rows="6" :cols="3" height="18px" />
      </div>

      <div v-else-if="!tableRows.length" class="column items-center justify-center q-py-xl text-grey-6">
        <q-icon name="ph ph-package" size="48px" class="q-mb-sm" />
        <div class="text-body2">No line items yet.</div>
      </div>

      <div v-else class="q-pa-md">
        <div class="row q-col-gutter-sm">
          <div
            v-for="row in tableRows"
            :key="row.id"
            class="col-12 col-md-6"
          >
            <ProductBasedCostingItemCard
              :row="row"
              :catalog="catalogForRow(row.product_id)"
              :buy-mark="buyMark"
              :sell-mark="sellMark"
              :currency-i18n="currencyI18n"
              :selected="selectedRowIds.includes(row.id)"
              @toggle-select="(checked) => toggleRowSelection(row.id, checked)"
            />
          </div>
        </div>
        <div v-if="isFetchingMoreItems" class="row justify-center q-py-md">
          <q-spinner-dots color="primary" size="32px" />
        </div>
        <div v-else-if="hasMoreItems" class="row justify-center q-py-md">
          <q-btn
            outline
            dense
            no-caps
            color="primary"
            label="Load more"
            @click="fetchNextPage()"
          />
        </div>
      </div>
    </div>

    <!-- Bottom Sticky Footer Section: Scrollbar Only -->
    <div
      v-if="itemsView === 'table'"
      class="pbc-v2-footer-section bg-white border-top q-px-md q-py-xs shrink-0 shadow-xs row items-center justify-end"
    >
      <div class="excel-scrollbar-wrapper row items-center no-wrap">
        <button class="excel-scroll-arrow-btn" @click="scrollTableByStep(-150)">
          <q-icon name="ph ph-caret-left" size="13px" />
        </button>
        <div
          ref="scrollTrackRef"
          class="excel-scroll-track cursor-pointer"
          @click="onTrackClick"
        >
          <div
            class="excel-scroll-thumb"
            :style="{ width: scrollThumbWidth + '%', left: scrollThumbLeft + '%' }"
            @mousedown="startThumbDrag"
          />
        </div>
        <button class="excel-scroll-arrow-btn" @click="scrollTableByStep(150)">
          <q-icon name="ph ph-caret-right" size="13px" />
        </button>
      </div>
    </div>

    <!-- Reusable Drawers & Dialogs -->
    <template v-if="!isLoading">
      <PbcBacklogSuggestDrawer
        v-model="showBacklogDrawer"
        :items="availableBacklogItems"
        :already-on-file-items="alreadyOnFileBacklogItems"
        :loading="backlog.loading.value"
        :adding="backlog.saving.value"
        @add="handleConsumeBacklog"
      />

      <ProductBasedCostingFileDialog
        v-model="showFileDialog"
        :data="editFormData"
        @submit="handleUpdateFileDialog"
      />

      <ProductBasedCostingSettingsDrawer
        v-model="showSettingsDrawer"
        :file="file"
        :summary-metrics="summaryMetrics"
        :conversion-rate="conversionRateValue"
        :cargo-rate="cargoRateValue"
        :profit-rate="profitRateValue"
        :vat-rate="vatRateValue"
        :offer-pricing-mode="offerPricingModeValue"
        :summary-file-meta="summaryFileMeta"
        :customers="customerAccounts"
        :status="status"
        :show-cancel="status !== 'delivered' && status !== 'cancelled'"
        :is-primary-loading="updatingStatus"
        :is-cancelling="updatingStatus && targetUpdatingStatus === 'cancelled'"
        :primary-disabled="pbcPrimaryDisabled"
        :primary-disabled-reason="pbcPrimaryDisabledReason"
        :initial-tab="settingsDrawerInitialTab"
        :can-open-offer-pdf="costingItems.length > 0"
        @update-file="handleUpdateFileDirect"
        @update-rates="handleUpdateRatesDirect"
        @primary-action="handlePbcPrimaryAction"
        @cancel-file="onCancelFile"
        @override-status="showStatusOverrideDialog = true"
        @drawer-action="onSettingsDrawerAction"
      />

      <ProductBasedCostingStatusOverrideDialog
        v-if="file"
        v-model="showStatusOverrideDialog"
        :file="file"
        :loading="updatingStatus"
        @apply="onStatusOverride"
      />

      <ProductBasedCostingItemAddDialog
        v-model="showItemDialog"
        :product-based-costing-file-id="fileId"
        :item-data="selectedItem"
        :default-vendor-code="file?.vendor_code ?? null"
        @created="handleCreated"
        @updated="handleUpdated"
      />

      <AddCostingItemsDrawer
        v-if="fileId"
        v-model="catalogDrawerOpen"
        :file-id="fileId"
        @saved="refreshAfterCatalogChange"
        @browse-catalog="openAddProductCartDrawer"
        @create-new-product="onCatalogCreateNewProduct"
      />

      <AddProductCartDrawer
        v-if="fileId"
        v-model="addProductCartDrawerOpen"
        :file-id="fileId"
        @closed="refreshAfterCatalogChange"
      />

      <AppResizableOverlayPanel
        v-model="showBulkPasteDialog"
        storage-key="product_based_costing.bulk-paste-width"
        :default-width="640"
        :min-width="400"
        :max-width="960"
        aria-label="Bulk paste costing values"
      >
        <div class="bulk-paste-overlay column no-wrap full-height">
          <div class="bulk-paste-overlay__header row items-center justify-between q-px-md q-pt-md q-pb-sm shrink-0">
            <div class="row items-center q-gutter-x-sm min-width-0">
              <q-avatar color="primary" text-color="white" icon="ph ph-clipboard-text" size="32px" />
              <div class="min-width-0">
                <div class="text-subtitle1 text-weight-bold text-grey-9">Bulk Paste {{ bulkPasteFieldLabel }}</div>
                <div class="text-caption text-grey-6">
                  Click a cell, then paste. Columns: Barcode, Product code, {{ bulkPasteFieldLabel }}.
                </div>
              </div>
            </div>
            <q-btn icon="ph ph-x" flat round dense color="grey-6" aria-label="Close" @click="showBulkPasteDialog = false" />
          </div>

          <div class="bulk-paste-overlay__body col q-px-md q-py-md overflow-auto">
            <div class="bulk-paste-grid-wrap" @paste.capture="onBulkPasteGridPaste">
              <table class="bulk-paste-grid">
                <thead>
                  <tr>
                    <th>Barcode</th>
                    <th>Product code</th>
                    <th>{{ bulkPasteFieldLabel }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(row, rowIdx) in bulkPasteRows" :key="row.rowKey">
                    <td>
                      <input
                        v-model="row.barcode"
                        class="bulk-paste-cell"
                        :data-row="rowIdx"
                        data-col="0"
                        @focus="onBulkPasteCellFocus(rowIdx, 0)"
                      />
                    </td>
                    <td>
                      <input
                        v-model="row.product_code"
                        class="bulk-paste-cell"
                        :data-row="rowIdx"
                        data-col="1"
                        @focus="onBulkPasteCellFocus(rowIdx, 1)"
                      />
                    </td>
                    <td>
                      <input
                        v-model="row.value"
                        class="bulk-paste-cell bulk-paste-cell--value"
                        :data-row="rowIdx"
                        data-col="2"
                        @focus="onBulkPasteCellFocus(rowIdx, 2)"
                      />
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div class="bulk-paste-overlay__footer row items-center justify-end q-gutter-sm q-pa-md shrink-0">
            <q-btn flat label="Cancel" color="grey-7" no-caps :disable="bulkPasteSaving" @click="showBulkPasteDialog = false" />
            <q-btn
              unelevated
              color="primary"
              icon="ph ph-check"
              label="Apply Paste"
              no-caps
              class="rounded-borders q-px-md text-weight-bold"
              :loading="bulkPasteSaving"
              :disable="bulkPasteSaving"
              @click="applyBulkPaste"
            />
          </div>
        </div>
      </AppResizableOverlayPanel>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar, copyToClipboard } from 'quasar';
import { useI18n } from 'vue-i18n';
import { useQueryClient } from '@tanstack/vue-query';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import SmartImage from 'src/components/SmartImage.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfSkeletonRows from 'src/components/ui/TfSkeletonRows.vue';
import ProductBasedCostingItemCard from '../components/ProductBasedCostingItemCard.vue';
import AddCostingItemsDrawer from '../components/AddCostingItemsDrawer.vue';
import AddProductCartDrawer from '../components/AddProductCartDrawer.vue';
import { productBasedCostingService } from '../services/productBasedCostingService';
import type { ProductBasedCostingItemUpdateInput } from '../types';
import PbcBacklogSuggestDrawer from '../components/PbcBacklogSuggestDrawer.vue';
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue';
import ProductBasedCostingItemAddDialog from '../components/ProductBasedCostingItemAddDialog.vue';
import ProductBasedCostingSettingsDrawer, {
  type PbcSettingsDrawerAction,
} from '../components/ProductBasedCostingSettingsDrawer.vue';
import { useProductBasedCostingFileDetailsPageQuery } from '../composables/useProductBasedCostingFileDetailsPageQuery';
import { useCustomerAccounts } from 'src/modules/customer/composables/useCustomerAccounts';
import ProductBasedCostingStatusOverrideDialog from '../components/ProductBasedCostingStatusOverrideDialog.vue';
import ProductBasedCostingStatusWorkflowBar from '../components/ProductBasedCostingStatusWorkflowBar.vue';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { useUpdateProductBasedCostingFileMutation } from '../composables/useProductBasedCostingFileMutations';
import {
  reorderPbcItemsInCache,
  useDeleteProductBasedCostingItemMutation,
  useDeleteProductBasedCostingItemsBulkMutation,
  useUpdateProductBasedCostingItemMutation,
  updatePbcItemInCache,
  useRecalculateOfferPricesMutation,
} from '../composables/useProductBasedCostingItemMutations';
import type { ProductBasedCostingItem } from '../types';
import { usePbcBacklog, type BacklogItem } from '../composables/usePbcBacklog';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';
import {
  allColumnNames,
  alwaysVisibleColumns,
  columnSelectorOptions,
  formatMoney,
  formatStatusLabel,
  getDefaultVisibleColumnsForStatus,
  normalizePbcFileStatus,
  quoteVisibleColumns,
  useProductBasedCostingFileDetailsState,
} from '../composables/useProductBasedCostingFileDetailsState';
import {
  getStaffPbcPrimaryAction,
  getStaffPbcPrimaryActionTargetStatus,
  type StaffPbcPrimaryAction,
} from '../utils/pbcFileStatus';
import {
  computeProfitRatePercentOnCost,
  getPriceGbpWithVat,
  getUnitCostBdt,
  normalizeOfferPriceBdt,
  normalizeOfferPricingMode,
  resolveEffectiveOfferPriceBdt,
} from '../utils/pricing';
import {
  pbcCurrencyMark,
  pbcFileBuyCurrencyCode,
  pbcFileSellCurrencyCode,
} from '../utils/pbcFileCurrencies';
import { DEFAULT_PBC_PREVIEW_SCREENSHOT_COLUMNS } from '../utils/pbcPreviewScreenshot';
import { useGlobalCurrencies } from 'src/modules/global_reference/composables/useGlobalCurrencies';

const props = defineProps<{
  id?: string | number;
}>();

const $q = useQuasar();
const { t } = useI18n();

const handleCopyCode = (text: string, label: string) => {
  void copyToClipboard(text)
    .then(() => {
      $q.notify({
        type: 'positive',
        message: t('product_based_costing.copied_to_clipboard', { label }),
        timeout: 1000,
      });
    })
    .catch(() => {
      $q.notify({
        type: 'negative',
        message: t('product_based_costing.failed_to_copy', { label }),
        timeout: 1000,
      });
    });
};

const copyAllLineNames = () => {
  const names = tableRows.value
    .map((row) => (row.name || '').trim())
    .filter((name) => name.length > 0);
  if (names.length === 0) {
    $q.notify({
      type: 'warning',
      message: 'No product names to copy.',
      timeout: 1500,
    });
    return;
  }
  void copyToClipboard(names.join('\n')).then(() => {
    $q.notify({
      type: 'positive',
      message: `Copied ${names.length} product name${names.length === 1 ? '' : 's'}.`,
      timeout: 1500,
    });
  });
};

const route = useRoute();
const router = useRouter();
const tenantStore = useTenantStore();
const queryClient = useQueryClient();
const backlog = usePbcBacklog();

const fileId = computed(() => {
  const rawId = props.id ?? route.params.id;
  const parsed = Number(rawId);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
});

// Queries (single bundle RPC on first page; same RPC for load-more with cursor)
const {
  file,
  costingItems,
  summaryMetrics,
  hasMoreItems,
  isLoadingFile,
  isLoadingItems,
  isFetchingMoreItems,
  fetchNextPage,
  isRefreshing,
  refresh,
  catalogByProductId,
} = useProductBasedCostingFileDetailsPageQuery(fileId);

const customerTenantId = computed(
  () => file.value?.tenant_id ?? tenantStore.selectedTenant?.id ?? null,
);
const { customerGroupOptions: customerAccounts } = useCustomerAccounts(customerTenantId);

const PBC_ITEMS_VIEW_STORAGE_KEY = 'pbc-file-items-view';
type PbcItemsViewMode = 'table' | 'card';

const readStoredItemsView = (): PbcItemsViewMode => {
  if (typeof localStorage === 'undefined') return 'table';
  return localStorage.getItem(PBC_ITEMS_VIEW_STORAGE_KEY) === 'card' ? 'card' : 'table';
};

const itemsView = ref<PbcItemsViewMode>(readStoredItemsView());

watch(itemsView, (mode) => {
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(PBC_ITEMS_VIEW_STORAGE_KEY, mode);
  }
});

const catalogForRow = (productId: number | null) => {
  if (productId == null) return null;
  return catalogByProductId.value.get(productId) ?? null;
};

const isLoading = computed(() => isLoadingFile.value || isLoadingItems.value);

// State
const selectedRowIds = ref<number[]>([]);
const showBacklogDrawer = ref(false);
const showFileDialog = ref(false);
const showSettingsDrawer = ref(false);
const settingsDrawerInitialTab = ref<string | undefined>(undefined);
const showStatusOverrideDialog = ref(false);
const showItemDialog = ref(false);
const catalogDrawerOpen = ref(false);
const addProductCartDrawerOpen = ref(false);
const selectedItem = ref<ProductBasedCostingItem | null>(null);
const updatingStatus = ref(false);
const targetUpdatingStatus = ref<string | null>(null);

type PbcBulkPasteField =
  | 'quantity'
  | 'price_gbp'
  | 'product_weight'
  | 'package_weight'
  | 'offer_price';

const showBulkPasteDialog = ref(false);
const bulkPasteField = ref<PbcBulkPasteField>('quantity');
const bulkPasteSaving = ref(false);
type BulkPasteGridRow = {
  rowKey: string;
  barcode: string;
  product_code: string;
  value: string;
};
const bulkPasteRows = ref<BulkPasteGridRow[]>([]);
const bulkPasteFocus = ref({ row: 0, col: 0 });
const bulkPasteCols = ['barcode', 'product_code', 'value'] as const;

const bulkPasteFieldLabel = computed(() => {
  switch (bulkPasteField.value) {
    case 'quantity':
      return 'Quantity';
    case 'price_gbp':
      return 'Price';
    case 'product_weight':
      return 'Product Weight';
    case 'package_weight':
      return 'Package Weight';
    case 'offer_price':
      return 'Offer Price';
    default:
      return 'Values';
  }
});

const ratesExpanded = ref(false);
const savingRates = ref(false);
const localRates = reactive({
  conversion_rate: 140,
  cargo_rate_kg_gbp: 0,
  profit_rate: 25,
  vat_rate: 0,
  offer_pricing_mode: 'landed_cost_plus' as 'landed_cost_plus' | 'gbp_vat_then_profit',
  buy_currency_id: null as number | null,
  sell_currency_id: null as number | null,
});

const offerPricingModeOptions = [
  { label: 'On cost', value: 'landed_cost_plus' },
  { label: 'VAT then £', value: 'gbp_vat_then_profit' },
];

// Inline title editing
const isEditingName = ref(false);
const editingNameValue = ref('');
const savingName = ref(false);
const nameInputRef = ref<HTMLInputElement | { focus: () => void; select: () => void } | null>(null);

// Mutations
const updateFileMutation = useUpdateProductBasedCostingFileMutation();
const updateItemMutation = useUpdateProductBasedCostingItemMutation();
const deleteItemMutation = useDeleteProductBasedCostingItemMutation();
const deleteItemsBulkMutation = useDeleteProductBasedCostingItemsBulkMutation();
const recalculateOfferPricesMutation = useRecalculateOfferPricesMutation();

// Rates (saved file only — draft edits stay in localRates until Save)
const cargoRateValue = computed(() => file.value?.cargo_rate_kg_gbp ?? 0);
const conversionRateValue = computed(() => file.value?.conversion_rate ?? 140);
const profitRateValue = computed(() => file.value?.profit_rate ?? 25);
const vatRateValue = computed(() => file.value?.vat_rate ?? 0);
const offerPricingModeValue = computed(() =>
  normalizeOfferPricingMode(file.value?.offer_pricing_mode),
);

const showPriceGbpWithVatColumn = computed(
  () => offerPricingModeValue.value === 'gbp_vat_then_profit',
);

const { currencies, loadingCurrencies } = useGlobalCurrencies();

const currencyOptions = computed(() =>
  currencies.value.map((c) => ({
    label: `${c.code} (${c.symbol})`,
    value: c.id,
  })),
);

const fileBuyCurrencyCode = computed(() => pbcFileBuyCurrencyCode(file.value));
const fileSellCurrencyCode = computed(() => pbcFileSellCurrencyCode(file.value));
const buyMark = computed(() => pbcCurrencyMark(fileBuyCurrencyCode.value));
const sellMark = computed(() => pbcCurrencyMark(fileSellCurrencyCode.value));

const currencyI18n = computed(() => ({
  buy: fileBuyCurrencyCode.value,
  sell: fileSellCurrencyCode.value,
}));

const currencyCodeById = (id: number | null | undefined): string | null => {
  if (id == null) return null;
  const row = currencies.value.find((c) => c.id === id);
  return row?.code?.trim() ? row.code.toUpperCase() : null;
};

const editorBuyCurrencyCode = computed(
  () =>
    currencyCodeById(localRates.buy_currency_id) ??
    fileBuyCurrencyCode.value,
);
const editorSellCurrencyCode = computed(
  () =>
    currencyCodeById(localRates.sell_currency_id) ??
    fileSellCurrencyCode.value,
);
const editorBuyMark = computed(() => pbcCurrencyMark(editorBuyCurrencyCode.value));
const editorSellMark = computed(() => pbcCurrencyMark(editorSellCurrencyCode.value));
const editorCurrencyI18n = computed(() => ({
  buy: editorBuyCurrencyCode.value,
  sell: editorSellCurrencyCode.value,
}));

function formatCostBdtUnitBreakdown(row: {
  product_weight: number;
  package_weight: number;
  totalWeight: number;
  price_gbp: number;
  cargoRate: number;
  cargoCostGbp: number;
  totalCostGbp: number;
  costBdt: number;
}): string {
  const fx = conversionRateValue.value || 140;
  const kg = row.totalWeight / 1000;
  const kgLabel = kg.toFixed(4).replace(/\.?0+$/, '');
  const buy = buyMark.value;
  const buyCode = fileBuyCurrencyCode.value;
  const sellCode = fileSellCurrencyCode.value;

  return [
    'Landed cost per unit (BDT)',
    '',
    '1) Weight',
    `   Product ${row.product_weight}g + package ${row.package_weight}g`,
    `   = ${row.totalWeight}g (${kgLabel} kg)`,
    '',
    '2) Cargo per unit',
    `   ${kgLabel} kg × ${formatMoney(row.cargoRate)} ${buyCode}/kg`,
    `   = ${buy}${formatMoney(row.cargoCostGbp)}`,
    '',
    '3) Landed cost per unit (buy currency)',
    `   ${buy}${formatMoney(row.price_gbp)} purchase`,
    `   + ${buy}${formatMoney(row.cargoCostGbp)} cargo`,
    `   = ${buy}${formatMoney(row.totalCostGbp)}`,
    '',
    '4) FX to sell currency',
    `   ${buy}${formatMoney(row.totalCostGbp)} × ${fx}`,
    `   = ${formatMoney(row.costBdt)} ${sellCode}`,
  ].join('\n');
}

function formatOfferPriceBdtBreakdown(row: {
  price_gbp: number;
  product_weight: number;
  package_weight: number;
  cargoRate: number;
  cargoCostGbp: number;
  offer_price: number;
}): string {
  const fx = conversionRateValue.value || 140;
  const profitRate = profitRateValue.value || 0;
  const vatRate = vatRateValue.value || 0;
  const vatMode = offerPricingModeValue.value === 'gbp_vat_then_profit';
  const buy = buyMark.value;
  const sellCode = fileSellCurrencyCode.value;
  const webGbp = row.price_gbp;
  const pricedGbp = vatMode ? getPriceGbpWithVat(webGbp, vatRate) : webGbp;
  const cargoGbp = vatMode
    ? ((row.product_weight + row.package_weight) / 1000) * row.cargoRate
    : row.cargoCostGbp;
  const landedGbp = Math.round((pricedGbp + cargoGbp) * 100) / 100;
  const offerCostBdt = getUnitCostBdt({
    priceGbp: pricedGbp,
    productWeight: row.product_weight,
    packageWeight: row.package_weight,
    cargoRate: row.cargoRate,
    conversionRate: fx,
  });
  const beforeRound = offerCostBdt + (offerCostBdt * profitRate) / 100;
  const lines = ['Offer price per unit', ''];
  let step = 1;
  if (vatMode) {
    lines.push(
      `${step}) VAT on web price`,
      `   ${buy}${formatMoney(webGbp)} × (1 + ${vatRate}%)`,
      `   = ${buy}${formatMoney(pricedGbp)}`,
      '',
    );
    step += 1;
  }
  lines.push(
    `${step}) Add cargo`,
    `   ${buy}${formatMoney(pricedGbp)} + ${buy}${formatMoney(cargoGbp)} cargo`,
    `   = ${buy}${formatMoney(landedGbp)}`,
    '',
    `${step + 1}) FX to ${sellCode}`,
    `   ${buy}${formatMoney(landedGbp)} × ${fx}`,
    `   = ${formatMoney(offerCostBdt)} ${sellCode} (ceil)`,
    '',
    `${step + 2}) Profit ${profitRate}%`,
    `   ${formatMoney(offerCostBdt)} + ${profitRate}%`,
    `   = ${formatMoney(beforeRound)} ${sellCode}`,
    '',
    `${step + 3}) Round up to 0 or 5`,
    `   = ${formatMoney(row.offer_price)} ${sellCode}`,
  );
  return lines.join('\n');
}

function syncLocalRatesFromFile(source: NonNullable<typeof file.value>) {
  localRates.conversion_rate = source.conversion_rate ?? 140;
  localRates.cargo_rate_kg_gbp = source.cargo_rate_kg_gbp ?? 0;
  localRates.profit_rate = source.profit_rate ?? 25;
  localRates.vat_rate = source.vat_rate ?? 0;
  localRates.offer_pricing_mode = normalizeOfferPricingMode(source.offer_pricing_mode);
  localRates.buy_currency_id = source.buy_currency_id ?? null;
  localRates.sell_currency_id = source.sell_currency_id ?? null;
}

function toggleRatesEditor() {
  if (!ratesExpanded.value && file.value) {
    syncLocalRatesFromFile(file.value);
  }
  ratesExpanded.value = !ratesExpanded.value;
}

function cancelRatesEdit() {
  if (file.value) {
    syncLocalRatesFromFile(file.value);
  }
  ratesExpanded.value = false;
}

watch(
  file,
  (newFile) => {
    if (!newFile || ratesExpanded.value) return;
    syncLocalRatesFromFile(newFile);
  },
  { immediate: true },
);

const totalItemsCount = computed(
  () => summaryMetrics.value.lineCount || costingItems.value.length,
);

const summaryFileMeta = computed(() => {
  const customer = customerAccounts.value.find(
    (row) => row.customer_group_id === file.value?.customer_group_id,
  );
  return {
    name: file.value?.name ?? null,
    orderFor: file.value?.order_for ?? null,
    customerLabel: customer?.group_name ?? null,
    status: file.value?.status ?? null,
    vendorCode: file.value?.vendor_code ?? null,
    marketCode: file.value?.market_code ?? null,
  };
});

// Composable State & Logic Helpers
const { downloadExcel } = useProductBasedCostingFileDetailsState({
  costingItems,
  cargoRateValue,
  conversionRateValue,
});

// Column Preferences
const { visibleColumns } = useMembershipColumnPreference({
  preferenceKey: 'ui.productBasedCosting.fileDetailsVisibleColumns',
  allColumnNames,
  alwaysVisibleColumns: ['select', 'sl', 'image', 'name'],
  defaultVisibleColumns: quoteVisibleColumns,
});

const visibleColumnMap = computed<Record<string, boolean>>(() => {
  const map: Record<string, boolean> = {};
  for (const col of allColumnNames) {
    map[col] = visibleColumns.value.includes(col);
  }
  return map;
});

const localVisibleColumns = computed({
  get: () => visibleColumns.value,
  set: (val: string[]) => {
    visibleColumns.value = val;
  },
});

const selectableColumnValues = columnSelectorOptions.map((option) => option.value);

const allSelectableColumnsSelected = computed({
  get: () => selectableColumnValues.every((value) => visibleColumns.value.includes(value)),
  set: (checked: boolean) => {
    visibleColumns.value = checked
      ? [...alwaysVisibleColumns, ...selectableColumnValues]
      : [...alwaysVisibleColumns];
  },
});

const columnSearchQuery = ref('');
const filteredColumnOptions = computed(() => {
  const q = columnSearchQuery.value.trim().toLowerCase();
  if (!q) return columnSelectorOptions;
  return columnSelectorOptions.filter((opt) => opt.label.toLowerCase().includes(q));
});

function syncPriceGbpWithVatColumnVisibility() {
  if (showPriceGbpWithVatColumn.value) {
    if (!visibleColumns.value.includes('priceGbpWithVat')) {
      const keys = [...visibleColumns.value];
      const idx = keys.indexOf('priceGbp');
      if (idx >= 0) keys.splice(idx + 1, 0, 'priceGbpWithVat');
      else keys.push('priceGbpWithVat');
      visibleColumns.value = keys;
    }
  } else if (visibleColumns.value.includes('priceGbpWithVat')) {
    visibleColumns.value = visibleColumns.value.filter((col) => col !== 'priceGbpWithVat');
  }
}

watch(offerPricingModeValue, syncPriceGbpWithVatColumnVisibility, { immediate: true });

// Table computed rows with financial values
const tableRows = computed(() => {
  const fx = conversionRateValue.value || 140;
  const cargoRate = cargoRateValue.value || 0;
  const fileProfitRate = profitRateValue.value || 0;

  return costingItems.value.map((item, index) => {
    const qty = item.quantity ?? 1;
    const confirmedQty = item.confirmed_quantity ?? qty;
    const priceGbp = item.price_gbp ?? 0;
    const totalPurchasePriceGbp = priceGbp * qty;

    const prodWt = item.product_weight ?? 0;
    const pkgWt = item.package_weight ?? 0;
    const totalWeight = prodWt + pkgWt;
    const totalUnitWtKg = totalWeight / 1000;

    const cargoCostGbp = totalUnitWtKg * cargoRate;
    const totalCostGbp = priceGbp + cargoCostGbp;
    const rowTotalCostGbp = totalCostGbp * qty;

    const costBdt = totalCostGbp * fx;
    const totalCostBdt = rowTotalCostGbp * fx;

    const itemProfitRate = item.profit_rate ?? fileProfitRate;
    const isOfferPriceManual = item.is_offer_price_manual === true;
    const offerPriceBdt = resolveEffectiveOfferPriceBdt(item, {
      priceGbp,
      productWeight: prodWt,
      packageWeight: pkgWt,
      cargoRate,
      conversionRate: fx,
      profitRate: itemProfitRate,
      vatRate: vatRateValue.value || 0,
      offerPricingMode: offerPricingModeValue.value,
    });

    const totalBdt = offerPriceBdt * qty;
    const profitPerUnitBdt = offerPriceBdt - costBdt;
    const profitBdt = profitPerUnitBdt * qty;

    return {
      id: item.id,
      sl: index + 1,
      name: item.name ?? '',
      product_code: item.product_code ?? '',
      product_id: item.product_id ?? null,
      barcode: item.barcode ?? '',
      imageUrl: item.image_url ?? '',
      brand: item.brand ?? '',
      note: item.note ?? '',
      website: item.website ?? '',
      quantity: qty,
      confirmed_quantity: confirmedQty,
      price_gbp: priceGbp,
      priceGbpWithVat: getPriceGbpWithVat(priceGbp, vatRateValue.value || 0),
      totalPurchasePriceGbp,
      product_weight: prodWt,
      package_weight: pkgWt,
      totalWeight,
      cargoRate,
      cargoCostGbp,
      totalCostGbp,
      rowTotalCostGbp,
      costBdt,
      totalCostBdt,
      offer_price: offerPriceBdt,
      isOfferPriceManual,
      totalBdt,
      profitPerUnitBdt,
      profitBdt,
      profitRate: computeProfitRatePercentOnCost(costBdt, profitPerUnitBdt),
      status: item.status ?? 'pending',
      raw: item,
    };
  });
});

// Draft Values for Inline Editing
const draftValues = reactive<Record<string, Record<string, unknown>>>({});
const inlineSaveInFlight = new Set<string>();

function getDraftValue(
  row: { id: number; raw: ProductBasedCostingItem; offer_price?: number; isOfferPriceManual?: boolean },
  field: keyof ProductBasedCostingItem,
): string | number | null {
  if (draftValues[row.id]?.[field] !== undefined) {
    return draftValues[row.id][field] as string | number | null;
  }
  if (field === 'offer_price') {
    if (row.isOfferPriceManual && row.raw.offer_price != null) {
      return normalizeOfferPriceBdt(row.raw.offer_price);
    }
    return normalizeOfferPriceBdt(row.offer_price ?? 0);
  }
  if (field === 'confirmed_quantity') {
    if (row.raw.confirmed_quantity != null) {
      return row.raw.confirmed_quantity;
    }
    return row.raw.quantity ?? '';
  }
  const raw = row.raw[field];
  if (typeof raw === 'boolean') return raw ? 1 : 0;
  return (raw ?? '') as string | number | null;
}

function setDraftValue(row: { id: number }, field: string, val: unknown) {
  if (!draftValues[row.id]) {
    draftValues[row.id] = {};
  }
  draftValues[row.id][field] = val;
}

async function saveDraftValue(
  row: { id: number; raw: ProductBasedCostingItem; isOfferPriceManual?: boolean; offer_price?: number },
  field: keyof ProductBasedCostingItem,
  opts?: { decimals?: number },
) {
  if (!draftValues[row.id] || draftValues[row.id][field] === undefined) return;

  const saveKey = `${row.id}:${String(field)}`;
  if (inlineSaveInFlight.has(saveKey)) return;

  const rawVal = draftValues[row.id][field];

  let parsedVal: number | string | null = rawVal as any;
  if (typeof rawVal === 'string' && rawVal.trim() !== '') {
    const num = Number(rawVal);
    if (!isNaN(num)) {
      parsedVal = opts?.decimals !== undefined ? Number(num.toFixed(opts.decimals)) : num;
    }
  } else if (rawVal === '') {
    parsedVal = null;
  }

  if (field === 'offer_price') {
    if (parsedVal != null && parsedVal !== '') {
      parsedVal = normalizeOfferPriceBdt(parsedVal);
    }
    const currentPrice = row.isOfferPriceManual && row.raw.offer_price != null
      ? normalizeOfferPriceBdt(row.raw.offer_price)
      : normalizeOfferPriceBdt(row.offer_price ?? 0);
    if (parsedVal === currentPrice) {
      delete draftValues[row.id][field];
      return;
    }
  } else if (row.raw[field] === parsedVal) {
    delete draftValues[row.id][field];
    return;
  }

  const previousItem = { ...row.raw };
  const optimisticItem: ProductBasedCostingItem = {
    ...row.raw,
    [field]: parsedVal as ProductBasedCostingItem[keyof ProductBasedCostingItem],
  };
  if (field === 'offer_price') {
    optimisticItem.is_offer_price_manual = true;
    optimisticItem.offer_price = parsedVal != null ? Number(parsedVal) : null;
  }

  delete draftValues[row.id][field];
  if (fileId.value) {
    updatePbcItemInCache(queryClient, fileId.value, optimisticItem);
  }

  const payload: Partial<ProductBasedCostingItem> & { id: number } = {
    id: row.id,
    [field]: parsedVal,
  };
  if (field === 'offer_price') {
    payload.is_offer_price_manual = true;
    payload.offer_price = parsedVal != null ? Number(parsedVal) : null;
  }

  inlineSaveInFlight.add(saveKey);
  try {
    await updateItemMutation.mutateAsync(payload);
  } catch {
    if (fileId.value) {
      updatePbcItemInCache(queryClient, fileId.value, previousItem);
    }
    $q.notify({ type: 'negative', message: 'Failed to update item' });
  } finally {
    inlineSaveInFlight.delete(saveKey);
  }
}

async function unlockOfferPrice(row: { id: number }) {
  if (draftValues[row.id]) {
    delete draftValues[row.id]['offer_price'];
  }
  try {
    await updateItemMutation.mutateAsync({
      id: row.id,
      is_offer_price_manual: false,
      offer_price: null,
    });
    $q.notify({
      type: 'positive',
      message: 'Offer price reset to auto-calculated rate',
    });
  } catch {
    $q.notify({
      type: 'negative',
      message: 'Failed to reset offer price',
    });
  }
}

// Selection handlers
const isAllRowsSelected = computed(() => {
  return tableRows.value.length > 0 && selectedRowIds.value.length === tableRows.value.length;
});

function toggleSelectAllRows(checked: boolean) {
  if (checked) {
    selectedRowIds.value = tableRows.value.map((r) => r.id);
  } else {
    selectedRowIds.value = [];
  }
}

function toggleRowSelection(id: number, checked: boolean) {
  if (checked) {
    if (!selectedRowIds.value.includes(id)) selectedRowIds.value.push(id);
  } else {
    selectedRowIds.value = selectedRowIds.value.filter((x) => x !== id);
  }
}

function onSlPositionChange(currentIndex: number, event: Event) {
  const target = event.target as HTMLInputElement | null;
  const raw = target?.value ?? '';
  void moveItemToPosition(currentIndex, raw);
}

async function moveItemToPosition(currentIndex: number, newPosition: string | number | null) {
  if (!fileId.value) return;

  const parsed = Number(newPosition);
  const total = totalItemsCount.value || tableRows.value.length;
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > total) {
    $q.notify({
      type: 'warning',
      message: `Position must be between 1 and ${total}.`,
    });
    return;
  }

  const currentItem = costingItems.value[currentIndex];
  if (!currentItem) return;

  if (parsed - 1 === currentIndex) return;

  const ordered = [...costingItems.value];
  const [removed] = ordered.splice(currentIndex, 1);
  if (!removed) return;
  ordered.splice(parsed - 1, 0, removed);
  const orderedIds = ordered.map((item) => item.id);

  try {
    await productBasedCostingRepository.reorderProductBasedCostingItemToPosition(
      fileId.value,
      currentItem.id,
      parsed,
    );
    reorderPbcItemsInCache(queryClient, fileId.value, orderedIds);
    await queryClient.resetQueries({
      queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
    });
    $q.notify({
      type: 'positive',
      message: 'Items reordered successfully.',
      icon: 'ph ph-check-circle',
    });
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: err instanceof Error ? err.message : 'Failed to reorder items.',
    });
  }
}

function editSingleSelectedItem() {
  const id = selectedRowIds.value[0];
  const item = costingItems.value.find((i) => i.id === id);
  if (item) onEdit(item);
}

async function deleteSingleSelectedItem() {
  const id = selectedRowIds.value[0];
  const item = costingItems.value.find((i) => i.id === id);
  if (item) await onDelete(item);
  selectedRowIds.value = [];
}

function bulkDeleteSelectedItems() {
  if (!selectedRowIds.value.length || !fileId.value) return;
  const count = selectedRowIds.value.length;
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete ${count} selected line items?`,
    cancel: true,
    persistent: true,
    ok: { label: 'Delete', color: 'negative', unelevated: true },
  }).onOk(() => {
    void (async () => {
      await deleteItemsBulkMutation.mutateAsync({
        fileId: fileId.value,
        ids: selectedRowIds.value,
      });
      selectedRowIds.value = [];
      refreshBacklog();
    })();
  });
}

// Backlog & Catalog handling
const availableBacklogItems = computed(() => {
  return (backlog.items.value ?? []).filter((item) => !isBacklogItemOnCurrentFile(item));
});

const alreadyOnFileBacklogItems = computed(() => {
  return (backlog.items.value ?? []).filter((item) => isBacklogItemOnCurrentFile(item));
});

function isBacklogItemOnCurrentFile(item: BacklogItem) {
  return costingItems.value.some((row) => {
    if (item.product_id && row.product_id === item.product_id) return true;
    const itemCode = item.product_code?.trim();
    const rowCode = row.product_code?.trim();
    if (itemCode && rowCode) return itemCode === rowCode;
    return false;
  });
}

function refreshBacklog() {
  const tenantId = tenantStore.selectedTenant?.id;
  const profileId = file.value?.profile_id;
  if (tenantId && profileId) {
    void backlog.fetchBacklogItems(tenantId, profileId);
  }
}

function openBacklogDrawer() {
  refreshBacklog();
  showBacklogDrawer.value = true;
}

async function handleConsumeBacklog(backlogIds: number[]) {
  if (!fileId.value) return;
  const addedIds = await backlog.consumeBacklogItems(fileId.value, backlogIds);
  if (addedIds.length > 0) {
    void queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
    });
    refreshBacklog();
    showBacklogDrawer.value = false;
  }
}

function refreshAfterCatalogChange() {
  if (!fileId.value) return;
  void queryClient.invalidateQueries({
    queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
  });
  refreshBacklog();
}

function openCatalogDialog() {
  if (!fileId.value) return;
  catalogDrawerOpen.value = true;
}

function openAddProductCartPage() {
  if (!fileId.value) return;
  addProductCartDrawerOpen.value = true;
}

function openAddProductCartDrawer() {
  catalogDrawerOpen.value = false;
  addProductCartDrawerOpen.value = true;
}

function onCatalogCreateNewProduct(name: string) {
  selectedItem.value = { name } as ProductBasedCostingItem;
  showItemDialog.value = true;
}

const emptyBulkPasteRow = (index: number): BulkPasteGridRow => ({
  rowKey: `empty-${index}`,
  barcode: '',
  product_code: '',
  value: '',
});

const looksLikePasteHeader = (cols: string[]): boolean => {
  const joined = cols.join(' ').toLowerCase();
  return (
    joined.includes('barcode') ||
    joined.includes('product code') ||
    joined.includes('product_code') ||
    joined.includes('actualweight') ||
    joined.includes('actual weight')
  );
};

function openBulkPasteDialog(field: PbcBulkPasteField) {
  if (!costingItems.value.length) {
    $q.notify({ type: 'warning', message: t('product_based_costing.no_items_to_update') });
    return;
  }
  bulkPasteField.value = field;
  bulkPasteSaving.value = false;
  bulkPasteRows.value = Array.from({ length: 16 }, (_, i) => emptyBulkPasteRow(i));
  bulkPasteFocus.value = { row: 0, col: 0 };
  showBulkPasteDialog.value = true;
  void nextTick(() => {
    const el = document.querySelector(
      '.bulk-paste-cell[data-row="0"][data-col="0"]',
    ) as HTMLInputElement | null;
    el?.focus();
  });
}

const onBulkPasteCellFocus = (row: number, col: number) => {
  bulkPasteFocus.value = { row, col };
};

const onBulkPasteGridPaste = (event: ClipboardEvent) => {
  const text = event.clipboardData?.getData('text/plain');
  if (!text) return;
  event.preventDefault();

  let pasted = text
    .split(/\r?\n/)
    .map((line) => line.split('\t').map((cell) => cell.trim()))
    .filter((cols) => cols.some((cell) => cell !== ''));
  if (pasted.length === 0) return;
  if (pasted[0] && looksLikePasteHeader(pasted[0])) {
    pasted = pasted.slice(1);
  }
  if (pasted.length === 0) return;

  const startRow = bulkPasteFocus.value.row;
  const startCol = bulkPasteFocus.value.col;
  const rows = [...bulkPasteRows.value];

  pasted.forEach((cols, rOffset) => {
    const rowIdx = startRow + rOffset;
    while (rowIdx >= rows.length) {
      rows.push(emptyBulkPasteRow(rows.length));
    }
    const row = rows[rowIdx];
    if (!row) return;
    cols.forEach((cell, cOffset) => {
      const colIdx = startCol + cOffset;
      const key = bulkPasteCols[colIdx];
      if (!key) return;
      row[key] = cell;
    });
  });

  bulkPasteRows.value = rows;
};

async function applyBulkPaste() {
  if (!fileId.value) return;

  const field = bulkPasteField.value;
  const updates: ProductBasedCostingItemUpdateInput[] = [];
  let count = 0;
  let skipped = 0;
  const usedIds = new Set<number>();

  const normalizeKey = (value: string | null | undefined) =>
    (value || '').trim().replace(/^['`]+/, '').replace(/\s+/g, '').toLowerCase();

  const normalizePasteNumber = (raw: string): number | null => {
    if (!raw.trim()) return null;
    const val = Number(raw.replace(/[^0-9.-]/g, ''));
    if (Number.isNaN(val)) return null;
    if (field === 'price_gbp') return Number(val.toFixed(2));
    if (field === 'quantity') return Math.max(1, Math.round(val));
    if (field === 'offer_price') return normalizeOfferPriceBdt(val);
    if (field === 'product_weight' || field === 'package_weight') return Number(val.toFixed(3));
    return val;
  };

  let itemsForMatch: ProductBasedCostingItem[] = costingItems.value;
  if (hasMoreItems.value) {
    itemsForMatch = await productBasedCostingRepository.listProductBasedCostingItems(fileId.value);
  }

  const itemCodes = (item: ProductBasedCostingItem) => ({
    barcode: normalizeKey(item.barcode),
    product_code: normalizeKey(item.product_code),
  });

  const findMatches = (rowBarcode: string, rowCode: string) =>
    itemsForMatch.filter((item) => {
      const codes = itemCodes(item);
      if (rowBarcode && rowCode) {
        return codes.barcode === rowBarcode && codes.product_code === rowCode;
      }
      if (rowBarcode) return codes.barcode === rowBarcode;
      if (rowCode) return codes.product_code === rowCode;
      return false;
    });

  const pushUpdate = (targetItem: ProductBasedCostingItem, normalized: number) => {
    if (usedIds.has(targetItem.id)) return false;
    usedIds.add(targetItem.id);
    if (field === 'offer_price') {
      updates.push({
        id: targetItem.id,
        offer_price: normalized,
        is_offer_price_manual: true,
      });
    } else {
      updates.push({
        id: targetItem.id,
        [field]: normalized,
      });
    }
    count++;
    return true;
  };

  const dataRows = bulkPasteRows.value.filter((row) => normalizePasteNumber(row.value) !== null);
  const pasteHasKeys = dataRows.some(
    (row) => normalizeKey(row.barcode) || normalizeKey(row.product_code),
  );

  if (pasteHasKeys) {
    for (const row of dataRows) {
      const normalized = normalizePasteNumber(row.value);
      if (normalized === null) continue;
      const barcode = normalizeKey(row.barcode);
      const productCode = normalizeKey(row.product_code);
      if (!barcode && !productCode) {
        skipped++;
        continue;
      }
      const hits = findMatches(barcode, productCode).filter((item) => !usedIds.has(item.id));
      if (hits.length !== 1) {
        skipped++;
        continue;
      }
      pushUpdate(hits[0]!, normalized);
    }
  } else {
    const positionalItems = costingItems.value;
    dataRows.forEach((row, i) => {
      const normalized = normalizePasteNumber(row.value);
      const targetItem = positionalItems[i];
      if (!targetItem || normalized === null) {
        skipped++;
        return;
      }
      if (!pushUpdate(targetItem, normalized)) skipped++;
    });
  }

  if (updates.length === 0) {
    $q.notify({
      type: 'warning',
      message: skipped > 0 ? `No rows updated (${skipped} unmatched)` : 'No valid numeric values found.',
    });
    return;
  }

  bulkPasteSaving.value = true;
  try {
    const result = await productBasedCostingService.updateProductBasedCostingItemsBulk(updates);
    if (!result.success) {
      $q.notify({
        type: 'negative',
        message: result.error ?? t('product_based_costing.bulk_update_failed'),
      });
      return;
    }

    if (result.data?.length) {
      await queryClient.resetQueries({
        queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
      });
    }

    $q.notify({
      type: 'positive',
      message: `Successfully pasted and saved ${count} ${bulkPasteFieldLabel.value} value(s)${
        skipped ? ` (${skipped} unmatched)` : ''
      }`,
      icon: 'ph ph-check-circle',
    });
    showBulkPasteDialog.value = false;
  } catch {
    $q.notify({
      type: 'negative',
      message: t('product_based_costing.bulk_update_failed'),
    });
  } finally {
    bulkPasteSaving.value = false;
  }
}

async function handleDownloadExcel() {
  if (!fileId.value) return;
  const items = await productBasedCostingRepository.listProductBasedCostingItems(fileId.value);
  void downloadExcel($q, file.value ?? null, items);
}

function openPreviewAndPrint() {
  if (!fileId.value) return;
  const previewRoute = router.resolve({
    name: 'product-based-costing-file-preview-page',
    params: { id: fileId.value },
    query: {
      view: 'screenshot',
      cols: DEFAULT_PBC_PREVIEW_SCREENSHOT_COLUMNS.join(','),
    },
  });
  window.open(previewRoute.href, '_blank', 'noopener');
}

// Status & Workflow Actions
const status = computed(() => normalizePbcFileStatus(file.value?.status || 'pending'));

const incompleteOfferItemCount = computed(
  () =>
    costingItems.value.filter((item) => {
      const price = Number(item.price_gbp ?? 0);
      const weight = Number(item.product_weight ?? 0);
      return !(price > 0) || !(weight > 0);
    }).length,
);

const pbcPrimaryDisabled = computed(() => {
  const action = getStaffPbcPrimaryAction(status.value);
  if (!action) return true;
  if (!costingItems.value.length) return true;
  if (action === 'send_offer') {
    return incompleteOfferItemCount.value > 0 || cargoRateValue.value <= 0;
  }
  return false;
});

const pbcPrimaryDisabledReason = computed(() => {
  const action = getStaffPbcPrimaryAction(status.value);
  if (!costingItems.value.length) {
    return t('product_based_costing.primary_disabled_no_items');
  }
  if (action === 'send_offer' && pbcPrimaryDisabled.value) {
    if (cargoRateValue.value <= 0) return t('product_based_costing.cargo_rate_zero');
    return t('product_based_costing.primary_disabled_incomplete');
  }
  return '';
});

watch(
  file,
  (newFile) => {
    if (!newFile) return;
    const fileStatus = normalizePbcFileStatus(newFile.status || 'pending');
    const saved = visibleColumns.value;
    const isLegacyAll =
      saved.length === allColumnNames.length &&
      allColumnNames.every((col) => saved.includes(col));
    if (isLegacyAll) {
      visibleColumns.value = getDefaultVisibleColumnsForStatus(fileStatus);
    } else if (fileStatus === 'confirmed') {
      const mustHave = ['confirmedQty', 'offerPriceBdt', 'priceGbp', 'profitRate', 'costBdt', 'status'];
      const missing = mustHave.filter((col) => !saved.includes(col));
      if (missing.length) {
        visibleColumns.value = [...saved, ...missing];
      }
    } else if (fileStatus === 'procuring') {
      const mustHave = ['confirmedQty', 'status'];
      const missing = mustHave.filter((col) => !saved.includes(col));
      if (missing.length) {
        visibleColumns.value = [...saved, ...missing];
      }
    }
  },
  { immediate: true },
);

function getItemStatusBadge(st: string) {
  const s = (st || '').toLowerCase();
  if (s === 'accepted') return { color: 'green-1', textColor: 'green-9' };
  if (s === 'rejected' || s === 'unavailable') return { color: 'red-1', textColor: 'red-9' };
  if (s === 'partial') return { color: 'amber-1', textColor: 'amber-9' };
  return { color: 'grey-2', textColor: 'grey-8' };
}

// Inline Name Edit
function startInlineNameEdit() {
  editingNameValue.value = file.value?.name ?? '';
  isEditingName.value = true;
}

function cancelInlineName() {
  isEditingName.value = false;
  editingNameValue.value = '';
}

async function saveInlineName() {
  if (!isEditingName.value || savingName.value || !fileId.value) return;
  const trimmed = editingNameValue.value.trim();
  const currentName = file.value?.name ?? '';
  if (!trimmed || trimmed === currentName) {
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

// Rates Save
async function handleSaveRates() {
  if (!fileId.value) return;
  savingRates.value = true;
  try {
    await updateFileMutation.mutateAsync({
      id: fileId.value,
      conversion_rate: localRates.conversion_rate || 0,
      cargo_rate_kg_gbp: localRates.cargo_rate_kg_gbp || 0,
      profit_rate: localRates.profit_rate || 0,
      vat_rate: localRates.vat_rate || 0,
      offer_pricing_mode: localRates.offer_pricing_mode,
      buy_currency_id: localRates.buy_currency_id ?? undefined,
      sell_currency_id: localRates.sell_currency_id ?? undefined,
    });
    await recalculateOfferPricesMutation.mutateAsync(fileId.value);
    if (file.value) {
      syncLocalRatesFromFile(file.value);
    }
    ratesExpanded.value = false;
    $q.notify({ type: 'positive', message: 'Rates updated and prices recalculated' });
  } finally {
    savingRates.value = false;
  }
}

// Modal Handlers
const editFormData = computed(() => {
  if (!file.value) return null;
  return {
    id: file.value.id,
    name: file.value.name ?? '',
    order_for: file.value.order_for ?? '',
    customer_group_id: file.value.customer_group_id ?? null,
    note: file.value.note ?? '',
    vendor_code: file.value.vendor_code ?? null,
    market_code: file.value.market_code ?? null,
    buy_currency_id: file.value.buy_currency_id ?? null,
    sell_currency_id: file.value.sell_currency_id ?? null,
  };
});

async function handleUpdateFileDialog(payload: {
  id: number | null;
  name: string;
  order_for: string;
  customer_group_id: number | null;
  note: string;
  vendor_code: string | null;
  market_code: string | null;
  buy_currency_id: number | null;
  sell_currency_id: number | null;
}) {
  if (!payload.id) return;
  await updateFileMutation.mutateAsync({
    id: payload.id,
    name: payload.name,
    order_for: payload.order_for,
    customer_group_id: payload.customer_group_id,
    note: payload.note,
    vendor_code: payload.vendor_code,
    market_code: payload.market_code,
    buy_currency_id: payload.buy_currency_id ?? undefined,
    sell_currency_id: payload.sell_currency_id ?? undefined,
  });
  showFileDialog.value = false;
  refreshBacklog();
}

async function handleUpdateFileDirect(payload: Record<string, any>) {
  if (!fileId.value) return;
  await updateFileMutation.mutateAsync({
    id: fileId.value,
    ...payload,
  });
  $q.notify({ type: 'positive', message: 'File details updated' });
}

async function handleUpdateRatesDirect(payload: {
  conversion_rate: number;
  cargo_rate_kg_gbp: number;
  profit_rate: number;
  vat_rate: number;
  offer_pricing_mode: string;
  buy_currency_id: number;
  sell_currency_id: number;
}) {
  if (!fileId.value) return;
  await updateFileMutation.mutateAsync({
    id: fileId.value,
    conversion_rate: payload.conversion_rate,
    cargo_rate_kg_gbp: payload.cargo_rate_kg_gbp,
    profit_rate: payload.profit_rate,
    vat_rate: payload.vat_rate,
    offer_pricing_mode: payload.offer_pricing_mode as
      | 'landed_cost_plus'
      | 'gbp_vat_then_profit'
      | undefined,
    buy_currency_id: payload.buy_currency_id,
    sell_currency_id: payload.sell_currency_id,
  });
  await recalculateOfferPricesMutation.mutateAsync(fileId.value);
  $q.notify({ type: 'positive', message: 'Rates updated and prices recalculated' });
}

async function onStatusChange(nextStatus: string) {
  if (!fileId.value) return;

  await updateFileMutation.mutateAsync({
    id: fileId.value,
    status: nextStatus,
  });

  visibleColumns.value = getDefaultVisibleColumnsForStatus(nextStatus);

  if (nextStatus === 'confirmed') {
    const allItems = await productBasedCostingRepository.listProductBasedCostingItems(fileId.value);
    const prefill = allItems
      .filter((item) => item.confirmed_quantity == null)
      .map((item) => ({
        id: item.id,
        confirmed_quantity: Math.round(Number(item.quantity ?? 0)),
      }));
    if (prefill.length > 0) {
      await productBasedCostingRepository.updateProductBasedCostingItemsBulk(prefill);
    }
    await queryClient.resetQueries({
      queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
    });
  }

  if (nextStatus === 'offered') {
    await recalculateOfferPricesMutation.mutateAsync(fileId.value);
  }
}

async function applyStatus(nextStatus: string) {
  if (status.value === nextStatus || updatingStatus.value) return;
  updatingStatus.value = true;
  targetUpdatingStatus.value = nextStatus;
  try {
    await onStatusChange(nextStatus);
    if (nextStatus === 'offered' && costingItems.value.length > 0) {
      $q.dialog({
        title: t('product_based_costing.status_offered'),
        message: t('product_based_costing.offered_dialog_message'),
        cancel: { label: t('product_based_costing.not_now'), flat: true },
        ok: { label: t('product_based_costing.open_offer'), unelevated: true, color: 'primary' },
      }).onOk(() => {
        openPreviewAndPrint();
      });
    }
  } finally {
    updatingStatus.value = false;
    targetUpdatingStatus.value = null;
  }
}

async function markReadyForShipment() {
  if (!fileId.value || updatingStatus.value) return;
  updatingStatus.value = true;
  targetUpdatingStatus.value = 'packed';
  try {
    await productBasedCostingRepository.markPbcReadyForShipment(fileId.value);
    visibleColumns.value = getDefaultVisibleColumnsForStatus('packed');
    await queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.fileDetail(fileId.value),
    });
    $q.notify({
      type: 'positive',
      message: t('product_based_costing.action_mark_packed'),
    });
  } catch (error) {
    $q.notify({
      type: 'negative',
      message: (error as Error).message || 'Failed to mark ready for shipment',
    });
  } finally {
    updatingStatus.value = false;
    targetUpdatingStatus.value = null;
  }
}

function handlePbcPrimaryAction(action: StaffPbcPrimaryAction) {
  const nextStatus = getStaffPbcPrimaryActionTargetStatus(action);
  if (action === 'confirm_order') {
    if (status.value === nextStatus || updatingStatus.value) return;
    $q.dialog({
      title: t('product_based_costing.confirm_order_title'),
      message: t('product_based_costing.confirm_order_message'),
      cancel: { label: t('product_based_costing.cancel'), flat: true },
      ok: { label: t('product_based_costing.confirm_order'), unelevated: true, color: 'primary' },
    }).onOk(() => {
      void applyStatus(nextStatus);
    });
    return;
  }
  if (action === 'mark_packed') {
    void markReadyForShipment();
    return;
  }
  void applyStatus(nextStatus);
}

function onWorkflowStatusClick(nextStatus: string) {
  const normalized = normalizePbcFileStatus(nextStatus);
  if (status.value === normalized || updatingStatus.value) return;

  if (status.value === 'cancelled' && normalized !== 'cancelled') {
    showStatusOverrideDialog.value = true;
    return;
  }

  if (normalized === 'cancelled') {
    onCancelFile();
    return;
  }

  const primaryAction = getStaffPbcPrimaryAction(status.value);
  const primaryTarget = primaryAction
    ? normalizePbcFileStatus(getStaffPbcPrimaryActionTargetStatus(primaryAction))
    : null;

  if (primaryAction && primaryTarget === normalized) {
    handlePbcPrimaryAction(primaryAction);
    return;
  }

  $q.dialog({
    title: 'Confirm status change',
    message: `Change this costing file to "${formatStatusLabel(normalized)}"?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    if (normalized === 'packed' && status.value === 'procuring') {
      void markReadyForShipment();
    } else {
      void applyStatus(normalized);
    }
  });
}

function onCancelFile() {
  if (updatingStatus.value) return;
  $q.dialog({
    title: t('product_based_costing.cancel_file_title'),
    message: t('product_based_costing.cancel_file_message'),
    cancel: { label: t('product_based_costing.not_now'), flat: true },
    ok: {
      label: t('product_based_costing.cancel_file'),
      color: 'negative',
      unelevated: true,
    },
  }).onOk(() => {
    void applyStatus('cancelled');
  });
}

async function onStatusOverride(payload: { status: string; reason: string }) {
  if (updatingStatus.value || status.value === payload.status) return;
  updatingStatus.value = true;
  targetUpdatingStatus.value = payload.status;
  try {
    await onStatusChange(payload.status);
    showStatusOverrideDialog.value = false;
    $q.notify({
      type: 'info',
      message: t('product_based_costing.override_applied', {
        status: t(`product_based_costing.status_${normalizePbcFileStatus(payload.status)}`),
        reason: payload.reason,
      }),
    });
  } finally {
    updatingStatus.value = false;
    targetUpdatingStatus.value = null;
  }
}

function onSettingsDrawerAction(action: PbcSettingsDrawerAction) {
  switch (action) {
    case 'edit-file':
      showFileDialog.value = true;
      break;
    case 'download-excel':
      handleDownloadExcel();
      break;
    case 'offer-pdf':
      openPreviewAndPrint();
      break;
  }
}

function openSettingsDrawer(tab?: string) {
  settingsDrawerInitialTab.value = tab;
  showSettingsDrawer.value = true;
}

function onEdit(item: ProductBasedCostingItem) {
  selectedItem.value = item;
  showItemDialog.value = true;
}

async function onDelete(item: ProductBasedCostingItem) {
  await deleteItemMutation.mutateAsync(item.id);
  refreshBacklog();
}

function handleCreated() {
  if (!fileId.value) return;
  void queryClient.invalidateQueries({
    queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
  });
  refreshBacklog();
}

function handleUpdated() {
  if (!fileId.value) return;
  void queryClient.invalidateQueries({
    queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
  });
  refreshBacklog();
}

const tableScrollContainerRef = ref<HTMLElement | null>(null);
const scrollTrackRef = ref<HTMLElement | null>(null);
const scrollThumbWidth = ref(30);
const scrollThumbLeft = ref(0);

const updateScrollbarFromTable = () => {
  const el = tableScrollContainerRef.value;
  if (!el) return;
  const maxScrollLeft = el.scrollWidth - el.clientWidth;
  if (maxScrollLeft <= 0) {
    scrollThumbWidth.value = 100;
    scrollThumbLeft.value = 0;
    return;
  }
  const ratio = el.clientWidth / el.scrollWidth;
  const thumbWidthPct = Math.max(15, Math.min(80, ratio * 100));
  scrollThumbWidth.value = thumbWidthPct;
  const scrollFraction = el.scrollLeft / maxScrollLeft;
  const availableTrackPct = 100 - thumbWidthPct;
  scrollThumbLeft.value = scrollFraction * availableTrackPct;
};

const onTableScroll = () => {
  updateScrollbarFromTable();
  maybeLoadMoreItems();
};

const maybeLoadMoreItems = () => {
  const el = tableScrollContainerRef.value;
  if (!el || isFetchingMoreItems.value || !hasMoreItems.value) return;

  const threshold = 120;
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - threshold) {
    void fetchNextPage();
  }
};

const scrollTableByStep = (delta: number) => {
  if (tableScrollContainerRef.value) {
    tableScrollContainerRef.value.scrollBy({ left: delta, behavior: 'smooth' });
  }
};

const onTrackClick = (e: MouseEvent) => {
  const table = tableScrollContainerRef.value;
  const track = scrollTrackRef.value;
  if (!track || !table) return;
  const rect = track.getBoundingClientRect();
  const clickX = e.clientX - rect.left;
  const fraction = Math.max(0, Math.min(1, clickX / rect.width));
  const maxScrollLeft = table.scrollWidth - table.clientWidth;
  table.scrollTo({ left: fraction * maxScrollLeft, behavior: 'smooth' });
};

const startThumbDrag = (e: MouseEvent) => {
  e.preventDefault();
  e.stopPropagation();
  const table = tableScrollContainerRef.value;
  const track = scrollTrackRef.value;
  if (!track || !table) return;

  const startX = e.clientX;
  const startScrollLeft = table.scrollLeft;
  const trackRect = track.getBoundingClientRect();
  const availableTrackWidth = trackRect.width * (1 - scrollThumbWidth.value / 100);
  const maxScrollLeft = table.scrollWidth - table.clientWidth;

  const onMouseMove = (moveEvent: MouseEvent) => {
    if (availableTrackWidth <= 0) return;
    const deltaX = moveEvent.clientX - startX;
    const deltaScroll = (deltaX / availableTrackWidth) * maxScrollLeft;
    table.scrollLeft = Math.max(0, Math.min(maxScrollLeft, startScrollLeft + deltaScroll));
  };

  const onMouseUp = () => {
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mouseup', onMouseUp);
  };

  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
};

import { onMounted, onUnmounted } from 'vue';

onMounted(() => {
  updateScrollbarFromTable();
  window.addEventListener('resize', updateScrollbarFromTable);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateScrollbarFromTable);
});

function goBackToList() {
  const tenantSlug = tenantStore.selectedTenant?.slug ?? route.params.tenantSlug;
  void router.push({
    name: 'product-based-costing-page',
    params: tenantSlug ? { tenantSlug } : {},
  });
}
</script>

<style scoped>
.pbc-file-details-v2-page {
  height: calc(100vh - var(--workspace-header-offset, 44px));
  overflow: hidden;
}

.pbc-v2-top-section {
  padding: 4px 10px 5px;
  gap: 2px;
}

.pbc-v2-top-section__sub {
  padding-left: 36px;
  min-height: 24px;
  row-gap: 4px;
}

.pbc-v2-header-workflow {
  min-width: 0;
  margin-top: 4px;
}

.pbc-v2-header-settings-btn :deep(.q-icon) {
  font-size: 17px;
}

.pbc-v2-top-section__code {
  font-size: 11px;
  line-height: 1.2;
}

.pbc-v2-top-section__title {
  font-size: 13px;
  line-height: 1.25;
}

.pbc-v2-top-section :deep(.name-inline-input .q-field__control) {
  min-height: 26px;
  height: 26px;
}

.pbc-v2-top-section :deep(.name-inline-input .q-field__native) {
  font-size: 13px;
  line-height: 1.25;
  padding-top: 0;
  padding-bottom: 0;
}

.pbc-v2-top-section :deep(.q-btn.q-btn--round) {
  width: 28px;
  height: 28px;
  min-width: 28px;
  min-height: 28px;
  font-size: 16px;
}

.pbc-v2-top-section :deep(.rounded-sq-btn.q-btn--dense) {
  min-height: 26px;
  font-size: 12px;
}

.border-bottom {
  border-bottom: 1px solid var(--tf-neutral-border);
}

.border-top {
  border-top: 1px solid var(--tf-neutral-border);
}

.border-grey {
  border: 1px solid var(--tf-neutral-border);
}

.rounded-sq-btn {
  border-radius: 8px !important;
}

.pbc-items-view-toggle {
  height: 24px;
  overflow: hidden;
}

.pbc-items-view-toggle :deep(.q-btn) {
  min-height: 24px;
  height: 24px;
  padding: 0 6px;
  font-size: 13px;
}

.pbc-v2-markup-table {
  border-collapse: collapse;
}

.pbc-v2-markup-table th.pbc-select-col,
.pbc-v2-markup-table td.pbc-select-col {
  width: 32px;
  min-width: 32px;
  max-width: 32px;
  padding: 2px !important;
  box-sizing: border-box;
}

.pbc-v2-markup-table th.pbc-sl-col,
.pbc-v2-markup-table td.pbc-sl-col {
  width: 36px;
  min-width: 36px;
  max-width: 36px;
  padding: 2px !important;
  box-sizing: border-box;
}

.pbc-v2-markup-table th.pbc-select-col :deep(.q-checkbox),
.pbc-v2-markup-table td.pbc-select-col :deep(.q-checkbox) {
  margin: 0 auto;
}

.sticky-col {
  position: sticky;
  left: 0;
  z-index: 4;
  background-color: var(--tf-neutral-surface) !important;
  border-right: 1px solid var(--tf-neutral-border);
}

.pbc-v2-markup-table thead tr th.sticky-col {
  z-index: 7;
  background-color: var(--tf-disabled-bg) !important;
}

.sticky-col-2 {
  position: sticky;
  left: 32px;
  z-index: 4;
  background-color: var(--tf-neutral-surface) !important;
  border-right: 1px solid var(--tf-neutral-border);
}

.pbc-v2-markup-table thead tr th.sticky-col-2 {
  z-index: 6;
  background-color: var(--tf-disabled-bg) !important;
}

.pbc-row-selected td.sticky-col,
.pbc-row-selected td.sticky-col-2 {
  background-color: var(--tf-info-soft) !important;
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
}

.pbc-image-cell {
  padding: 2px !important;
  vertical-align: middle;
}

/* Soft Column Tints (Color Code Standard from OPS_SPREADSHEET_TABLE_PATTERN.md) */
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

.pbc-row-selected {
  background-color: var(--tf-info-soft) !important;
}

.pbc-row-selected td {
  background-color: var(--tf-info-soft) !important;
}

.pbc-row-img {
  width: 0.85in;
  height: 0.85in;
  display: block;
  margin: 0 auto;
  border-radius: 6px;
  border: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-surface);
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
  border: 1px dashed var(--tf-neutral-border);
  background-color: var(--tf-disabled-bg);
  overflow: hidden;
}

.pbc-row-img-placeholder :deep(.smart-image__fallback) {
  font-size: 10px;
  text-align: center;
  padding: 4px;
}

/* Compact 28px cell height */
:deep(.inline-edit-input .q-field__control) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 4px !important;
}

:deep(.inline-edit-input .q-field__native) {
  padding: 0;
  font-size: 12px;
}

/* Hide default browser numeric spin arrows */
:deep(.inline-edit-input input[type='number']::-webkit-outer-spin-button),
:deep(.inline-edit-input input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

.sl-reorder-cell {
  background-color: color-mix(in srgb, var(--tf-neutral-surface) 96%, var(--tf-neutral-ink) 4%);
}

.bulk-paste-overlay {
  min-height: 0;
  background: var(--tf-neutral-surface);
}

.bulk-paste-overlay__footer {
  border-top: 1px solid var(--tf-neutral-border);
  background: color-mix(in srgb, var(--tf-neutral-surface) 96%, var(--tf-neutral-ink) 4%);
}

.bulk-paste-overlay__body .bulk-paste-grid-wrap {
  max-height: none;
  min-height: 12rem;
}

.bulk-paste-grid-wrap {
  overflow: auto;
  max-height: 360px;
  border: 1px solid var(--tf-neutral-border);
  border-radius: 8px;
}

.bulk-paste-grid {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

.bulk-paste-grid th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: var(--tf-disabled-bg);
  color: var(--tf-neutral-muted);
  font-weight: 700;
  text-align: left;
  padding: 6px 8px;
  border-bottom: 1px solid var(--tf-neutral-border);
  border-right: 1px solid var(--tf-neutral-border);
}

.bulk-paste-grid td {
  border-bottom: 1px solid var(--tf-neutral-border);
  border-right: 1px solid var(--tf-neutral-border);
  padding: 0;
}

.bulk-paste-grid td:last-child {
  border-right: none;
}

.bulk-paste-cell {
  width: 100%;
  height: 28px;
  border: none;
  outline: none;
  padding: 0 8px;
  font-size: 12px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  background: var(--tf-neutral-surface);
  color: var(--tf-neutral-ink);
}

.bulk-paste-cell:focus {
  box-shadow: inset 0 0 0 2px var(--q-primary, var(--tf-ops-accent-qty));
}

.bulk-paste-cell--value {
  font-weight: 700;
}

.bulk-paste-header-btn {
  opacity: 0.6;
  transition: opacity 0.15s ease-in-out, transform 0.15s ease-in-out;
  padding: 0 !important;
  min-height: 18px !important;
  min-width: 18px !important;
}

.bulk-paste-header-btn:hover {
  opacity: 1 !important;
  color: var(--q-primary) !important;
  transform: scale(1.1);
}

:deep(.inline-edit-input input[type='number']) {
  -moz-appearance: textfield;
  appearance: textfield;
}

/* Borderless transparent idle state: inherits cell background tint */
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

:deep(.excel-cell-input:hover .q-field__control) {
  background-color: rgba(255, 255, 255, 0.4) !important;
}

/* Crisp Excel focus — theme primary (native focus ring disabled in app.scss) */
:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: var(--tf-theme-surface, var(--tf-neutral-surface)) !important;
  border: 1.5px solid var(--tf-theme-primary, var(--q-primary)) !important;
  box-shadow: none !important;
}

.rates-pill {
  border: 1px solid var(--tf-neutral-border);
  font-size: 11px;
  line-height: 1.2;
  padding-top: 2px;
  padding-bottom: 2px;
}

.pbc-cost-bdt-cell {
  border-bottom: 1px dashed color-mix(in srgb, var(--tf-neutral-muted) 55%, transparent);
}

.pbc-cost-bdt-tooltip__pre {
  margin: 0;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 11px;
  line-height: 1.45;
  white-space: pre;
  text-align: left;
}

.pbc-rates-editor {
  border-top: 1px solid var(--tf-neutral-border);
  margin-top: 6px;
  padding-top: 10px;
  padding-bottom: 4px;
}

.pbc-rates-editor__grid {
  display: grid;
  grid-template-columns: minmax(240px, 0.9fr) minmax(320px, 1.4fr) auto;
  gap: 10px 12px;
  align-items: stretch;
}

.pbc-rates-group {
  background: color-mix(in srgb, var(--tf-neutral-surface) 96%, var(--tf-neutral-ink) 4%);
  border: 1px solid var(--tf-neutral-border);
  border-radius: 8px;
  padding: 8px 10px 10px;
}

.pbc-rates-group__title {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted);
  margin-bottom: 6px;
}

.pbc-rates-mode-toggle {
  border: 1px solid var(--tf-neutral-border);
  border-radius: 8px;
  overflow: hidden;
}

.pbc-rates-mode-toggle :deep(.q-btn) {
  border-radius: 0;
  font-weight: 600;
  font-size: 12px;
}

.pbc-rates-editor__actions {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  gap: 6px;
  min-width: 96px;
}

@media (max-width: 1023px) {
  .pbc-rates-editor__grid {
    grid-template-columns: 1fr;
  }

  .pbc-rates-editor__actions {
    flex-direction: row;
    justify-content: flex-end;
  }
}

.name-inline-title:hover .edit-icon {
  color: var(--q-primary) !important;
}

.excel-scrollbar-wrapper {
  background-color: var(--tf-neutral-border);
  height: 22px;
  width: 220px;
  max-width: 260px;
  border-radius: 4px;
  border: 1px solid var(--tf-neutral-border-strong);
  padding: 0 2px;
}

.excel-scroll-arrow-btn {
  background: transparent;
  border: none;
  color: var(--tf-neutral-muted);
  width: 16px;
  height: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  padding: 0;
  border-radius: 2px;
}

.excel-scroll-arrow-btn:hover {
  background-color: var(--tf-neutral-border-strong);
  color: var(--tf-neutral-ink);
}

.excel-scroll-track {
  height: 12px;
  width: 160px;
  background-color: var(--tf-neutral-border-strong);
  border-radius: 3px;
  position: relative;
  margin: 0 4px;
}

.excel-scroll-thumb {
  height: 12px;
  background-color: var(--tf-neutral-muted);
  border-radius: 3px;
  position: absolute;
  top: 0;
  cursor: grab;
  transition: background-color 0.15s ease;
}

.excel-scroll-thumb:hover {
  background-color: var(--tf-neutral-muted);
}

.hide-native-scrollbar {
  scrollbar-width: thin;
}
</style>
