<template>
  <q-page class="q-pa-xs q-sm-pa-md invoice-accounting-page">
    <!-- ── Hero Header ──────────────────────────────────────── -->
    <q-card flat class="q-mb-sm q-sm-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-subtitle1 text-weight-bold">Commerce Invoice Accounting</div>
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
              <!-- Top Header Grouping -->
              <tr class="header-group-row">
                <th colspan="5" class="text-left bg-light-blue-1 text-primary text-weight-bold" style="border-right: 1px solid rgba(34,56,101,.08)">General Details</th>
                <th colspan="3" class="text-right bg-blue-1 text-indigo-9 text-weight-bold" style="border-right: 1px solid rgba(34,56,101,.08)">Product Stock Totals</th>
                <th colspan="5" class="text-right bg-orange-1 text-orange-9 text-weight-bold" style="border-right: 1px solid rgba(34,56,101,.08)">Charges & Adjustments</th>
                <th colspan="3" class="text-right bg-green-1 text-green-9 text-weight-bold">Outcomes & Actions</th>
              </tr>
              <!-- Column Headers -->
              <tr class="column-header-row">
                <th style="width: 36px"></th>
                <th class="text-left">Invoice ID</th>
                <th class="text-left">Type</th>
                <th class="text-left">Latest Date</th>
                <th class="text-right" style="border-right: 1px solid rgba(34,56,101,.08)">Entries</th>
                <th class="text-right">Total Qty</th>
                <th class="text-right">COGS (BDT)</th>
                <th class="text-right" style="border-right: 1px solid rgba(34,56,101,.08)">Revenue (BDT)</th>
                <th class="text-right">Delivery</th>
                <th class="text-right">Wrapping</th>
                <th class="text-right">COD</th>
                <th class="text-right">Print</th>
                <th class="text-right" style="border-right: 1px solid rgba(34,56,101,.08)">Discount</th>
                <th class="text-right">Gross Profit</th>
                <th class="text-left">Status</th>
                <th class="text-center" style="width: 60px">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!groupedEntries.length">
                <td colspan="16" class="text-center text-grey-7 q-pa-lg">
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
                    <span class="text-weight-bold text-primary">
                       {{ group.invoice_id ? `#${group.invoice_id}` : '—' }}
                    </span>
                  </td>
                  <td>
                    <q-badge
                      outline
                      :color="group.type === 'commerce' ? 'indigo' : 'primary'"
                      class="text-capitalize text-weight-bold"
                      style="font-size: 10px; padding: 2px 6px;"
                    >
                      {{ group.type ?? 'normal' }}
                    </q-badge>
                  </td>
                  <td class="text-grey-8">{{ group.latestDate }}</td>
                  <td class="text-right text-grey-7" style="border-right: 1px solid rgba(34,56,101,.05)">{{ group.entries.length }}</td>
                  <td class="text-right text-weight-bold text-grey-9">{{ group.totalQty }}</td>
                  <td class="text-right text-grey-8">{{ fmt(group.totalCogs) }}</td>
                  <td class="text-right text-weight-medium text-grey-9" style="border-right: 1px solid rgba(34,56,101,.05)">{{ fmt(group.totalRevenue) }}</td>
                  <td class="text-right" :class="group.totalDelivery ? 'text-weight-bold text-grey-9' : 'text-grey-4'">{{ group.totalDelivery ? fmt(group.totalDelivery) : '—' }}</td>
                  <td class="text-right" :class="group.totalWrapping ? 'text-weight-bold text-grey-9' : 'text-grey-4'">{{ group.totalWrapping ? fmt(group.totalWrapping) : '—' }}</td>
                  <td class="text-right" :class="group.totalCod ? 'text-weight-bold text-grey-9' : 'text-grey-4'">{{ group.totalCod ? fmt(group.totalCod) : '—' }}</td>
                  <td class="text-right" :class="group.totalPrint ? 'text-weight-bold text-grey-9' : 'text-grey-4'">{{ group.totalPrint ? fmt(group.totalPrint) : '—' }}</td>
                  <td class="text-right" :class="group.totalDiscount ? 'text-weight-bold text-red-8' : 'text-grey-4'">{{ group.totalDiscount ? `-${fmt(group.totalDiscount)}` : '—' }}</td>
                  <td
                    class="text-right text-weight-bold"
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
                  <td class="text-center" @click.stop>
                    <q-btn
                      v-if="group.invoice_id"
                      flat
                      round
                      dense
                      color="negative"
                      icon="o_delete"
                      size="sm"
                      @click="onDeleteInvoice(group.invoice_id)"
                    >
                      <q-tooltip>Delete Invoice & Accounting Entries</q-tooltip>
                    </q-btn>
                  </td>
                </tr>

                <!-- ── Child (nested line items) ── -->
                <template v-if="expandedKeys.has(group.invoiceKey)">
                  <tr class="expanded-detail-row">
                    <td></td>
                    <td colspan="15" class="q-pa-sm bg-grey-1">
                      <div class="nested-table-card shadow-1 q-pa-sm bg-white">
                        <div class="row items-center justify-between q-mb-sm q-px-xs">
                          <div class="text-caption text-weight-bold text-indigo-9">
                            Invoice Details & Charges Breakdown
                          </div>
                        </div>

                        <q-markup-table flat dense wrap-cells class="nested-detail-table">
                          <thead>
                            <tr class="nested-header-row bg-indigo-1">
                              <th class="text-left text-indigo-9 text-caption">Entry ID</th>
                              <th class="text-left text-indigo-9 text-caption">Shipment</th>
                              <th class="text-left text-indigo-9 text-caption">Entry Date</th>
                              <th class="text-left text-indigo-9 text-caption">Product / Item</th>
                              <th class="text-right text-indigo-9 text-caption">Qty</th>
                              <th class="text-right text-indigo-9 text-caption">Cost/Unit</th>
                              <th class="text-right text-indigo-9 text-caption">Sell/Unit</th>
                              <th class="text-right text-orange-9 text-caption">Delivery</th>
                              <th class="text-right text-orange-9 text-caption">Wrapping</th>
                              <th class="text-right text-orange-9 text-caption">COD</th>
                              <th class="text-right text-orange-9 text-caption">Print</th>
                              <th class="text-right text-red text-caption">Discount</th>
                              <th class="text-right text-indigo-9 text-caption">Gross Profit</th>
                              <th class="text-left text-indigo-9 text-caption">Status</th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr
                              v-for="row in group.entries"
                              :key="row.id"
                              class="nested-row"
                              :class="{ 'nested-row--charges': row.is_charges }"
                            >
                              <td class="text-grey-7" style="font-size: 11px">#{{ row.id }}</td>
                              <td class="text-grey-8" style="font-size: 11px">
                                <template v-if="row.shipment_id">
                                  <q-badge color="indigo-1" text-color="indigo-9" class="q-mr-xs" style="font-size: 10px">
                                    #{{ row.shipment_id }}
                                  </q-badge>
                                  <span>{{ row.shipment_name ?? '—' }}</span>
                                </template>
                                <template v-else>
                                  —
                                </template>
                              </td>
                              <td class="text-grey-8" style="font-size: 11px">{{ row.entry_date ?? '—' }}</td>
                              <td class="text-grey-7" style="font-size: 11px">
                                <template v-if="row.is_charges">
                                  <q-badge color="deep-purple-1" text-color="deep-purple-9" class="text-weight-bold" style="font-size: 9px; padding: 2px 6px;">
                                    Invoice Charges & Fees
                                  </q-badge>
                                </template>
                                <template v-else>
                                  {{ row.product_id ? `#${row.product_id}` : '—' }}
                                </template>
                              </td>
                              <td class="text-right">{{ row.is_charges ? '—' : row.quantity }}</td>
                              <td class="text-right">{{ row.is_charges ? '—' : fmt(row.cost_amount) }}</td>
                              <td class="text-right">{{ row.is_charges ? '—' : fmt(row.sell_price_amount) }}</td>
                              <td class="text-right" :class="row.delivery_charge ? 'text-weight-bold text-grey-9' : 'text-grey-4'">{{ row.delivery_charge ? fmt(row.delivery_charge) : '—' }}</td>
                              <td class="text-right" :class="row.wrapping_charge ? 'text-weight-bold text-grey-9' : 'text-grey-4'">{{ row.wrapping_charge ? fmt(row.wrapping_charge) : '—' }}</td>
                              <td class="text-right" :class="row.cod ? 'text-weight-bold text-grey-9' : 'text-grey-4'">{{ row.cod ? fmt(row.cod) : '—' }}</td>
                              <td class="text-right" :class="row.print_charge ? 'text-weight-bold text-grey-9' : 'text-grey-4'">{{ row.print_charge ? fmt(row.print_charge) : '—' }}</td>
                              <td class="text-right" :class="row.discount_amount ? 'text-weight-bold text-red-8' : 'text-grey-4'">{{ row.discount_amount ? `-${fmt(row.discount_amount)}` : '—' }}</td>
                              <td
                                class="text-right text-weight-medium"
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
                          </tbody>
                        </q-markup-table>
                      </div>
                    </td>
                  </tr>
                </template>
              </template>

              <!-- Grand total row -->
              <tr v-if="groupedEntries.length" class="totals-row">
                <td colspan="5" class="text-right text-weight-bold text-primary">Grand Total</td>
                <td class="text-right text-weight-bold text-grey-9">{{ totals.qty }}</td>
                <td class="text-right text-weight-bold text-grey-8">{{ fmt(totals.cogs) }}</td>
                <td class="text-right text-weight-bold text-grey-9" style="border-right: 1px solid rgba(34,56,101,.10)">{{ fmt(totals.revenue) }}</td>
                <td class="text-right text-weight-bold text-grey-8">{{ fmt(totals.delivery) }}</td>
                <td class="text-right text-weight-bold text-grey-8">{{ fmt(totals.wrapping) }}</td>
                <td class="text-right text-weight-bold text-grey-8">{{ fmt(totals.cod) }}</td>
                <td class="text-right text-weight-bold text-grey-8">{{ fmt(totals.print) }}</td>
                <td class="text-right text-weight-bold text-red-8" style="border-right: 1px solid rgba(34,56,101,.10)">{{ totals.discount ? `-${fmt(totals.discount)}` : '—' }}</td>
                <td
                  class="text-right text-weight-bold"
                  :class="totals.profit >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ fmt(totals.profit) }}
                </td>
                <td></td>
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
import { useQuasar } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useAccountingStore } from 'src/modules/accounting/stores/accountingStore'
import { formatAmountBdt } from 'src/utils/currency'
import type { InventoryAccountingEntry } from 'src/modules/accounting/types'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { commerceInvoiceService } from 'src/modules/commerce_invoice/services/commerceInvoiceService'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'

const $q = useQuasar()
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

  const res = Array.from(map.entries()).map(([invoiceKey, entries]) => {
    const first = entries[0]!
    const totalQty     = entries.reduce((s, e) => s + Number(e.quantity ?? 0), 0)
    const totalCogs    = entries.reduce((s, e) => s + Number(e.total_cost_amount ?? 0), 0)
    const totalRevenue = entries.reduce((s, e) => s + Number(e.total_sell_amount ?? 0), 0)
    const totalProfit  = entries.reduce((s, e) => s + Number(e.gross_profit_amount ?? 0), 0)
    const totalDelivery = entries.reduce((s, e) => s + Number(e.delivery_charge ?? 0), 0)
    const totalWrapping = entries.reduce((s, e) => s + Number(e.wrapping_charge ?? 0), 0)
    const totalCod      = entries.reduce((s, e) => s + Number(e.cod ?? 0), 0)
    const totalPrint    = entries.reduce((s, e) => s + Number(e.print_charge ?? 0), 0)
    const totalDiscount = entries.reduce((s, e) => s + Number(e.discount_amount ?? 0), 0)
    const dominantStatus = entries.some((e) => e.status === 'due') ? 'due' : 'paid'
    const latestDate = entries.map((e) => e.entry_date ?? '').filter(Boolean).sort().at(-1) ?? '—'

    const result = {
      invoiceKey,
      invoice_id: first.invoice_id,
      type: first.type,
      entries,
      totalQty,
      totalCogs,
      totalRevenue,
      totalDelivery,
      totalWrapping,
      totalCod,
      totalPrint,
      totalDiscount,
      totalProfit,
      dominantStatus,
      latestDate
    }
    return result
  })
  return res
})

// ── Grand totals ─────────────────────────────────────────────
const totals = computed(() => ({
  qty:      groupedEntries.value.reduce((s, g) => s + g.totalQty, 0),
  cogs:     groupedEntries.value.reduce((s, g) => s + g.totalCogs, 0),
  revenue:  groupedEntries.value.reduce((s, g) => s + g.totalRevenue, 0),
  delivery: groupedEntries.value.reduce((s, g) => s + g.totalDelivery, 0),
  wrapping: groupedEntries.value.reduce((s, g) => s + g.totalWrapping, 0),
  cod:      groupedEntries.value.reduce((s, g) => s + g.totalCod, 0),
  print:    groupedEntries.value.reduce((s, g) => s + g.totalPrint, 0),
  discount: groupedEntries.value.reduce((s, g) => s + g.totalDiscount, 0),
  profit:   groupedEntries.value.reduce((s, g) => s + g.totalProfit, 0),
  due:      accountingStore.accountingEntries.filter((e) => e.status === 'due').length,
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
    filters: { type: 'commerce' },
    operators: { type: 'eq' },
    sortBy: 'entry_date',
    sortOrder: 'desc',
  })
}

const onDeleteInvoice = (invoiceId: number) => {
  $q.dialog({
    title: 'Delete Invoice?',
    message: `This will permanently delete Invoice #${invoiceId}, remove its related accounting records, and unassign and restock any linked inventory items.`,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: true,
    },
    cancel: {
      label: 'Cancel',
      color: 'grey-7',
      flat: true,
    },
  }).onOk(() => {
    void (async () => {
      try {
        const res = await commerceInvoiceService.deleteCommerceInvoice(invoiceId)
        if (res.success) {
          showSuccessNotification(`Invoice #${invoiceId} deleted successfully.`)
          await load()
        } else {
          showWarningDialog(res.error || 'Failed to delete invoice.')
        }
      } catch (err) {
        showWarningDialog(err instanceof Error ? err.message : 'An error occurred while deleting invoice.')
      }
    })()
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

.invoice-table :deep(.header-group-row th) {
  font-size: 11px !important;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 6px 12px !important;
  border-bottom: 2px solid rgba(34,56,101,.12) !important;
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
.child-header-row.header-group-row td {
  font-size: 10px !important;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 6px 12px !important;
  border-bottom: 1px solid rgba(34,56,101,.10) !important;
}
.child-row td {
  background: rgba(248,250,254,.85);
  padding: 6px 12px;
  font-size: 12px;
}
.child-row--charges td {
  background: rgba(237, 231, 246, 0.20) !important; /* soft violet-indigo tint to highlight charges row */
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
