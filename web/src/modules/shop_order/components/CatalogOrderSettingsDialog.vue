<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="shop_order.catalog-settings-drawer-width"
    :default-width="520"
    :min-width="360"
    :max-width="960"
    aria-label="Catalog order settings"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <div class="column full-height no-wrap overflow-hidden catalog-settings-drawer">
      <TfDrawerSectionTabsHeader
        v-model="activeTab"
        :tabs="visibleSettingsTabs"
        aria-label="Catalog order settings sections"
      >
        <template #trailing>
          <q-btn
            flat
            round
            dense
            icon="ph ph-x"
            color="grey-7"
            aria-label="Close settings"
            class="catalog-settings-drawer__close shrink-0"
            @click="emit('update:modelValue', false)"
          />
        </template>
      </TfDrawerSectionTabsHeader>

      <q-tab-panels v-model="activeTab" animated class="col bg-white catalog-settings-drawer-panels">
        <q-tab-panel name="summary" class="catalog-settings-tab-pane catalog-settings-tab-pane--summary">
          <CatalogOrderItemsSummaryCards
            :item-count="itemCount"
            :buy-currency-symbol="buyCurrencySymbol"
            :sell-currency-symbol="sellCurrencySymbol"
            :conversion-rate="conversionRate"
            :cargo-rate="cargoRate"
            :totals="totals"
          />
        </q-tab-panel>

        <q-tab-panel name="bills" class="catalog-settings-tab-pane q-pa-md">
          <CatalogOrderBillsPanel
            v-if="order"
            :tenant-id="billsParentTenantId ?? null"
            :order-id="order.id"
            :enabled="billsListEnabled"
            @open-bill="(bill) => emit('open-bill', bill)"
          />
        </q-tab-panel>

        <q-tab-panel name="delivery" class="catalog-settings-tab-pane q-pa-md">
          <div v-if="!showDeliveryPapers" class="text-body2 text-grey-7">
            Delivery papers are available once the order is procuring or in fulfillment (dispatch,
            delivered, or closed).
          </div>
          <DocumentDeliveryPaperChips
            v-else-if="order"
            layout="section"
            document-type="shop_order"
            :tenant-id="deliveryPaperTenantId ?? null"
            :document-id="order.id"
            :enabled="deliveryPapersEnabled"
            :allow-create="allowCreateDeliveryPaper"
            @open-paper="(id) => emit('open-delivery-paper', id)"
            @created="(id) => emit('open-delivery-paper', id)"
          />
        </q-tab-panel>

        <q-tab-panel name="actions" class="catalog-settings-tab-pane q-pa-md">
          <div class="column q-gutter-y-sm">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs q-mb-sm">
              <q-icon name="ph ph-dots-three-outline" size="18px" color="primary" />
              <span>Order actions</span>
            </div>

            <div
              v-if="order?.shop_type_snapshot === 'vendor_catalog'"
              class="q-pa-sm rounded-borders border-grey-3 q-mb-sm"
            >
              <q-toggle
                :model-value="!!order.hidden_from_customer"
                :disable="hiddenFromCustomerSaving"
                :label="$t('shop_admin.manual_catalog_hide_from_customer', 'Hide from customer storefront')"
                data-test="catalog-order-hidden-from-customer"
                @update:model-value="(val) => emit('update-hidden-from-customer', !!val)"
              />
              <div class="text-caption text-grey-7 q-mt-xs">
                {{
                  $t(
                    'shop_admin.order_hidden_from_customer_hint',
                    'When on, the customer does not see this order in their storefront.',
                  )
                }}
              </div>
            </div>

            <q-btn-dropdown
              flat
              no-caps
              align="left"
              icon="ph ph-file-xls"
              label="Download Excel"
              class="rounded-sq-btn action-list-btn"
              auto-close
              :disable="!canDownloadExcel"
            >
              <q-list dense class="q-py-xs" style="min-width: 220px">
                <q-item clickable v-ripple @click="emit('download-excel', { includeImages: true })">
                  <q-item-section avatar style="min-width: 28px">
                    <q-icon name="ph ph-image" size="16px" color="positive" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-caption text-weight-medium">With images</q-item-label>
                    <q-item-label caption>Product pictures in column B</q-item-label>
                  </q-item-section>
                </q-item>
                <q-item clickable v-ripple @click="emit('download-excel', { includeImages: false })">
                  <q-item-section avatar style="min-width: 28px">
                    <q-icon name="ph ph-table" size="16px" color="grey-8" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-caption text-weight-medium">Without images</q-item-label>
                    <q-item-label caption>Faster export, compact rows</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-btn-dropdown>
            <q-btn
              v-if="showCancel"
              flat
              no-caps
              align="left"
              color="negative"
              icon="ph ph-trash"
              label="Cancel order"
              class="rounded-sq-btn action-list-btn"
              :loading="isDeleting"
              @click="emit('cancel-order')"
            />
          </div>
        </q-tab-panel>
      </q-tab-panels>
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import TfDrawerSectionTabsHeader from 'src/components/ui/TfDrawerSectionTabsHeader.vue';
import CatalogOrderItemsSummaryCards from './CatalogOrderItemsSummaryCards.vue';
import DocumentDeliveryPaperChips from 'src/modules/procurement_stock/components/DocumentDeliveryPaperChips.vue';
import CatalogOrderBillsPanel from './CatalogOrderBillsPanel.vue';
import type { ShopOrder } from '../types';
import type { ShopOrderBillListItem } from '../types/shopOrderBillList';
import type { CostingTotalsSummary } from 'src/types/costingTotalsSummary';

export type CatalogOrderSummaryTotals = CostingTotalsSummary;

const props = defineProps<{
  modelValue: boolean;
  order: ShopOrder | null;
  itemCount: number;
  buyCurrencySymbol: string;
  sellCurrencySymbol: string;
  conversionRate: number;
  cargoRate: number;
  totals: CostingTotalsSummary;
  showCancel?: boolean;
  isDeleting?: boolean;
  canDownloadExcel?: boolean;
  deliveryPaperTenantId?: number | null;
  billsParentTenantId?: number | null;
  showDeliveryPapers?: boolean;
  allowCreateDeliveryPaper?: boolean;
  hiddenFromCustomerSaving?: boolean;
}>();

const deliveryPapersEnabled = computed(
  () =>
    !!props.modelValue &&
    !!props.showDeliveryPapers &&
    props.deliveryPaperTenantId != null &&
    !!props.order?.id,
);

const billsListEnabled = computed(
  () =>
    showBillsTab.value &&
    !!props.modelValue &&
    props.billsParentTenantId != null &&
    !!props.order?.id,
);

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'download-excel', payload: { includeImages: boolean }): void;
  (e: 'cancel-order'): void;
  (e: 'open-delivery-paper', paperId: number): void;
  (e: 'open-bill', bill: ShopOrderBillListItem): void;
  (e: 'update-hidden-from-customer', hidden: boolean): void;
}>();

const settingsTabs = [
  { name: 'summary', label: 'Summary', icon: 'ph ph-chart-pie-slice' },
  { name: 'bills', label: 'Bills', icon: 'ph ph-receipt' },
  { name: 'delivery', label: 'Delivery', icon: 'ph ph-truck' },
  { name: 'actions', label: 'Actions', icon: 'ph ph-dots-three-outline' },
] as const;

const showBillsTab = computed(() => !!props.showDeliveryPapers);

const visibleSettingsTabs = computed(() =>
  settingsTabs.filter((tab) => tab.name !== 'bills' || showBillsTab.value),
);

const activeTab = ref<(typeof settingsTabs)[number]['name']>('summary');

watch(showBillsTab, (visible) => {
  if (!visible && activeTab.value === 'bills') {
    activeTab.value = 'summary';
  }
});
</script>

<style scoped>
.catalog-settings-drawer-panels {
  min-height: 0;
  overflow: auto;
}

.catalog-settings-tab-pane {
  min-width: 0;
}

.catalog-settings-tab-pane--summary {
  padding: 0;
}

.rounded-sq-btn {
  border-radius: 8px !important;
}

.action-list-btn {
  width: 100%;
}
</style>
