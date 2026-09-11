<template>
  <div class="q-gutter-y-sm">
    <q-card flat bordered class="storefront-toolbar q-pa-sm">
      <div class="row items-center q-col-gutter-sm no-wrap">
        <div class="col-auto">
          <q-btn
            flat
            :round="$q.screen.xs"
            dense
            no-caps
            color="primary"
            icon="ph ph-funnel-simple"
            :label="$q.screen.xs ? undefined : $t('shop.filters')"
            data-test="catalog-filter-btn"
            @click="$emit('open-filter')"
          >
            <q-badge v-if="activeFilterCount > 0" color="primary" floating rounded>
              {{ activeFilterCount }}
            </q-badge>
            <q-tooltip v-if="$q.screen.xs">{{ $t('shop.filters') }}</q-tooltip>
          </q-btn>
        </div>

        <div class="col">
          <q-input
            v-model="searchModel"
            filled
            dense
            type="text"
            class="soft-input"
            :placeholder="$t('shop.search_this_shop')"
            clearable
            data-test="catalog-shop-search"
            @keydown.enter="$emit('search')"
            @clear="$emit('search')"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </div>

        <div v-if="showFixedPriceChip" class="col-auto">
          <q-chip
            dense
            square
            size="sm"
            class="fixed-price-chip text-weight-medium"
            data-test="catalog-fixed-price-chip"
          >
            {{ $t('shop.fixed_price_catalog') }}
          </q-chip>
        </div>
      </div>
    </q-card>

    <div v-if="hasActiveFilters" class="row items-center q-gutter-xs active-filters-section">
      <span class="text-caption text-weight-medium text-grey-7 q-mr-xs">
        {{ $t('shop.active_filters') }}
      </span>
      <q-chip
        v-if="searchModel"
        removable
        outline
        color="primary"
        text-color="primary"
        size="sm"
        class="q-ma-xs"
        @remove="searchModel = ''"
      >
        Search: "{{ searchModel }}"
      </q-chip>
      <q-chip
        v-if="brand"
        removable
        outline
        color="primary"
        text-color="primary"
        size="sm"
        class="q-ma-xs"
        @remove="$emit('update:brand', null)"
      >
        {{ $t('shop.brand_filter', { name: brand }) }}
      </q-chip>
      <q-chip
        v-if="category"
        removable
        outline
        color="primary"
        text-color="primary"
        size="sm"
        class="q-ma-xs"
        @remove="$emit('update:category', null)"
      >
        {{ $t('shop.category_filter', { name: category }) }}
      </q-chip>
      <q-btn
        flat
        dense
        no-caps
        color="primary"
        :label="$t('shop.clear_all')"
        size="sm"
        class="q-px-sm q-ml-xs text-weight-bold"
        @click="$emit('reset-filters')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  search: string;
  brand: string | null;
  category: string | null;
  activeFilterCount: number;
  hasActiveFilters: boolean;
  showFixedPriceChip?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:search', val: string): void;
  (e: 'update:brand', val: string | null): void;
  (e: 'update:category', val: string | null): void;
  (e: 'search'): void;
  (e: 'open-filter'): void;
  (e: 'reset-filters'): void;
}>();

const searchModel = computed({
  get: () => props.search,
  set: (val: string) => emit('update:search', val || ''),
});
</script>

<style scoped>
.storefront-toolbar {
  border-radius: 12px;
}

@media (max-width: 599px) {
  .storefront-toolbar {
    padding: 4px 6px !important;
  }
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 82%, transparent);
}

.fixed-price-chip {
  border-radius: 8px;
  background: color-mix(in srgb, var(--bw-theme-primary, #2a2b2a) 12%, #fff);
  color: var(--bw-theme-ink, #2a2b2a);
}
</style>
