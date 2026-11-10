<template>
  <div class="kpi-strip">
    <div class="row q-col-gutter-md items-stretch">
      <div class="col-12 col-sm-4">
        <div class="kpi-tile">
          <div class="kpi-label">Total cost</div>
          <div class="kpi-value tf-num">{{ formatMoney(matrix.total_cost_bdt, 'BDT') }}</div>
          <div v-if="matrix.total_cost_by_currency.length" class="row q-gutter-xs q-mt-xs">
            <q-chip
              v-for="c in matrix.total_cost_by_currency"
              :key="c.currency_code"
              dense
              size="sm"
              class="kpi-chip tf-num"
            >
              {{ formatMoney(c.amount, c.currency_code) }}
            </q-chip>
          </div>
        </div>
      </div>
      <div class="col-12 col-sm-4">
        <div class="kpi-tile">
          <div class="kpi-label">Total sell</div>
          <div class="kpi-value tf-num text-primary">
            {{ formatMoney(matrix.total_sell_bdt, 'BDT') }}
          </div>
        </div>
      </div>
      <div class="col-12 col-sm-4">
        <div class="kpi-tile">
          <div class="kpi-label">Profit / loss</div>
          <div
            class="kpi-value tf-num"
            :class="matrix.profit_loss_bdt >= 0 ? 'text-positive' : 'text-negative'"
          >
            {{ formatMoney(matrix.profit_loss_bdt, 'BDT') }}
          </div>
          <q-badge
            dense
            rounded
            class="q-mt-xs text-weight-bold"
            :color="matrix.profit_loss_pct >= 0 ? 'green-1' : 'red-1'"
            :text-color="matrix.profit_loss_pct >= 0 ? 'green-9' : 'red-9'"
          >
            {{ matrix.profit_loss_pct }}% margin
          </q-badge>
        </div>
      </div>
    </div>
    <div v-if="secondaryChips.length" class="row q-gutter-xs q-mt-sm">
      <q-chip
        v-for="chip in secondaryChips"
        :key="chip.key"
        dense
        size="sm"
        :color="chip.color"
        :text-color="chip.textColor"
        class="tf-num"
      >
        {{ chip.label }}: {{ formatMoney(chip.amount, 'BDT') }}
      </q-chip>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { ShipmentReportProfitMatrix } from '../types/shipmentReportDetailTypes';

const props = defineProps<{
  matrix: ShipmentReportProfitMatrix;
  warehouseValueBdt: number;
}>();

function formatMoney(amount: number | null | undefined, currencyCode: string) {
  return formatSettlementCurrencyAmount(amount, currencyCode);
}

const secondaryChips = computed(() => {
  const chips: {
    key: string;
    label: string;
    amount: number;
    color?: string;
    textColor?: string;
  }[] = [];
  if (props.matrix.receive_loss_bdt > 0.009) {
    chips.push({
      key: 'loss',
      label: 'Receive loss',
      amount: props.matrix.receive_loss_bdt,
      color: 'orange-1',
      textColor: 'orange-10',
    });
  }
  if (props.warehouseValueBdt > 0.009) {
    chips.push({
      key: 'wh',
      label: 'Warehouse value',
      amount: props.warehouseValueBdt,
    });
  }
  if (props.matrix.unpaid_total_bdt > 0.009) {
    chips.push({
      key: 'unpaid',
      label: 'Customers not paid',
      amount: props.matrix.unpaid_total_bdt,
      color: 'red-1',
      textColor: 'red-9',
    });
  }
  return chips;
});
</script>

<style scoped>
.kpi-strip {
  width: 100%;
}

.kpi-tile {
  background: var(--tf-neutral-surface);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
  padding: 10px 12px;
  height: 100%;
}

.kpi-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-muted);
  margin-bottom: 4px;
}

.kpi-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
  line-height: 1.2;
}

.kpi-chip {
  background: var(--tf-neutral-chrome);
  color: var(--tf-neutral-ink);
}
</style>
