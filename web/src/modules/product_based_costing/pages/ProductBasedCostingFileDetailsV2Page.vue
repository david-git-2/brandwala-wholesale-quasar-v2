<template>
  <q-page class="pbc-file-details-v2-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Top Sticky Header Section: Compact Title, Status Badge, Rates Summary & Actions -->
    <div class="pbc-v2-top-section bg-white border-bottom q-px-md q-py-xs shrink-0 shadow-xs" style="min-height: 48px">
      <div class="row items-center justify-between no-wrap">
        <!-- Left: Back Button, Code, Name, Status Badge -->
        <div class="row items-center q-gutter-x-xs no-wrap ellipsis min-width-0 col-auto">
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-left"
            color="grey-8"
            size="sm"
            @click="goBackToList"
          >
            <q-tooltip>{{ $t('product_based_costing.go_back') }}</q-tooltip>
          </q-btn>

          <span class="text-subtitle2 text-weight-bolder text-grey-8 font-mono bg-grey-2 q-px-xs rounded-borders" style="font-size: 12px">
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
            class="text-subtitle1 text-weight-bolder text-grey-9 ellipsis cursor-pointer name-inline-title row items-center q-gutter-x-2xs no-wrap"
            style="font-size: 14px"
            :title="$t('product_based_costing.click_to_edit_name')"
            @click="startInlineNameEdit"
          >
            <span class="ellipsis">{{ file?.name || $t('product_based_costing.costing_file_default') }}</span>
            <q-icon name="ph ph-pencil-simple" size="12px" class="text-grey-6 edit-icon" />
          </div>

          <!-- Customer / Order For Chip -->
          <span v-if="file?.order_for" class="text-caption text-grey-6 ellipsis text-weight-medium">
            ({{ file.order_for }})
          </span>

          <!-- Status Badge -->
          <q-badge
            rounded
            class="text-weight-bold text-capitalize q-ml-xs text-caption q-px-xs q-py-2xs"
            :color="statusBadgeColor.color"
            :text-color="statusBadgeColor.textColor"
          >
            {{ formatStatusLabel(file?.status || 'pending') }}
          </q-badge>

        </div>

        <!-- Center / Rates Bar Quick Summary -->
        <div class="row items-center q-gutter-x-sm no-wrap q-mx-sm">
          <div class="rates-pill row items-center q-gutter-x-xs q-px-sm q-py-2xs bg-grey-2 rounded-borders text-caption text-grey-8 font-mono">
            <span><strong>FX:</strong> ৳{{ conversionRateValue }}</span>
            <span class="text-grey-4">|</span>
            <span><strong>Cargo:</strong> £{{ cargoRateValue }}/kg</span>
            <span class="text-grey-4">|</span>
            <span><strong>Profit:</strong> {{ profitRateValue }}%</span>
            <q-btn
              flat
              round
              dense
              size="xs"
              icon="ph ph-sliders-horizontal"
              color="primary"
              class="q-ml-2xs"
              @click="ratesExpanded = !ratesExpanded"
            >
              <q-tooltip>Edit rates (FX, Cargo, Profit)</q-tooltip>
            </q-btn>
          </div>
        </div>

        <!-- Right Header Action Controls -->
        <div class="row items-center q-gutter-x-xs no-wrap col-auto">
          <!-- Add Products Button -->
          <q-btn
            color="primary"
            unelevated
            dense
            no-caps
            size="sm"
            icon="ph ph-plus"
            :label="$t('product_based_costing.add_products')"
            class="q-px-sm rounded-sq-btn text-weight-bold"
            style="border-radius: 8px"
            @click="openCatalogDialog"
          />

          <!-- Backlog Auto-Suggest Button -->
          <q-btn
            v-if="availableBacklogItems.length"
            outline
            dense
            no-caps
            color="orange-9"
            size="sm"
            icon="ph ph-tray"
            :label="`Backlog (${availableBacklogItems.length})`"
            class="q-px-sm rounded-sq-btn text-weight-bold bg-orange-1"
            style="border-radius: 8px"
            @click="openBacklogDrawer"
          >
            <q-tooltip>Review open unfulfilled demand backlog for this customer</q-tooltip>
          </q-btn>

          <!-- Columns Menu -->
          <q-btn
            flat
            dense
            no-caps
            color="grey-8"
            class="rounded-sq-btn text-weight-bold q-px-sm border-grey"
            icon="ph ph-columns"
            :label="$t('product_based_costing.columns')"
            size="sm"
            style="border-radius: 8px"
          >
            <q-menu>
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
                    >
                      <template #prepend>
                        <q-icon name="ph ph-magnifying-glass" size="14px" />
                      </template>
                    </q-input>
                  </q-item-section>
                </q-item>
                <q-item clickable class="q-py-xs" @click="toggleSelectAllColumns">
                  <q-item-section>
                    <q-checkbox :model-value="allColumnsVisible" :label="$t('product_based_costing.select_deselect_all')" />
                  </q-item-section>
                </q-item>
                <q-separator class="q-my-xs" />
                <q-item
                  v-for="col in filteredColumnOptions"
                  :key="col.value"
                  clickable
                  class="q-py-2xs"
                  @click="toggleColumn(col.value)"
                >
                  <q-item-section>
                    <q-checkbox :model-value="visibleColumnMap[col.value]" :label="col.label" />
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>

          <!-- Settings Gear Button (Opens Side Drawer) -->
          <q-btn
            flat
            round
            dense
            color="grey-8"
            icon="ph ph-gear"
            size="sm"
            @click="openSettingsDrawer()"
          >
            <q-tooltip>File Settings & Summary</q-tooltip>
          </q-btn>

        </div>
      </div>

      <!-- Expandable Inline Rates Editor Bar -->
      <div v-if="ratesExpanded" class="q-pt-sm q-pb-xs border-top q-mt-xs">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-md-3">
            <q-input
              v-model.number="localRates.conversion_rate"
              dense
              outlined
              type="number"
              prefix="৳"
              label="FX Rate (GBP → BDT)"
              hide-bottom-space
            />
          </div>
          <div class="col-12 col-md-3">
            <q-input
              v-model.number="localRates.cargo_rate_kg_gbp"
              dense
              outlined
              type="number"
              prefix="£"
              suffix="/kg"
              label="Cargo Rate (GBP/kg)"
              hide-bottom-space
            />
          </div>
          <div class="col-12 col-md-3">
            <q-input
              v-model.number="localRates.profit_rate"
              dense
              outlined
              type="number"
              suffix="%"
              label="Markup / Profit %"
              hide-bottom-space
            />
          </div>
          <div class="col-12 col-md-3 row justify-end q-gutter-xs">
            <q-btn
              flat
              dense
              no-caps
              label="Cancel"
              class="rounded-sq-btn"
              style="border-radius: 8px"
              @click="ratesExpanded = false"
            />
            <q-btn
              unelevated
              dense
              no-caps
              color="primary"
              label="Save Rates"
              class="rounded-sq-btn q-px-sm"
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
      class="pbc-v2-middle-section col overflow-auto q-pa-none bg-white hide-native-scrollbar"
      style="overflow-x: auto !important; overflow-y: auto !important; flex: 1 1 0%; min-height: 0"
      @scroll="onTableScroll"
    >
      <table class="pbc-v2-markup-table bg-white" style="min-width: 1080px; width: 100%">
        <thead>
          <tr class="bg-grey-2 text-grey-9 text-weight-bold" style="font-size: 11px">
            <!-- Row Selection Header -->
            <th class="text-center q-pa-none sticky-col" style="width: 18px; min-width: 18px; max-width: 18px">
              <q-checkbox
                :model-value="isAllRowsSelected"
                dense
                size="xs"
                @update:model-value="toggleSelectAllRows"
              />
            </th>

            <!-- Serial # / Position -->
            <th v-if="visibleColumnMap.sl" class="text-center sticky-col-2 q-pa-none" style="width: 36px; min-width: 36px; max-width: 36px">
              SL
            </th>

            <!-- Image -->
            <th v-if="visibleColumnMap.image" class="text-center pbc-image-col" style="width: 0.85in; min-width: 0.85in">
              Image
            </th>

            <!-- Product Name -->
            <th v-if="visibleColumnMap.name" class="text-left" style="min-width: 120px; width: 120px; max-width: 120px; white-space: normal">
              Name
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
            <th v-if="visibleColumnMap.qty" class="text-center bw-ops-col-tint--qty" style="width: 56px; min-width: 56px">
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
            <th v-if="visibleColumnMap.confirmedQty" class="text-center bw-ops-col-tint--qty" style="width: 56px; min-width: 56px">
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
            <th v-if="visibleColumnMap.priceGbp" class="text-center bw-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <span>Price (£)</span>
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

            <!-- Total Purchase GBP -->
            <th v-if="visibleColumnMap.totalPurchasePriceGbp" class="text-center bw-ops-col-tint--price" style="width: 56px; min-width: 56px">
              Tot (£)
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
            <th v-if="visibleColumnMap.packageWeight" class="text-center bw-ops-col-tint--weight" style="width: 56px; min-width: 56px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
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
            <th v-if="visibleColumnMap.totalWeight" class="text-center bw-ops-col-tint--weight" style="width: 56px; min-width: 56px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
              <div>Total</div>
              <div>Weight</div>
            </th>

            <!-- Cargo Rate -->
            <th v-if="visibleColumnMap.cargoRate" class="text-center" style="width: 56px; min-width: 56px">
              Cargo Rate
            </th>

            <!-- Cargo Cost GBP -->
            <th v-if="visibleColumnMap.cargoCostGbp" class="text-center" style="width: 56px; min-width: 56px">
              Cargo (£)
            </th>

            <!-- Total Cost GBP/Unit -->
            <th v-if="visibleColumnMap.totalCostGbp" class="text-center bw-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              Cost (£)
            </th>

            <!-- Row Total Cost GBP -->
            <th v-if="visibleColumnMap.rowTotalCostGbp" class="text-center bw-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              Row (£)
            </th>

            <!-- Cost BDT -->
            <th v-if="visibleColumnMap.costBdt" class="text-center bw-ops-col-tint--cost" style="width: 60px; min-width: 60px">
              Cost (৳)
            </th>

            <!-- Row Total Cost BDT -->
            <th v-if="visibleColumnMap.totalCostBdt" class="text-center bw-ops-col-tint--cost" style="width: 60px; min-width: 60px">
              Row (৳)
            </th>

            <!-- Offer Price BDT -->
            <th v-if="visibleColumnMap.offerPriceBdt" class="text-center bw-ops-col-tint--price" style="width: 64px; min-width: 64px">
              Offer (৳)
            </th>

            <!-- Total Offer BDT -->
            <th v-if="visibleColumnMap.totalBdt" class="text-center bw-ops-col-tint--price" style="width: 64px; min-width: 64px">
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
              <q-spinner-dots color="primary" size="40px" />
              <div class="text-caption text-grey-6 q-mt-xs">Loading costing line items...</div>
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
              <td class="text-center q-pa-none sticky-col" style="width: 18px; min-width: 18px; max-width: 18px">
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
                class="text-center sticky-col-2 q-pa-none sl-reorder-cell"
                style="width: 36px; min-width: 36px; max-width: 36px"
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
                    @change="(val: string | number | null) => onSlPositionChange(idx, val)"
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
              <td v-if="visibleColumnMap.qty" class="text-center bw-ops-col-tint--qty" style="width: 56px; min-width: 56px">
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
              <td v-if="visibleColumnMap.confirmedQty" class="text-center bw-ops-col-tint--qty" style="width: 56px; min-width: 56px">
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
                  <div v-if="row.product_code" class="row items-center justify-between no-wrap">
                    <div class="ellipsis">
                      <span class="text-grey-6 text-uppercase" style="font-size: 8px">C: </span>
                      <b class="text-dark" style="font-size: 10px">{{ row.product_code }}</b>
                    </div>
                  </div>
                  <div v-if="row.barcode" class="row items-center justify-between no-wrap">
                    <div class="ellipsis">
                      <span class="text-grey-6 text-uppercase" style="font-size: 8px">B: </span>
                      <span class="text-grey-9" style="font-size: 10px">{{ row.barcode }}</span>
                    </div>
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
              <td v-if="visibleColumnMap.priceGbp" class="text-center bw-ops-col-tint--price" style="width: 56px; min-width: 56px">
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
                  T: £{{ formatMoney(row.totalPurchasePriceGbp) }}
                </div>
              </td>

              <!-- Total Purchase Price GBP -->
              <td v-if="visibleColumnMap.totalPurchasePriceGbp" class="text-center bw-ops-col-tint--price font-mono text-caption text-grey-9" style="width: 56px; min-width: 56px">
                £{{ formatMoney(row.totalPurchasePriceGbp) }}
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
              <td v-if="visibleColumnMap.packageWeight" class="text-center bw-ops-col-tint--weight font-mono text-grey-8" style="width: 56px; min-width: 56px">
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
              <td v-if="visibleColumnMap.totalWeight" class="text-center bw-ops-col-tint--weight font-mono text-caption text-grey-9" style="width: 56px; min-width: 56px">
                {{ row.totalWeight }}g
              </td>

              <!-- Cargo Rate -->
              <td v-if="visibleColumnMap.cargoRate" class="text-center font-mono text-caption text-grey-8" style="width: 56px; min-width: 56px">
                £{{ formatMoney(row.cargoRate) }}
              </td>

              <!-- Cargo Cost GBP -->
              <td v-if="visibleColumnMap.cargoCostGbp" class="text-center font-mono text-caption text-grey-8" style="width: 56px; min-width: 56px">
                £{{ formatMoney(row.cargoCostGbp) }}
              </td>

              <!-- Total Cost GBP -->
              <td v-if="visibleColumnMap.totalCostGbp" class="text-center bw-ops-col-tint--cost font-mono text-caption text-grey-9" style="width: 56px; min-width: 56px">
                £{{ formatMoney(row.totalCostGbp) }}
              </td>

              <!-- Row Total Cost GBP -->
              <td v-if="visibleColumnMap.rowTotalCostGbp" class="text-center bw-ops-col-tint--cost font-mono text-caption text-grey-9" style="width: 56px; min-width: 56px">
                £{{ formatMoney(row.rowTotalCostGbp) }}
              </td>

              <!-- Cost BDT -->
              <td v-if="visibleColumnMap.costBdt" class="text-center bw-ops-col-tint--cost font-mono text-weight-bold text-grey-9" style="width: 60px; min-width: 60px">
                ৳{{ formatMoney(row.costBdt) }}
              </td>

              <!-- Row Total Cost BDT -->
              <td v-if="visibleColumnMap.totalCostBdt" class="text-center bw-ops-col-tint--cost font-mono text-caption text-grey-9" style="width: 60px; min-width: 60px">
                ৳{{ formatMoney(row.totalCostBdt) }}
              </td>

              <!-- Offer Price BDT (Inline Edit) -->
              <td v-if="visibleColumnMap.offerPriceBdt" class="text-center bw-ops-col-tint--price" style="width: 64px; min-width: 64px">
                <div class="row justify-center">
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
                </div>
              </td>

              <!-- Total Offer BDT -->
              <td v-if="visibleColumnMap.totalBdt" class="text-center bw-ops-col-tint--price font-mono text-weight-bold text-positive" style="width: 64px; min-width: 64px">
                ৳{{ formatMoney(row.totalBdt) }}
              </td>

              <!-- Profit Per Unit BDT -->
              <td v-if="visibleColumnMap.profitPerUnitBdt" class="text-center font-mono text-caption text-teal-9 text-weight-bold" style="width: 56px; min-width: 56px">
                ৳{{ formatMoney(row.profitPerUnitBdt) }}
              </td>

              <!-- Row Total Profit BDT -->
              <td v-if="visibleColumnMap.profitBdt" class="text-center font-mono text-caption text-teal-9 text-weight-bold" style="width: 56px; min-width: 56px">
                ৳{{ formatMoney(row.profitBdt) }}
              </td>

              <!-- Profit Rate % -->
              <td v-if="visibleColumnMap.profitRate" class="text-center font-mono text-caption text-grey-8" style="width: 50px; min-width: 50px">
                {{ row.profitRate.toFixed(1) }}%
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
    </div>

    <!-- Bottom Sticky Footer Section: Scrollbar Only -->
    <div class="pbc-v2-footer-section bg-white border-top q-px-md q-py-xs shrink-0 shadow-xs row items-center justify-end">
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
        :summary="summaryMetrics"
        :billing-profiles="allBillingProfiles"
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
        :default-market-code="file?.market_code ?? null"
        @created="handleCreated"
        @updated="handleUpdated"
      />

      <q-dialog v-model="showBulkPasteDialog" persistent>
        <q-card style="width: 520px; max-width: 95vw; border-radius: 12px">
          <q-card-section class="row items-center justify-between q-pb-none">
            <div class="row items-center q-gutter-x-sm">
              <q-avatar color="primary" text-color="white" icon="ph ph-clipboard-text" size="32px" />
              <div>
                <div class="text-subtitle1 text-weight-bold text-grey-9">Bulk Paste {{ bulkPasteFieldLabel }}</div>
                <div class="text-caption text-grey-6">Paste tab-separated or newline-separated values from Excel/Sheets</div>
              </div>
            </div>
            <q-btn v-close-popup icon="ph ph-x" flat round dense color="grey-6" />
          </q-card-section>

          <q-card-section class="q-py-md">
            <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Paste Area</div>
            <q-input
              v-model="bulkPasteText"
              type="textarea"
              outlined
              dense
              rows="8"
              placeholder="Paste your copied column values here (e.g. from Excel)..."
              class="bg-white font-mono"
              style="font-size: 13px"
              autofocus
            />
          </q-card-section>

          <q-separator />

          <q-card-actions align="right" class="q-pa-md bg-grey-1">
            <q-btn v-close-popup flat label="Cancel" color="grey-7" no-caps :disable="bulkPasteSaving" />
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
          </q-card-actions>
        </q-card>
      </q-dialog>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useI18n } from 'vue-i18n';
import { useQueryClient } from '@tanstack/vue-query';
import SmartImage from 'src/components/SmartImage.vue';
import AddCostingItemsDrawer from '../components/AddCostingItemsDrawer.vue';
import { productBasedCostingService } from '../services/productBasedCostingService';
import type { ProductBasedCostingItemUpdateInput } from '../types';
import PbcBacklogSuggestDrawer from '../components/PbcBacklogSuggestDrawer.vue';
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue';
import ProductBasedCostingItemAddDialog from '../components/ProductBasedCostingItemAddDialog.vue';
import ProductBasedCostingSettingsDrawer, {
  type PbcSettingsDrawerAction,
} from '../components/ProductBasedCostingSettingsDrawer.vue';
import ProductBasedCostingStatusOverrideDialog from '../components/ProductBasedCostingStatusOverrideDialog.vue';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useBillingProfilesQuery } from 'src/modules/sales_invoice/composables/useBillingProfileQuery';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { useProductBasedCostingFileDetailQuery } from '../composables/useProductBasedCostingFileDetailQuery';
import { useProductBasedCostingItemsInfiniteQuery } from '../composables/useProductBasedCostingItemsInfiniteQuery';
import { useUpdateProductBasedCostingFileMutation } from '../composables/useProductBasedCostingFileMutations';
import {
  useDeleteProductBasedCostingItemMutation,
  useDeleteProductBasedCostingItemsBulkMutation,
  useUpdateProductBasedCostingItemMutation,
  useRecalculateOfferPricesMutation,
} from '../composables/useProductBasedCostingItemMutations';
import type { ProductBasedCostingItem } from '../types';
import { usePbcBacklog, type BacklogItem } from '../composables/usePbcBacklog';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';
import {
  allColumnNames,
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

const props = defineProps<{
  id?: string | number;
}>();

const $q = useQuasar();
const { t } = useI18n();
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

// Queries
const { data: file, isLoading: isLoadingFile } = useProductBasedCostingFileDetailQuery(fileId);
const {
  costingItems,
  totalItemsCount,
  hasMoreItems,
  isLoading: isLoadingItems,
  isFetchingNextPage: isFetchingMoreItems,
  fetchNextPage,
} = useProductBasedCostingItemsInfiniteQuery(fileId);

const isLoading = computed(() => isLoadingFile.value || isLoadingItems.value);

// State
const selectedRowIds = ref<number[]>([]);
const showBacklogDrawer = ref(false);
const showFileDialog = ref(false);
const showSettingsDrawer = ref(false);
const settingsDrawerInitialTab = ref<string | undefined>(undefined);
const showStatusOverrideDialog = ref(false);
const showItemDialog = ref(false);
const selectedItem = ref<ProductBasedCostingItem | null>(null);
const updatingStatus = ref(false);
const targetUpdatingStatus = ref<string | null>(null);

type PbcBulkPasteField = 'quantity' | 'price_gbp' | 'product_weight' | 'package_weight';

const showBulkPasteDialog = ref(false);
const bulkPasteField = ref<PbcBulkPasteField>('quantity');
const bulkPasteText = ref('');
const bulkPasteSaving = ref(false);

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
    default:
      return 'Values';
  }
});

const tenantIdRef = computed(() => tenantStore.selectedTenant?.id);
const { data: billingProfilesResult } = useBillingProfilesQuery(tenantIdRef);
const allBillingProfiles = computed(() => billingProfilesResult.value?.data ?? []);

const ratesExpanded = ref(false);
const savingRates = ref(false);
const localRates = reactive({
  conversion_rate: 140,
  cargo_rate_kg_gbp: 0,
  profit_rate: 25,
});

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

// Rates
const cargoRateValue = computed(() => file.value?.cargo_rate_kg_gbp ?? localRates.cargo_rate_kg_gbp);
const conversionRateValue = computed(() => file.value?.conversion_rate ?? localRates.conversion_rate);
const profitRateValue = computed(() => file.value?.profit_rate ?? localRates.profit_rate);

watch(
  file,
  (newFile) => {
    if (newFile) {
      localRates.conversion_rate = newFile.conversion_rate ?? 140;
      localRates.cargo_rate_kg_gbp = newFile.cargo_rate_kg_gbp ?? 0;
      localRates.profit_rate = newFile.profit_rate ?? 25;
    }
  },
  { immediate: true },
);

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
  const map: Record<string, boolean> = {
    select: true,
    sl: true,
    image: true,
    name: true,
  };
  for (const col of allColumnNames) {
    map[col] = visibleColumns.value.includes(col);
  }
  return map;
});

const columnSearchQuery = ref('');
const filteredColumnOptions = computed(() => {
  const q = columnSearchQuery.value.trim().toLowerCase();
  if (!q) return columnSelectorOptions;
  return columnSelectorOptions.filter((opt) => opt.label.toLowerCase().includes(q));
});

const allColumnsVisible = computed(() => {
  return columnSelectorOptions.every((col) => visibleColumns.value.includes(col.value));
});

function toggleSelectAllColumns() {
  if (allColumnsVisible.value) {
    visibleColumns.value = ['select', 'sl', 'image', 'name'];
  } else {
    visibleColumns.value = [...allColumnNames];
  }
}

function toggleColumn(key: string) {
  if (visibleColumns.value.includes(key)) {
    visibleColumns.value = visibleColumns.value.filter((col) => col !== key);
  } else {
    visibleColumns.value = [...visibleColumns.value, key];
  }
}

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
    const calculatedOfferPriceBdt = costBdt * (1 + itemProfitRate / 100);
    const offerPriceBdt = item.is_offer_price_manual && item.offer_price != null
      ? item.offer_price
      : calculatedOfferPriceBdt;

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
      totalBdt,
      profitPerUnitBdt,
      profitBdt,
      profitRate: itemProfitRate,
      status: item.status ?? 'pending',
      raw: item,
    };
  });
});

// Draft Values for Inline Editing
const draftValues = reactive<Record<string, Record<string, unknown>>>({});

function getDraftValue(row: { id: number; raw: ProductBasedCostingItem }, field: keyof ProductBasedCostingItem) {
  if (draftValues[row.id]?.[field] !== undefined) {
    return draftValues[row.id][field];
  }
  return row.raw[field] ?? '';
}

function setDraftValue(row: { id: number }, field: string, val: unknown) {
  if (!draftValues[row.id]) {
    draftValues[row.id] = {};
  }
  draftValues[row.id][field] = val;
}

async function saveDraftValue(
  row: { id: number; raw: ProductBasedCostingItem },
  field: keyof ProductBasedCostingItem,
  opts?: { decimals?: number },
) {
  if (!draftValues[row.id] || draftValues[row.id][field] === undefined) return;
  const rawVal = draftValues[row.id][field];
  delete draftValues[row.id][field];

  let parsedVal: number | string | null = rawVal as any;
  if (typeof rawVal === 'string' && rawVal.trim() !== '') {
    const num = Number(rawVal);
    if (!isNaN(num)) {
      parsedVal = opts?.decimals !== undefined ? Number(num.toFixed(opts.decimals)) : num;
    }
  } else if (rawVal === '') {
    parsedVal = null;
  }

  if (row.raw[field] === parsedVal) return;

  try {
    const payload: Partial<ProductBasedCostingItem> & { id: number } = {
      id: row.id,
      [field]: parsedVal,
    };
    if (field === 'offer_price') {
      payload.is_offer_price_manual = true;
    }
    await updateItemMutation.mutateAsync(payload);
  } catch {
    $q.notify({ type: 'negative', message: 'Failed to update item' });
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

function onSlPositionChange(currentIndex: number, newPosition: string | number | null) {
  moveItemToPosition(currentIndex, newPosition);
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

  try {
    await productBasedCostingRepository.reorderProductBasedCostingItemToPosition(
      fileId.value,
      currentItem.id,
      parsed,
    );
    await queryClient.invalidateQueries({
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
  const profileId = file.value?.billing_profile_id;
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

function openCatalogDialog() {
  if (!fileId.value) return;
  $q.dialog({
    component: AddCostingItemsDrawer,
    componentProps: { fileId: fileId.value },
  }).onOk((result?: { createProductName?: string }) => {
    void queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
    });
    refreshBacklog();
    if (result?.createProductName != null) {
      selectedItem.value = { name: result.createProductName } as ProductBasedCostingItem;
      showItemDialog.value = true;
    }
  });
}

function openBulkPasteDialog(field: PbcBulkPasteField) {
  if (!costingItems.value.length) {
    $q.notify({ type: 'warning', message: t('product_based_costing.no_items_to_update') });
    return;
  }
  bulkPasteField.value = field;
  bulkPasteText.value = '';
  bulkPasteSaving.value = false;
  showBulkPasteDialog.value = true;
}

async function applyBulkPaste() {
  const text = bulkPasteText.value.trim();
  if (!text) {
    showBulkPasteDialog.value = false;
    return;
  }

  const tokens = text
    .split(/[\r\n\t]+/)
    .map((token) => token.trim())
    .filter((token) => token.length > 0);

  if (tokens.length === 0) {
    showBulkPasteDialog.value = false;
    return;
  }

  const items = costingItems.value;
  const field = bulkPasteField.value;
  const updates: ProductBasedCostingItemUpdateInput[] = [];
  let count = 0;

  for (let i = 0; i < tokens.length; i++) {
    const targetItem = items[i];
    if (!targetItem) break;

    const cleaned = tokens[i].replace(/[^0-9.-]/g, '');
    if (cleaned === '') continue;

    const val = Number(cleaned);
    if (isNaN(val)) continue;

    let normalized: number;
    if (field === 'price_gbp') {
      normalized = Number(val.toFixed(2));
    } else if (field === 'quantity') {
      normalized = Math.max(1, Math.round(val));
    } else {
      normalized = Number(val.toFixed(3));
    }

    updates.push({
      id: targetItem.id,
      [field]: normalized,
    });
    count++;
  }

  if (updates.length === 0) {
    $q.notify({
      type: 'warning',
      message: 'No valid numeric values found in pasted text.',
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

    if (result.data?.length && fileId.value) {
      await queryClient.invalidateQueries({
        queryKey: productBasedCostingQueryKeys.itemsRoot(fileId.value),
      });
    }

    $q.notify({
      type: 'positive',
      message: `Successfully pasted and saved ${count} ${bulkPasteFieldLabel.value} value(s)`,
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

function handleDownloadExcel() {
  void downloadExcel(file.value?.name ?? `PBC_${fileId.value}`);
}

function openPreviewAndPrint() {
  if (!fileId.value) return;
  const previewRoute = router.resolve({
    name: 'product-based-costing-file-preview-page',
    params: { id: fileId.value },
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

const statusBadgeColor = computed(() => {
  const st = status.value;
  if (st === 'confirmed' || st === 'ready_for_shipment' || st === 'delivered') {
    return { color: 'green-1', textColor: 'green-9' };
  }
  if (st === 'offered' || st === 'procuring') {
    return { color: 'blue-1', textColor: 'blue-9' };
  }
  if (st === 'cancelled') {
    return { color: 'red-1', textColor: 'red-9' };
  }
  return { color: 'orange-1', textColor: 'orange-9' };
});

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
    });
    await recalculateOfferPricesMutation.mutateAsync(fileId.value);
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
    billing_profile_id: file.value.billing_profile_id ?? null,
    note: file.value.note ?? '',
    vendor_code: file.value.vendor_code ?? null,
    market_code: file.value.market_code ?? null,
  };
});

async function handleUpdateFileDialog(payload: {
  id: number | null;
  name: string;
  order_for: string;
  billing_profile_id: number | null;
  note: string;
  vendor_code: string | null;
  market_code: string | null;
}) {
  if (!payload.id) return;
  await updateFileMutation.mutateAsync({
    id: payload.id,
    name: payload.name,
    order_for: payload.order_for,
    billing_profile_id: payload.billing_profile_id,
    note: payload.note,
    vendor_code: payload.vendor_code,
    market_code: payload.market_code,
  });
  showFileDialog.value = false;
  refreshBacklog();
}

const summaryMetrics = computed(() => {
  let totalQuantity = 0;
  let goodsCostGbp = 0;
  let cargoWeightKg = 0;
  let totalCostBdt = 0;
  let totalOfferPriceBdt = 0;
  let totalProfitBdt = 0;

  for (const item of costingItems.value) {
    const qty = Number(item.quantity) || 0;
    const priceGbp = Number(item.price_gbp) || 0;
    const offerPrice = Number(item.offer_price) || 0;
    const pkgWt = Number(item.package_weight) || 0;

    totalQuantity += qty;
    goodsCostGbp += priceGbp * qty;
    cargoWeightKg += (pkgWt * qty) / 1000;

    const rowCostGbp = priceGbp * qty + ((cargoRateValue.value * pkgWt * qty) / 1000);
    const rowCostBdt = rowCostGbp * conversionRateValue.value;
    const rowOfferBdt = offerPrice * qty;

    totalCostBdt += rowCostBdt;
    totalOfferPriceBdt += rowOfferBdt;
    totalProfitBdt += (rowOfferBdt - rowCostBdt);
  }

  return {
    totalQuantity,
    goodsCostGbp,
    cargoWeightKg,
    totalCostBdt,
    totalOfferPriceBdt,
    totalProfitBdt,
  };
});

async function handleUpdateFileDirect(payload: Record<string, any>) {
  if (!fileId.value) return;
  await updateFileMutation.mutateAsync({
    id: fileId.value,
    ...payload,
  });
  $q.notify({ type: 'positive', message: 'File details updated' });
}

async function handleUpdateRatesDirect(payload: { conversion_rate: number; cargo_rate_kg_gbp: number; profit_rate: number }) {
  if (!fileId.value) return;
  await updateFileMutation.mutateAsync({
    id: fileId.value,
    conversion_rate: payload.conversion_rate,
    cargo_rate_kg_gbp: payload.cargo_rate_kg_gbp,
    profit_rate: payload.profit_rate,
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
    if (allItems.length > 0) {
      await Promise.all(
        allItems.map((item) =>
          productBasedCostingRepository.updateProductBasedCostingItem({
            id: item.id,
            confirmed_quantity: item.quantity ?? 0,
          }),
        ),
      );
    }
    await queryClient.invalidateQueries({
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
  void applyStatus(nextStatus);
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
  height: calc(100vh - 55px);
  overflow: hidden;
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.border-grey {
  border: 1px solid rgba(0, 0, 0, 0.12);
}

.rounded-sq-btn {
  border-radius: 8px !important;
}

.pbc-v2-markup-table {
  border-collapse: collapse;
}

.pbc-v2-markup-table thead tr th {
  position: sticky;
  top: 0;
  z-index: 5;
  background-color: #f1f5f9 !important;
  color: #0f172a !important;
  border-bottom: 1px solid rgba(0, 0, 0, 0.12);
  padding: 4px 6px !important;
  font-size: 11px;
}

.pbc-v2-markup-table tbody tr td {
  padding: 3px 4px !important;
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
  min-height: 44px;
  height: auto;
  vertical-align: middle;
}

.pbc-image-cell {
  padding: 2px !important;
  vertical-align: middle;
}

/* Soft Column Tints (Color Code Standard from OPS_SPREADSHEET_TABLE_PATTERN.md) */
.pbc-v2-markup-table th.bw-ops-col-tint--price,
.pbc-v2-markup-table td.bw-ops-col-tint--price {
  background-color: #daf3e4 !important;
  box-shadow: inset 2px 0 0 #059669;
}

.pbc-v2-markup-table th.bw-ops-col-tint--cost,
.pbc-v2-markup-table td.bw-ops-col-tint--cost {
  background-color: #ffe8d1 !important;
  box-shadow: inset 2px 0 0 #ea580c;
}

.pbc-v2-markup-table th.bw-ops-col-tint--qty,
.pbc-v2-markup-table td.bw-ops-col-tint--qty {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

.pbc-v2-markup-table th.bw-ops-col-tint--weight,
.pbc-v2-markup-table td.bw-ops-col-tint--weight {
  background-color: #e8d7f7 !important;
  box-shadow: inset 2px 0 0 #9333ea;
}

.pbc-row:hover {
  background-color: #f8fafc !important;
}

.pbc-row:hover td {
  filter: brightness(0.98);
}

.pbc-row-selected {
  background-color: #eff6ff !important;
}

.pbc-row-selected td {
  background-color: #e0f2fe !important;
}

.pbc-row-img {
  width: 0.85in;
  height: 0.85in;
  display: block;
  margin: 0 auto;
  border-radius: 6px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background: #fff;
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
  border: 1px dashed rgba(0, 0, 0, 0.12);
  background-color: #f1f5f9;
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
  background-color: #f8f9fa;
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

/* Crisp Excel focus box */
:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: #ffffff !important;
  border: 1.5px solid #059669 !important;
  box-shadow: 0 0 0 1px #059669 !important;
}

.rates-pill {
  border: 1px solid rgba(0, 0, 0, 0.08);
}

.name-inline-title:hover .edit-icon {
  color: var(--q-primary) !important;
}

.excel-scrollbar-wrapper {
  background-color: #e2e8f0;
  height: 22px;
  width: 220px;
  max-width: 260px;
  border-radius: 4px;
  border: 1px solid #cbd5e1;
  padding: 0 2px;
}

.excel-scroll-arrow-btn {
  background: transparent;
  border: none;
  color: #475569;
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
  background-color: #cbd5e1;
  color: #0f172a;
}

.excel-scroll-track {
  height: 12px;
  width: 160px;
  background-color: #cbd5e1;
  border-radius: 3px;
  position: relative;
  margin: 0 4px;
}

.excel-scroll-thumb {
  height: 12px;
  background-color: #64748b;
  border-radius: 3px;
  position: absolute;
  top: 0;
  cursor: grab;
  transition: background-color 0.15s ease;
}

.excel-scroll-thumb:hover {
  background-color: #475569;
}

.hide-native-scrollbar {
  scrollbar-width: thin;
}
</style>
