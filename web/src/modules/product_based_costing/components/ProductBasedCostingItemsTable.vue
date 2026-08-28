<template>
  <div class="product-based-costing-table">
    <div
      v-if="selectedRowIds.length"
      class="bulk-selection-bar row items-center justify-between q-mb-sm"
    >
      <div class="text-body2 text-weight-medium">{{ selectedRowIds.length }} item(s) selected</div>
      <div class="row items-center q-gutter-sm">
        <q-btn
          flat
          no-caps
          color="grey-8"
          :label="$t('product_based_costing.clear_selection')"
          @click="selectedRowIds = []"
        />
        <q-btn
          v-if="selectedRowIds.length === 1"
          unelevated
          no-caps
          color="primary"
          icon="ph ph-pencil-simple"
          :label="$t('product_based_costing.edit')"
          @click="onEditSelected"
        />
        <q-btn
          color="negative"
          no-caps
          icon="ph ph-trash"
          :label="
            selectedRowIds.length === 1
              ? $t('product_based_costing.delete')
              : $t('product_based_costing.delete_selected')
          "
          @click="showBulkDeleteConfirm = true"
        />
      </div>
    </div>

    <div
      v-if="normalizedFileStatus === 'procuring' || normalizedFileStatus === 'ready_for_shipment'"
      class="row items-center justify-between q-pa-sm q-mb-sm bg-grey-1 rounded-borders border-grey-3"
    >
      <div class="row items-center q-gutter-xs">
        <q-btn
          :unelevated="statusFilter === 'all'"
          :flat="statusFilter !== 'all'"
          dense
          no-caps
          color="primary"
          :label="$t('product_based_costing.all_statuses')"
          class="q-px-sm text-caption"
          @click="statusFilter = 'all'"
        />
        <q-btn
          :unelevated="statusFilter === 'active'"
          :flat="statusFilter !== 'active'"
          dense
          no-caps
          color="teal-8"
          icon="ph ph-funnel"
          :label="
            status === 'ready_for_shipment'
              ? $t('product_based_costing.hide_rejected_unavailable')
              : $t('product_based_costing.hide_rejected')
          "
          class="q-px-sm text-caption"
          @click="statusFilter = 'active'"
        />
      </div>
      <div class="text-caption text-grey-7">
        {{
          $t('product_based_costing.showing_of_items', {
            shown: displayRows.length,
            total: tableRows.length,
          })
        }}
      </div>
    </div>

    <q-table
      flat
      bordered
      :rows="displayRows"
      :columns="columns"
      :visible-columns="resolvedVisibleColumns"
      row-key="id"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      :style="{ height: 'clamp(360px, calc(100vh - 300px), 78vh)' }"
      :table-style="{ maxHeight: '100%' }"
      class="costing-q-table"
    >
      <template #item="slotProps">
        <div class="col-12 col-sm-6 q-pa-xs q-sm-pa-sm">
          <q-card
            flat
            bordered
            class="costing-item-card floating-surface shadow-1"
            :class="{ 'row-incomplete-offer': slotProps.row.offerInputsIncomplete }"
          >
            <!-- Card Header -->
            <div class="card-header row items-center justify-between q-px-md q-py-sm">
              <div class="row items-center q-gutter-xs">
                <q-checkbox
                  :model-value="selectedRowIds.includes(slotProps.row.id)"
                  @update:model-value="(checked) => onToggleRowSelection(slotProps.row.id, checked)"
                  dense
                />
                <q-badge color="grey-3" text-color="grey-9" class="text-weight-bold cursor-pointer text-underline-dashed">
                  #{{ slotProps.row.sl }}
                  <q-popup-edit
                    :model-value="slotProps.row.sl"
                    buttons
                    persistent
                    :label-set="$t('product_based_costing.move') || 'Move'"
                    :label-cancel="$t('product_based_costing.cancel') || 'Cancel'"
                    v-slot="scope"
                    @save="(val) => moveItemToPosition(slotProps.rowIndex, val)"
                  >
                    <q-input
                      :model-value="scope.value ?? ''"
                      type="number"
                      dense
                      outlined
                      autofocus
                      min="1"
                      :max="displayRows.length"
                      label="New SL Position"
                      @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                      @keyup.enter="scope.set"
                    />
                  </q-popup-edit>
                </q-badge>
                <div class="row items-center q-gutter-none">
                  <q-btn
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-caret-up"
                    :disable="slotProps.rowIndex === 0"
                    class="q-my-none"
                    style="height: 18px; min-height: 18px; width: 18px"
                    @click.stop="moveItem(slotProps.rowIndex, 'up')"
                  >
                    <q-tooltip>Move Up</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-caret-down"
                    :disable="slotProps.rowIndex === displayRows.length - 1"
                    class="q-my-none"
                    style="height: 18px; min-height: 18px; width: 18px"
                    @click.stop="moveItem(slotProps.rowIndex, 'down')"
                  >
                    <q-tooltip>Move Down</q-tooltip>
                  </q-btn>
                </div>
              </div>

              <div class="row items-center q-gutter-xs">
                <div
                  v-if="isColumnVisible('status')"
                  class="text-center relative-position"
                >
                  <q-badge
                    :color="getStatusColor(slotProps.row.status)"
                    outline
                    class="q-px-sm q-py-xs"
                  >
                    {{ slotProps.row.status }}
                    <q-tooltip
                      v-if="getItemStatusHint(slotProps.row.status)"
                      class="pbc-status-tooltip"
                      max-width="280px"
                      anchor="top middle"
                      self="bottom middle"
                      :offset="[0, 8]"
                    >
                      <div class="pbc-status-tooltip__k">{{ $t('product_based_costing.tooltip_use_when') }}</div>
                      <div class="pbc-status-tooltip__v">
                        {{ getItemStatusHint(slotProps.row.status)?.when }}
                      </div>
                      <div class="pbc-status-tooltip__k pbc-status-tooltip__k--next">
                        {{ $t('product_based_costing.tooltip_this_will') }}
                      </div>
                      <div class="pbc-status-tooltip__v">
                        {{ getItemStatusHint(slotProps.row.status)?.does }}
                      </div>
                    </q-tooltip>
                  </q-badge>
                </div>
              </div>
            </div>

            <q-separator />

            <!-- Card Body -->
            <q-card-section class="q-pa-md">
              <div class="row q-col-gutter-sm items-start">
                <!-- Image -->
                <div v-if="isColumnVisible('image')" class="col-4 col-sm-3 text-center">
                  <div class="card-image-wrapper">
                    <SmartImage
                      :src="slotProps.row.imageUrl"
                      :alt="slotProps.row.name || $t('product_based_costing.product_image_alt')"
                      img-class="card-image"
                      fallback-class="card-image-placeholder"
                    />
                  </div>
                  <q-badge
                    v-if="slotProps.row.offerInputsIncomplete"
                    color="warning"
                    text-color="grey-9"
                    class="offer-incomplete-badge q-mt-xs"
                  >
                    {{ $t('product_based_costing.missing_price_weight') }}
                  </q-badge>
                </div>

                <!-- Info -->
                <div class="col-8 col-sm-9">
                  <div class="row items-start justify-between no-wrap q-gutter-xs">
                    <span
                      class="card-item-name text-weight-bold text-primary cursor-pointer"
                      @click="onEdit(slotProps.row)"
                    >{{ slotProps.row.name }}</span>
                    <q-badge
                      v-if="slotProps.row.raw.assigned_shipment_id || slotProps.row.status === 'on_shipment'"
                      color="teal-8"
                      text-color="white"
                      class="q-px-xs text-caption"
                    >
                      <q-icon name="ph ph-truck" class="q-mr-xs" />
                      {{ $t('product_based_costing.added_to_shipment') }}
                    </q-badge>
                  </div>

                  <div
                    v-if="isColumnVisible('brand') && slotProps.row.brand"
                    class="text-caption text-grey-8 q-mt-xs"
                  >
                    <strong>{{ $t('product_based_costing.table_col_brand') }}:</strong> {{ slotProps.row.brand }}
                  </div>

                  <div
                    v-if="isColumnVisible('barcodeText')"
                    class="card-barcode-lines text-caption text-grey-7 q-mt-xs"
                  >
                    <div v-if="slotProps.row.barcode" class="row items-center no-wrap">
                      <span>{{ $t('product_based_costing.barcode') }}: {{ slotProps.row.barcode }}</span>
                      <q-btn
                        flat
                        round
                        dense
                        size="xs"
                        icon="ph ph-copy"
                        color="grey-6"
                        class="q-ml-xs"
                        @click="handleCopy(slotProps.row.barcode, $t('product_based_costing.barcode'))"
                      >
                        <q-tooltip>{{ $t('product_based_costing.copy_barcode') }}</q-tooltip>
                      </q-btn>
                    </div>
                    <div v-if="slotProps.row.productCode" class="row items-center no-wrap">
                      <span>{{ $t('product_based_costing.code') }}: {{ slotProps.row.productCode }}</span>
                      <q-btn
                        flat
                        round
                        dense
                        size="xs"
                        icon="ph ph-copy"
                        color="grey-6"
                        class="q-ml-xs"
                        @click="handleCopy(slotProps.row.productCode, $t('product_based_costing.code'))"
                      >
                        <q-tooltip>{{ $t('product_based_costing.copy_code') }}</q-tooltip>
                      </q-btn>
                    </div>
                    <div v-if="slotProps.row.productId" class="row items-center no-wrap">
                      <span>ID: {{ slotProps.row.productId }}</span>
                      <q-btn
                        flat
                        round
                        dense
                        size="xs"
                        icon="ph ph-copy"
                        color="grey-6"
                        class="q-ml-xs"
                        @click="handleCopy(String(slotProps.row.productId), $t('product_based_costing.product_id'))"
                      >
                        <q-tooltip>{{ $t('product_based_costing.copy_product_id') }}</q-tooltip>
                      </q-btn>
                    </div>
                  </div>

                  <div v-if="isColumnVisible('website') && slotProps.row.website" class="q-mt-xs">
                    <q-btn
                      flat
                      dense
                      no-caps
                      color="primary"
                      icon="ph ph-arrow-up-right"
                      :label="$t('product_based_costing.table_col_website')"
                      size="xs"
                      type="a"
                      :href="slotProps.row.website"
                      target="_blank"
                      rel="noopener noreferrer"
                    />
                  </div>
                </div>
              </div>

              <!-- Note Section -->
              <div
                v-if="isColumnVisible('note')"
                class="card-note-section q-mt-md q-pa-sm rounded-borders bg-grey-1 text-caption"
              >
                <div class="text-weight-bold text-grey-7 q-mb-xs">{{ $t('product_based_costing.note') }}</div>
                <q-input
                  v-model="slotProps.row.noteHtml"
                  type="textarea"
                  autogrow
                  dense
                  borderless
                  class="cell-input"
                  input-class="text-caption"
                  :placeholder="$t('product_based_costing.note')"
                  @blur="onNoteBlur(slotProps.row)"
                />
              </div>
            </q-card-section>

            <q-separator />

            <!-- Costing Grid -->
            <q-card-section class="q-pa-md bg-grey-0">
              <div class="row q-col-gutter-sm card-costing-grid">
                <!-- Qty -->
                <div
                  v-if="isColumnVisible('qty')"
                  class="col-6 col-sm-3 text-center q-pa-xs rounded-borders"
                >
                  <div class="metric-label">{{ $t('product_based_costing.table_col_qty') }}</div>
                  <q-input
                    v-model.number="slotProps.row.qty"
                    type="number"
                    dense
                    borderless
                    input-class="text-center bw-tabular"
                    class="cell-input"
                    min="0"
                    step="1"
                    @blur="onQtyBlur(slotProps.row)"
                    @keyup.enter="blurInput"
                  />
                </div>

                <!-- Confirmed Qty -->
                <div
                  v-if="isColumnVisible('confirmedQty')"
                  class="col-6 col-sm-3 text-center q-pa-xs rounded-borders"
                  :class="{ 'qty-col--focus': focusConfirmedQty }"
                >
                  <div class="metric-label">
                    <q-icon
                      v-if="focusConfirmedQty"
                      name="ph ph-pencil-simple"
                      size="12px"
                      class="q-mr-xs"
                    />
                    {{ $t('product_based_costing.table_col_confirmedQty') }}
                  </div>
                  <q-input
                    v-model.number="slotProps.row.confirmedQty"
                    type="number"
                    dense
                    borderless
                    input-class="text-center bw-tabular"
                    class="cell-input"
                    :class="{ 'cell-input--review': focusConfirmedQty }"
                    min="0"
                    step="1"
                    @blur="onConfirmedQtyBlur(slotProps.row)"
                    @keyup.enter="blurInput"
                  />
                  <div v-if="focusConfirmedQty" class="text-caption text-grey-7">
                    {{ $t('product_based_costing.edit_if_took_less') }}
                  </div>
                </div>

                <!-- Price GBP -->
                <div
                  v-if="isColumnVisible('priceGbp')"
                  class="col-6 col-sm-3 text-center bg-gbp-light q-pa-xs rounded-borders"
                >
                  <div class="metric-label text-green-9">{{ $t('product_based_costing.bulk_price_gbp') }}</div>
                  <q-input
                    v-model.number="slotProps.row.priceGbp"
                    type="number"
                    dense
                    borderless
                    input-class="text-center text-green-10 text-weight-bold bw-tabular"
                    class="cell-input"
                    min="0"
                    step="0.01"
                    @blur="onPriceGbpBlur(slotProps.row)"
                    @keyup.enter="blurInput"
                  />
                </div>

                <div
                  v-if="isColumnVisible('productWeight')"
                  class="col-6 col-sm-3 text-center q-pa-xs rounded-borders"
                >
                  <div class="metric-label">{{ $t('product_based_costing.bulk_product_weight_g') }}</div>
                  <q-input
                    v-model.number="slotProps.row.productWeight"
                    type="number"
                    dense
                    borderless
                    input-class="text-center bw-tabular"
                    class="cell-input"
                    min="0"
                    step="1"
                    @focus="clearZeroOnFocus(slotProps.row, 'productWeight')"
                    @blur="onProductWeightBlur(slotProps.row)"
                    @keyup.enter="blurInput"
                  />
                </div>

                <div
                  v-if="isColumnVisible('packageWeight')"
                  class="col-6 col-sm-3 text-center q-pa-xs rounded-borders"
                >
                  <div class="metric-label">{{ $t('product_based_costing.bulk_package_weight_g') }}</div>
                  <q-input
                    v-model.number="slotProps.row.packageWeight"
                    type="number"
                    dense
                    borderless
                    input-class="text-center bw-tabular"
                    class="cell-input"
                    min="0"
                    step="1"
                    @focus="clearZeroOnFocus(slotProps.row, 'packageWeight')"
                    @blur="onPackageWeightBlur(slotProps.row)"
                    @keyup.enter="blurInput"
                  />
                </div>

                <!-- Offer Price BDT -->
                <div
                  v-if="isColumnVisible('offerPriceBdt')"
                  class="col-6 col-sm-3 text-center bg-offer-light q-pa-xs rounded-borders"
                >
                  <div class="metric-label text-purple-9">{{ $t('product_based_costing.preview_offer_price_bdt') }}</div>
                  <div class="row items-center justify-center no-wrap">
                    <q-icon
                      v-if="slotProps.row.isOfferPriceManual"
                      name="ph ph-lock-key"
                      color="amber-8"
                      size="16px"
                    >
                      <q-tooltip>{{ $t('product_based_costing.offer_locked_tooltip') }}</q-tooltip>
                    </q-icon>
                    <q-input
                      v-model.number="slotProps.row.offerPriceBdt"
                      type="number"
                      dense
                      borderless
                      input-class="text-center text-purple-10 text-weight-bold bw-tabular"
                      class="cell-input"
                      min="0"
                      step="1"
                      @blur="onOfferPriceBlur(slotProps.row)"
                      @keyup.enter="blurInput"
                    />
                    <q-btn
                      v-if="slotProps.row.isOfferPriceManual"
                      flat
                      round
                      dense
                      size="xs"
                      icon="ph ph-arrows-clockwise"
                      color="grey-7"
                      :aria-label="$t('product_based_costing.unlock_offer_price')"
                      @click="onUnlockOfferPrice(slotProps.row)"
                    >
                      <q-tooltip>{{ $t('product_based_costing.unlock_offer_price_tooltip') }}</q-tooltip>
                    </q-btn>
                  </div>
                </div>

                <!-- Cost BDT -->
                <div
                  v-if="isColumnVisible('costBdt')"
                  class="col-6 col-sm-3 text-center bg-bdt-light q-pa-xs rounded-borders"
                >
                  <div class="metric-label text-amber-9">{{ $t('product_based_costing.preview_cost_bdt') }}</div>
                  <div class="metric-value text-amber-10 bw-tabular text-weight-medium">
                    ৳{{ formatNumber(getCostBdt(slotProps.row)) }}
                  </div>
                </div>

                <!-- Total Cost BDT -->
                <div
                  v-if="isColumnVisible('totalCostBdt')"
                  class="col-6 col-sm-3 text-center bg-bdt-light q-pa-xs rounded-borders"
                >
                  <div class="metric-label text-amber-9">{{ $t('product_based_costing.table_col_totalCostBdt') }}</div>
                  <div class="metric-value text-amber-10 bw-tabular text-weight-medium">
                    ৳{{ formatNumber(getTotalCostBdt(slotProps.row)) }}
                  </div>
                </div>

                <!-- Profit BDT -->
                <div v-if="isColumnVisible('profitBdt')" class="col-6 col-sm-3 text-center">
                  <div class="metric-label">{{ $t('product_based_costing.preview_profit_bdt') }}</div>
                  <div class="metric-value bw-tabular">
                    ৳{{ formatNumber(getProfitBdt(slotProps.row)) }}
                  </div>
                </div>

                <!-- Profit Rate -->
                <div v-if="isColumnVisible('profitRate')" class="col-6 col-sm-3 text-center">
                  <div class="metric-label">{{ $t('product_based_costing.table_col_profitRate') }}</div>
                  <div class="metric-value bw-tabular">
                    {{ formatNumber(getProfitRate(slotProps.row)) }}%
                  </div>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </template>

      <template #header-cell-select="slotProps">
        <q-th :props="slotProps">
          <q-checkbox v-model="isAllSelected" dense />
        </q-th>
      </template>

      <template #header-cell-confirmedQty="slotProps">
        <q-th
          :props="slotProps"
          class="col-confirmed-qty text-center"
          :class="{ 'qty-col--focus': focusConfirmedQty }"
        >
          <div class="confirmed-qty-header">
            <span>
              <q-icon
                v-if="focusConfirmedQty"
                name="ph ph-pencil-simple"
                size="14px"
                class="q-mr-xs"
              />
              {{ $t('product_based_costing.table_col_confirmedQty') }}
            </span>
            <span v-if="focusConfirmedQty" class="text-caption text-grey-7">
              {{ $t('product_based_costing.edit_if_took_less') }}
            </span>
          </div>
        </q-th>
      </template>

      <template #body="slotProps">
        <q-tr :props="slotProps" :class="{ 'row-incomplete-offer': slotProps.row.offerInputsIncomplete }">
          <q-td key="select" :props="slotProps" class="col-select text-center">
            <q-checkbox
              :model-value="selectedRowIds.includes(slotProps.row.id)"
              @update:model-value="(checked) => onToggleRowSelection(slotProps.row.id, checked)"
              dense
            />
          </q-td>
          <q-td key="sl" :props="slotProps" class="col-sl text-right">
            <div class="row items-center justify-end no-wrap">
              <span class="cursor-pointer text-underline-dashed text-weight-medium">
                {{ slotProps.row.sl }}
              </span>
              <q-popup-edit
                :model-value="slotProps.row.sl"
                buttons
                persistent
                :label-set="$t('product_based_costing.move') || 'Move'"
                :label-cancel="$t('product_based_costing.cancel') || 'Cancel'"
                v-slot="scope"
                @save="(val) => moveItemToPosition(slotProps.rowIndex, val)"
              >
                <q-input
                  :model-value="scope.value ?? ''"
                  type="number"
                  dense
                  outlined
                  autofocus
                  min="1"
                  :max="displayRows.length"
                  label="New SL Position"
                  @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
              <div class="column items-center justify-center q-ml-xs">
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-caret-up"
                  :disable="slotProps.rowIndex === 0"
                  class="q-my-none"
                  style="height: 14px; min-height: 14px"
                  @click.stop="moveItem(slotProps.rowIndex, 'up')"
                >
                  <q-tooltip>Move Up</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-caret-down"
                  :disable="slotProps.rowIndex === displayRows.length - 1"
                  class="q-my-none"
                  style="height: 14px; min-height: 14px"
                  @click.stop="moveItem(slotProps.rowIndex, 'down')"
                >
                  <q-tooltip>Move Down</q-tooltip>
                </q-btn>
              </div>
            </div>
          </q-td>

          <q-td key="image" :props="slotProps" class="col-image text-center">
            <SmartImage
              :src="slotProps.row.imageUrl"
              :alt="slotProps.row.name || $t('product_based_costing.product_image_alt')"
              img-class="table-image"
              fallback-class="table-image-placeholder"
            />
            <q-badge
              v-if="slotProps.row.offerInputsIncomplete"
              color="warning"
              text-color="grey-9"
              class="offer-incomplete-badge q-mt-xs"
            >
              {{ $t('product_based_costing.missing_price_weight') }}
            </q-badge>
          </q-td>

          <q-td key="name" :props="slotProps" class="col-name">
            <div class="name-cell-content">
              <span
                class="name-cell-text text-primary cursor-pointer"
                @click="onEdit(slotProps.row)"
              >{{ slotProps.row.name }}</span>
              <q-badge
                v-if="slotProps.row.raw.assigned_shipment_id || slotProps.row.status === 'on_shipment'"
                color="teal-8"
                text-color="white"
                class="q-px-xs text-caption q-mt-xs"
              >
                <q-icon name="ph ph-truck" class="q-mr-xs" />
                {{ $t('product_based_costing.added_to_shipment') }}
              </q-badge>
            </div>
          </q-td>

          <q-td v-if="isColumnVisible('brand')" key="brand" :props="slotProps" class="col-brand">
            {{ slotProps.row.brand || '-' }}
          </q-td>

          <q-td
            v-if="isColumnVisible('note')"
            key="note"
            :props="slotProps"
            class="col-note editable-cell"
          >
            <q-input
              v-model="slotProps.row.noteHtml"
              type="textarea"
              autogrow
              dense
              borderless
              class="cell-input"
              input-class="text-caption"
              :placeholder="$t('product_based_costing.note')"
              @blur="onNoteBlur(slotProps.row)"
            />
          </q-td>

          <q-td
            v-if="isColumnVisible('qty')"
            key="qty"
            :props="slotProps"
            class="col-qty text-center editable-cell"
          >
            <q-input
              v-model.number="slotProps.row.qty"
              type="number"
              dense
              borderless
              input-class="text-center bw-tabular"
              class="cell-input"
              min="0"
              step="1"
              @blur="onQtyBlur(slotProps.row)"
              @keyup.enter="blurInput"
            />
          </q-td>

          <q-td
            v-if="isColumnVisible('confirmedQty')"
            key="confirmedQty"
            :props="slotProps"
            class="col-confirmed-qty text-center editable-cell"
            :class="{ 'qty-col--focus': focusConfirmedQty }"
          >
            <q-input
              v-model.number="slotProps.row.confirmedQty"
              type="number"
              dense
              borderless
              input-class="text-center bw-tabular"
              class="cell-input"
              :class="{ 'cell-input--review': focusConfirmedQty }"
              min="0"
              step="1"
              @blur="onConfirmedQtyBlur(slotProps.row)"
              @keyup.enter="blurInput"
            />
          </q-td>

          <q-td
            v-if="isColumnVisible('barcodeText')"
            key="barcodeText"
            :props="slotProps"
            class="col-barcode"
          >
            <div class="barcode-lines text-caption">
              <div class="row items-center no-wrap">
                <span class="text-weight-bold">{{ $t('product_based_costing.barcode') }}:</span>
                <span class="q-ml-xs bw-tabular">{{ slotProps.row.barcode || '-' }}</span>
                <q-btn
                  v-if="slotProps.row.barcode"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-6"
                  class="q-ml-xs"
                  @click="handleCopy(slotProps.row.barcode, $t('product_based_costing.barcode'))"
                >
                  <q-tooltip>{{ $t('product_based_costing.copy_barcode') }}</q-tooltip>
                </q-btn>
              </div>
              <div class="row items-center no-wrap">
                <span class="text-weight-bold">{{ $t('product_based_costing.code') }}:</span>
                <span class="q-ml-xs bw-tabular">{{ slotProps.row.productCode || '-' }}</span>
                <q-btn
                  v-if="slotProps.row.productCode"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-6"
                  class="q-ml-xs"
                  @click="handleCopy(slotProps.row.productCode, $t('product_based_costing.code'))"
                >
                  <q-tooltip>{{ $t('product_based_costing.copy_code') }}</q-tooltip>
                </q-btn>
              </div>
              <div class="row items-center no-wrap">
                <span class="text-weight-bold">{{ $t('product_based_costing.product_id') }}:</span>
                <span class="q-ml-xs bw-tabular">{{ slotProps.row.productId || '-' }}</span>
                <q-btn
                  v-if="slotProps.row.productId"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-6"
                  class="q-ml-xs"
                  @click="handleCopy(String(slotProps.row.productId), $t('product_based_costing.product_id'))"
                >
                  <q-tooltip>{{ $t('product_based_costing.copy_product_id') }}</q-tooltip>
                </q-btn>
              </div>
            </div>
          </q-td>

          <q-td
            v-if="isColumnVisible('website')"
            key="website"
            :props="slotProps"
            class="col-website"
          >
            <a
              v-if="slotProps.row.website"
              :href="slotProps.row.website"
              target="_blank"
              rel="noopener noreferrer"
            >
              {{ $t('product_based_costing.open') }}
            </a>
            <span v-else>-</span>
          </q-td>

          <q-td
            v-if="isColumnVisible('priceGbp')"
            key="priceGbp"
            :props="slotProps"
            class="col-price-gbp text-right editable-cell"
          >
            <q-input
              v-model.number="slotProps.row.priceGbp"
              type="number"
              dense
              borderless
              input-class="text-right bw-tabular"
              class="cell-input"
              min="0"
              step="0.01"
              @blur="onPriceGbpBlur(slotProps.row)"
              @keyup.enter="blurInput"
            />
          </q-td>

          <q-td
            v-if="isColumnVisible('totalPurchasePriceGbp')"
            key="totalPurchasePriceGbp"
            :props="slotProps"
            class="col-total-purchase-price-gbp text-right"
          >
            {{ formatNumber(getTotalPurchasePriceGbp(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('productWeight')"
            key="productWeight"
            :props="slotProps"
            class="col-product-weight text-right editable-cell"
          >
            <q-input
              v-model.number="slotProps.row.productWeight"
              type="number"
              dense
              borderless
              input-class="text-right bw-tabular"
              class="cell-input"
              min="0"
              step="1"
              @focus="clearZeroOnFocus(slotProps.row, 'productWeight')"
              @blur="onProductWeightBlur(slotProps.row)"
              @keyup.enter="blurInput"
            />
          </q-td>

          <q-td
            v-if="isColumnVisible('packageWeight')"
            key="packageWeight"
            :props="slotProps"
            class="col-package-weight text-right editable-cell"
          >
            <q-input
              v-model.number="slotProps.row.packageWeight"
              type="number"
              dense
              borderless
              input-class="text-right bw-tabular"
              class="cell-input"
              min="0"
              step="1"
              @focus="clearZeroOnFocus(slotProps.row, 'packageWeight')"
              @blur="onPackageWeightBlur(slotProps.row)"
              @keyup.enter="blurInput"
            />
          </q-td>

          <q-td
            v-if="isColumnVisible('totalWeight')"
            key="totalWeight"
            :props="slotProps"
            class="col-total-weight text-right"
          >
            {{ formatNumber(getTotalWeight(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('cargoRate')"
            key="cargoRate"
            :props="slotProps"
            class="col-cargo-rate text-right"
          >
            {{ formatNumber(slotProps.row.cargoRate) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('cargoCostGbp')"
            key="cargoCostGbp"
            :props="slotProps"
            class="col-cargo-cost-gbp text-right"
          >
            {{ formatNumber(getCargoCostGbp(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('totalCostGbp')"
            key="totalCostGbp"
            :props="slotProps"
            class="col-total-cost-gbp text-right"
          >
            {{ formatNumber(getTotalCostGbp(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('rowTotalCostGbp')"
            key="rowTotalCostGbp"
            :props="slotProps"
            class="col-row-total-cost-gbp text-right"
          >
            {{ formatNumber(getRowTotalCostGbp(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('costBdt')"
            key="costBdt"
            :props="slotProps"
            class="col-cost-bdt text-right"
          >
            {{ formatNumber(getCostBdt(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('totalCostBdt')"
            key="totalCostBdt"
            :props="slotProps"
            class="col-total-cost-bdt text-right"
          >
            {{ formatNumber(getTotalCostBdt(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('offerPriceBdt')"
            key="offerPriceBdt"
            :props="slotProps"
            class="col-offer-price-bdt text-right editable-cell"
          >
            <div class="row items-center justify-end no-wrap q-gutter-x-xs">
              <q-icon
                v-if="slotProps.row.isOfferPriceManual"
                name="ph ph-lock-key"
                color="amber-8"
                size="16px"
              >
                <q-tooltip>{{ $t('product_based_costing.offer_locked_tooltip') }}</q-tooltip>
              </q-icon>
              <q-input
                v-model.number="slotProps.row.offerPriceBdt"
                type="number"
                dense
                borderless
                input-class="text-right bw-tabular"
                class="cell-input col"
                min="0"
                step="1"
                @blur="onOfferPriceBlur(slotProps.row)"
                @keyup.enter="blurInput"
              />
              <q-btn
                v-if="slotProps.row.isOfferPriceManual"
                flat
                round
                dense
                size="xs"
                icon="ph ph-arrows-clockwise"
                color="grey-7"
                :aria-label="$t('product_based_costing.unlock_offer_price')"
                @click.stop="onUnlockOfferPrice(slotProps.row)"
              >
                <q-tooltip>{{ $t('product_based_costing.unlock_offer_price_tooltip') }}</q-tooltip>
              </q-btn>
            </div>
          </q-td>

          <q-td
            v-if="isColumnVisible('totalBdt')"
            key="totalBdt"
            :props="slotProps"
            class="col-total-bdt text-right"
          >
            {{ formatNumber(getTotalBdt(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('profitPerUnitBdt')"
            key="profitPerUnitBdt"
            :props="slotProps"
            class="col-profit-per-unit-bdt text-right"
          >
            {{ formatNumber(getProfitPerUnit(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('profitBdt')"
            key="profitBdt"
            :props="slotProps"
            class="col-profit-bdt text-right"
          >
            {{ formatNumber(getProfitBdt(slotProps.row)) }}
          </q-td>

          <q-td
            v-if="isColumnVisible('profitRate')"
            key="profitRate"
            :props="slotProps"
            class="col-profit-rate text-right"
          >
            {{ formatNumber(getProfitRate(slotProps.row)) }}%
          </q-td>

          <q-td
            v-if="isColumnVisible('status')"
            key="status"
            :props="slotProps"
            class="col-status text-center"
          >
            <q-badge :color="getStatusColor(slotProps.row.status)" outline>
              {{ slotProps.row.status }}
              <q-tooltip
                v-if="getItemStatusHint(slotProps.row.status)"
                class="pbc-status-tooltip"
                max-width="280px"
                anchor="top middle"
                self="bottom middle"
                :offset="[0, 8]"
              >
                <div class="pbc-status-tooltip__k">{{ $t('product_based_costing.tooltip_use_when') }}</div>
                <div class="pbc-status-tooltip__v">
                  {{ getItemStatusHint(slotProps.row.status)?.when }}
                </div>
                <div class="pbc-status-tooltip__k pbc-status-tooltip__k--next">
                  {{ $t('product_based_costing.tooltip_this_will') }}
                </div>
                <div class="pbc-status-tooltip__v">
                  {{ getItemStatusHint(slotProps.row.status)?.does }}
                </div>
              </q-tooltip>
            </q-badge>
          </q-td>
        </q-tr>
      </template>

      <template #no-data>
        <div class="full-width row flex-center q-pa-md text-grey-7">
          {{ $t('product_based_costing.no_products_yet_add_above') }}
        </div>
      </template>
    </q-table>

    <q-dialog v-model="showBulkDeleteConfirm" persistent>
      <q-card style="min-width: 360px; max-width: 92vw">
        <q-card-section class="text-h6">{{ $t('product_based_costing.delete_selected_items') }}</q-card-section>
        <q-card-section>
          {{ $t('product_based_costing.confirm_delete_selected_items', { count: selectedRowIds.length }) }}
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat :label="$t('product_based_costing.cancel')" @click="showBulkDeleteConfirm = false" />
          <q-btn color="negative" :label="$t('product_based_costing.delete')" @click="onConfirmBulkDelete" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuasar, copyToClipboard, type QTableColumn } from 'quasar';
import { useI18n } from 'vue-i18n';
import SmartImage from 'src/components/SmartImage.vue';
import {
  calculateOfferPriceBdt,
  getUnitCostBdt as calculateUnitCostBdt,
  getUnitTotalCostGbp as calculateUnitTotalCostGbp,
  normalizeOfferPriceBdt,
  toNumberSafe,
} from '../utils/pricing';
import { getItemStatusHint, normalizePbcFileStatus } from '../composables/useProductBasedCostingFileDetailsState';

interface ProductBasedCostingItem {
  id: number;
  product_based_costing_file_id: number | null;
  product_id?: number | null;
  name: string | null;
  image_url: string | null;
  note: string | null;
  quantity: number | null;
  confirmed_quantity?: number | null;
  barcode: string | null;
  product_code: string | null;
  brand?: string | null;
  web_link: string | null;
  price_gbp: number | null;
  product_weight: number | null;
  package_weight: number | null;
  offer_price: number | null;
  is_offer_price_manual?: boolean | null;
  status: string | null;
  assigned_shipment_id?: number | null;
  created_at: string;
  updated_at: string;
}

interface ProductBasedCostingTableRow {
  id: number;
  sl: number;
  name: string;
  brand: string;
  noteHtml: string;
  imageUrl: string | null;
  qty: number;
  confirmedQty: number;
  barcode: string;
  productCode: string;
  productId: string;
  website: string | null;
  priceGbp: number;
  productWeight: number;
  packageWeight: number;
  cargoRate: number;
  conversionRate: number;
  profitRate: number;
  offerPriceBdt: number;
  isOfferPriceManual: boolean;
  offerInputsIncomplete: boolean;
  status: string;
  raw: ProductBasedCostingItem;
}

const props = withDefaults(
  defineProps<{
    items: ProductBasedCostingItem[];
    cargoRate?: number;
    conversionRate?: number;
    profitRate?: number;
    status?: string | undefined;
    shippedItemIds?: number[];
    visibleColumns?: string[];
  }>(),
  {
    cargoRate: 0,
    conversionRate: 0,
    profitRate: 0,
    status: 'pending',
    shippedItemIds: () => [],
  },
);

const normalizedFileStatus = computed(() => normalizePbcFileStatus(props.status ?? 'pending'));

const focusConfirmedQty = computed(() => normalizedFileStatus.value === 'confirmed');

const emit = defineEmits<{
  (e: 'edit', item: ProductBasedCostingItem): void;
  (e: 'delete', item: ProductBasedCostingItem): void;
  (
    e: 'row-change',
    payload: {
      item: ProductBasedCostingItem;
      row: ProductBasedCostingTableRow;
      field:
        | 'quantity'
        | 'offer_price'
        | 'status'
        | 'note'
        | 'confirmed_quantity'
        | 'product_weight'
        | 'package_weight'
        | 'price_gbp';
    },
  ): void;
  (
    e: 'product-weight-change',
    payload: {
      item: ProductBasedCostingItem;
      row: ProductBasedCostingTableRow;
      field: 'product_weight';
    },
  ): void;
  (
    e: 'package-weight-change',
    payload: {
      item: ProductBasedCostingItem;
      row: ProductBasedCostingTableRow;
      field: 'package_weight';
    },
  ): void;
  (e: 'bulk-delete', ids: number[]): void;
  (e: 'reorder', itemsOrder: { id: number; sort_order: number }[]): void;
  (e: 'update:visible-columns', columns: string[]): void;
}>();

const $q = useQuasar();
const { t } = useI18n();

const handleCopy = (text: string, label: string) => {
  copyToClipboard(text)
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

const toNumber = (value: unknown) => toNumberSafe(value);

const toText = (value: unknown, fallback = '-') => {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : fallback;
};

const htmlToPlainText = (html: string): string => {
  if (!html) return '';
  const el = document.createElement('div');
  el.innerHTML = html;
  return (el.textContent ?? '').replace(/\s+/g, ' ').trim();
};

const formatNumber = (value: number | null | undefined) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return '-';
  }

  return Number(value).toFixed(2);
};

const getUnitWeight = (productWeight: number, packageWeight: number) =>
  productWeight + packageWeight;

const getUnitCargoCostGbp = (productWeight: number, packageWeight: number, cargoRate: number) =>
  (getUnitWeight(productWeight, packageWeight) / 1000) * cargoRate;

const getUnitTotalCostGbp = (
  priceGbp: number,
  productWeight: number,
  packageWeight: number,
  cargoRate: number,
) =>
  calculateUnitTotalCostGbp({
    priceGbp,
    productWeight,
    packageWeight,
    cargoRate,
  });

const getUnitCostBdt = (
  priceGbp: number,
  productWeight: number,
  packageWeight: number,
  cargoRate: number,
  conversionRate: number,
) =>
  calculateUnitCostBdt({
    priceGbp,
    productWeight,
    packageWeight,
    cargoRate,
    conversionRate,
  });

const deriveItemStatus = (
  currentStatus: string,
  confirmedQty: number,
  assignedShipmentId?: number | null,
): string => {
  if (assignedShipmentId) {
    return 'on_shipment';
  }
  if (confirmedQty === 0) {
    return 'rejected';
  }
  if (confirmedQty > 0 && currentStatus === 'pending') {
    return 'accepted';
  }
  return currentStatus || 'pending';
};

const buildRows = (): ProductBasedCostingTableRow[] => {
  return (props.items ?? []).map((item, index) => {
    const barcode = toText(item.barcode, '');
    const productCode = toText(item.product_code, '');
    const productId = item.product_id != null ? String(item.product_id) : '';
    const qty = toNumber(item.quantity);
    const confirmedQty = item.confirmed_quantity != null ? toNumber(item.confirmed_quantity) : 0;
    const priceGbp = toNumber(item.price_gbp);
    const productWeight = toNumber(item.product_weight);
    const packageWeight = toNumber(item.package_weight);
    const cargoRate = toNumber(props.cargoRate);
    const conversionRate = toNumber(props.conversionRate);
    const profitRate = toNumber(props.profitRate);
    const calculatedOfferPriceBdt = calculateOfferPriceBdt({
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate,
      conversionRate,
      profitRate,
    });

    return {
      id: item.id,
      sl: index + 1,
      name: toText(item.name),
      brand: toText(item.brand, ''),
      noteHtml: htmlToPlainText(item.note ?? ''),
      imageUrl: item.image_url ?? null,
      qty,
      confirmedQty,
      barcode,
      productCode,
      productId,
      website: item.web_link ?? null,
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate,
      conversionRate,
      profitRate,
      isOfferPriceManual:
        item.is_offer_price_manual === true ||
        (item.is_offer_price_manual == null &&
          item.offer_price != null &&
          normalizeOfferPriceBdt(item.offer_price) !== calculatedOfferPriceBdt),
      offerInputsIncomplete: priceGbp <= 0 || productWeight <= 0,
      offerPriceBdt:
        (item.is_offer_price_manual === true ||
          (item.is_offer_price_manual == null &&
            item.offer_price != null &&
            normalizeOfferPriceBdt(item.offer_price) !== calculatedOfferPriceBdt)) &&
        item.offer_price != null
          ? normalizeOfferPriceBdt(item.offer_price)
          : calculatedOfferPriceBdt,
      status: deriveItemStatus(
        item.status ?? 'pending',
        confirmedQty,
        item.assigned_shipment_id ?? null,
      ),
      raw: { ...item },
    };
  });
};

const tableRows = ref<ProductBasedCostingTableRow[]>([]);
const statusFilter = ref<'all' | 'active'>('active');

const displayRows = computed(() => {
  if (normalizedFileStatus.value === 'ready_for_shipment') {
    if (statusFilter.value === 'all') {
      return tableRows.value;
    }
    return tableRows.value.filter(
      (row) => row.status !== 'rejected' && row.status !== 'unavailable',
    );
  }
  if (normalizedFileStatus.value === 'procuring') {
    if (statusFilter.value === 'all') {
      return tableRows.value;
    }
    return tableRows.value.filter((row) => row.status !== 'rejected');
  }
  return tableRows.value;
});

const selectedRowIds = ref<number[]>([]);
const showBulkDeleteConfirm = ref(false);

const isAllSelected = computed({
  get: () => {
    if (displayRows.value.length === 0) return false;
    return displayRows.value.every((row) => selectedRowIds.value.includes(row.id));
  },
  set: (val: boolean) => {
    if (val) {
      selectedRowIds.value = displayRows.value.map((row) => row.id);
    } else {
      selectedRowIds.value = [];
    }
  },
});

watch(
  () => [props.items, props.cargoRate, props.conversionRate, props.profitRate, props.status],
  () => {
    tableRows.value = buildRows();
    const allowedIds = new Set(tableRows.value.map((row) => row.id));
    selectedRowIds.value = selectedRowIds.value.filter((id) => allowedIds.has(id));
  },
  { immediate: true, deep: true },
);

const resetRows = () => {
  tableRows.value = buildRows();
};

defineExpose({
  resetRows,
});

const columns = computed<QTableColumn[]>(() => [
  {
    name: 'select',
    label: '',
    field: 'select',
    align: 'center',
    style: 'width: 42px; min-width: 42px; max-width: 42px; text-align: center;',
  },
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'right',
    style: 'width: 58px; min-width: 58px; max-width: 58px; text-align: right;',
  },
  {
    name: 'image',
    label: t('product_based_costing.table_image'),
    field: 'imageUrl',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'name',
    label: t('product_based_costing.col_name'),
    field: 'name',
    align: 'left',
    classes: 'col-name-wrap',
    headerClasses: 'col-name-wrap',
    style: 'text-align: center;',
  },
  {
    name: 'brand',
    label: t('product_based_costing.table_col_brand'),
    field: 'brand',
    align: 'left',
    style: 'text-align: left;',
  },
  {
    name: 'note',
    label: t('product_based_costing.note'),
    field: 'noteHtml',
    align: 'left',
    style: 'text-align: left;',
  },
  {
    name: 'qty',
    label: t('product_based_costing.table_col_qty'),
    field: 'qty',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'confirmedQty',
    label: t('product_based_costing.table_col_confirmedQty'),
    field: 'confirmedQty',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'barcodeText',
    label: t('product_based_costing.table_col_barcodeText'),
    field: 'barcodeText',
    align: 'left',
    style: 'text-align: center;',
  },
  {
    name: 'website',
    label: t('product_based_costing.table_col_website'),
    field: 'website',
    align: 'left',
    style: 'text-align: center;',
  },

  {
    name: 'priceGbp',
    label: t('product_based_costing.table_col_priceGbp'),
    field: 'priceGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'totalPurchasePriceGbp',
    label: t('product_based_costing.table_col_totalPurchasePriceGbp'),
    field: 'totalPurchasePriceGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'productWeight',
    label: t('product_based_costing.table_col_productWeight'),
    field: 'productWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'packageWeight',
    label: t('product_based_costing.table_col_packageWeight'),
    field: 'packageWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'totalWeight',
    label: t('product_based_costing.table_col_totalWeight'),
    field: 'totalWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'cargoRate',
    label: t('product_based_costing.table_col_cargoRate'),
    field: 'cargoRate',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'cargoCostGbp',
    label: t('product_based_costing.table_col_cargoCostGbp'),
    field: 'cargoCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'totalCostGbp',
    label: t('product_based_costing.table_col_totalCostGbp'),
    field: 'totalCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'rowTotalCostGbp',
    label: t('product_based_costing.table_col_rowTotalCostGbp'),
    field: 'rowTotalCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },

  {
    name: 'costBdt',
    label: t('product_based_costing.table_col_costBdt'),
    field: 'costBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'totalCostBdt',
    label: t('product_based_costing.table_col_totalCostBdt'),
    field: 'totalCostBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'offerPriceBdt',
    label: t('product_based_costing.table_col_offerPriceBdt'),
    field: 'offerPriceBdt',
    align: 'center',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: center;',
  },
  {
    name: 'totalBdt',
    label: t('product_based_costing.table_col_totalBdt'),
    field: 'totalBdt',
    align: 'center',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: center;',
  },
  {
    name: 'profitPerUnitBdt',
    label: t('product_based_costing.table_col_profitPerUnitBdt'),
    field: 'profitPerUnitBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'profitBdt',
    label: t('product_based_costing.table_col_profitBdt'),
    field: 'profitBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },

  {
    name: 'profitRate',
    label: t('product_based_costing.table_col_profitRate'),
    field: 'profitRate',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'status',
    label: t('product_based_costing.col_status'),
    field: 'status',
    align: 'center',
    style: 'text-align： center;',
  },
]);

type ColumnName = string;
const allColumnNames = computed<ColumnName[]>(() =>
  columns.value.map((column) => String(column.name)),
);
const internalVisibleColumns = ref<ColumnName[]>([]);
const resolvedVisibleColumns = computed<ColumnName[]>({
  get: () => props.visibleColumns ?? internalVisibleColumns.value,
  set: (next) => {
    if (props.visibleColumns !== undefined) {
      emit('update:visible-columns', next);
      return;
    }
    internalVisibleColumns.value = next;
  },
});
const isColumnVisible = (columnName: string) => resolvedVisibleColumns.value.includes(columnName);

watch(
  allColumnNames,
  (names) => {
    if (props.visibleColumns !== undefined) {
      const allowed = new Set(names);
      const next = props.visibleColumns.filter((name) => allowed.has(name));
      if (next.length !== props.visibleColumns.length) {
        resolvedVisibleColumns.value = next;
      }
      return;
    }

    if (!internalVisibleColumns.value.length) {
      internalVisibleColumns.value = [...names];
      return;
    }

    const allowed = new Set(names);
    const next = internalVisibleColumns.value.filter((name) => allowed.has(name));
    names.forEach((name) => {
      if (!next.includes(name)) {
        next.push(name);
      }
    });
    internalVisibleColumns.value = next;
  },
  { immediate: true },
);

const getTotalPurchasePriceGbp = (row: ProductBasedCostingTableRow) => {
  return row.priceGbp * row.qty;
};

const getTotalWeight = (row: ProductBasedCostingTableRow) => {
  return getUnitWeight(row.productWeight, row.packageWeight);
};

const getCargoCostGbp = (row: ProductBasedCostingTableRow) => {
  return getUnitCargoCostGbp(row.productWeight, row.packageWeight, row.cargoRate);
};

const getTotalCostGbp = (row: ProductBasedCostingTableRow) => {
  return getUnitTotalCostGbp(row.priceGbp, row.productWeight, row.packageWeight, row.cargoRate);
};

const getRowTotalCostGbp = (row: ProductBasedCostingTableRow) => {
  return getTotalCostGbp(row) * row.qty;
};

const getCostBdt = (row: ProductBasedCostingTableRow) => {
  return getUnitCostBdt(
    row.priceGbp,
    row.productWeight,
    row.packageWeight,
    row.cargoRate,
    row.conversionRate,
  );
};

const getTotalCostBdt = (row: ProductBasedCostingTableRow) => {
  return getCostBdt(row) * row.qty;
};

const getTotalBdt = (row: ProductBasedCostingTableRow) => {
  return row.offerPriceBdt * row.qty;
};

const getProfitPerUnit = (row: ProductBasedCostingTableRow) => {
  return row.offerPriceBdt - getCostBdt(row);
};

const getProfitBdt = (row: ProductBasedCostingTableRow) => {
  return getProfitPerUnit(row) * row.qty;
};

const getProfitRate = (row: ProductBasedCostingTableRow) => {
  const costBdt = getCostBdt(row);

  if (costBdt <= 0) return 0;

  return (getProfitPerUnit(row) / costBdt) * 100;
};



const emitRowChange = (
  row: ProductBasedCostingTableRow,
  field: 'quantity' | 'confirmed_quantity' | 'offer_price' | 'status' | 'note' | 'price_gbp',
) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    confirmed_quantity: row.confirmedQty,
    price_gbp: row.priceGbp,
    offer_price: row.isOfferPriceManual ? row.offerPriceBdt : null,
    is_offer_price_manual: row.isOfferPriceManual,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
    note: row.noteHtml,
  };

  row.raw = updatedItem;

  emit('row-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field,
  });
};

const emitProductWeightChange = (row: ProductBasedCostingTableRow) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    confirmed_quantity: row.confirmedQty,
    offer_price: row.offerPriceBdt,
    is_offer_price_manual: row.isOfferPriceManual,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
  };

  row.raw = updatedItem;

  emit('product-weight-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field: 'product_weight',
  });
};

const emitPackageWeightChange = (row: ProductBasedCostingTableRow) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    confirmed_quantity: row.confirmedQty,
    offer_price: row.offerPriceBdt,
    is_offer_price_manual: row.isOfferPriceManual,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
  };

  row.raw = updatedItem;

  emit('package-weight-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field: 'package_weight',
  });
};

const onQtySave = (row: ProductBasedCostingTableRow) => {
  row.qty = toNumber(row.qty);
  emitRowChange(row, 'quantity');
};

const onQtyBlur = (row: ProductBasedCostingTableRow) => {
  row.qty = Math.max(0, toNumber(row.qty));
  if (valuesEqual(row.qty, row.raw.quantity)) return;
  onQtySave(row);
};

const onConfirmedQtySave = (row: ProductBasedCostingTableRow) => {
  row.confirmedQty = Math.max(0, toNumber(row.confirmedQty));
  row.status = deriveItemStatus(
    row.status,
    row.confirmedQty,
    row.raw.assigned_shipment_id ?? null,
  );
  emitRowChange(row, 'confirmed_quantity');
};

const onConfirmedQtyBlur = (row: ProductBasedCostingTableRow) => {
  row.confirmedQty = Math.max(0, toNumber(row.confirmedQty));
  if (valuesEqual(row.confirmedQty, row.raw.confirmed_quantity)) return;
  onConfirmedQtySave(row);
};

const onOfferPriceBdtSave = (row: ProductBasedCostingTableRow) => {
  row.offerPriceBdt = normalizeOfferPriceBdt(row.offerPriceBdt);
  row.isOfferPriceManual = true;
  emitRowChange(row, 'offer_price');
};

const onOfferPriceBlur = (row: ProductBasedCostingTableRow) => {
  const next = normalizeOfferPriceBdt(row.offerPriceBdt);
  row.offerPriceBdt = next;
  const autoPrice = calculateOfferPriceBdt({
    priceGbp: row.priceGbp,
    productWeight: row.productWeight,
    packageWeight: row.packageWeight,
    cargoRate: row.cargoRate,
    conversionRate: row.conversionRate,
    profitRate: row.profitRate,
  });
  const prev = row.isOfferPriceManual
    ? normalizeOfferPriceBdt(row.raw.offer_price)
    : autoPrice;
  if (next === prev) return;
  onOfferPriceBdtSave(row);
};

const onUnlockOfferPrice = (row: ProductBasedCostingTableRow) => {
  row.isOfferPriceManual = false;
  const prodWt = toNumber(row.productWeight);
  const pkgWt = toNumber(row.packageWeight);
  const cargoRate = toNumber(props.cargoRate);
  const conversionRate = toNumber(props.conversionRate);
  const profitRate = toNumber(props.profitRate);

  row.offerPriceBdt = calculateOfferPriceBdt({
    priceGbp: toNumber(row.priceGbp),
    productWeight: prodWt,
    packageWeight: pkgWt,
    cargoRate,
    conversionRate,
    profitRate,
  });

  emitRowChange(row, 'offer_price');
};

const onNoteSave = (row: ProductBasedCostingTableRow) => {
  row.noteHtml = toText(row.noteHtml, '');
  emitRowChange(row, 'note');
};

const onNoteBlur = (row: ProductBasedCostingTableRow) => {
  const next = toText(htmlToPlainText(row.noteHtml), '');
  row.noteHtml = next;
  const prev = htmlToPlainText(row.raw.note ?? '');
  if (next === prev) return;
  onNoteSave(row);
};

const blurInput = (event: KeyboardEvent) => {
  (event.target as HTMLInputElement | null)?.blur();
};

const valuesEqual = (a: unknown, b: unknown) => toNumber(a) === toNumber(b);

const clearZeroOnFocus = (
  row: ProductBasedCostingTableRow,
  field: 'productWeight' | 'packageWeight',
) => {
  if (toNumber(row[field]) !== 0) return;
  row[field] = '' as unknown as number;
};

const applyOfferFromInputs = (row: ProductBasedCostingTableRow) => {
  if (row.isOfferPriceManual) return;
  row.offerPriceBdt = calculateOfferPriceBdt({
    priceGbp: row.priceGbp,
    productWeight: row.productWeight,
    packageWeight: row.packageWeight,
    cargoRate: row.cargoRate,
    conversionRate: row.conversionRate,
    profitRate: row.profitRate,
  });
};

const onPriceGbpBlur = (row: ProductBasedCostingTableRow) => {
  row.priceGbp = Math.max(0, toNumber(row.priceGbp));
  if (valuesEqual(row.priceGbp, row.raw.price_gbp)) return;
  applyOfferFromInputs(row);
  emitRowChange(row, 'price_gbp');
};

const onProductWeightBlur = (row: ProductBasedCostingTableRow) => {
  row.productWeight = Math.max(0, toNumber(row.productWeight));
  if (valuesEqual(row.productWeight, row.raw.product_weight)) return;
  onProductWeightSave(row);
};

const onPackageWeightBlur = (row: ProductBasedCostingTableRow) => {
  row.packageWeight = Math.max(0, toNumber(row.packageWeight));
  if (valuesEqual(row.packageWeight, row.raw.package_weight)) return;
  onPackageWeightSave(row);
};

const onProductWeightSave = (row: ProductBasedCostingTableRow) => {
  row.productWeight = toNumber(row.productWeight);
  row.offerPriceBdt = calculateOfferPriceBdt({
    priceGbp: row.priceGbp,
    productWeight: row.productWeight,
    packageWeight: row.packageWeight,
    cargoRate: row.cargoRate,
    conversionRate: row.conversionRate,
    profitRate: row.profitRate,
  });
  emitProductWeightChange(row);
};

const onPackageWeightSave = (row: ProductBasedCostingTableRow) => {
  row.packageWeight = toNumber(row.packageWeight);
  row.offerPriceBdt = calculateOfferPriceBdt({
    priceGbp: row.priceGbp,
    productWeight: row.productWeight,
    packageWeight: row.packageWeight,
    cargoRate: row.cargoRate,
    conversionRate: row.conversionRate,
    profitRate: row.profitRate,
  });
  emitPackageWeightChange(row);
};

const onEdit = (row: ProductBasedCostingTableRow) => {
  emit('edit', row.raw);
};

const onEditSelected = () => {
  if (selectedRowIds.value.length !== 1) return;
  const row = displayRows.value.find((item) => item.id === selectedRowIds.value[0]);
  if (row) onEdit(row);
};

const onToggleRowSelection = (rowId: number, checked: boolean) => {
  if (checked) {
    if (!selectedRowIds.value.includes(rowId)) {
      selectedRowIds.value.push(rowId);
    }
    return;
  }
  selectedRowIds.value = selectedRowIds.value.filter((id) => id !== rowId);
};

const onConfirmBulkDelete = () => {
  if (!selectedRowIds.value.length) {
    showBulkDeleteConfirm.value = false;
    return;
  }

  emit('bulk-delete', [...selectedRowIds.value]);
  selectedRowIds.value = [];
  showBulkDeleteConfirm.value = false;
};

const moveItem = (index: number, direction: 'up' | 'down') => {
  const targetIndex = direction === 'up' ? index - 1 : index + 1;
  if (targetIndex < 0 || targetIndex >= displayRows.value.length) return;

  const currentItem = displayRows.value[index];
  const targetItem = displayRows.value[targetIndex];
  if (!currentItem || !targetItem) return;

  // Build new items list from current displayRows
  const updatedRows = [...displayRows.value];
  updatedRows[index] = targetItem;
  updatedRows[targetIndex] = currentItem;

  const itemsOrder = updatedRows.map((row, idx) => ({
    id: row.id,
    sort_order: idx * 10,
  }));

  emit('reorder', itemsOrder);
};

const moveItemToPosition = (currentIndex: number, newPosition: string | number | null) => {
  const parsed = Number(newPosition);
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > displayRows.value.length) {
    $q.notify({
      type: 'warning',
      message: `Position must be between 1 and ${displayRows.value.length}.`,
    });
    return;
  }

  const targetIndex = parsed - 1;
  if (currentIndex === targetIndex) return;

  const updatedRows = [...displayRows.value];
  const [removedRow] = updatedRows.splice(currentIndex, 1);
  if (!removedRow) return;

  updatedRows.splice(targetIndex, 0, removedRow);

  const itemsOrder = updatedRows.map((row, idx) => ({
    id: row.id,
    sort_order: idx * 10,
  }));

  emit('reorder', itemsOrder);
};

const getStatusColor = (status: string | null) => {
  switch ((status || '').toLowerCase()) {
    case 'pending':
      return 'warning';
    case 'accepted':
      return 'positive';
    case 'partial':
      return 'info';
    case 'on_shipment':
      return 'teal-8';
    case 'rejected':
      return 'negative';
    case 'unavailable':
      return 'deep-orange';
    default:
      return 'grey';
  }
};

</script>

<style scoped>
.product-based-costing-table {
  width: 100%;
}

.bulk-selection-bar {
  padding: 10px 12px;
  border: 1px solid #f0c9c9;
  border-radius: 10px;
  background: #fff8f8;
}
.costing-q-table {
  max-width: 100%;
  /* height set via Quasar :style — keeps bottom scrollbars in viewport */
  background: var(--bw-theme-base, #eef2f5);
}

.product-based-costing-table :deep(.costing-q-table .q-table__middle) {
  height: 100%;
  max-height: 100% !important;
  overflow: scroll !important;
}

:deep(.q-table) {
  min-width: max-content;
  width: max-content;
}

.product-based-costing-table :deep(.costing-q-table table) {
  table-layout: fixed;
  min-width: max-content;
  width: max-content;
}

.product-based-costing-table :deep(.costing-q-table thead tr th) {
  position: sticky;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
}

.product-based-costing-table :deep(.costing-q-table thead tr:first-child th) {
  top: 0;
  z-index: 1;
}

.product-based-costing-table :deep(.costing-q-table thead tr + tr th) {
  top: 48px;
  z-index: 3;
}

.product-based-costing-table :deep(.costing-q-table td:first-child),
.product-based-costing-table :deep(.costing-q-table th:first-child) {
  position: sticky;
  left: 0;
}

.product-based-costing-table :deep(.costing-q-table td:nth-child(2)),
.product-based-costing-table :deep(.costing-q-table th:nth-child(2)) {
  position: sticky;
  left: 42px;
}

.product-based-costing-table :deep(.costing-q-table td:nth-child(3)),
.product-based-costing-table :deep(.costing-q-table th:nth-child(3)) {
  position: sticky;
  left: 84px;
}

.product-based-costing-table :deep(.costing-q-table td:first-child) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.product-based-costing-table :deep(.costing-q-table td:nth-child(2)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.product-based-costing-table :deep(.costing-q-table td:nth-child(3)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.product-based-costing-table :deep(.costing-q-table tr:first-child th:first-child) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.product-based-costing-table :deep(.costing-q-table tr:first-child th:nth-child(2)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.product-based-costing-table :deep(.costing-q-table tr:first-child th:nth-child(3)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.product-based-costing-table :deep(.costing-q-table tbody) {
  scroll-margin-top: 48px;
}

.product-based-costing-table :deep(tr.row-incomplete-offer td:first-child) {
  box-shadow: inset 3px 0 0 var(--q-warning);
}

.costing-item-card.row-incomplete-offer {
  border-color: color-mix(in srgb, var(--q-warning) 60%, var(--bw-theme-border, #e2e8f0));
}

.table-image {
  width: 96px;
  height: 96px;
  display: block;
  margin: 0 auto;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fff;
  overflow: hidden;
}

.table-image :deep(.smart-image__img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  object-position: center;
}

:deep(.q-table__container),
:deep(.q-table__middle),
:deep(.q-table__middle table),
:deep(.q-table__bottom) {
  background: var(--bw-theme-base, #eef2f5);
}

.table-image-placeholder {
  width: 96px;
  height: 96px;
  margin: 0 auto;
  border: 1px dashed #bbb;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  color: #777;
  background: #fafafa;
}

.editable-cell {
  cursor: text;
}

.editable-cell :deep(.q-field__control) {
  min-height: 28px;
  height: 28px;
  padding: 0 4px;
}

.editable-cell :deep(.q-field__native) {
  padding: 0;
}

.cell-input :deep(.q-field__control) {
  border: 1px solid transparent;
  border-radius: 6px;
  min-height: 28px;
  height: 28px;
}

.cell-input.q-field--focused :deep(.q-field__control),
.cell-input:focus-within :deep(.q-field__control) {
  border-color: var(--q-primary);
  box-shadow: 0 0 0 2px color-mix(in srgb, var(--q-primary) 28%, transparent);
}

.cell-input--review :deep(.q-field__control) {
  border-color: var(--q-primary);
  border-style: dashed;
}

.cell-input :deep(input[type='number']::-webkit-outer-spin-button),
.cell-input :deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

.cell-input :deep(input[type='number']) {
  -moz-appearance: textfield;
}

.editable-value {
  min-height: 24px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.col-select {
  min-width: 42px;
  width: 42px;
  max-width: 42px;
}

.col-sl {
  min-width: 42px;
  width: 42px;
  max-width: 42px;
  background: #f8f9fa;
}

.col-image {
  min-width: 130px;
  width: 130px;
  max-width: 130px;
  background: #fcfcfc;
}

.col-name {
  min-width: 200px;
  width: 200px;
  max-width: 200px;
  background: #ffffff;
}

.name-cell-content {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
  width: 100%;
}

.offer-incomplete-badge {
  display: inline-block;
  max-width: 100%;
  white-space: normal;
  line-height: 1.2;
  font-size: 10px;
  padding: 2px 6px;
}

.name-cell-text {
  flex: 1;
  min-width: 0;
  white-space: normal;
  word-break: break-word;
  line-height: 1.3;
}

.name-cell-ship-btn {
  width: 36px;
  min-width: 36px;
  display: flex;
  justify-content: center;
}

.col-brand {
  min-width: 150px;
  width: 150px;
  max-width: 150px;
  background: #ffffff;
}

.col-note {
  min-width: 260px;
  width: 260px;
  max-width: 260px;
  background: #fcfcfc;
  overflow: hidden;
  vertical-align: top;
}

.col-qty {
  min-width: 100px;
  width: 100px;
  max-width: 100px;
  background: #f8f9fa;
}

.col-confirmed-qty,
.col-ordered-qty {
  min-width: 128px;
  width: 128px;
  max-width: 128px;
}

.qty-col--focus {
  background: #f8f9fa;
}

.confirmed-qty-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  line-height: 1.2;
  white-space: normal;
}

.col-delivered-qty {
  min-width: 120px;
  width: 120px;
  max-width: 120px;
  background: #f8f9fa;
}

.col-barcode {
  min-width: 240px;
  width: 240px;
  max-width: 240px;
  background: #ffffff;
}

.col-website {
  min-width: 120px;
  width: 120px;
  max-width: 120px;
  background: #f8f9fa;
}

.col-price-gbp {
  min-width: 110px;
  width: 110px;
  max-width: 110px;
  background: #ffffff;
}

.col-total-purchase-price-gbp {
  min-width: 150px;
  width: 150px;
  max-width: 150px;
  background: #ffffff;
}

.col-product-weight {
  min-width: 120px;
  width: 120px;
  max-width: 120px;
  background: #f8f9fa;
}

.col-package-weight {
  min-width: 130px;
  width: 130px;
  max-width: 130px;
  background: #ffffff;
}

.col-total-weight {
  min-width: 120px;
  width: 120px;
  max-width: 120px;
  background: #f8f9fa;
}

.col-cargo-rate {
  min-width: 100px;
  width: 100px;
  max-width: 100px;
  background: #ffffff;
}

.col-cargo-cost-gbp {
  min-width: 130px;
  width: 130px;
  max-width: 130px;
  background: #f8f9fa;
}

.col-total-cost-gbp {
  min-width: 130px;
  width: 130px;
  max-width: 130px;
  background: #ffffff;
}

.col-row-total-cost-gbp {
  min-width: 150px;
  width: 150px;
  max-width: 150px;
  background: #f8f9fa;
}

.col-cost-bdt {
  min-width: 110px;
  width: 110px;
  max-width: 110px;
  background: #f8f9fa;
}

.col-total-cost-bdt {
  min-width: 130px;
  width: 130px;
  max-width: 130px;
  background: #ffffff;
}

.col-offer-price-bdt {
  min-width: 150px;
  width: 150px;
  max-width: 150px;
  background: #f8f9fa;
}

.col-total-bdt {
  min-width: 110px;
  width: 110px;
  max-width: 110px;
  background: #ffffff;
}

.col-profit-per-unit-bdt {
  min-width: 130px;
  width: 130px;
  max-width: 130px;
  background: #f8f9fa;
}

.col-profit-bdt {
  min-width: 110px;
  width: 110px;
  max-width: 110px;
  background: #f8f9fa;
}

.col-profit-rate {
  min-width: 110px;
  width: 110px;
  max-width: 110px;
  background: #ffffff;
}

.col-status {
  min-width: 150px;
  width: 150px;
  max-width: 150px;
  background: #f8f9fa;
}

:deep(.bg-gbp) {
  background-color: #e6f4ea !important;
}

:deep(.bg-bdt) {
  background-color: #fff8e1 !important;
}

:deep(.bg-offer) {
  background-color: #f3e5f5 !important;
}
.col-name-wrap {
  min-width: 150px;
  max-width: 200px;
  white-space: normal; /* allow wrapping */
  word-break: break-word; /* break long words */
  line-height: 1.3;
}

.item-note-preview,
.item-note-empty {
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  overflow: hidden;
  min-height: calc(1.35em * 2);
  max-height: calc(1.35em * 2);
  line-height: 1.35;
  word-break: break-word;
  overflow-wrap: anywhere;
}
/* Card View Styles */
.costing-item-card {
  border-radius: 12px;
  transition: all 0.3s ease;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
}

.costing-item-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.06) !important;
}

.card-header {
  background-color: var(--bw-theme-surface-variant, #fafafa);
  min-height: 48px;
}

.card-image-wrapper {
  width: 100%;
  aspect-ratio: 1;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
}

.card-image {
  width: 100%;
  height: 100%;
  display: block;
  overflow: hidden;
}

.card-image :deep(.smart-image__img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  object-position: center;
}

.card-image-placeholder {
  width: 100%;
  height: 100%;
  background-color: #f0f0f0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #aaa;
  font-size: 11px;
}

.card-item-name {
  font-size: 14px;
  line-height: 1.4;
  color: #2c3e50;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.card-barcode-lines {
  line-height: 1.4;
}

.card-note-section {
  border: 1px dashed rgba(0, 0, 0, 0.1);
  background: var(--bw-theme-surface-variant, #f9f9f9);
}

.card-costing-grid {
  font-size: 13px;
}

.metric-label {
  font-size: 11px;
  color: #7f8c8d;
  margin-bottom: 2px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.metric-value {
  font-size: 14px;
  color: #2c3e50;
}

.bg-gbp-light {
  background-color: color-mix(in srgb, #e6f4ea 35%, var(--bw-theme-surface, #fff));
}

.bg-offer-light {
  background-color: color-mix(in srgb, #f3e5f5 35%, var(--bw-theme-surface, #fff));
}

.bg-bdt-light {
  background-color: color-mix(in srgb, #fff8e1 35%, var(--bw-theme-surface, #fff));
}
</style>

<style>
.pbc-status-tooltip.q-tooltip {
  background: #fff !important;
  color: #334155 !important;
  font-size: 13px;
  line-height: 1.4;
  white-space: normal;
  max-width: 280px;
  padding: 10px 12px;
  border-radius: 10px;
  border: 1px solid #e2e8f0;
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.14);
}

.pbc-status-tooltip__k {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #64748b;
}

.pbc-status-tooltip__k--next {
  margin-top: 8px;
}

.pbc-status-tooltip__v {
  white-space: normal;
  overflow-wrap: anywhere;
}
</style>
