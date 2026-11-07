<template>
  <q-page class="q-pa-sm">
    <div class="column q-gutter-y-sm manual-catalog-page-layout" style="max-width: 960px; margin: 0 auto">
      <div class="row items-center no-wrap q-gutter-x-sm manual-catalog-header">
        <q-btn flat round dense icon="ph ph-arrow-left" @click="goBack" />
        <div class="col text-subtitle1 text-weight-bold ellipsis min-width-0">
          {{ $t('shop_admin.manual_catalog_order_title', 'Create catalog order') }}
        </div>
        <span class="manual-catalog-submit-wrap inline-block">
          <TfBtn
            color="primary"
            size="md"
            :label="$t('shop_admin.manual_catalog_submit', 'Create catalog order')"
            :disable="!canSubmit"
            :loading="isBusy"
            class="flex-shrink-0"
            data-test="manual-catalog-submit"
            @click="submit"
          />
          <q-tooltip v-if="submitDisabledTooltip">
            {{ submitDisabledTooltip }}
          </q-tooltip>
        </span>
      </div>

      <TfFolderTabs
        v-model="createTabModel"
        :tabs="manualCatalogCreateTabs"
        aria-label="Catalog order mode"
        class="col"
      >
        <div class="row q-col-gutter-sm">
          <div v-if="!isOldOrderTab" class="col-12 col-md-6">
            <q-select
              v-model="selectedShopId"
              dense
              outlined
              clearable
              emit-value
              map-options
              :options="shopSelectOptions"
              :label="$t('shop_admin.manual_catalog_shop_optional', 'Shop (optional)')"
              :hint="$t('shop_admin.manual_catalog_shop_optional_hint', 'Leave empty to search all catalog shops. Pick one if you have several.')"
              data-test="manual-catalog-shop"
            />
          </div>
          <div class="col-12 col-md-6">
            <q-select
              v-model="selectedCustomerGroupId"
              dense
              outlined
              emit-value
              map-options
              use-input
              fill-input
              hide-selected
              input-debounce="200"
              :loading="booksCustomerGroupsQuery.isLoading.value"
              :options="filteredCustomerGroupSelectOptions"
              :label="$t('shop_admin.manual_order_customer_group', 'Customer group')"
              data-test="manual-catalog-group"
              @filter="filterCustomerGroups"
            >
              <template #no-option>
                <q-item>
                  <q-item-section class="text-grey-6">
                    {{
                      booksCustomerGroupsQuery.isLoading.value
                        ? $t('common.loading', 'Loading…')
                        : $t('shop_admin.no_customer_groups', 'No customer groups yet.')
                    }}
                  </q-item-section>
                </q-item>
              </template>
            </q-select>
          </div>
          <div class="col-12 col-md-6">
            <q-input
              v-model="recordedAtDate"
              dense
              outlined
              hide-bottom-space
              readonly
              clearable
              class="manual-catalog-order-date-input cursor-pointer"
              :rules="orderDateRules"
              :label="$t('shop_admin.manual_catalog_order_date', 'Order date') + ' *'"
              data-test="manual-catalog-order-date"
              @click="openOrderDatePicker"
            >
              <template #append>
                <q-icon
                  name="ph ph-calendar"
                  class="cursor-pointer"
                  @click.stop="openOrderDatePicker"
                >
                  <q-popup-proxy
                    ref="orderDatePopupRef"
                    cover
                    transition-show="scale"
                    transition-hide="scale"
                  >
                    <q-date
                      v-model="recordedAtDate"
                      mask="YYYY-MM-DD"
                      @update:model-value="onOrderDatePicked"
                    />
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
          <div class="col-12">
            <q-toggle
              v-model="hiddenFromCustomer"
              dense
              :label="$t('shop_admin.manual_catalog_hide_from_customer', 'Hide from customer storefront')"
            />
          </div>
        </div>

        <template v-if="isOldOrderTab">
          <div class="row items-center q-gutter-sm q-mb-sm manual-catalog-body-split">
            <div class="text-subtitle2 text-weight-bold">
              {{ $t('shop_admin.manual_catalog_old_order_setup', 'Old order setup') }}
            </div>
            <OrderPricingModeBadge :is-negotiable="false" shop-type="vendor_catalog" />
          </div>
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-md-6">
              <q-select
                v-model="oldOrderInitialStatus"
                dense
                outlined
                emit-value
                map-options
                :options="oldOrderStatusOptions"
                :label="$t('shop_admin.manual_catalog_old_order_status', 'Order status')"
              />
            </div>
            <div class="col-12 col-md-6">
              <q-select
                v-model="oldOrderRates.profit_basis"
                dense
                outlined
                emit-value
                map-options
                :options="profitBasisOptions"
                :label="$t('shop_admin.manual_catalog_profit_basis', 'Profit basis')"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-4">
              <q-input
                v-model.number="oldOrderRates.conversion_rate"
                dense
                outlined
                type="number"
                step="0.01"
                :label="$t('shop_admin.manual_catalog_rate_fx', 'Conversion rate (FX)')"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-4">
              <q-input
                v-model.number="oldOrderRates.cargo_rate"
                dense
                outlined
                type="number"
                step="0.01"
                :label="$t('shop_admin.manual_catalog_rate_cargo', 'Cargo rate')"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-4">
              <q-input
                v-model.number="oldOrderRates.profit_rate"
                dense
                outlined
                type="number"
                step="0.01"
                :label="$t('shop_admin.manual_catalog_rate_profit', 'Profit rate %')"
              />
            </div>
          </div>
          <div class="text-caption text-grey-7 q-mt-sm">
            {{ $t('shop_admin.manual_catalog_old_order_hint', 'Non-negotiable. Enter customer sell price per line.') }}
          </div>
        </template>

        <ManualCatalogOrderItemSearch :disabled="isBusy" @open-add-items="openAddItemsDrawer" />

        <ManualCatalogOrderLinesTable
          :items="items"
          :old-order-mode="isOldOrderTab"
          :disable="isBusy"
          @update-qty="onQtyChange"
          @update-cost="onCostChange"
          @update-sell="onSellPriceChange"
          @remove="removeLine"
          @bulk-update="openBulkUpdate"
        />
      </TfFolderTabs>
    </div>

    <ManualCatalogAddItemsDrawer
      v-model="addItemsDrawerOpen"
      :tenant-id="tenantId"
      :browse-shop-ids="browseShopIds"
      :old-order-mode="isOldOrderTab"
      @add-product="onDrawerAddProduct"
    />
    <ManualCatalogOrderBulkPastePanel ref="bulkPastePanelRef" :items="lineItems" />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import type { QPopupProxy } from 'quasar';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfFolderTabs from 'src/components/ui/TfFolderTabs.vue';
import {
  requestUnsavedChangesConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import { useShopListQuery } from '../composables/useShopQuery';
import { useManualCatalogOrder, type ManualCatalogCreateTab } from '../composables/useManualCatalogOrder';
import ManualCatalogOrderItemSearch from '../components/manual/ManualCatalogOrderItemSearch.vue';
import ManualCatalogOrderLinesTable from '../components/manual/ManualCatalogOrderLinesTable.vue';
import ManualCatalogAddItemsDrawer from '../components/manual/ManualCatalogAddItemsDrawer.vue';
import ManualCatalogOrderBulkPastePanel from '../components/manual/ManualCatalogOrderBulkPastePanel.vue';
import OrderPricingModeBadge from '../components/OrderPricingModeBadge.vue';
import type { ShopCatalogItem } from '../types';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const parseCreateTabFromQuery = (raw: unknown): ManualCatalogCreateTab => {
  if (typeof raw !== 'string') return 'standard';
  if (raw === 'old_order' || raw === 'history') return 'old_order';
  if (raw === 'standard' || raw === 'new') return 'standard';
  return 'standard';
};
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const parentTenantId = computed(() => authStore.selectedTenant?.parent_id ?? authStore.tenantId);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const shopListParams = computed(() => ({
  tenantId: tenantId.value,
  parentTenantId: parentTenantId.value,
}));

const shopListQuery = useShopListQuery(shopListParams);
const shops = computed(() => shopListQuery.data.value ?? []);

const vendorCatalogShopIds = computed(() =>
  shops.value.filter((s) => s.shop_type === 'vendor_catalog').map((s) => s.id),
);

const shopSelectOptions = computed(() =>
  shops.value
    .filter((s) => s.shop_type === 'vendor_catalog')
    .map((s) => ({ label: s.name, value: s.id })),
);

const manualCatalogCreateTabs = computed(() => [
  {
    name: 'standard',
    label: t('shop_admin.manual_catalog_tab_create', 'New order'),
  },
  {
    name: 'old_order',
    label: t('shop_admin.manual_catalog_tab_history', 'Order history'),
  },
]);

const {
  createTab,
  isOldOrderTab,
  oldOrderInitialStatus,
  oldOrderRates,
  selectedShopId,
  selectedCustomerGroupId,
  recordedAtDate,
  hiddenFromCustomer,
  customerGroupOptions,
  booksCustomerGroupsQuery,
  items,
  lineItems,
  browseShopIds,
  addProduct,
  setLineQuantity,
  setLineCostPrice,
  setLineSellPrice,
  removeLine,
  submitMutation,
  isBusy,
  canSubmit,
  submitBlocker,
  hasDraftChanges,
} = useManualCatalogOrder({
  tenantId,
  parentTenantId,
  vendorCatalogShopIds,
});

watch(
  () => route.query.mode,
  (mode) => {
    const next = parseCreateTabFromQuery(mode);
    if (createTab.value !== next) createTab.value = next;
  },
  { immediate: true },
);

const submitDisabledTooltip = computed(() => {
  const blocker = submitBlocker.value;
  if (!blocker || blocker === 'submitting') return '';
  switch (blocker) {
    case 'customer_group':
      return t('shop_admin.manual_catalog_submit_blocked_customer_group', 'Choose a customer group.');
    case 'order_date':
      return t('shop_admin.manual_catalog_submit_blocked_order_date', 'Choose an order date.');
    case 'no_lines':
      return t('shop_admin.manual_catalog_submit_blocked_no_lines', 'Add at least one line with Add Items.');
    case 'line_sell_required':
      return t(
        'shop_admin.manual_catalog_submit_blocked_line_sell_required',
        'Order history: enter a sell price on every line in the table.',
      );
    case 'old_order_rates':
      return t(
        'shop_admin.manual_catalog_submit_blocked_old_order_rates',
        'Order history: fill conversion rate, cargo rate, profit rate %, and profit basis.',
      );
    default:
      return '';
  }
});

const createTabModel = computed({
  get(): ManualCatalogCreateTab {
    return createTab.value;
  },
  set(tab: ManualCatalogCreateTab) {
    if (createTab.value !== tab) createTab.value = tab;
    const mode = tab;
    if (route.query.mode === mode) return;
    void router.replace({
      params: route.params,
      query: { ...route.query, mode },
    });
  },
});

const addItemsDrawerOpen = ref(false);
const bulkPastePanelRef = ref<InstanceType<typeof ManualCatalogOrderBulkPastePanel> | null>(null);
const skipLeaveGuard = ref(false);

const confirmDiscardDraft = async (): Promise<boolean> => {
  if (skipLeaveGuard.value || !hasDraftChanges.value) return true;
  const choice = await requestUnsavedChangesConfirmation(
    t(
      'shop_admin.manual_catalog_leave_unsaved',
      'This catalog order is not saved. If you leave now, you will lose your work.',
    ),
    t('shop_admin.manual_catalog_leave_title', 'Leave without saving?'),
  );
  return choice === 'discard';
};

onBeforeRouteLeave(async () => confirmDiscardDraft());

const onBeforeUnload = (event: BeforeUnloadEvent) => {
  if (skipLeaveGuard.value || !hasDraftChanges.value) return;
  event.preventDefault();
};

if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', onBeforeUnload);
}

onBeforeUnmount(() => {
  if (typeof window !== 'undefined') {
    window.removeEventListener('beforeunload', onBeforeUnload);
  }
});

const orderDatePopupRef = ref<QPopupProxy | null>(null);

const openOrderDatePicker = () => {
  orderDatePopupRef.value?.show();
};

const onOrderDatePicked = () => {
  orderDatePopupRef.value?.hide();
};

const orderDateRules = [
  (v: string | null | undefined) =>
    (v != null && String(v).trim().length > 0) ||
    t('shop_admin.manual_catalog_order_date_required', 'Order date is required'),
];

const customerGroupSelectOptions = computed(() =>
  customerGroupOptions.value.map((g) => ({ label: g.name, value: g.id })),
);

const customerGroupFilterNeedle = ref('');

const filteredCustomerGroupSelectOptions = computed(() => {
  const needle = customerGroupFilterNeedle.value.trim().toLowerCase();
  if (!needle) return customerGroupSelectOptions.value;
  return customerGroupSelectOptions.value.filter((opt) => opt.label.toLowerCase().includes(needle));
});

const filterCustomerGroups = (val: string, update: (cb: () => void) => void) => {
  update(() => {
    customerGroupFilterNeedle.value = val;
  });
};

const oldOrderStatusOptions = computed(() => [
  { label: t('shop_admin.status_procuring', 'Procuring'), value: 'procuring' as const },
  { label: t('shop_admin.status_delivered', 'Delivered'), value: 'delivered' as const },
  { label: t('shop_admin.status_closed', 'Closed'), value: 'closed' as const },
]);

const profitBasisOptions = [
  { label: 'Purchase', value: 'purchase' as const },
  { label: 'Total cost', value: 'total_cost' as const },
];

const onCostChange = (localId: string, amount: number) => {
  setLineCostPrice(localId, amount);
};

const onSellPriceChange = (localId: string, amount: number) => {
  setLineSellPrice(localId, amount);
};

const onQtyChange = (localId: string, qty: number) => {
  setLineQuantity(localId, qty);
};

const openAddItemsDrawer = () => {
  addItemsDrawerOpen.value = true;
};

const onDrawerAddProduct = (row: ShopCatalogItem, qty: number) => {
  try {
    addProduct(row, qty);
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : t('common.error_generic', 'Something went wrong'));
  }
};

const openBulkUpdate = () => {
  bulkPastePanelRef.value?.openBulkPasteDialog('all');
};

const goBack = async () => {
  if (!(await confirmDiscardDraft())) return;
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  void router.push(`${slug}/app/shop/orders`);
};

const submit = async () => {
  try {
    const result = await submitMutation.mutateAsync();
    if (result.billing_profile_warning) {
      showErrorNotification(
        t(
          'shop_admin.manual_order_billing_profile_warning',
          'Order created but no billing profile is linked to this customer group. Link a profile before fulfillment.',
        ),
      );
    } else {
      showSuccessNotification(t('shop.place_order_success', 'Order placed successfully'));
    }
    skipLeaveGuard.value = true;
    const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
    void router.push(`${slug}/app/shop/orders/${result.order_id}`);
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : t('common.error_generic', 'Something went wrong'));
  }
};
</script>

<script lang="ts">
export default {
  name: 'ManualCatalogOrderPage',
};
</script>

<style scoped>
.manual-catalog-page-layout {
  min-height: calc(100dvh - 16px);
}

.manual-catalog-body-split {
  padding-top: 16px;
  border-top: 1px solid var(--tf-neutral-border);
}

.manual-catalog-header {
  max-width: 100%;
}

.manual-catalog-submit-wrap {
  display: inline-block;
}

.manual-catalog-line {
  padding: 4px 0;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.manual-catalog-line:last-child {
  border-bottom: none;
}
</style>
