<template>
  <div class="product-based-costing-table">
    <div v-if="selectedRowIds.length" class="bulk-selection-bar row items-center justify-between q-mb-sm">
      <div class="text-body2 text-weight-medium">
        {{ selectedRowIds.length }} item(s) selected
      </div>
      <div class="row items-center q-gutter-sm">
        <q-btn
          flat
          no-caps
          color="grey-8"
          label="Clear Selection"
          @click="selectedRowIds = []"
        />
        <q-btn
          color="negative"
          no-caps
          icon="o_delete"
          label="Delete Selected"
          @click="showBulkDeleteConfirm = true"
        />
      </div>
    </div>

    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="columns"
      :visible-columns="resolvedVisibleColumns"
      row-key="id"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      :table-style="{ maxHeight: '100%' }"
      class="costing-q-table"
      :grid="$q.screen.xs"
    >
      <template #item="slotProps">
        <div class="col-12 col-sm-6 q-pa-xs q-sm-pa-sm">
          <q-card flat bordered class="costing-item-card floating-surface shadow-1">
            <!-- Card Header -->
            <div class="card-header row items-center justify-between q-px-md q-py-sm">
              <div class="row items-center q-gutter-xs">
                <q-checkbox
                  :model-value="selectedRowIds.includes(slotProps.row.id)"
                  @update:model-value="(checked) => onToggleRowSelection(slotProps.row.id, checked)"
                  dense
                />
                <q-badge color="grey-3" text-color="grey-9" class="text-weight-bold">
                  #{{ slotProps.row.sl }}
                </q-badge>
              </div>

              <div class="row items-center q-gutter-xs">
                <!-- Status -->
                <div v-if="isColumnVisible('status')" class="cursor-pointer text-center relative-position">
                  <q-badge :color="getStatusColor(slotProps.row.status)" outline class="q-px-sm q-py-xs">
                    {{ slotProps.row.status }}
                    <q-icon name="arrow_drop_down" size="xs" />
                  </q-badge>
                  <q-popup-edit
                    v-slot="scope"
                    :model-value="slotProps.row.status"
                    buttons
                    persistent
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="
                      (value) => {
                        slotProps.row.status = toText(value, 'pending').toLowerCase();
                        onStatusSave(slotProps.row);
                      }
                    "
                  >
                    <q-select
                      v-model="scope.value"
                      :options="statusOptions"
                      dense
                      outlined
                      options-dense
                      emit-value
                      map-options
                      autofocus
                    />
                  </q-popup-edit>
                </div>

                <!-- Actions -->
                <q-btn
                  v-if="isColumnVisible('action')"
                  icon="o_edit"
                  flat
                  round
                  dense
                  color="blue-10"
                  size="sm"
                  @click="onEdit(slotProps.row)"
                />
                <q-btn
                  v-if="isColumnVisible('action')"
                  icon="o_delete"
                  flat
                  round
                  dense
                  color="negative"
                  size="sm"
                  @click="onDelete(slotProps.row)"
                />
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
                      :alt="slotProps.row.name || 'Product image'"
                      img-class="card-image"
                      fallback-class="card-image-placeholder"
                    />
                  </div>
                </div>

                <!-- Info -->
                <div class="col-8 col-sm-9">
                  <div class="row items-start justify-between no-wrap q-gutter-xs">
                    <span class="card-item-name text-weight-bold">{{ slotProps.row.name }}</span>
                    <div v-if="props.status === 'processing'" class="card-ship-btn">
                      <q-btn
                        icon="local_shipping"
                        :color="isShipped(slotProps.row.raw) ? 'negative' : 'primary'"
                        flat
                        round
                        dense
                        size="sm"
                        @click="onShip(slotProps.row)"
                      >
                        <q-tooltip>{{ isShipped(slotProps.row.raw) ? 'Added in shipment' : 'Add Shipment' }}</q-tooltip>
                      </q-btn>
                    </div>
                  </div>

                  <div v-if="isColumnVisible('brand') && slotProps.row.brand" class="text-caption text-grey-8 q-mt-xs">
                    <strong>Brand:</strong> {{ slotProps.row.brand }}
                  </div>

                  <div v-if="isColumnVisible('barcodeText')" class="card-barcode-lines text-caption text-grey-7 q-mt-xs">
                    <div v-if="slotProps.row.barcode">Barcode: {{ slotProps.row.barcode }}</div>
                    <div v-if="slotProps.row.productCode">Code: {{ slotProps.row.productCode }}</div>
                    <div v-if="slotProps.row.productId">ID: {{ slotProps.row.productId }}</div>
                  </div>

                  <div v-if="isColumnVisible('website') && slotProps.row.website" class="q-mt-xs">
                    <q-btn
                      flat
                      dense
                      no-caps
                      color="primary"
                      icon="open_in_new"
                      label="Website"
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
              <div v-if="isColumnVisible('note')" class="card-note-section q-mt-md q-pa-sm rounded-borders cursor-pointer bg-grey-1 text-caption">
                <div class="text-weight-bold text-grey-7 q-mb-xs">Note:</div>
                <div
                  v-if="slotProps.row.noteHtml"
                  class="item-note-html"
                  v-html="slotProps.row.noteHtml"
                />
                <span v-else class="text-grey-5">No notes. Tap to add one.</span>

                <q-popup-edit
                  v-slot="scope"
                  :model-value="slotProps.row.noteHtml"
                  cover
                  :content-style="{ minWidth: '300px', maxWidth: '90vw' }"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="
                    (value) => {
                      slotProps.row.noteHtml = toText(value, '');
                      onNoteSave(slotProps.row);
                    }
                  "
                >
                  <q-editor
                    v-model="scope.value"
                    dense
                    flat
                    square
                    min-height="100px"
                    :toolbar="[
                      ['bold', 'italic', 'underline'],
                      ['removeFormat'],
                      ['unordered', 'ordered'],
                      ['undo', 'redo'],
                    ]"
                    autofocus
                  />
                </q-popup-edit>
              </div>
            </q-card-section>

            <q-separator />

            <!-- Costing Grid -->
            <q-card-section class="q-pa-md bg-grey-0">
              <div class="row q-col-gutter-sm card-costing-grid">
                <!-- Qty -->
                <div v-if="isColumnVisible('qty')" class="col-6 col-sm-3 cursor-pointer text-center">
                  <div class="metric-label">Qty</div>
                  <div class="metric-value font-mono font-weight-medium">
                    {{ slotProps.row.qty }}
                    <q-icon name="edit" size="xs" color="grey-6" class="q-ml-xs" />
                  </div>
                  <q-popup-edit
                    v-slot="scope"
                    :model-value="slotProps.row.qty"
                    buttons
                    persistent
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="
                      (value) => {
                        slotProps.row.qty = toNumber(value);
                        onQtySave(slotProps.row);
                      }
                    "
                  >
                    <q-input
                      v-model.number="scope.value"
                      type="number"
                      dense
                      outlined
                      autofocus
                      min="0"
                    />
                  </q-popup-edit>
                </div>

                <!-- Delivered Qty -->
                <div v-if="isColumnVisible('deliveredQty')" class="col-6 col-sm-3 cursor-pointer text-center">
                  <div class="metric-label">Delivered Qty</div>
                  <div class="metric-value font-mono font-weight-medium">
                    {{ slotProps.row.deliveredQty }}
                    <q-icon name="edit" size="xs" color="grey-6" class="q-ml-xs" />
                  </div>
                  <q-popup-edit
                    v-slot="scope"
                    :model-value="slotProps.row.deliveredQty"
                    buttons
                    persistent
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="
                      (value) => {
                        slotProps.row.deliveredQty = toNumber(value);
                        onDeliveredQtySave(slotProps.row);
                      }
                    "
                  >
                    <q-input
                      v-model.number="scope.value"
                      type="number"
                      dense
                      outlined
                      autofocus
                      min="0"
                    />
                  </q-popup-edit>
                </div>

                <!-- Price GBP -->
                <div v-if="isColumnVisible('priceGbp')" class="col-6 col-sm-3 text-center bg-gbp-light q-pa-xs rounded-borders">
                  <div class="metric-label text-green-9">Price GBP</div>
                  <div class="metric-value text-green-10 text-weight-bold font-mono">
                    £{{ formatNumber(slotProps.row.priceGbp) }}
                  </div>
                </div>

                <!-- Offer Price BDT -->
                <div v-if="isColumnVisible('offerPriceBdt')" class="col-6 col-sm-3 cursor-pointer text-center bg-offer-light q-pa-xs rounded-borders">
                  <div class="metric-label text-purple-9">Offer Price BDT</div>
                  <div class="metric-value text-purple-10 text-weight-bold font-mono">
                    ৳{{ formatNumber(slotProps.row.offerPriceBdt) }}
                    <q-icon name="edit" size="xs" color="purple-6" class="q-ml-xs" />
                  </div>
                  <q-popup-edit
                    v-slot="scope"
                    :model-value="slotProps.row.offerPriceBdt"
                    buttons
                    persistent
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="
                      (value) => {
                        slotProps.row.offerPriceBdt = toNumber(value);
                        onOfferPriceBdtSave(slotProps.row);
                      }
                    "
                  >
                    <q-input
                      v-model.number="scope.value"
                      type="number"
                      dense
                      outlined
                      autofocus
                      min="0"
                    />
                  </q-popup-edit>
                </div>

                <!-- Cost BDT -->
                <div v-if="isColumnVisible('costBdt')" class="col-6 col-sm-3 text-center bg-bdt-light q-pa-xs rounded-borders">
                  <div class="metric-label text-amber-9">Cost BDT</div>
                  <div class="metric-value text-amber-10 font-mono text-weight-medium">
                    ৳{{ formatNumber(getCostBdt(slotProps.row)) }}
                  </div>
                </div>

                <!-- Total Cost BDT -->
                <div v-if="isColumnVisible('totalCostBdt')" class="col-6 col-sm-3 text-center bg-bdt-light q-pa-xs rounded-borders">
                  <div class="metric-label text-amber-9">Total Cost BDT</div>
                  <div class="metric-value text-amber-10 font-mono text-weight-medium">
                    ৳{{ formatNumber(getTotalCostBdt(slotProps.row)) }}
                  </div>
                </div>

                <!-- Profit BDT -->
                <div v-if="isColumnVisible('profitBdt')" class="col-6 col-sm-3 text-center">
                  <div class="metric-label">Profit BDT</div>
                  <div class="metric-value font-mono">
                    ৳{{ formatNumber(getProfitBdt(slotProps.row)) }}
                  </div>
                </div>

                <!-- Profit Rate -->
                <div v-if="isColumnVisible('profitRate')" class="col-6 col-sm-3 text-center">
                  <div class="metric-label">Profit Rate</div>
                  <div class="metric-value font-mono">
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

      <template #body="slotProps">
        <q-tr :props="slotProps">
          <q-td key="select" :props="slotProps" class="col-select text-center">
            <q-checkbox
              :model-value="selectedRowIds.includes(slotProps.row.id)"
              @update:model-value="(checked) => onToggleRowSelection(slotProps.row.id, checked)"
              dense
            />
          </q-td>
          <q-td key="sl" :props="slotProps" class="col-sl text-center">
            {{ slotProps.row.sl }}
          </q-td>

          <q-td key="image" :props="slotProps" class="col-image text-center">
            <SmartImage
              :src="slotProps.row.imageUrl"
              :alt="slotProps.row.name || 'Product image'"
              img-class="table-image"
              fallback-class="table-image-placeholder"
            />
          </q-td>

          <q-td key="name" :props="slotProps" class="col-name">
            <div class="name-cell-content">
              <span class="name-cell-text">{{ slotProps.row.name }}</span>
              <div class="name-cell-ship-btn">
                <q-btn
                  v-if="props.status === 'processing'"
                  icon="local_shipping"
                  :color="isShipped(slotProps.row.raw) ? 'negative' : 'primary'"
                  flat
                  round
                  dense
                  size="md"
                  @click="onShip(slotProps.row)"
                >
                  <q-tooltip>{{ isShipped(slotProps.row.raw) ? 'Added in shipment' : 'Add Shipment' }}</q-tooltip>
                </q-btn>
              </div>
            </div>
          </q-td>

          <q-td v-if="isColumnVisible('brand')" key="brand" :props="slotProps" class="col-brand">
            {{ slotProps.row.brand || '-' }}
          </q-td>

          <q-td v-if="isColumnVisible('note')" key="note" :props="slotProps" class="col-note editable-cell">
            <div
              v-if="slotProps.row.noteHtml"
              class="item-note-html"
              v-html="slotProps.row.noteHtml"
            />
            <span v-else>-</span>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.noteHtml"
              cover
              :content-style="{ minWidth: '320px', maxWidth: '520px' }"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.noteHtml = toText(value, '');
                  onNoteSave(slotProps.row);
                }
              "
            >
              <q-editor
                v-model="scope.value"
                dense
                flat
                square
                min-height="120px"
                :toolbar="[
                  ['bold', 'italic', 'underline'],
                  ['removeFormat'],
                  ['unordered', 'ordered'],
                  ['undo', 'redo'],
                ]"
                autofocus
              />
            </q-popup-edit>
          </q-td>

          <q-td v-if="isColumnVisible('qty')" key="qty" :props="slotProps" class="col-qty text-center editable-cell">
            <div class="editable-value">
              {{ slotProps.row.qty }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.qty"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.qty = toNumber(value);
                  onQtySave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td v-if="isColumnVisible('deliveredQty')" key="deliveredQty" :props="slotProps" class="col-delivered-qty text-center editable-cell">
            <div class="editable-value">
              {{ slotProps.row.deliveredQty }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.deliveredQty"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.deliveredQty = toNumber(value);
                  onDeliveredQtySave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td v-if="isColumnVisible('barcodeText')" key="barcodeText" :props="slotProps" class="col-barcode">
            <div class="barcode-lines">
              <div><strong>Barcode:</strong> {{ slotProps.row.barcode || '-' }}</div>
              <div><strong>Code:</strong> {{ slotProps.row.productCode || '-' }}</div>
              <div><strong>Product ID:</strong> {{ slotProps.row.productId || '-' }}</div>
            </div>
          </q-td>

          <q-td v-if="isColumnVisible('website')" key="website" :props="slotProps" class="col-website">
            <a
              v-if="slotProps.row.website"
              :href="slotProps.row.website"
              target="_blank"
              rel="noopener noreferrer"
            >
              Open
            </a>
            <span v-else>-</span>
          </q-td>

          <q-td v-if="isColumnVisible('priceGbp')" key="priceGbp" :props="slotProps" class="col-price-gbp text-right">
            {{ formatNumber(slotProps.row.priceGbp) }}
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
            <div class="editable-value">
              {{ formatNumber(slotProps.row.productWeight) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.productWeight"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.productWeight = toNumber(value);
                  onProductWeightSave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td
            v-if="isColumnVisible('packageWeight')"
            key="packageWeight"
            :props="slotProps"
            class="col-package-weight text-right editable-cell"
          >
            <div class="editable-value">
              {{ formatNumber(slotProps.row.packageWeight) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.packageWeight"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.packageWeight = toNumber(value);
                  onPackageWeightSave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td
            v-if="isColumnVisible('totalWeight')"
            key="totalWeight"
            :props="slotProps"
            class="col-total-weight text-right"
          >
            {{ formatNumber(getTotalWeight(slotProps.row)) }}
          </q-td>

          <q-td v-if="isColumnVisible('cargoRate')" key="cargoRate" :props="slotProps" class="col-cargo-rate text-right">
            {{ formatNumber(slotProps.row.cargoRate) }}
          </q-td>

          <q-td v-if="isColumnVisible('cargoCostGbp')" key="cargoCostGbp" :props="slotProps" class="col-cargo-cost-gbp text-right">
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

          <q-td v-if="isColumnVisible('costBdt')" key="costBdt" :props="slotProps" class="col-cost-bdt text-right">
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
            <div class="editable-value">
              {{ formatNumber(slotProps.row.offerPriceBdt) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.offerPriceBdt"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.offerPriceBdt = toNumber(value);
                  onOfferPriceBdtSave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td
            v-if="isColumnVisible('totalBdt')"
            key="totalBdt"
            :props="slotProps"
            class="col-total-bdt text-right"
          >
            {{ formatNumber(getTotalBdt(slotProps.row)) }}
          </q-td>

          <q-td v-if="isColumnVisible('profitPerUnitBdt')" key="profitPerUnitBdt" :props="slotProps" class="col-profit-per-unit-bdt text-right">
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

          <q-td v-if="isColumnVisible('profitRate')" key="profitRate" :props="slotProps" class="col-profit-rate text-right">
            {{ formatNumber(getProfitRate(slotProps.row)) }}
          </q-td>

          <q-td v-if="isColumnVisible('status')" key="status" :props="slotProps" class="col-status text-center editable-cell">
            <q-badge :color="getStatusColor(slotProps.row.status)" outline>
              {{ slotProps.row.status }}
            </q-badge>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.status"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.status = toText(value, 'pending').toLowerCase();
                  onStatusSave(slotProps.row);
                }
              "
            >
              <q-select
                v-model="scope.value"
                :options="statusOptions"
                dense
                outlined
                options-dense
                emit-value
                map-options
                autofocus
              />
            </q-popup-edit>
          </q-td>

          <q-td v-if="isColumnVisible('action')" key="action" :props="slotProps" class="col-action">
            <div class="row items-center justify-center q-gutter-xs">
              <q-btn
                icon="o_edit"
                flat
                round
                dense
                color="blue-10"
                @click="onEdit(slotProps.row)"
                class="col"
              />
              <q-btn
                icon="o_delete"
                flat
                round
                dense
                color="negative"
                @click="onDelete(slotProps.row)"
                class="col"
              />
            </div>
          </q-td>
        </q-tr>
      </template>

      <template #bottom-row>
        <q-tr class="totals-row">
          <q-td v-if="isColumnVisible('select')" class="totals-row__cell col-select" />
          <q-td v-if="isColumnVisible('sl')" class="totals-row__cell col-sl text-center">
            Total
          </q-td>
          <q-td v-if="isColumnVisible('image')" class="totals-row__cell col-image" />
          <q-td v-if="isColumnVisible('name')" class="totals-row__cell col-name">
            {{ tableRows.length }} Items
          </q-td>
          <q-td v-if="isColumnVisible('brand')" class="totals-row__cell col-brand" />
          <q-td v-if="isColumnVisible('note')" class="totals-row__cell col-note" />
          <q-td v-if="isColumnVisible('qty')" class="totals-row__cell col-qty text-center">
            {{ formatNumber(totals.qty) }}
          </q-td>
          <q-td v-if="isColumnVisible('deliveredQty')" class="totals-row__cell col-delivered-qty text-center">
            {{ formatNumber(totals.deliveredQty) }}
          </q-td>
          <q-td v-if="isColumnVisible('barcodeText')" class="totals-row__cell col-barcode" />
          <q-td v-if="isColumnVisible('website')" class="totals-row__cell col-website" />
          <q-td v-if="isColumnVisible('priceGbp')" class="totals-row__cell col-price-gbp text-right">
            <div class="totals-row__value bg-gbp">
              {{ formatNumber(totals.priceGbp) }}
            </div>
          </q-td>
          <q-td v-if="isColumnVisible('totalPurchasePriceGbp')" class="totals-row__cell col-total-purchase-price-gbp text-right">
            <div class="totals-row__value bg-gbp">
              {{ formatNumber(totals.totalPurchasePriceGbp) }}
            </div>
          </q-td>
          <q-td
            v-if="isColumnVisible('productWeight')"
            class="totals-row__cell col-product-weight text-right"
          >
            {{ formatNumber(totals.productWeight) }}
          </q-td>
          <q-td
            v-if="isColumnVisible('packageWeight')"
            class="totals-row__cell col-package-weight text-right"
          >
            {{ formatNumber(totals.packageWeight) }}
          </q-td>
          <q-td v-if="isColumnVisible('totalWeight')" class="totals-row__cell col-total-weight text-right">
            {{ formatNumber(totals.totalWeight) }}
          </q-td>
          <q-td v-if="isColumnVisible('cargoRate')" class="totals-row__cell col-cargo-rate text-right">
            {{ formatNumber(totals.cargoRate) }}
          </q-td>
          <q-td
            v-if="isColumnVisible('cargoCostGbp')"
            class="totals-row__cell col-cargo-cost-gbp text-right"
          >
            <div class="totals-row__value bg-gbp">
              {{ formatNumber(totals.cargoCostGbp) }}
            </div>
          </q-td>
          <q-td v-if="isColumnVisible('totalCostGbp')" class="totals-row__cell col-total-cost-gbp text-right">
            <div class="totals-row__value bg-gbp">
              {{ formatNumber(totals.totalCostGbp) }}
            </div>
          </q-td>
          <q-td
            v-if="isColumnVisible('rowTotalCostGbp')"
            class="totals-row__cell col-row-total-cost-gbp text-right"
          >
            <div class="totals-row__value bg-gbp">
              {{ formatNumber(totals.rowTotalCostGbp) }}
            </div>
          </q-td>
          <q-td v-if="isColumnVisible('costBdt')" class="totals-row__cell col-cost-bdt text-right">
            <div class="totals-row__value bg-bdt">
              {{ formatNumber(totals.costBdt) }}
            </div>
          </q-td>
          <q-td v-if="isColumnVisible('totalCostBdt')" class="totals-row__cell col-total-cost-bdt text-right">
            <div class="totals-row__value bg-bdt">
              {{ formatNumber(totals.totalCostBdt) }}
            </div>
          </q-td>
          <q-td
            v-if="isColumnVisible('offerPriceBdt')"
            class="totals-row__cell col-offer-price-bdt text-right"
          >
            <div class="totals-row__value bg-offer">
              {{ formatNumber(totals.offerPriceBdt) }}
            </div>
          </q-td>
          <q-td v-if="isColumnVisible('totalBdt')" class="totals-row__cell col-total-bdt text-right">
            <div class="totals-row__value bg-offer">
              {{ formatNumber(totals.totalBdt) }}
            </div>
          </q-td>
          <q-td
            v-if="isColumnVisible('profitPerUnitBdt')"
            class="totals-row__cell col-profit-per-unit-bdt text-right"
          >
            <div class="totals-row__value bg-bdt">
              {{ formatNumber(totals.profitPerUnitBdt) }}
            </div>
          </q-td>
          <q-td v-if="isColumnVisible('profitBdt')" class="totals-row__cell col-profit-bdt text-right">
            <div class="totals-row__value bg-bdt">
              {{ formatNumber(totals.profitBdt) }}
            </div>
          </q-td>
          <q-td v-if="isColumnVisible('profitRate')" class="totals-row__cell col-profit-rate text-right">
            {{ formatNumber(totals.averageProfitRate) }}
          </q-td>
          <q-td v-if="isColumnVisible('status')" class="totals-row__cell col-status" />
          <q-td v-if="isColumnVisible('action')" class="totals-row__cell col-action" />
        </q-tr>
      </template>

      <template #no-data>
        <div class="full-width row flex-center q-pa-md text-grey-7">No items found</div>
      </template>
    </q-table>

    <q-dialog v-model="showBulkDeleteConfirm" persistent>
      <q-card style="min-width: 360px; max-width: 92vw">
        <q-card-section class="text-h6">Delete Selected Items</q-card-section>
        <q-card-section>
          Are you sure you want to delete {{ selectedRowIds.length }} selected item(s)?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="showBulkDeleteConfirm = false" />
          <q-btn color="negative" label="Delete" @click="onConfirmBulkDelete" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuasar, type QTableColumn } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import {
  calculateOfferPriceBdt,
  getUnitCostBdt as calculateUnitCostBdt,
  getUnitTotalCostGbp as calculateUnitTotalCostGbp,
  normalizeOfferPriceBdt,
  toNumberSafe,
} from '../utils/pricing';

interface ProductBasedCostingItem {
  id: number;
  product_based_costing_file_id: number | null;
  product_id?: number | null;
  name: string | null;
  image_url: string | null;
  note: string | null;
  quantity: number | null;
  delivered_quantity: number | null;
  barcode: string | null;
  product_code: string | null;
  brand?: string | null;
  web_link: string | null;
  price_gbp: number | null;
  product_weight: number | null;
  package_weight: number | null;
  offer_price: number | null;
  status: string | null;
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
  deliveredQty: number;
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

const emit = defineEmits<{
  (e: 'edit', item: ProductBasedCostingItem): void;
  (e: 'delete', item: ProductBasedCostingItem): void;
  (e: 'ship', item: ProductBasedCostingItem): void;
  (
    e: 'row-change',
    payload: {
      item: ProductBasedCostingItem;
      row: ProductBasedCostingTableRow;
      field: 'quantity' | 'offer_price' | 'status' | 'note' | 'delivered_quantity';
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
  (e: 'update:visible-columns', columns: string[]): void;
}>();

const $q = useQuasar();

const statusOptions = [
  { label: 'Pending', value: 'pending' },
  { label: 'Accepted', value: 'accepted' },
  { label: 'Rejected', value: 'rejected' },
];

const toNumber = (value: unknown) => toNumberSafe(value);

const toText = (value: unknown, fallback = '-') => {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : fallback;
};

const formatNumber = (value: number | null | undefined) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return '-';
  }

  return Number(value).toFixed(2);
};

const getUnitWeight = (productWeight: number, packageWeight: number) =>
  productWeight + packageWeight;

const getUnitCargoCostGbp = (
  productWeight: number,
  packageWeight: number,
  cargoRate: number,
) => (getUnitWeight(productWeight, packageWeight) / 1000) * cargoRate;

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

const buildRows = (): ProductBasedCostingTableRow[] => {
  return (props.items ?? []).map((item, index) => {
    const barcode = toText(item.barcode, '');
    const productCode = toText(item.product_code, '');
    const productId = item.product_id != null ? String(item.product_id) : '';
    const qty = toNumber(item.quantity);
    const deliveredQty = toNumber(item.delivered_quantity);
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
      noteHtml: item.note ?? '',
      imageUrl: item.image_url ?? null,
      qty,
      deliveredQty,
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
      offerPriceBdt:
        item.offer_price == null ? calculatedOfferPriceBdt : normalizeOfferPriceBdt(item.offer_price),
      status: toText(item.status, 'pending').toLowerCase(),
      raw: { ...item },
    };
  });
};

const tableRows = ref<ProductBasedCostingTableRow[]>([]);
const selectedRowIds = ref<number[]>([])
const showBulkDeleteConfirm = ref(false)

const isAllSelected = computed({
  get: () => {
    if (tableRows.value.length === 0) return false;
    return tableRows.value.every((row) => selectedRowIds.value.includes(row.id));
  },
  set: (val: boolean) => {
    if (val) {
      selectedRowIds.value = tableRows.value.map((row) => row.id);
    } else {
      selectedRowIds.value = [];
    }
  },
});

watch(
  () => [props.items, props.cargoRate, props.conversionRate, props.profitRate],
  () => {
    tableRows.value = buildRows();
    const allowedIds = new Set(tableRows.value.map((row) => row.id))
    selectedRowIds.value = selectedRowIds.value.filter((id) => allowedIds.has(id))
  },
  { immediate: true, deep: true },
);

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
    align: 'center',
    style: 'width: 42px; min-width: 42px; max-width: 42px; text-align: center;',
  },
  {
    name: 'image',
    label: 'Image',
    field: 'imageUrl',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left',
    classes: 'col-name-wrap',
    headerClasses: 'col-name-wrap',
    style: 'text-align: center;',
  },
  {
    name: 'brand',
    label: 'Brand',
    field: 'brand',
    align: 'left',
    style: 'text-align: left;',
  },
  {
    name: 'note',
    label: 'Note',
    field: 'noteHtml',
    align: 'left',
    style: 'text-align: left;',
  },
  { name: 'qty', label: 'Qty', field: 'qty', align: 'center', style: 'text-align: center;' },
  {
    name: 'deliveredQty',
    label: 'Delivered Qty',
    field: 'deliveredQty',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'barcodeText',
    label: 'Barcode / Code / Product ID',
    field: 'barcodeText',
    align: 'left',
    style: 'text-align: center;',
  },
  {
    name: 'website',
    label: 'Website',
    field: 'website',
    align: 'left',
    style: 'text-align: center;',
  },

  {
    name: 'priceGbp',
    label: 'Price (GBP)/Unit',
    field: 'priceGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'totalPurchasePriceGbp',
    label: 'Total Purchase Price (GBP)',
    field: 'totalPurchasePriceGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'productWeight',
    label: 'Product Wt (g/Unit)',
    field: 'productWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'packageWeight',
    label: 'Package Wt (g/Unit)',
    field: 'packageWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'totalWeight',
    label: 'Total Wt (g/Unit)',
    field: 'totalWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'cargoRate',
    label: 'Cargo Rate',
    field: 'cargoRate',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'cargoCostGbp',
    label: 'Cargo Cost (GBP/Unit)',
    field: 'cargoCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'totalCostGbp',
    label: 'Total Cost (GBP/Unit)',
    field: 'totalCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'rowTotalCostGbp',
    label: 'Row Total Cost (GBP)',
    field: 'rowTotalCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },

  {
    name: 'costBdt',
    label: 'Cost (BDT/Unit)',
    field: 'costBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'totalCostBdt',
    label: 'Row Total Cost (BDT)',
    field: 'totalCostBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'offerPriceBdt',
    label: 'Offer Price (BDT/Unit)',
    field: 'offerPriceBdt',
    align: 'center',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: center;',
  },
  {
    name: 'totalBdt',
    label: 'Row Offer Total (BDT)',
    field: 'totalBdt',
    align: 'center',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: center;',
  },
  {
    name: 'profitPerUnitBdt',
    label: 'Profit (BDT/Unit)',
    field: 'profitPerUnitBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'profitBdt',
    label: 'Row Total Profit (BDT)',
    field: 'profitBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },

  {
    name: 'profitRate',
    label: 'Profit Rate (%)',
    field: 'profitRate',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'status',
    label: 'Status',
    field: 'status',
    align: 'center',
    style: 'text-align： center;',
  },
  {
    name: 'action',
    label: 'Action',
    field: 'action',
    align: 'center',
    style: 'text-align： center;',
  },
]);

type ColumnName = string
const allColumnNames = computed<ColumnName[]>(() => columns.value.map((column) => String(column.name)))
const internalVisibleColumns = ref<ColumnName[]>([])
const resolvedVisibleColumns = computed<ColumnName[]>({
  get: () => props.visibleColumns ?? internalVisibleColumns.value,
  set: (next) => {
    if (props.visibleColumns !== undefined) {
      emit('update:visible-columns', next)
      return
    }
    internalVisibleColumns.value = next
  },
})
const isColumnVisible = (columnName: string) => resolvedVisibleColumns.value.includes(columnName)

watch(
  allColumnNames,
  (names) => {
    if (!resolvedVisibleColumns.value.length) {
      resolvedVisibleColumns.value = [...names]
      return
    }

    const allowed = new Set(names)
    const next = resolvedVisibleColumns.value.filter((name) => allowed.has(name))
    names.forEach((name) => {
      if (!next.includes(name)) {
        next.push(name)
      }
    })
    resolvedVisibleColumns.value = next
  },
  { immediate: true },
)

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
  return getUnitTotalCostGbp(
    row.priceGbp,
    row.productWeight,
    row.packageWeight,
    row.cargoRate,
  );
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
  field: 'quantity' | 'offer_price' | 'status' | 'note' | 'delivered_quantity',
) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    delivered_quantity: row.deliveredQty,
    offer_price: row.offerPriceBdt,
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
    offer_price: row.offerPriceBdt,
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
    offer_price: row.offerPriceBdt,
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

const onDeliveredQtySave = (row: ProductBasedCostingTableRow) => {
  row.deliveredQty = toNumber(row.deliveredQty);
  emitRowChange(row, 'delivered_quantity');
};

const onOfferPriceBdtSave = (row: ProductBasedCostingTableRow) => {
  row.offerPriceBdt = normalizeOfferPriceBdt(row.offerPriceBdt);
  emitRowChange(row, 'offer_price');
};

const onStatusSave = (row: ProductBasedCostingTableRow) => {
  row.status = toText(row.status, 'pending').toLowerCase();
  emitRowChange(row, 'status');
};

const onNoteSave = (row: ProductBasedCostingTableRow) => {
  row.noteHtml = toText(row.noteHtml, '');
  emitRowChange(row, 'note');
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

const onDelete = (row: ProductBasedCostingTableRow) => {
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete #${row.id} ${row.name || ''}?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    emit('delete', row.raw);
  });
};

const onToggleRowSelection = (rowId: number, checked: boolean) => {
  if (checked) {
    if (!selectedRowIds.value.includes(rowId)) {
      selectedRowIds.value.push(rowId)
    }
    return
  }
  selectedRowIds.value = selectedRowIds.value.filter((id) => id !== rowId)
}

const onConfirmBulkDelete = () => {
  if (!selectedRowIds.value.length) {
    showBulkDeleteConfirm.value = false
    return
  }

  emit('bulk-delete', [...selectedRowIds.value])
  selectedRowIds.value = []
  showBulkDeleteConfirm.value = false
}

const onShip = (row: ProductBasedCostingTableRow) => {
  emit('ship', row.raw);
};

const isShipped = (item: ProductBasedCostingItem) => {
  return props.shippedItemIds.includes(item.id);
};

const getStatusColor = (status: string | null) => {
  switch ((status || '').toLowerCase()) {
    case 'pending':
      return 'warning';
    case 'accepted':
      return 'positive';
    case 'rejected':
      return 'negative';
    default:
      return 'grey';
  }
};

const totals = computed(() => {
  const initial = {
    qty: 0,
    deliveredQty: 0,
    priceGbp: 0,
    totalPurchasePriceGbp: 0,
    productWeight: 0,
    packageWeight: 0,
    totalWeight: 0,
    cargoRate: 0,
    cargoCostGbp: 0,
    totalCostGbp: 0,
    rowTotalCostGbp: 0,
    costBdt: 0,
    totalCostBdt: 0,
    offerPriceBdt: 0,
    totalBdt: 0,
    profitPerUnitBdt: 0,
    profitBdt: 0,
    averageProfitRate: 0,
  };

  const sum = tableRows.value.reduce((acc, row) => {
    acc.qty += row.qty;
    acc.deliveredQty += row.deliveredQty;
    acc.priceGbp += row.priceGbp;
    acc.totalPurchasePriceGbp += getTotalPurchasePriceGbp(row);
    acc.productWeight += row.productWeight;
    acc.packageWeight += row.packageWeight;
    acc.totalWeight += getTotalWeight(row);
    acc.cargoRate += row.cargoRate;
    acc.cargoCostGbp += getCargoCostGbp(row);
    acc.totalCostGbp += getTotalCostGbp(row);
    acc.rowTotalCostGbp += getRowTotalCostGbp(row);
    acc.costBdt += getCostBdt(row);
    acc.totalCostBdt += getTotalCostBdt(row);
    acc.offerPriceBdt += row.offerPriceBdt;
    acc.totalBdt += getTotalBdt(row);
    acc.profitPerUnitBdt += getProfitPerUnit(row);
    acc.profitBdt += getProfitBdt(row);
    return acc;
  }, initial);

  sum.averageProfitRate = sum.totalCostBdt > 0 ? (sum.profitBdt / sum.totalCostBdt) * 100 : 0;

  return sum;
});

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
  height: clamp(400px, calc(100vh - 280px), 82vh);
  background: var(--bw-theme-base, #eef2f5);
}

.product-based-costing-table :deep(.costing-q-table .q-table__middle) {
  height: 100%;
  max-height: 100% !important;
  overflow: auto;
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

.table-image {
  width: 96px;
  height: 96px;
  display: block;
  margin: 0 auto;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fff;
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
  cursor: pointer;
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
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  width: 100%;
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
  text-overflow: ellipsis;
}

.col-qty {
  min-width: 100px;
  width: 100px;
  max-width: 100px;
  background: #f8f9fa;
}

.col-delivered-qty {
  min-width: 120px;
  width: 120px;
  max-width: 120px;
  background: #f8f9fa;
}

.col-barcode {
  min-width: 180px;
  width: 180px;
  max-width: 180px;
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

.col-action {
  min-width: 100px;
  width: 100px;
  max-width: 100px;
  background: #ffffff;
}

.totals-row {
  background: inherit;
}

.totals-row__cell {
  font-weight: 700;
  color: inherit;
  white-space: normal;
  word-break: break-word;
  padding: 0;
  text-align: center;
}

.totals-row__value {
  display: block;
  width: 100%;
  min-height: 100%;
  padding: 8px 16px;
  text-align: center;
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

.item-note-html {
  max-width: 100%;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  word-break: break-word;
  overflow-wrap: anywhere;
  line-height: 1.35;
}

.item-note-html :deep(p),
.item-note-html :deep(ul),
.item-note-html :deep(ol) {
  margin: 0;
  padding-left: 0;
}

.item-note-html :deep(img),
.item-note-html :deep(table),
.item-note-html :deep(pre) {
  max-width: 100%;
  overflow: hidden;
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
  object-fit: contain;
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
