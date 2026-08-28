<template>
  <q-page class="shipment-items-v2-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Header Bar -->
    <div class="bg-white border-bottom q-px-md q-py-sm shadow-1">
      <div class="row items-center justify-between no-wrap">
        <div class="row items-center q-gutter-sm">
          <q-btn
            icon="ph ph-arrow-left"
            flat
            round
            dense
            color="grey-8"
            @click="goBackToShipment"
          >
            <q-tooltip>Back to shipment</q-tooltip>
          </q-btn>

          <q-separator vertical inset class="q-mx-xs" />

          <div class="text-subtitle1 text-weight-bold text-grey-9">
            Shipment Items (v2)
          </div>
        </div>

        <!-- Right: Version Toggle -->
        <div class="row items-center q-gutter-xs justify-end">
          <q-btn-toggle
            :model-value="itemsVersion"
            flat
            dense
            no-caps
            size="sm"
            toggle-color="primary"
            color="grey-2"
            text-color="grey-8"
            :options="[
              { label: 'Legacy', value: 'legacy', icon: 'ph ph-clock-counter-clockwise' },
              { label: 'New (v2)', value: 'v2', icon: 'ph ph-sparkle' },
            ]"
            class="border-grey version-toggle"
            @update:model-value="onVersionChange"
          >
            <template #legacy>
              <q-tooltip>Switch to Legacy Items View</q-tooltip>
            </template>
            <template #v2>
              <q-tooltip>Active: New (v2) Items View</q-tooltip>
            </template>
          </q-btn-toggle>
        </div>
      </div>
    </div>

    <!-- Top Sticky Section: Shipment Name & Column Buttons (Visual Only) -->
    <div class="shipment-items-top-section bg-white border-bottom q-px-md q-py-sm shrink-0">
      <div class="row items-center justify-between no-wrap">
        <!-- Left: Static Shipment Info -->
        <div class="row items-center q-gutter-x-sm no-wrap ellipsis">
          <span class="text-caption text-weight-bold text-grey-6 font-mono">
            #SHP-2026-0089
          </span>
          <span class="text-grey-4">·</span>
          <div class="text-subtitle2 text-weight-bold text-grey-9 ellipsis">
            Inbound Shipment #89 - Summer Collection
          </div>
          <q-badge
            rounded
            class="text-weight-bold text-capitalize q-ml-xs text-xxs"
            color="primary"
          >
            In Transit
          </q-badge>
        </div>

        <!-- Right: Header Buttons (Visual Only) -->
        <div class="row items-center q-gutter-x-sm no-wrap">
          <!-- Add Column Button -->
          <q-btn
            outline
            dense
            no-caps
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-sm"
            icon="ph ph-plus"
            label="Add Column"
            size="sm"
          >
            <q-tooltip>Add Column</q-tooltip>
          </q-btn>

          <!-- Column Settings Button -->
          <q-btn
            flat
            dense
            no-caps
            color="grey-8"
            class="rounded-sq-btn text-weight-bold q-px-sm border-grey"
            icon="ph ph-sliders-horizontal"
            label="Columns"
            size="sm"
          >
            <q-tooltip>Column Settings</q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <!-- Middle Scrollable Section -->
    <div class="shipment-items-middle-section col overflow-auto q-pa-none">
      <q-markup-table flat class="shipment-items-markup-table full-width bg-white">
        <thead>
          <tr>
            <th class="text-center" style="width: 40px">
              <q-checkbox v-model="allSelected" dense size="sm" />
            </th>
            <th v-if="visibleColumnMap.sl" class="text-right" style="width: 50px">SL</th>
            <th v-if="visibleColumnMap.image" class="text-left" style="width: 60px">Image</th>
            <th v-if="visibleColumnMap.name" class="text-left">Product Name / Code</th>
            <th v-if="visibleColumnMap.category" class="text-left">Category</th>
            <th v-if="visibleColumnMap.vendor" class="text-left">Vendor</th>
            <th v-if="visibleColumnMap.quantity" class="text-center">Quantity</th>
            <th v-if="visibleColumnMap.price" class="text-right">Unit Price</th>
            <th v-if="visibleColumnMap.cost" class="text-right">Total Cost</th>
            <th v-if="visibleColumnMap.status" class="text-center">Status</th>
            <!-- Dynamically added custom columns -->
            <template v-for="col in customColumns" :key="col.name">
              <th v-if="visibleColumnMap[col.name]" class="text-left">{{ col.label }}</th>
            </template>
            <th class="text-right" style="width: 50px">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(item, index) in dummyItems"
            :key="item.id"
            class="shipment-item-row cursor-pointer"
            :class="{ 'row-selected': item.selected }"
          >
            <!-- Select -->
            <td class="text-center">
              <q-checkbox v-model="item.selected" dense size="sm" />
            </td>

            <!-- SL -->
            <td v-if="visibleColumnMap.sl" class="text-right text-weight-medium text-grey-7">
              {{ index + 1 }}
            </td>

            <!-- Image -->
            <td v-if="visibleColumnMap.image">
              <q-avatar square size="36px" class="avatar-soft-sq bg-grey-2 border-grey overflow-hidden">
                <img :src="item.image" alt="item" />
              </q-avatar>
            </td>

            <!-- Name & Code -->
            <td v-if="visibleColumnMap.name">
              <div class="text-weight-bold text-grey-9 line-clamp-1">{{ item.name }}</div>
              <div class="text-caption text-grey-6 text-xxs font-mono">{{ item.code }}</div>
            </td>

            <!-- Category / Section -->
            <td v-if="visibleColumnMap.category">
              <span class="text-caption text-grey-8">{{ item.category }}</span>
            </td>

            <!-- Vendor -->
            <td v-if="visibleColumnMap.vendor">
              <div class="row items-center no-wrap">
                <q-avatar
                  square
                  size="22px"
                  color="grey-3"
                  text-color="grey-9"
                  class="q-mr-xs text-weight-bold text-xxs avatar-soft-sq"
                >
                  {{ item.vendorInitials }}
                </q-avatar>
                <span class="text-caption text-weight-medium text-grey-9">{{ item.vendor }}</span>
              </div>
            </td>

            <!-- Quantity -->
            <td v-if="visibleColumnMap.quantity" class="text-center text-weight-bold">
              {{ item.quantity }}
            </td>

            <!-- Unit Price -->
            <td v-if="visibleColumnMap.price" class="text-right font-mono">
              ¥{{ item.price.toFixed(2) }}
            </td>

            <!-- Total Cost -->
            <td v-if="visibleColumnMap.cost" class="text-right font-mono text-weight-bold text-primary">
              ৳{{ item.cost.toLocaleString() }}
            </td>

            <!-- Status -->
            <td v-if="visibleColumnMap.status" class="text-center">
              <q-chip
                square
                dense
                :color="getStatusColor(item.status).color"
                :text-color="getStatusColor(item.status).textColor"
                class="text-weight-bold text-capitalize text-xxs q-ma-none soft-chip"
              >
                {{ item.status }}
              </q-chip>
            </td>

            <!-- Dynamically added custom column cells -->
            <template v-for="col in customColumns" :key="col.name">
              <td v-if="visibleColumnMap[col.name]" class="text-grey-7 font-mono text-caption">
                {{ (item as any)[col.name] || '-' }}
              </td>
            </template>

            <!-- Actions -->
            <td class="text-right">
              <q-btn flat round dense size="sm" icon="ph ph-dots-three-vertical" color="grey-7">
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable>
                      <q-item-section avatar class="min-width-auto q-pr-sm">
                        <q-icon name="ph ph-pencil-simple" size="14px" />
                      </q-item-section>
                      <q-item-section>Edit</q-item-section>
                    </q-item>
                    <q-item clickable class="text-negative">
                      <q-item-section avatar class="min-width-auto q-pr-sm">
                        <q-icon name="ph ph-trash" size="14px" />
                      </q-item-section>
                      <q-item-section>Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <!-- Bottom Sticky Section: Excel-style Dark Bar with Sheet Tabs & Right Horizontal Scrollbar -->
    <div class="shipment-items-bottom-section excel-bottom-bar shrink-0 row items-center no-wrap">
      <!-- Left: Navigation Scroll Arrows ( |<  <  >  >| ) -->
      <div class="row items-center no-wrap excel-left-nav">
        <button class="excel-icon-btn" title="First Sheet" @click="scrollToTab('start')">
          <q-icon name="ph ph-caret-line-left" size="15px" />
        </button>
        <button class="excel-icon-btn" title="Previous Sheet" @click="scrollTabs(-100)">
          <q-icon name="ph ph-caret-left" size="15px" />
        </button>
        <button class="excel-icon-btn" title="Next Sheet" @click="scrollTabs(100)">
          <q-icon name="ph ph-caret-right" size="15px" />
        </button>
        <button class="excel-icon-btn" title="Last Sheet" @click="scrollToTab('end')">
          <q-icon name="ph ph-caret-line-right" size="15px" />
        </button>
      </div>

      <!-- Sheet Tabs Container -->
      <div ref="tabsContainerRef" class="excel-tabs-scroll-container row items-center no-wrap">
        <div
          v-for="sheet in sheets"
          :key="sheet.id"
          class="excel-tab-item row items-center no-wrap cursor-pointer"
          :class="{ 'excel-tab-item--active': activeSheetId === sheet.id }"
          @click="activeSheetId = sheet.id"
        >
          <span class="excel-tab-label">{{ sheet.name }}</span>
          <q-icon
            v-if="sheets.length > 1 && activeSheetId === sheet.id"
            name="ph ph-x"
            size="12px"
            class="excel-tab-close q-ml-xs"
            @click.stop="removeSheet(sheet.id)"
          />
        </div>
      </div>

      <!-- Plus Button for Add New Sheet -->
      <button class="excel-icon-btn excel-plus-btn q-mr-sm" title="Add Sheet" @click="addDummySheet">
        <q-icon name="ph ph-plus" size="16px" />
      </button>

      <!-- Splitter / Divider Bar -->
      <div class="excel-splitter-bar" />

      <!-- Right Side Horizontal Scrollbar Track & Thumb -->
      <div class="excel-scrollbar-wrapper col row items-center no-wrap">
        <!-- Scrollbar Left End Arrow -->
        <button class="excel-scroll-arrow-btn" @click="scrollTableHorizontally(-100)">
          <q-icon name="ph ph-caret-left" size="13px" />
        </button>

        <!-- Scrollbar Track & Thumb -->
        <div class="excel-scroll-track col">
          <div
            class="excel-scroll-thumb"
            :style="{ width: scrollThumbWidth + '%', transform: `translateX(${scrollThumbOffset}%)` }"
          />
        </div>

        <!-- Scrollbar Right End Arrow -->
        <button class="excel-scroll-arrow-btn" @click="scrollTableHorizontally(100)">
          <q-icon name="ph ph-caret-right" size="13px" />
        </button>

        <div class="excel-end-cap" />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';

withDefaults(
  defineProps<{
    itemsVersion?: 'legacy' | 'v2';
  }>(),
  {
    itemsVersion: 'v2',
  },
);

const emit = defineEmits<{
  (e: 'update:itemsVersion', value: 'legacy' | 'v2'): void;
}>();

const route = useRoute();
const router = useRouter();
const shipmentId = Number(route.params.id);

const ITEMS_VERSION_STORAGE_KEY = 'shipment_items_version';

const onVersionChange = (newVersion: 'legacy' | 'v2') => {
  localStorage.setItem(ITEMS_VERSION_STORAGE_KEY, newVersion);
  emit('update:itemsVersion', newVersion);
};

const goBackToShipment = () => {
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { tenantSlug, id: shipmentId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { id: shipmentId },
    });
  }
};

const visibleColumnMap = reactive<Record<string, boolean>>({
  sl: true,
  image: true,
  name: true,
  category: true,
  vendor: true,
  quantity: true,
  price: true,
  cost: true,
  status: true,
});

const showAddColumnDialog = ref(false);
const newColumnName = ref('');
const newColumnType = ref('text');

const customColumns = ref<Array<{ name: string; label: string }>>([]);

const allSelected = computed({
  get: () => dummyItems.value.length > 0 && dummyItems.value.every((i) => i.selected),
  set: (val: boolean) => {
    dummyItems.value.forEach((i) => {
      i.selected = val;
    });
  },
});

const columns = reactive([
  { name: 'select', label: '', field: 'selected', align: 'center' },
  { name: 'sl', label: 'SL', field: 'sl', align: 'right' },
  { name: 'image', label: 'Image', field: 'image', align: 'left' },
  { name: 'name', label: 'Product Name / Code', field: 'name', align: 'left', sortable: true },
  { name: 'category', label: 'Category', field: 'category', align: 'left', sortable: true },
  { name: 'vendor', label: 'Vendor', field: 'vendor', align: 'left' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'center', sortable: true },
  { name: 'price', label: 'Unit Price', field: 'price', align: 'right', sortable: true },
  { name: 'cost', label: 'Total Cost', field: 'cost', align: 'right', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'actions', label: '', field: 'actions', align: 'right' },
]);

const dummyItems = ref([
  {
    id: 1,
    selected: false,
    name: 'Premium Silk Blend Scarf',
    code: 'SKU-SLK-001',
    category: 'Accessories',
    vendor: 'Guangzhou Silk Co.',
    vendorInitials: 'GS',
    quantity: 150,
    price: 32.5,
    cost: 58500,
    status: 'received',
    image: 'https://images.unsplash.com/photo-1601924994987-69e26d50dc26?w=100&auto=format&fit=crop&q=60',
  },
  {
    id: 2,
    selected: false,
    name: 'Oversized Cotton Knit Hoodie',
    code: 'SKU-HD-902',
    category: 'Apparel',
    vendor: 'Zhejiang Garments Ltd',
    vendorInitials: 'ZG',
    quantity: 300,
    price: 48.0,
    cost: 172800,
    status: 'in_transit',
    image: 'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=100&auto=format&fit=crop&q=60',
  },
  {
    id: 3,
    selected: false,
    name: 'Vintage Wash Denim Jacket',
    code: 'SKU-JK-441',
    category: 'Outerwear',
    vendor: 'Dongguan Denim Works',
    vendorInitials: 'DD',
    quantity: 200,
    price: 65.0,
    cost: 156000,
    status: 'pending',
    image: 'https://images.unsplash.com/photo-1576995853123-5a10305d93c0?w=100&auto=format&fit=crop&q=60',
  },
  {
    id: 4,
    selected: false,
    name: 'Relaxed Fit Linen Pants',
    code: 'SKU-PT-112',
    category: 'Bottoms',
    vendor: 'Zhejiang Garments Ltd',
    vendorInitials: 'ZG',
    quantity: 400,
    price: 22.0,
    cost: 105600,
    status: 'in_transit',
    image: 'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=100&auto=format&fit=crop&q=60',
  },
  {
    id: 5,
    selected: false,
    name: 'Canvas Utility Crossbody Bag',
    code: 'SKU-BG-808',
    category: 'Accessories',
    vendor: 'Yiwu Accessories Hub',
    vendorInitials: 'YA',
    quantity: 200,
    price: 15.5,
    cost: 37200,
    status: 'received',
    image: 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=100&auto=format&fit=crop&q=60',
  },
]);

// Excel Sheets Management
const tabsContainerRef = ref<HTMLElement | null>(null);
const activeSheetId = ref('sheet_1');
const sheets = ref([
  { id: 'sheet_1', name: 'Order Details' },
]);

const scrollThumbWidth = ref(40);
const scrollThumbOffset = ref(0);

const scrollTabs = (offset: number) => {
  if (tabsContainerRef.value) {
    tabsContainerRef.value.scrollBy({ left: offset, behavior: 'smooth' });
  }
};

const scrollToTab = (pos: 'start' | 'end') => {
  if (tabsContainerRef.value) {
    tabsContainerRef.value.scrollTo({
      left: pos === 'start' ? 0 : tabsContainerRef.value.scrollWidth,
      behavior: 'smooth',
    });
  }
};

const addDummySheet = () => {
  const newId = `sheet_${Date.now()}`;
  sheets.value.push({
    id: newId,
    name: `Sheet ${sheets.value.length + 1}`,
  });
  activeSheetId.value = newId;
  setTimeout(() => scrollToTab('end'), 50);
};

const removeSheet = (id: string) => {
  const idx = sheets.value.findIndex((s) => s.id === id);
  if (idx !== -1) {
    sheets.value.splice(idx, 1);
    if (activeSheetId.value === id && sheets.value.length > 0) {
      activeSheetId.value = sheets.value[Math.max(0, idx - 1)].id;
    }
  }
};

const scrollTableHorizontally = (delta: number) => {
  scrollThumbOffset.value = Math.max(0, Math.min(150, scrollThumbOffset.value + delta * 0.2));
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'received':
      return { color: 'positive', textColor: 'white' };
    case 'in_transit':
      return { color: 'warning', textColor: 'dark' };
    case 'pending':
    default:
      return { color: 'grey-4', textColor: 'grey-9' };
  }
};
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-top {
  border-top: 1px solid #e2e8f0;
}
.border-grey {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.shrink-0 {
  flex-shrink: 0;
}
.h-full {
  height: 100%;
}
.avatar-soft-sq {
  border-radius: 6px;
}
.soft-chip {
  border-radius: 6px;
  font-size: 11px;
}
.text-xxs {
  font-size: 11px;
}
.line-clamp-1 {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.font-mono {
  font-family: monospace;
}
.min-width-auto {
  min-width: auto;
}
.shipment-items-markup-table {
  background: white;
  border-collapse: separate;
  border-spacing: 0;
}
.shipment-items-markup-table thead tr th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #f8fafc;
  font-weight: 600;
  font-size: 12px;
  color: #475569;
  border-bottom: 1px solid #e2e8f0;
  padding: 8px 12px;
}
.shipment-items-markup-table tbody tr td {
  padding: 8px 12px;
  border-bottom: 1px solid #f1f5f9;
  font-size: 13px;
}
.shipment-items-markup-table tbody tr:hover {
  background-color: #f8fafc;
}

/* Excel Style Light Bottom Bar */
.excel-bottom-bar {
  height: 36px;
  min-height: 36px;
  background-color: #f8fafc;
  color: #475569;
  border-top: 1px solid #cbd5e1;
  padding: 0 8px;
  user-select: none;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.excel-left-nav {
  display: flex;
  align-items: center;
  gap: 2px;
}

.excel-icon-btn {
  background: transparent;
  border: none;
  color: #64748b;
  padding: 4px 6px;
  cursor: pointer;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 26px;
  min-width: 24px;
  transition: all 0.15s;
}

.excel-icon-btn:hover {
  background: #e2e8f0;
  color: #1e293b;
}

.excel-plus-btn {
  color: #475569;
  margin-left: 4px;
}

.excel-tabs-scroll-container {
  overflow-x: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
  display: flex;
  align-items: center;
  height: 100%;
}
.excel-tabs-scroll-container::-webkit-scrollbar {
  display: none;
}

.excel-tab-item {
  height: 36px;
  padding: 0 16px;
  color: #64748b;
  font-size: 13px;
  border-bottom: 3px solid transparent;
  transition: all 0.15s;
}

.excel-tab-item:hover {
  color: #1e293b;
  background-color: #e2e8f0;
}

.excel-tab-item--active {
  color: #059669; /* Emerald text */
  border-bottom: 3px solid #059669;
  background-color: #ffffff;
  font-weight: 600;
}

.excel-tab-label {
  white-space: nowrap;
}

.excel-tab-close {
  opacity: 0.5;
  cursor: pointer;
}
.excel-tab-close:hover {
  opacity: 1;
  color: #ef4444;
}

/* Excel Splitter Bar between tabs and right scrollbar */
.excel-splitter-bar {
  width: 5px;
  height: 20px;
  background: #cbd5e1;
  border-radius: 2px;
  margin: 0 10px;
  cursor: col-resize;
}

/* Excel Right Scrollbar */
.excel-scrollbar-wrapper {
  background-color: #f8fafc;
  height: 24px;
  display: flex;
  align-items: center;
  gap: 3px;
}

.excel-scroll-arrow-btn {
  background: #ffffff;
  border: 1px solid #cbd5e1;
  color: #64748b;
  height: 20px;
  width: 20px;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 3px;
  transition: all 0.15s;
}

.excel-scroll-arrow-btn:hover {
  background: #e2e8f0;
  color: #0f172a;
}

.excel-scroll-track {
  height: 14px;
  background-color: #e2e8f0;
  border: 1px solid #cbd5e1;
  border-radius: 7px;
  position: relative;
  overflow: hidden;
  margin: 0 4px;
}

.excel-scroll-thumb {
  height: 100%;
  background-color: #94a3b8;
  border-radius: 7px;
  transition: transform 0.1s ease-out;
  cursor: pointer;
}

.excel-scroll-thumb:hover {
  background-color: #64748b;
}

.excel-end-cap {
  width: 3px;
  height: 18px;
  background-color: #cbd5e1;
  margin-left: 2px;
}
</style>
