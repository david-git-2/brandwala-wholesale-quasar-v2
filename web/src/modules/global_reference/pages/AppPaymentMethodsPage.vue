<template>
  <AppReferenceReadOnlyPage
    title="Payment Methods"
    caption="Active payment methods (read-only)"
    :columns="columns"
    :rows="rows"
    :loading="loading"
  />
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import type { QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';
import AppReferenceReadOnlyPage from '../components/AppReferenceReadOnlyPage.vue';

type Row = { code: string; name: string; category: string; scope: string; sort_order: number };

const rows = ref<Row[]>([]);
const loading = ref(false);

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'category', label: 'Category', field: 'category', align: 'left', sortable: true },
  { name: 'scope', label: 'Scope', field: 'scope', align: 'left', sortable: true },
];

onMounted(async () => {
  loading.value = true;
  try {
    const { data, error } = await supabase.rpc('list_payment_methods');
    if (error) throw error;
    rows.value = (data as Row[] | null) ?? [];
  } finally {
    loading.value = false;
  }
});
</script>
