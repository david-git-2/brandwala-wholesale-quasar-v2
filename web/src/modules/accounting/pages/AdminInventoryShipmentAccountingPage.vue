<template>
  <q-page class="q-pa-xs q-sm-pa-md inventory-accounting-page">
    <!-- ── Hero Header ──────────────────────────────────────── -->
    <q-card flat class="q-mb-sm q-sm-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-subtitle1 text-weight-bold">Inventory Accounting Summary</div>
            <div class="text-caption text-grey-8 q-mt-xs">
              {{ allSummaries.length }} shipment{{ allSummaries.length !== 1 ? 's' : '' }} tracked
            </div>
          </div>
          <div class="col-12 col-sm-auto row items-center q-gutter-sm justify-start justify-sm-end">
            <!-- Show zeroes toggle -->
            <q-toggle
              v-model="showZeroRows"
              dense
              color="primary"
              label="Show zero rows"
              left-label
              class="text-caption text-grey-8"
            />
            <q-btn
              color="primary"
              outline
              no-caps
              size="sm"
              icon="refresh"
              label="Refresh"
              :loading="inventoryStore.saving"
              class="pill-btn slim-btn"
              @click="onRefreshSummary"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="inventoryStore.loading" />

    <template v-else>
      <!-- ── Summary Stat Cards ──────────────────────────────── -->
      <q-card flat class="q-mb-sm q-sm-mb-md floating-surface shadow-1">
        <q-card-section class="q-pb-xs">
          <!-- Row 1: Quantity metrics -->
          <div class="text-caption text-grey-7 text-weight-medium q-mb-xs" style="letter-spacing: 0.04em; font-size: 10px; text-transform: uppercase;">Quantity</div>
          <div class="row q-col-gutter-sm q-mb-sm">
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card stat-card--positive">
                <div class="stat-label">Usable Qty</div>
                <div class="stat-value text-positive">{{ totals.usableQty }}</div>
                <div class="stat-unit">units</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card stat-card--negative">
                <div class="stat-label">Damaged Qty</div>
                <div class="stat-value text-negative">{{ totals.damagedQty }}</div>
                <div class="stat-unit">units</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card stat-card--negative">
                <div class="stat-label">Stolen Qty</div>
                <div class="stat-value text-negative">{{ totals.stolenQty }}</div>
                <div class="stat-unit">units</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Expired Qty</div>
                <div class="stat-value">{{ totals.expiredQty }}</div>
                <div class="stat-unit">units</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Open Box Qty</div>
                <div class="stat-value">{{ totals.openBoxQty }}</div>
                <div class="stat-unit">units</div>
              </div>
            </div>
          </div>

          <!-- Row 2: Cost metrics -->
          <div class="text-caption text-grey-7 text-weight-medium q-mb-xs" style="letter-spacing: 0.04em; font-size: 10px; text-transform: uppercase;">Cost (BDT)</div>
          <div class="row q-col-gutter-sm">
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card stat-card--positive">
                <div class="stat-label">Usable Cost</div>
                <div class="stat-value text-positive">{{ formatFixed2(totals.usableCost) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card stat-card--negative">
                <div class="stat-label">Damaged Cost</div>
                <div class="stat-value text-negative">{{ formatFixed2(totals.damagedCost) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card stat-card--negative">
                <div class="stat-label">Stolen Cost</div>
                <div class="stat-value text-negative">{{ formatFixed2(totals.stolenCost) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md">
              <div class="stat-card">
                <div class="stat-label">Expired Cost</div>
                <div class="stat-value">{{ formatFixed2(totals.expiredCost) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
            <div class="col-6 col-sm-4 col-md stat-card--primary">
              <div class="stat-card stat-card--primary">
                <div class="stat-label">Total Inventory Cost</div>
                <div class="stat-value text-primary">{{ formatFixed2(totals.totalCost) }}</div>
                <div class="stat-unit">BDT</div>
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <!-- ── Table ───────────────────────────────────────────── -->
      <q-card flat class="floating-surface shadow-1">
        <div class="row items-center justify-between q-px-md q-pt-sm q-pb-xs">
          <div class="text-caption text-grey-7">
            Showing {{ visibleSummaries.length }} of {{ allSummaries.length }} shipments
          </div>
        </div>
        <div class="inventory-table-wrap">
          <q-markup-table flat wrap-cells class="inventory-table">
            <thead>
              <tr>
                <th class="text-left sticky-col sticky-col-sl">SL</th>
                <th class="text-left sticky-col sticky-col-shipment">Shipment</th>
                <th class="text-left">Status</th>
                <th class="text-right">Usable Qty</th>
                <th class="text-right">Damaged Qty</th>
                <th class="text-right">Stolen Qty</th>
                <th class="text-right">Expired Qty</th>
                <th class="text-right">Open Box Qty</th>
                <th class="text-right">Usable Cost (BDT)</th>
                <th class="text-right">Damaged Cost (BDT)</th>
                <th class="text-right">Stolen Cost (BDT)</th>
                <th class="text-right">Expired Cost (BDT)</th>
                <th class="text-right">Open Box Cost (BDT)</th>
                <th class="text-right">Total Inv. Cost (BDT)</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!visibleSummaries.length">
                <td colspan="14" class="text-center text-grey-7 q-pa-lg">
                  No shipment inventory accounting summary found.
                </td>
              </tr>
              <tr
                v-for="(row, index) in visibleSummaries"
                :key="row.id"
                class="summary-row"
                :class="{ 'row-zero': isZeroRow(row) }"
              >
                <td class="sticky-col sticky-col-sl text-grey-7">{{ index + 1 }}</td>
                <td class="sticky-col sticky-col-shipment">
                  <q-badge color="primary" outline class="q-mr-xs" style="font-size: 10px">
                    #{{ row.shipment_id }}
                  </q-badge>
                  <span class="text-weight-medium">{{ row.shipment_name ?? '-' }}</span>
                </td>
                <td>
                  <span
                    class="inv-status-chip"
                    :class="`inv-status-chip--${(row.shipment_status ?? 'unknown').trim().toLowerCase()}`"
                  >
                    <span class="status-dot" :style="{ backgroundColor: statusDotColor(row.shipment_status) }" />
                    {{ row.shipment_status ?? '-' }}
                  </span>
                </td>
                <td class="text-right text-positive text-weight-medium">{{ row.usable_quantity }}</td>
                <td class="text-right" :class="row.damaged_quantity > 0 ? 'text-negative' : ''">{{ row.damaged_quantity }}</td>
                <td class="text-right" :class="row.stolen_quantity > 0 ? 'text-negative' : ''">{{ row.stolen_quantity }}</td>
                <td class="text-right">{{ row.expired_quantity }}</td>
                <td class="text-right">{{ row.open_box_quantity }}</td>
                <td class="text-right text-positive">{{ formatFixed2(row.usable_cost_total) }}</td>
                <td class="text-right" :class="row.damaged_cost_total > 0 ? 'text-negative' : ''">{{ formatFixed2(row.damaged_cost_total) }}</td>
                <td class="text-right" :class="row.stolen_cost_total > 0 ? 'text-negative' : ''">{{ formatFixed2(row.stolen_cost_total) }}</td>
                <td class="text-right">{{ formatFixed2(row.expired_cost_total) }}</td>
                <td class="text-right">{{ formatFixed2(row.open_box_cost_total) }}</td>
                <td class="text-right text-weight-bold">{{ formatFixed2(row.inventory_cost_total) }}</td>
              </tr>
              <tr v-if="visibleSummaries.length" class="totals-row">
                <td colspan="3" class="text-right text-weight-bold">Total</td>
                <td class="text-right text-weight-bold text-positive">{{ totals.usableQty }}</td>
                <td class="text-right text-weight-bold">{{ totals.damagedQty }}</td>
                <td class="text-right text-weight-bold">{{ totals.stolenQty }}</td>
                <td class="text-right text-weight-bold">{{ totals.expiredQty }}</td>
                <td class="text-right text-weight-bold">{{ totals.openBoxQty }}</td>
                <td class="text-right text-weight-bold text-positive">{{ formatFixed2(totals.usableCost) }}</td>
                <td class="text-right text-weight-bold">{{ formatFixed2(totals.damagedCost) }}</td>
                <td class="text-right text-weight-bold">{{ formatFixed2(totals.stolenCost) }}</td>
                <td class="text-right text-weight-bold">{{ formatFixed2(totals.expiredCost) }}</td>
                <td class="text-right text-weight-bold">{{ formatFixed2(totals.openBoxCost) }}</td>
                <td class="text-right text-weight-bold">{{ formatFixed2(totals.totalCost) }}</td>
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
import { useInventoryStore } from 'src/modules/inventory/stores/inventoryStore'
import { formatAmountBdt } from 'src/utils/currency'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const authStore = useAuthStore()
const inventoryStore = useInventoryStore()

// Toggle: show rows that are all-zero quantities/costs
const showZeroRows = ref(false)

const allSummaries = computed(() => inventoryStore.shipmentInventoryAccountingSummaries)

const isZeroRow = (row: (typeof allSummaries.value)[number]) =>
  Number(row.usable_quantity ?? 0) === 0 &&
  Number(row.damaged_quantity ?? 0) === 0 &&
  Number(row.stolen_quantity ?? 0) === 0 &&
  Number(row.expired_quantity ?? 0) === 0 &&
  Number(row.open_box_quantity ?? 0) === 0 &&
  Number(row.inventory_cost_total ?? 0) === 0

const visibleSummaries = computed(() =>
  showZeroRows.value ? allSummaries.value : allSummaries.value.filter((row) => !isZeroRow(row)),
)

const totals = computed(() =>
  visibleSummaries.value.reduce(
    (sum, row) => ({
      usableQty: sum.usableQty + Number(row.usable_quantity ?? 0),
      damagedQty: sum.damagedQty + Number(row.damaged_quantity ?? 0),
      stolenQty: sum.stolenQty + Number(row.stolen_quantity ?? 0),
      expiredQty: sum.expiredQty + Number(row.expired_quantity ?? 0),
      openBoxQty: sum.openBoxQty + Number(row.open_box_quantity ?? 0),
      usableCost: sum.usableCost + Number(row.usable_cost_total ?? 0),
      damagedCost: sum.damagedCost + Number(row.damaged_cost_total ?? 0),
      stolenCost: sum.stolenCost + Number(row.stolen_cost_total ?? 0),
      expiredCost: sum.expiredCost + Number(row.expired_cost_total ?? 0),
      openBoxCost: sum.openBoxCost + Number(row.open_box_cost_total ?? 0),
      totalCost: sum.totalCost + Number(row.inventory_cost_total ?? 0),
    }),
    {
      usableQty: 0,
      damagedQty: 0,
      stolenQty: 0,
      expiredQty: 0,
      openBoxQty: 0,
      usableCost: 0,
      damagedCost: 0,
      stolenCost: 0,
      expiredCost: 0,
      openBoxCost: 0,
      totalCost: 0,
    },
  ),
)

const formatFixed2 = (value: number | null | undefined) => formatAmountBdt(value)

const statusDotColor = (status: string | null | undefined) => {
  const v = (status ?? '').trim().toLowerCase()
  if (v === 'active') return '#2f8b5d'
  if (v === 'completed') return '#009688'
  if (v === 'pending') return '#9a6a24'
  if (v === 'cancelled') return '#a64c62'
  return '#66758c'
}

const loadSummaries = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return
  await inventoryStore.fetchShipmentInventoryAccountingSummaries({
    tenant_id: tenantId,
    page: 1,
    page_size: 1000,
    sortBy: 'shipment_id',
    sortOrder: 'desc',
  })
}

const onRefreshSummary = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return
  const refreshResult = await inventoryStore.refreshShipmentInventoryAccountingSummaries({
    tenant_id: tenantId,
  })
  if (!refreshResult.success) return
  await loadSummaries()
}

onMounted(() => {
  void loadSummaries()
})
</script>

<style scoped>
.inventory-accounting-page {
  background: transparent;
}

/* ── Floating surface ── */
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

/* ── Pill / slim buttons ── */
.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

/* ── Stat cards ── */
.stat-card {
  background: rgba(248, 250, 254, 0.9);
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 10px;
  padding: 12px 14px 10px;
  margin-bottom: 12px;
  transition: box-shadow 0.15s;
}

.stat-card:hover {
  box-shadow: 0 2px 12px rgba(34, 56, 101, 0.08);
}

.stat-card--negative { border-left: 3px solid #e53935; background: rgba(253, 245, 245, 0.9); }
.stat-card--positive { border-left: 3px solid #2e7d32; background: rgba(244, 251, 246, 0.9); }
.stat-card--primary  { border-left: 3px solid var(--q-primary, #1976d2); background: rgba(245, 249, 255, 0.9); }

.stat-label {
  font-size: 11px;
  font-weight: 500;
  color: #555e72;
  letter-spacing: 0.01em;
  margin-bottom: 4px;
  line-height: 1.35;
}

.stat-value {
  font-size: 20px;
  font-weight: 700;
  color: #1a2642;
  line-height: 1.2;
  letter-spacing: -0.01em;
}

.stat-unit {
  font-size: 10px;
  color: #8896aa;
  margin-top: 2px;
}

/* ── Status chip ── */
.inv-status-chip {
  display: inline-flex;
  align-items: center;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
  text-transform: capitalize;
  background: rgba(34, 56, 101, 0.06);
  color: #3b4b66;
  white-space: nowrap;
}

.inv-status-chip--active    { background: #e8f5e9; color: #2e7d32; }
.inv-status-chip--completed { background: #e0f2f1; color: #00695c; }
.inv-status-chip--pending   { background: #fff8e1; color: #6a4a14; }
.inv-status-chip--cancelled { background: #fdecea; color: #c62828; }

.status-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: 999px;
  margin-right: 6px;
  flex-shrink: 0;
}

/* ── Table ── */
.inventory-table-wrap {
  overflow-x: auto;
  overflow-y: auto;
  max-height: calc(100vh - 360px);
}

.inventory-table :deep(th) {
  background: color-mix(in srgb, #f7f9fc 96%, rgba(34, 56, 101, 0.04) 4%);
  font-size: 12px;
  font-weight: 600;
  color: #3b4b66;
  padding: 10px 12px;
  white-space: nowrap;
  position: sticky;
  top: 0;
  z-index: 2;
  border-bottom: 1px solid rgba(34, 56, 101, 0.1);
}

.inventory-table :deep(td) {
  padding: 8px 12px;
  font-size: 13px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.05);
  vertical-align: middle;
}

/* Sticky columns — solid backgrounds matching costing table pattern */
.sticky-col {
  position: sticky !important;
  z-index: 1;
}

.sticky-col-sl {
  left: 0;
  min-width: 44px;
  width: 44px;
  background: color-mix(in srgb, #fff 94%, #f8f9fa 6%);
}

.sticky-col-shipment {
  left: 44px;
  min-width: 200px;
  background: color-mix(in srgb, #fff 96%, #fcfcfc 4%);
}

/* Sticky header cells get higher z-index so they sit above data cells */
thead .sticky-col-sl {
  z-index: 4;
  background: color-mix(in srgb, #f7f9fc 94%, #f8f9fa 6%);
}

thead .sticky-col-shipment {
  z-index: 4;
  background: color-mix(in srgb, #f7f9fc 96%, #fcfcfc 4%);
}

.summary-row:hover td {
  background: rgba(34, 56, 101, 0.03);
}

/* Zero-value rows appear muted */
.row-zero td {
  opacity: 0.45;
}

.totals-row td {
  background: rgba(248, 250, 254, 0.95) !important;
  border-top: 2px solid rgba(34, 56, 101, 0.12);
  font-size: 13px;
}

/* ── Mobile ── */
@media (max-width: 599px) {
  .inventory-table-wrap {
    max-height: calc(100vh - 280px);
  }
}
</style>
