<template>
  <q-page class="shipment-items-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
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

          <!-- Section Switcher / Breadcrumb -->
          <div class="row items-center q-gutter-x-xs">
            <q-icon name="ph ph-folder" size="18px" color="primary" />
            <q-btn-dropdown
              flat
              dense
              no-caps
              size="sm"
              class="text-weight-bold text-subtitle2 text-grey-9 rounded-borders"
              :label="activeSectionLabel"
            >
              <q-list dense style="min-width: 220px">
                <q-item
                  clickable
                  v-close-popup
                  :active="selectedSectionId == null"
                  @click="selectSection(null)"
                >
                  <q-item-section avatar style="min-width: 28px">
                    <q-icon name="ph ph-squares-four" size="16px" />
                  </q-item-section>
                  <q-item-section>
                    <div class="text-weight-medium">All Sections (Full Review)</div>
                    <div class="text-caption text-grey-6">{{ (shipmentStore.currentShipmentItems ?? []).length }} items</div>
                  </q-item-section>
                </q-item>
                <q-separator />
                <q-item
                  v-for="sec in shipmentStore.currentShipmentSections"
                  :key="sec.id"
                  clickable
                  v-close-popup
                  :active="selectedSectionId === sec.id"
                  @click="selectSection(sec.id)"
                >
                  <q-item-section avatar style="min-width: 28px">
                    <q-icon name="ph ph-folder" size="16px" color="primary" />
                  </q-item-section>
                  <q-item-section>
                    <div class="text-weight-medium">{{ sec.title }}</div>
                    <div v-if="sec.vendor?.name" class="text-caption text-grey-6">
                      {{ sec.vendor.name }}
                      <span v-if="sec.metadata?.invoice_number"> · Inv: {{ sec.metadata.invoice_number }}</span>
                    </div>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-btn-dropdown>

            <q-badge
              v-if="selectedSectionVendorName"
              color="grey-2"
              text-color="grey-9"
              class="q-ml-xs text-weight-medium"
              style="border-radius: 4px; font-size: 11px"
            >
              {{ selectedSectionVendorName }}
            </q-badge>
          </div>
        </div>

        <!-- Right: Actions (View mode, Columns, Bulk paste, Add, Refresh) -->
        <div class="row items-center q-gutter-xs justify-end">
          <q-btn-toggle
            v-model="lineItemsViewMode"
            flat
            dense
            no-caps
            size="sm"
            toggle-color="primary"
            color="grey-3"
            text-color="grey-8"
            :options="[
              { value: 'table', icon: 'ph ph-table' },
              { value: 'cards', icon: 'ph ph-rows' }
            ]"
            class="q-mr-xs border-grey"
          >
            <template v-slot:table>
              <q-tooltip>Table View</q-tooltip>
            </template>
            <template v-slot:cards>
              <q-tooltip>Card List View</q-tooltip>
            </template>
          </q-btn-toggle>

          <q-btn
            color="primary"
            outline
            no-caps
            size="sm"
            icon="ph ph-columns"
            dense
            label="Columns"
            class="q-px-sm"
          >
            <q-menu>
              <q-list style="min-width: 220px" class="q-py-xs">
                <q-item>
                  <q-item-section>
                    <div class="text-subtitle2 text-weight-bold text-primary">Show Columns</div>
                  </q-item-section>
                </q-item>
                <q-item clickable>
                  <q-item-section>
                    <q-checkbox v-model="allColumnsSelected" label="Select / Deselect All" />
                  </q-item-section>
                </q-item>
                <q-separator />
                <q-item v-for="col in availableColumnOptions" :key="col.value" clickable>
                  <q-item-section>
                    <q-checkbox
                      v-model="visibleColumns"
                      :val="col.value"
                      :label="col.label"
                    />
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>

          <q-btn
            v-if="isEditable"
            color="secondary"
            icon="ph ph-clipboard"
            label="Paste"
            unelevated
            dense
            no-caps
            size="sm"
            class="q-px-sm"
            @click="openBulkPaste"
          />

          <q-btn
            v-if="isEditable"
            color="primary"
            icon="ph ph-plus"
            label="Add Items"
            unelevated
            dense
            no-caps
            size="sm"
            class="q-px-sm"
            @click="openAddItems"
          />
        </div>
      </div>
    </div>

    <!-- Main Content Table/Grid -->
    <div class="col column no-wrap q-pa-sm shipment-items-body">
      <!-- Loading State -->
      <div v-if="shipmentStore.loading && !shipmentStore.currentShipment" class="text-center q-pa-xl">
        <q-spinner color="primary" size="3em" />
        <div class="text-grey-6 q-mt-md">Loading items...</div>
      </div>

      <!-- Error State -->
      <div v-else-if="shipmentStore.error && !shipmentStore.currentShipment" class="q-pa-md">
        <q-banner class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
          <template #action>
            <q-btn flat color="white" label="Back to Overview" @click="goBackToShipment" />
          </template>
        </q-banner>
      </div>

      <!-- Items Content -->
      <q-card
        v-else
        flat
        bordered
        class="col column no-wrap q-pa-none bg-white rounded-borders shipment-items-card"
      >
        <div
          v-if="!hasLineItems && !shipmentStore.loading"
          class="column items-center q-pa-xl text-center"
        >
          <q-icon name="ph ph-package" size="48px" color="grey-5" />
          <div class="text-subtitle1 text-weight-bold text-grey-8 q-mt-md">No products in this shipment yet</div>
          <div class="text-caption text-grey-6 q-mb-md">Start by adding items or paste them in bulk.</div>
          <q-btn
            v-if="isEditable"
            color="primary"
            unelevated
            no-caps
            dense
            size="md"
            icon="ph ph-plus"
            label="Add items"
            class="q-px-md"
            @click="openAddItems"
          />
        </div>

        <div v-else class="col shipment-items-fill">
          <ShipmentLineItemsTable
            v-if="lineItemsViewMode === 'table'"
            :items="displayedItems"
            :shipment="shipmentForLiveCosting"
            :loading="shipmentStore.loading"
            :visible-columns="visibleColumns"
            :purchase-currency-symbol="currentPurchaseCurrencySymbol"
            :cost-currency-symbol="currentCostCurrencySymbol"
            @edit-details="openEditItem"
            @delete="confirmDeleteItem"
          />
          <ShipmentItemCardGrid
            v-else
            :items="displayedItems"
            :shipment="shipmentForLiveCosting"
            :loading="shipmentStore.loading"
            :purchase-currency-symbol="currentPurchaseCurrencySymbol"
            :cost-currency-symbol="currentCostCurrencySymbol"
            @edit-details="openEditItem"
            @delete="confirmDeleteItem"
          />
        </div>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

// Components
import ShipmentLineItemsTable from '../components/ShipmentLineItemsTable.vue';
import ShipmentItemCardGrid from '../components/ShipmentItemCardGrid.vue';

// Composables
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { useInboundShipmentActions } from '../composables/useInboundShipmentActions';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const VIEW_MODE_STORAGE_KEY = 'inbound_shipment_line_items_view_mode';
const lineItemsViewMode = ref<'table' | 'cards'>('table');

onMounted(() => {
  const savedMode = localStorage.getItem(VIEW_MODE_STORAGE_KEY) as 'table' | 'cards' | null;
  if (savedMode && ['table', 'cards'].includes(savedMode)) {
    lineItemsViewMode.value = savedMode;
  }
});

const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('lines');
const assignShopCard = ref<HTMLElement | null>(null);
const paySettleCard = ref<HTMLElement | null>(null);

// Initialize Composables
const calculations = useInboundShipmentCalculations();
const actions = useInboundShipmentActions({
  shipmentId,
  activeTab,
  calculations,
  assignShopCard,
  paySettleCard,
});

const {
  shipmentForLiveCosting,
  isEditable,
  hasLineItems,
  availableColumnOptions,
  visibleColumns,
  allColumnsSelected,
  currentPurchaseCurrencySymbol,
  currentCostCurrencySymbol,
} = calculations;

const {
  currentVendorLabel,
  currentCargoLabel,
  loadShipmentDetails,
  openAddItems: baseOpenAddItems,
  openEditItem,
  confirmDeleteItem,
} = actions;

// Section Filtering Logic
const selectedSectionId = computed<number | null>(() => {
  const q = route.query.sectionId;
  return q ? Number(q) : null;
});

const activeSection = computed(() => {
  if (selectedSectionId.value == null) return null;
  return shipmentStore.currentShipmentSections.find((s) => s.id === selectedSectionId.value) ?? null;
});

const activeSectionLabel = computed(() => {
  if (!activeSection.value) return 'All Sections (Full Review)';
  return activeSection.value.title;
});

const selectedSectionVendorName = computed(() => {
  return activeSection.value?.vendor?.name || '';
});

const displayedItems = computed(() => {
  const allItems = shipmentStore.currentShipmentItems ?? [];
  if (selectedSectionId.value == null) return allItems;
  return allItems.filter(
    (it) =>
      it.section_id === selectedSectionId.value ||
      (shipmentStore.currentShipmentSections.length === 1 && it.section_id == null),
  );
});

const selectSection = (sectionId: number | null) => {
  const query = { ...route.query };
  if (sectionId == null) {
    delete query.sectionId;
  } else {
    query.sectionId = String(sectionId);
  }
  void router.push({ query });
};

import { useQuasar } from 'quasar';
import BulkPasteDialog from '../components/BulkPasteDialog.vue';
import AddShipmentItemsDrawer from '../components/AddShipmentItemsDrawer.vue';

const $q = useQuasar();

const openBulkPaste = () => {
  $q.dialog({
    component: BulkPasteDialog,
    componentProps: {
      initialSectionId: selectedSectionId.value,
    },
  }).onOk(() => {
    void loadShipmentDetails();
  });
};

const openAddItems = () => {
  $q.dialog({
    component: AddShipmentItemsDrawer,
    componentProps: {
      shipmentId,
    },
  }).onOk(() => {
    void loadShipmentDetails();
  });
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

onMounted(async () => {
  await loadShipmentDetails();
});
</script>

<style scoped>
.shipment-items-page .min-width-0,
.shipment-items-body,
.shipment-items-card,
.shipment-items-fill {
  min-width: 0;
  min-height: 0;
}

.shipment-items-fill {
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.shipment-items-fill > * {
  flex: 1;
  min-height: 0;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
</style>
