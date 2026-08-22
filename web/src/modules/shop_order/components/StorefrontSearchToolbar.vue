<template>
  <div class="q-gutter-y-sm">
    <q-card flat bordered class="storefront-toolbar q-pa-sm">
      <div class="row items-center q-col-gutter-sm">
        <div class="col-12 col-sm-auto storefront-toolbar__shop">
          <q-btn-dropdown
            v-if="shops.length > 1"
            outline
            no-caps
            dense
            unelevated
            color="primary"
            icon="ph ph-storefront"
            dropdown-icon="ph ph-caret-down"
            :label="shopName"
            class="catalog-shop-switcher"
            content-class="catalog-shop-switcher__menu"
            data-test="catalog-shop-switcher"
            :aria-label="$t('shop.switch_shop')"
          >
            <q-tooltip>{{ $t('shop.switch_shop') }}</q-tooltip>
            <q-list>
              <q-item
                v-for="shop in shops"
                :key="shop.id"
                v-close-popup
                clickable
                :active="shop.slug === currentSlug"
                @click="$emit('switch-shop', shop)"
              >
                <q-item-section avatar>
                  <q-icon name="ph ph-storefront" size="18px" color="grey-7" />
                </q-item-section>
                <q-item-section>{{ shop.name }}</q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
          <div
            v-else
            class="catalog-shop-switcher catalog-shop-switcher--static row items-center no-wrap q-gutter-x-sm"
          >
            <q-icon name="ph ph-storefront" size="20px" color="primary" />
            <span class="text-subtitle2 text-weight-bold text-grey-9 ellipsis">{{ shopName }}</span>
          </div>
        </div>

        <div class="col row no-wrap q-gutter-x-sm items-center">
            <q-input
              v-model="searchModel"
              filled
              dense
              type="text"
              class="soft-input col"
              :placeholder="$t('shop.search_placeholder')"
              clearable
              @keydown.enter="$emit('search')"
              @clear="$emit('search')"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
            <q-btn
              v-if="!$q.screen.xs"
              unelevated
              no-caps
              color="primary"
              :label="$t('shop.search')"
              class="storefront-search-btn"
              @click="$emit('search')"
            />
            <q-btn
              v-else
              unelevated
              dense
              color="primary"
              icon="ph ph-magnifying-glass"
              class="storefront-search-btn"
              :aria-label="$t('shop.search')"
              @click="$emit('search')"
            />
          </div>

          <!-- Filter -->
          <div class="col-auto">
            <q-btn
              flat
              :round="$q.screen.xs"
              dense
              no-caps
              color="primary"
              icon="ph ph-funnel-simple"
              :label="$q.screen.xs ? undefined : $t('shop.filters')"
              @click="$emit('open-filter')"
            >
              <q-badge v-if="activeFilterCount > 0" color="primary" floating rounded>
                {{ activeFilterCount }}
              </q-badge>
              <q-tooltip v-if="$q.screen.xs">{{ $t('shop.filters') }}</q-tooltip>
            </q-btn>
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
  shopName: string;
  currentSlug: string;
  shops: Array<{ id: number; slug: string; name: string }>;
  search: string;
  brand: string | null;
  category: string | null;
  activeFilterCount: number;
  hasActiveFilters: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:search', val: string): void;
  (e: 'update:brand', val: string | null): void;
  (e: 'update:category', val: string | null): void;
  (e: 'search'): void;
  (e: 'open-filter'): void;
  (e: 'reset-filters'): void;
  (e: 'switch-shop', shop: { id: number; slug: string; name: string }): void;
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

.storefront-toolbar__shop {
  min-width: 0;
  max-width: 100%;
}

.catalog-shop-switcher {
  border-radius: 8px;
  max-width: 100%;
  min-height: 40px;
  padding: 4px 10px;
  font-weight: 600;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 92%, var(--q-primary) 8%);
}

.catalog-shop-switcher--static {
  min-height: 40px;
  padding: 8px 12px;
  border: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.18));
  border-radius: 8px;
  background: var(--bw-theme-surface, #fff);
}

@media (max-width: 599px) {
  .catalog-shop-switcher {
    width: 100%;
  }

  .catalog-shop-switcher :deep(.q-btn__content) {
    flex: 1;
    justify-content: space-between;
  }
}

.catalog-shop-switcher :deep(.q-btn__content) {
  gap: 6px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 82%, transparent);
}

.storefront-search-btn {
  border-radius: 8px;
}
</style>
