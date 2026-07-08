<template>
  <AppReferenceReadOnlyPage
    title="Units of Measure"
    caption="Active units (read-only)"
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

type Row = {
  code: string;
  name: string;
  unit_type: string;
  symbol: string | null;
  sort_order: number;
};

const rows = ref<Row[]>([]);
const loading = ref(false);

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'unit_type', label: 'Type', field: 'unit_type', align: 'left', sortable: true },
  { name: 'symbol', label: 'Symbol', field: 'symbol', align: 'left', sortable: true },
];

onMounted(async () => {
  loading.value = true;
  try {
    const { data, error } = await supabase.rpc('list_units_of_measure');
    if (error) throw error;
    rows.value = (data as Row[] | null) ?? [];
  } finally {
    loading.value = false;
  }
});
</script>
