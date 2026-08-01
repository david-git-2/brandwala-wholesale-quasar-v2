<template>
  <AppReferenceReadOnlyPage
    title="Payment Methods"
    caption="Active payment methods (read-only)"
    :columns="columns"
    :rows="rows"
    :loading="isLoading"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { QTableColumn } from 'quasar';
import { useGlobalPaymentMethodsQuery } from '../composables/useGlobalReferenceQuery';
import AppReferenceReadOnlyPage from '../components/AppReferenceReadOnlyPage.vue';

const { data, isLoading } = useGlobalPaymentMethodsQuery();
const rows = computed(() => (data.value ?? []) as unknown as Array<Record<string, unknown>>);

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'category', label: 'Category', field: 'category', align: 'left', sortable: true },
  { name: 'scope', label: 'Scope', field: 'scope', align: 'left', sortable: true },
];
</script>
