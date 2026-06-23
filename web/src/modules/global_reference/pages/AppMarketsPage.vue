<template>
  <AppReferenceReadOnlyPage
    title="Markets"
    caption="Active market catalog (read-only)"
    :columns="columns"
    :rows="activeRows"
    :loading="loading"
  />
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { QTableColumn } from 'quasar'
import { supabase } from 'src/boot/supabase'
import AppReferenceReadOnlyPage from '../components/AppReferenceReadOnlyPage.vue'

type MarketRow = { code: string; name: string; region: string }

const rows = ref<MarketRow[]>([])
const loading = ref(false)
const activeRows = computed(() => rows.value)

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'region', label: 'Region', field: 'region', align: 'left', sortable: true },
]

onMounted(async () => {
  loading.value = true
  try {
    const { data, error } = await supabase.rpc('list_vendor_markets')
    if (error) throw error
    rows.value = (data as MarketRow[] | null) ?? []
  } finally {
    loading.value = false
  }
})
</script>
