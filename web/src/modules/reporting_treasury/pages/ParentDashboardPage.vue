<template>
  <TreasuryPageShell
    title="Consolidated Treasury Rollup"
    subtitle="Multi-tenant operations summary: sales performance, cash collections, accounts receivable, and middle-man obligations."
    :error="error"
  >
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <div v-else class="q-gutter-y-lg">
      <TreasuryStatGrid :items="statCards" />

      <div class="row q-col-gutter-lg">
        <div class="col-12 col-md-5">
          <q-card flat bordered class="q-pa-md full-height">
            <div class="text-subtitle1 text-weight-bold q-mb-lg text-primary">
              Sales Distribution (by Channels)
            </div>
            <div class="q-gutter-y-lg">
              <div v-for="type in typeDistribution" :key="type.name">
                <div class="row justify-between text-caption text-weight-bold q-mb-xs">
                  <span class="text-grey-8 text-capitalize">{{ type.name }}</span>
                  <span class="text-primary"
                    >{{ formatAmountBdt(type.amount) }} ({{ type.percent }}%)</span
                  >
                </div>
                <q-linear-progress
                  :value="type.percent / 100"
                  color="primary"
                  class="rounded-borders"
                  style="height: 10px"
                />
              </div>
            </div>
          </q-card>
        </div>

        <div class="col-12 col-md-7">
          <q-card flat bordered class="q-pa-md full-height">
            <div class="text-subtitle1 text-weight-bold q-mb-lg text-primary">
              Treasury Clearances
            </div>
            <TreasuryTableWrap>
              <q-markup-table flat bordered wrap-cells style="min-width: 700px">
                <thead>
                  <tr>
                    <th class="text-left font-semibold">Financial Area</th>
                    <th class="text-right font-semibold">Total Amount</th>
                    <th class="text-right font-semibold">Unallocated/Pending</th>
                    <th class="text-right font-semibold">Clearance %</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="py-3 font-semibold">Customer Invoices</td>
                    <td class="text-right">{{ formatAmountBdt(totals.revenue) }}</td>
                    <td class="text-right text-negative">
                      {{ formatAmountBdt(totals.active_ar) }}
                    </td>
                    <td class="text-right text-primary font-semibold cursor-pointer">
                      {{
                        totals.revenue > 0
                          ? (((totals.revenue - totals.active_ar) / totals.revenue) * 100).toFixed(
                              1,
                            )
                          : '0.0'
                      }}%
                      <q-tooltip>AR Clearance % = (Revenue - Active AR) / Revenue</q-tooltip>
                    </td>
                  </tr>
                  <tr>
                    <td class="py-3 font-semibold">Received Payments</td>
                    <td class="text-right">{{ formatAmountBdt(totals.cash_collected) }}</td>
                    <td class="text-right text-warning">
                      {{ formatAmountBdt(totals.unallocated_payments) }}
                    </td>
                    <td class="text-right text-primary font-semibold cursor-pointer">
                      {{
                        totals.cash_collected > 0
                          ? (
                              ((totals.cash_collected - totals.unallocated_payments) /
                                totals.cash_collected) *
                              100
                            ).toFixed(1)
                          : '0.0'
                      }}%
                      <q-tooltip>Allocation % = (Collected - Unallocated) / Collected</q-tooltip>
                    </td>
                  </tr>
                  <tr>
                    <td class="py-3 font-semibold">Middle-Man Payouts</td>
                    <td class="text-right">{{ formatAmountBdt(totals.middleman_total) }}</td>
                    <td class="text-right text-warning">
                      {{ formatAmountBdt(totals.middleman_liability) }}
                    </td>
                    <td class="text-right text-primary font-semibold cursor-pointer">
                      {{
                        totals.middleman_total > 0
                          ? (
                              ((totals.middleman_total - totals.middleman_liability) /
                                totals.middleman_total) *
                              100
                            ).toFixed(1)
                          : '0.0'
                      }}%
                      <q-tooltip
                        >Settled % = (Payouts Total - Pending Liability) / Payouts Total</q-tooltip
                      >
                    </td>
                  </tr>
                </tbody>
              </q-markup-table>
            </TreasuryTableWrap>
          </q-card>
        </div>
      </div>
    </div>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { treasuryRepository } from '../repositories/treasuryRepository';
import TreasuryPageShell from '../components/TreasuryPageShell.vue';
import TreasuryStatGrid from '../components/TreasuryStatGrid.vue';
import TreasuryTableWrap from '../components/TreasuryTableWrap.vue';

const $q = useQuasar();
const authStore = useAuthStore();

const loading = ref(false);
const error = ref<string | null>(null);

const totals = ref({
  revenue: 0,
  cash_collected: 0,
  active_ar: 0,
  unallocated_payments: 0,
  middleman_total: 0,
  middleman_liability: 0,
});

const typeAmounts = ref<Record<string, number>>({
  wholesale: 0,
  retail: 0,
  dropship: 0,
});

const statCards = computed(() => [
  {
    label: 'Consolidated Sales',
    value: totals.value.revenue,
    caption: 'All posted invoices subtotal',
  },
  {
    label: 'Total Cash Collected',
    value: totals.value.cash_collected,
    caption: 'Aggregated global payments',
    valueClass: 'text-positive',
  },
  {
    label: 'Active AR (Receivables)',
    value: totals.value.active_ar,
    caption: 'Outstanding buyer obligations',
    valueClass: 'text-negative',
  },
  {
    label: 'Middle-Man Liabilities',
    value: totals.value.middleman_liability,
    caption: 'Pending dropship payouts',
    valueClass: 'text-warning',
  },
]);

const loadStats = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId) return;

  loading.value = true;
  error.value = null;
  try {
    const dashboard = await treasuryRepository.getParentDashboard(tenantId);
    totals.value = {
      revenue: Number(dashboard.totals.revenue) || 0,
      cash_collected: Number(dashboard.totals.cash_collected) || 0,
      active_ar: Number(dashboard.totals.active_ar) || 0,
      unallocated_payments: Number(dashboard.totals.unallocated_payments) || 0,
      middleman_total: Number(dashboard.totals.middleman_total) || 0,
      middleman_liability: Number(dashboard.totals.middleman_liability) || 0,
    };

    const map: Record<string, number> = { wholesale: 0, retail: 0, dropship: 0 };
    for (const row of dashboard.type_distribution ?? []) {
      const key = row.name || 'wholesale';
      if (map[key] !== undefined) {
        map[key] = Number(row.amount) || 0;
      }
    }
    typeAmounts.value = map;
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to load dashboard';
    error.value = message;
    $q.notify({ type: 'negative', message: `Failed to load dashboard: ${message}` });
  } finally {
    loading.value = false;
  }
};

const typeDistribution = computed(() => {
  const sum = Object.values(typeAmounts.value).reduce((a, b) => a + b, 0);
  return Object.entries(typeAmounts.value).map(([name, amount]) => ({
    name,
    amount,
    percent: sum > 0 ? Math.round((amount / sum) * 100) : 0,
  }));
});

onMounted(() => {
  void loadStats();
});
</script>

<style scoped>
.full-height {
  height: 100%;
}
</style>
