<template>
  <div class="payment-leg-location-picker">
    <div class="payment-leg-location-picker__heading">
      <span class="payment-leg-location-picker__leg">{{ legLabel }}</span>
      <span class="payment-leg-location-picker__party">{{ partyName }}</span>
    </div>

    <div v-if="loading" class="payment-leg-location-picker__loading">
      <q-skeleton type="rect" height="40px" class="q-mb-sm" />
      <q-skeleton type="rect" height="56px" />
      <span class="payment-leg-location-picker__loading-text">Loading cash…</span>
    </div>

    <div v-else-if="!displaySections.length" class="payment-leg-location-picker__empty">
      No matching locations for this bill currency.
    </div>

    <template v-else>
      <BillDialogField label="Location">
        <q-select
          v-model="locationPointId"
          outlined
          dense
          emit-value
          map-options
          :options="locationOptions"
          hide-bottom-space
          data-test="money-pay-location-select"
        />
      </BillDialogField>

      <div
        v-if="locationPointId != null"
        class="payment-leg-location-picker__bundles q-mt-md"
      >
        <div class="payment-leg-location-picker__bundles-label">
          Bundle
        </div>

        <div
          v-if="!bundlesAtLocation.length"
          class="payment-leg-location-picker__empty"
        >
          No matching bundles at this location.
        </div>

        <div
          v-else
          class="payment-leg-location-picker__pots"
          role="listbox"
          aria-label="Bundle"
        >
          <button
            v-for="pot in bundlesAtLocation"
            :key="pot.value"
            type="button"
            role="option"
            :aria-selected="modelValue === pot.value"
            class="payment-leg-location-picker__pot"
            :class="{
              'payment-leg-location-picker__pot--selected': modelValue === pot.value,
            }"
            data-test="money-pay-bundle-option"
            @click="emit('update:modelValue', pot.value)"
          >
            <span class="payment-leg-location-picker__pot-currency">
              {{ pot.currencyCode }}
            </span>
            <span class="payment-leg-location-picker__pot-balance tf-num">
              {{ potBalance(pot) }}
            </span>
            <span
              v-if="booksRateLabel(pot)"
              class="payment-leg-location-picker__pot-rate text-caption"
            >
              {{ booksRateLabel(pot) }}
            </span>
            <span
              v-if="pot.drawerGroup?.trim()"
              class="payment-leg-location-picker__pot-group text-caption"
            >
              {{ pot.drawerGroup }}
            </span>
          </button>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import BillDialogField from './BillDialogField.vue';
import type {
  CashbookLegLocationSection,
  CashbookLegPotChipOption,
} from '../composables/useCashbookLegPots';

const props = defineProps<{
  legLabel: string;
  partyName: string;
  options: CashbookLegPotChipOption[];
  sections?: CashbookLegLocationSection[];
  modelValue: number | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: number | null];
}>();

type PointGroup = {
  pointId: number;
  pointName: string;
  pots: CashbookLegPotChipOption[];
};

const fallbackSections = computed((): PointGroup[] => {
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
  return [...byPoint.values()].sort((a, b) => a.pointName.localeCompare(b.pointName));
});

const displaySections = computed(() =>
  props.sections?.length ? props.sections : fallbackSections.value,
);

const locationOptions = computed(() =>
  displaySections.value.map((s) => ({
    label: s.pointName,
    value: s.pointId,
  })),
);

const locationPointId = ref<number | null>(null);

const bundlesAtLocation = computed((): CashbookLegPotChipOption[] => {
  const pointId = locationPointId.value;
  if (pointId == null) return [];
  const section = displaySections.value.find((s) => s.pointId === pointId);
  return section?.pots ?? [];
});

function pointIdForPot(potId: number | null): number | null {
  if (potId == null) return null;
  return props.options.find((o) => o.value === potId)?.pointId ?? null;
}

function pickBundleForLocation(pointId: number, preferredPotId: number | null): number | null {
  const section = displaySections.value.find((s) => s.pointId === pointId);
  const pots = section?.pots ?? [];
  if (!pots.length) return null;
  if (preferredPotId != null && pots.some((p) => p.value === preferredPotId)) {
    return preferredPotId;
  }
  return pots[0]?.value ?? null;
}

function syncLocationFromSelection() {
  const sections = displaySections.value;
  if (!sections.length) {
    locationPointId.value = null;
    return;
  }
  const fromPot = pointIdForPot(props.modelValue);
  if (fromPot != null && sections.some((s) => s.pointId === fromPot)) {
    locationPointId.value = fromPot;
    return;
  }
  if (
    locationPointId.value != null
    && sections.some((s) => s.pointId === locationPointId.value)
  ) {
    return;
  }
  locationPointId.value = sections[0].pointId;
}

watch(
  [displaySections, () => props.modelValue],
  () => {
    syncLocationFromSelection();
  },
  { immediate: true },
);

watch(locationPointId, (pointId, prevPointId) => {
  if (pointId == null) {
    if (props.modelValue != null) emit('update:modelValue', null);
    return;
  }
  if (pointId === prevPointId && pointIdForPot(props.modelValue) === pointId) {
    return;
  }
  const next = pickBundleForLocation(pointId, props.modelValue);
  if (next !== props.modelValue) {
    emit('update:modelValue', next);
  }
});

function potBalance(opt: CashbookLegPotChipOption): string {
  if (opt.balanceDisplay?.trim()) {
    const parts = opt.balanceDisplay.split(/\s+/);
    return parts.length > 1 ? parts.slice(1).join(' ') : opt.balanceDisplay;
  }
  const parts = opt.label.split(' · ');
  return parts.length > 1 ? parts.slice(1).join(' · ') : '0.00';
}

function booksRateLabel(opt: CashbookLegPotChipOption): string | null {
  const rate = opt.booksRate;
  if (rate == null || !Number.isFinite(rate)) return null;
  if (Math.abs(rate - 1) < 0.0001) return null;
  return `@ ${rate}`;
}
</script>

<style scoped lang="scss">
.payment-leg-location-picker__heading {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--tf-space-md, 12px);
  margin-bottom: 10px;
}

.payment-leg-location-picker__leg {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text, #5b6b80);
  flex-shrink: 0;
}

.payment-leg-location-picker__party {
  font-size: 12px;
  font-weight: 500;
  color: var(--tf-neutral-muted, #64748b);
  text-align: right;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.payment-leg-location-picker__loading-text {
  display: block;
  margin-top: 6px;
  font-size: 12px;
  color: var(--tf-neutral-muted, #475569);
}

.payment-leg-location-picker__empty {
  font-size: 12px;
  color: var(--tf-neutral-muted, #475569);
}

.payment-leg-location-picker__bundles-label {
  margin-bottom: 8px;
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-ink, #171412);
}

.payment-leg-location-picker__pots {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.payment-leg-location-picker__pot {
  appearance: none;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
  min-width: 6.5rem;
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

.payment-leg-location-picker__pot-currency {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted, #64748b);
}

.payment-leg-location-picker__pot-balance {
  font-size: 13px;
  font-weight: 600;
  color: var(--tf-neutral-ink, #0f172a);
}

.payment-leg-location-picker__pot-rate,
.payment-leg-location-picker__pot-group {
  color: var(--tf-neutral-muted, #64748b);
  line-height: 1.2;
}
</style>
