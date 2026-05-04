<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Shipment"
        @click="onBack"
      />
    </div>

    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5">
        #{{ shipmentStore.selectedShipment?.id }} {{ shipmentStore.selectedShipment?.name }}
      </div>
      <div class="row items-center q-gutter-sm">
        <q-btn
          v-if="canAddToInventory"
          color="positive"
          no-caps
          label="Add To Inventory"
          :disable="isAddToInventoryRateInvalid"
          :loading="shipmentStore.saving"
          @click="showAddToInventoryConfirmDialog = true"
        />
        <q-btn
          color="secondary"
          flat
          no-caps
          icon="info"
          label="Shipment Info"
          aria-label="Open shipment info page"
          @click="goToShipmentInfo"
        >
          <q-tooltip>Open shipment information page</q-tooltip>
        </q-btn>
        <q-btn
          color="secondary"
          flat
          no-caps
          icon="fact_check"
          label="Batch Code"
          aria-label="Open batch code entry page"
          @click="goToBatchCodePage"
        >
          <q-tooltip>Open batch code paste page</q-tooltip>
        </q-btn>
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
        <q-btn flat round dense icon="view_column" aria-label="Select columns">
          <q-menu>
            <q-list style="min-width: 220px">
              <q-item>
                <q-item-section>
                  <div class="text-subtitle2">Show Columns</div>
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

    <div v-if="shipmentStore.selectedShipment" class="q-mb-md row justify-end">
      <q-select
        v-model="selectedStatus"
        :options="statusOptions"
        label="Shipment Status"
        outlined
        dense
        class="shipment-status-select"
        :disable="shipmentStore.saving"
        @update:model-value="onStatusChange"
      />
    </div>

    <q-card
      v-if="shipmentStore.selectedShipment && !initialLoading"
      flat
      bordered
      class="q-mb-md bg-white"
    >
      <q-card-section class="row q-col-gutter-md shipment-summary-grid">
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Quantity</div>
          <div class="text-subtitle1 text-weight-bold">{{ totals.quantity }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Price GBP</div>
          <div class="text-subtitle1 text-weight-bold">{{ formatFixed2(totals.price_gbp) }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Cost BDT</div>
          <div class="text-subtitle1 text-weight-bold">{{ formatFixed2(totals.cost_bdt) }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Weight</div>
          <div class="text-subtitle1 text-weight-bold">{{ formatDecimal(totals.package_weight) }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Received Qty</div>
          <div class="text-subtitle1 text-weight-bold text-positive">{{ totals.received_quantity }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Received Cost BDT</div>
          <div class="text-subtitle1 text-weight-bold text-positive">{{ formatFixed2(totals.received_cost_bdt) }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Damaged Qty</div>
          <div class="text-subtitle1 text-weight-bold text-warning">{{ totals.damaged_quantity }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Damaged Cost BDT</div>
          <div class="text-subtitle1 text-weight-bold text-warning">{{ formatFixed2(totals.damaged_cost_bdt) }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Total Stolen Qty</div>
          <div class="text-subtitle1 text-weight-bold text-negative">{{ totals.stolen_quantity }}</div>
        </div>
        <div class="shipment-summary-card">
          <div class="text-caption text-grey-8">Stolen Cost BDT</div>
          <div class="text-subtitle1 text-weight-bold text-negative">{{ formatFixed2(totals.stolen_cost_bdt) }}</div>
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

    <q-card v-if="!initialLoading" flat bordered>
      <q-card-section class="q-pa-none shipment-table-scroll-wrap">
        <q-markup-table flat class="shipment-details-table">
          <thead>
            <tr>
              <th class="text-right shipment-sl-col">SL</th>
              <th class="text-left shipment-image-col">Image</th>
              <th v-if="isColumnVisible('name')" class="text-left shipment-name-col">Name</th>
              <th v-if="isColumnVisible('method')" class="text-left">Method</th>
              <th v-if="isColumnVisible('price_gbp')" class="text-right">Price GBP</th>
              <th v-if="isColumnVisible('cost_bdt')" class="text-right">Cost BDT</th>
              <th
                v-if="isColumnVisible('quantity')"
                class="text-right shipment-qty-col shipment-qty-col--quantity"
              >
                Quantity
              </th>
              <th
                v-if="!isDraftStatus && isColumnVisible('received_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--received"
              >
                Received Qty
              </th>
              <th
                v-if="!isDraftStatus && isColumnVisible('damaged_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--damaged"
              >
                Damaged Qty
              </th>
              <th
                v-if="!isDraftStatus && isColumnVisible('stolen_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--stolen"
              >
                Stolen Qty
              </th>
              <th v-if="isColumnVisible('product_weight')" class="text-right">Product Wt</th>
              <th v-if="isColumnVisible('package_weight')" class="text-right">Package Wt</th>
              <th v-if="isColumnVisible('actions')" class="text-right">Actions</th>
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
                  />
                </div>
              </td>
              <td
                v-if="isColumnVisible('name')"
                class="shipment-item-name-cell shipment-name-col"
                @click="openItemDetailsDialog(item)"
              >
                {{ item.name ?? '-' }}
              </td>
              <td v-if="isColumnVisible('method')" class="text-uppercase">{{ item.method ?? '-' }}</td>
              <td v-if="isColumnVisible('price_gbp')" class="text-right">
                <span class="cursor-pointer">{{ formatDecimal(item.price_gbp) }}</span>
                <q-popup-edit
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
              <td v-if="isColumnVisible('cost_bdt')" class="text-right">
                {{ formatFixed2(calculateItemCostBdt(item)) }}
              </td>
              <td
                v-if="isColumnVisible('quantity')"
                class="text-right shipment-qty-col shipment-qty-col--quantity"
              >
                <span class="cursor-pointer">{{ item.quantity }}</span>
                <q-popup-edit
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
              <td
                v-if="!isDraftStatus && isColumnVisible('received_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--received"
              >
                <span class="cursor-pointer">{{ item.received_quantity }}</span>
                <q-popup-edit
                  :model-value="toPopupQuantityValue(item.received_quantity)"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'received_quantity', value)"
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
              <td
                v-if="!isDraftStatus && isColumnVisible('damaged_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--damaged"
              >
                <span class="cursor-pointer">{{ item.damaged_quantity }}</span>
                <q-popup-edit
                  :model-value="toPopupQuantityValue(item.damaged_quantity)"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'damaged_quantity', value)"
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
              <td
                v-if="!isDraftStatus && isColumnVisible('stolen_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--stolen"
              >
                <span class="cursor-pointer">{{ item.stolen_quantity }}</span>
                <q-popup-edit
                  :model-value="toPopupQuantityValue(item.stolen_quantity)"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'stolen_quantity', value)"
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
              <td v-if="isColumnVisible('product_weight')" class="text-right">
                <span class="cursor-pointer">{{ formatDecimal(item.product_weight) }}</span>
                <q-popup-edit
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
              <td v-if="isColumnVisible('package_weight')" class="text-right">
                <span class="cursor-pointer">{{ formatDecimal(item.package_weight) }}</span>
                <q-popup-edit
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
              <td v-if="isColumnVisible('actions')" class="text-right">
                <q-btn
                  flat
                  dense
                  color="negative"
                  round
                  icon="delete"
                  @click="openDeleteDialog(item)"
                >
                  <q-tooltip>Delete</q-tooltip>
                </q-btn>
              </td>
            </tr>
            <tr v-if="shipmentStore.shipmentItems.length" class="shipment-total-row">
              <td class="shipment-sl-col"></td>
              <td class="shipment-image-col"></td>
              <td v-if="isColumnVisible('name')" class="shipment-name-col"></td>
              <td v-if="isColumnVisible('method')"></td>
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
              <td
                v-if="!isDraftStatus && isColumnVisible('received_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--received text-weight-bold"
              >
                {{ totals.received_quantity }}
              </td>
              <td
                v-if="!isDraftStatus && isColumnVisible('damaged_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--damaged text-weight-bold"
              >
                {{ totals.damaged_quantity }}
              </td>
              <td
                v-if="!isDraftStatus && isColumnVisible('stolen_quantity')"
                class="text-right shipment-qty-col shipment-qty-col--stolen text-weight-bold"
              >
                {{ totals.stolen_quantity }}
              </td>
              <td v-if="isColumnVisible('product_weight')" class="text-right text-weight-bold">
                {{ formatDecimal(totals.product_weight) }}
              </td>
              <td v-if="isColumnVisible('package_weight')" class="text-right text-weight-bold">
                {{ formatDecimal(totals.package_weight) }}
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

    <q-dialog v-model="showAddProductDialog">
      <q-card style="min-width: 560px; max-width: 92vw">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6">Add Product + Add to Shipment</div>
          <q-btn icon="close" flat round dense @click="showAddProductDialog = false" />
        </q-card-section>

        <q-card-section>
          <q-form ref="addProductFormRef" class="q-gutter-sm">
          <q-input
            v-model="addProductForm.name"
            label="Name *"
            outlined
            dense
            autofocus
            hide-bottom-space
            :rules="[(value: string) => Boolean(value?.trim()) || 'Name is required']"
          />
          <q-input
            v-model.number="addProductForm.quantity"
            label="Quantity *"
            type="number"
            min="1"
            outlined
            dense
            hide-bottom-space
            :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) > 0) || 'Quantity is required']"
          />
          <q-input v-model="addProductForm.barcode" label="Barcode" outlined dense hide-bottom-space />
          <q-input v-model="addProductForm.product_code" label="Product Code" outlined dense hide-bottom-space />
          <q-input
            v-model="addProductForm.image_url"
            label="Image URL *"
            outlined
            dense
            hide-bottom-space
            :rules="[(value: string) => Boolean(value?.trim()) || 'Image URL is required']"
          />
          <q-input
            v-model.number="addProductForm.price_gbp"
            label="Price GBP *"
            type="number"
            outlined
            dense
            hide-bottom-space
            :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) >= 0) || 'Price GBP is required']"
          />
          <q-input
            v-model.number="addProductForm.product_weight"
            label="Product Weight *"
            type="number"
            outlined
            dense
            hide-bottom-space
            :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) >= 0) || 'Product Weight is required']"
          />
          <q-input
            v-model.number="addProductForm.package_weight"
            label="Package Weight *"
            type="number"
            outlined
            dense
            hide-bottom-space
            :rules="[(value: number | null) => (value != null && Number.isFinite(Number(value)) && Number(value) >= 0) || 'Package Weight is required']"
          />
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
            hide-bottom-space
          />
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
            hide-bottom-space
          />
          <q-input
            v-model.number="addProductForm.minimum_order_quantity"
            label="Minimum Order Quantity"
            type="number"
            outlined
            dense
            hide-bottom-space
          />
          </q-form>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" @click="showAddProductDialog = false" />
          <q-btn
            color="primary"
            no-caps
            label="Create & Add"
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

    <q-dialog v-model="showAddToInventoryConfirmDialog" persistent>
      <q-card style="min-width: 420px; max-width: 500px; width: 92vw">
        <q-card-section class="text-h6">Confirm Add To Inventory</q-card-section>
        <q-card-section>
          make sure the weight and received quantity is accurate as this will determint the purches cost in the inventory and based on that accounting entries will be done
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="showAddToInventoryConfirmDialog = false" />
          <q-btn
            color="positive"
            label="Confirm"
            :loading="shipmentStore.saving"
            @click="onConfirmAddToInventory"
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
import { SHIPMENT_STATUS_OPTIONS, type ShipmentItem, type ShipmentStatus } from '../types'

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
const showAddToInventoryConfirmDialog = ref(false)
const showItemDetailsDialog = ref(false)
const initialLoading = ref(true)
const pendingDeleteItem = ref<ShipmentItem | null>(null)
const selectedDetailsItem = ref<ShipmentItem | null>(null)
const selectedStatus = ref<ShipmentStatus>('Draft')
const isDraftStatus = computed(() => selectedStatus.value === 'Draft')
const productSearch = ref('')
const productSearchField = ref<'name' | 'barcode' | 'product_code' | 'id'>('name')
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
  { label: 'Method', value: 'method' },
  { label: 'Price GBP', value: 'price_gbp' },
  { label: 'Cost BDT', value: 'cost_bdt' },
  { label: 'Quantity', value: 'quantity' },
  { label: 'Product Wt', value: 'product_weight' },
  { label: 'Package Wt', value: 'package_weight' },
  { label: 'Actions', value: 'actions' },
] as const

const statusColumnSelectorOptions = [
  { label: 'Received Qty', value: 'received_quantity' },
  { label: 'Damaged Qty', value: 'damaged_quantity' },
  { label: 'Stolen Qty', value: 'stolen_quantity' },
] as const

type ShipmentColumnKey =
  | (typeof baseColumnSelectorOptions)[number]['value']
  | (typeof statusColumnSelectorOptions)[number]['value']

const columnSelectorOptions = computed(() =>
  isDraftStatus.value
    ? baseColumnSelectorOptions
    : [...baseColumnSelectorOptions, ...statusColumnSelectorOptions],
)

const columnSelectorOptionsUi = computed(() =>
  columnSelectorOptions.value.map((option) => ({ ...option })),
)

const visibleColumns = ref<ShipmentColumnKey[]>(
  [...baseColumnSelectorOptions, ...statusColumnSelectorOptions].map((option) => option.value),
)
const addProductFormRef = ref<QForm | null>(null)
const addProductForm = reactive({
  name: '',
  quantity: 1,
  barcode: '',
  product_code: '',
  image_url: '',
  price_gbp: null as number | null,
  product_weight: null as number | null,
  package_weight: null as number | null,
  vendor_code: null as string | null,
  market_code: null as string | null,
  minimum_order_quantity: null as number | null,
})
const vendorOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...vendorStore.items.map((vendor) => ({
    label: `${vendor.name} (${vendor.code})`,
    value: vendor.code,
  })),
])
const marketOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...marketStore.items.map((market) => ({
    label: `${market.name} (${market.code})`,
    value: market.code,
  })),
])

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

  const cargoRate = Number(shipment.cargo_rate ?? 0)
  const productConversionRate = Number(shipment.product_conversion_rate ?? 0)
  const cargoConversionRate = Number(shipment.cargo_conversion_rate ?? 0)

  return cargoRate <= 0 || productConversionRate <= 0 || cargoConversionRate <= 0
})

const isColumnVisible = (column: ShipmentColumnKey) => visibleColumns.value.includes(column)

const shipmentTableColspan = computed(() => {
  const base = 2 // SL + Image are always visible
  return (
    base +
    (isColumnVisible('name') ? 1 : 0) +
    (isColumnVisible('method') ? 1 : 0) +
    (isColumnVisible('price_gbp') ? 1 : 0) +
    (isColumnVisible('cost_bdt') ? 1 : 0) +
    (isColumnVisible('quantity') ? 1 : 0) +
    (!isDraftStatus.value && isColumnVisible('received_quantity') ? 1 : 0) +
    (!isDraftStatus.value && isColumnVisible('damaged_quantity') ? 1 : 0) +
    (!isDraftStatus.value && isColumnVisible('stolen_quantity') ? 1 : 0) +
    (isColumnVisible('product_weight') ? 1 : 0) +
    (isColumnVisible('package_weight') ? 1 : 0) +
    (isColumnVisible('actions') ? 1 : 0)
  )
})

const onBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment`)
}

const goToShipmentInfo = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipmentId.value}/info`)
}

const goToBatchCodePage = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipmentId.value}/batch-code-pc`)
}

const resetProductSearchDialog = () => {
  productSearch.value = ''
  productSearchField.value = 'name'
  Object.keys(productQuantityById).forEach((key) => {
    delete productQuantityById[Number(key)]
  })
  productStore.items = []
}

const openAddItemDialog = () => {
  resetProductSearchDialog()
  showAddItemDialog.value = true
}

const resetAddProductForm = () => {
  addProductForm.name = ''
  addProductForm.quantity = 1
  addProductForm.barcode = ''
  addProductForm.product_code = ''
  addProductForm.image_url = ''
  addProductForm.price_gbp = null
  addProductForm.product_weight = null
  addProductForm.package_weight = null
  addProductForm.vendor_code = null
  addProductForm.market_code = null
  addProductForm.minimum_order_quantity = null
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

const openItemDetailsDialog = (item: ShipmentItem) => {
  selectedDetailsItem.value = item
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

const onConfirmAddToInventory = async () => {
  const result = await shipmentStore.addShipmentToInventory()
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
  })

  if (!result.success) {
    return
  }

  if (result.data?.id) {
    await shipmentStore.updateShipmentItem({
      id: result.data.id,
      patch: {
        method: 'manual',
      },
    })
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
  const priceGbp = Number(addProductForm.price_gbp)
  const productWeight = Number(addProductForm.product_weight)
  const packageWeight = Number(addProductForm.package_weight)

  const createProductResult = await productStore.createProduct({
    tenant_id: authStore.tenantId ?? null,
    name,
    image_url: addProductForm.image_url.trim() || null,
    barcode: addProductForm.barcode.trim() || null,
    product_code: addProductForm.product_code.trim() || null,
    price_gbp: priceGbp,
    country_of_origin: null,
    brand: null,
    category: null,
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
  })

  if (!addResult.success) {
    return
  }

  if (addResult.data?.id) {
    await shipmentStore.updateShipmentItem({
      id: addResult.data.id,
      patch: {
        method: 'manual',
      },
    })
  }

  showAddProductDialog.value = false
  resetAddProductForm()
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

type EditableNumericField =
  | 'price_gbp'
  | 'quantity'
  | 'received_quantity'
  | 'damaged_quantity'
  | 'stolen_quantity'
  | 'product_weight'
  | 'package_weight'

const formatDecimal = (value: number | null | undefined) =>
  value == null ? '-' : String(Number(value))

const formatFixed2 = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const toPopupQuantityValue = (value: number | null | undefined): number | null =>
  value == null || Number(value) === 0 ? null : Number(value)

const roundTo = (value: number, decimals = 0) => {
  const factor = 10 ** decimals
  return Math.round(value * factor) / factor
}

const calculateItemCostBdt = (item: ShipmentItem) => {
  const shipment = shipmentStore.selectedShipment
  return calculateCostBdt({
    productWeight: item.product_weight,
    packageWeight: item.package_weight,
    cargoRate: shipment?.cargo_rate,
    priceGbp: item.price_gbp,
    productConversionRate: shipment?.product_conversion_rate,
    cargoConversionRate: shipment?.cargo_conversion_rate,
  })
}

const totals = computed(() => {
  return shipmentStore.shipmentItems.reduce(
    (acc, item) => {
      const itemCostBdt = Number(calculateItemCostBdt(item) ?? 0)
      const itemQuantity = Number(item.quantity ?? 0)
      const receivedQty = Number(item.received_quantity ?? 0)
      const damagedQty = Number(item.damaged_quantity ?? 0)
      const stolenQty = Number(item.stolen_quantity ?? 0)

      acc.price_gbp += Number(item.price_gbp ?? 0) * itemQuantity
      acc.cost_bdt += itemCostBdt * itemQuantity
      acc.quantity += itemQuantity
      acc.received_quantity += receivedQty
      acc.damaged_quantity += damagedQty
      acc.stolen_quantity += stolenQty
      acc.received_cost_bdt += itemCostBdt * receivedQty
      acc.damaged_cost_bdt += itemCostBdt * damagedQty
      acc.stolen_cost_bdt += itemCostBdt * stolenQty
      acc.product_weight += Number(item.product_weight ?? 0)
      acc.package_weight += Number(item.package_weight ?? 0)
      return acc
    },
    {
      price_gbp: 0,
      cost_bdt: 0,
      quantity: 0,
      received_quantity: 0,
      damaged_quantity: 0,
      stolen_quantity: 0,
      received_cost_bdt: 0,
      damaged_cost_bdt: 0,
      stolen_cost_bdt: 0,
      product_weight: 0,
      package_weight: 0,
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
    field === 'quantity' ||
    field === 'received_quantity' ||
    field === 'damaged_quantity' ||
    field === 'stolen_quantity'
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

onMounted(async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }
  try {
    await Promise.all([
      shipmentStore.fetchShipmentById(shipmentId.value),
      vendorStore.fetchVendors(),
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

.shipment-status-select {
  min-width: 260px;
  width: fit-content;
  max-width: 100%;
}

.shipment-summary-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 16px;
}

.shipment-name-col {
  width: 200px;
  min-width: 200px;
  max-width: 200px;
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

.shipment-details-table :deep(th) {
  background: #fff;
}

.shipment-table-scroll-wrap {
  height: 70vh;
  overflow: auto;
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

.shipment-details-table :deep(td:first-child) {
  z-index: 1;
  background: #fff;
}

.shipment-details-table :deep(td:nth-child(2)) {
  z-index: 1;
  background: #fff;
}

.shipment-details-table :deep(tr:first-child th:first-child) {
  z-index: 3;
}

.shipment-details-table :deep(tr:first-child th:nth-child(2)) {
  z-index: 3;
}

.shipment-qty-col--quantity {
  background: #eaf7ef;
}

.shipment-qty-col--received {
  background: #eef4ff;
}

.shipment-qty-col--damaged {
  background: #fff1f0;
}

.shipment-qty-col--stolen {
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

</style>
