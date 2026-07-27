<template>
  <div class="q-pa-md">
    <q-select
      v-model="brandModel"
      filled
      use-input
      dense
      hide-selected
      fill-input
      input-debounce="300"
      emit-value
      map-options
      :options="brandOptions"
      class="soft-input q-mb-sm"
      :label="$t('shop.brand')"
      @filter="(val, update) => $emit('filter-brands', val, update)"
    />

    <q-select
      v-model="categoryModel"
      filled
      use-input
      dense
      hide-selected
      fill-input
      input-debounce="300"
      emit-value
      map-options
      :options="categoryOptions"
      class="soft-input q-mb-md"
      :label="$t('shop.category')"
      @filter="(val, update) => $emit('filter-categories', val, update)"
    />

    <div class="row q-gutter-sm justify-end q-mt-md">
      <q-btn
        flat
        no-caps
        :label="$t('shop_admin.reset')"
        color="grey-7"
        @click="$emit('reset-filters')"
      />
      <q-btn
        unelevated
        no-caps
        :label="$t('shop.apply')"
        color="primary"
        class="pill-btn"
        @click="$emit('apply')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  brand: string | null;
  category: string | null;
  brandOptions: Array<{ label: string; value: string | null }>;
  categoryOptions: Array<{ label: string; value: string | null }>;
}>();

const emit = defineEmits<{
  (e: 'update:brand', val: string | null): void;
  (e: 'update:category', val: string | null): void;
  (e: 'filter-brands', val: string, update: (fn: () => void) => void): void;
  (e: 'filter-categories', val: string, update: (fn: () => void) => void): void;
  (e: 'reset-filters'): void;
  (e: 'apply'): void;
}>();

const brandModel = computed({
  get: () => props.brand,
  set: (val: string | null) => emit('update:brand', val),
});

const categoryModel = computed({
  get: () => props.category,
  set: (val: string | null) => emit('update:category', val),
});
</script>

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 82%, transparent);
}
</style>
