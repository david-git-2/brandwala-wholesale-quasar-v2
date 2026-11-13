<template>
  <div class="payment-leg-pot-cards">
    <div class="payment-leg-pot-cards__heading">
      <span class="payment-leg-pot-cards__leg">{{ legLabel }}</span>
      <span class="payment-leg-pot-cards__party">{{ partyName }}</span>
    </div>

    <div v-if="loading" class="payment-leg-pot-cards__loading">
      <div class="payment-leg-pot-cards__grid">
        <q-skeleton
          v-for="n in 2"
          :key="n"
          type="rect"
          height="96px"
          class="payment-leg-pot-cards__skeleton"
        />
      </div>
      <span class="payment-leg-pot-cards__loading-text">Loading accounts…</span>
    </div>

    <div v-else-if="!pointGroups.length" class="payment-leg-pot-cards__empty">
      No cash points for this party yet.
    </div>

    <div v-else class="payment-leg-pot-cards__grid" role="listbox" :aria-label="legLabel">
      <section
        v-for="group in pointGroups"
        :key="group.pointId"
        class="payment-leg-pot-cards__point"
        :class="{
          'payment-leg-pot-cards__point--active': selectedPointId === group.pointId,
        }"
      >
        <div class="payment-leg-pot-cards__point-name">
          {{ group.pointName }}
        </div>
        <div
          class="payment-leg-pot-cards__pots"
          role="group"
          :aria-label="`${group.pointName} balances`"
        >
          <button
            v-for="pot in group.pots"
            :key="pot.value"
            type="button"
            role="option"
            :aria-selected="modelValue === pot.value"
            class="payment-leg-pot-cards__pot"
            :class="{ 'payment-leg-pot-cards__pot--selected': modelValue === pot.value }"
            @click="emit('update:modelValue', pot.value)"
          >
            <span class="payment-leg-pot-cards__pot-currency">{{ pot.currencyCode }}</span>
            <span class="payment-leg-pot-cards__pot-balance tf-num">{{ potBalance(pot) }}</span>
          </button>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { CashbookLegPotChipOption } from '../composables/useCashbookLegPots';

const props = defineProps<{
  legLabel: string;
  partyName: string;
  options: CashbookLegPotChipOption[];
  modelValue: number | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: number];
}>();

type PointGroup = {
  pointId: number;
  pointName: string;
  pots: CashbookLegPotChipOption[];
};

const pointGroups = computed((): PointGroup[] => {
  const byPoint = new Map<number, PointGroup>();
  for (const opt of props.options) {
    const pointId = opt.pointId;
    let group = byPoint.get(pointId);
    if (!group) {
      const name = opt.pointName?.trim() || 'Location';
      group = { pointId, pointName: name, pots: [] };
      byPoint.set(pointId, group);
    }
    group.pots.push(opt);
  }
  for (const group of byPoint.values()) {
    group.pots.sort((a, b) => a.currencyCode.localeCompare(b.currencyCode));
  }
  return [...byPoint.values()].sort((a, b) =>
    a.pointName.localeCompare(b.pointName),
  );
});

const selectedPointId = computed(() => {
  const id = props.modelValue;
  if (id == null) return null;
  const opt = props.options.find((o) => o.value === id);
  return opt?.pointId ?? null;
});

function potBalance(opt: CashbookLegPotChipOption): string {
  if (opt.balanceDisplay?.trim()) {
    const parts = opt.balanceDisplay.split(/\s+/);
    return parts.length > 1 ? parts.slice(1).join(' ') : opt.balanceDisplay;
  }
  const parts = opt.label.split(' · ');
  return parts.length > 1 ? parts.slice(1).join(' · ') : '0.00';
}
</script>

<style scoped lang="scss">
.payment-leg-pot-cards__heading {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--tf-space-md, 12px);
  margin-bottom: 10px;
}

.payment-leg-pot-cards__leg {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text, #5b6b80);
  flex-shrink: 0;
}

.payment-leg-pot-cards__party {
  font-size: 12px;
  font-weight: 500;
  color: var(--tf-neutral-muted, #64748b);
  text-align: right;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.payment-leg-pot-cards__grid {
  display: flex;
  flex-direction: column;
  gap: var(--tf-space-sm, 8px);
}

.payment-leg-pot-cards__skeleton {
  border-radius: var(--tf-radius-sm, 8px);
}

.payment-leg-pot-cards__loading-text {
  display: block;
  margin-top: 6px;
  font-size: 12px;
  color: var(--tf-neutral-muted, #475569);
}

.payment-leg-pot-cards__empty {
  font-size: 12px;
  color: var(--tf-neutral-muted, #475569);
}

.payment-leg-pot-cards__point {
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
  border-radius: var(--tf-radius-sm, 8px);
  background: var(--tf-neutral-surface, #fff);
  padding: 12px 14px;
  transition:
    border-color var(--tf-dur-fast, 0.12s) var(--tf-ease, ease),
    background-color var(--tf-dur-fast, 0.12s) var(--tf-ease, ease);

  &--active {
    border-width: 2px;
    padding: 11px 13px;
    border-color: var(--tf-theme-primary, #0d6b5c);
    background: color-mix(
      in srgb,
      var(--tf-theme-primary, #0d6b5c) 6%,
      var(--tf-neutral-surface, #fff)
    );
  }
}

.payment-leg-pot-cards__point-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--tf-neutral-ink, #0f172a);
  line-height: 1.35;
  margin-bottom: 10px;
}

.payment-leg-pot-cards__pots {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.payment-leg-pot-cards__pot {
  appearance: none;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
  min-width: 0;
  margin: 0;
  padding: 8px 12px;
  cursor: pointer;
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
  border-radius: var(--tf-radius-sm, 8px);
  background: var(--tf-neutral-canvas, #f8fafc);
  text-align: left;
  transition:
    border-color var(--tf-dur-fast, 0.12s) var(--tf-ease, ease),
    background-color var(--tf-dur-fast, 0.12s) var(--tf-ease, ease);

  &:hover {
    border-color: var(--tf-neutral-border-strong, #cbd5e1);
  }

  &--selected {
    border-color: var(--tf-theme-primary, #0d6b5c);
    background: color-mix(
      in srgb,
      var(--tf-theme-primary, #0d6b5c) 12%,
      var(--tf-neutral-surface, #fff)
    );
    box-shadow: inset 0 0 0 1px var(--tf-theme-primary, #0d6b5c);
  }
}

.payment-leg-pot-cards__pot-currency {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted, #64748b);
}

.payment-leg-pot-cards__pot-balance {
  font-size: 13px;
  font-weight: 600;
  color: var(--tf-neutral-ink, #0f172a);
}
</style>
