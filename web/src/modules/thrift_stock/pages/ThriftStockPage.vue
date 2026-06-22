<template>
  <q-page class="q-pa-md thrift-stock-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Stock</div>
            <div class="text-caption text-grey-8">Manage bulk and single items, conditions, sizes, boxes, and shelves</div>
          </div>
          <div class="col-12 col-sm-auto row justify-start justify-sm-end q-mt-xs q-mt-sm-none">
            <q-btn
              outline
              color="secondary"
              no-caps
              size="sm"
              class="pill-btn slim-btn q-mr-sm"
              icon="settings"
              label="Settings"
              @click="goToSettings"
            />
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Register Stock"
              @click="openAddDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Filters -->
    <q-card flat class="q-mb-md floating-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row q-col-gutter-sm items-end">
          <div class="col-12 col-md-5">
            <q-input
              v-model="searchText"
              outlined
              dense
              label="Search"
              placeholder="Name, brand, or barcode"
              debounce="400"
              @update:model-value="onFiltersChanged"
            >
              <template #append>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>
          <div class="col-6 col-md-3">
            <q-select
              v-model="statusFilter"
              outlined
              dense
              label="Status"
              :options="statusOptions"
              emit-value
              map-options
              clearable
              @update:model-value="onFiltersChanged"
            />
          </div>
          <div class="col-6 col-md-3">
            <q-select
              v-model="conditionFilter"
              outlined
              dense
              label="Condition"
              :options="conditionOptions"
              emit-value
              map-options
              clearable
              @update:model-value="onFiltersChanged"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="loading && !stocks.length" />

    <!-- Table -->
    <q-card v-else flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="stocks"
        :columns="columns"
        row-key="id"
        v-model:pagination="tablePagination"
        :rows-per-page-options="[10, 20, 50]"
        :loading="loading && stocks.length > 0"
        class="thrift-table"
        @request="onTableRequest"
      >
        <template #loading>
          <PageInitialLoader compact />
        </template>
        <template #body-cell-sl="props">
          <q-td :props="props">
            {{ (tablePagination.page - 1) * tablePagination.rowsPerPage + props.rowIndex + 1 }}
          </q-td>
        </template>
        <template #body-cell-image="props">
          <q-td :props="props">
            <q-avatar square size="40px" class="rounded-borders shadow-1" style="background: #f7f9fc; overflow: hidden;">
              <SmartImage
                :src="props.value"
                :alt="props.row.name || 'Stock image'"
                style="width: 40px; height: 40px;"
                imgClass="full-width full-height"
                :enableEdit="false"
              />
            </q-avatar>
          </q-td>
        </template>
        <template #body-cell-barcode="props">
          <q-td :props="props">
            <span
              v-if="props.value"
              class="text-primary cursor-pointer text-weight-medium"
              @click.stop="openBarcodePreview(props.row)"
            >
              {{ props.value }}
            </span>
            <span v-else class="text-grey-5">—</span>
          </q-td>
        </template>
        <template #body-cell-box="props">
          <q-td :props="props">
            {{ getBoxName(props.row.box_id) }}
          </q-td>
        </template>
        <template #body-cell-product_weight="props">
          <q-td :props="props">
            {{ props.value ? `${props.value} g` : '—' }}
          </q-td>
        </template>
        <template #body-cell-extra_weight="props">
          <q-td :props="props">
            {{ props.value ? `${props.value} g` : '—' }}
          </q-td>
        </template>
        <template #body-cell-status="props">
          <q-td :props="props">
            <q-chip
              dense
              square
              :style="statusChipStyle(props.value)"
              class="thrift-status-chip"
            >
              <span class="status-dot" :style="{ backgroundColor: statusDotColor(props.value) }" />
              {{ props.value ?? 'AVAILABLE' }}
            </q-chip>
          </q-td>
        </template>
        <template #body-cell-pricing="props">
          <q-td :props="props">
            <div v-if="props.value" class="text-caption text-black">
              <span class="text-grey-7">Origin:</span> {{ formatThriftAmount(props.row.origin_purchase_price, shipmentPurchaseCurrency(props.row.shipment_id)) }}
              &nbsp;|&nbsp;
              <span class="text-grey-7">Extra origin:</span> {{ formatThriftAmount(props.row.extra_origin_purchase_expense, shipmentPurchaseCurrency(props.row.shipment_id)) }}
              &nbsp;|&nbsp;
              <span class="text-grey-7">Cost:</span> {{ formatThriftAmount(props.value.cost_of_goods_sold, shipmentCostCurrency(props.row.shipment_id)) }}
              &nbsp;|&nbsp;
              <span class="text-grey-7">Extra cost:</span> {{ formatThriftAmount(props.value.extra_expense_cost, shipmentCostCurrency(props.row.shipment_id)) }}
              &nbsp;|&nbsp;
              <span class="text-grey-7">Listed:</span> {{ formatThriftAmount(props.value.listed_price, shipmentCostCurrency(props.row.shipment_id)) }}
            </div>
            <div v-else class="text-grey-5">—</div>
          </q-td>
        </template>
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn flat round dense icon="o_edit" size="sm" color="primary" @click.stop="openEditDialog(props.row)">
              <q-tooltip>Edit Details</q-tooltip>
            </q-btn>
            <q-btn flat round dense icon="delete" size="sm" color="negative" @click.stop="confirmDelete(props.row)">
              <q-tooltip>Delete Stock</q-tooltip>
            </q-btn>
            <q-btn flat round dense icon="o_report_problem" size="sm" color="warning" @click.stop="updateStatus(props.row.id, 'DAMAGED')">
              <q-tooltip>Mark Damaged</q-tooltip>
            </q-btn>
            <q-btn flat round dense icon="o_block" size="sm" color="negative" @click.stop="updateStatus(props.row.id, 'STOLEN')">
              <q-tooltip>Mark Stolen</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Register Stock Dialog -->
    <q-dialog v-model="dialogOpen" persistent @hide="onEditDialogHide">
      <q-card style="width: 600px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Thrift Stock' : 'Register Thrift Stock' }}</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section>
          <q-form @submit="onSubmit" class="q-gutter-sm q-pt-sm">
            <!-- Product Image -->
            <div>
              <div class="text-caption text-grey-8 q-mb-xs">Product Image</div>
              <div
                v-if="editImage.url"
                class="stock-image-preview relative-position text-center q-pa-sm rounded-borders"
              >
                <q-img
                  :src="editImage.url"
                  style="max-height: 200px; border-radius: 8px;"
                  fit="contain"
                  spinner-color="primary"
                />
                <div class="row justify-center q-gutter-sm q-mt-sm">
                  <q-btn
                    flat
                    dense
                    no-caps
                    color="primary"
                    icon="cloud_upload"
                    label="Replace"
                    @click="openEditUploader"
                  />
                  <q-btn
                    flat
                    dense
                    no-caps
                    color="negative"
                    icon="delete"
                    label="Remove"
                    @click="imageRemoveConfirmOpen = true"
                  />
                </div>
              </div>
              <div
                v-else
                class="stock-image-upload text-center q-pa-lg rounded-borders cursor-pointer"
                @click="openEditUploader"
              >
                <q-icon name="cloud_upload" size="40px" color="primary" />
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mt-xs">Upload Image</div>
                <div class="text-caption text-grey-6">Click to select photo (uploads when you save)</div>
              </div>
            </div>

            <q-separator />

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select v-model="form.shipment_id" outlined dense label="Shipment *" :options="shipments"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']" @update:model-value="onShipmentChange" />
              </div>
              <div class="col-12 col-sm-6">
                <q-select v-model="form.box_id" outlined dense label="Box Number/Name" :options="filteredBoxes"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  clearable />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select v-model="form.category_id" outlined dense label="Category *" :options="categories"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']" />
              </div>
              <div class="col-12 col-sm-6">
                <q-select v-model="form.type_id" outlined dense label="Product Style/Type *" :options="types"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']">
                  <template #option="scope">
                    <q-item v-bind="scope.itemProps">
                      <q-item-section avatar>
                        <q-icon :name="resolveTypeIcon(scope.opt.icon)" />
                      </q-item-section>
                      <q-item-section>{{ scope.opt.name }}</q-item-section>
                    </q-item>
                  </template>
                  <template #selected-item="scope">
                    <span v-if="scope.opt" class="row items-center no-wrap">
                      <q-icon :name="resolveTypeIcon(scope.opt.icon)" class="q-mr-sm" />
                      {{ scope.opt.name }}
                    </span>
                  </template>
                </q-select>
              </div>
            </div>

            <q-input v-model="form.name" outlined dense label="Item Name" class="soft-input" />

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input v-model="form.brand_name" outlined dense label="Brand Name" class="soft-input" />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model="form.barcode" outlined dense label="Barcode *" class="soft-input"
                  :rules="[val => !!val && val.length > 0 || 'Required']" />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-select v-model="form.section" outlined dense label="Section" class="soft-input"
                  :options="['MALE', 'FEMALE', 'UNISEX', 'KIDS', 'HOME']"
                  clearable />
              </div>
              <div class="col-12 col-sm-4">
                <q-select v-model="form.condition" outlined dense label="Condition" class="soft-input"
                  :options="['NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR']"
                  clearable />
              </div>
              <div class="col-12 col-sm-4">
                <q-select v-model="form.shelf_id" outlined dense label="Shelf" class="soft-input"
                  :options="shelves" option-value="id" option-label="shelf_code" emit-value map-options
                  clearable />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input v-model="form.color" outlined dense label="Color" class="soft-input" />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model="form.size" outlined dense label="Size" class="soft-input" />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model.number="form.quantity" type="number" outlined dense label="Quantity *" class="soft-input"
                  :rules="[val => val >= 0 || 'Cannot be negative']" />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input v-model.number="form.product_weight" type="number" step="1" outlined dense label="Product Weight (g)" class="soft-input" />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model.number="form.extra_weight" type="number" step="1" outlined dense label="Extra Weight (g)" class="soft-input" />
              </div>
            </div>

            <q-separator class="q-my-xs" />
            <div class="text-caption text-grey-8 q-mb-xs">Purchase ({{ purchaseCurrency?.code ?? '—' }})</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="originPurchasePrice"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Origin purchase price"
                  :prefix="purchaseCurrencySymbol"
                  class="soft-input"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="extraOriginPurchaseExpense"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Extra origin purchase expense"
                  :prefix="purchaseCurrencySymbol"
                  class="soft-input"
                />
              </div>
            </div>

            <q-separator class="q-my-xs" />
            <div class="text-caption text-grey-8 q-mb-xs">Cost / pricing ({{ costCurrency?.code ?? '—' }})</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="pricing.cost_of_goods_sold"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="COGS Cost"
                  :prefix="costCurrencySymbol"
                  class="soft-input"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="pricing.extra_expense_cost"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Extra expense cost"
                  :prefix="costCurrencySymbol"
                  class="soft-input"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="pricing.target_price"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Target Price"
                  :prefix="costCurrencySymbol"
                  class="soft-input"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="pricing.listed_price"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Listed Price"
                  :prefix="costCurrencySymbol"
                  class="soft-input"
                />
              </div>
            </div>

            <div class="row justify-end q-gutter-sm q-pt-sm">
              <q-btn flat no-caps label="Cancel" v-close-popup />
              <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Stock" type="submit" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Quick Add / Image Upload Dialog -->
    <q-dialog v-model="quickAddDialogOpen" persistent @hide="onQuickAddDialogHide">
      <q-card style="width: 450px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">Quick Register Stock</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />

        <q-card-section class="q-pt-md">
          <div class="q-gutter-md">
            <q-select
              v-model="quickAddForm.shipment_id"
              outlined
              dense
              label="Shipment *"
              :options="shipments"
              option-value="id"
              option-label="name"
              emit-value
              map-options
              class="soft-input"
              @update:model-value="onQuickShipmentChange"
            />

            <q-select
              v-model="quickAddForm.box_id"
              outlined
              dense
              label="Box"
              :options="quickAddFilteredBoxes"
              option-value="id"
              option-label="name"
              emit-value
              map-options
              class="soft-input"
              clearable
              @update:model-value="generateBarcode"
            />

            <!-- Upload Area -->
            <div class="text-center q-pa-md border-dashed rounded-borders bg-grey-1 cursor-pointer" @click="uploaderTarget = 'quick'; isUploaderOpen = true">
              <div v-if="quickAddForm.imagePreviewUrl" class="text-center">
                <q-img :src="quickAddForm.imagePreviewUrl" style="max-height: 180px; border-radius: 8px;" fit="contain" />
                <div class="text-caption text-grey-8 q-mt-sm">Image selected (uploads on submit)</div>
              </div>
              <div v-else class="q-py-md">
                <q-icon name="cloud_upload" size="40px" color="primary" />
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mt-xs">Select Image *</div>
                <div class="text-caption text-grey-6">Click to choose your item photo</div>
              </div>
            </div>

            <!-- Barcode -->
            <div>
              <label class="text-caption text-weight-medium text-grey-8">Auto-Generated Barcode</label>
              <q-input
                v-model="quickAddForm.barcode"
                outlined
                dense
                readonly
                class="soft-input q-mt-xs"
                placeholder="Generating Barcode..."
              />
            </div>

            <!-- Purchase default -->
            <div class="q-pa-sm rounded-borders bg-grey-2 text-caption text-grey-8">
              <div class="row justify-between">
                <span>Default origin purchase:</span>
                <span class="text-weight-bold">{{ formatThriftAmount(settingsStore.defaultOriginPurchasePrice, quickAddPurchaseCurrency) }}</span>
              </div>
            </div>
          </div>
        </q-card-section>

        <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            no-caps
            size="sm"
            class="pill-btn slim-btn px-md"
            label="Submit & Edit Details"
            :loading="quickSubmitting"
            :disabled="!quickAddForm.pendingBlob || !quickAddForm.shipment_id"
            @click="submitQuickAdd"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Delete Confirmation Dialog -->
    <q-dialog v-model="deleteConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw;" class="floating-surface shadow-2 q-pa-md relative-position">
        <q-inner-loading :showing="deleteLoading" color="negative">
          <q-spinner size="40px" color="negative" />
          <div class="text-caption text-grey-8 q-mt-sm">Deleting stock and image...</div>
        </q-inner-loading>
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Stock Item</span>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete stock item <strong>{{ selectedRow?.name }}</strong>? This action cannot be undone.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup :disable="deleteLoading" />
          <q-btn
            color="negative"
            label="Delete"
            :loading="deleteLoading"
            :disable="deleteLoading"
            @click="deleteItem"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Remove Image Confirmation Dialog -->
    <q-dialog v-model="imageRemoveConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center">
          <q-avatar icon="image" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Remove Product Image</span>
        </q-card-section>
        <q-card-section>
          Remove this product image? The change is applied when you save the stock item.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" color="grey-7" v-close-popup />
          <q-btn color="negative" label="Remove" no-caps @click="removeEditImage" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Barcode Preview Dialog -->
    <q-dialog v-model="barcodePreviewOpen">
      <q-card style="min-width: 320px; text-align: center; border-radius: 14px;">
        <q-card-section class="bg-grey-2 q-py-xs text-right">
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-lg">
          <div class="text-overline text-grey-7 q-mb-xs">THRIFT STOCK BARCODE</div>
          <div v-if="previewStockLabel" class="text-caption text-grey-7 q-mb-xs">{{ previewStockLabel }}</div>
          <div class="q-mb-md text-weight-bold text-subtitle1">{{ previewBarcodeValue }}</div>

          <div class="q-my-md q-px-md row justify-center">
            <div class="barcode-preview-frame">
              <BarcodeRenderer
                v-if="previewBarcodeValue"
                :value="previewBarcodeValue"
                :display-value="false"
                :height="48"
              />
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="center" class="q-pb-md">
          <q-btn
            color="primary"
            no-caps
            icon="content_copy"
            label="Copy barcode"
            class="pill-btn"
            @click="copyPreviewBarcode"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Global Cloudinary Uploader Dialog -->
    <CloudinaryUploaderDialog
      v-model="isUploaderOpen"
      folder="thrift-stocks"
      defer-upload
      @selected="onImageSelected"
    />

    <PageInitialLoader v-if="actionLoading" overlay />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftStockStore } from '../stores/thriftStockStore';
import { useThriftStore } from 'src/modules/thrift/stores/thriftStore';
import { useThriftSettingsStore } from 'src/modules/thrift_settings/stores/thriftSettingsStore';
import { useThriftCurrencyStore } from 'src/modules/thrift_currency/stores/thriftCurrencyStore';
import { formatThriftAmount } from 'src/modules/thrift_currency/utils/formatMoney';
import type { ThriftCurrency } from 'src/modules/thrift_currency/types';
import { useQuasar, copyToClipboard, type QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';
import SmartImage from 'src/components/SmartImage.vue';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import BarcodeRenderer from 'src/modules/thrift_barcode/components/BarcodeRenderer.vue';
import type { ThriftStock, ThriftSection, ThriftCondition } from '../types';
import { resolveTypeIcon } from 'src/modules/thrift/utils/typeIcon';
import type { CloudinarySelectedImage } from 'src/components/CloudinaryUploaderDialog.vue';
import {
  deleteCloudinaryImage,
  uploadToCloudinary,
} from 'src/utils/cloudinaryClient';

const $q = useQuasar();
const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const store = useThriftStockStore();
const thriftStore = useThriftStore();
const settingsStore = useThriftSettingsStore();
const currencyStore = useThriftCurrencyStore();

interface ShipmentOption {
  id: number;
  name: string;
  purchase_currency_id: number;
  cost_currency_id: number;
}

// Dialogs state
const dialogOpen = ref(false);
const editingId = ref<number | null>(null);
const quickAddDialogOpen = ref(false);
const isUploaderOpen = ref(false);
const uploaderTarget = ref<'quick' | 'edit'>('quick');
const quickSubmitting = ref(false);
const deleteConfirmOpen = ref(false);
const deleteLoading = ref(false);
const imageRemoveConfirmOpen = ref(false);
const barcodePreviewOpen = ref(false);
const previewBarcodeValue = ref('');
const previewStockLabel = ref('');
const actionLoading = ref(false);
const selectedRow = ref<ThriftStock | null>(null);

const quickAddForm = ref({
  shipment_id: null as number | null,
  box_id: null as number | null,
  barcode: '',
  imagePreviewUrl: '',
  pendingBlob: null as Blob | null,
});

const editImage = ref({
  url: '',
  originalUrl: '',
  pendingBlob: null as Blob | null,
  pendingPreviewUrl: null as string | null,
  removed: false,
});

const stocks = computed(() => store.stocks);
const loading = computed(() => store.loading);

const tablePagination = ref({
  page: 1,
  rowsPerPage: 20,
  rowsNumber: 0,
});
const categories = computed(() => thriftStore.categories);
const types = computed(() => thriftStore.types);
const shelves = computed(() => thriftStore.shelves);

const form = ref({
  category_id: null as number | null,
  type_id: null as number | null,
  shipment_id: null as number | null,
  box_id: null as number | null,
  name: '',
  brand_name: '',
  barcode: '',
  section: 'UNISEX' as ThriftSection | null,
  shelf_id: null as number | null,
  color: '',
  size: '',
  condition: 'EXCELLENT' as ThriftCondition | null,
  quantity: 1,
  product_weight: 250,
  extra_weight: 0,
  note: '',
});

const originPurchasePrice = ref(0);
const extraOriginPurchaseExpense = ref(0);

const purchaseCurrency = computed(() => {
  const shipmentId = form.value.shipment_id;
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
});
const costCurrency = computed(() => {
  const shipmentId = form.value.shipment_id;
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.cost_currency_id);
});
const purchaseCurrencySymbol = computed(() => purchaseCurrency.value?.symbol ?? '');
const costCurrencySymbol = computed(() => costCurrency.value?.symbol ?? '');

const quickAddPurchaseCurrency = computed(() => {
  const shipmentId = quickAddForm.value.shipment_id;
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
});

const shipments = ref<ShipmentOption[]>([]);

const shipmentById = computed(() => {
  const map = new Map<number, ShipmentOption>();
  for (const shipment of shipments.value) {
    map.set(shipment.id, shipment);
  }
  return map;
});

function shipmentPurchaseCurrency(shipmentId: number | null | undefined): ThriftCurrency | undefined {
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
}

function shipmentCostCurrency(shipmentId: number | null | undefined): ThriftCurrency | undefined {
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.cost_currency_id);
}

async function loadShipments() {
  if (!authStore.tenantId) return;
  const { data } = await supabase
    .from('thrift_shipments')
    .select('id, name, purchase_currency_id, cost_currency_id')
    .eq('tenant_id', authStore.tenantId)
    .order('name', { ascending: true });
  shipments.value = (data || []) as ShipmentOption[];
}

const filteredBoxes = computed(() => {
  if (!form.value.shipment_id) return [];
  return thriftStore.boxes.filter(b => b.shipment_id === form.value.shipment_id);
});

const quickAddFilteredBoxes = computed(() => {
  if (!quickAddForm.value.shipment_id) return [];
  return thriftStore.boxes.filter(b => b.shipment_id === quickAddForm.value.shipment_id);
});

function onShipmentChange() {
  form.value.box_id = null;
}

function onQuickShipmentChange() {
  quickAddForm.value.box_id = null;
  void generateBarcode();
}

function getBoxName(boxId: number | undefined | null) {
  if (!boxId) return '—';
  const bx = thriftStore.boxes.find(b => b.id === boxId);
  return bx ? bx.name : `#${boxId}`;
}

const pricing = ref({
  cost_of_goods_sold: 0,
  target_price: 0,
  listed_price: 0,
  extra_expense_cost: 0,
});

const searchText = ref('');
const statusFilter = ref<string | null>(null);
const conditionFilter = ref<string | null>(null);

const statusOptions = [
  { label: 'Available', value: 'AVAILABLE' },
  { label: 'Out of Stock', value: 'OUT_OF_STOCK' },
  { label: 'Damaged', value: 'DAMAGED' },
  { label: 'Stolen', value: 'STOLEN' },
];

const conditionOptions = [
  { label: 'New With Tags', value: 'NEW_WITH_TAGS' },
  { label: 'Excellent', value: 'EXCELLENT' },
  { label: 'Good', value: 'GOOD' },
  { label: 'Fair', value: 'FAIR' },
];

const columns: QTableColumn[] = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'center', sortable: false, headerStyle: 'width: 50px' },
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true, headerStyle: 'width: 70px' },
  { name: 'image', align: 'center', label: 'Image', field: 'image_url' },
  { name: 'barcode', align: 'left', label: 'Barcode', field: 'barcode', sortable: true },
  { name: 'name', align: 'left', label: 'Name', field: 'name', sortable: true },
  { name: 'brand_name', align: 'left', label: 'Brand', field: 'brand_name' },
  { name: 'section', align: 'left', label: 'Section', field: 'section' },
  { name: 'size', align: 'left', label: 'Size', field: 'size' },
  { name: 'box', align: 'left', label: 'Box', field: 'box' },
  { name: 'product_weight', align: 'right', label: 'Product Wt', field: 'product_weight' },
  { name: 'extra_weight', align: 'right', label: 'Extra Wt', field: 'extra_weight' },
  { name: 'condition', align: 'left', label: 'Condition', field: 'condition' },
  { name: 'quantity', align: 'right', label: 'Qty', field: 'quantity', sortable: true },
  { name: 'pricing', align: 'left', label: 'Pricing', field: 'pricing' },
  { name: 'status', align: 'center', label: 'Status', field: 'status', sortable: true },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await Promise.all([
      loadStockPage(1),
      thriftStore.loadModuleData(authStore.tenantId),
      loadShipments(),
      settingsStore.loadSettings(authStore.tenantId),
      currencyStore.loadCurrencies(),
    ]);
  }
});

function syncTablePagination() {
  tablePagination.value.page = store.page;
  tablePagination.value.rowsPerPage = store.pageSize;
  tablePagination.value.rowsNumber = store.total;
}

async function loadStockPage(nextPage = store.page) {
  if (!authStore.tenantId) return;
  await store.loadStocks(authStore.tenantId, {
    page: nextPage,
    pageSize: tablePagination.value.rowsPerPage,
    search: searchText.value,
    status: statusFilter.value,
    condition: conditionFilter.value,
  });
  syncTablePagination();
}

function onFiltersChanged() {
  void loadStockPage(1);
}

async function onTableRequest(props: { pagination: { page: number; rowsPerPage: number } }) {
  tablePagination.value.rowsPerPage = props.pagination.rowsPerPage;
  await loadStockPage(props.pagination.page);
}

function goToSettings() {
  const slug = route.params.tenantSlug || authStore.tenantSlug;
  const tenantSlug = Array.isArray(slug) ? slug[0] : slug;
  void router.push(tenantSlug ? `/${tenantSlug}/app/thrift/settings` : '/app/thrift/settings');
}

async function generateBarcode() {
  if (!authStore.tenantId || !quickAddForm.value.shipment_id) return;

  const tenantId = authStore.tenantId;
  const shipmentId = quickAddForm.value.shipment_id;
  const boxId = quickAddForm.value.box_id || 0;

  try {
    let query = supabase
      .from('thrift_stocks')
      .select('*', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('shipment_id', shipmentId);

    if (quickAddForm.value.box_id) {
      query = query.eq('box_id', quickAddForm.value.box_id);
    } else {
      query = query.is('box_id', null);
    }

    const { count, error } = await query;
    if (error) throw error;

    const seq = (count || 0) + 1;
    const formattedSeq = String(seq).padStart(4, '0');

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let rand = '';
    for (let i = 0; i < 3; i++) {
      rand += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    quickAddForm.value.barcode = `${tenantId}-${shipmentId}-${boxId}-${formattedSeq}-${rand}`;
  } catch (err) {
    console.error('Failed to generate barcode:', err);
    quickAddForm.value.barcode = `BC-FALLBACK-${Math.floor(Math.random() * 90000 + 10000)}`;
  }
}


async function openAddDialog() {
  quickAddForm.value = {
    shipment_id: null,
    box_id: null,
    barcode: '',
    imagePreviewUrl: '',
    pendingBlob: null,
  };
  uploaderTarget.value = 'quick';
  if (authStore.tenantId) {
    await settingsStore.loadSettings(authStore.tenantId);
  }
  quickAddDialogOpen.value = true;
}

function stockImageFileName(stockId: number) {
  return `stock-${stockId}-${Date.now()}.jpg`;
}

function revokeBlobPreview(url: string) {
  if (url?.startsWith('blob:')) {
    URL.revokeObjectURL(url);
  }
}

function clearPendingEditImage() {
  if (editImage.value.pendingPreviewUrl) {
    revokeBlobPreview(editImage.value.pendingPreviewUrl);
  }
  editImage.value.pendingBlob = null;
  editImage.value.pendingPreviewUrl = null;
}

async function uploadStockImage(stockId: number, blob: Blob): Promise<string> {
  const result = await uploadToCloudinary(blob, stockImageFileName(stockId));
  return result.secureUrl;
}

function onQuickImageSelected(payload: CloudinarySelectedImage) {
  if (quickAddForm.value.imagePreviewUrl?.startsWith('blob:')) {
    revokeBlobPreview(quickAddForm.value.imagePreviewUrl);
  }
  quickAddForm.value.imagePreviewUrl = payload.previewUrl;
  quickAddForm.value.pendingBlob = payload.blob;
}

function openEditUploader() {
  uploaderTarget.value = 'edit';
  isUploaderOpen.value = true;
}

function onEditImageSelected(payload: CloudinarySelectedImage) {
  clearPendingEditImage();
  editImage.value.url = payload.previewUrl;
  editImage.value.pendingBlob = payload.blob;
  editImage.value.pendingPreviewUrl = payload.previewUrl;
  editImage.value.removed = false;
}

function onImageSelected(payload: CloudinarySelectedImage) {
  if (uploaderTarget.value === 'edit') {
    onEditImageSelected(payload);
  } else {
    onQuickImageSelected(payload);
  }
}

function removeEditImage() {
  clearPendingEditImage();
  editImage.value.url = '';
  editImage.value.removed = true;
  imageRemoveConfirmOpen.value = false;
}

function openBarcodePreview(row: ThriftStock) {
  const barcode = row.barcode?.trim();
  if (!barcode) return;

  previewBarcodeValue.value = barcode;
  previewStockLabel.value = [row.name, row.brand_name].filter(Boolean).join(' · ');
  barcodePreviewOpen.value = true;
}

async function copyPreviewBarcode() {
  const text = previewBarcodeValue.value.trim();
  if (!text) return;

  await copyToClipboard(text);
  $q.notify({
    type: 'positive',
    message: 'Barcode copied',
    position: 'top-right',
  });
}

function resetEditImage() {
  clearPendingEditImage();
  editImage.value = {
    url: '',
    originalUrl: '',
    pendingBlob: null,
    pendingPreviewUrl: null,
    removed: false,
  };
}

function onQuickAddDialogHide() {
  if (quickAddForm.value.imagePreviewUrl?.startsWith('blob:')) {
    revokeBlobPreview(quickAddForm.value.imagePreviewUrl);
  }
  quickAddForm.value.imagePreviewUrl = '';
  quickAddForm.value.pendingBlob = null;
}

function onEditDialogHide() {
  if (editImage.value.pendingPreviewUrl) {
    revokeBlobPreview(editImage.value.pendingPreviewUrl);
    editImage.value.pendingBlob = null;
    editImage.value.pendingPreviewUrl = null;
    if (!editImage.value.removed) {
      editImage.value.url = editImage.value.originalUrl;
    }
  }
}

async function submitQuickAdd() {
  if (!authStore.tenantId || !quickAddForm.value.shipment_id || !quickAddForm.value.pendingBlob) return;

  quickSubmitting.value = true;
  const pendingBlob = quickAddForm.value.pendingBlob;
  let uploadedImageUrl = '';

  try {
    const barcode = quickAddForm.value.barcode;

    const catId = categories.value.find(c => c.name === 'Women Clothing')?.id ?? categories.value[0]?.id;
    const typId = types.value[0]?.id;

    if (!catId || !typId) {
      throw new Error('Category or type is not available. Please refresh and try again.');
    }

    const draftStock = await store.createStock(
      authStore.tenantId,
      quickAddForm.value.shipment_id,
      '',
      '',
      catId,
      typId,
      'UNISEX',
      '',
      '',
      'EXCELLENT',
      barcode,
      'SINGLE',
      1,
      quickAddForm.value.box_id || undefined,
      250,
      0,
      'Quick register draft entry',
      authStore.user?.email || 'admin@brandwala.com',
      {
        cost_of_goods_sold: 0,
        target_price: 0,
        listed_price: 0,
        extra_expense_cost: 0,
      },
      undefined,
      shelves.value[0]?.id ?? null,
      settingsStore.defaultOriginPurchasePrice,
      0,
    );

    uploadedImageUrl = await uploadStockImage(draftStock.id, pendingBlob);
    await store.attachStockImage(
      draftStock.id,
      uploadedImageUrl,
      draftStock.inserted_by,
    );

    $q.notify({
      type: 'positive',
      message: 'Draft created. Please complete other details.',
    });

    quickAddForm.value.imagePreviewUrl = '';
    quickAddForm.value.pendingBlob = null;
    quickAddDialogOpen.value = false;

    openEditDialog({ ...draftStock, image_url: uploadedImageUrl });
  } catch (err: unknown) {
    if (uploadedImageUrl) {
      await deleteCloudinaryImage(uploadedImageUrl);
    }
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Draft creation failed',
    });
  } finally {
    quickSubmitting.value = false;
  }
}

function openEditDialog(row: ThriftStock) {
  editingId.value = row.id;
  editImage.value = {
    url: row.image_url || '',
    originalUrl: row.image_url || '',
    pendingBlob: null,
    pendingPreviewUrl: null,
    removed: false,
  };
  form.value = {
    category_id: row.category_id,
    type_id: row.type_id,
    shipment_id: row.shipment_id,
    box_id: row.box_id || null,
    name: row.name,
    brand_name: row.brand_name || '',
    barcode: row.barcode,
    section: row.section,
    shelf_id: row.shelf_id ?? null,
    color: row.color,
    size: row.size,
    condition: row.condition,
    quantity: row.quantity,
    product_weight: row.product_weight || 0,
    extra_weight: row.extra_weight || 0,
    note: row.note || '',
  };
  originPurchasePrice.value = row.origin_purchase_price ?? settingsStore.defaultOriginPurchasePrice;
  extraOriginPurchaseExpense.value = row.extra_origin_purchase_expense ?? 0;
  pricing.value = {
    cost_of_goods_sold: row.pricing?.cost_of_goods_sold || 0,
    target_price: row.pricing?.target_price || 0,
    listed_price: row.pricing?.listed_price || 0,
    extra_expense_cost: row.pricing?.extra_expense_cost || 0,
  };
  dialogOpen.value = true;
}

async function updateStatus(stockId: number, status: string) {
  actionLoading.value = true;
  try {
    await store.updateStockStatus(stockId, status);
    $q.notify({ type: 'positive', message: `Stock marked as ${status}` });
    await loadStockPage();
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Update failed' });
  } finally {
    actionLoading.value = false;
  }
}

function confirmDelete(row: ThriftStock) {
  selectedRow.value = row;
  deleteConfirmOpen.value = true;
}

async function deleteItem() {
  if (!selectedRow.value || deleteLoading.value) return;
  deleteLoading.value = true;
  const imageUrl = selectedRow.value.image_url || '';
  try {
    await store.deleteStock(selectedRow.value.id);
    if (imageUrl) {
      await deleteCloudinaryImage(imageUrl);
    }
    $q.notify({ type: 'positive', message: 'Stock item deleted successfully' });
    deleteConfirmOpen.value = false;
    selectedRow.value = null;
    await loadStockPage();
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Delete failed' });
  } finally {
    deleteLoading.value = false;
  }
}

async function onSubmit() {
  if (!authStore.tenantId) return;
  actionLoading.value = true;
  let orphanImageUrl = '';

  try {
    const stockData = {
      shipment_id: form.value.shipment_id!,
      name: form.value.name,
      brand_name: form.value.brand_name,
      category_id: form.value.category_id!,
      type_id: form.value.type_id!,
      section: form.value.section,
      shelf_id: form.value.shelf_id,
      color: form.value.color,
      size: form.value.size,
      condition: form.value.condition,
      barcode: form.value.barcode,
      quantity: form.value.quantity,
      box_id: form.value.box_id || undefined,
      product_weight: form.value.product_weight || undefined,
      extra_weight: form.value.extra_weight || undefined,
      note: form.value.note,
      origin_purchase_price: originPurchasePrice.value || undefined,
      extra_origin_purchase_expense: extraOriginPurchaseExpense.value || undefined,
    };

    if (editingId.value) {
      const imageChanged = editImage.value.removed || !!editImage.value.pendingBlob;
      let imagePayload: string | null | undefined;
      const previousImageUrl = editImage.value.originalUrl;

      if (editImage.value.removed) {
        imagePayload = null;
      } else if (editImage.value.pendingBlob) {
        const uploadedUrl = await uploadStockImage(editingId.value, editImage.value.pendingBlob);
        orphanImageUrl = uploadedUrl;
        imagePayload = uploadedUrl;
      }

      await store.updateStock(
        editingId.value,
        stockData satisfies Partial<ThriftStock>,
        pricing.value,
        imageChanged ? imagePayload : undefined,
      );

      if (imageChanged && previousImageUrl) {
        await deleteCloudinaryImage(previousImageUrl);
      }

      orphanImageUrl = '';
      $q.notify({ type: 'positive', message: 'Thrift stock updated successfully' });
    } else {
      const created = await store.createStock(
        authStore.tenantId,
        form.value.shipment_id!,
        form.value.name,
        form.value.brand_name,
        form.value.category_id!,
        form.value.type_id!,
        form.value.section || 'UNISEX',
        form.value.color,
        form.value.size,
        form.value.condition || 'EXCELLENT',
        form.value.barcode,
        'SINGLE',
        form.value.quantity,
        form.value.box_id || undefined,
        form.value.product_weight || undefined,
        form.value.extra_weight || undefined,
        form.value.note,
        authStore.user?.email || 'admin@brandwala.com',
        pricing.value,
        undefined,
        form.value.shelf_id,
        originPurchasePrice.value || undefined,
        extraOriginPurchaseExpense.value || undefined,
      );

      if (editImage.value.pendingBlob && !editImage.value.removed) {
        const uploadedUrl = await uploadStockImage(created.id, editImage.value.pendingBlob);
        orphanImageUrl = uploadedUrl;
        await store.attachStockImage(created.id, uploadedUrl, created.inserted_by);
      }

      orphanImageUrl = '';
      $q.notify({ type: 'positive', message: 'Thrift stock registered successfully' });
    }
    resetEditImage();
    dialogOpen.value = false;
    await loadStockPage();
  } catch (err: unknown) {
    if (orphanImageUrl) {
      await deleteCloudinaryImage(orphanImageUrl);
    }
    $q.notify({ type: 'negative', message: (err as Error).message || 'Saving failed' });
  } finally {
    actionLoading.value = false;
  }
}

const normalizeStatus = (status: string | null | undefined) =>
  (status ?? '').trim().toUpperCase() || 'AVAILABLE'

const statusChipStyle = (status: string | null | undefined) => {
  const v = normalizeStatus(status)
  if (v === 'AVAILABLE') return { backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #6ee7b7' }
  if (v === 'OUT_OF_STOCK') return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' }
  if (v === 'DAMAGED') return { backgroundColor: '#fef3c7', color: '#92400e', border: '1px solid #fcd34d' }
  if (v === 'STOLEN') return { backgroundColor: '#fee2e2', color: '#7f1d1d', border: '1px solid #fca5a5' }
  return { backgroundColor: '#e5e7eb', color: '#374151', border: '1px solid #d1d5db' }
}

const statusDotColor = (status: string | null | undefined) => {
  const v = normalizeStatus(status)
  if (v === 'AVAILABLE') return '#059669'
  if (v === 'OUT_OF_STOCK') return '#9ca3af'
  if (v === 'DAMAGED') return '#d97706'
  if (v === 'STOLEN') return '#dc2626'
  return '#9ca3af'
}
</script>

<style scoped>
.thrift-stock-page {
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

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.thrift-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.stock-image-preview {
  border: 1px solid rgba(34, 56, 101, 0.1);
  background: rgba(247, 249, 252, 0.8);
}

.stock-image-upload {
  border: 2px dashed rgba(34, 56, 101, 0.2);
  background: rgba(247, 249, 252, 0.6);
  transition: border-color 0.2s ease, background 0.2s ease;
}

.stock-image-upload:hover {
  border-color: var(--q-primary);
  background: rgba(var(--q-primary-rgb, 25, 118, 210), 0.04);
}

.border-dashed {
  border: 2px dashed rgba(34, 56, 101, 0.2);
}

.barcode-preview-frame {
  width: 100%;
  max-width: 280px;
  border: 1px solid #e0e0e0;
  padding: 12px;
  border-radius: 8px;
  background: #fff;
}
</style>
