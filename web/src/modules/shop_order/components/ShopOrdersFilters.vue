<template>
  <q-card flat class="floating-surface q-pa-xs flex-shrink-0">
    <div class="row items-center q-col-gutter-xs">
      <div class="col-12 row items-center q-gutter-x-xs">
        <q-input
          :model-value="search"
          clearable
          debounce="350"
          dense
          outlined
          rounded
          style="min-width: 220px"
          class="col-grow col-sm-auto"
          :placeholder="$t('shop_admin.search_orders_placeholder')"
          data-test="shop-orders-search"
          @update:model-value="(val) => emit('update:search', (val as string) || '')"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-6" />
          </template>
        </q-input>

        <q-select
          :model-value="selectedShopId"
          dense
          outlined
          rounded
          emit-value
          map-options
          clearable
          use-input
          input-debounce="200"
          :label="$t('shop_admin.filter_by_shop')"
          :options="filteredShopOptions"
          :loading="shopsLoading"
          style="min-width: 180px"
          class="col-grow col-sm-auto"
          data-test="shop-orders-shop-filter"
          @filter="filterShops"
          @update:model-value="(val) => emit('update:selectedShopId', val)"
        >
          <template #no-option>
            <q-item>
              <q-item-section class="text-grey-6">
                {{ shopsLoading ? $t('shop_admin.loading_orders') : $t('shop_admin.no_shops_found') }}
              </q-item-section>
            </q-item>
          </template>
        </q-select>

        <q-select
          :model-value="shopTypeFilter"
          dense
          outlined
          rounded
          emit-value
          map-options
          clearable
          :label="$t('shop_admin.shop_type_filter')"
          :options="shopTypeOptions"
          style="min-width: 160px"
          class="col-grow col-sm-auto"
          data-test="shop-orders-type-filter"
          @update:model-value="(val) => emit('update:shopTypeFilter', val)"
        />

        <q-select
          :model-value="statusFilter"
          dense
          outlined
          rounded
          emit-value
          map-options
          clearable
          :label="$t('shop_admin.filter_by_status')"
          :options="statusOptions"
          style="min-width: 160px"
          class="col-grow col-sm-auto"
          data-test="shop-orders-status-filter"
          @update:model-value="(val) => emit('update:statusFilter', val)"
        />
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import type { Shop } from '../types';

const props = defineProps<{
  shops: Shop[];
  selectedShopId: number | null;
  search: string;
  statusFilter: string | null;
  shopTypeFilter?: string | null;
  shopsLoading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:selectedShopId', value: number | null): void;
  (e: 'update:search', value: string): void;
  (e: 'update:statusFilter', value: string | null): void;
  (e: 'update:shopTypeFilter', value: string | null): void;
}>();

const { t } = useI18n();

const shopSearch = ref('');

const shopTypeOptions = computed(() => [
  { label: t('shop_admin.all_shop_types'), value: null },
  { label: t('shop_admin.shop_type_vendor_catalog'), value: 'vendor_catalog' },
  { label: t('shop_admin.shop_type_dropship'), value: 'dropship' },
  { label: t('shop_admin.shop_type_fixed_price'), value: 'fixed_price' },
]);

const statusOptions = computed(() => [
  { label: t('shop_admin.all_statuses'), value: null },
  { label: t('shop_admin.status_submitted'), value: 'submitted' },
  { label: t('shop_admin.status_costing_pending'), value: 'costing_pending' },
  { label: t('shop_admin.status_priced'), value: 'priced' },
  { label: t('shop_admin.status_countered'), value: 'countered' },
  { label: t('shop_admin.status_final_offered'), value: 'final_offered' },
  { label: t('shop_admin.status_confirmed'), value: 'confirmed' },
  { label: t('shop_admin.status_procuring'), value: 'procuring' },
  { label: t('shop_admin.status_ordered'), value: 'ordered' },
  { label: t('shop_admin.status_delivered'), value: 'delivered' },
  { label: t('shop_admin.status_processing'), value: 'processing' },
  { label: t('shop_admin.status_shipped'), value: 'shipped' },
  { label: t('shop_admin.status_payment_received'), value: 'payment_received' },
  { label: t('shop_admin.status_negotiating'), value: 'negotiating' },
  { label: t('shop_admin.status_placed'), value: 'placed' },
  { label: t('shop_admin.status_fulfilled'), value: 'fulfilled' },
  { label: t('shop_admin.status_cancelled'), value: 'cancelled' },
]);

const shopOptions = computed(() =>
  props.shops.map((shop) => ({
    label: shop.name,
    value: shop.id,
  })),
);

const filteredShopOptions = computed(() => {
  const needle = shopSearch.value.trim().toLowerCase();
  if (!needle) {
    return shopOptions.value;
  }
  return shopOptions.value.filter((opt) => opt.label.toLowerCase().includes(needle));
});

const filterShops = (val: string, update: (cb: () => void) => void) => {
  update(() => {
    shopSearch.value = val;
  });
};
</script>

<style scoped>
.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: none;
  box-shadow: none;
}

body.body--dark .floating-surface {
  background: #1c1c1c;
}
</style>
