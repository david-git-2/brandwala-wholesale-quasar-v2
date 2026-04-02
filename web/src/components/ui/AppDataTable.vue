<template>
  <AppSectionCard :title="title" :caption="caption">
    <template v-if="$slots.actions" #actions>
      <slot name="actions" />
    </template>

    <q-table
      flat
      class="bw-data-table"
      :rows="rows"
      :columns="columns"
      :row-key="rowKey"
      :loading="loading"
      hide-pagination
      :rows-per-page-options="[0]"
    >
      <template v-if="$slots['body-cell']" #body-cell="slotProps">
        <slot name="body-cell" v-bind="slotProps" />
      </template>

      <template #no-data>
        <AppEmptyState
          :icon="emptyIcon"
          :title="emptyTitle"
          :message="emptyMessage"
        />
      </template>
    </q-table>
  </AppSectionCard>
</template>

<script setup lang="ts">
import type { PropType } from 'vue'
import type { QTableProps } from 'quasar'

import AppEmptyState from './AppEmptyState.vue'
import AppSectionCard from './AppSectionCard.vue'

defineProps({
  title: {
    type: String,
    default: '',
  },
  caption: {
    type: String,
    default: '',
  },
  rows: {
    type: Array as PropType<QTableProps['rows']>,
    default: () => [],
  },
  columns: {
    type: Array as PropType<QTableProps['columns']>,
    default: () => [],
  },
  rowKey: {
    type: [String, Function] as PropType<QTableProps['rowKey']>,
    default: 'id',
  },
  loading: {
    type: Boolean,
    default: false,
  },
  emptyIcon: {
    type: String,
    default: 'table_rows',
  },
  emptyTitle: {
    type: String,
    default: 'No records yet',
  },
  emptyMessage: {
    type: String,
    default: 'When data becomes available, it will appear here.',
  },
})
</script>

<style scoped>
:deep(.bw-data-table .q-table__top),
:deep(.bw-data-table thead tr) {
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, white 12%);
}

:deep(.bw-data-table thead th) {
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.11em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

:deep(.bw-data-table tbody td) {
  color: var(--bw-theme-ink);
}

:deep(.bw-data-table .q-table tbody tr:hover) {
  background: rgb(var(--bw-theme-primary-rgb) / 0.05);
}
</style>
