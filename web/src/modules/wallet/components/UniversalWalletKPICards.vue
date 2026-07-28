<template>
  <div class="row q-col-gutter-md">
    <!-- Current Balance Card -->
    <div class="col-xs-12 col-sm-4">
      <q-card flat class="soft-kpi-card balance-card">
        <q-card-section class="q-pa-md q-pa-md-lg">
          <div class="row items-center justify-between q-mb-sm">
            <span class="text-caption text-uppercase text-weight-bolder text-muted tracking-wider">
              Current Balance
            </span>
            <div class="icon-circle" :class="balanceAvatarClass">
              <q-icon name="ph ph-wallet" size="20px" />
            </div>
          </div>
          <div class="text-h4 text-weight-bolder font-mono q-my-xs" :class="balanceTextClass">
            {{ formatCurrency(totals.currentBalance) }}
          </div>
          <div class="row items-center text-caption text-muted q-mt-xs">
            <q-icon name="ph ph-clock-counter-clockwise" size="14px" class="q-mr-xs" />
            <span>Net running balance balance</span>
          </div>
        </q-card-section>
      </q-card>
    </div>

    <!-- Total Credits (IN) Card -->
    <div class="col-xs-12 col-sm-4">
      <q-card flat class="soft-kpi-card credit-card">
        <q-card-section class="q-pa-md q-pa-md-lg">
          <div class="row items-center justify-between q-mb-sm">
            <span class="text-caption text-uppercase text-weight-bolder text-positive-muted tracking-wider">
              Total Credits (IN)
            </span>
            <div class="icon-circle bg-emerald-soft text-emerald">
              <q-icon name="ph ph-arrow-down-left" size="20px" />
            </div>
          </div>
          <div class="text-h4 text-weight-bolder font-mono text-emerald q-my-xs">
            +{{ formatCurrency(totals.totalCredits) }}
          </div>
          <div class="row items-center text-caption text-muted q-mt-xs">
            <q-icon name="ph ph-trend-up" size="14px" class="q-mr-xs text-emerald" />
            <span>Total incoming payments</span>
          </div>
        </q-card-section>
      </q-card>
    </div>

    <!-- Total Debits (OUT) Card -->
    <div class="col-xs-12 col-sm-4">
      <q-card flat class="soft-kpi-card debit-card">
        <q-card-section class="q-pa-md q-pa-md-lg">
          <div class="row items-center justify-between q-mb-sm">
            <span class="text-caption text-uppercase text-weight-bolder text-negative-muted tracking-wider">
              Total Debits (OUT)
            </span>
            <div class="icon-circle bg-rose-soft text-rose">
              <q-icon name="ph ph-arrow-up-right" size="20px" />
            </div>
          </div>
          <div class="text-h4 text-weight-bolder font-mono text-rose q-my-xs">
            -{{ formatCurrency(totals.totalDebits) }}
          </div>
          <div class="row items-center text-caption text-muted q-mt-xs">
            <q-icon name="ph ph-trend-down" size="14px" class="q-mr-xs text-rose" />
            <span>Total outgoing payouts / fees</span>
          </div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { WalletTotals } from '../composables/useWalletMath';

const props = defineProps<{
  totals: WalletTotals;
  currencyCode?: string;
}>();

const formatCurrency = (amount: number) => {
  const currency = props.currencyCode || 'BDT';
  return new Intl.NumberFormat('en-BD', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
};

const balanceTextClass = computed(() => {
  if (props.totals.currentBalance > 0) return 'text-emerald';
  if (props.totals.currentBalance < 0) return 'text-rose';
  return 'text-ink';
});

const balanceAvatarClass = computed(() => {
  if (props.totals.currentBalance > 0) return 'bg-emerald-soft text-emerald';
  if (props.totals.currentBalance < 0) return 'bg-rose-soft text-rose';
  return 'bg-blue-soft text-blue';
});
</script>

<style scoped>
.soft-kpi-card {
  border-radius: 16px;
  border: 1px solid rgba(226, 232, 240, 0.8);
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: 0 4px 16px -4px rgba(0, 0, 0, 0.03);
}

.soft-kpi-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 24px -4px rgba(0, 0, 0, 0.06);
}

.balance-card {
  background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%);
}

.credit-card {
  background: linear-gradient(135deg, #ffffff 0%, #f0fdf4 100%);
}

.debit-card {
  background: linear-gradient(135deg, #ffffff 0%, #fff1f2 100%);
}

.text-ink {
  color: #0f172a;
}

.text-muted {
  color: #64748b;
}

.text-emerald {
  color: #059669;
}

.text-rose {
  color: #e11d48;
}

.text-blue {
  color: #2563eb;
}

.bg-emerald-soft {
  background: rgba(16, 185, 129, 0.12);
}

.bg-rose-soft {
  background: rgba(244, 63, 94, 0.12);
}

.bg-blue-soft {
  background: rgba(37, 99, 235, 0.12);
}

.icon-circle {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.tracking-wider {
  letter-spacing: 0.05em;
}
</style>

