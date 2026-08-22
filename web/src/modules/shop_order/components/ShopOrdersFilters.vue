<template>
  <div class="column q-gutter-y-md">
    <!-- Shops Filter Button Group -->
    <div class="row items-center q-mb-xs">
      <div class="col-12">
        <q-btn-toggle
          :model-value="selectedShopId"
          dense
          unelevated
          no-caps
          toggle-color="primary"
          color="white"
          text-color="primary"
          class="soft-btn-toggle border-all-1"
          :options="shopToggleOptions"
          @click="emit('shop-filter-open')"
          @update:model-value="(val) => emit('update:selectedShopId', val)"
        />
        <q-spinner v-if="shopsLoading" size="20px" color="primary" class="q-ml-sm" />
      </div>
    </div>

    <!-- Filters Toolbar -->
    <q-card flat bordered class="q-pa-sm">
      <section class="row items-center q-col-gutter-md">
        <div class="col-12 col-sm-4">
          <q-input
            :model-value="search"
            clearable
            debounce="350"
            dense
            outlined
            :placeholder="$t('shop_admin.search_orders_placeholder')"
            @update:model-value="(val) => emit('update:search', (val as string) || '')"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </div>
        <div class="col-auto">
          <q-select
            :model-value="shopTypeFilter"
            dense
            outlined
            emit-value
            map-options
            :label="$t('shop_admin.shop_type_filter')"
            :options="shopTypeOptions"
            style="min-width: 160px"
            @update:model-value="(val) => emit('update:shopTypeFilter', val)"
          />
        </div>
        <div class="col-auto">
          <q-select
            :model-value="statusFilter"
            dense
            outlined
            emit-value
            map-options
            :label="$t('shop_admin.filter_by_status')"
            :options="statusOptions"
            style="min-width: 160px"
            @update:model-value="(val) => emit('update:statusFilter', val)"
          />
        </div>
      </section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
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
  (e: 'shop-filter-open'): void;
}>();

const { t } = useI18n();

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

const shopToggleOptions = computed(() => {
  const options: Array<{ label: string; value: number | null }> = [{ label: t('shop_admin.all_shops'), value: null }];
  props.shops.forEach((shop) => {
    options.push({ label: shop.name, value: shop.id });
  });
  return options;
});
</script>

