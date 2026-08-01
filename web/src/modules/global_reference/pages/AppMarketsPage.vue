<template>
  <AppReferenceReadOnlyPage
    title="Markets"
    caption="Active market catalog (read-only)"
    :columns="columns"
    :rows="rows"
    :loading="isLoading"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { QTableColumn } from 'quasar';
import { useGlobalMarketsQuery } from '../composables/useGlobalReferenceQuery';
import AppReferenceReadOnlyPage from '../components/AppReferenceReadOnlyPage.vue';

const { data, isLoading } = useGlobalMarketsQuery();
const rows = computed(() => (data.value ?? []) as unknown as Array<Record<string, unknown>>);

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'region', label: 'Region', field: 'region', align: 'left', sortable: true },
];
</script>
