<template>
  <div>
    <div class="text-subtitle1 text-weight-bold q-mb-md">
      {{ $t('customer_dashboard.categories_title') }}
    </div>

    <div class="row q-col-gutter-md">
      <div v-for="category in categories" :key="category.id" class="col-6 col-sm-4 col-md-3">
        <q-card
          flat
          class="category-card q-pa-md cursor-pointer"
          role="button"
          tabindex="0"
          data-test="category-card"
        >
          <div class="row items-center no-wrap q-gutter-sm">
            <q-icon
              :name="category.icon || 'ph ph-squares-four'"
              size="22px"
              color="primary"
            />
            <div class="text-subtitle2 text-weight-bold ellipsis">{{ category.name }}</div>
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { CustomerDashboardCategory } from '../types/customerDashboard';

defineProps<{
  categories: CustomerDashboardCategory[];
}>();
</script>

<style scoped>
.category-card {
  border-radius: var(--bw-shop-radius-card, 20px);
  background: var(--bw-theme-surface);
  box-shadow: var(--bw-theme-shadow);
}
</style>
