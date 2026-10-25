<template>
  <q-page class="q-pa-sm">
    <div class="column q-gutter-y-sm" style="max-width: 960px; margin: 0 auto">
      <div class="row items-center q-gutter-x-sm">
        <q-btn flat round dense icon="ph ph-arrow-left" @click="goBack" />
        <div class="text-subtitle1 text-weight-bold">
          {{ $t('shop_admin.manual_dropship_order_title', 'Create dropship order') }}
        </div>
      </div>

      <q-card flat bordered class="q-pa-sm">
        <div class="row q-col-gutter-sm">
          <div class="col-12 col-md-6">
            <q-select
              v-model="selectedShopId"
              dense
              outlined
              emit-value
              map-options
              :options="shopOptions"
              :label="$t('shop_admin.filter_by_shop', 'Shop')"
              data-test="manual-dropship-shop"
            />
          </div>
          <div class="col-12 col-md-6">
            <q-select
              v-model="selectedCustomerGroupId"
              dense
              outlined
              emit-value
              map-options
              :loading="booksCustomerGroupsQuery.isLoading.value"
              :options="customerGroupSelectOptions"
              :label="$t('shop_admin.manual_order_customer_group', 'Customer group')"
              data-test="manual-dropship-group"
            />
          </div>
        </div>
      </q-card>

      <ManualDropshipOrderItemSearch
        v-model:search="itemSearch"
        :active-query="activeSearch"
        :listings="listings"
        :loading="browseQuery.isFetching.value"
        :disabled="!contextReady"
        :adding="false"
        @submit="submitItemSearch"
        @add="onAddListing"
      />

      <q-card v-if="items.length" flat bordered class="q-pa-sm">
        <div class="text-subtitle2 text-weight-bold q-mb-sm">
          {{ $t('shop_admin.manual_order_lines', 'Order lines') }}
        </div>
        <div class="column q-gutter-y-sm">
          <ShopDropshipCartItemCard
            v-for="item in items"
            :key="item.localId"
            :name="item.name"
            :image-url="item.image_url"
            :quantity="item.quantity"
            :price="getLineUnitPrice(item)"
            :currency-symbol="currencySymbol"
            :min-qty="1"
            show-resell-input
            :min-resell-price="item.minimum_sell_price_amount"
            :disable-qty="isBusy"
            :disable-resell="isBusy"
            :disable-remove="isBusy"
            @update:quantity="(qty) => onQtyChange(item.localId, qty)"
            @update:price="(p) => setLineSellPrice(item.localId, p)"
            @remove="() => removeLine(item.localId)"
          />
        </div>
      </q-card>

      <q-card flat bordered class="q-pa-sm">
        <div class="text-subtitle2 text-weight-bold q-mb-sm">
          {{ $t('shop.shipping_info', 'Shipping') }}
        </div>
        <div class="row q-col-gutter-sm">
          <div class="col-12 col-sm-6">
            <q-input
              v-model="recipientName"
              dense
              outlined
              hide-bottom-space
              :label="$t('shop.recipient_name') + ' *'"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-input
              v-model="recipientPhone"
              dense
              outlined
              hide-bottom-space
              :label="$t('shop.recipient_phone') + ' *'"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-input
              v-model="recipientPhoneSecondary"
              dense
              outlined
              hide-bottom-space
              :label="$t('shop.recipient_phone_secondary', 'Secondary phone')"
            />
          </div>
          <div class="col-12">
            <q-input
              v-model="shippingAddress"
              dense
              outlined
              type="textarea"
              autogrow
              hide-bottom-space
              :label="$t('shop.shipping_address') + ' *'"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-input
              v-model="shippingDistrict"
              dense
              outlined
              hide-bottom-space
              :label="$t('shop.shipping_district', 'District')"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-input
              v-model="shippingThana"
              dense
              outlined
              hide-bottom-space
              :label="$t('shop.shipping_thana', 'Thana')"
            />
          </div>
          <div class="col-12">
            <q-input
              v-model="deliveryInstructions"
              dense
              outlined
              type="textarea"
              autogrow
              hide-bottom-space
              :label="$t('shop_admin.manual_order_channel_note', 'Channel / note (optional)')"
            />
          </div>
        </div>
      </q-card>

      <TfBtn
        color="primary"
        class="full-width"
        :label="$t('shop.place_order', 'Place order')"
        :disable="!canSubmit"
        :loading="submitMutation.isPending.value"
        data-test="manual-dropship-submit"
        @click="submit"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import TfBtn from 'src/components/ui/TfBtn.vue';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { useShopOrdersStaffPageQuery } from '../composables/useShopOrdersStaffPageQuery';
import { useManualDropshipOrder } from '../composables/useManualDropshipOrder';
import ManualDropshipOrderItemSearch from '../components/manual/ManualDropshipOrderItemSearch.vue';
import ShopDropshipCartItemCard from '../components/ShopDropshipCartItemCard.vue';
import type { StaffDropshipListingRow } from '../repositories/staffManualDropshipOrderRepository';

const router = useRouter();
const { t } = useI18n();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const parentTenantId = computed(() => authStore.selectedTenant?.parent_id ?? authStore.tenantId);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const pageParams = computed(() => ({
  tenantId: tenantId.value,
  parentTenantId: parentTenantId.value,
  shopType: 'dropship' as const,
}));

const { shops } = useShopOrdersStaffPageQuery(pageParams);

const shopOptions = computed(() =>
  shops.value
    .filter((s) => s.shop_type === 'dropship')
    .map((s) => ({ label: s.name, value: s.id })),
);

const {
  selectedShopId,
  selectedCustomerGroupId,
  itemSearch,
  activeSearch,
  submitItemSearch,
  recipientName,
  recipientPhone,
  recipientPhoneSecondary,
  shippingAddress,
  shippingDistrict,
  shippingThana,
  deliveryInstructions,
  customerGroupOptions,
  booksCustomerGroupsQuery,
  browseQuery,
  listings,
  items,
  currencySymbol,
  getLineUnitPrice,
  addListing,
    setLineQuantity,
    setLineSellPrice,
    removeLine,
  submitMutation,
  isBusy,
  canSubmit,
} = useManualDropshipOrder({
  tenantId,
  parentTenantId,
});

const contextReady = computed(
  () => (selectedShopId.value ?? 0) > 0 && (selectedCustomerGroupId.value ?? 0) > 0,
);

const customerGroupSelectOptions = computed(() =>
  customerGroupOptions.value.map((g) => ({ label: g.name, value: g.id })),
);

const onAddListing = (row: StaffDropshipListingRow) => {
  try {
    addListing(row);
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : t('common.error_generic', 'Something went wrong'));
  }
};

const onQtyChange = (localId: string, qty: number) => {
  try {
    setLineQuantity(localId, qty);
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : t('common.error_generic', 'Something went wrong'));
  }
};

const goBack = () => {
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
          'Order created but no billing profile is linked to this customer group. Link a profile before shipping.',
        ),
      );
    } else {
      showSuccessNotification(t('shop.place_order_success', 'Order placed successfully'));
    }
    const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
    void router.push(`${slug}/app/shop/orders/${result.order_id}`);
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : t('common.error_generic', 'Something went wrong'));
  }
};
</script>

<script lang="ts">
export default {
  name: 'ManualDropshipOrderPage',
};
</script>
