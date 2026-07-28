<template>
  <div class="row q-col-gutter-md">
    <!-- Current Balance Card -->
    <div class="col-xs-12 col-sm-4">
      <q-card flat bordered class="stat-card card-hover">
        <q-card-section class="q-pa-md">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-uppercase text-weight-bold text-muted">
              Current Balance
            </span>
            <q-avatar
              size="32px"
              :class="balanceAvatarClass"
            >
              <q-icon name="account_balance_wallet" size="18px" />
            </q-avatar>
          </div>
          <div class="text-h5 text-weight-bolder" :class="balanceTextClass">
            {{ formatCurrency(totals.currentBalance) }}
          </div>
          <div class="text-caption text-muted q-mt-xs">
            Running balance after latest txn
          </div>
        </q-card-section>
      </q-card>
    </div>

    <!-- Total Credits (IN) Card -->
    <div class="col-xs-12 col-sm-4">
      <q-card flat bordered class="stat-card card-hover">
        <q-card-section class="q-pa-md">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-uppercase text-weight-bold text-muted">
              Total Credits (IN)
            </span>
            <q-avatar size="32px" class="bg-positive-soft text-positive">
              <q-icon name="arrow_downward" size="18px" />
            </q-avatar>
          </div>
          <div class="text-h5 text-weight-bolder text-positive">
            +{{ formatCurrency(totals.totalCredits) }}
          </div>
          <div class="text-caption text-muted q-mt-xs">
            Total money received
          </div>
        </q-card-section>
      </q-card>
    </div>

    <!-- Total Debits (OUT) Card -->
    <div class="col-xs-12 col-sm-4">
      <q-card flat bordered class="stat-card card-hover">
        <q-card-section class="q-pa-md">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-uppercase text-weight-bold text-muted">
              Total Debits (OUT)
            </span>
            <q-avatar size="32px" class="bg-negative-soft text-negative">
              <q-icon name="arrow_upward" size="18px" />
            </q-avatar>
          </div>
          <div class="text-h5 text-weight-bolder text-negative">
            -{{ formatCurrency(totals.totalDebits) }}
          </div>
          <div class="text-caption text-muted q-mt-xs">
            Total money paid / deducted
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
  if (props.totals.currentBalance > 0) return 'text-positive';
  if (props.totals.currentBalance < 0) return 'text-negative';
  return 'text-ink';
});

const balanceAvatarClass = computed(() => {
  if (props.totals.currentBalance > 0) return 'bg-positive-soft text-positive';
  if (props.totals.currentBalance < 0) return 'bg-negative-soft text-negative';
  return 'bg-primary-soft text-primary';
});
</script>

<style scoped>
.stat-card {
  background: var(--bw-theme-surface);
  border-color: var(--bw-theme-border);
  border-radius: 10px;
}

.text-muted {
  color: var(--bw-theme-muted);
}

.text-ink {
  color: var(--bw-theme-ink);
}

.bg-positive-soft {
  background: rgba(33, 186, 69, 0.12);
}

.bg-negative-soft {
  background: rgba(193, 0, 21, 0.12);
}

.bg-primary-soft {
  background: var(--bw-theme-primary-soft);
}

.card-hover {
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: var(--bw-theme-shadow);
}
</style>
