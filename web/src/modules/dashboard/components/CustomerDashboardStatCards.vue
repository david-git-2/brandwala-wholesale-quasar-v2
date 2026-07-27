<template>
  <div class="row q-col-gutter-md">
    <div class="col-12 col-sm-4">
      <q-card flat bordered class="stat-card q-pa-md">
        <div class="row items-center justify-between no-wrap">
          <div>
            <div class="text-caption text-grey-6 text-uppercase text-weight-bold">{{ $t('customer_dashboard.kpi_active_shops') }}</div>
            <div class="text-h5 text-weight-bold text-grey-9 q-mt-xs">{{ activeShopsCount }}</div>
          </div>
          <q-avatar color="blue-1" text-color="blue-7" icon="ph ph-storefront" size="44px" />
        </div>
      </q-card>
    </div>

    <div class="col-12 col-sm-4">
      <q-card flat bordered class="stat-card q-pa-md">
        <div class="row items-center justify-between no-wrap">
          <div>
            <div class="text-caption text-grey-6 text-uppercase text-weight-bold">{{ $t('customer_dashboard.kpi_recent_orders') }}</div>
            <div class="text-h5 text-weight-bold text-grey-9 q-mt-xs">{{ recentOrdersCount }}</div>
          </div>
          <q-avatar color="green-1" text-color="green-7" icon="ph ph-tote" size="44px" />
        </div>
      </q-card>
    </div>

    <div class="col-12 col-sm-4">
      <q-card flat bordered class="stat-card q-pa-md">
        <div class="row items-center justify-between no-wrap">
          <div>
            <div class="text-caption text-grey-6 text-uppercase text-weight-bold">{{ $t('customer_dashboard.kpi_active_value') }}</div>
            <div class="text-h5 text-weight-bold text-primary q-mt-xs">
              {{ currencySymbol }}{{ totalOutlay.toFixed(2) }}
            </div>
          </div>
          <q-avatar color="indigo-1" text-color="indigo-7" icon="ph ph-receipt" size="44px" />
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  activeShopsCount: number;
  recentOrdersCount: number;
  totalOutlay: number;
  currencySymbol: string;
}>();
</script>

<style scoped>
.stat-card {
  border-radius: 10px;
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
}
</style>
