<template>
  <q-card flat bordered class="q-pa-sm">
    <div class="text-subtitle2 text-weight-bold q-mb-sm">
      {{ $t('shop_admin.manual_order_add_items', 'Add items') }}
    </div>
    <q-input
      :model-value="search"
      dense
      outlined
      hide-bottom-space
      :disable="disabled"
      :placeholder="$t('shop_admin.manual_order_search_placeholder', 'Search by name or barcode')"
      data-test="manual-dropship-item-search"
      @update:model-value="(v) => emit('update:search', String(v ?? ''))"
      @keyup.enter="onSubmit"
    >
      <template #prepend>
        <q-icon name="ph ph-magnifying-glass" size="16px" />
      </template>
      <template #append>
        <q-btn
          flat
          dense
          round
          icon="ph ph-magnifying-glass"
          :disable="disabled || search.trim().length < 2"
          @click="onSubmit"
        />
      </template>
    </q-input>

    <q-inner-loading :showing="loading" />

    <q-list v-if="activeQuery.trim().length >= 2" dense class="q-mt-sm">
      <q-item
        v-for="row in listings"
        :key="row.listing_id"
        clickable
        :disable="disabled || adding"
        @click="emit('add', row)"
      >
        <q-item-section avatar>
          <q-avatar square size="40px" class="shop-product-thumb">
            <q-img v-if="row.product_image_url" :src="row.product_image_url" fit="contain" />
            <q-icon v-else name="ph ph-image" color="grey-5" />
          </q-avatar>
        </q-item-section>
        <q-item-section>
          <q-item-label class="text-weight-medium">{{ row.product_name }}</q-item-label>
          <q-item-label caption>
            {{ $t('shop_admin.manual_order_stock_available', 'Available') }}: {{ row.available_to_sell }}
          </q-item-label>
        </q-item-section>
        <q-item-section side>
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-plus"
            :label="$t('common.add', 'Add')"
            :disable="disabled || adding || row.available_to_sell <= 0"
          />
        </q-item-section>
      </q-item>
      <q-item v-if="!loading && !listings.length">
        <q-item-section class="text-grey-6">
          {{ $t('shop_admin.manual_order_no_products', 'No products match your search') }}
        </q-item-section>
      </q-item>
    </q-list>
    <div v-else class="text-caption tf-text-muted q-mt-xs">
      {{
        $t(
          'shop_admin.manual_order_search_hint_enter',
          'Type at least 2 characters, then press Enter to search',
        )
      }}
    </div>
  </q-card>
</template>

<script setup lang="ts">
import type { StaffDropshipListingRow } from '../../repositories/staffManualDropshipOrderRepository';

const props = defineProps<{
  search: string;
  activeQuery: string;
  listings: StaffDropshipListingRow[];
  loading?: boolean;
  disabled?: boolean;
  adding?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:search', value: string): void;
  (e: 'submit'): void;
  (e: 'add', row: StaffDropshipListingRow): void;
}>();

const onSubmit = () => {
  if (props.disabled || props.search.trim().length < 2) return;
  emit('submit');
};
</script>
