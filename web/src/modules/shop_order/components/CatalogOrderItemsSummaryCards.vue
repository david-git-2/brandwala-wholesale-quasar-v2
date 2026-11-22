<template>
  <CostingTotalsSummaryCards
    :item-count="itemCount"
    :buy-currency-symbol="buyCurrencySymbol"
    :sell-currency-symbol="sellCurrencySymbol"
    :conversion-rate="conversionRate"
    :cargo-rate="cargoRate"
    :totals="totals"
  />
</template>

<script setup lang="ts">
import CostingTotalsSummaryCards from 'src/components/ui/CostingTotalsSummaryCards.vue';
import type { CostingTotalsSummary } from 'src/types/costingTotalsSummary';

defineProps<{
  itemCount: number;
  buyCurrencySymbol: string;
  sellCurrencySymbol: string;
  conversionRate: number;
  cargoRate: number;
  totals: CostingTotalsSummary;
}>();
</script>