<template>
  <div class="shipment-line-items">
    <q-card-section class="q-pa-none shipment-table-scroll-wrap">
      <q-inner-loading :showing="loading" />
      <q-markup-table flat class="shipment-details-table" :class="{ 'is-editable': isEditable }">
        <thead>
          <tr>
            <th class="text-center shipment-select-col">
              <q-checkbox
                :model-value="allSelected"
                :indeterminate="isIndeterminate"
                dense
                size="sm"
                @update:model-value="toggleSelectAll"
              />
            </th>
            <th class="text-right shipment-sl-col">SL</th>
            <th class="text-left shipment-image-col">Image</th>
            <th v-if="isColumnVisible('name')" class="text-left shipment-name-col">Name</th>

            <th
              v-if="isColumnVisible('product_codes')"
              class="text-left shipment-codes-col"
            >
              Codes
            </th>
            <th
              v-if="isColumnVisible('section')"
              class="text-left shipment-section-col"
            >
              Section / Vendor
            </th>
            <th v-if="isColumnVisible('purchase_price')" class="text-center shipment-price-col bw-ops-col-tint--price">
              Price {{ purchaseCurrencySymbol }}
            </th>
            <th v-if="isColumnVisible('cost_bdt')" class="text-center shipment-cost-col bw-ops-col-tint--cost">
              Cost {{ costCurrencySymbol }}
            </th>
            <th
              v-if="isColumnVisible('ordered_quantity')"
              class="text-center shipment-qty-col shipment-qty-col--quantity bw-ops-col-tint--qty"
            >
              Ordered Quantity
            </th>
            <th
              v-if="isColumnVisible('product_weight')"
              class="text-center shipment-product-weight-col"
            >
              Product Wt
            </th>
            <th
              v-if="isColumnVisible('package_weight')"
              class="text-center shipment-package-weight-col bw-ops-col-tint--weight"
            >
              Package Wt
            </th>
            <th v-if="isColumnVisible('actions')" class="text-right shipment-actions-col">
              Actions
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, index) in items" :key="item.id" :class="{ 'row-selected': isItemSelected(item.id) }">
            <td class="text-center shipment-select-col">
              <q-checkbox
                :model-value="isItemSelected(item.id)"
                dense
                size="sm"
                @update:model-value="(val) => toggleItemSelection(item.id, !!val)"
              />
            </td>
            <td class="text-right shipment-sl-col">
              <div class="row items-center justify-end no-wrap">
                <span
                  :class="{ 'cursor-pointer': isEditable, 'text-underline-dashed': isEditable }"
                  >{{ index + 1 }}</span
                >
                <q-popup-edit
                  v-if="isEditable"
                  :model-value="index + 1"
                  buttons
                  persistent
                  label-set="Move"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(val) => moveItemToPosition(index, val)"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    type="number"
                    dense
                    outlined
                    autofocus
                    min="1"
                    :max="items.length"
                    label="New SL Position"
                    @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                    @keyup.enter="scope.set"
                  />
                </q-popup-edit>
                <div v-if="isEditable" class="column items-center justify-center q-ml-xs">
                  <q-btn
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-caret-up"
                    :disable="index === 0"
                    class="q-my-none"
                    style="height: 14px; min-height: 14px"
                    @click="moveItem(index, 'up')"
                  >
                    <q-tooltip>Move Up</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-caret-down"
                    :disable="index === items.length - 1"
                    class="q-my-none"
                    style="height: 14px; min-height: 14px"
                    @click="moveItem(index, 'down')"
                  >
                    <q-tooltip>Move Down</q-tooltip>
                  </q-btn>
                </div>
              </div>
            </td>
            <td class="shipment-image-col">
              <div class="shipment-item-image-box">
                <SmartImage
                  :src="item.image_url"
                  alt="shipment item"
                  img-class="shipment-item-image"
                  fallback-class="shipment-item-image-fallback"
                  :enable-edit="false"
                />
              </div>
            </td>
            <td
              v-if="isColumnVisible('name')"
              class="shipment-item-name-cell shipment-name-col cursor-pointer"
              @click="emit('edit-details', item)"
            >
              {{ item.name ?? '-' }}
            </td>

            <td
              v-if="isColumnVisible('product_codes')"
              class="shipment-codes-col font-mono text-caption"
            >
              <div class="column q-gutter-y-2xs" style="line-height: 1.1">
                <div v-if="item.product_code" class="row items-center justify-between no-wrap">
                  <div class="ellipsis">
                    <span class="text-grey-6 text-uppercase" style="font-size: 8px">C: </span>
                    <b class="text-dark" style="font-size: 10px">{{ item.product_code }}</b>
                  </div>
                  <q-btn
                    flat
                    dense
                    round
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-7"
                    style="font-size: 9px; padding: 0"
                    @click.stop="copyToClipboard(item.product_code, 'Product Code')"
                  >
                    <q-tooltip>Copy Code</q-tooltip>
                  </q-btn>
                </div>

                <div v-if="item.barcode" class="row items-center justify-between no-wrap">
                  <div class="ellipsis">
                    <span class="text-grey-6 text-uppercase" style="font-size: 8px">B: </span>
                    <span class="text-grey-9" style="font-size: 10px">{{ item.barcode }}</span>
                  </div>
                  <q-btn
                    flat
                    dense
                    round
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-7"
                    style="font-size: 9px; padding: 0"
                    @click.stop="copyToClipboard(item.barcode, 'Barcode')"
                  >
                    <q-tooltip>Copy Barcode</q-tooltip>
                  </q-btn>
                </div>

                <div v-if="item.product_id" class="row items-center justify-between no-wrap">
                  <div class="ellipsis">
                    <span class="text-grey-6 text-uppercase" style="font-size: 8px">ID: </span>
                    <span class="text-grey-8" style="font-size: 10px">{{ item.product_id }}</span>
                  </div>
                  <q-btn
                    flat
                    dense
                    round
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-7"
                    style="font-size: 9px; padding: 0"
                    @click.stop="copyToClipboard(item.product_id, 'Product ID')"
                  >
                    <q-tooltip>Copy ID</q-tooltip>
                  </q-btn>
                </div>

                <div v-if="item.add_method">
                  <span
                    class="text-uppercase text-weight-medium bg-grey-3 text-grey-8 q-px-xs rounded-borders"
                    style="font-size: 9px"
                  >
                    {{ item.add_method }}
                  </span>
                </div>
              </div>
            </td>

            <td
              v-if="isColumnVisible('section')"
              class="shipment-section-col font-mono text-caption"
            >
              <div class="column q-gutter-y-2xs" style="line-height: 1.2">
                <div class="row items-center no-wrap q-gutter-x-xs">
                  <span class="text-weight-bold text-grey-9 ellipsis" style="max-width: 140px">
                    {{ getSectionTitle(item.section_id) }}
                  </span>
                </div>
                <div v-if="getSectionVendorName(item.section_id)" class="ellipsis text-grey-6" style="font-size: 10px; max-width: 140px">
                  {{ getSectionVendorName(item.section_id) }}
                </div>
              </div>
            </td>

            <td v-if="isColumnVisible('purchase_price')" class="text-center shipment-price-col bw-ops-col-tint--price">
              <div>
                <q-input
                  v-if="isEditable"
                  :model-value="getDraftValue(item, 'purchase_price')"
                  type="number"
                  step="0.01"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-edit-input"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'purchase_price', val)"
                  @blur="saveDraftValue(item, 'purchase_price', { decimals: 2 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
                <span v-else>{{ formatPrice(item.purchase_price) }}</span>
              </div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-xs" style="font-size: 10px">
                T: {{ formatFixed2((item.purchase_price || 0) * (item.ordered_quantity || 0)) }}
              </div>
            </td>
            <td v-if="isColumnVisible('cost_bdt')" class="text-center shipment-cost-col bw-ops-col-tint--cost">
              <div>{{ formatFixed2(lineCostBdt(item)) }}</div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-xs" style="font-size: 10px">
                T: {{ formatFixed2(lineCostBdt(item) * (item.ordered_quantity || 0)) }}
              </div>
            </td>
            <td
              v-if="isColumnVisible('ordered_quantity')"
              class="text-center shipment-qty-col shipment-qty-col--quantity bw-ops-col-tint--qty"
            >
              <div>
                <q-input
                  v-if="isEditable"
                  :model-value="getDraftValue(item, 'ordered_quantity')"
                  type="number"
                  min="1"
                  step="1"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-edit-input"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'ordered_quantity', val)"
                  @blur="saveDraftValue(item, 'ordered_quantity')"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
                <span v-else>{{ item.ordered_quantity }}</span>
              </div>
              <div class="text-caption text-transparent q-mt-xs" style="font-size: 10px; user-select: none;">
                &nbsp;
              </div>
            </td>
            <td
              v-if="isColumnVisible('product_weight')"
              class="text-center shipment-product-weight-col"
            >
              <div>
                <q-input
                  v-if="isEditable"
                  :model-value="getDraftValue(item, 'product_weight')"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-edit-input"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'product_weight', val)"
                  @blur="saveDraftValue(item, 'product_weight', { decimals: 3 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
                <span v-else>{{ formatDecimal(item.product_weight) }}</span>
              </div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-xs" style="font-size: 10px">
                T: {{ formatFixed2((item.product_weight || 0) * (item.ordered_quantity || 0)) }} gm
              </div>
            </td>
            <td
              v-if="isColumnVisible('package_weight')"
              class="text-center shipment-package-weight-col bw-ops-col-tint--weight"
            >
              <div>
                <q-input
                  v-if="isEditable"
                  :model-value="getDraftValue(item, 'package_weight')"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-edit-input"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'package_weight', val)"
                  @blur="saveDraftValue(item, 'package_weight', { decimals: 3 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
                <span v-else>{{ formatDecimal(item.package_weight) }}</span>
              </div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-xs" style="font-size: 10px">
                T: {{ formatFixed2((item.package_weight || 0) * (item.ordered_quantity || 0)) }} gm
              </div>
            </td>
            <td v-if="isColumnVisible('actions')" class="text-right shipment-actions-col">
              <q-btn flat round dense icon="ph ph-dots-three-vertical">
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable @click="emit('edit-details', item)">
                      <q-item-section>Edit details</q-item-section>
                    </q-item>
                    <q-item v-if="isEditable && shipmentStore.currentShipmentSections.length > 1" clickable>
                      <q-item-section>Move to Section</q-item-section>
                      <q-item-section side>
                        <q-icon name="ph ph-caret-right" size="14px" />
                      </q-item-section>
                      <q-menu anchor="top end" self="top start" dense>
                        <q-list style="min-width: 160px">
                          <q-item
                            v-for="sec in shipmentStore.currentShipmentSections"
                            :key="sec.id"
                            clickable
                            :active="item.section_id === sec.id"
                            v-close-popup
                            @click="moveItemToSection(item.id, sec.id)"
                          >
                            <q-item-section>{{ sec.title }}</q-item-section>
                          </q-item>
                        </q-list>
                      </q-menu>
                    </q-item>
                    <q-item
                      v-if="isEditable"
                      clickable
                      class="text-negative"
                      @click="emit('delete', item.id)"
                    >
                      <q-item-section>Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </td>
          </tr>

        </tbody>
      </q-markup-table>
    </q-card-section>

    <div
      v-if="items.length"
      class="shipment-summary-bar row items-center q-gutter-x-md q-px-md q-py-sm wrap"
    >
      <span class="text-caption text-grey-7 text-weight-medium">Summary</span>
      <span
        v-if="isColumnVisible('purchase_price')"
        class="text-caption text-weight-bold shipment-summary-stat shipment-summary-stat--price"
      >
        Price {{ purchaseCurrencySymbol }} {{ formatFixed2(tableTotals.price_gbp) }}
      </span>
      <span
        v-if="isColumnVisible('cost_bdt')"
        class="text-caption text-weight-bold shipment-summary-stat shipment-summary-stat--cost"
      >
        Cost {{ costCurrencySymbol }} {{ formatFixed2(tableTotals.cost_bdt) }}
      </span>
      <span
        v-if="isColumnVisible('ordered_quantity')"
        class="text-caption text-weight-bold shipment-summary-stat shipment-summary-stat--qty"
      >
        Qty {{ tableTotals.quantity }}
      </span>
      <span
        v-if="isColumnVisible('product_weight')"
        class="text-caption text-weight-bold shipment-summary-stat shipment-summary-stat--product-wt"
      >
        Product {{ formatFixed2(tableTotals.product_weight) }} gm
      </span>
      <span
        v-if="isColumnVisible('package_weight')"
        class="text-caption text-weight-bold shipment-summary-stat shipment-summary-stat--package-wt"
      >
        Package {{ formatFixed2(tableTotals.package_weight) }} gm
      </span>
    </div>
  </div>

  <!-- Centered Quantity Split Dialog -->
  <q-dialog v-model="splitDialogActive" persistent>
    <q-card
      v-if="activeSplitItem"
      style="width: 450px; max-width: 95vw"
      class="q-pa-md rounded-borders"
    >
      <q-card-section class="row items-start no-wrap q-pb-none q-mb-sm">
        <q-avatar rounded size="48px" class="bg-grey-2 q-mr-md shadow-1 flex-shrink-0">
          <img
            v-if="activeSplitItem.image_url"
            :src="activeSplitItem.image_url"
            style="object-fit: cover; width: 100%; height: 100%"
          />
          <q-icon v-else name="ph ph-image" color="grey-6" />
        </q-avatar>
        <div class="col column justify-center text-left">
          <div
            class="text-subtitle1 text-weight-bold text-grey-9 text-wrap"
            style="line-height: 1.2; word-break: break-word"
          >
            {{ activeSplitItem.name }}
          </div>
          <div class="text-caption text-grey-6 text-weight-medium q-mt-xs" style="font-size: 11px">
            Qty: {{ activeSplitItem.ordered_quantity }} pcs | Code:
            {{ activeSplitItem.product_code || '-' }}
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense v-close-popup class="q-ml-md self-start" />
      </q-card-section>

      <q-separator class="q-mx-md q-my-sm" />

      <q-card-section class="q-py-sm">
        <!-- Availability splits -->
        <div class="q-gutter-y-md">
          <div
            v-for="opt in STOCK_AVAILABILITY_OPTIONS"
            :key="opt.value"
            class="row items-center justify-between no-wrap q-py-xs"
          >
            <div class="column text-left">
              <span class="text-weight-bold text-grey-9 text-subtitle2" style="line-height: 1.1">{{
                opt.label
              }}</span>
            </div>
            <q-input
              v-model.number="localSplits[activeSplitItem!.id]![opt.value]"
              type="number"
              dense
              outlined
              style="width: 130px"
              min="0"
              class="text-right"
              :rules="[(val) => val >= 0 || 'Must be >= 0']"
              hide-bottom-space
            />
          </div>
        </div>
      </q-card-section>

      <q-separator class="q-my-sm" />

      <q-card-actions align="between" class="q-pt-sm">
        <!-- Sum validation message -->
        <div
          class="text-subtitle2 text-weight-bolder"
          :class="isItemSplitsCompleteLocal(activeSplitItem) ? 'text-positive' : 'text-negative'"
        >
          Allocated: {{ getSumOfSplits(activeSplitItem.id) }} /
          {{ activeSplitItem.ordered_quantity }}
        </div>

        <div class="row q-gutter-sm">
          <q-btn label="Cancel" color="grey-7" flat v-close-popup no-caps />
          <q-btn
            label="Save"
            color="primary"
            unelevated
            no-caps
            :disable="!isItemSplitsCompleteLocal(activeSplitItem)"
            :loading="savingSplits[activeSplitItem.id]"
            @click="saveItemSplits"
          />
        </div>
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, watch } from 'vue';
import SmartImage from 'src/components/SmartImage.vue';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { GlobalShipment, GlobalShipmentItem } from '../repositories/globalShipmentRepository';
import { calculateLineLandedCostBdt } from 'src/shared/shipment-engine';
import { syncShipmentWeightToProduct } from '../utils/syncShipmentWeightToProduct';
import { useStockLocationStore } from '../stores/stockLocationStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { supabase } from 'src/boot/supabase';
import {
  STOCK_AVAILABILITY_OPTIONS,
  type StockAvailability,
} from '../constants/stockAvailability';
import { getDefaultPutawayLocationId } from '../utils/stockLocationOptions';
import {
  showSuccessNotification,
  showErrorNotification,
  showWarningNotification,
} from 'src/utils/appFeedback';

const props = withDefaults(
  defineProps<{
    items: GlobalShipmentItem[];
    shipment: GlobalShipment | null;
    loading?: boolean;
    visibleColumns?: ColumnKey[];
    purchaseCurrencySymbol?: string;
    costCurrencySymbol?: string;
    selectedIds?: number[];
  }>(),
  {
    purchaseCurrencySymbol: '£',
    costCurrencySymbol: '৳',
    selectedIds: () => [],
  },
);

const copyToClipboard = (text: any, label: string) => {
  if (!text) return;
  void navigator.clipboard.writeText(String(text));
  showSuccessNotification(`Copied ${label} to clipboard`);
};

const emit = defineEmits<{
  'edit-details': [item: GlobalShipmentItem];
  delete: [id: number];
  'update:selectedIds': [ids: number[]];
}>();

const isItemSelected = (id: number): boolean => {
  return (props.selectedIds ?? []).includes(id);
};

const allSelected = computed<boolean>(() => {
  if (!props.items || props.items.length === 0) return false;
  const currentSet = new Set(props.selectedIds ?? []);
  return props.items.every((it) => currentSet.has(it.id));
});

const isIndeterminate = computed<boolean>(() => {
  if (!props.items || props.items.length === 0) return false;
  const selectedCount = props.items.filter((it) => (props.selectedIds ?? []).includes(it.id)).length;
  return selectedCount > 0 && selectedCount < props.items.length;
});

const toggleSelectAll = (val: boolean | null) => {
  if (val) {
    const allItemIds = props.items.map((it) => it.id);
    const merged = Array.from(new Set([...(props.selectedIds ?? []), ...allItemIds]));
    emit('update:selectedIds', merged);
  } else {
    const itemIdsToRemove = new Set(props.items.map((it) => it.id));
    const remaining = (props.selectedIds ?? []).filter((id) => !itemIdsToRemove.has(id));
    emit('update:selectedIds', remaining);
  }
};

const toggleItemSelection = (id: number, selected: boolean) => {
  const current = new Set(props.selectedIds ?? []);
  if (selected) {
    current.add(id);
  } else {
    current.delete(id);
  }
  emit('update:selectedIds', Array.from(current));
};

const shipmentStore = useGlobalShipmentStore();

const baseColumnOptions = [
  { label: 'Name', value: 'name' },
  { label: 'Product Identifiers', value: 'product_codes' },
  { label: 'Section / Vendor', value: 'section' },
  { label: 'Price GBP', value: 'purchase_price' },
  { label: 'Cost BDT', value: 'cost_bdt' },
  { label: 'Ordered Quantity', value: 'ordered_quantity' },
  { label: 'Product Wt', value: 'product_weight' },
  { label: 'Package Wt', value: 'package_weight' },
  { label: 'Actions', value: 'actions' },
] as const;

export type ColumnKey = (typeof baseColumnOptions)[number]['value'];

const internalVisibleColumns = ref<ColumnKey[]>([
  'name',
  'product_codes',
  'section',
  'purchase_price',
  'cost_bdt',
  'ordered_quantity',
  'product_weight',
  'package_weight',
  'actions',
]);

const activeVisibleColumns = computed(() => props.visibleColumns ?? internalVisibleColumns.value);

const isInternational = computed(() => props.shipment?.type === 'international');

const columnOptions = computed(() =>
  baseColumnOptions
    .filter((opt) => {
      if (!isInternational.value) {
        return !['purchase_price', 'product_weight', 'package_weight'].includes(opt.value);
      }
      return true;
    })
    .map((opt) => {
      if (opt.value === 'purchase_price') {
        return {
          label: `Price ${props.purchaseCurrencySymbol}`,
          value: 'purchase_price' as ColumnKey,
        };
      }
      if (opt.value === 'cost_bdt') {
        return { label: `Cost ${props.costCurrencySymbol}`, value: 'cost_bdt' as ColumnKey };
      }
      return opt;
    }),
);

const isEditable = computed(() => {
  if (!props.shipment) return false;
  return props.shipment.status !== 'received' && props.shipment.status !== 'cancelled';
});

const isColumnVisible = (column: ColumnKey) => activeVisibleColumns.value.includes(column);

const tableColspan = computed(() => {
  let count = 3; // select col + sl col + image col
  for (const opt of columnOptions.value) {
    if (isColumnVisible(opt.value)) count++;
  }
  if (props.shipment?.status === 'in_transit') count++;
  return count;
});

const locationStore = useStockLocationStore();
const authStore = useAuthStore();

const getSectionTitle = (sectionId?: number | null): string => {
  if (!sectionId) return 'Default Section';
  const sec = shipmentStore.currentShipmentSections.find((s) => s.id === sectionId);
  return sec?.title || `Section #${sectionId}`;
};

const getSectionVendorName = (sectionId?: number | null): string => {
  if (!sectionId) return '';
  const sec = shipmentStore.currentShipmentSections.find((s) => s.id === sectionId);
  return sec?.vendor?.name || '';
};

const moveItemToSection = async (itemId: number, sectionId: number | null) => {
  try {
    await shipmentStore.moveItemToSection(itemId, sectionId);
    showSuccessNotification('Item moved to section');
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to move item');
  }
};

const emptyAvailabilitySplits = (): Record<StockAvailability, number> => ({
  sellable: 0,
  held: 0,
  unsellable: 0,
});

const localSplits = ref<Record<number, Record<StockAvailability, number>>>({});
const savingSplits = ref<Record<number, boolean>>({});

const splitDialogActive = ref(false);
const activeSplitItem = ref<GlobalShipmentItem | null>(null);

const openSplitDialog = (item: GlobalShipmentItem) => {
  activeSplitItem.value = item;
  splitDialogActive.value = true;
};

onMounted(async () => {
  if (authStore.tenantId && locationStore.items.length === 0) {
    await locationStore.fetchLocations(authStore.tenantId, false);
  }
});

const initLocalSplits = () => {
  const stocks = shipmentStore.currentShipmentStocks || [];
  const items = props.items || [];

  const newSplits: Record<number, Record<StockAvailability, number>> = {};
  for (const item of items) {
    const itemStocks = stocks.filter((s) => s.shipment_item_id === item.id);
    const splits = emptyAvailabilitySplits();
    newSplits[item.id] = splits;

    if (itemStocks.length > 0) {
      for (const s of itemStocks) {
        const availability = (s.availability || 'sellable') as StockAvailability;
        splits[availability] = (splits[availability] || 0) + (s.quantity || 0);
      }
    } else {
      splits.sellable = item.ordered_quantity;
    }
  }
  localSplits.value = newSplits;
};

watch(
  [() => shipmentStore.currentShipmentStocks, () => props.items],
  () => {
    initLocalSplits();
  },
  { immediate: true },
);

const getSumOfSplits = (itemId: number): number => {
  const itemSplits = localSplits.value[itemId] || {};
  return Object.values(itemSplits).reduce((sum: number, qty) => sum + (Number(qty) || 0), 0);
};

const isItemSplitsCompleteInDb = (item: GlobalShipmentItem): boolean => {
  const stocks = shipmentStore.currentShipmentStocks || [];
  const itemStocks = stocks.filter((s) => s.shipment_item_id === item.id);
  if (itemStocks.length === 0) return false;
  const sum = itemStocks.reduce((acc, s) => acc + (s.quantity || 0), 0);
  return sum === item.ordered_quantity;
};

const isItemSplitsCompleteLocal = (item: GlobalShipmentItem): boolean => {
  return getSumOfSplits(item.id) === item.ordered_quantity;
};

const saveItemSplits = async () => {
  const item = activeSplitItem.value;
  if (!item || !isItemSplitsCompleteLocal(item) || !authStore.tenantId) return;

  savingSplits.value[item.id] = true;
  try {
    const locationId = getDefaultPutawayLocationId(locationStore.items);
    if (!locationId) {
      showErrorNotification('No default put-away location configured.');
      return;
    }

    const itemSplits = localSplits.value[item.id] || emptyAvailabilitySplits();
    const stockRows = STOCK_AVAILABILITY_OPTIONS.map((opt) => ({
      parent_tenant_id: authStore.tenantId,
      shipment_item_id: item.id,
      availability: opt.value,
      location_id: locationId,
      quantity: itemSplits[opt.value] || 0,
      is_usable: opt.value === 'sellable',
    })).filter((row) => row.quantity > 0);

    const { error: deleteError } = await supabase
      .from('global_stocks')
      .delete()
      .eq('shipment_item_id', item.id);
    if (deleteError) throw deleteError;

    if (stockRows.length > 0) {
      const { error: insertError } = await supabase.from('global_stocks').insert(stockRows);
      if (insertError) throw insertError;
    }

    showSuccessNotification(`Stock splits saved successfully for ${item.name}.`);

    splitDialogActive.value = false;
    await shipmentStore.fetchShipmentDetails(props.shipment!.id);
  } catch (error: any) {
    showErrorNotification(error.message || 'Failed to save splits.');
  } finally {
    savingSplits.value[item.id] = false;
  }
};

const formatDecimal = (value: number | null | undefined) =>
  value == null ? '-' : String(Number(value));

const formatFixed2 = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2);

const formatPrice = (value: number | null | undefined) => {
  if (value == null) return '-';
  const num = Number(value);
  // Check if there are decimal places beyond 2 digits
  if (Math.abs(num - Math.round(num * 100) / 100) > 0.000001) {
    return num.toFixed(6).replace(/\.?0+$/, ''); // show up to 6 decimals, trimming trailing zeros
  }
  return num.toFixed(2);
};

const lineCostBdt = (item: GlobalShipmentItem) => {
  if (item.landed_cost_bdt != null && Number.isFinite(Number(item.landed_cost_bdt))) {
    return Number(item.landed_cost_bdt);
  }
  if (!props.shipment) return 0;
  return calculateLineLandedCostBdt(item, props.shipment, props.items);
};

const tableTotals = computed(() =>
  props.items.reduce(
    (acc, item) => {
      const qty = Number(item.ordered_quantity ?? 0);
      const unitCost = lineCostBdt(item);
      acc.price_gbp += Number(item.purchase_price ?? 0) * qty;
      acc.cost_bdt += unitCost * qty;
      acc.quantity += qty;
      acc.product_weight += Number(item.product_weight ?? 0) * qty;
      acc.package_weight += Number(item.package_weight ?? 0) * qty;
      return acc;
    },
    { price_gbp: 0, cost_bdt: 0, quantity: 0, product_weight: 0, package_weight: 0 },
  ),
);

type EditableField = 'purchase_price' | 'ordered_quantity' | 'product_weight' | 'package_weight';

const roundTo = (value: number, decimals = 0) => {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
};

const activeSaves = new Set<string>();
const draftValues = ref<Record<string, any>>({});

const getDraftValue = (item: GlobalShipmentItem, field: EditableField) => {
  const key = `${item.id}:${field}`;
  if (key in draftValues.value) {
    return draftValues.value[key];
  }
  return item[field] ?? '';
};

const setDraftValue = (item: GlobalShipmentItem, field: EditableField, val: any) => {
  const key = `${item.id}:${field}`;
  draftValues.value[key] = val;
};

const saveDraftValue = async (
  item: GlobalShipmentItem,
  field: EditableField,
  options?: { decimals?: number },
) => {
  const key = `${item.id}:${field}`;
  const rawValue = key in draftValues.value ? draftValues.value[key] : item[field];
  delete draftValues.value[key];

  if (rawValue === null || rawValue === undefined || rawValue === '') return;

  const parsed = Number(rawValue);
  if (isNaN(parsed) || !Number.isFinite(parsed) || parsed < 0) {
    showWarningNotification('Value must be 0 or greater.');
    return;
  }

  let normalized =
    options?.decimals != null ? roundTo(parsed, options.decimals) : Math.floor(parsed);
  if (field === 'ordered_quantity') {
    normalized = Math.max(1, Math.floor(parsed));
  }

  const currentValue = Number(item[field] ?? 0);
  if (currentValue === normalized) return;

  if (activeSaves.has(key)) return;
  activeSaves.add(key);

  try {
    await shipmentStore.updateShipmentItem(item.id, { [field]: normalized });
    showSuccessNotification(`Updated ${field.replace('_', ' ')}.`);
    if ((field === 'product_weight' || field === 'package_weight') && item.product_id != null) {
      await syncShipmentWeightToProduct(item.product_id, field, normalized);
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to update item.';
    showErrorNotification(msg);
  } finally {
    activeSaves.delete(key);
  }
};

const moveItem = async (index: number, direction: 'up' | 'down') => {
  const targetIndex = direction === 'up' ? index - 1 : index + 1;
  if (targetIndex < 0 || targetIndex >= props.items.length) return;

  const updatedItems = [...props.items];
  const temp = updatedItems[index];
  const targetItem = updatedItems[targetIndex];
  if (!temp || !targetItem) return;

  updatedItems[index] = targetItem;
  updatedItems[targetIndex] = temp;

  const itemsOrder = updatedItems.map((item, idx) => ({
    id: item.id,
    sort_order: idx * 10,
  }));

  try {
    if (props.shipment) {
      await shipmentStore.reorderShipmentItems(props.shipment.id, itemsOrder);
      showSuccessNotification('Items reordered successfully.');
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to reorder items.';
    showErrorNotification(msg);
  }
};

const moveItemToPosition = async (currentIndex: number, newPosition: string | number | null) => {
  const parsed = Number(newPosition);
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > props.items.length) {
    showWarningNotification(`Position must be between 1 and ${props.items.length}.`);
    return;
  }

  const targetIndex = parsed - 1;
  if (currentIndex === targetIndex) return;

  const updatedItems = [...props.items];
  const [removedItem] = updatedItems.splice(currentIndex, 1);
  if (!removedItem) return;

  updatedItems.splice(targetIndex, 0, removedItem);

  const itemsOrder = updatedItems.map((item, idx) => ({
    id: item.id,
    sort_order: idx * 10,
  }));

  try {
    if (props.shipment) {
      await shipmentStore.reorderShipmentItems(props.shipment.id, itemsOrder);
      showSuccessNotification(`Item moved to position ${parsed} successfully.`);
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to move item.';
    showErrorNotification(msg);
  }
};

defineExpose({
  columnOptions,
  internalVisibleColumns,
});
</script>

<style scoped>
.text-underline-dashed {
  text-decoration: underline dashed;
}

.shipment-line-items {
  min-width: 0;
  min-height: 0;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.shipment-table-scroll-wrap {
  flex: 1;
  min-height: 0;
  overflow: auto;
  position: relative;
  background: var(--bw-theme-base, #eef2f5);
}

.shipment-details-table {
  min-width: max-content;
  width: max-content;
  height: auto;
  overflow: visible;
  --sl-col-width: 60px;
}

.shipment-details-table.is-editable {
  --sl-col-width: 60px;
}

.shipment-details-table :deep(table) {
  table-layout: fixed;
  border-collapse: separate;
  border-spacing: 0;
  min-width: max-content;
  width: max-content;
}

.shipment-details-table :deep(tbody td) {
  vertical-align: middle;
}

.shipment-details-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
  box-shadow: inset 0 -1px 0 rgba(148, 163, 184, 0.25);
  white-space: normal;
  line-height: 1.2;
  word-break: normal;
  vertical-align: middle;
}

.shipment-item-image-box {
  width: 1in;
  height: 1in;
  flex-shrink: 0;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f8f9fa;
}

.shipment-details-table :deep(.shipment-item-image-box .smart-image-wrapper) {
  width: 100% !important;
  height: 100% !important;
  display: block !important;
}

.shipment-details-table :deep(.shipment-item-image-box .smart-image__img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.shipment-details-table :deep(.shipment-item-image-fallback),
.shipment-details-table :deep(.shipment-item-image-box .smart-image__fallback) {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.shipment-item-name-cell {
  white-space: normal;
  word-break: break-word;
  line-height: 1.25;
}

.shipment-select-col {
  width: 44px;
  min-width: 44px;
  max-width: 44px;
  padding: 0 4px !important;
}

.shipment-sl-col {
  width: var(--sl-col-width);
  min-width: var(--sl-col-width);
  max-width: var(--sl-col-width);
}

.shipment-image-col {
  width: 1.2in;
  min-width: 1.2in;
  max-width: 1.2in;
}

.shipment-name-col {
  width: 180px;
  min-width: 180px;
  max-width: 180px;
}

.shipment-codes-col {
  width: 140px;
  min-width: 140px;
  max-width: 140px;
}

.shipment-section-col {
  width: 150px;
  min-width: 150px;
  max-width: 150px;
}

.shipment-price-col,
.shipment-product-weight-col,
.shipment-package-weight-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-cost-col {
  width: 120px;
  min-width: 120px;
  max-width: 120px;
}

.shipment-actions-col {
  width: 80px;
  min-width: 80px;
  max-width: 80px;
}

.shipment-qty-col--quantity {
  width: 140px;
  min-width: 140px;
  max-width: 140px;
}

/* Row selection highlight */
.shipment-details-table :deep(tr.row-selected td) {
  background: #f0f7ff !important;
}

.shipment-details-table :deep(td:first-child),
.shipment-details-table :deep(th:first-child) {
  position: sticky;
  left: 0;
}

.shipment-details-table :deep(td:nth-child(2)),
.shipment-details-table :deep(th:nth-child(2)) {
  position: sticky;
  left: 44px;
}

.shipment-details-table :deep(td:nth-child(3)),
.shipment-details-table :deep(th:nth-child(3)) {
  position: sticky;
  left: calc(44px + var(--sl-col-width));
}

.shipment-details-table :deep(td:first-child) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.shipment-details-table :deep(td:nth-child(2)),
.shipment-details-table :deep(td:nth-child(3)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-details-table :deep(tr:first-child th:first-child),
.shipment-details-table :deep(tr:first-child th:nth-child(2)),
.shipment-details-table :deep(tr:first-child th:nth-child(3)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-summary-bar {
  flex-shrink: 0;
  border-top: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
  background: var(--bw-theme-surface, #fff);
  row-gap: 6px;
}

.shipment-summary-stat {
  padding: 2px 8px;
  border-radius: 4px;
}

.shipment-summary-stat--price {
  background: color-mix(in srgb, var(--bw-theme-surface) 94%, var(--bw-ops-hue-price) 6%);
  box-shadow: inset 1px 0 0 var(--bw-ops-hue-price);
}

.shipment-summary-stat--cost {
  background: color-mix(in srgb, var(--bw-theme-surface) 94%, var(--bw-ops-hue-cost) 6%);
  box-shadow: inset 1px 0 0 var(--bw-ops-hue-cost);
}

.shipment-summary-stat--qty {
  background: color-mix(in srgb, var(--bw-theme-surface) 94%, var(--bw-ops-hue-qty) 6%);
  box-shadow: inset 1px 0 0 var(--bw-ops-hue-qty);
}

.shipment-summary-stat--product-wt {
  background: #eceff1;
}

.shipment-summary-stat--package-wt {
  background: color-mix(in srgb, var(--bw-theme-surface) 94%, var(--bw-ops-hue-weight) 6%);
  box-shadow: inset 1px 0 0 var(--bw-ops-hue-weight);
}

.inline-edit-input :deep(.q-field__control) {
  height: 28px;
  min-height: 28px;
  padding: 0 4px;
  border-radius: 4px;
}

.inline-edit-input :deep(.q-field__native) {
  padding: 0;
  font-size: 12px;
}

:deep(input[type='number']::-webkit-outer-spin-button),
:deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(input[type='number']) {
  -moz-appearance: textfield;
}
</style>
