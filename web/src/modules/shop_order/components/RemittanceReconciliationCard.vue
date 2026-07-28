<template>
  <q-card flat bordered class="reconciliation-card">
    <q-card-section class="q-pb-sm">
      <div class="row items-center justify-between">
        <div class="text-subtitle1 text-weight-bold flex items-center gap-2">
          <q-icon name="account_balance_wallet" color="primary" size="20px" />
          <span>Remittance Live Reconciliation</span>
        </div>
        <!-- Status Indicator Pill -->
        <q-chip
          :color="isBalanced ? 'positive' : 'negative'"
          text-color="white"
          dense
          size="md"
          class="text-weight-bold"
        >
          <q-icon :name="isBalanced ? 'check_circle' : 'warning'" class="q-mr-xs" />
          {{ isBalanced ? 'RECONCILED (0.00 Variance)' : `VARIANCE: ৳ ${formatAmount(variance)}` }}
        </q-chip>
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section class="q-pt-md">
      <div class="row q-col-gutter-md">
        <!-- Selected Items Stat -->
        <div class="col-xs-6 col-sm-3">
          <div class="stat-block">
            <div class="text-caption text-grey-7">Selected Orders</div>
            <div class="text-h6 text-weight-bold text-dark">
              {{ itemCount }} <span class="text-caption text-grey-6">items</span>
            </div>
          </div>
        </div>

        <!-- Total Gross COD -->
        <div class="col-xs-6 col-sm-3">
          <div class="stat-block">
            <div class="text-caption text-grey-7">Selected Gross COD</div>
            <div class="text-h6 text-weight-bold text-primary">
              ৳ {{ formatAmount(totalCod) }}
            </div>
          </div>
        </div>

        <!-- Total Courier Charges -->
        <div class="col-xs-6 col-sm-3">
          <div class="stat-block">
            <div class="text-caption text-grey-7">Selected Courier Fees</div>
            <div class="text-h6 text-weight-bold text-negative">
              ৳ {{ formatAmount(totalCharges) }}
            </div>
          </div>
        </div>

        <!-- Calculated Batch Net -->
        <div class="col-xs-6 col-sm-3">
          <div class="stat-block bg-primary-soft">
            <div class="text-caption text-grey-7">Calculated Batch Net</div>
            <div class="text-h6 text-weight-bold text-positive">
              ৳ {{ formatAmount(calculatedNet) }}
            </div>
          </div>
        </div>
      </div>

      <!-- Variance Details Warning Bar -->
      <div v-if="!isBalanced" class="q-mt-md">
        <q-banner dense rounded class="bg-red-1 text-negative border-red">
          <template #avatar>
            <q-icon name="error_outline" color="negative" />
          </template>
          <div>
            <strong>Variance Alert:</strong> Bank Deposit Net (<strong>৳ {{ formatAmount(netDepositedAmount) }}</strong>)
            does not match Calculated Batch Net (<strong>৳ {{ formatAmount(calculatedNet) }}</strong>).
            Difference is <strong>৳ {{ formatAmount(variance) }}</strong>.
          </div>
        </q-banner>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  itemCount: number;
  totalCod: number;
  totalCharges: number;
  calculatedNet: number;
  netDepositedAmount: number;
}>();

const variance = computed(() => {
  return Number((props.netDepositedAmount - props.calculatedNet).toFixed(2));
});

const isBalanced = computed(() => {
  return Math.abs(variance.value) < 0.01;
});

function formatAmount(val: number): string {
  return (val || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
</script>

<style scoped lang="scss">
.reconciliation-card {
  border-radius: 12px;
  background: var(--bw-theme-surface);
  border: 1px solid var(--bw-theme-border);
}

.stat-block {
  padding: 10px 14px;
  border-radius: 8px;
  background: rgba(0, 0, 0, 0.02);
  border: 1px solid var(--bw-theme-border);

  &.bg-primary-soft {
    background: var(--bw-theme-primary-soft, rgba(25, 118, 210, 0.08));
    border-color: rgba(25, 118, 210, 0.2);
  }
}

.border-red {
  border: 1px solid rgba(198, 40, 40, 0.3);
}
</style>
