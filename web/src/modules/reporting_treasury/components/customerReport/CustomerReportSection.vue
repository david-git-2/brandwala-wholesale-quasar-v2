<template>
  <ShipmentReportSectionShell :title="title">
    <div class="row items-center justify-end q-mb-xs" v-if="hasMore">
      <TfBtn flat dense no-caps label="Load more" :loading="isLoadingMore" @click="fetchNextPage" />
    </div>
    <q-table
      flat
      bordered
      dense
      :rows="rows"
      :columns="columns"
      :row-key="rowKey"
      :loading="isLoading && !rows.length"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      class="compact-ops-table customer-report-table"
      no-data-label="No rows yet"
    >
      <template v-for="(_, name) in $slots" #[name]="slotData">
        <slot :name="name" v-bind="slotData ?? {}" />
      </template>
    </q-table>
  </ShipmentReportSectionShell>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar';
import TfBtn from 'src/components/ui/TfBtn.vue';
import ShipmentReportSectionShell from '../shipmentReport/ShipmentReportSectionShell.vue';

defineProps<{
  title: string;
  rows: Record<string, unknown>[];
  columns: QTableColumn[];
  rowKey: string;
  isLoading: boolean;
  hasMore: boolean;
  isLoadingMore: boolean;
  fetchNextPage: () => void;
}>();
</script>