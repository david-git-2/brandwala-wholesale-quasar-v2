<template>
  <div class="row q-col-gutter-md">
    <div
      v-for="tile in tiles"
      :key="tile.key"
      class="col-xs-12 col-sm-4"
    >
      <q-card flat class="soft-kpi-card" :class="tile.cardClass">
        <q-card-section class="q-pa-md q-pa-md-lg">
          <div class="row items-center justify-between q-mb-sm">
            <span class="text-caption text-uppercase text-weight-bolder tracking-wider" :class="tile.labelClass">
              {{ tile.label }}
            </span>
            <div class="icon-circle" :class="tile.iconBg">
              <q-icon :name="tile.icon" size="20px" />
            </div>
          </div>
          <div class="text-h4 text-weight-bolder font-mono q-my-xs" :class="tile.valueClass">
            {{ tile.prefix }}{{ formatCurrency(tile.value) }}
          </div>
          <div class="row items-center text-caption text-muted q-mt-xs">
            <q-icon :name="tile.subIcon" size="14px" class="q-mr-xs" :class="tile.subIconClass" />
            <span>{{ tile.hint }}</span>
          </div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { WalletTotals } from '../composables/useWalletMath';
import type { UniversalWalletEntityType } from '../types';

interface KpiTile {
  key: string;
  label: string;
  value: number;
  prefix: string;
  hint: string;
  icon: string;
  subIcon: string;
  cardClass: string;
  labelClass: string;
  iconBg: string;
  valueClass: string;
  subIconClass: string;
}

const props = defineProps<{
  totals: WalletTotals;
  entityType: UniversalWalletEntityType;
  currencyCode?: string;
}>();

const fmt = (amount: number) => {
  const currency = props.currencyCode || 'BDT';
  return new Intl.NumberFormat('en-BD', {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Math.abs(amount));
};

const formatCurrency = fmt;

const s = computed(() => props.totals.sectionTotals);

const balanceValueClass = computed(() => {
  if (props.totals.currentBalance > 0) return 'text-emerald';
  if (props.totals.currentBalance < 0) return 'text-rose';
  return 'text-ink';
});

const balanceIconBg = computed(() => {
  if (props.totals.currentBalance > 0) return 'bg-emerald-soft text-emerald';
  if (props.totals.currentBalance < 0) return 'bg-rose-soft text-rose';
  return 'bg-blue-soft text-blue';
});

const tiles = computed<KpiTile[]>(() => {
  const balance = props.totals.currentBalance;

  if (props.entityType === 'customer' || props.entityType === 'middleman') {
    const profitPending = s.value['payout_earned'] ?? 0;
    const paymentsReceived = s.value['payment_received'] ?? 0;

    return [
      {
        key: 'balance',
        label: 'Outstanding Balance',
        value: balance,
        prefix: balance < 0 ? '-' : '',
        hint: 'Negative = they owe you; profit credits raise the balance',
        icon: 'ph ph-warning-circle',
        subIcon: 'ph ph-info',
        cardClass: balance < 0 ? 'card-rose' : 'card-default',
        labelClass: balance < 0 ? 'text-rose-muted' : 'text-muted',
        iconBg: balanceIconBg.value,
        valueClass: balanceValueClass.value,
        subIconClass: '',
      },
      {
        key: 'profit',
        label: 'Profit Pending Payout',
        value: Math.max(profitPending, 0),
        prefix: '',
        hint: 'Dropship margin awaiting payout (0 for wholesale accounts)',
        icon: 'ph ph-piggy-bank',
        subIcon: 'ph ph-trend-up',
        cardClass: 'card-amber',
        labelClass: 'text-amber-muted',
        iconBg: 'bg-amber-soft text-amber',
        valueClass: 'text-amber',
        subIconClass: 'text-amber',
      },
      {
        key: 'payments',
        label: 'Total Payments Received',
        value: paymentsReceived,
        prefix: '',
        hint: 'Total incoming payments',
        icon: 'ph ph-hand-coins',
        subIcon: 'ph ph-trend-up',
        cardClass: 'card-emerald',
        labelClass: 'text-positive-muted',
        iconBg: 'bg-emerald-soft text-emerald',
        valueClass: 'text-emerald',
        subIconClass: 'text-emerald',
      },
    ];
  }

  if (props.entityType === 'courier') {
    const codPending = Math.abs(s.value['cod_holding'] ?? 0);
    const deliveryFees = Math.abs(s.value['delivery_fee'] ?? 0);

    return [
      {
        key: 'balance',
        label: 'Current Balance',
        value: balance,
        prefix: balance < 0 ? '-' : '',
        hint: 'Negative = COD/fees not yet settled',
        icon: 'ph ph-wallet',
        subIcon: 'ph ph-clock-counter-clockwise',
        cardClass: 'card-default',
        labelClass: 'text-muted',
        iconBg: balanceIconBg.value,
        valueClass: balanceValueClass.value,
        subIconClass: '',
      },
      {
        key: 'cod',
        label: 'COD Pending Remittance',
        value: codPending,
        prefix: '',
        hint: 'Collected COD not yet remitted',
        icon: 'ph ph-money',
        subIcon: 'ph ph-clock',
        cardClass: 'card-blue',
        labelClass: 'text-blue-muted',
        iconBg: 'bg-blue-soft text-blue',
        valueClass: 'text-blue',
        subIconClass: 'text-blue',
      },
      {
        key: 'fees',
        label: 'Delivery Fees Outstanding',
        value: deliveryFees,
        prefix: '',
        hint: 'Delivery fees not yet settled',
        icon: 'ph ph-truck',
        subIcon: 'ph ph-receipt',
        cardClass: 'card-rose',
        labelClass: 'text-rose-muted',
        iconBg: 'bg-rose-soft text-rose',
        valueClass: 'text-rose',
        subIconClass: 'text-rose',
      },
    ];
  }

  if (props.entityType === 'tenant') {
    const totalRevenue = s.value['revenue'] ?? 0;
    // courier costs tracked as delivery_fee debits
    const courierCosts = Math.abs(s.value['delivery_fee'] ?? 0);
    const profitPaidOut = Math.abs(s.value['payout_earned'] ?? 0);

    return [
      {
        key: 'revenue',
        label: 'Total Revenue',
        value: totalRevenue,
        prefix: '',
        hint: 'Net revenue recorded',
        icon: 'ph ph-chart-line-up',
        subIcon: 'ph ph-trend-up',
        cardClass: 'card-teal',
        labelClass: 'text-teal-muted',
        iconBg: 'bg-teal-soft text-teal',
        valueClass: 'text-teal',
        subIconClass: 'text-teal',
      },
      {
        key: 'courier',
        label: 'Total Courier Costs',
        value: courierCosts,
        prefix: '',
        hint: 'Delivery / COD fees (posted on remittance, not at accounting invoice)',
        icon: 'ph ph-truck',
        subIcon: 'ph ph-trend-down',
        cardClass: 'card-rose',
        labelClass: 'text-rose-muted',
        iconBg: 'bg-rose-soft text-rose',
        valueClass: 'text-rose',
        subIconClass: 'text-rose',
      },
      {
        key: 'payout',
        label: 'Total Profit Paid Out',
        value: profitPaidOut,
        prefix: '',
        hint: 'Reseller profit disbursed',
        icon: 'ph ph-arrow-up-right',
        subIcon: 'ph ph-trend-down',
        cardClass: 'card-amber',
        labelClass: 'text-amber-muted',
        iconBg: 'bg-amber-soft text-amber',
        valueClass: 'text-amber',
        subIconClass: 'text-amber',
      },
    ];
  }

  // Generic fallback (vendor etc.)
  return [
    {
      key: 'balance',
      label: 'Current Balance',
      value: balance,
      prefix: balance < 0 ? '-' : '',
      hint: 'Net running balance',
      icon: 'ph ph-wallet',
      subIcon: 'ph ph-clock-counter-clockwise',
      cardClass: 'card-default',
      labelClass: 'text-muted',
      iconBg: balanceIconBg.value,
      valueClass: balanceValueClass.value,
      subIconClass: '',
    },
    {
      key: 'credits',
      label: 'Total Credits (IN)',
      value: props.totals.totalCredits,
      prefix: '+',
      hint: 'Total incoming payments',
      icon: 'ph ph-arrow-down-left',
      subIcon: 'ph ph-trend-up',
      cardClass: 'card-emerald',
      labelClass: 'text-positive-muted',
      iconBg: 'bg-emerald-soft text-emerald',
      valueClass: 'text-emerald',
      subIconClass: 'text-emerald',
    },
    {
      key: 'debits',
      label: 'Total Debits (OUT)',
      value: props.totals.totalDebits,
      prefix: '-',
      hint: 'Total outgoing payouts / fees',
      icon: 'ph ph-arrow-up-right',
      subIcon: 'ph ph-trend-down',
      cardClass: 'card-rose',
      labelClass: 'text-negative-muted',
      iconBg: 'bg-rose-soft text-rose',
      valueClass: 'text-rose',
      subIconClass: 'text-rose',
    },
  ];
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

.card-default { background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%); }
.card-emerald { background: linear-gradient(135deg, #ffffff 0%, #f0fdf4 100%); }
.card-rose    { background: linear-gradient(135deg, #ffffff 0%, #fff1f2 100%); }
.card-amber   { background: linear-gradient(135deg, #ffffff 0%, #fffbeb 100%); }
.card-blue    { background: linear-gradient(135deg, #ffffff 0%, #eff6ff 100%); }
.card-teal    { background: linear-gradient(135deg, #ffffff 0%, #f0fdfa 100%); }

.text-ink   { color: #0f172a; }
.text-muted { color: #64748b; }
.text-emerald { color: #059669; }
.text-rose    { color: #e11d48; }
.text-blue    { color: #2563eb; }
.text-amber   { color: #d97706; }
.text-teal    { color: #0d9488; }

.text-rose-muted  { color: #f43f5e; }
.text-amber-muted { color: #f59e0b; }
.text-blue-muted  { color: #3b82f6; }
.text-teal-muted  { color: #14b8a6; }

.bg-emerald-soft { background: rgba(16, 185, 129, 0.12); }
.bg-rose-soft    { background: rgba(244, 63, 94, 0.12); }
.bg-blue-soft    { background: rgba(37, 99, 235, 0.12); }
.bg-amber-soft   { background: rgba(217, 119, 6, 0.12); }
.bg-teal-soft    { background: rgba(13, 148, 136, 0.12); }

.icon-circle {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.tracking-wider { letter-spacing: 0.05em; }
</style>
