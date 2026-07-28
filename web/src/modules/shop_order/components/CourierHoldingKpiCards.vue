<template>
  <div class="row q-col-gutter-md">
    <!-- Card 1: Total Gross COD Owed by Couriers -->
    <div class="col-12 col-md-4">
      <q-card flat bordered class="q-pa-md bg-surface border-base rounded-borders">
        <div class="row items-center justify-between no-wrap q-mb-xs">
          <span class="text-caption text-weight-medium text-grey-7">Owed by Couriers (COD)</span>
          <q-avatar size="32px" color="blue-1" text-color="primary" icon="account_balance_wallet" />
        </div>
        <div class="text-h5 text-weight-bold text-primary">
          ৳{{ formatCurrency(totals.grossCod) }}
        </div>
        <div class="text-caption text-grey-6 q-mt-xs">
          Across {{ totals.orderCount }} unremitted order{{ totals.orderCount === 1 ? '' : 's' }}
        </div>
      </q-card>
    </div>

    <!-- Card 2: Company Wholesale Share -->
    <div class="col-12 col-md-4">
      <q-card flat bordered class="q-pa-md bg-surface border-base rounded-borders">
        <div class="row items-center justify-between no-wrap q-mb-xs">
          <span class="text-caption text-weight-medium text-grey-7">Company Wholesale Share</span>
          <q-avatar size="32px" color="green-1" text-color="positive" icon="storefront" />
        </div>
        <div class="text-h5 text-weight-bold text-positive">
          ৳{{ formatCurrency(totals.companyWholesale) }}
        </div>
        <div class="text-caption text-grey-6 q-mt-xs">
          Base product cost & wholesale revenue
        </div>
      </q-card>
    </div>

    <!-- Card 3: Middleman Margin Liability -->
    <div class="col-12 col-md-4">
      <q-card flat bordered class="q-pa-md bg-surface border-base rounded-borders">
        <div class="row items-center justify-between no-wrap q-mb-xs">
          <span class="text-caption text-weight-medium text-grey-7">Middleman Margin (Locked)</span>
          <q-avatar size="32px" color="amber-1" text-color="warning" icon="lock" />
        </div>
        <div class="text-h5 text-weight-bold text-warning">
          ৳{{ formatCurrency(totals.middlemanMargin) }}
        </div>
        <div class="text-caption text-grey-6 q-mt-xs">
          Locked reseller profit pending courier deposit
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
interface Totals {
  grossCod: number;
  companyWholesale: number;
  middlemanMargin: number;
  orderCount: number;
}

defineProps<{
  totals: Totals;
}>();

function formatCurrency(val: number): string {
  return (val || 0).toLocaleString('en-BD', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
</script>

<style scoped>
.border-base {
  border: 1px solid var(--q-border-color, #e0e0e0);
}
.rounded-borders {
  border-radius: 8px;
}
</style>
