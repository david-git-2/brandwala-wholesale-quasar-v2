<template>
  <div class="column q-gutter-y-md">
    <div v-if="isLoading" class="row justify-center q-py-lg">
      <q-spinner color="primary" size="2em" />
    </div>

    <div v-else-if="isError" class="text-center text-negative q-pa-md">
      {{ errorMessage }}
    </div>

    <template v-else-if="summary">
      <div v-if="!summary.billing_profile_id" class="text-caption text-grey-7 text-center q-pa-md">
        No billing profile linked — create or link one to see account balances.
      </div>

      <template v-else>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-card flat bordered class="q-pa-md rounded-borders account-card account-card--due">
              <div class="text-caption text-uppercase text-grey-7">They owe us</div>
              <div class="text-h5 text-weight-bolder" :class="stillDueClass">
                {{ formatBdt(summary.still_due) }}
              </div>
              <div class="text-caption text-grey-6">Invoice balance due</div>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat bordered class="q-pa-md rounded-borders account-card account-card--credit">
              <div class="text-caption text-uppercase text-grey-7">We owe them</div>
              <div class="text-h5 text-weight-bolder text-positive">
                {{ formatBdt(summary.store_credit_balance) }}
              </div>
              <div class="text-caption text-grey-6">Store credit</div>
            </q-card>
          </div>
        </div>

        <div class="row q-col-gutter-xs text-caption text-grey-7">
          <div class="col-auto">Billed: {{ formatBdt(summary.total_billed) }}</div>
          <div class="col-auto">·</div>
          <div class="col-auto">Cash collected: {{ formatBdt(summary.collected_cash) }}</div>
          <div class="col-auto">·</div>
          <div class="col-auto">Credit applied: {{ formatBdt(summary.wallet_applied) }}</div>
          <div class="col-auto">·</div>
          <div class="col-auto">Settlement: {{ formatBdt(summary.settlement) }}</div>
          <div v-if="summary.unallocated_payments > 0" class="col-auto">·</div>
          <div v-if="summary.unallocated_payments > 0" class="col-auto text-orange-9">
            Unallocated: {{ formatBdt(summary.unallocated_payments) }}
          </div>
        </div>

        <div class="row q-gutter-xs wrap">
          <q-btn
            flat
            dense
            icon="ph ph-arrows-clockwise"
            label="Refresh"
            no-caps
            size="sm"
            class="text-caption"
            @click="emit('refresh')"
          />
        </div>

        <div v-if="summary.open_invoices.length">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Open invoices</div>
          <q-card flat bordered class="rounded-borders">
            <q-markup-table flat dense wrap-cells>
              <thead>
                <tr>
                  <th class="text-left">Invoice</th>
                  <th class="text-left">Type</th>
                  <th class="text-right">Due</th>
                  <th class="text-left">Desk</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="inv in summary.open_invoices" :key="inv.id">
                  <td class="text-weight-medium">{{ inv.invoice_no }}</td>
                  <td class="text-caption text-grey-7">{{ inv.invoice_type }}</td>
                  <td class="text-right text-weight-bold text-negative">
                    {{ formatBdt(inv.due_amount) }}
                  </td>
                  <td class="text-caption">{{ inv.issued_by_tenant_name || '—' }}</td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>
        </div>

        <div v-if="activityRows.length">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Recent activity</div>
          <q-list separator bordered class="rounded-borders">
            <q-item v-for="row in activityRows" :key="row.key" class="q-py-sm">
              <q-item-section>
                <q-item-label class="text-weight-bold text-caption text-grey-9">
                  {{ row.label }}
                </q-item-label>
                <q-item-label caption class="text-grey-7">
                  {{ row.subtitle }}
                </q-item-label>
              </q-item-section>
              <q-item-section side class="text-right">
                <q-item-label
                  class="text-weight-bold text-caption"
                  :class="row.amountClass"
                >
                  {{ row.amountText }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div v-if="summary.shop_access.length">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Shop access</div>
          <q-card flat bordered class="rounded-borders">
            <q-markup-table flat dense wrap-cells>
              <thead>
                <tr>
                  <th class="text-left">Shop</th>
                  <th class="text-left">Tenant</th>
                  <th class="text-left">Type</th>
                  <th class="text-right">Credit limit</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="shop in summary.shop_access" :key="shop.shop_id">
                  <td>{{ shop.shop_name }}</td>
                  <td class="text-caption">{{ shop.shop_tenant_name }}</td>
                  <td class="text-caption text-grey-7">{{ shop.shop_type }}</td>
                  <td class="text-right text-caption">
                    {{ shop.credit_limit_amount != null ? formatBdt(shop.credit_limit_amount) : '—' }}
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>
        </div>
      </template>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { CustomerAccountSummary } from '../types/customer';

const props = defineProps<{
  tenantId: number;
  customerGroupId: number;
  groupName: string;
  billingProfileId: number | null;
  summary: CustomerAccountSummary | null | undefined;
  isLoading: boolean;
  isError: boolean;
  error: Error | null;
}>();

const emit = defineEmits<{
  (e: 'refresh'): void;
  (e: 'action-complete'): void;
}>();

const errorMessage = computed(() => props.error?.message || 'Failed to load account summary.');

const stillDueClass = computed(() =>
  Number(props.summary?.still_due ?? 0) > 0 ? 'text-negative' : 'text-grey-8',
);

type ActivityRow = {
  key: string;
  label: string;
  subtitle: string;
  amountText: string;
  amountClass: string;
};

const activityRows = computed<ActivityRow[]>(() => {
  const summary = props.summary;
  if (!summary) return [];

  const payments = (summary.recent_payments ?? []).map((p) => ({
    key: `pay-${p.payment_id}`,
    label: `Payment (${p.method})`,
    subtitle: `${p.payment_date}${p.invoice_id ? ` · Invoice #${p.invoice_id}` : ''}`,
    amountText: `+${formatBdt(p.amount)}`,
    amountClass: 'text-positive',
    sortAt: p.payment_date,
  }));

  const ledger = (summary.recent_ledger ?? []).map((l) => ({
    key: `led-${l.id}`,
    label: l.label || l.transaction_type || 'Ledger entry',
    subtitle: formatActivityDate(l.created_at),
    amountText: `${l.type === 'credit' ? '+' : '-'}${formatBdt(Number(l.amount))}`,
    amountClass: l.type === 'credit' ? 'text-positive' : 'text-negative',
    sortAt: l.created_at,
  }));

  return [...payments, ...ledger]
    .sort((a, b) => String(b.sortAt).localeCompare(String(a.sortAt)))
    .slice(0, 20)
    .map(({ key, label, subtitle, amountText, amountClass }) => ({
      key,
      label,
      subtitle,
      amountText,
      amountClass,
    }));
});

const formatBdt = (val?: number | null) => {
  const num = Number(val) || 0;
  return `${num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} BDT`;
};

const formatActivityDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
</script>

<style scoped>
.account-card {
  border-radius: 10px;
}

.account-card--due {
  border-left: 3px solid #ef4444;
}

.account-card--credit {
  border-left: 3px solid #22c55e;
}
</style>
