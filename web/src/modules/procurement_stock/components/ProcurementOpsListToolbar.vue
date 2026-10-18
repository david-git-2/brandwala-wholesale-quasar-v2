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
        @update:model-value="emit('update:search', $event == null ? $event : String($event))"
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
  background: var(--tf-neutral-surface, #ffffff);
  border-radius: var(--tf-radius-sm, 8px);
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
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
  color: var(--tf-neutral-chrome, #64748b);
}

</style>
