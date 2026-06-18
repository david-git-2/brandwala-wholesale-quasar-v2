<template>
  <q-page class="q-pa-md invoice-accounting-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-subtitle1 text-weight-bold">Global Invoice Accounting</div>
            <div class="text-caption text-grey-8 q-mt-xs">
              {{ groupedRows.length }} invoice{{ groupedRows.length !== 1 ? 's' : '' }} with rollups
            </div>
          </div>
          <div class="col-12 col-sm-auto row items-center q-gutter-sm justify-start justify-sm-end">
            <q-btn
              color="primary"
              outline
              no-caps
              size="sm"
              icon="refresh"
              label="Refresh"
              :loading="globalAccountingStore.loading"
              class="pill-btn slim-btn"
              @click="load"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="globalAccountingStore.loading && !globalAccountingStore.invoiceAccountingRows.length" />

    <template v-else>
      <q-card flat class="q-mb-md floating-surface shadow-1">
        <q-card-section class="q-pb-xs">
          <div class="row q-col-gutter-sm">
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Invoices</div>
                <div class="stat-value">{{ groupedRows.length }}</div>
                <div class="stat-unit">total</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Subtotal</div>
                <div class="stat-value">{{ fmt(totals.subtotal) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Charges</div>
                <div class="stat-value">{{ fmt(totals.charges) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card stat-card--primary">
                <div class="stat-label">Total Amount</div>
                <div class="stat-value text-primary">{{ fmt(totals.total) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card" :class="totals.profit >= 0 ? 'stat-card--positive' : 'stat-card--negative'">
                <div class="stat-label">Gross Profit</div>
                <div class="stat-value" :class="totals.profit >= 0 ? 'text-positive' : 'text-negative'">
                  {{ fmt(totals.profit) }}
                </div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <q-card flat class="floating-surface shadow-1">
        <div class="row items-center justify-between q-px-md q-pt-sm q-pb-xs">
          <div class="text-caption text-grey-7">Click a row to expand details</div>
          <q-btn
            flat
            dense
            no-caps
            size="xs"
            :label="allExpanded ? 'Collapse All' : 'Expand All'"
            color="primary"
            @click="toggleAll"
          />
        </div>

        <div class="invoice-table-wrap">
          <q-markup-table flat wrap-cells class="invoice-table">
            <thead>
              <tr>
                <th style="width: 36px"></th>
                <th class="text-left">Invoice ID</th>
                <th class="text-right">Subtotal</th>
                <th class="text-right">Charges</th>
                <th class="text-right">Total</th>
                <th class="text-right">Profit</th>
                <th class="text-left">Refreshed</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="group in groupedRows" :key="group.invoiceId">
                <tr class="invoice-group-row" :class="{ 'invoice-group-row--expanded': expanded.has(group.invoiceId) }" @click="toggle(group.invoiceId)">
                  <td>
                    <q-icon :name="expanded.has(group.invoiceId) ? 'expand_more' : 'chevron_right'" size="18px" color="grey-7" />
                  </td>
                  <td class="text-weight-medium">#{{ group.invoiceId }}</td>
                  <td class="text-right">{{ fmt(group.subtotal) }}</td>
                  <td class="text-right">{{ fmt(group.charges) }}</td>
                  <td class="text-right text-weight-medium">{{ fmt(group.total) }}</td>
                  <td class="text-right" :class="group.profit >= 0 ? 'text-positive' : 'text-negative'">{{ fmt(group.profit) }}</td>
                  <td class="text-grey-7 text-caption">{{ formatDate(group.refreshedAt) }}</td>
                </tr>
                <tr v-if="expanded.has(group.invoiceId)">
                  <td colspan="7" class="q-pa-none">
                    <q-markup-table flat dense class="q-ma-sm">
                      <thead>
                        <tr>
                          <th class="text-left">Rollup ID</th>
                          <th class="text-right">Subtotal</th>
                          <th class="text-right">Charges</th>
                          <th class="text-right">Total</th>
                          <th class="text-right">Profit</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in group.rows" :key="row.id">
                          <td>#{{ row.id }}</td>
                          <td class="text-right">{{ fmt(row.subtotal_amount) }}</td>
                          <td class="text-right">{{ fmt(row.charge_total) }}</td>
                          <td class="text-right">{{ fmt(row.total_amount) }}</td>
                          <td class="text-right">{{ fmt(row.gross_profit_total) }}</td>
                        </tr>
                      </tbody>
                    </q-markup-table>
                  </td>
                </tr>
              </template>
              <tr v-if="!groupedRows.length">
                <td colspan="7" class="text-center text-grey-7 q-py-md">No invoice accounting rows.</td>
              </tr>
              <tr v-if="groupedRows.length" class="totals-row">
                <td colspan="2" class="text-right text-weight-bold text-primary">Grand Total</td>
                <td class="text-right text-weight-bold">{{ fmt(totals.subtotal) }}</td>
                <td class="text-right text-weight-bold">{{ fmt(totals.charges) }}</td>
                <td class="text-right text-weight-bold">{{ fmt(totals.total) }}</td>
                <td class="text-right text-weight-bold" :class="totals.profit >= 0 ? 'text-positive' : 'text-negative'">{{ fmt(totals.profit) }}</td>
                <td></td>
              </tr>
            </tbody>
          </q-markup-table>
        </div>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'

import { useGlobalAccountingStore } from '../stores/globalAccountingStore'

const authStore = useAuthStore()
const globalAccountingStore = useGlobalAccountingStore()

const expanded = ref<Set<number>>(new Set())
const fmt = (value: number | null | undefined) => formatAmountBdt(value)

const groupedRows = computed(() => {
  const map = new Map<number, typeof globalAccountingStore.invoiceAccountingRows>()
  for (const row of globalAccountingStore.invoiceAccountingRows) {
    const list = map.get(row.global_invoice_id) ?? []
    list.push(row)
    map.set(row.global_invoice_id, list)
  }

  return Array.from(map.entries()).map(([invoiceId, rows]) => ({
    invoiceId,
    rows,
    subtotal: rows.reduce((sum, row) => sum + Number(row.subtotal_amount ?? 0), 0),
    charges: rows.reduce((sum, row) => sum + Number(row.charge_total ?? 0), 0),
    total: rows.reduce((sum, row) => sum + Number(row.total_amount ?? 0), 0),
    profit: rows.reduce((sum, row) => sum + Number(row.gross_profit_total ?? 0), 0),
    refreshedAt: rows.map((row) => row.refreshed_at).sort().at(-1) ?? '',
  }))
})

const totals = computed(() => ({
  subtotal: groupedRows.value.reduce((sum, group) => sum + group.subtotal, 0),
  charges: groupedRows.value.reduce((sum, group) => sum + group.charges, 0),
  total: groupedRows.value.reduce((sum, group) => sum + group.total, 0),
  profit: groupedRows.value.reduce((sum, group) => sum + group.profit, 0),
}))

const allExpanded = computed(() => expanded.value.size === groupedRows.value.length && groupedRows.value.length > 0)

const toggle = (invoiceId: number) => {
  const next = new Set(expanded.value)
  if (next.has(invoiceId)) next.delete(invoiceId)
  else next.add(invoiceId)
  expanded.value = next
}

const toggleAll = () => {
  if (allExpanded.value) {
    expanded.value = new Set()
    return
  }
  expanded.value = new Set(groupedRows.value.map((group) => group.invoiceId))
}

const formatDate = (val: string) => {
  if (!val) return '—'
  try {
    return new Date(val).toLocaleString()
  } catch {
    return val
  }
}

const load = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return
  await globalAccountingStore.fetchInvoiceAccounting(tenantId)
}

onMounted(() => {
  void load()
})
</script>

<style scoped>
.invoice-group-row--expanded td {
  background: rgba(34, 56, 101, 0.03);
}
</style>
