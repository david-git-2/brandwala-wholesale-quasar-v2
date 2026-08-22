<template>
  <div ref="anchorRef" class="shop-header-search-wrap">
    <q-input
      v-model="query"
      filled
      dense
      rounded
      clearable
      class="shop-header-search"
      :placeholder="$t('customer_dashboard.search_placeholder')"
      data-test="shop-header-search"
      aria-label="Search products"
      @focus="menuOpen = true"
      @keydown.enter.prevent="onSearch"
    >
      <template #prepend>
        <q-icon name="ph ph-magnifying-glass" size="16px" color="grey-7" />
      </template>
    </q-input>

    <q-menu
      v-model="menuOpen"
      :target="anchorRef"
      no-focus
      no-parent-event
      fit
      anchor="bottom left"
      self="top left"
      class="shop-header-search-menu"
      :offset="[0, 6]"
    >
      <q-list dense separator class="shop-header-search-results">
        <q-item v-if="query.trim().length < minSearchLength" class="text-grey-7">
          <q-item-section>
            <q-item-label caption>
              {{ $t('shop.search_type_more', { count: minSearchLength }) }}
            </q-item-label>
          </q-item-section>
        </q-item>

        <q-item v-else-if="!hasSubmittedSearch" class="text-grey-7">
          <q-item-section>
            <q-item-label caption>{{ $t('shop.search_press_enter') }}</q-item-label>
          </q-item-section>
        </q-item>

        <q-item v-else-if="isLoading">
          <q-item-section avatar>
            <q-spinner size="20px" color="primary" />
          </q-item-section>
          <q-item-section>{{ $t('shop.searching') }}</q-item-section>
        </q-item>

        <q-item v-else-if="isError">
          <q-item-section class="text-negative">{{ $t('shop.search_failed') }}</q-item-section>
        </q-item>

        <q-item v-else-if="results.length === 0">
          <q-item-section class="text-grey-7">{{ $t('shop.no_products_found') }}</q-item-section>
        </q-item>

        <q-item
          v-for="item in results"
          :key="`${item.shop_id}-${item.product_id}`"
          v-close-popup
          clickable
          data-test="shop-header-search-result"
          @click="onSelect(item)"
        >
          <q-item-section avatar>
            <q-avatar rounded size="36px" color="grey-2" class="search-result-avatar">
              <img
                v-if="item.product_image_url"
                :src="item.product_image_url"
                :alt="item.product_name"
                class="search-result-img"
                loading="lazy"
                referrerpolicy="no-referrer"
              />
              <q-icon v-else name="ph ph-package" color="grey-6" size="18px" />
            </q-avatar>
          </q-item-section>
          <q-item-section>
            <q-item-label class="text-weight-medium">{{ item.product_name }}</q-item-label>
            <q-item-label caption lines="1">
              {{ item.shop_name }}
              <span v-if="item.product_code"> · {{ item.product_code }}</span>
            </q-item-label>
          </q-item-section>
          <q-item-section v-if="item.unit_price_amount != null" side>
            <q-item-label class="text-primary text-weight-medium">
              {{ formatPrice(item) }}
            </q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
    </q-menu>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopCatalogSearchQuery } from '../composables/useShopCatalogSearchQuery';
import { shopCatalogProductPath } from '../utils/catalogShop';
import type { ShopCatalogSearchItem } from '../types';

const router = useRouter();
const authStore = useAuthStore();
const anchorRef = ref<HTMLElement | null>(null);
const query = ref('');
const submittedSearch = ref('');
const menuOpen = ref(false);

const { results, isLoading, isError, minSearchLength } = useShopCatalogSearchQuery(submittedSearch);

const hasSubmittedSearch = computed(() => submittedSearch.value.trim().length >= minSearchLength);

const onSearch = () => {
  menuOpen.value = true;
  const term = query.value.trim();
  if (term.length < minSearchLength) {
    submittedSearch.value = '';
    return;
  }
  submittedSearch.value = term;
};

watch(query, (value) => {
  if (!value.trim()) {
    submittedSearch.value = '';
  }
});

const formatPrice = (item: ShopCatalogSearchItem) => {
  const amount = Number(item.unit_price_amount);
  if (!Number.isFinite(amount)) return '';
  const symbol = item.unit_price_currency_symbol?.trim() || '';
  return `${symbol} ${amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`.trim();
};

const onSelect = (item: ShopCatalogSearchItem) => {
  menuOpen.value = false;
  query.value = '';
  submittedSearch.value = '';
  void router.push(shopCatalogProductPath(authStore.tenantSlug, item.shop_slug, item.product_id));
};
</script>

<style scoped>
.shop-header-search-wrap {
  position: relative;
  width: 100%;
  max-width: 320px;
}

.shop-header-search {
  width: 100%;
}

.shop-header-search :deep(.q-field__control) {
  min-height: 34px;
  border-radius: 8px;
  background: #eceff1 !important;
}

.shop-header-search :deep(.q-field__control:before) {
  border: 1px solid #cfd4d8;
}

.shop-header-search :deep(.q-field__control:hover:before) {
  border-color: #b0b8bf;
}

.shop-header-search :deep(.q-field--focused .q-field__control:before) {
  border-color: var(--q-primary);
}

.shop-header-search :deep(.q-field__native) {
  color: #1f2937;
}

.shop-header-search :deep(.q-field__native::placeholder) {
  color: #6b7280;
}

.shop-header-search-results {
  min-width: 280px;
  max-width: 420px;
}

.search-result-avatar {
  overflow: hidden;
}

.search-result-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

@media (max-width: 599px) {
  .shop-header-search-wrap {
    max-width: 160px;
  }
}
</style>
