<template>
  <q-card flat bordered class="wallet-account-card q-pa-md shadow-1">
    <div class="row items-center justify-between q-mb-md">
      <div class="row items-center q-gutter-x-sm">
        <q-avatar size="36px" class="bg-primary-soft text-primary text-weight-bold">
          <q-icon name="ph ph-wallet" size="20px" />
        </q-avatar>
        <div>
          <div class="text-caption text-grey-7 font-mono uppercase tracking-wider">3-Bucket Balance State</div>
          <div class="text-subtitle1 text-weight-bolder text-ink">
            {{ entityName || entityType.toUpperCase() }} Financial Account
          </div>
        </div>
      </div>
      <div class="row items-center q-gutter-x-sm">
        <q-chip dense flat class="bg-grey-2 text-grey-8 font-mono text-weight-bold">
          {{ currencyCode }}
        </q-chip>
        <q-btn
          v-if="allowActions"
          flat
          dense
          color="primary"
          icon="ph ph-arrows-left-right"
          label="Transfer Buckets"
          class="q-px-sm text-weight-bold text-caption rounded-borders"
          @click="$emit('open-transfer')"
        >
          <q-tooltip>Shift funds between Pending, Available &amp; Locked</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- 3 Buckets Grid -->
    <div class="row q-col-gutter-md">
      <!-- 1. Available Balance (Settled & Withdrawable) -->
      <div class="col-xs-12 col-sm-4">
        <div class="bucket-box available-bucket q-pa-md rounded-borders">
          <div class="row items-center justify-between q-mb-xs">
            <span class="bucket-label text-positive text-weight-bold">Available Balance</span>
            <q-icon name="ph ph-check-circle" color="positive" size="18px" />
          </div>
          <div class="bucket-amount text-h6 text-weight-bolder font-mono text-positive">
            {{ formatCurrency(account?.available_balance || 0) }}
          </div>
          <div class="bucket-subtext text-caption text-grey-6">
            Settled &amp; liquid funds available for payout/withdrawal
          </div>
        </div>
      </div>

      <!-- 2. Pending Balance (Accrued / In-Flight Holding) -->
      <div class="col-xs-12 col-sm-4">
        <div class="bucket-box pending-bucket q-pa-md rounded-borders">
          <div class="row items-center justify-between q-mb-xs">
            <span class="bucket-label text-warning text-weight-bold">Pending Balance</span>
            <q-icon name="ph ph-clock-clockwise" color="warning" size="18px" />
          </div>
          <div class="bucket-amount text-h6 text-weight-bolder font-mono text-warning">
            {{ formatCurrency(account?.pending_balance || 0) }}
          </div>
          <div class="bucket-subtext text-caption text-grey-6">
            Accrued margins / COD holding awaiting remittance
          </div>
        </div>
      </div>

      <!-- 3. Locked Balance (Reserved / Hold) -->
      <div class="col-xs-12 col-sm-4">
        <div class="bucket-box locked-bucket q-pa-md rounded-borders">
          <div class="row items-center justify-between q-mb-xs">
            <span class="bucket-label text-indigo text-weight-bold">Locked Balance</span>
            <q-icon name="ph ph-lock-key" color="indigo" size="18px" />
          </div>
          <div class="bucket-amount text-h6 text-weight-bolder font-mono text-indigo">
            {{ formatCurrency(account?.locked_balance || 0) }}
          </div>
          <div class="bucket-subtext text-caption text-grey-6">
            Reserved for active payout requests or dispute holds
          </div>
        </div>
      </div>
    </div>

    <!-- Net Total Bar -->
    <div class="net-total-bar row items-center justify-between q-mt-md q-px-md q-py-sm rounded-borders">
      <div class="text-caption text-weight-bold text-grey-8">Total Net Entity Balance</div>
      <div class="text-subtitle1 text-weight-bolder font-mono text-primary">
        {{ formatCurrency(totalNetBalance) }} {{ currencyCode }}
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { WalletAccount, UniversalWalletEntityType } from '../types';

const props = withDefaults(
  defineProps<{
    account?: WalletAccount | null;
    entityType: UniversalWalletEntityType;
    entityName?: string;
    currencyCode?: string;
    allowActions?: boolean;
  }>(),
  {
    account: null,
    entityName: '',
    currencyCode: 'BDT',
    allowActions: true,
  },
);

defineEmits<{
  (e: 'open-transfer'): void;
}>();

const totalNetBalance = computed(() => {
  if (!props.account) return 0;
  return (
    Number(props.account.available_balance || 0) +
    Number(props.account.pending_balance || 0) +
    Number(props.account.locked_balance || 0)
  );
});

function formatCurrency(val: number): string {
  return new Intl.NumberFormat('en-BD', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(val || 0);
}
</script>

<style scoped>
.wallet-account-card {
  border-radius: 12px;
  background: var(--bw-card-bg, #ffffff);
}

.text-ink {
  color: var(--bw-theme-ink, #1e293b);
}

.bg-primary-soft {
  background: rgba(var(--q-primary-rgb, 59, 130, 246), 0.08) !important;
}

.bucket-box {
  border: 1px solid #e2e8f0;
  transition: all 0.2s ease;
}

.bucket-box:hover {
  transform: translateY(-2px);
}

.available-bucket {
  background: rgba(34, 197, 94, 0.04);
  border-color: rgba(34, 197, 94, 0.2);
}

.pending-bucket {
  background: rgba(245, 158, 11, 0.04);
  border-color: rgba(245, 158, 11, 0.2);
}

.locked-bucket {
  background: rgba(99, 102, 241, 0.04);
  border-color: rgba(99, 102, 241, 0.2);
}

.net-total-bar {
  background: rgba(241, 245, 249, 0.8);
  border: 1px solid #e2e8f0;
}
</style>
