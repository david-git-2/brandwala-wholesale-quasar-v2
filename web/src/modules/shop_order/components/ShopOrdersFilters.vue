<template>
  <q-card flat bordered class="q-pa-xs flex-shrink-0">
    <div class="row items-center q-gutter-x-xs wrap full-width">
        <q-input
          :model-value="search"
          clearable
          dense
          outlined
          rounded
          style="min-width: 220px"
          class="col-grow col-sm-auto"
          :placeholder="$t('shop_admin.search_orders_placeholder', 'Search by Order No, recipient, shop...')"
          data-test="shop-orders-search"
          @update:model-value="onSearchInput"
          @keyup.enter="emit('apply-search')"
          @clear="emit('apply-search')"
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
          use-input
          input-debounce="200"
          :label="$t('shop_admin.filter_by_shop', 'Shop')"
          :options="filteredShopOptions"
          :loading="shopsLoading"
          style="min-width: 190px"
          class="col-grow col-sm-auto"
          data-test="shop-orders-shop-filter"
          @filter="filterShops"
          @update:model-value="(val) => emit('update:selectedShopId', val)"
        >
          <template #prepend>
            <q-icon name="ph ph-storefront" size="16px" class="text-grey-6" />
          </template>
          <template #no-option>
            <q-item>
              <q-item-section class="text-grey-6">
                {{ shopsLoading ? $t('shop_admin.loading_orders') : $t('shop_admin.no_shops_found') }}
              </q-item-section>
            </q-item>
          </template>
        </q-select>

        <q-select
          :model-value="statusFilter"
          dense
          outlined
          rounded
          emit-value
          map-options
          :label="$t('shop_admin.filter_by_status', 'Status')"
          :options="statusOptions"
          style="min-width: 160px"
          class="col-grow col-sm-auto"
          data-test="shop-orders-status-filter"
          @update:model-value="(val) => emit('update:statusFilter', val)"
        >
          <template #prepend>
            <q-icon name="ph ph-flag" size="16px" class="text-grey-6" />
          </template>
        </q-select>

      <div class="row items-center no-wrap q-gutter-x-xs q-ml-auto flex-shrink-0">
        <TfBtn
          color="primary"
          size="sm"
          icon="ph ph-plus"
          :label="$t('shop_admin.create_dropship_order', 'Create dropship order')"
          data-test="shop-orders-create-dropship"
          @click="emit('create-dropship')"
        />
        <q-btn
          flat
          round
          dense
          icon="ph ph-arrows-clockwise"
          class="text-grey-7"
          :loading="refreshing"
          :aria-label="$t('common.refresh', 'Refresh')"
          data-test="shop-orders-refresh"
          @click="emit('refresh')"
        >
          <q-tooltip :delay="400">{{ $t('common.refresh', 'Refresh') }}</q-tooltip>
        </q-btn>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { StaffOrdersPageShop } from '../types';

const props = defineProps<{
  shops: StaffOrdersPageShop[];
  selectedShopId: number | null;
  search: string;
  statusFilter: string | null;
  shopsLoading?: boolean;
  refreshing?: boolean;
}>();

const emit = defineEmits<{
  (e: 'refresh'): void;
  (e: 'create-dropship'): void;
  (e: 'apply-search'): void;
  (e: 'update:selectedShopId', value: number | null): void;
  (e: 'update:search', value: string): void;
  (e: 'update:statusFilter', value: string | null): void;
}>();

const onSearchInput = (val: string | number | null) => {
  const next = (val as string) || '';
  emit('update:search', next);
  if (!next) {
    emit('apply-search');
  }
};

const { t } = useI18n();

const shopSearch = ref('');

const statusOptions = computed(() => [
  { label: t('shop_admin.all_statuses'), value: null },
  { label: t('shop_admin.status_submitted'), value: 'submitted' },
  { label: t('shop_admin.status_costing_pending'), value: 'costing_pending' },
  { label: t('shop_admin.status_priced'), value: 'priced' },
  { label: t('shop_admin.status_countered'), value: 'countered' },
  { label: t('shop_admin.status_final_offered'), value: 'final_offered' },
  { label: t('shop_admin.status_confirmed'), value: 'confirmed' },
  { label: t('shop_admin.status_procuring'), value: 'procuring' },
  { label: t('shop_admin.status_packed'), value: 'packed' },
  { label: t('shop_admin.status_delivered'), value: 'delivered' },
  { label: t('shop_admin.status_processing'), value: 'processing' },
  { label: t('shop_admin.status_shipped'), value: 'shipped' },
  { label: t('shop_admin.status_payment_received'), value: 'payment_received' },
  { label: t('shop_admin.status_negotiating'), value: 'negotiating' },
  { label: t('shop_admin.status_placed'), value: 'placed' },
  { label: t('shop_admin.status_fulfilled'), value: 'fulfilled' },
  { label: t('shop_admin.status_cancelled'), value: 'cancelled' },
]);

const allShopsOption = computed(() => ({
  label: t('shop_admin.all_shops'),
  value: null as number | null,
}));

const shopOptions = computed(() => [
  allShopsOption.value,
  ...props.shops.map((shop) => ({
    label: shop.tenant_name ? `${shop.name} (${shop.tenant_name})` : shop.name,
    value: shop.id,
  })),
]);

const filteredShopOptions = computed(() => {
  const needle = shopSearch.value.trim().toLowerCase();
  if (!needle) {
    return shopOptions.value;
  }
  const matchesAll =
    allShopsOption.value.label.toLowerCase().includes(needle);
  const shopMatches = shopOptions.value
    .slice(1)
    .filter((opt) => opt.label.toLowerCase().includes(needle));
  return matchesAll ? [allShopsOption.value, ...shopMatches] : shopMatches;
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
