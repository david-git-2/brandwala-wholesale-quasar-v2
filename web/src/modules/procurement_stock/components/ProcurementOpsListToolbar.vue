<template>
  <q-card flat bordered class="q-pa-xs flex-shrink-0 procurement-ops-toolbar">
    <div class="row items-center q-col-gutter-x-xs q-px-xs procurement-ops-toolbar__primary">
      <q-input
        :model-value="search"
        outlined
        dense
        debounce="300"
        clearable
        style="min-width: 220px"
        class="col-grow dense-search-input procurement-ops-toolbar__search"
        :placeholder="searchPlaceholder"
        @update:model-value="emit('update:search', $event)"
      >
        <template #prepend>
          <q-icon name="ph ph-magnifying-glass" size="16px" class="text-slate-400" />
        </template>
      </q-input>
      <slot name="toolbar-extra" />
      <q-btn
        flat
        round
        dense
        icon="ph ph-funnel"
        class="text-slate-500 flex-shrink-0"
        @click="emit('open-filters')"
      >
        <q-badge v-if="filterCount > 0" color="primary" rounded floating>
          {{ filterCount }}
        </q-badge>
        <q-tooltip>Filter options</q-tooltip>
      </q-btn>
      <slot name="trailing" />
    </div>

    <div v-if="$slots.pills" class="row items-center q-mt-xs q-px-xs procurement-ops-toolbar__pills">
      <slot name="pills" />
    </div>

    <div v-if="$slots.chips" class="row items-center q-mt-xs q-px-xs q-gutter-xs wrap procurement-ops-toolbar__chips">
      <slot name="chips" />
    </div>
  </q-card>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    search: string | null | undefined;
    searchPlaceholder?: string;
    filterCount?: number;
  }>(),
  {
    searchPlaceholder: 'Search…',
    filterCount: 0,
  },
);

const emit = defineEmits<{
  'update:search': [value: string | null | undefined];
  'open-filters': [];
}>();
</script>

<style scoped>
.procurement-ops-toolbar {
  background: var(--bw-neutral-surface, #ffffff);
  border-radius: var(--bw-radius-sm, 8px);
  border: 1px solid var(--bw-neutral-border, #e2e8f0);
}

.procurement-ops-toolbar__primary {
  flex-wrap: nowrap;
  min-width: 0;
}

.procurement-ops-toolbar__search {
  min-width: 0;
  max-width: 100%;
}

.procurement-ops-toolbar__pills {
  min-width: 0;
  overflow-x: auto;
  overflow-y: hidden;
  flex-wrap: nowrap;
  scrollbar-width: thin;
}

.text-slate-400 {
  color: var(--bw-neutral-chrome, #64748b);
}

:deep(.quick-filter-toggle) {
  display: flex;
  align-items: center;
  background: #f1f5f9;
  border-radius: var(--bw-radius-sm, 8px);
  padding: 2px;
  gap: 2px;
  flex-shrink: 0;
}

:deep(.quick-filter-pill) {
  border: none;
  background: transparent;
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 500;
  color: #64748b;
  border-radius: 6px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  transition: all 0.15s ease;
  white-space: nowrap;
}

:deep(.quick-filter-pill:hover) {
  color: #0f172a;
}

:deep(.quick-filter-pill--active) {
  background: var(--bw-neutral-surface, #ffffff);
  color: #0f172a;
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}

:deep(.pill-badge) {
  font-size: 10.5px;
  font-weight: 700;
  padding: 0 5px;
  border-radius: 4px;
  background: #e2e8f0;
  color: #475569;
}

:deep(.pill-badge--active) {
  background: rgba(37, 99, 235, 0.12);
  color: #2563eb;
}
</style>
