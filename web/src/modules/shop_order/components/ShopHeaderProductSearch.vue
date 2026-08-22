<template>
  <q-input
    v-model="query"
    outlined
    dense
    rounded
    clearable
    class="shop-header-search soft-input"
    :placeholder="$t('customer_dashboard.search_placeholder')"
    data-test="shop-header-search"
    aria-label="Search products"
  >
    <template #prepend>
      <q-icon name="ph ph-magnifying-glass" size="16px" color="grey-6" />
    </template>
  </q-input>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const query = ref('');
</script>

<style scoped>
.shop-header-search {
  width: 100%;
  max-width: 320px;
}

.shop-header-search :deep(.q-field__control) {
  min-height: 32px;
  border-radius: 8px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 82%, transparent);
}

@media (max-width: 599px) {
  .shop-header-search {
    max-width: 140px;
  }
}
</style>
