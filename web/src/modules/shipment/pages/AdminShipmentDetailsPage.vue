<template>
  <q-page class="q-pa-md shipment-details-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="row items-center q-gutter-sm">
              <q-badge color="primary" outline class="text-weight-medium">
                #{{ shipmentStore.selectedShipment?.tenant_shipment_id ?? shipmentStore.selectedShipment?.id ?? '-' }}
              </q-badge>
              <div class="text-h6 text-weight-bold">
                {{ shipmentStore.selectedShipment?.name ?? 'Shipment' }}
              </div>
            </div>
          </div>
          <div class="col-auto row items-center q-gutter-sm shipment-action-row">
        <q-chip
          dense
          square
          clickable
          :style="statusChipStyle(selectedStatus)"
          class="shipment-status-chip q-px-md q-py-sm"
        >
          <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(selectedStatus) }" />
          {{ selectedStatus }}
          <q-menu>
            <q-list dense style="min-width: 170px">
              <q-item
                v-for="option in statusOptions"
                :key="option"
                clickable
                v-close-popup
                @click="onStatusMenuSelect(option)"
              >
                <q-item-section>{{ option }}</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-chip>

        <q-btn
          v-if="isDraftStatus"
          color="secondary"
          no-caps
          label="Add New Item"
          @click="openAddProductDialog"
        />
        <q-btn
          v-if="isDraftStatus"
          color="primary"
          no-caps
          label="Search Item"
          @click="openAddItemDialog"
        />
        <q-btn-dropdown
          color="primary"
          outline
          no-caps
          size="sm"
          label="Actions"
          class="pill-btn slim-btn"
          dropdown-icon="expand_more"
        >
          <q-list dense>
            <q-item
              v-if="isInventoryAdded"
              clickable
              v-close-popup
              @click="openReadonlyShipmentInfoDialog"
            >
              <q-item-section avatar>
                <q-icon name="info" />
              </q-item-section>
              <q-item-section>View Conversion Details</q-item-section>
            </q-item>
            <q-item
              v-else
              clickable
              v-close-popup
              @click="openEditableShipmentInfoDialog"
            >
              <q-item-section avatar>
                <q-icon name="info" />
              </q-item-section>
              <q-item-section>Shipment Info</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="goToBatchCodePage">
              <q-item-section avatar>
                <q-icon name="fact_check" />
              </q-item-section>
              <q-item-section>Batch Code</q-item-section>
            </q-item>
            <q-item
              v-if="shipmentStore.shipmentItems.length"
              clickable
              v-close-popup
              @click="downloadShipmentExcel"
            >
              <q-item-section avatar>
                <q-icon name="table_view" />
              </q-item-section>
              <q-item-section>Download Excel</q-item-section>
            </q-item>
            <q-item
              v-if="shipmentStore.shipmentItems.length"
              clickable
              v-close-popup
              :disable="shipmentStore.saving || isInventoryAdded"
              @click="onResetTags"
            >
              <q-item-section avatar>
                <q-icon name="restart_alt" color="warning" />
              </q-item-section>
              <q-item-section>Reset Tags</q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
        <q-btn flat round dense size="sm" icon="view_column" aria-label="Select columns">
          <q-menu>
            <q-list style="min-width: 220px">
              <q-item>
                <q-item-section>
                  <div class="text-subtitle2">Show Columns</div>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-checkbox
                    v-model="allSelectableColumnsSelected"
                    label="Select / Deselect All"
                  />
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-option-group
                    v-model="visibleColumns"
                    type="checkbox"
                    :options="columnSelectorOptionsUi"
                  />
                </q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card
      v-if="shipmentStore.selectedShipment && !initialLoading"
      flat
      class="q-mb-md floating-surface shadow-1"
    >
      <q-card-section class="q-py-sm row q-col-gutter-sm shipment-summary-grid">
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Quantity</div>
          <div class="text-body1 text-weight-bold">{{ totals.quantity }}</div>
        </div>
        <div class="shipment-summary-card" v-if="shipmentStore.selectedShipment?.is_gbp">
          <div class="text-caption text-grey-8">Total Price GBP</div>
          <div class="text-body1 text-weight-bold">{{ formatFixed2(totals.price_gbp) }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Cost BDT</div>
          <div class="text-body1 text-weight-bold">{{ formatFixed2(totals.cost_bdt) }}</div>
        </div>
        <div class="shipment-summary-card" v-if="shipmentStore.selectedShipment?.is_gbp">
          <div class="text-caption text-grey-8">Total Weight</div>
          <div class="text-body1 text-weight-bold">{{ formatFixed2(totals.total_weight_gm / 1000) }} kg</div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Ingestion Progress Bar (Visible in Warehouse Received status) -->
    <q-card
      v-if="canAddToInventory && !initialLoading"
      flat
      bordered
      class="q-mb-md Ingestion-flow-card"
      style="border-color: rgba(0,0,0,0.06); border-radius: 8px; background: #fafafa;"
    >
      <q-card-section class="q-py-md q-px-md">
        <div class="row items-center justify-between no-wrap q-gutter-x-lg">
          <!-- Flow steps -->
          <div class="row items-center q-gutter-x-lg col">
            <!-- Label -->
            <div class="row items-center q-gutter-xs text-grey-8 font-medium">
              <q-icon name="sync_alt" size="18px" class="text-primary text-weight-bold" />
              <span class="text-subtitle2 text-weight-bold text-grey-9">Ingestion Flow</span>
            </div>

            <!-- Pipeline Separator -->
            <div style="width: 1px; height: 32px; background: #e0e0e0;"></div>

            <!-- Step 1: Rate and Weight -->
            <div 
              v-if="shipmentStore.selectedShipment?.is_gbp"
              class="cursor-pointer row items-center q-gutter-xs text-weight-medium transition-colors hover-opacity"
              :class="isAddToInventoryRateInvalid ? 'text-amber-9 text-weight-bold' : 'text-positive'"
              @click="openEditableShipmentInfoDialog"
            >
              <q-icon :name="isAddToInventoryRateInvalid ? 'warning' : 'check_circle'" size="18px" />
              <div class="column">
                <span class="text-weight-bold" style="font-size: 13px;">1. Rates & Weight</span>
                <span class="text-caption text-grey-6" style="margin-top: -2px;">Configure rates & weight</span>
              </div>
              <q-tooltip anchor="top middle" self="bottom middle">Click to configure rates and cargo weight</q-tooltip>
            </div>

            <q-icon v-if="shipmentStore.selectedShipment?.is_gbp" name="chevron_right" color="grey-4" size="18px" />

            <!-- Step 2: Confirm Quantities (with Confirm All Perfect button below it) -->
            <div 
              class="row items-center q-gutter-xs text-weight-medium"
              :class="confirmedItemIds.size < shipmentStore.shipmentItems.length ? 'text-amber-9 text-weight-bold' : 'text-positive'"
            >
              <q-icon :name="confirmedItemIds.size < shipmentStore.shipmentItems.length ? 'pending' : 'check_circle'" size="18px" />
              <div class="column">
                <span class="text-weight-bold" style="font-size: 13px;">2. Confirm Quantities ({{ confirmedItemIds.size }}/{{ shipmentStore.shipmentItems.length }})</span>
                <!-- Button below the text -->
                <div class="q-mt-xs">
                  <q-btn 
                    v-if="confirmedItemIds.size < shipmentStore.shipmentItems.length"
                    size="xs" 
                    color="primary" 
                    unelevated
                    no-caps 
                    label="Confirm All Perfect" 
                    class="q-px-sm text-weight-bold text-caption rounded-borders"
                    style="height: 20px; font-size: 10px; line-height: 1;"
                    @click="confirmAllItemsPerfect" 
                  />
                  <span v-else class="text-caption text-positive text-weight-bold">All Items Inspected</span>
                </div>
              </div>
            </div>

            <q-icon name="chevron_right" color="grey-4" size="18px" />

            <!-- Process Ingestion Button as the final stage of flow -->
            <div>
              <q-btn
                color="positive"
                no-caps
                dense
                unelevated
                label="Process Ingestion"
                :disable="!canIngestWorkflowCommit"
                :loading="shipmentStore.saving"
                @click="showAddToInventoryConfirmDialog = true"
                class="q-px-md text-weight-bold text-body2"
                style="min-height: 36px; border-radius: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);"
              />
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="initialLoading" />

    <q-banner v-else-if="shipmentStore.loading" class="bg-grey-2 text-grey-8 q-mb-md">
      Loading shipment details...
    </q-banner>

    <q-banner v-if="!initialLoading && shipmentStore.error" class="bg-red-1 text-negative q-mb-md">
      {{ shipmentStore.error }}
    </q-banner>

    <q-card v-if="!initialLoading" flat class="floating-surface shadow-1">
      <q-card-section class="q-pa-none shipment-table-scroll-wrap">
        <q-markup-table flat class="shipment-details-table">
          <thead>
            <tr>
              <th class="text-right shipment-sl-col">SL</th>
              <th class="text-left shipment-image-col">Image</th>
              <th v-if="isColumnVisible('name')" class="text-left shipment-name-col">Name</th>
              <th v-if="isColumnVisible('product_id')" class="text-left shipment-product-id-col">Product ID</th>
              <th v-if="isColumnVisible('barcode')" class="text-left shipment-barcode-col">Barcode</th>
              <th v-if="isColumnVisible('product_code')" class="text-left shipment-product-code-col">Product Code</th>
              <th v-if="isColumnVisible('batch_manufacture')" class="text-left shipment-batch-col">Batch / MFG Date</th>
              <th v-if="isColumnVisible('method')" class="text-left shipment-method-col">Method</th>
              <th class="text-left shipment-tag-col">Tag</th>
              <th
                v-if="isColumnVisible('price_gbp')"
                class="text-right shipment-price-col"
              >
                Price GBP
              </th>
              <th
                v-if="isColumnVisible('cost_bdt')"
                class="text-right shipment-cost-col"
              >
                Cost BDT
              </th>
              <th
                v-if="isColumnVisible('quantity')"
                class="text-right shipment-qty-col shipment-qty-col--quantity"
              >
                Quantity
              </th>


              <th v-if="isColumnVisible('product_weight')" class="text-right shipment-product-weight-col">Product Wt</th>
              <th v-if="isColumnVisible('package_weight')" class="text-right shipment-package-weight-col">Package Wt</th>
              <th v-if="isColumnVisible('actions')" class="text-right shipment-actions-col">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, index) in shipmentStore.shipmentItems" :key="item.id">
              <td class="text-right shipment-sl-col">{{ index + 1 }}</td>
              <td class="shipment-image-col">
                <div class="shipment-item-image-box">
                  <SmartImage
                    :src="item.image_url"
                    alt="shipment item"
                    imgClass="shipment-item-image"
                    fallbackClass="shipment-item-image-fallback"
                    :enable-edit="false"
                  />
                </div>
              </td>
              <td
                v-if="isColumnVisible('name')"
                class="shipment-item-name-cell shipment-name-col"
                :class="{ 'cursor-pointer': !isInventoryAdded }"
                @click="!isInventoryAdded && openItemDetailsDialog(item)"
              >
                <div>{{ item.name ?? '-' }}</div>
                <div class="q-mt-xs row q-gutter-xs" v-if="hasItemSplits(item)">
                  <q-badge color="positive" dense v-if="getOrInitItemReceipt(item).standard > 0">
                    Usable (Standard): {{ getOrInitItemReceipt(item).standard }}
                  </q-badge>
                  <q-badge color="orange" dense v-if="getOrInitItemReceipt(item).box_damage > 0">
                    Box Damage: {{ getOrInitItemReceipt(item).box_damage }}
                  </q-badge>
                  <q-badge color="blue" dense v-if="getOrInitItemReceipt(item).boxless > 0">
                    Boxless: {{ getOrInitItemReceipt(item).boxless }}
                  </q-badge>
                  <q-badge color="red" dense v-if="getOrInitItemReceipt(item).expired > 0">
                    Expired / Damaged: {{ getOrInitItemReceipt(item).expired }}
                  </q-badge>
                  <q-badge color="grey-7" dense v-if="getOrInitItemReceipt(item).stolen > 0">
                    Transit Loss: {{ getOrInitItemReceipt(item).stolen }}
                  </q-badge>
                </div>
              </td>
              <td v-if="isColumnVisible('product_id')" class="shipment-product-id-col">{{ item.product_id ?? '-' }}</td>
              <td v-if="isColumnVisible('barcode')" class="shipment-barcode-col">{{ item.barcode ?? '-' }}</td>
              <td v-if="isColumnVisible('product_code')" class="shipment-product-code-col">{{ item.product_code ?? '-' }}</td>
              <td v-if="isColumnVisible('batch_manufacture')" class="shipment-batch-col">
                <div
                  class="shipment-batch-cell"
                  :class="{ 'cursor-pointer': !isInventoryAdded }"
                  @click="!isInventoryAdded && openBatchEditorDialog(item)"
                >
                <template v-if="getBatchManufactureLines(item).length">
                  <div
                    v-for="(line, lineIndex) in getBatchManufactureLines(item)"
                    :key="`${item.id}-batch-line-${lineIndex}`"
                    class="shipment-batch-line"
                  >
                    <span class="shipment-batch-code">{{ line.batchId }}</span>
                    <span class="shipment-batch-date"> / {{ line.manufacturingDate }}</span>
                    <span class="shipment-batch-remaining"> ({{ line.remainingMonthsLabel }})</span>
                  </div>
                </template>
                <span v-else>-</span>
                </div>
              </td>
              <td v-if="isColumnVisible('method')" class="text-uppercase shipment-method-col">{{ item.method ?? '-' }}</td>
              <td class="shipment-tag-col">
                <q-btn-dropdown
                  flat
                  no-caps
                  no-icon-animation
                  class="shipment-tag-dropdown"
                  :disable="isInventoryAdded"
                >
                  <template #label>
                    <q-chip
                      dense
                      square
                      size="sm"
                      :color="getTagChipColor(item.marker_tag)"
                      text-color="white"
                      class="shipment-tag-chip"
                    >
                      {{ getTagLabel(item.marker_tag) }}
                    </q-chip>
                  </template>

                  <q-list dense style="min-width: 160px">
                    <q-item
                      v-for="option in shipmentMarkerTagOptions"
                      :key="String(option.label)"
                      clickable
                      v-close-popup
                      @click="onMarkerTagChange(item, option.value)"
                    >
                      <q-item-section>
                        <q-chip
                          dense
                          square
                          size="sm"
                          :color="getTagChipColor(option.value)"
                          text-color="white"
                          class="shipment-tag-chip"
                        >
                          {{ option.label }}
                        </q-chip>
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-btn-dropdown>
              </td>
              <td v-if="isColumnVisible('price_gbp')" class="text-right shipment-price-col">
                <span :class="{ 'cursor-pointer': !isInventoryAdded }">{{ formatDecimal(item.price_gbp) }}</span>
                <q-popup-edit
                  v-if="!isInventoryAdded"
                  :model-value="item.price_gbp"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'price_gbp', value, { decimals: 2 })"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    @update:model-value="(value) => (scope.value = value === '' ? null : Number(value))"
                    @keyup.enter="scope.set"
                    type="number"
                    step="0.01"
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </td>
              <td v-if="isColumnVisible('cost_bdt')" class="text-right shipment-cost-col">
                <span :class="{ 'cursor-pointer': !isInventoryAdded && !shipmentStore.selectedShipment?.is_gbp }">
                  {{ formatFixed2(calculateItemCostBdt(item)) }}
                </span>
                <q-popup-edit
                  v-if="!isInventoryAdded && !shipmentStore.selectedShipment?.is_gbp"
                  :model-value="item.cost_bdt"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'cost_bdt', value, { decimals: 2 })"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    @update:model-value="(value) => (scope.value = value === '' ? null : Number(value))"
                    @keyup.enter="scope.set"
                    type="number"
                    step="0.01"
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </td>
              <td
                v-if="isColumnVisible('quantity')"
                class="text-right shipment-qty-col shipment-qty-col--quantity"
              >
                <span :class="{ 'cursor-pointer': canEditQuantity && !isInventoryAdded }">{{ item.quantity }}</span>
                <q-popup-edit
                  v-if="canEditQuantity && !isInventoryAdded"
                  :model-value="item.quantity"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'quantity', value)"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    @update:model-value="(value) => (scope.value = value === '' ? null : Number(value))"
                    @keyup.enter="scope.set"
                    type="number"
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </td>


              <td v-if="isColumnVisible('product_weight')" class="text-right shipment-product-weight-col">
                <span :class="{ 'cursor-pointer': !isInventoryAdded }">{{ formatDecimal(item.product_weight) }}</span>
                <q-popup-edit
                  v-if="!isInventoryAdded"
                  :model-value="item.product_weight"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'product_weight', value, { decimals: 3 })"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    @update:model-value="(value) => (scope.value = value === '' ? null : Number(value))"
                    @keyup.enter="scope.set"
                    type="number"
                    step="0.001"
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </td>
              <td v-if="isColumnVisible('package_weight')" class="text-right shipment-package-weight-col">
                <span :class="{ 'cursor-pointer': !isInventoryAdded }">{{ formatDecimal(item.package_weight) }}</span>
                <q-popup-edit
                  v-if="!isInventoryAdded"
                  :model-value="item.package_weight"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'package_weight', value, { decimals: 3 })"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    @update:model-value="(value) => (scope.value = value === '' ? null : Number(value))"
                    @keyup.enter="scope.set"
                    type="number"
                    step="0.001"
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </td>
              <td v-if="isColumnVisible('actions')" class="text-right shipment-actions-col">
                <div class="row items-center justify-end no-wrap q-gutter-xs">
                  <q-checkbox
                    v-if="canAddToInventory"
                    :model-value="confirmedItemIds.has(item.id)"
                    @update:model-value="toggleItemConfirmed(item)"
                    dense
                    color="positive"
                    class="q-mr-xs"
                  >
                    <q-tooltip>{{ confirmedItemIds.has(item.id) ? 'Mark as Unconfirmed' : 'Confirm as Perfect' }}</q-tooltip>
                  </q-checkbox>
                  <q-btn
                    v-if="canAddToInventory"
                    flat
                    dense
                    color="teal"
                    round
                    icon="fact_check"
                    @click="openInspectDialog(item)"
                  >
                    <q-tooltip>Receive & Inspect (Split Batch)</q-tooltip>
                  </q-btn>
                  <q-btn v-if="!isInventoryAdded" flat round dense icon="more_vert">
                    <q-menu auto-close>
                      <q-list style="min-width: 100px">
                        <q-item
                          v-if="item.method === 'manual'"
                          clickable
                          @click="openEditManualItemDialog(item)"
                        >
                          <q-item-section>Edit</q-item-section>
                        </q-item>
                        <q-item clickable class="text-negative" @click="openDeleteDialog(item)">
                          <q-item-section>Delete</q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-btn>
                </div>
              </td>
            </tr>
            <tr v-if="shipmentStore.shipmentItems.length" class="shipment-total-row">
              <td class="shipment-sl-col"></td>
              <td class="shipment-image-col"></td>
              <td v-if="isColumnVisible('name')" class="shipment-name-col"></td>
              <td v-if="isColumnVisible('product_id')"></td>
              <td v-if="isColumnVisible('barcode')"></td>
              <td v-if="isColumnVisible('product_code')"></td>
              <td v-if="isColumnVisible('batch_manufacture')"></td>
              <td v-if="isColumnVisible('method')"></td>
              <td class="shipment-tag-col"></td>
              <td v-if="isColumnVisible('price_gbp')" class="text-right text-weight-bold">
                {{ formatFixed2(totals.price_gbp) }}
              </td>
              <td v-if="isColumnVisible('cost_bdt')" class="text-right text-weight-bold">
                {{ formatFixed2(totals.cost_bdt) }}
              </td>
              <td
                v-if="isColumnVisible('quantity')"
                class="text-right shipment-qty-col shipment-qty-col--quantity text-weight-bold"
              >
                {{ totals.quantity }}
              </td>


              <td v-if="isColumnVisible('product_weight')" class="text-right text-weight-bold">
                {{ formatFixed2(totals.product_weight) }}
              </td>
              <td v-if="isColumnVisible('package_weight')" class="text-right text-weight-bold">
                {{ formatFixed2(totals.package_weight) }}
              </td>
              <td v-if="isColumnVisible('actions')"></td>
            </tr>
            <tr v-if="!shipmentStore.shipmentItems.length">
              <td :colspan="shipmentTableColspan" class="text-center text-grey-6 q-pa-md">
                No shipment items yet
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card-section>
    </q-card>

    <q-dialog v-model="showAddItemDialog">
      <q-card style="min-width: 860px; max-width: 94vw">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6">Search Product</div>
          <q-btn icon="close" flat round dense @click="showAddItemDialog = false" />
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <div class="row no-wrap q-col-gutter-sm items-start">
            <div style="width: 220px; min-width: 220px">
              <q-select
                v-model="productSearchField"
                :options="productSearchFieldOptions"
                label="Search By"
                outlined
                dense
                emit-value
                map-options
                option-value="value"
                option-label="label"
              />
            </div>
            <div style="width: 220px; min-width: 220px">
              <q-select
                v-model="productSearchVendorCode"
                :options="vendorOptions"
                label="Vendor"
                outlined
                dense
                emit-value
                map-options
                option-value="value"
                option-label="label"
                clearable
                @update:model-value="onSearchVendorChange"
              />
            </div>
            <div style="width: 220px; min-width: 220px">
              <q-select
                v-model="productSearchCategory"
                :options="categoryOptions"
                label="Category"
                outlined
                dense
                emit-value
                map-options
                option-value="value"
                option-label="label"
                clearable
              />
            </div>
            <div class="col">
              <q-input
                v-model="productSearch"
                label="Search"
                outlined
                dense
                autofocus
                @keyup.enter="onSearchProducts"
              />
            </div>
          </div>

          <q-markup-table flat bordered wrap-cells>
            <thead>
              <tr>
                <th class="text-left">Image</th>
                <th class="text-left">Name</th>
                <th class="text-left">Barcode</th>
                <th class="text-left">Product Code</th>
                <th class="text-right">Price GBP</th>
                <th class="text-right">Minimum Qty</th>
                <th class="text-right">Qty</th>
                <th class="text-right">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!productStore.items.length && !productStore.loading">
                <td colspan="8" class="text-center text-grey-6">No products found</td>
              </tr>
              <tr v-for="product in productStore.items" :key="product.id">
                <td>
                  <div class="shipment-item-image-box">
                    <SmartImage
                      :src="product.image_url"
                      alt="product image"
                      imgClass="shipment-item-image"
                      fallbackClass="shipment-item-image-fallback"
                    />
                  </div>
                </td>
                <td class="shipment-item-name-cell">{{ product.name ?? '-' }}</td>
                <td>{{ product.barcode ?? '-' }}</td>
                <td>{{ product.product_code ?? '-' }}</td>
                <td class="text-right">{{ formatFixed2(product.price_gbp) }}</td>
                <td class="text-right">{{ product.minimum_order_quantity ?? '-' }}</td>
                <td class="text-right" style="width: 130px">
                  <q-input
                    :model-value="productQuantityById[product.id] ?? 1"
                    type="number"
                    dense
                    outlined
                    min="1"
                    @update:model-value="(value) => onSetProductQuantity(product.id, value)"
                  />
                </td>
                <td class="text-right">
                  <q-btn
                    color="primary"
                    no-caps
                    label="Add"
                    :loading="shipmentStore.saving"
                    @click="onAddProductToShipment(product.id)"
                  />
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Close" @click="showAddItemDialog = false" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="showAddProductDialog" persistent>
      <q-card style="width: 960px; max-width: 95vw;">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">
            Add Product + Add to Shipment
          </div>
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator />

        <q-card-section class="q-pa-md">
          <q-form ref="addProductFormRef" @submit.prevent="onCreateProductAndAddToShipment">
            <div class="row q-col-gutter-lg">
              <!-- Left Column (Image & Identification) -->
              <div class="col-12 col-md-5 q-gutter-y-md">
                <div class="image-preview-container border rounded-borders q-pa-sm bg-grey-1 text-center">
                  <div v-if="addProductForm.image_url" class="image-preview-box">
                    <SmartImage :src="addProductForm.image_url" style="max-height: 200px; max-width: 100%; object-fit: contain; margin: 0 auto;" />
                  </div>
                  <div v-else class="image-preview-placeholder flex flex-center text-grey-6" style="height: 200px;">
                    <div class="column items-center">
                      <q-icon name="image" size="48px" />
                      <div class="text-caption q-mt-sm">No Image Preview</div>
                    </div>
                  </div>
                </div>

                <q-input
                  v-model="addProductForm.image_url"
                  label="Image URL *"
                  outlined
                  dense
                  class="soft-input"
                  hide-bottom-space
                  :rules="[(value: string) => Boolean(value?.trim()) || 'Image URL is required']"
                >
                  <template #prepend>
                    <q-icon name="image" />
                  </template>
                </q-input>

                <q-input
                  v-model="addProductForm.name"
                  label="Name *"
                  type="textarea"
                  autogrow
                  outlined
                  dense
                  class="soft-input"
                  hide-bottom-space
                  :rules="[(value: string) => Boolean(value?.trim()) || 'Name is required']"
                >
                  <template #prepend>
                    <q-icon name="inventory_2" />
                  </template>
                </q-input>

                <q-input
                  v-model="addProductForm.barcode"
                  label="Barcode"
                  outlined
                  dense
                  class="soft-input"
                  hide-bottom-space
                >
                  <template #prepend>
                    <q-icon name="qr_code" />
                  </template>
                </q-input>

                <q-input
                  v-model="addProductForm.product_code"
                  label="Product Code"
                  outlined
                  dense
                  class="soft-input"
                  hide-bottom-space
                >
                  <template #prepend>
                    <q-icon name="badge" />
                  </template>
                </q-input>
              </div>

              <!-- Right Column (Metadata, Parameters & Note) -->
              <div class="col-12 col-md-7 q-gutter-y-md">
                <div class="row q-col-gutter-sm">
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="addProductForm.vendor_code"
                      :options="vendorOptions"
                      emit-value
                      map-options
                      option-value="value"
                      option-label="label"
                      label="Vendor"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                      @update:model-value="onAddProductVendorChange"
                    >
                      <template #prepend>
                        <q-icon name="storefront" />
                      </template>
                    </q-select>
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="addProductForm.market_code"
                      :options="marketOptions"
                      emit-value
                      map-options
                      option-value="value"
                      option-label="label"
                      label="Market"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                      @update:model-value="onAddProductDefaultMarketChange"
                    >
                      <template #prepend>
                        <q-icon name="public" />
                      </template>
                    </q-select>
                  </div>
                </div>

                <div class="row q-col-gutter-sm">
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="addProductForm.category"
                      :options="categoryOptions"
                      emit-value
                      map-options
                      option-value="value"
                      option-label="label"
                      label="Category"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                    >
                      <template #prepend>
                        <q-icon name="category" />
                      </template>
                    </q-select>
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="addProductForm.minimum_order_quantity"
                      label="Minimum Order Quantity"
                      type="number"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                    >
                      <template #prepend>
                        <q-icon name="warehouse" />
                      </template>
                    </q-input>
                  </div>
                </div>

                <div class="row q-col-gutter-sm">
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="addProductForm.quantity"
                      label="Quantity *"
                      type="number"
                      min="1"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                      :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) > 0) || 'Quantity is required']"
                    >
                      <template #prepend>
                        <q-icon name="numbers" />
                      </template>
                    </q-input>
                  </div>
                  <div class="col-12 col-sm-6">
                    <!-- Price fields -->
                    <q-input
                      v-if="shipmentStore.selectedShipment?.is_gbp"
                      v-model.number="addProductForm.price_gbp"
                      label="Price GBP *"
                      type="number"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                      :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) >= 0) || 'Price GBP is required']"
                    >
                      <template #prepend>
                        <q-icon name="currency_pound" />
                      </template>
                    </q-input>
                    <q-input
                      v-else
                      v-model.number="addProductForm.cost_bdt"
                      label="Cost BDT *"
                      type="number"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                      :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) >= 0) || 'Cost BDT is required']"
                    >
                      <template #prepend>
                        <q-icon name="payments" />
                      </template>
                    </q-input>
                  </div>
                </div>

                <!-- Weight fields (GBP only) -->
                <div class="row q-col-gutter-sm" v-if="shipmentStore.selectedShipment?.is_gbp">
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="addProductForm.product_weight"
                      label="Product Weight *"
                      type="number"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                      :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) >= 0) || 'Product Weight is required']"
                    >
                      <template #prepend>
                        <q-icon name="scale" />
                      </template>
                    </q-input>
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="addProductForm.package_weight"
                      label="Package Weight *"
                      type="number"
                      outlined
                      dense
                      class="soft-input"
                      hide-bottom-space
                      :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) >= 0) || 'Package Weight is required']"
                    >
                      <template #prepend>
                        <q-icon name="fitness_center" />
                      </template>
                    </q-input>
                  </div>
                </div>
              </div>
            </div>
          </q-form>
        </q-card-section>

        <q-separator />
        
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" color="grey-7" @click="showAddProductDialog = false" />
          <q-btn
            color="primary"
            no-caps
            label="Create & Add"
            class="pill-btn slim-btn shadow-1 q-px-md"
            :loading="productStore.saving || shipmentStore.saving"
            @click="onCreateProductAndAddToShipment"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="showDeleteDialog" persistent>
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Shipment Item</q-card-section>
        <q-card-section>
          Are you sure you want to delete
          <strong>{{ pendingDeleteItem?.name ?? 'this item' }}</strong
          >?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="showDeleteDialog = false" />
          <q-btn
            color="negative"
            label="Delete"
            :loading="shipmentStore.saving"
            @click="onConfirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="showEditManualItemDialog" persistent>
      <q-card style="min-width: 560px; max-width: 92vw">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6">Edit Manual Shipment Item</div>
          <q-btn icon="close" flat round dense @click="showEditManualItemDialog = false" />
        </q-card-section>

        <q-card-section>
          <q-form ref="editManualItemFormRef" class="q-gutter-sm">
            <q-input
              v-model="editManualItemForm.name"
              label="Name *"
              outlined
              dense
              hide-bottom-space
              :rules="[(value: string) => Boolean(value?.trim()) || 'Name is required']"
            />
            <q-input v-model="editManualItemForm.barcode" label="Barcode" outlined dense hide-bottom-space />
            <q-input v-model="editManualItemForm.product_code" label="Product Code" outlined dense hide-bottom-space />
            <q-input
              v-model="editManualItemForm.image_url"
              label="Image URL"
              outlined
              dense
              hide-bottom-space
            />
            <div v-if="editManualItemForm.image_url?.trim()" class="shipment-form-preview">
              <div class="text-caption text-grey-7 q-mb-xs">Image Preview</div>
              <div class="shipment-form-preview-box">
                <SmartImage
                  :src="editManualItemForm.image_url"
                  alt="manual item preview"
                  imgClass="shipment-form-preview-image"
                  fallbackClass="shipment-form-preview-fallback"
                />
              </div>
            </div>
            <q-input
              v-model.number="editManualItemForm.quantity"
              label="Quantity *"
              type="number"
              min="1"
              outlined
              dense
              hide-bottom-space
              :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) > 0) || 'Quantity is required']"
              :disabled="!canEditQuantity"
            />
            <q-input
              v-if="shipmentStore.selectedShipment?.is_gbp"
              v-model.number="editManualItemForm.price_gbp"
              label="Price GBP"
              type="number"
              outlined
              dense
              hide-bottom-space
            />
            <q-input
              v-else
              v-model.number="editManualItemForm.cost_bdt"
              label="Cost BDT"
              type="number"
              outlined
              dense
              hide-bottom-space
            />
            <q-input
              v-if="shipmentStore.selectedShipment?.is_gbp"
              v-model.number="editManualItemForm.product_weight"
              label="Product Weight"
              type="number"
              outlined
              dense
              hide-bottom-space
            />
            <q-input
              v-if="shipmentStore.selectedShipment?.is_gbp"
              v-model.number="editManualItemForm.package_weight"
              label="Package Weight"
              type="number"
              outlined
              dense
              hide-bottom-space
            />
            <q-select
              v-model="editManualItemForm.vendor_code"
              :options="vendorOptions"
              emit-value
              map-options
              option-value="value"
              option-label="label"
              label="Vendor"
              outlined
              dense
              hide-bottom-space
              @update:model-value="onAddProductDefaultVendorChange"
            />
            <q-select
              v-model="editManualItemForm.market_code"
              :options="marketOptions"
              emit-value
              map-options
              option-value="value"
              option-label="label"
              label="Market"
              outlined
              dense
              hide-bottom-space
              @update:model-value="onAddProductDefaultMarketChange"
            />
          </q-form>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" @click="showEditManualItemDialog = false" />
          <q-btn
            color="primary"
            no-caps
            label="Save"
            :loading="shipmentStore.saving"
            @click="onSaveManualItemEdit"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="showAddToInventoryConfirmDialog" persistent>
      <q-card style="min-width: 460px; max-width: 540px; width: 92vw">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6">Confirm Process Ingestion</div>
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        
        <q-separator />

        <q-card-section class="q-py-md">
          <div class="text-subtitle2 q-mb-md text-grey-8">Receiving Summary:</div>
          <q-list bordered separator class="rounded-borders">
            <q-item>
              <q-item-section>
                <q-item-label class="text-weight-medium">Usable (Standard)</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge color="positive" class="text-subtitle2 q-px-md">{{ receiptSummary.standard }} units</q-badge>
              </q-item-section>
            </q-item>
            <q-item v-if="receiptSummary.box_damage > 0">
              <q-item-section>
                <q-item-label class="text-weight-medium">Box Damage</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge color="orange" class="text-subtitle2 q-px-md">{{ receiptSummary.box_damage }} units</q-badge>
              </q-item-section>
            </q-item>
            <q-item v-if="receiptSummary.boxless > 0">
              <q-item-section>
                <q-item-label class="text-weight-medium">Boxless</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge color="blue" class="text-subtitle2 q-px-md">{{ receiptSummary.boxless }} units</q-badge>
              </q-item-section>
            </q-item>
            <q-item v-if="receiptSummary.expired > 0">
              <q-item-section>
                <q-item-label class="text-weight-medium">Expired</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge color="red" class="text-subtitle2 q-px-md">{{ receiptSummary.expired }} units</q-badge>
              </q-item-section>
            </q-item>
            <q-item v-if="receiptSummary.stolen > 0">
              <q-item-section>
                <q-item-label class="text-weight-medium">Missing / Stolen</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge color="grey-7" class="text-subtitle2 q-px-md">{{ receiptSummary.stolen }} units</q-badge>
              </q-item-section>
            </q-item>
          </q-list>
          
          <div class="q-mt-md text-caption text-grey-7 bg-grey-2 q-pa-sm rounded-borders">
            ⚠️ <strong>Warning:</strong> Once committed, the batch splits and polymorphic notes will be generated. The purchase cost and accounting records will be permanently locked.
          </div>
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" @click="showAddToInventoryConfirmDialog = false" />
          <q-btn
            color="positive"
            no-caps
            label="Commit Ingestion"
            :loading="shipmentStore.saving"
            @click="onConfirmAddToInventory"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="showInspectDialog" persistent>
      <q-card style="min-width: 580px; max-width: 92vw">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6">Receive & Inspect</div>
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        
        <q-separator />

        <q-card-section v-if="inspectItem" class="q-pa-md">
          <!-- Item info block -->
          <div class="row items-center no-wrap q-mb-md q-pa-sm bg-grey-2 rounded-borders">
            <q-avatar rounded size="64px" class="q-mr-md bg-white">
              <SmartImage
                :src="inspectItem.image_url"
                imgClass="shipment-item-image"
                fallbackClass="shipment-item-image-fallback"
                :enable-edit="false"
              />
            </q-avatar>
            <div class="col">
              <div class="text-subtitle1 text-weight-bold leading-normal">{{ inspectItem.name }}</div>
              <div class="text-caption text-grey-7 row q-col-gutter-x-sm">
                <div>Code: {{ inspectItem.product_code ?? '-' }}</div>
                <div>•</div>
                <div>Expected Qty: <strong class="text-primary">{{ inspectItem.quantity }}</strong></div>
              </div>
            </div>
          </div>

          <!-- Splits form using Quasar list -->
          <q-list class="q-gutter-y-sm">
            <!-- Usable -->
            <q-item class="q-px-none items-center">
              <q-item-section>
                <q-item-label class="text-weight-bold">Usable (Standard)</q-item-label>
                <q-item-label caption>Perfect condition</q-item-label>
              </q-item-section>
              <q-item-section side style="width: 280px">
                <q-input
                  v-model.number="inspectForm.standard"
                  type="number"
                  outlined
                  dense
                  min="0"
                  suffix="units"
                />
              </q-item-section>
            </q-item>

            <!-- Box Damage -->
            <q-item class="q-px-none items-start">
              <q-item-section class="q-pt-xs">
                <q-item-label class="text-weight-bold text-orange-9">Box Damage</q-item-label>
                <q-item-label caption>Dented/torn packaging</q-item-label>
              </q-item-section>
              <q-item-section side style="width: 280px" class="q-gutter-y-xs">
                <q-input
                  v-model.number="inspectForm.box_damage"
                  type="number"
                  outlined
                  dense
                  min="0"
                  suffix="units"
                />
                <q-input
                  v-if="inspectForm.box_damage > 0"
                  v-model="inspectForm.box_damage_note"
                  type="textarea"
                  autogrow
                  outlined
                  dense
                  placeholder="Packaging defect note..."
                />
              </q-item-section>
            </q-item>

            <!-- Boxless -->
            <q-item class="q-px-none items-start">
              <q-item-section class="q-pt-xs">
                <q-item-label class="text-weight-bold text-blue-9">Boxless</q-item-label>
                <q-item-label caption>No box/loose items</q-item-label>
              </q-item-section>
              <q-item-section side style="width: 280px" class="q-gutter-y-xs">
                <q-input
                  v-model.number="inspectForm.boxless"
                  type="number"
                  outlined
                  dense
                  min="0"
                  suffix="units"
                />
                <q-input
                  v-if="inspectForm.boxless > 0"
                  v-model="inspectForm.boxless_note"
                  type="textarea"
                  autogrow
                  outlined
                  dense
                  placeholder="Boxless description..."
                />
              </q-item-section>
            </q-item>

            <!-- Expired -->
            <q-item class="q-px-none items-start">
              <q-item-section class="q-pt-xs">
                <q-item-label class="text-weight-bold text-red-9">Expired / Damaged</q-item-label>
                <q-item-label caption>Out of date / damaged item</q-item-label>
              </q-item-section>
              <q-item-section side style="width: 280px" class="q-gutter-y-xs">
                <q-input
                  v-model.number="inspectForm.expired"
                  type="number"
                  outlined
                  dense
                  min="0"
                  suffix="units"
                />
                <q-input
                  v-if="inspectForm.expired > 0"
                  v-model="inspectForm.expired_note"
                  type="textarea"
                  autogrow
                  outlined
                  dense
                  placeholder="Damage/expiry notes..."
                />
              </q-item-section>
            </q-item>

            <!-- Missing / Stolen -->
            <q-item class="q-px-none items-start">
              <q-item-section class="q-pt-xs">
                <q-item-label class="text-weight-bold text-grey-9">Transit Loss</q-item-label>
                <q-item-label caption>Stolen / Missing cargo</q-item-label>
              </q-item-section>
              <q-item-section side style="width: 280px" class="q-gutter-y-xs">
                <q-input
                  v-model.number="inspectForm.stolen"
                  type="number"
                  outlined
                  dense
                  min="0"
                  suffix="units"
                />
                <q-input
                  v-if="inspectForm.stolen > 0"
                  v-model="inspectForm.stolen_note"
                  type="textarea"
                  autogrow
                  outlined
                  dense
                  placeholder="Transit shortage notes..."
                />
              </q-item-section>
            </q-item>
          </q-list>

          <!-- Summary bar -->
          <div class="q-mt-lg q-pa-md rounded-borders row items-center justify-between" :class="inspectFormRemaining === 0 ? 'bg-green-1' : 'bg-red-1'">
            <div class="row items-center q-gutter-xs">
              <q-icon :name="inspectFormRemaining === 0 ? 'check_circle' : 'warning'" :color="inspectFormRemaining === 0 ? 'positive' : 'negative'" size="20px" />
              <div class="text-weight-bold text-body2">
                {{ inspectFormRemaining === 0 ? 'Splits are fully assigned' : `Remaining to distribute: ${inspectFormRemaining} units` }}
              </div>
            </div>
            <div class="text-caption text-grey-8">
              Sum: {{ inspectFormTotal }} / {{ inspectItem.quantity }}
            </div>
          </div>
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            no-caps
            label="Apply Inspection"
            :disabled="!isInspectFormValid"
            @click="saveInspectSplits"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="showBatchEditorDialog" persistent>
      <q-card style="min-width: 760px; max-width: 96vw">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div>
            <div class="text-h6">Edit Batch Codes</div>
            <div class="text-caption text-grey-7">
              {{ batchEditorItem?.name ?? '-' }} ({{ batchEditorItem?.product_code ?? '-' }})
            </div>
          </div>
          <q-btn icon="close" flat round dense @click="showBatchEditorDialog = false" />
        </q-card-section>
        <q-card-section class="q-pt-none">
          <q-markup-table flat bordered class="shipment-batch-editor-table">
            <thead>
              <tr>
                <th class="text-left">Batch Code</th>
                <th class="text-left">Manufacturing Date</th>
                <th class="text-right" style="width: 56px">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in batchEditorRows" :key="`batch-edit-${index}`">
                <td>
                  <q-input
                    v-model="row.batch_id"
                    dense
                    outlined
                    placeholder="Batch code"
                  />
                </td>
                <td>
                  <q-input
                    v-model="row.manufacturing_date"
                    dense
                    outlined
                    mask="##/##/####"
                    fill-mask
                    placeholder="DD/MM/YYYY (e.g. 25/12/2026)"
                  >
                    <template #append>
                      <q-icon name="event" class="cursor-pointer" />
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-date
                          v-model="row.manufacturing_date"
                          mask="DD/MM/YYYY"
                        >
                          <div class="row items-center justify-end">
                            <q-btn v-close-popup label="Close" color="primary" flat />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </template>
                  </q-input>
                </td>
                <td class="text-right">
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="o_delete"
                    @click="removeBatchEditorRow(index)"
                  />
                </td>
              </tr>
              <tr v-if="!batchEditorRows.length">
                <td colspan="3" class="text-center text-grey-7 q-py-sm">
                  No batch rows yet. Add one below.
                </td>
              </tr>
            </tbody>
          </q-markup-table>
          <div class="q-mt-sm">
            <q-btn
              flat
              no-caps
              color="primary"
              icon="add"
              label="Add Row"
              @click="addBatchEditorRow"
            />
          </div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" @click="showBatchEditorDialog = false" />
          <q-btn
            color="primary"
            no-caps
            label="Save"
            :loading="shipmentStore.saving"
            @click="saveBatchEditorRows"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="showShipmentInfoDialog" persistent>
      <q-card style="min-width: 720px; max-width: 90vw">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">
            {{ shipmentInfoReadOnly ? 'Conversion Rate Details' : 'Edit Ingestion Settings' }}
          </div>
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        
        <q-separator />

        <q-card-section class="q-py-md">
          <div class="row q-col-gutter-md">
            <!-- Inputs Column -->
            <div class="col-12 col-sm-6 q-gutter-y-md">
              <q-input
                v-model.number="shipmentInfoForm.product_conversion_rate"
                type="number"
                step="0.0001"
                label="Product Conversion Rate *"
                outlined
                dense
                :readonly="shipmentInfoReadOnly"
                :rules="[val => val > 0 || 'Must be greater than 0']"
              />
              <q-input
                v-model.number="shipmentInfoForm.cargo_conversion_rate"
                type="number"
                step="0.0001"
                label="Cargo Conversion Rate *"
                outlined
                dense
                :readonly="shipmentInfoReadOnly"
                :rules="[val => val > 0 || 'Must be greater than 0']"
              />
              <q-input
                v-model.number="shipmentInfoForm.cargo_rate"
                type="number"
                step="0.01"
                label="Cargo Rate *"
                outlined
                dense
                :readonly="shipmentInfoReadOnly"
                :rules="[val => val > 0 || 'Must be greater than 0']"
              />
              <q-input
                :model-value="`${formatFixed2(totals.total_weight_gm / 1000)} kg`"
                label="Expected Weight"
                outlined
                dense
                readonly
                bg-color="grey-2"
              />
              <q-input
                v-model.number="shipmentInfoForm.received_weight"
                type="number"
                step="0.001"
                label="Received Weight (kg)"
                outlined
                dense
                :readonly="shipmentInfoReadOnly"
              />
            </div>

            <!-- Real-time Preview Column -->
            <div class="col-12 col-sm-6">
              <q-card flat bordered style="background-color: #fafafa; border-radius: 8px;" class="full-height">
                <q-card-section class="q-pa-md">
                  <div class="text-subtitle2 text-weight-bold text-primary q-mb-md">Calculated Transaction Rate</div>
                  
                  <div class="q-gutter-y-sm">
                    <div class="row justify-between text-body2">
                      <span class="text-grey-7">Goods Cost (GBP):</span>
                      <span class="text-weight-bold">£{{ liveGoodsCostGbp.toFixed(2) }}</span>
                    </div>
                    <div class="row justify-between text-body2">
                      <span class="text-grey-7">Goods Cost (BDT):</span>
                      <span class="text-weight-bold">৳{{ liveGoodsCostBdt.toFixed(2) }}</span>
                    </div>

                    <q-separator class="q-my-xs" />

                    <div class="row justify-between text-body2">
                      <span class="text-grey-7">Cargo Weight (KG):</span>
                      <span class="text-weight-bold">{{ liveCargoWeight.toFixed(2) }} kg</span>
                    </div>
                    <div class="row justify-between text-body2">
                      <span class="text-grey-7">Cargo Cost (GBP):</span>
                      <span class="text-weight-bold">£{{ liveCargoCostGbp.toFixed(2) }}</span>
                    </div>
                    <div class="row justify-between text-body2">
                      <span class="text-grey-7">Cargo Cost (BDT):</span>
                      <span class="text-weight-bold">৳{{ liveCargoCostBdt.toFixed(2) }}</span>
                    </div>

                    <q-separator class="q-my-xs" />

                    <div class="row justify-between text-body2 text-primary">
                      <span class="text-weight-medium">Total Costing (BDT):</span>
                      <span class="text-weight-bold">৳{{ liveCostingBdt.toFixed(2) }}</span>
                    </div>
                    
                    <div class="bg-primary text-white q-pa-md q-mt-md rounded-borders shadow-1 text-center" style="border-radius: 8px;">
                      <div class="text-caption text-uppercase tracking-wider">Transaction Rate</div>
                      <div class="text-h5 text-weight-bolder">৳{{ liveTransactionRate.toFixed(2) }}</div>
                      <div class="text-caption text-grey-3 q-mt-xs">Blended rate for this shipment</div>
                    </div>
                  </div>
                </q-card-section>
              </q-card>
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            v-if="!shipmentInfoReadOnly"
            color="primary"
            label="Save Details"
            :loading="shipmentStore.saving"
            @click="saveShipmentInfoDialog"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <ShipmentItemDetailsDialog
      v-model="showItemDetailsDialog"
      :item="selectedDetailsItem"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import type { QForm } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import ShipmentItemDetailsDialog from '../components/ShipmentItemDetailsDialog.vue'
import { calculateCostBdt } from '../utils/costing'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useMarketStore } from 'src/modules/market/stores/marketStore'
import { useProductStore } from 'src/modules/products/stores/productStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { useShipmentStore } from '../stores/shipmentStore'
import { SHIPMENT_STATUS_OPTIONS, type BatchCodePc, type ShipmentItem, type ShipmentStatus, type ShipmentReceiveItemInput, type ShipmentReceiveItemSplit, type ShipmentItemReceivingSplits } from '../types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const productStore = useProductStore()
const vendorStore = useVendorStore()
const marketStore = useMarketStore()
const $q = useQuasar()

const showAddItemDialog = ref(false)
const showAddProductDialog = ref(false)
const showDeleteDialog = ref(false)
const showEditManualItemDialog = ref(false)
const showAddToInventoryConfirmDialog = ref(false)
const showItemDetailsDialog = ref(false)
const showBatchEditorDialog = ref(false)
const initialLoading = ref(true)
const pendingDeleteItem = ref<ShipmentItem | null>(null)
const editingManualItem = ref<ShipmentItem | null>(null)
const selectedDetailsItemId = ref<number | null>(null)
const selectedDetailsItem = computed(() => {
  if (selectedDetailsItemId.value == null) return null
  return shipmentStore.shipmentItems.find((item) => item.id === selectedDetailsItemId.value) ?? null
})
const batchEditorItem = ref<ShipmentItem | null>(null)
const batchEditorRows = ref<Array<{ id: number | null; batch_id: string; manufacturing_date: string }>>([])
const selectedStatus = ref<ShipmentStatus>('Draft')
const isInventoryAdded = computed(
  () =>
    shipmentStore.selectedShipment?.inventory_added === true ||
    selectedStatus.value === 'Added to Inventory',
)
const isDraftStatus = computed(() => selectedStatus.value === 'Draft' && !isInventoryAdded.value)
const canEditQuantity = computed(() => selectedStatus.value === 'Draft' && !isInventoryAdded.value)

const showInspectDialog = ref(false)
const inspectItem = ref<ShipmentItem | null>(null)
const receiptsMap = ref<Record<number, {
  standard: number
  box_damage: number
  box_damage_note: string
  expired: number
  expired_note: string
  boxless: number
  boxless_note: string
  stolen: number
  stolen_note: string
}>>({})

const confirmedItemIds = ref<Set<number>>(new Set())

const toggleItemConfirmed = async (item: ShipmentItem) => {
  const currentStatus = confirmedItemIds.value.has(item.id)
  let splitsPayload: ShipmentItemReceivingSplits | null = null
  
  if (currentStatus) {
    confirmedItemIds.value.delete(item.id)
    splitsPayload = null
  } else {
    const r = getOrInitItemReceipt(item)
    confirmedItemIds.value.add(item.id)
    splitsPayload = {
      standard: { qty: r.standard, note: null },
      box_damage: { qty: r.box_damage, note: r.box_damage_note || null },
      expired: { qty: r.expired, note: r.expired_note || null },
      boxless: { qty: r.boxless, note: r.boxless_note || null },
      stolen: { qty: r.stolen, note: r.stolen_note || null },
    }
  }
  
  const result = await shipmentStore.updateShipmentItem({
    id: item.id,
    patch: {
      inspected: !currentStatus,
      receiving_splits: splitsPayload
    }
  })
  
  if (!result.success) {
    if (currentStatus) {
      confirmedItemIds.value.add(item.id)
    } else {
      confirmedItemIds.value.delete(item.id)
    }
  }
}

const confirmAllItemsPerfect = async () => {
  const updates = shipmentStore.shipmentItems.map((item) => {
    const r = getOrInitItemReceipt(item)
    confirmedItemIds.value.add(item.id)
    const splitsPayload: ShipmentItemReceivingSplits = {
      standard: { qty: r.standard, note: null },
      box_damage: { qty: r.box_damage, note: r.box_damage_note || null },
      expired: { qty: r.expired, note: r.expired_note || null },
      boxless: { qty: r.boxless, note: r.boxless_note || null },
      stolen: { qty: r.stolen, note: r.stolen_note || null },
    }
    return shipmentStore.updateShipmentItem({
      id: item.id,
      patch: {
        inspected: true,
        receiving_splits: splitsPayload
      }
    })
  })
  
  const results = await Promise.all(updates)
  const failed = results.filter((r) => !r.success).length
  if (failed > 0) {
    $q.notify({
      type: 'warning',
      message: `Failed to confirm ${failed} item(s).`,
    })
  } else {
    $q.notify({
      type: 'positive',
      message: 'All items marked as perfect and confirmed.',
    })
  }
}

const showShipmentInfoDialog = ref(false)
const shipmentInfoReadOnly = ref(false)
const shipmentInfoForm = reactive({
  product_conversion_rate: 0,
  cargo_conversion_rate: 0,
  cargo_rate: 0,
  received_weight: null as number | null,
})

const liveGoodsCostGbp = computed(() => {
  return (shipmentStore.shipmentItems ?? []).reduce((sum, item) => {
    return sum + (Number(item.price_gbp ?? 0) * Number(item.quantity ?? 0))
  }, 0)
})

const liveGoodsCostBdt = computed(() => {
  return liveGoodsCostGbp.value * Number(shipmentInfoForm.product_conversion_rate ?? 0)
})

const liveCargoWeight = computed(() => {
  return Number(shipmentInfoForm.received_weight ?? 0)
})

const liveCargoCostGbp = computed(() => {
  return liveCargoWeight.value * Number(shipmentInfoForm.cargo_rate ?? 0)
})

const liveCargoCostBdt = computed(() => {
  return liveCargoCostGbp.value * Number(shipmentInfoForm.cargo_conversion_rate ?? 0)
})

const liveCostingBdt = computed(() => {
  return liveGoodsCostBdt.value + liveCargoCostBdt.value
})

const liveTransactionRate = computed(() => {
  const totalGbp = liveGoodsCostGbp.value + liveCargoCostGbp.value
  if (totalGbp <= 0) return 0
  return liveCostingBdt.value / totalGbp
})

const openShipmentInfoDialog = (readOnly = false) => {
  const current = shipmentStore.selectedShipment
  if (!current) return
  shipmentInfoReadOnly.value = readOnly
  shipmentInfoForm.product_conversion_rate = current.product_conversion_rate ?? 0
  shipmentInfoForm.cargo_conversion_rate = current.cargo_conversion_rate ?? 0
  shipmentInfoForm.cargo_rate = current.cargo_rate ?? 0
  shipmentInfoForm.received_weight = current.received_weight
  showShipmentInfoDialog.value = true
}

const saveShipmentInfoDialog = async () => {
  if (shipmentInfoReadOnly.value) return
  if (!shipmentStore.selectedShipment) return
  const result = await shipmentStore.updateShipment({
    id: shipmentStore.selectedShipment.id,
    patch: {
      product_conversion_rate: Number(shipmentInfoForm.product_conversion_rate) || null,
      cargo_conversion_rate: Number(shipmentInfoForm.cargo_conversion_rate) || null,
      cargo_rate: Number(shipmentInfoForm.cargo_rate) || null,
      received_weight: shipmentInfoForm.received_weight != null ? Number(shipmentInfoForm.received_weight) : null,
    }
  })
  if (result.success) {
    showShipmentInfoDialog.value = false
    await Promise.all([
      shipmentStore.fetchShipmentById(shipmentStore.selectedShipment.id),
      shipmentStore.fetchBatchCodePcByShipment(shipmentStore.selectedShipment.id),
    ])
  }
}

const openEditableShipmentInfoDialog = () => {
  openShipmentInfoDialog(false)
}

const openReadonlyShipmentInfoDialog = () => {
  openShipmentInfoDialog(true)
}

const canIngestWorkflowCommit = computed(() => {
  return !isAddToInventoryRateInvalid.value && confirmedItemIds.value.size === shipmentStore.shipmentItems.length
})

watch(
  () => shipmentStore.shipmentItems,
  (items) => {
    if (!items || items.length === 0) return
    items.forEach((item) => {
      if (item.inspected) {
        confirmedItemIds.value.add(item.id)
      }
    })
  },
  { immediate: true, deep: true }
)

const inspectForm = reactive({
  standard: 0,
  box_damage: 0,
  box_damage_note: '',
  expired: 0,
  expired_note: '',
  boxless: 0,
  boxless_note: '',
  stolen: 0,
  stolen_note: '',
})

const getOrInitItemReceipt = (item: ShipmentItem): {
  standard: number
  box_damage: number
  box_damage_note: string
  expired: number
  expired_note: string
  boxless: number
  boxless_note: string
  stolen: number
  stolen_note: string
} => {
  if (!receiptsMap.value[item.id]) {
    if (item.receiving_splits) {
      receiptsMap.value[item.id] = {
        standard: item.receiving_splits.standard?.qty ?? 0,
        box_damage: item.receiving_splits.box_damage?.qty ?? 0,
        box_damage_note: item.receiving_splits.box_damage?.note ?? '',
        expired: item.receiving_splits.expired?.qty ?? 0,
        expired_note: item.receiving_splits.expired?.note ?? '',
        boxless: item.receiving_splits.boxless?.qty ?? 0,
        boxless_note: item.receiving_splits.boxless?.note ?? '',
        stolen: item.receiving_splits.stolen?.qty ?? 0,
        stolen_note: item.receiving_splits.stolen?.note ?? '',
      }
    } else {
      receiptsMap.value[item.id] = {
        standard: item.quantity,
        box_damage: 0,
        box_damage_note: '',
        expired: 0,
        expired_note: '',
        boxless: 0,
        boxless_note: '',
        stolen: 0,
        stolen_note: '',
      }
    }
  }
  return receiptsMap.value[item.id]!
}

const hasItemSplits = (item: ShipmentItem) => {
  if (!item.inspected) return false
  const receipt = getOrInitItemReceipt(item)
  return (
    receipt.standard > 0 ||
    receipt.box_damage > 0 ||
    receipt.expired > 0 ||
    receipt.boxless > 0 ||
    receipt.stolen > 0
  )
}

const getReceivedQty = (item: ShipmentItem) => {
  const r = getOrInitItemReceipt(item)
  return r.standard + r.box_damage + r.boxless
}

const getDamagedQty = (item: ShipmentItem) => {
  const r = getOrInitItemReceipt(item)
  return r.expired
}

const getStolenQty = (item: ShipmentItem) => {
  const r = getOrInitItemReceipt(item)
  return r.stolen
}

const openInspectDialog = (item: ShipmentItem) => {
  inspectItem.value = item
  const current = getOrInitItemReceipt(item)
  inspectForm.standard = current.standard
  inspectForm.box_damage = current.box_damage
  inspectForm.box_damage_note = current.box_damage_note
  inspectForm.expired = current.expired
  inspectForm.expired_note = current.expired_note
  inspectForm.boxless = current.boxless
  inspectForm.boxless_note = current.boxless_note
  inspectForm.stolen = current.stolen
  inspectForm.stolen_note = current.stolen_note
  showInspectDialog.value = true
}

const saveInspectSplits = async () => {
  if (!inspectItem.value) return
  const itemId = inspectItem.value.id
  const flatPayload = {
    standard: Number(inspectForm.standard) || 0,
    box_damage: Number(inspectForm.box_damage) || 0,
    box_damage_note: inspectForm.box_damage_note.trim(),
    expired: Number(inspectForm.expired) || 0,
    expired_note: inspectForm.expired_note.trim(),
    boxless: Number(inspectForm.boxless) || 0,
    boxless_note: inspectForm.boxless_note.trim(),
    stolen: Number(inspectForm.stolen) || 0,
    stolen_note: inspectForm.stolen_note.trim(),
  }
  receiptsMap.value[itemId] = flatPayload
  confirmedItemIds.value.add(itemId)
  showInspectDialog.value = false
  inspectItem.value = null

  const splitsPayload: ShipmentItemReceivingSplits = {
    standard: { qty: flatPayload.standard, note: null },
    box_damage: { qty: flatPayload.box_damage, note: flatPayload.box_damage_note || null },
    expired: { qty: flatPayload.expired, note: flatPayload.expired_note || null },
    boxless: { qty: flatPayload.boxless, note: flatPayload.boxless_note || null },
    stolen: { qty: flatPayload.stolen, note: flatPayload.stolen_note || null },
  }

  await shipmentStore.updateShipmentItem({
    id: itemId,
    patch: {
      inspected: true,
      receiving_splits: splitsPayload
    }
  })
}

const inspectFormTotal = computed(() => {
  return (
    Number(inspectForm.standard || 0) +
    Number(inspectForm.box_damage || 0) +
    Number(inspectForm.expired || 0) +
    Number(inspectForm.boxless || 0) +
    Number(inspectForm.stolen || 0)
  )
})

const inspectFormRemaining = computed(() => {
  if (!inspectItem.value) return 0
  return inspectItem.value.quantity - inspectFormTotal.value
})

const isInspectFormValid = computed(() => {
  return inspectFormRemaining.value === 0
})

const receiptSummary = computed(() => {
  let standard = 0
  let box_damage = 0
  let expired = 0
  let boxless = 0
  let stolen = 0

  shipmentStore.shipmentItems.forEach((item) => {
    const r = getOrInitItemReceipt(item)
    standard += r.standard
    box_damage += r.box_damage
    expired += r.expired
    boxless += r.boxless
    stolen += r.stolen
  })

  return { standard, box_damage, expired, boxless, stolen }
})
const productSearch = ref('')
const productSearchField = ref<'name' | 'barcode' | 'product_code' | 'id'>('name')
const productSearchVendorCode = ref<string | null>(null)
const productSearchCategory = ref<string | null>(null)
const productSearchFieldOptions: Array<{
  label: string
  value: 'name' | 'barcode' | 'product_code' | 'id'
}> = [
  { label: 'Name', value: 'name' },
  { label: 'Barcode', value: 'barcode' },
  { label: 'Product Code', value: 'product_code' },
  { label: 'Product ID', value: 'id' },
]
const productQuantityById = reactive<Record<number, number>>({})
const baseColumnSelectorOptions = [
  { label: 'Name', value: 'name' },
  { label: 'Product ID', value: 'product_id' },
  { label: 'Barcode', value: 'barcode' },
  { label: 'Product Code', value: 'product_code' },
  { label: 'Batch / MFG Date', value: 'batch_manufacture' },
  { label: 'Method', value: 'method' },
  { label: 'Price GBP', value: 'price_gbp' },
  { label: 'Cost BDT', value: 'cost_bdt' },
  { label: 'Quantity', value: 'quantity' },

  { label: 'Product Wt', value: 'product_weight' },
  { label: 'Package Wt', value: 'package_weight' },
  { label: 'Actions', value: 'actions' },
] as const

type ShipmentColumnKey = (typeof baseColumnSelectorOptions)[number]['value']

const columnSelectorOptions = computed(() => {
  const isGbp = shipmentStore.selectedShipment?.is_gbp !== false
  return baseColumnSelectorOptions.filter((option) => {
    if (!isGbp) {
      return (
        option.value !== 'price_gbp' &&
        option.value !== 'product_weight' &&
        option.value !== 'package_weight'
      )
    }
    return true
  })
})

const columnSelectorOptionsUi = computed(() =>
  columnSelectorOptions.value.map((option) => ({ ...option })),
)
const allSelectableColumnsSelected = computed({
  get: () => {
    const current = new Set(visibleColumns.value)
    return columnSelectorOptions.value.every((option) => current.has(option.value))
  },
  set: (checked: boolean) => {
    if (checked) {
      visibleColumns.value = columnSelectorOptions.value.map((option) => option.value)
      return
    }
    visibleColumns.value = []
  },
})

const visibleColumns = ref<ShipmentColumnKey[]>(
  baseColumnSelectorOptions.map((option) => option.value),
)
const addProductFormRef = ref<QForm | null>(null)
const editManualItemFormRef = ref<QForm | null>(null)
const addProductForm = reactive({
  name: '',
  quantity: 1,
  barcode: '',
  product_code: '',
  image_url: '',
  price_gbp: null as number | null,
  cost_bdt: null as number | null,
  product_weight: null as number | null,
  package_weight: null as number | null,
  vendor_code: null as string | null,
  category: null as string | null,
  market_code: null as string | null,
  minimum_order_quantity: null as number | null,
})
const editManualItemForm = reactive({
  name: '',
  barcode: '',
  product_code: '',
  image_url: '',
  quantity: 1,
  price_gbp: null as number | null,
  cost_bdt: null as number | null,
  product_weight: null as number | null,
  package_weight: null as number | null,
  vendor_code: null as string | null,
  market_code: null as string | null,
})
const vendorOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...vendorStore.items.map((vendor) => ({
    label: `${vendor.name} (${vendor.code})`,
    value: vendor.code,
  })),
])
const categoryOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...productStore.categoryOptions.map((category) => ({
    label: category,
    value: category,
  })),
])
const marketOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...marketStore.items.map((market) => ({
    label: `${market.name} (${market.code})`,
    value: market.code,
  })),
])
const shipmentMarkerTagOptions = [
  { label: 'None', value: null },
  { label: 'Price Reviewed', value: 'price_reviewed' as const },
  { label: 'Issue', value: 'issue' as const },
  { label: 'Done', value: 'done' as const },
]
const getTagChipColor = (tag: 'price_reviewed' | 'issue' | 'done' | null) => {
  if (tag === 'price_reviewed') return 'indigo-6'
  if (tag === 'issue') return 'negative'
  if (tag === 'done') return 'positive'
  return 'grey-6'
}
const getTagLabel = (tag: 'price_reviewed' | 'issue' | 'done' | null) => {
  const option = shipmentMarkerTagOptions.find((item) => item.value === tag)
  return option?.label ?? 'None'
}

const shipmentId = computed(() => Number(route.params.id))
const statusOptions = SHIPMENT_STATUS_OPTIONS
const canAddToInventory = computed(
  () =>
    shipmentStore.selectedShipment?.status === 'Warehouse Received' &&
    shipmentStore.selectedShipment?.inventory_added !== true,
)
const isAddToInventoryRateInvalid = computed(() => {
  const shipment = shipmentStore.selectedShipment
  if (!shipment) {
    return true
  }
  if (!shipment.is_gbp) {
    return false
  }

  const cargoRate = Number(shipment.cargo_rate ?? 0)
  const productConversionRate = Number(shipment.product_conversion_rate ?? 0)
  const cargoConversionRate = Number(shipment.cargo_conversion_rate ?? 0)

  return cargoRate <= 0 || productConversionRate <= 0 || cargoConversionRate <= 0
})

const isColumnVisible = (column: ShipmentColumnKey) => visibleColumns.value.includes(column)

const shipmentTableColspan = computed(() => {
  const base = 3 // SL + Image + Tag are always visible
  return (
    base +
    (isColumnVisible('name') ? 1 : 0) +
    (isColumnVisible('product_id') ? 1 : 0) +
    (isColumnVisible('barcode') ? 1 : 0) +
    (isColumnVisible('product_code') ? 1 : 0) +
    (isColumnVisible('batch_manufacture') ? 1 : 0) +
    (isColumnVisible('method') ? 1 : 0) +
    (isColumnVisible('price_gbp') ? 1 : 0) +
    (isColumnVisible('cost_bdt') ? 1 : 0) +
    (isColumnVisible('quantity') ? 1 : 0) +
    (isColumnVisible('product_weight') ? 1 : 0) +
    (isColumnVisible('package_weight') ? 1 : 0) +
    (isColumnVisible('actions') ? 1 : 0)
  )
})

const formatIsoDateToDdMmYyyy = (value: string | null | undefined) => {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  const day = String(date.getDate()).padStart(2, '0')
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const year = String(date.getFullYear())
  return `${day}/${month}/${year}`
}

const normalizeDdMmYyyyToIso = (value: string | null | undefined) => {
  const raw = (value ?? '').trim()
  if (!raw) return null
  const match = raw.match(/^(\d{2})\/(\d{2})\/(\d{4})$/)
  if (!match) return null
  const [, dd, mm, yyyy] = match
  const day = Number(dd)
  const month = Number(mm)
  const year = Number(yyyy)
  if (!Number.isFinite(day) || !Number.isFinite(month) || !Number.isFinite(year)) return null
  if (month < 1 || month > 12 || day < 1 || day > 31) return null
  const iso = `${yyyy}-${mm}-${dd}`
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return null
  return iso
}

const getRemainingMonthsLabelFromIsoDate = (manufacturingDateIso: string | null | undefined) => {
  if (!manufacturingDateIso) return 'N/A'
  const mfg = new Date(manufacturingDateIso)
  if (Number.isNaN(mfg.getTime())) return 'N/A'

  const expiry = new Date(mfg)
  expiry.setMonth(expiry.getMonth() + 36)
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const end = new Date(expiry.getFullYear(), expiry.getMonth(), expiry.getDate())

  if (end.getTime() <= start.getTime()) return 'Expired'

  let months =
    (end.getFullYear() - start.getFullYear()) * 12 +
    (end.getMonth() - start.getMonth())

  let anchor = new Date(start)
  anchor.setMonth(anchor.getMonth() + months)
  if (anchor.getTime() > end.getTime()) {
    months -= 1
    anchor = new Date(start)
    anchor.setMonth(anchor.getMonth() + months)
  }

  const msPerDay = 24 * 60 * 60 * 1000
  const days = Math.max(0, Math.round((end.getTime() - anchor.getTime()) / msPerDay))
  const monthText = `${months} month${months === 1 ? '' : 's'}`
  const dayText = `${days} day${days === 1 ? '' : 's'}`
  return `${monthText} ${dayText} left`
}

const getMatchedBatchRows = (item: ShipmentItem): BatchCodePc[] => {
  const matchedByShipmentItem = shipmentStore.batchCodePcRows.filter(
    (row) => row.shipment_item_id === item.id,
  )
  return matchedByShipmentItem.length > 0
    ? matchedByShipmentItem
    : shipmentStore.batchCodePcRows.filter(
        (row) => row.product_code != null && row.product_code === item.product_code,
      )
}

const getBatchManufactureLines = (item: ShipmentItem) => {
  const matchedRows = getMatchedBatchRows(item)

  if (!matchedRows.length) return []

  const seen = new Set<string>()
  const parts: Array<{ batchId: string; manufacturingDate: string; remainingMonthsLabel: string }> = []
  matchedRows.forEach((row) => {
    const batchId = row.batch_id?.trim() || '-'
    const manufacturingDate = formatIsoDateToDdMmYyyy(row.manufacturing_date)
    const remainingMonthsLabel = getRemainingMonthsLabelFromIsoDate(row.manufacturing_date)
    const key = `${batchId}__${manufacturingDate}`
    if (seen.has(key)) return
    seen.add(key)
    parts.push({ batchId, manufacturingDate, remainingMonthsLabel })
  })

  return parts
}

const openBatchEditorDialog = (item: ShipmentItem) => {
  batchEditorItem.value = item
  batchEditorRows.value = getMatchedBatchRows(item).map((row) => ({
    id: row.id,
    batch_id: row.batch_id ?? '',
    manufacturing_date: row.manufacturing_date ? formatIsoDateToDdMmYyyy(row.manufacturing_date) : '',
  }))
  showBatchEditorDialog.value = true
}

const addBatchEditorRow = () => {
  batchEditorRows.value.push({ id: null, batch_id: '', manufacturing_date: '' })
}

const removeBatchEditorRow = (index: number) => {
  batchEditorRows.value.splice(index, 1)
}

const saveBatchEditorRows = async () => {
  const item = batchEditorItem.value
  if (!item || !shipmentStore.selectedShipment) return

  const existingRows = getMatchedBatchRows(item)
  const deleteResults = await Promise.all(
    existingRows.map((row) => shipmentStore.deleteBatchCodePc({ id: row.id })),
  )
  if (deleteResults.some((result) => !result.success)) {
    return
  }

  const rowsToCreate = batchEditorRows.value
    .map((row) => ({
      batch_id: row.batch_id.trim(),
      manufacturing_date: row.manufacturing_date.trim(),
    }))
    .filter((row) => row.batch_id || row.manufacturing_date)
    .map((row) => ({
      shipment_id: shipmentStore.selectedShipment!.id,
      shipment_item_id: item.id,
      product_code: item.product_code ?? null,
      batch_id: row.batch_id || null,
      manufacturing_date: normalizeDdMmYyyyToIso(row.manufacturing_date),
      expire_date: null,
    }))

  if (rowsToCreate.length) {
    const createResult = await shipmentStore.bulkCreateBatchCodePc({ rows: rowsToCreate })
    if (!createResult.success) {
      return
    }
  }

  await shipmentStore.fetchBatchCodePcByShipment(shipmentStore.selectedShipment.id)
  showBatchEditorDialog.value = false
}

const goToBatchCodePage = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipmentId.value}/batch-code-pc`)
}

const resetProductSearchDialog = () => {
  productSearch.value = ''
  productSearchField.value = 'name'
  productSearchVendorCode.value = shipmentStore.selectedShipment?.vendor_code ?? null
  productSearchCategory.value = null
  Object.keys(productQuantityById).forEach((key) => {
    delete productQuantityById[Number(key)]
  })
  productStore.items = []
}

const openAddItemDialog = () => {
  resetProductSearchDialog()
  void loadCategoryOptionsForVendor(productSearchVendorCode.value)
  showAddItemDialog.value = true
}

const resetAddProductForm = () => {
  addProductForm.name = ''
  addProductForm.quantity = 1
  addProductForm.barcode = ''
  addProductForm.product_code = ''
  addProductForm.image_url = ''
  addProductForm.price_gbp = null
  addProductForm.cost_bdt = null
  addProductForm.product_weight = null
  addProductForm.package_weight = null
  addProductForm.vendor_code = shipmentStore.selectedShipment?.vendor_code ?? null
  addProductForm.category = null
  addProductForm.market_code = shipmentStore.selectedShipment?.market_code ?? null
  addProductForm.minimum_order_quantity = null
  void loadCategoryOptionsForVendor(addProductForm.vendor_code)
}

const openAddProductDialog = () => {
  resetAddProductForm()
  showAddProductDialog.value = true
}

const onSetProductQuantity = (productId: number, value: string | number | null) => {
  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed <= 0) {
    productQuantityById[productId] = 1
    return
  }
  productQuantityById[productId] = Math.floor(parsed)
}

const openDeleteDialog = (item: ShipmentItem) => {
  pendingDeleteItem.value = item
  showDeleteDialog.value = true
}

const openEditManualItemDialog = (item: ShipmentItem) => {
  const matchedProduct = item.product_id
    ? productStore.items.find((product) => product.id === item.product_id)
    : null

  editingManualItem.value = item
  editManualItemForm.name = item.name ?? ''
  editManualItemForm.barcode = item.barcode ?? ''
  editManualItemForm.product_code = item.product_code ?? ''
  editManualItemForm.image_url = item.image_url ?? ''
  editManualItemForm.quantity = Number(item.quantity ?? 1)
  editManualItemForm.price_gbp = item.price_gbp ?? null
  editManualItemForm.cost_bdt = item.cost_bdt ?? null
  editManualItemForm.product_weight = item.product_weight ?? null
  editManualItemForm.package_weight = item.package_weight ?? null
  editManualItemForm.vendor_code = matchedProduct?.vendor_code ?? shipmentStore.selectedShipment?.vendor_code ?? null
  editManualItemForm.market_code = matchedProduct?.market_code ?? shipmentStore.selectedShipment?.market_code ?? null
  showEditManualItemDialog.value = true
}

const openItemDetailsDialog = (item: ShipmentItem) => {
  selectedDetailsItemId.value = item.id
  showItemDetailsDialog.value = true
}

const onStatusChange = async (value: ShipmentStatus | null) => {
  const selectedShipment = shipmentStore.selectedShipment
  if (!selectedShipment || !value || value === selectedShipment.status) {
    return
  }

  await shipmentStore.updateShipmentField({
    id: selectedShipment.id,
    field: 'status',
    value,
  })
}

const onStatusMenuSelect = async (value: ShipmentStatus) => {
  if (selectedStatus.value === value) {
    return
  }
  selectedStatus.value = value
  await onStatusChange(value)
}

const statusChipStyle = (status: ShipmentStatus | null | undefined) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'draft') return { backgroundColor: '#efd399', color: '#6a4a14', border: '1px solid #d8b672' }
  if (value === 'order placed') return { backgroundColor: '#c8d8f8', color: '#27487a', border: '1px solid #a9c4f3' }
  if (value === 'proforma generated') return { backgroundColor: '#dccdfa', color: '#4e2d86', border: '1px solid #c6b1f1' }
  if (value === 'payment done') return { backgroundColor: '#bfeadc', color: '#1c5f4b', border: '1px solid #9edcc8' }
  if (value === 'delivery date received') return { backgroundColor: '#bde9f4', color: '#1e5f71', border: '1px solid #9fd8e7' }
  if (value === 'uk warehouse delivery received') return { backgroundColor: '#c4d5fa', color: '#274a8d', border: '1px solid #a9c2f2' }
  if (value === 'air shipment date set') return { backgroundColor: '#f7d6af', color: '#7a4516', border: '1px solid #ecc08f' }
  if (value === 'airport arrival') return { backgroundColor: '#f4c8ba', color: '#7f3420', border: '1px solid #e7ab98' }
  if (value === 'airport released') return { backgroundColor: '#decebf', color: '#5d4635', border: '1px solid #cdb9a8' }
  if (value === 'warehouse received') return { backgroundColor: '#c3e8d2', color: '#1f5d3c', border: '1px solid #9fd4b7' }
  if (value === 'added to inventory') return { backgroundColor: '#b9e3ca', color: '#194f35', border: '1px solid #95cfaf' }
  return { backgroundColor: '#dbe5f3', color: '#3b4b66', border: '1px solid #b9c8dd' }
}

const statusDotColor = (status: ShipmentStatus | null | undefined) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'draft') return '#9a6a24'
  if (value === 'order placed') return '#3f67b3'
  if (value === 'proforma generated') return '#6f4ab2'
  if (value === 'payment done') return '#2f8f72'
  if (value === 'delivery date received') return '#308ca6'
  if (value === 'uk warehouse delivery received') return '#3f67b3'
  if (value === 'air shipment date set') return '#b86d23'
  if (value === 'airport arrival') return '#b65336'
  if (value === 'airport released') return '#7a5e48'
  if (value === 'warehouse received') return '#2f8b5d'
  if (value === 'added to inventory') return '#25784d'
  return '#66758c'
}

const onConfirmAddToInventory = async () => {
  const receipts: ShipmentReceiveItemInput[] = shipmentStore.shipmentItems.map((item) => {
    const r = getOrInitItemReceipt(item)
    const splits: ShipmentReceiveItemSplit[] = []

    if (r.standard > 0) {
      splits.push({ type: 'standard', qty: r.standard, note: null })
    }
    if (r.box_damage > 0) {
      splits.push({ type: 'box_damage', qty: r.box_damage, note: r.box_damage_note || null })
    }
    if (r.expired > 0) {
      splits.push({ type: 'expired', qty: r.expired, note: r.expired_note || null })
    }
    if (r.boxless > 0) {
      splits.push({ type: 'boxless', qty: r.boxless, note: r.boxless_note || null })
    }
    if (r.stolen > 0) {
      splits.push({ type: 'stolen', qty: r.stolen, note: r.stolen_note || null })
    }

    return {
      shipmentItemId: item.id,
      splits,
    }
  })

  const result = await shipmentStore.addShipmentToInventory(receipts)
  if (result.success) {
    showAddToInventoryConfirmDialog.value = false
  }
}

const onSearchProducts = async () => {
  await productStore.fetchProducts({
    page: 1,
    pageSize: 40,
    search: productSearch.value,
    searchField: productSearchField.value,
    vendorCode: productSearchVendorCode.value,
    category: productSearchCategory.value,
    tenantId: authStore.tenantId,
  })
}

const onAddProductToShipment = async (productId: number) => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }
  const quantity = Number(productQuantityById[productId] ?? 1)
  if (!Number.isFinite(quantity) || quantity <= 0) {
    $q.notify({ type: 'warning', message: 'Quantity must be greater than 0.' })
    return
  }

  const result = await shipmentStore.addShipmentItemFromProduct({
    shipment_id: shipmentId.value,
    product_id: productId,
    quantity,
    method: 'manual',
  })

  if (!result.success) {
    return
  }

  resetProductSearchDialog()
}

const onCreateProductAndAddToShipment = async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }

  const isValid = await addProductFormRef.value?.validate()
  if (!isValid) {
    return
  }

  const name = addProductForm.name.trim()
  const quantity = Number(addProductForm.quantity ?? 0)
  const isGbp = shipmentStore.selectedShipment?.is_gbp !== false
  const priceGbp = isGbp ? Number(addProductForm.price_gbp) : 0
  const productWeight = isGbp ? Number(addProductForm.product_weight) : 0
  const packageWeight = isGbp ? Number(addProductForm.package_weight) : 0

  const createProductResult = await productStore.createProduct({
    tenant_id: authStore.tenantId ?? null,
    name,
    image_url: addProductForm.image_url.trim() || null,
    barcode: addProductForm.barcode.trim() || null,
    product_code: addProductForm.product_code.trim() || null,
    price_gbp: priceGbp,
    country_of_origin: null,
    brand: null,
    category: addProductForm.category,
    available_units: null,
    tariff_code: null,
    languages: null,
    batch_code_manufacture_date: null,
    expire_date: null,
    minimum_order_quantity: addProductForm.minimum_order_quantity,
    product_weight: productWeight,
    package_weight: packageWeight,
    vendor_code: addProductForm.vendor_code,
    market_code: addProductForm.market_code,
    is_available: true,
  })

  if (!createProductResult.success || !createProductResult.data?.id) {
    return
  }

  const addResult = await shipmentStore.addShipmentItemFromProduct({
    shipment_id: shipmentId.value,
    product_id: createProductResult.data.id,
    quantity,
    method: 'manual',
  })

  if (!addResult.success || !addResult.data?.id) {
    return
  }

  if (!isGbp && addProductForm.cost_bdt != null) {
    await shipmentStore.updateShipmentItem({
      id: addResult.data.id,
      patch: {
        cost_bdt: Number(addProductForm.cost_bdt),
      },
    })
  }

  showAddProductDialog.value = false
  resetAddProductForm()
}

const loadCategoryOptionsForVendor = async (vendorCode: string | null) => {
  await productStore.fetchCategoryOptions({
    vendorCode: vendorCode ?? null,
    tenantId: authStore.tenantId ?? null,
  })
}

const onSearchVendorChange = async (value: string | null) => {
  productSearchVendorCode.value = value ?? null
  productSearchCategory.value = null
  await loadCategoryOptionsForVendor(productSearchVendorCode.value)
}

const onAddProductVendorChange = async (value: string | null) => {
  addProductForm.vendor_code = value ?? null
  addProductForm.category = null
  await loadCategoryOptionsForVendor(addProductForm.vendor_code)
  await onAddProductDefaultVendorChange(addProductForm.vendor_code)
}

const onAddProductDefaultVendorChange = async (value: string | null) => {
  const shipment = shipmentStore.selectedShipment
  if (!shipment || !Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }
  if ((shipment.vendor_code ?? null) === (value ?? null)) {
    return
  }
  await shipmentStore.updateShipment({
    id: shipmentId.value,
    patch: {
      vendor_code: value ?? null,
    },
  })
}

const onAddProductDefaultMarketChange = async (value: string | null) => {
  const shipment = shipmentStore.selectedShipment
  if (!shipment || !Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }
  if ((shipment.market_code ?? null) === (value ?? null)) {
    return
  }
  await shipmentStore.updateShipment({
    id: shipmentId.value,
    patch: {
      market_code: value ?? null,
    },
  })
}

const onConfirmDelete = async () => {
  const pendingDelete = pendingDeleteItem.value
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0 || !pendingDelete) {
    showDeleteDialog.value = false
    return
  }

  const result = await shipmentStore.deleteShipmentItem({ id: pendingDelete.id })
  if (!result.success) {
    return
  }

  pendingDeleteItem.value = null
  showDeleteDialog.value = false
}

const onSaveManualItemEdit = async () => {
  const item = editingManualItem.value
  if (!item) {
    return
  }

  const isValid = await editManualItemFormRef.value?.validate()
  if (!isValid) {
    return
  }

  const quantity = Math.max(1, Math.floor(Number(editManualItemForm.quantity ?? 1)))

  const patch: Partial<ShipmentItem> = {
    name: editManualItemForm.name.trim(),
    barcode: editManualItemForm.barcode.trim() || null,
    product_code: editManualItemForm.product_code.trim() || null,
    image_url: editManualItemForm.image_url.trim() || null,
    price_gbp: editManualItemForm.price_gbp == null ? null : Number(editManualItemForm.price_gbp),
    cost_bdt: editManualItemForm.cost_bdt == null ? null : Number(editManualItemForm.cost_bdt),
    product_weight:
      editManualItemForm.product_weight == null ? null : Number(editManualItemForm.product_weight),
    package_weight:
      editManualItemForm.package_weight == null ? null : Number(editManualItemForm.package_weight),
  }

  if (canEditQuantity.value) {
    patch.quantity = quantity
  }

  const result = await shipmentStore.updateShipmentItem({
    id: item.id,
    patch,
  })

  if (!result.success) {
    return
  }

  if (item.product_id != null) {
    const productUpdateResult = await productStore.updateProduct({
      id: item.product_id,
      name: editManualItemForm.name.trim(),
      barcode: editManualItemForm.barcode.trim() || null,
      product_code: editManualItemForm.product_code.trim() || null,
      image_url: editManualItemForm.image_url.trim() || null,
      price_gbp: editManualItemForm.price_gbp == null ? null : Number(editManualItemForm.price_gbp),
      product_weight: editManualItemForm.product_weight == null ? null : Number(editManualItemForm.product_weight),
      package_weight: editManualItemForm.package_weight == null ? null : Number(editManualItemForm.package_weight),
      vendor_code: editManualItemForm.vendor_code ?? null,
      market_code: editManualItemForm.market_code ?? null,
    })
    if (!productUpdateResult.success) {
      return
    }
  }

  showEditManualItemDialog.value = false
  editingManualItem.value = null
}

type EditableNumericField =
  | 'price_gbp'
  | 'cost_bdt'
  | 'quantity'
  | 'product_weight'
  | 'package_weight'

const formatDecimal = (value: number | null | undefined) =>
  value == null ? '-' : String(Number(value))

const formatFixed2 = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const roundTo = (value: number, decimals = 0) => {
  const factor = 10 ** decimals
  return Math.round(value * factor) / factor
}

const calculateItemCostBdt = (item: ShipmentItem) => {
  const shipment = shipmentStore.selectedShipment
  if (shipment && !shipment.is_gbp) {
    return item.cost_bdt ?? 0
  }
  return calculateCostBdt({
    productWeight: item.product_weight,
    packageWeight: item.package_weight,
    cargoRate: shipment?.cargo_rate,
    priceGbp: item.price_gbp,
    transactionRate: shipment?.transaction_rate,
    productConversionRate: shipment?.product_conversion_rate,
    cargoConversionRate: shipment?.cargo_conversion_rate,
  })
}

const totals = computed(() => {
  return shipmentStore.shipmentItems.reduce(
    (acc, item) => {
      const itemCostBdt = Number(calculateItemCostBdt(item) ?? 0)
      const itemQuantity = Number(item.quantity ?? 0)
      const productWeight = Number(item.product_weight ?? 0)
      const packageWeight = Number(item.package_weight ?? 0)

      acc.price_gbp += Number(item.price_gbp ?? 0) * itemQuantity
      acc.cost_bdt += itemCostBdt * itemQuantity
      acc.quantity += itemQuantity
      acc.product_weight += productWeight
      acc.package_weight += packageWeight
      acc.total_weight_gm += (productWeight + packageWeight) * itemQuantity
      return acc
    },
    {
      price_gbp: 0,
      cost_bdt: 0,
      quantity: 0,
      product_weight: 0,
      package_weight: 0,
      total_weight_gm: 0,
    },
  )
})

const onNumericPopupSave = async (
  item: ShipmentItem,
  field: EditableNumericField,
  value: string | number | null,
  options?: { decimals?: number },
) => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }

  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed < 0) {
    $q.notify({ type: 'warning', message: 'Value must be 0 or greater.' })
    return
  }

  const normalized =
    field === 'quantity'
      ? Math.floor(parsed)
      : roundTo(parsed, options?.decimals ?? 0)

  const result = await shipmentStore.updateShipmentItem({
    id: item.id,
    patch: {
      [field]: normalized,
    },
  })

  if (!result.success) {
    return
  }

  if ((field === 'product_weight' || field === 'package_weight') && item.product_id != null) {
    const productId = item.product_id
    if (field === 'product_weight') {
      await productStore.updateProduct({
        id: productId,
        product_weight: normalized,
      })
    } else if (field === 'package_weight') {
      await productStore.updateProduct({
        id: productId,
        package_weight: normalized,
      })
    }
  }
}

const onMarkerTagChange = async (
  item: ShipmentItem,
  value: 'price_reviewed' | 'issue' | 'done' | null,
) => {
  const result = await shipmentStore.updateShipmentItem({
    id: item.id,
    patch: {
      marker_tag: value,
    },
  })

  if (!result.success) {
    return
  }
}

const onResetTags = () => {
  if (!shipmentStore.shipmentItems.length) {
    return
  }

  $q.dialog({
    title: 'Reset All Tags',
    message: 'Are you sure you want to reset all item tags to None?',
    cancel: true,
    persistent: true,
    ok: {
      label: 'Reset',
      color: 'warning',
      unelevated: true,
    },
  }).onOk(() => {
    void (async () => {
      const updates = await Promise.allSettled(
        shipmentStore.shipmentItems.map((item) =>
          shipmentStore.updateShipmentItem({
            id: item.id,
            patch: { marker_tag: null },
          }),
        ),
      )

      const failedCount = updates.filter(
        (entry) => entry.status === 'rejected' || (entry.status === 'fulfilled' && !entry.value.success),
      ).length

      if (failedCount > 0) {
        $q.notify({
          type: 'warning',
          message: `${shipmentStore.shipmentItems.length - failedCount} tag(s) reset, ${failedCount} failed.`,
        })
        return
      }

      $q.notify({
        type: 'positive',
        message: 'All tags reset successfully.',
      })
    })()
  })
}

const safeNamePart = (value: string | null | undefined) =>
  (value ?? '')
    .trim()
    .replace(/[^a-zA-Z0-9-_]+/g, '_')
    .replace(/^_+|_+$/g, '')

const downloadShipmentExcel = async () => {
  if (!shipmentStore.shipmentItems.length) {
    $q.notify({ type: 'warning', message: 'No shipment items to export.' })
    return
  }

  const ExcelJS = await import('exceljs')
  const workbook = new ExcelJS.Workbook()
  const sheet = workbook.addWorksheet('Shipment Items')

  const isGbp = shipmentStore.selectedShipment?.is_gbp !== false
  const headers = [
    'SL',
    'Name',
    'Product ID',
    'Barcode',
    'Product Code',
    'Batch Code',
    'Manufacturing Date',
    'Method',
    'Tag',
    ...(isGbp ? ['Price GBP'] : []),
    'Cost BDT',
    'Quantity',
    'Usable (Standard)',
    'Expired / Damaged',
    'Transit Loss',
    ...(isGbp ? ['Product Weight', 'Package Weight'] : []),
  ]

  sheet.addRow(headers)

  sheet.getRow(1).font = { bold: true }
  sheet.views = [{ state: 'frozen', ySplit: 1 }]
  sheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: headers.length },
  }

  shipmentStore.shipmentItems.forEach((item, index) => {
    const batchRows = getMatchedBatchRows(item)
    const uniqueBatchCodes = Array.from(
      new Set(batchRows.map((row) => row.batch_id?.trim()).filter((value): value is string => Boolean(value))),
    )
    const uniqueManufacturingDates = Array.from(
      new Set(
        batchRows
          .map((row) => formatIsoDateToDdMmYyyy(row.manufacturing_date))
          .filter((value) => value !== '-'),
      ),
    )

    sheet.addRow([
      index + 1,
      item.name ?? '',
      item.product_id ?? '',
      item.barcode ?? '',
      item.product_code ?? '',
      uniqueBatchCodes.join(', '),
      uniqueManufacturingDates.join(', '),
      item.method ?? '',
      getTagLabel(item.marker_tag ?? null),
      ...(isGbp ? [Number(item.price_gbp ?? 0)] : []),
      Number(calculateItemCostBdt(item) ?? 0),
      Number(item.quantity ?? 0),
      Number(getReceivedQty(item)),
      Number(getDamagedQty(item)),
      Number(getStolenQty(item)),
      ...(isGbp ? [Number(item.product_weight ?? 0), Number(item.package_weight ?? 0)] : []),
    ])
  })

  sheet.columns = [
    { width: 8 },
    { width: 40 },
    { width: 14 },
    { width: 20 },
    { width: 18 },
    { width: 28 },
    { width: 28 },
    { width: 12 },
    { width: 16 },
    ...(isGbp ? [{ width: 12 }] : []), // Price GBP
    { width: 12 }, // Cost BDT
    { width: 10 }, // Quantity
    { width: 12 }, // Usable
    { width: 12 }, // Expired
    { width: 12 }, // Stolen
    ...(isGbp ? [{ width: 14 }, { width: 14 }] : []), // Product/Package weight
  ]

  const numberColumns = isGbp ? [10, 11, 16, 17] : [10]
  numberColumns.forEach((columnIndex) => {
    sheet.getColumn(columnIndex).numFmt = '#,##0.00'
  })

  const integerColumns = isGbp ? [12, 13, 14, 15] : [11, 12, 13, 14]
  integerColumns.forEach((columnIndex) => {
    sheet.getColumn(columnIndex).numFmt = '#,##0'
  })

  const shipmentCode = safeNamePart(shipmentStore.selectedShipment?.name ?? '') || 'shipment'
  const shipmentIdValue = shipmentStore.selectedShipment?.id ?? shipmentId.value
  const filename = `shipment_${shipmentIdValue}_${shipmentCode}.xlsx`
  const buffer = await workbook.xlsx.writeBuffer()
  const blob = new Blob([buffer], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = filename
  link.click()
  URL.revokeObjectURL(link.href)
}

onMounted(async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }
  try {
    await Promise.all([
      shipmentStore.fetchShipmentById(shipmentId.value),
      shipmentStore.fetchBatchCodePcByShipment(shipmentId.value),
      vendorStore.fetchVendors(authStore.tenantId ?? null),
      marketStore.fetchMarkets(),
    ])
  } finally {
    initialLoading.value = false
  }
})

watch(
  () => shipmentStore.selectedShipment?.status,
  (value) => {
    selectedStatus.value = value ?? 'Draft'
  },
  { immediate: true },
)

watch(showShipmentInfoDialog, (open) => {
  if (!open) {
    shipmentInfoReadOnly.value = false
  }
})

watch(
  () => columnSelectorOptions.value,
  (options) => {
    const allowed = new Set(options.map((option) => option.value))
    visibleColumns.value = visibleColumns.value.filter((column) => allowed.has(column))

    const existing = new Set(visibleColumns.value)
    options.forEach((option) => {
      if (!existing.has(option.value)) {
        visibleColumns.value.push(option.value)
      }
    })
  },
  { immediate: true },
)

watch(showAddItemDialog, (open) => {
  if (!open) {
    resetProductSearchDialog()
  }
})
</script>

<style scoped>
.shipment-details-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.shipment-action-row :deep(.q-btn) {
  min-height: 32px;
  border-radius: 999px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.image-preview-container {
  border: 1px dashed #cfd8dc;
  border-radius: 8px;
  background-color: #fafafa;
  overflow: hidden;
  transition: all 0.3s ease;
}
.image-preview-container:hover {
  border-color: var(--q-primary);
  background-color: #f5f7fa;
}
.image-preview-box {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 200px;
}
.image-preview-placeholder {
  min-height: 200px;
}

.shipment-item-image-box {
  width: 64px;
  height: 64px;
  min-width: 64px;
  min-height: 64px;
  border-radius: 6px;
  overflow: hidden;
  background: #ffffff;
  border: 1px solid #e5e7eb;
}

.shipment-item-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

.shipment-item-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #e5e7eb;
  font-size: 11px;
}

.shipment-item-name-cell {
  white-space: normal;
  word-break: break-word;
  cursor: pointer;
}

.shipment-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.shipment-summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
}

.shipment-summary-card {
  line-height: 1.2;
}

.shipment-name-col {
  width: 200px;
  min-width: 200px;
  max-width: 200px;
}

.shipment-tag-col {
  width: 112px;
  min-width: 112px;
  max-width: 112px;
}

.shipment-tag-chip {
  min-height: 20px;
  height: 20px;
  font-size: 11px;
  line-height: 1;
  padding: 0 8px;
  border-radius: 0;
}

.shipment-tag-dropdown {
  padding: 0;
  min-height: 22px;
  width: 96px;
  min-width: 96px;
  max-width: 96px;
}

.shipment-tag-dropdown :deep(.q-btn-dropdown__arrow) {
  display: none;
}

.shipment-sl-col {
  width: 60px;
  min-width: 60px;
  max-width: 60px;
}

.shipment-image-col {
  width: 88px;
  min-width: 88px;
  max-width: 88px;
}

.shipment-table-scroll-wrap {
  overflow: visible;
}

.shipment-details-table {
  min-width: 0;
  max-width: 100%;
  height: clamp(400px, calc(100vh - 320px), 80vh);
  background: var(--bw-theme-base, #eef2f5);
  overflow: auto;
}

.shipment-details-table :deep(table) {
  table-layout: fixed;
  border-collapse: separate;
  border-spacing: 0;
  min-width: max-content;
  width: max-content;
}

.shipment-details-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
  box-shadow: inset 0 -1px 0 rgba(148, 163, 184, 0.25);
}

.shipment-details-table :deep(thead tr:first-child th) {
  top: 0;
  z-index: 1;
}

.shipment-product-id-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-barcode-col {
  width: 170px;
  min-width: 170px;
  max-width: 170px;
}

.shipment-product-code-col {
  width: 170px;
  min-width: 170px;
  max-width: 170px;
}

.shipment-batch-col {
  width: 220px;
  min-width: 220px;
  max-width: 220px;
  white-space: normal;
}

.shipment-batch-cell {
  cursor: pointer;
}

.shipment-batch-line {
  line-height: 1.25;
  word-break: break-word;
  margin-bottom: 4px;
}

.shipment-batch-line:last-child {
  margin-bottom: 0;
}

.shipment-batch-code {
  display: inline-block;
  font-weight: 700;
  color: #1e3a8a;
  background: #dbeafe;
  border: 1px solid #bfdbfe;
  border-radius: 6px;
  padding: 1px 6px;
}

.shipment-batch-date {
  color: #475569;
}

.shipment-batch-remaining {
  color: #64748b;
  font-size: 12px;
}

.shipment-method-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-price-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-cost-col {
  width: 120px;
  min-width: 120px;
  max-width: 120px;
}

.shipment-product-weight-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-package-weight-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-actions-col {
  width: 140px;
  min-width: 140px;
  max-width: 140px;
}

.shipment-details-table :deep(td.shipment-actions-col) {
  padding-left: 4px;
  padding-right: 8px;
}

.shipment-details-table :deep(td:first-child),
.shipment-details-table :deep(th:first-child) {
  position: sticky;
  left: 0;
}

.shipment-details-table :deep(td:nth-child(2)),
.shipment-details-table :deep(th:nth-child(2)) {
  position: sticky;
  left: 60px;
}

.shipment-details-table :deep(td:nth-child(3)),
.shipment-details-table :deep(th:nth-child(3)) {
  position: sticky;
  left: 148px;
}

.shipment-details-table :deep(td:first-child) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.shipment-details-table :deep(td:nth-child(2)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-details-table :deep(td:nth-child(3)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-details-table :deep(tr:first-child th:first-child) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.shipment-details-table :deep(tr:first-child th:nth-child(2)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-details-table :deep(tr:first-child th:nth-child(3)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-details-table :deep(tbody) {
  scroll-margin-top: 48px;
}

.shipment-qty-col--quantity {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
  background: #eaf7ef;
}

.shipment-qty-col--received {
  width: 130px;
  min-width: 130px;
  max-width: 130px;
  background: #eef4ff;
}

.shipment-qty-col--damaged {
  width: 130px;
  min-width: 130px;
  max-width: 130px;
  background: #fff1f0;
}

.shipment-qty-col--stolen {
  width: 130px;
  min-width: 130px;
  max-width: 130px;
  background: #fff8e9;
}

.shipment-details-table :deep(th.shipment-qty-col--quantity) {
  background: #eaf7ef;
}

.shipment-details-table :deep(th.shipment-qty-col--received) {
  background: #eef4ff;
}

.shipment-details-table :deep(th.shipment-qty-col--damaged) {
  background: #fff1f0;
}

.shipment-details-table :deep(th.shipment-qty-col--stolen) {
  background: #fff8e9;
}

.shipment-form-preview-box {
  width: 96px;
  height: 96px;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  overflow: hidden;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
}

.shipment-form-preview {
  display: flex;
  flex-direction: column;
  align-items: center;
}

:deep(.shipment-form-preview-image) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

:deep(.shipment-form-preview-fallback) {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #746655;
  background: #f3efe9;
  font-size: 0.75rem;
}

.border-subtle {
  border: 1px solid rgba(0, 0, 0, 0.08);
}
.leading-normal {
  line-height: 1.4;
}
.transition-colors {
  transition: color 0.2s ease, opacity 0.2s ease;
}
.hover-opacity:hover {
  opacity: 0.8;
}
</style>
