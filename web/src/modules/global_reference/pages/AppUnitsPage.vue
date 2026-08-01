<template>
  <AppReferenceReadOnlyPage
    title="Units of Measure"
    caption="Active units (read-only)"
    :columns="columns"
    :rows="rows"
    :loading="isLoading"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { QTableColumn } from 'quasar';
import { useGlobalUnitsOfMeasureQuery } from '../composables/useGlobalReferenceQuery';
import AppReferenceReadOnlyPage from '../components/AppReferenceReadOnlyPage.vue';

const { data, isLoading } = useGlobalUnitsOfMeasureQuery();
const rows = computed(() => (data.value ?? []) as unknown as Array<Record<string, unknown>>);

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'unit_type', label: 'Type', field: 'unit_type', align: 'left', sortable: true },
  { name: 'symbol', label: 'Symbol', field: 'symbol', align: 'left', sortable: true },
];
</script>
