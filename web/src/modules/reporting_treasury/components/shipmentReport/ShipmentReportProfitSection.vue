<template>
  <ShipmentReportSectionShell :title="sectionTitle">
    <template v-if="variant === 'hero'">
      <div class="q-mb-md">
        <ShipmentReportStatTile
          label="Gross profit"
          :value="formatMoney(matrix.profit_loss_bdt, 'BDT')"
          :hint="`${matrix.profit_loss_pct}% margin`"
          emphasis="hero"
          :tone="profitTone"
        />
      </div>
      <div class="row q-col-gutter-md q-mb-sm">
        <div class="col-12 col-sm-6">
          <ShipmentReportStatTile
            label="Total cost"
            :value="formatMoney(matrix.total_cost_bdt, 'BDT')"
          />
          <div v-if="matrix.total_cost_by_currency.length" class="row q-gutter-xs q-mt-sm">
            <q-chip
              v-for="c in matrix.total_cost_by_currency"
              :key="c.currency_code"
              dense
              size="sm"
              class="tf-num"
            >
              {{ formatMoney(c.amount, c.currency_code) }}
            </q-chip>
          </div>
        </div>
        <div class="col-12 col-sm-6">
          <ShipmentReportStatTile
            label="Total sell"
            :value="formatMoney(matrix.total_sell_bdt, 'BDT')"
          />
        </div>
      </div>
    </template>

    <template v-else>
      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-4">
          <ShipmentReportStatTile
            label="Total cost"
            :value="formatMoney(matrix.total_cost_bdt, 'BDT')"
          />
          <div v-if="matrix.total_cost_by_currency.length" class="row q-gutter-xs q-mt-xs">
            <q-chip
              v-for="c in matrix.total_cost_by_currency"
              :key="c.currency_code"
              dense
              size="sm"
              class="tf-num"
            >
              {{ formatMoney(c.amount, c.currency_code) }}
            </q-chip>
          </div>
        </div>
        <div class="col-12 col-sm-4">
          <ShipmentReportStatTile
            label="Total sell"
            :value="formatMoney(matrix.total_sell_bdt, 'BDT')"
          />
        </div>
        <div class="col-12 col-sm-4">
          <ShipmentReportStatTile
            label="Gross profit"
            :value="formatMoney(matrix.profit_loss_bdt, 'BDT')"
            :hint="`${matrix.profit_loss_pct}% margin`"
            :emphasis="profitTone"
          />
        </div>
      </div>
    </template>

    <q-list
      v-if="secondaryLines.length"
      dense
      class="q-mt-md q-pt-sm shipment-profit-secondary"
    >
      <q-item v-for="line in secondaryLines" :key="line.key" dense class="q-px-none">
        <q-item-section>{{ line.label }}</q-item-section>
        <q-item-section side class="tf-num text-weight-medium">
          {{ formatMoney(line.amount, 'BDT') }}
        </q-item-section>
      </q-item>
    </q-list>
  </ShipmentReportSectionShell>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { ShipmentReportProfitMatrix } from '../../types/shipmentReportDetailTypes';
import ShipmentReportSectionShell from './ShipmentReportSectionShell.vue';
import ShipmentReportStatTile from './ShipmentReportStatTile.vue';

const props = withDefaults(
  defineProps<{
    matrix: ShipmentReportProfitMatrix;
    warehouseValueBdt: number;
    variant?: 'hero' | 'card';
  }>(),
  {
    variant: 'hero',
  },
);

const sectionTitle = computed(() =>
  props.variant === 'hero' ? 'Profit & loss' : 'Profit',
);

const profitTone = computed((): 'positive' | 'negative' =>
  props.matrix.profit_loss_bdt >= 0 ? 'positive' : 'negative',
);

function formatMoney(amount: number | null | undefined, currencyCode: string) {
  return formatSettlementCurrencyAmount(amount, currencyCode);
}

const secondaryLines = computed(() => {
  const lines: { key: string; label: string; amount: number }[] = [];
  if (props.matrix.receive_loss_bdt > 0.009) {
    lines.push({ key: 'loss', label: 'Receive loss (info)', amount: props.matrix.receive_loss_bdt });
  }
  if (props.warehouseValueBdt > 0.009) {
    lines.push({ key: 'wh', label: 'Warehouse value', amount: props.warehouseValueBdt });
  }
  if (props.matrix.unpaid_total_bdt > 0.009) {
    lines.push({ key: 'unpaid', label: 'Customers still owed', amount: props.matrix.unpaid_total_bdt });
  }
  return lines;
});
</script>

<style scoped>
.shipment-profit-secondary {
  border-top: 1px solid var(--tf-neutral-border);
}
</style>