<template>
  <AppReferenceReadOnlyPage
    title="Currencies"
    caption="Global currency catalog (read-only)"
    :columns="columns"
    :rows="currencyStore.currencies"
    :loading="currencyStore.loading"
  />
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import type { QTableColumn } from 'quasar'
import { useThriftCurrencyStore } from 'src/modules/thrift/currency/stores/thriftCurrencyStore'
import AppReferenceReadOnlyPage from '../components/AppReferenceReadOnlyPage.vue'

const currencyStore = useThriftCurrencyStore()

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'symbol', label: 'Symbol', field: 'symbol', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'country', label: 'Country', field: 'country', align: 'left', sortable: true },
]

onMounted(async () => {
  await currencyStore.loadCurrencies()
})
</script>
