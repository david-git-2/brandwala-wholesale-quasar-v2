<template>
  <q-page class="q-pa-md invoice-accounting-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-subtitle1 text-weight-bold">Global Ledger</div>
            <div class="text-caption text-grey-8 q-mt-xs">Consolidated accounting across sister concerns</div>
          </div>
          <div class="col-12 col-sm-auto row items-center q-gutter-sm justify-start justify-sm-end">
            <q-btn
              color="primary"
              outline
              no-caps
              size="sm"
              icon="refresh"
              label="Refresh"
              :loading="loading"
              class="pill-btn slim-btn"
              @click="load"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card v-if="cashCards.length" flat class="q-mb-md floating-surface shadow-1">
      <q-card-section class="q-pb-xs">
        <div class="row q-col-gutter-sm">
          <div v-for="card in cashCards" :key="card.label" class="col-6 col-sm-4 col-md-3">
            <div class="stat-card" :class="card.tone">
              <div class="stat-label">{{ card.label }}</div>
              <div class="stat-value" :class="card.valueClass">{{ formatAmount(card.value) }}</div>
              <div class="stat-unit">BDT</div>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="loading && !globalAccountingStore.ledgerRows.length" />

    <q-banner v-else-if="globalAccountingStore.error" class="bg-negative text-white q-mb-md" rounded>
      {{ globalAccountingStore.error }}
    </q-banner>

    <q-card v-else flat class="floating-surface shadow-1">
      <q-table
        flat
        bordered
        row-key="id"
        :rows="globalAccountingStore.ledgerRows"
        :columns="columns"
        :pagination="{ rowsPerPage: 0 }"
        hide-bottom
        class="inventory-page__table"
      >
        <template #body-cell-sell_price_amount="props">
          <q-td :props="props" class="text-right">{{ formatAmount(props.row.sell_price_amount) }}</q-td>
        </template>
        <template #body-cell-gross_profit_amount="props">
          <q-td
            :props="props"
            class="text-right text-weight-medium"
            :class="Number(props.row.gross_profit_amount) >= 0 ? 'text-positive' : 'text-negative'"
          >
            {{ formatAmount(props.row.gross_profit_amount) }}
          </q-td>
        </template>
        <template #body-cell-status="props">
          <q-td :props="props">
            <span class="entry-status-chip" :class="`entry-status-chip--${props.row.status}`">
              <span class="status-dot" :style="{ backgroundColor: statusDotColor(props.row.status) }" />
              {{ props.row.status }}
            </span>
          </q-td>
        </template>
        <template #no-data>
          <div class="full-width text-center text-grey-7 q-py-md">No ledger entries.</div>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { QTableColumn } from 'quasar'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'

import { useGlobalAccountingStore } from '../stores/globalAccountingStore'

const authStore = useAuthStore()
const globalAccountingStore = useGlobalAccountingStore()
const loading = ref(false)

const columns: QTableColumn[] = [
  { name: 'entry_date', label: 'Date', field: 'entry_date', align: 'left', sortable: true },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right' },
  { name: 'sell_price_amount', label: 'Sell', field: 'sell_price_amount', align: 'right' },
  { name: 'gross_profit_amount', label: 'Profit', field: 'gross_profit_amount', align: 'right' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'note', label: 'Note', field: 'note', align: 'left', style: 'white-space: normal; min-width: 180px;' },
]

const formatAmount = (value: number) => formatAmountBdt(value)

const cashCards = computed(() => {
  const cash = globalAccountingStore.cashCirculation
  if (!cash) return []

  return [
    { label: 'Investor capital available', value: cash.investor_capital_available, tone: 'stat-card--primary' },
    { label: 'Customer AR due', value: cash.customer_ar_due, tone: cash.customer_ar_due > 0 ? 'stat-card--negative' : '' },
    { label: 'Stock cost in circulation', value: cash.stock_cost_in_circulation, tone: '' },
    { label: 'Profit MTD', value: cash.realized_profit_mtd, tone: 'stat-card--positive', valueClass: 'text-positive' },
  ]
})

const statusDotColor = (status: string | null | undefined) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'paid') return '#2f8b5d'
  if (value === 'due') return '#a64c62'
  return '#66758c'
}

const load = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  await Promise.all([
    globalAccountingStore.fetchLedger(tenantId),
    globalAccountingStore.fetchCashCirculation(tenantId),
  ])
  loading.value = false
}

onMounted(() => {
  void load()
})
</script>
