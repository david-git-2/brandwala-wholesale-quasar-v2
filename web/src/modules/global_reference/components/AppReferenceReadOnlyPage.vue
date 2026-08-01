<template>
  <q-page class="q-pa-md">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="text-h6 text-weight-bold">{{ title }}</div>
        <div class="text-caption text-grey-8">{{ caption }}</div>
      </q-card-section>
    </q-card>
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="rows"
        :columns="columns"
        :row-key="rowKey"
        :loading="loading"
        :filter="filter"
        :pagination="pagination"
        hide-pagination
      >
        <template #top-right>
          <q-input
            v-model="filter"
            dense
            outlined
            placeholder="Search..."
            clearable
            class="bg-white"
            style="min-width: 250px"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { QTableColumn } from 'quasar';

withDefaults(
  defineProps<{
    title: string;
    caption: string;
    columns: QTableColumn[];
    rows: Record<string, unknown>[];
    loading: boolean;
    rowKey?: string | ((row: Record<string, unknown>) => string | number);
  }>(),
  {
    rowKey: (row: Record<string, unknown>) => (row.id ?? row.code ?? JSON.stringify(row)) as string | number,
  }
);

const filter = ref('');
const pagination = ref({
  rowsPerPage: 0,
});
</script>

<style scoped>
.hero-surface {
  border-radius: 16px;
}
</style>

