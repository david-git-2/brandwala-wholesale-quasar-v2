<template>
  <q-dialog v-model="modalModel" position="top" transition-show="slide-down" transition-hide="slide-up">
    <q-card style="width: 700px; max-width: 95vw; margin-top: 20px;" class="q-pa-sm q-pa-sm-md shadow-10 rounded-lg">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div>
          <div class="text-h6 text-weight-bold text-grey-9">{{ $t('customer_dashboard.search_results_title') }}</div>
          <div class="text-caption text-grey-6">
            {{ $t('customer_dashboard.search_results_sub', { query: executedSearchQuery }) }}
          </div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-md">
        <!-- Search Loading State -->
        <div v-if="searching" class="column items-center justify-center q-pa-lg text-grey-7">
          <q-spinner color="primary" size="36px" />
          <div class="q-mt-sm text-subtitle2">{{ $t('customer_dashboard.searching_catalogs') }}</div>
        </div>

        <!-- Empty Search Results State -->
        <div v-else-if="searchResults.length === 0" class="column items-center justify-center q-pa-xl text-center text-grey-6">
          <q-icon name="ph ph-magnifying-glass-minus" size="56px" color="grey-4" class="q-mb-sm" />
          <div class="text-subtitle1 text-weight-bold">{{ $t('customer_dashboard.no_products_found') }}</div>
          <div class="text-caption text-grey-5 q-mt-xs">
            {{ $t('customer_dashboard.no_products_sub') }}
          </div>
        </div>

        <!-- Product Search Results List -->
        <div v-else class="q-gutter-y-sm" style="max-height: 60vh; overflow-y: auto;">
          <q-card
            v-for="item in searchResults"
            :key="item.product_id + '-' + (item.global_stock_allocation_id || '')"
            flat
            bordered
            class="q-pa-sm card-hover cursor-pointer"
            @click="$emit('select-product', item)"
          >
            <div class="row items-center no-wrap q-col-gutter-sm">
              <!-- Product Image -->
              <div class="col-auto">
                <q-img
                  :src="item.product_image_url || '/placeholder.png'"
                  spinner-color="primary"
                  style="height: 64px; width: 64px; border-radius: 8px;"
                  fit="cover"
                  class="bg-grey-2"
                />
              </div>

              <!-- Product & Shop Info -->
              <div class="col">
                <div class="row items-center gap-xs">
                  <q-badge color="blue-1" text-color="blue-8" class="text-weight-bold q-px-xs">
                    <q-icon name="ph ph-storefront" size="12px" class="q-mr-xs" />
                    {{ item.shop_name }}
                  </q-badge>
                  <q-badge v-if="item.product_brand" color="grey-2" text-color="grey-8" class="q-px-xs">
                    {{ item.product_brand }}
                  </q-badge>
                </div>
                <div class="text-subtitle2 text-weight-bold text-grey-9 line-clamp-1 q-mt-xs">
                  {{ item.product_name }}
                </div>
                <div class="row items-center q-gutter-x-sm text-caption text-grey-6 q-mt-xs">
                  <template v-if="item.see_price">
                    <span v-if="item.unit_price_amount != null" class="text-weight-bold text-primary">
                      <span v-if="item.shop_type === 'dropship'" class="text-caption text-grey-6 block text-weight-medium q-mb-xs" style="line-height: 1;">{{ $t('shop.wholesale_price') }}</span>
                      {{ item.unit_price_currency_symbol || '৳' }}{{ Number(item.unit_price_amount).toFixed(2) }}
                    </span>
                    <span v-if="item.shop_type === 'dropship' && item.minimum_sell_price_amount != null" class="text-caption text-secondary text-weight-bold q-ml-sm">
                      {{ $t('customer_dashboard.min_sell', { price: (item.minimum_sell_price_currency_symbol || '৳') + Number(item.minimum_sell_price_amount).toFixed(2) }) }}
                    </span>
                  </template>
                  <span v-if="item.available_units != null" class="q-ml-sm">
                    {{ $t('customer_dashboard.stock', { count: item.available_units }) }}
                  </span>
                </div>
              </div>

            </div>
          </q-card>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  modelValue: boolean;
  executedSearchQuery: string;
  searching: boolean;
  searchResults: any[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'select-product', item: any): void;
}>();

const modalModel = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});
</script>

<style scoped>
.card-hover {
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease, border-color 0.2s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: var(--bw-theme-shadow, 0 4px 12px rgba(0, 0, 0, 0.05));
  border-color: var(--q-primary);
}

.gap-xs {
  gap: 4px;
}
</style>
