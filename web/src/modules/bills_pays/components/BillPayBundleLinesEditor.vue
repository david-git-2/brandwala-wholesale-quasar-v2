<template>
  <div class="bill-pay-bundle-lines">
    <div class="row items-center justify-between q-mb-sm">
      <div class="text-caption text-weight-bold text-uppercase text-grey-7">
        Pay from bundles
      </div>
      <TfBtn
        variant="secondary"
        size="sm"
        icon="ph ph-plus"
        label="Add bundle"
        :disable="!canAddLine"
        data-test="bill-pay-add-bundle-line"
        @click="emit('add-line')"
      />
    </div>

    <div class="bill-pay-bundle-lines__table-wrap">
      <table class="bill-pay-bundle-lines__table" data-test="bill-pay-bundle-table">
        <thead>
          <tr>
            <th scope="col" class="bill-pay-bundle-lines__th bill-pay-bundle-lines__th--num">#</th>
            <th scope="col" class="bill-pay-bundle-lines__th">Bundle</th>
            <th scope="col" class="bill-pay-bundle-lines__th bill-pay-bundle-lines__th--avail">Available</th>
            <th scope="col" class="bill-pay-bundle-lines__th bill-pay-bundle-lines__th--amount">Pay amount</th>
            <th scope="col" class="bill-pay-bundle-lines__th bill-pay-bundle-lines__th--action" aria-label="Actions" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(line, index) in lines"
            :key="line.id"
            :data-test="`bill-pay-bundle-line-${index}`"
          >
            <td class="bill-pay-bundle-lines__td bill-pay-bundle-lines__td--num text-grey-7">
              {{ index + 1 }}
            </td>
            <td class="bill-pay-bundle-lines__td">
              <q-select
                :model-value="line.bundleId"
                :options="bundleSelectOptions(line.bundleId)"
                emit-value
                map-options
                outlined
                dense
                hide-bottom-space
                class="bill-pay-bundle-lines__field"
                :error="showBundleError(line)"
                data-test="bill-pay-bundle-select"
                @update:model-value="(v) => emit('update-line', line.id, { bundleId: v != null ? Number(v) : null })"
              />
            </td>
            <td class="bill-pay-bundle-lines__td bill-pay-bundle-lines__td--avail tf-num text-grey-7">
              <span v-if="line.bundleId != null && lineAvailable(line.bundleId) != null">
                {{ formatAvail(line.bundleId) }}
              </span>
              <span v-else>—</span>
            </td>
            <td class="bill-pay-bundle-lines__td bill-pay-bundle-lines__td--amount">
              <q-input
                :model-value="line.amount"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                hide-bottom-space
                class="bill-pay-bundle-lines__field bill-pay-bundle-lines__field--amount"
                :prefix="currencyCode"
                :error="showAmountError(line)"
                @update:model-value="(v) => emit('update-line', line.id, { amount: parseAmount(v) })"
              />
            </td>
            <td class="bill-pay-bundle-lines__td bill-pay-bundle-lines__td--action">
              <TfBtn
                variant="icon"
                size="sm"
                icon="ph ph-trash"
                aria-label="Remove line"
                :disable="lines.length <= 1"
                @click="emit('remove-line', line.id)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="row items-center justify-between q-mt-sm">
      <span class="text-caption text-grey-7">
        Total paying now
      </span>
      <span class="text-body2 text-weight-medium tf-num">
        {{ totalAmount.toFixed(2) }} {{ currencyCode }}
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { CashbookLegPotChipOption } from '../composables/useCashbookLegPots';
import type { BillPayBundleLineDraft } from '../composables/useBillPayBundleLines';

const props = defineProps<{
  lines: BillPayBundleLineDraft[];
  bundleOptions: CashbookLegPotChipOption[];
  currencyCode: string;
  totalAmount: number;
  canAddLine: boolean;
  usedBundleIds: Set<number>;
  lineAvailable: (bundleId: number | null) => number | null;
  showAmountError: (line: BillPayBundleLineDraft) => boolean;
  showBundleError: (line: BillPayBundleLineDraft) => boolean;
  parseAmount: (v: unknown) => number | null;
}>();

const emit = defineEmits<{
  'add-line': [];
  'remove-line': [id: string];
  'update-line': [id: string, patch: Partial<Pick<BillPayBundleLineDraft, 'bundleId' | 'amount'>>];
}>();

function bundleSelectLabel(o: CashbookLegPotChipOption): string {
  const loc = o.pointName?.trim() || 'Location';
  const bal = o.balanceDisplay?.trim() || `${o.currencyCode} ${o.amount}`;
  const rate = o.booksRate != null ? Number(o.booksRate) : null;
  if (rate != null && Number.isFinite(rate) && rate > 0) {
    return `${loc} · ${bal} · rate ${rate}`;
  }
  return `${loc} · ${bal}`;
}

function bundleSelectOptions(currentBundleId: number | null) {
  return props.bundleOptions
    .filter(
      (o) =>
        o.value === currentBundleId
        || !props.usedBundleIds.has(o.value),
    )
    .sort((a, b) => b.value - a.value)
    .map((o) => ({
      label: bundleSelectLabel(o),
      value: o.value,
    }));
}

function formatAvail(bundleId: number) {
  const avail = props.lineAvailable(bundleId);
  if (avail == null) return '—';
  return avail.toFixed(2);
}
</script>

<style scoped>
.bill-pay-bundle-lines__table-wrap {
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
  overflow: auto;
}

.bill-pay-bundle-lines__table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.bill-pay-bundle-lines__th {
  text-align: left;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-chrome-text);
  padding: 6px 8px;
  border-bottom: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-chrome-bg, var(--tf-neutral-surface));
}

.bill-pay-bundle-lines__td {
  padding: 6px 8px;
  vertical-align: middle;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.bill-pay-bundle-lines__td--num {
  width: 2rem;
}

.bill-pay-bundle-lines__td--avail {
  width: 6rem;
  text-align: right;
}

.bill-pay-bundle-lines__td--amount {
  width: 10rem;
}

.bill-pay-bundle-lines__td--action {
  width: 2.5rem;
}

.bill-pay-bundle-lines__field {
  min-width: 12rem;
}

.bill-pay-bundle-lines__field--amount {
  min-width: 8rem;
}
</style>