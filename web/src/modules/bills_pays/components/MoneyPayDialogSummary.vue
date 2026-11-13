<template>
  <div v-if="visible" class="money-pay-dialog-summary">
    <div class="money-pay-dialog-summary__top">
      <div class="money-pay-dialog-summary__due-block">
        <div class="money-pay-dialog-summary__overline">Due on Bill</div>
        <div v-if="dueDisplay" class="money-pay-dialog-summary__due font-mono tf-num">
          {{ dueDisplay }}
        </div>
      </div>
      <span
        v-if="context?.modeCaption"
        class="money-pay-dialog-summary__mode-badge"
      >
        {{ context.modeCaption }}
      </span>
    </div>

    <div
      v-if="context?.payerName || context?.payeeName"
      class="money-pay-dialog-summary__parties"
    >
      <div
        v-if="context?.payerName"
        class="money-pay-dialog-summary__party money-pay-dialog-summary__party--payer"
      >
        <div class="money-pay-dialog-summary__party-label">Payer</div>
        <div class="money-pay-dialog-summary__party-name">{{ context.payerName }}</div>
      </div>

      <div
        v-if="context?.payeeName"
        class="money-pay-dialog-summary__party money-pay-dialog-summary__party--payee"
      >
        <div class="money-pay-dialog-summary__party-label">Payee</div>
        <div class="money-pay-dialog-summary__party-name">{{ context.payeeName }}</div>
      </div>
    </div>

    <p v-if="context?.headline" class="money-pay-dialog-summary__headline q-mt-sm q-mb-none">
      {{ context.headline }}
    </p>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { MoneyPaySummaryContext } from '../types/moneyPayDialog';

const props = defineProps<{
  visible: boolean;
  context?: MoneyPaySummaryContext | null;
}>();

const dueDisplay = computed(() => {
  const c = props.context;
  const due = c?.dueAmount;
  if (due == null || !Number.isFinite(due)) return null;
  const code = (c?.dueCurrencyCode ?? 'BDT').trim() || 'BDT';
  return formatSettlementCurrencyAmount(due, code);
});
</script>

<style scoped lang="scss">
.money-pay-dialog-summary {
  width: 100%;
  padding: var(--tf-space-md, 16px) var(--tf-space-lg, 18px);
  border-radius: var(--tf-radius-sm, 8px);
  background: color-mix(
    in srgb,
    var(--tf-theme-primary, #0d6b5c) 6%,
    var(--tf-neutral-canvas, #f8fafc)
  );
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
  box-sizing: border-box;
}

.money-pay-dialog-summary__top {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--tf-space-md, 12px);
}

.money-pay-dialog-summary__due-block {
  min-width: 0;
}

.money-pay-dialog-summary__overline {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text, #5b6b80);
}

.money-pay-dialog-summary__due {
  font-size: 1.5rem;
  font-weight: 700;
  line-height: 1.15;
  color: var(--tf-neutral-ink, #0f172a);
  margin-top: 4px;
}

.money-pay-dialog-summary__mode-badge {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  padding: 4px 10px;
  border-radius: var(--tf-radius-sm, 8px);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
  color: var(--tf-neutral-muted, #475569);
  background: var(--tf-neutral-surface, #fff);
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
}

.money-pay-dialog-summary__parties {
  display: flex;
  justify-content: space-between;
  gap: var(--tf-space-lg, 20px);
  margin-top: var(--tf-space-md, 14px);
  padding-top: var(--tf-space-md, 14px);
  border-top: 1px solid color-mix(in srgb, var(--tf-neutral-border, #e2e8f0) 85%, transparent);
}

.money-pay-dialog-summary__party {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex: 1;
}

.money-pay-dialog-summary__party--payee {
  align-items: flex-end;
  text-align: right;
}

.money-pay-dialog-summary__party-label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text, #5b6b80);
  line-height: 1.2;
}

.money-pay-dialog-summary__party-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--tf-neutral-ink, #0f172a);
  line-height: 1.35;
  word-break: break-word;
}

.money-pay-dialog-summary__headline {
  font-size: 13px;
  color: var(--tf-neutral-muted, #475569);
}

@media (max-width: 479px) {
  .money-pay-dialog-summary__parties {
    flex-direction: column;
    gap: var(--tf-space-sm, 10px);
  }

  .money-pay-dialog-summary__party--payee {
    align-items: flex-start;
    text-align: left;
  }
}
</style>
