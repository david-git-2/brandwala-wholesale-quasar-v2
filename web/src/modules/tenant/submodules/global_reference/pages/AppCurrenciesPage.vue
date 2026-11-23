<template>
  <AppReferenceReadOnlyPage
    title="Currencies"
    caption="Global currency catalog (read-only)"
    :columns="columns"
    :rows="currencies"
    :loading="isLoading"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { QTableColumn } from 'quasar';
import { useGlobalCurrenciesQuery } from '../composables/useGlobalReferenceQuery';
import AppReferenceReadOnlyPage from '../components/AppReferenceReadOnlyPage.vue';

const { data, isLoading } = useGlobalCurrenciesQuery();
const currencies = computed(() => (data.value ?? []) as unknown as Array<Record<string, unknown>>);

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'symbol', label: 'Symbol', field: 'symbol', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'country', label: 'Country', field: 'country', align: 'left', sortable: true },
];
</script>
