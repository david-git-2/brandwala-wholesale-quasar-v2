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
          @click="$emit('select', category)"
          @keydown.enter.prevent="$emit('select', category)"
          @keydown.space.prevent="$emit('select', category)"
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

defineEmits<{
  (e: 'select', category: CustomerDashboardCategory): void;
}>();
</script>

<style scoped>
.category-card {
  border-radius: var(--tf-shop-radius-card, 20px);
  background: var(--tf-theme-surface);
  box-shadow: var(--tf-theme-shadow);
  transition:
    transform var(--tf-dur-fast, 120ms) var(--tf-ease, ease),
    box-shadow var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.category-card:hover,
.category-card:focus-visible {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgb(0 0 0 / 0.08);
}
</style>
