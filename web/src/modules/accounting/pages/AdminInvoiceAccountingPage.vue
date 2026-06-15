<template>
  <q-page class="q-pa-xs q-sm-pa-md invoice-accounting-page">
    <!-- ── Hero Header ──────────────────────────────────────── -->
    <q-card flat class="q-mb-sm q-sm-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-subtitle1 text-weight-bold">Invoice Accounting</div>
            <div class="text-caption text-grey-8 q-mt-xs">
              {{ groupedEntries.length }} invoice{{ groupedEntries.length !== 1 ? 's' : '' }}
              &bull; {{ accountingStore.accountingEntries.length }} entries
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
              :loading="accountingStore.loading"
              class="pill-btn slim-btn"
              @click="load"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="accountingStore.loading && !accountingStore.accountingEntries.length" />

    <template v-else>
      <!-- ── Summary Stats ─────────────────────────────────── -->
      <q-card flat class="q-mb-sm q-sm-mb-md floating-surface shadow-1">
        <q-card-section class="q-pb-xs">
          <div class="row q-col-gutter-sm">
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Invoices</div>
                <div class="stat-value">{{ groupedEntries.length }}</div>
                <div class="stat-unit">total</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Total Qty Sold</div>
                <div class="stat-value">{{ totals.qty }}</div>
                <div class="stat-unit">units</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Total COGS</div>
                <div class="stat-value">{{ fmt(totals.cogs) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card stat-card--primary">
                <div class="stat-label">Total Revenue</div>
                <div class="stat-value text-primary">{{ fmt(totals.revenue) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md" :class="totals.profit >= 0 ? 'stat-card--positive' : 'stat-card--negative'">
              <div class="stat-card" :class="totals.profit >= 0 ? 'stat-card--positive' : 'stat-card--negative'">
                <div class="stat-label">Gross Profit</div>
                <div class="stat-value" :class="totals.profit >= 0 ? 'text-positive' : 'text-negative'">{{ fmt(totals.profit) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card" :class="totals.due > 0 ? 'stat-card--negative' : 'stat-card--positive'">
                <div class="stat-label">Due Entries</div>
                <div class="stat-value" :class="totals.due > 0 ? 'text-negative' : 'text-positive'">{{ totals.due }}</div>
                <div class="stat-unit">entries</div>
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <!-- ── Grouped Expandable Table ──────────────────────── -->
      <q-card flat class="floating-surface shadow-1">
        <div class="row items-center justify-between q-px-md q-pt-sm q-pb-xs">
          <div class="text-caption text-grey-7">
            Click a row to expand its line items
          </div>
          <q-btn
            flat dense no-caps size="xs"
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
                <th class="text-left">Type</th>
                <th class="text-left">Latest Date</th>
                <th class="text-right">Entries</th>
                <th class="text-right">Total Qty</th>
                <th class="text-right">COGS (BDT)</th>
                <th class="text-right">Revenue (BDT)</th>
                <th class="text-right">Gross Profit (BDT)</th>
                <th class="text-left">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!groupedEntries.length">
                <td colspan="10" class="text-center text-grey-7 q-pa-lg">
                  No accounting entries found.
                </td>
              </tr>

              <template v-for="group in groupedEntries" :key="group.invoiceKey">
                <!-- ── Parent (invoice summary) row ── -->
                <tr
                  class="invoice-group-row"
                  :class="{ 'invoice-group-row--expanded': expandedKeys.has(group.invoiceKey) }"
                  @click="toggle(group.invoiceKey)"
                >
                  <td class="expand-toggle-cell text-center">
                    <q-icon
                      :name="expandedKeys.has(group.invoiceKey) ? 'expand_more' : 'chevron_right'"
                      size="18px"
                      class="text-grey-6"
                    />
                  </td>
                  <td>
                    <span class="text-weight-bold">
                      {{ group.invoice_id ? `#${group.invoice_id}` : '—' }}
                    </span>
                  </td>
                  <td>
                    <q-badge
                      outline
                      :color="group.type === 'commerce' ? 'indigo' : 'primary'"
                      class="text-capitalize"
                      style="font-size: 10px"
                    >
                      {{ group.type ?? 'normal' }}
                    </q-badge>
                  </td>
                  <td class="text-grey-8">{{ group.latestDate }}</td>
                  <td class="text-right text-grey-7">{{ group.entries.length }}</td>
                  <td class="text-right text-weight-medium">{{ group.totalQty }}</td>
                  <td class="text-right">{{ fmt(group.totalCogs) }}</td>
                  <td class="text-right">{{ fmt(group.totalRevenue) }}</td>
                  <td
                    class="text-right text-weight-medium"
                    :class="group.totalProfit >= 0 ? 'text-positive' : 'text-negative'"
                  >
                    {{ fmt(group.totalProfit) }}
                  </td>
                  <td>
                    <span
                      class="entry-status-chip"
                      :class="`entry-status-chip--${group.dominantStatus}`"
                    >
                      <span class="status-dot" :style="{ backgroundColor: statusDotColor(group.dominantStatus) }" />
                      {{ group.dominantStatus }}
                    </span>
                  </td>
                </tr>

                <!-- ── Child (line item) rows ── -->
                <template v-if="expandedKeys.has(group.invoiceKey)">
                  <!-- child sub-header -->
                  <tr class="child-header-row">
                    <td></td>
                    <td class="text-caption text-grey-6">Entry ID</td>
                    <td class="text-caption text-grey-6">Shipment</td>
                    <td class="text-caption text-grey-6">Entry Date</td>
                    <td class="text-caption text-grey-6">Product</td>
                    <td class="text-right text-caption text-grey-6">Qty</td>
                    <td class="text-right text-caption text-grey-6">Cost/Unit</td>
                    <td class="text-right text-caption text-grey-6">Sell/Unit</td>
                    <td class="text-right text-caption text-grey-6">Gross Profit</td>
                    <td class="text-caption text-grey-6">Status</td>
                  </tr>
                  <tr
                    v-for="row in group.entries"
                    :key="row.id"
                    class="child-row"
                  >
                    <td></td>
                    <td class="text-grey-7" style="font-size: 11px">#{{ row.id }}</td>
                    <td class="text-grey-8" style="font-size: 11px">
                      {{ row.shipment_id ? `#${row.shipment_id}` : '—' }}
                    </td>
                    <td class="text-grey-8">{{ row.entry_date ?? '—' }}</td>
                    <td class="text-grey-7" style="font-size: 11px">
                      {{ row.product_id ? `#${row.product_id}` : '—' }}
                    </td>
                    <td class="text-right">{{ row.quantity }}</td>
                    <td class="text-right">{{ fmt(row.cost_amount) }}</td>
                    <td class="text-right">{{ fmt(row.sell_price_amount) }}</td>
                    <td
                      class="text-right"
                      :class="Number(row.gross_profit_amount ?? 0) >= 0 ? 'text-positive' : 'text-negative'"
                    >
                      {{ fmt(row.gross_profit_amount) }}
                    </td>
                    <td>
                      <span
                        class="entry-status-chip entry-status-chip--sm"
                        :class="`entry-status-chip--${row.status ?? 'unknown'}`"
                      >
                        <span class="status-dot" :style="{ backgroundColor: statusDotColor(row.status) }" />
                        {{ row.status }}
                      </span>
                    </td>
                  </tr>
                </template>
              </template>

              <!-- Grand total row -->
              <tr v-if="groupedEntries.length" class="totals-row">
                <td colspan="5" class="text-right text-weight-bold">Grand Total</td>
                <td class="text-right text-weight-bold">{{ totals.qty }}</td>
                <td class="text-right text-weight-bold">{{ fmt(totals.cogs) }}</td>
                <td class="text-right text-weight-bold">{{ fmt(totals.revenue) }}</td>
                <td
                  class="text-right text-weight-bold"
                  :class="totals.profit >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ fmt(totals.profit) }}
                </td>
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
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useAccountingStore } from '../stores/accountingStore'
import { formatAmountBdt } from 'src/utils/currency'
import type { InventoryAccountingEntry } from '../types'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const authStore = useAuthStore()
const accountingStore = useAccountingStore()

const fmt = (v: number | null | undefined) => formatAmountBdt(v)

// ── Expand / collapse ────────────────────────────────────────
const expandedKeys = ref<Set<string>>(new Set())

const toggle = (key: string) => {
  const next = new Set(expandedKeys.value)
  if (next.has(key)) next.delete(key)
  else next.add(key)
  expandedKeys.value = next
}

const allExpanded = computed(() => expandedKeys.value.size === groupedEntries.value.length)

const toggleAll = () => {
  if (allExpanded.value) {
    expandedKeys.value = new Set()
  } else {
    expandedKeys.value = new Set(groupedEntries.value.map((g) => g.invoiceKey))
  }
}

// ── Group flat entries by invoice_id + type ──────────────────
const groupedEntries = computed(() => {
  const map = new Map<string, InventoryAccountingEntry[]>()
  for (const entry of accountingStore.accountingEntries) {
    const key = `${entry.invoice_id ?? 'none'}_${entry.type ?? 'normal'}`
    if (!map.has(key)) map.set(key, [])
    map.get(key)!.push(entry)
  }

  return Array.from(map.entries()).map(([invoiceKey, entries]) => {
    const first = entries[0]!
    const totalQty     = entries.reduce((s, e) => s + Number(e.quantity ?? 0), 0)
    const totalCogs    = entries.reduce((s, e) => s + Number(e.total_cost_amount ?? 0), 0)
    const totalRevenue = entries.reduce((s, e) => s + Number(e.total_sell_amount ?? 0), 0)
    const totalProfit  = entries.reduce((s, e) => s + Number(e.gross_profit_amount ?? 0), 0)
    const dominantStatus = entries.some((e) => e.status === 'due') ? 'due' : 'paid'
    const latestDate = entries.map((e) => e.entry_date ?? '').filter(Boolean).sort().at(-1) ?? '—'

    return { invoiceKey, invoice_id: first.invoice_id, type: first.type, entries, totalQty, totalCogs, totalRevenue, totalProfit, dominantStatus, latestDate }
  })
})

// ── Grand totals ─────────────────────────────────────────────
const totals = computed(() => ({
  qty:     groupedEntries.value.reduce((s, g) => s + g.totalQty, 0),
  cogs:    groupedEntries.value.reduce((s, g) => s + g.totalCogs, 0),
  revenue: groupedEntries.value.reduce((s, g) => s + g.totalRevenue, 0),
  profit:  groupedEntries.value.reduce((s, g) => s + g.totalProfit, 0),
  due:     accountingStore.accountingEntries.filter((e) => e.status === 'due').length,
}))

const statusDotColor = (status: string | null | undefined) => {
  const v = (status ?? '').toLowerCase()
  if (v === 'paid') return '#2f8b5d'
  if (v === 'due')  return '#a64c62'
  return '#66758c'
}

// ── Data load ────────────────────────────────────────────────
const load = async () => {
  if (!authStore.tenantId) return
  await accountingStore.fetchInventoryAccountingEntries({
    tenant_id: authStore.tenantId,
    page: 1,
    page_size: 1000,
    sortBy: 'entry_date',
    sortOrder: 'desc',
  })
}

onMounted(load)
</script>

<style scoped>
.invoice-accounting-page {
  background: transparent;
}

/* ── Floating surface ── */
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface { border-radius: 16px; }

/* ── Buttons ── */
.pill-btn { border-radius: 999px; }
.slim-btn  { min-height: 32px; padding-left: 10px; padding-right: 10px; }

/* ── Stat cards ── */
.stat-card {
  background: rgba(248, 250, 254, 0.9);
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 10px;
  padding: 12px 14px 10px;
  margin-bottom: 12px;
  transition: box-shadow 0.15s;
}
.stat-card:hover { box-shadow: 0 2px 12px rgba(34, 56, 101, 0.08); }
.stat-card--negative { border-left: 3px solid #e53935; background: rgba(253,245,245,.9); }
.stat-card--positive { border-left: 3px solid #2e7d32; background: rgba(244,251,246,.9); }
.stat-card--primary  { border-left: 3px solid var(--q-primary,#1976d2); background: rgba(245,249,255,.9); }

.stat-label {
  font-size: 11px; font-weight: 500; color: #555e72;
  letter-spacing: .01em; margin-bottom: 4px; line-height: 1.35;
}
.stat-value { font-size: 20px; font-weight: 700; color: #1a2642; line-height: 1.2; }
.stat-unit  { font-size: 10px; color: #8896aa; margin-top: 2px; }

/* ── Table wrap ── */
.invoice-table-wrap {
  overflow-x: auto;
  overflow-y: auto;
  max-height: calc(100vh - 380px);
}

/* ── Table header ── */
.invoice-table :deep(th) {
  background: color-mix(in srgb, #f7f9fc 96%, rgba(34,56,101,.04) 4%);
  font-size: 12px; font-weight: 600; color: #3b4b66;
  padding: 10px 12px; white-space: nowrap;
  position: sticky; top: 0; z-index: 2;
  border-bottom: 1px solid rgba(34,56,101,.10);
}

.invoice-table :deep(td) {
  padding: 9px 12px; font-size: 13px;
  border-bottom: 1px solid rgba(34,56,101,.05);
  vertical-align: middle;
}

/* ── Parent invoice row ── */
.invoice-group-row {
  cursor: pointer;
  transition: background 0.12s;
}
.invoice-group-row:hover td { background: rgba(34,56,101,.04); }
.invoice-group-row--expanded td { background: rgba(34,56,101,.03); }

.expand-toggle-cell { width: 36px; }

/* ── Child rows ── */
.child-header-row td {
  background: rgba(34,56,101,.03) !important;
  padding: 4px 12px;
  border-bottom: none;
}
.child-row td {
  background: rgba(248,250,254,.85);
  padding: 6px 12px;
  font-size: 12px;
}
.child-row:last-of-type td { border-bottom: 2px solid rgba(34,56,101,.08); }

/* ── Status chip ── */
.entry-status-chip {
  display: inline-flex; align-items: center;
  border-radius: 6px; font-size: 11px; font-weight: 600;
  padding: 2px 8px; text-transform: capitalize;
  background: rgba(34,56,101,.06); color: #3b4b66;
}
.entry-status-chip--sm { font-size: 10px; padding: 1px 6px; }
.entry-status-chip--paid { background: #e8f5e9; color: #2e7d32; }
.entry-status-chip--due  { background: #fdecea; color: #c62828; }

.status-dot {
  display: inline-block; width: 7px; height: 7px;
  border-radius: 999px; margin-right: 6px; flex-shrink: 0;
}

/* ── Totals row ── */
.totals-row td {
  background: rgba(248,250,254,.95) !important;
  border-top: 2px solid rgba(34,56,101,.12);
  font-size: 13px;
}

@media (max-width: 599px) {
  .invoice-table-wrap { max-height: calc(100vh - 280px); }
}
</style>
