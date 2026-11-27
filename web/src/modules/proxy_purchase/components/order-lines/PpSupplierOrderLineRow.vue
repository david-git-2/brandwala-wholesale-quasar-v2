<template>
  <div class="pp-supplier-order-line-row">
    <div class="pp-supplier-order-line-row__grid">
      <div class="pp-supplier-order-line-row__cell pp-supplier-order-line-row__cell--product">
        <div class="pp-supplier-order-line-row__product row items-center">
          <div class="pp-supplier-order-line-row__thumb shrink-0">
            <q-img
              v-if="line.image_url?.trim()"
              :src="line.image_url"
              ratio="1"
              class="pp-supplier-order-line-row__thumb-img"
            />
            <div v-else class="pp-supplier-order-line-row__thumb-placeholder">
              <q-icon name="ph ph-image" size="16px" color="grey-6" aria-hidden="true" />
            </div>
          </div>
          <div class="col min-width-0">
            <div class="pp-supplier-order-line-row__title text-weight-medium">
              {{ titleLabel }}
            </div>
            <div class="pp-supplier-order-line-row__meta row items-center wrap">
              <span class="pp-supplier-order-line-row__id">#{{ line.id }}</span>
              <span v-if="line.url.trim()" class="pp-supplier-order-line-row__dot" aria-hidden="true">·</span>
              <TfBtn
                v-if="line.url.trim()"
                variant="link"
                size="sm"
                :label="linkLabel"
                icon="ph ph-arrow-square-out"
                class="pp-supplier-order-line-row__link"
                :aria-label="`Open product link for line ${line.id}`"
                @click="openPpOrderLineUrl(line.url)"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="pp-supplier-order-line-row__cell pp-supplier-order-line-row__cell--description">
        <div v-if="customerDescription" class="pp-supplier-order-line-row__description">
          {{ customerDescription }}
        </div>
        <span v-else class="pp-supplier-order-line-row__empty">—</span>
      </div>

      <div class="pp-supplier-order-line-row__cell pp-supplier-order-line-row__cell--store">
        <span v-if="storeLabel" class="pp-supplier-order-line-row__store-text">{{ storeLabel }}</span>
        <span v-else class="pp-supplier-order-line-row__empty">—</span>
      </div>

      <div
        class="pp-supplier-order-line-row__cell pp-supplier-order-line-row__cell--quantities tf-num"
        @click.stop
      >
        <div class="pp-supplier-order-line-row__qty-tier">
          <span class="pp-supplier-order-line-row__qty-tier-label">Customer</span>
          <q-input
            :model-value="line.needed_qty"
            type="number"
            dense
            borderless
            hide-bottom-space
            readonly
            input-class="font-mono text-center excel-cell-input-native"
            class="excel-cell-input excel-cell-input--qty-tint pp-supplier-order-line-row__qty-input"
            disable
          />
        </div>
        <div class="pp-supplier-order-line-row__qty-tier">
          <span class="pp-supplier-order-line-row__qty-tier-label">Ordered</span>
          <q-input
            :model-value="placedQtyDisplay"
            type="number"
            min="0"
            step="1"
            dense
            borderless
            hide-bottom-space
            placeholder="—"
            input-class="font-mono text-center excel-cell-input-native"
            class="excel-cell-input excel-cell-input--qty-tint pp-supplier-order-line-row__qty-input"
            :disable="updating || !canEditPlacedQty"
            @update:model-value="onPlacedQtyInput"
            @blur="savePlacedQty"
            @keydown.enter="(e) => (e.target as HTMLInputElement).blur()"
          />
        </div>
        <div class="pp-supplier-order-line-row__qty-tier">
          <span class="pp-supplier-order-line-row__qty-tier-label">Received</span>
          <q-input
            :model-value="receivedQtyDisplay"
            type="number"
            dense
            borderless
            hide-bottom-space
            placeholder="—"
            readonly
            input-class="font-mono text-center excel-cell-input-native"
            class="excel-cell-input excel-cell-input--qty-tint pp-supplier-order-line-row__qty-input"
            disable
          />
        </div>
      </div>

      <div class="pp-supplier-order-line-row__cell pp-supplier-order-line-row__cell--center pp-supplier-order-line-row__cell--price tf-num">
        {{ priceLabel }}
      </div>

      <div class="pp-supplier-order-line-row__cell pp-supplier-order-line-row__cell--tracking">
        <div class="pp-supplier-order-line-row__tracking-row">
          <span class="pp-supplier-order-line-row__tracking-text">{{ trackingLabel }}</span>
          <TfBtn
            v-if="trackingUrlOpenable"
            variant="icon"
            size="sm"
            icon="ph ph-arrow-square-out"
            class="pp-supplier-order-line-row__tracking-open shrink-0"
            :aria-label="`Open tracking link for line ${line.id}`"
            @click="openPpOrderLineUrl(trackingUrl)"
          />
        </div>
      </div>

      <div
        class="pp-supplier-order-line-row__cell pp-supplier-order-line-row__cell--center pp-supplier-order-line-row__cell--placement"
        @click.stop
      >
        <TfToneSelect
          :model-value="placementSelectValue"
          :options="placementOptions"
          :tone-class="placementCellClass"
          :disable="updating"
          :readonly="!canChangePlacement"
          aria-label="Fulfillment status"
          @update:model-value="onPlacementChange"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfToneSelect from 'src/components/ui/TfToneSelect.vue';
import { openPpOrderLineUrl, ppOrderLineHostLabel } from '../../utils/ppOrderLineUrl';
import {
  canSupplierChangePlacement,
  canSupplierEditPlacedQty,
  ppSupplierPlacementSelectOptions,
} from '../../utils/ppOrderLinePlacement';
import { ppPlacementCellClass } from '../../utils/ppOrderLineSelectTones';
import { buildPpSupplierOrderLineUpdate } from '../../utils/ppSupplierOrderLineUpdate';
import type {
  PpOrderLine,
  PpOrderLinePlacementStatus,
  PpSupplierOrderLineUpdatePayload,
} from '../../types/ppPurchaseRequest';

const props = withDefaults(
  defineProps<{
    line: PpOrderLine;
    updating?: boolean;
  }>(),
  { updating: false },
);

const emit = defineEmits<{
  patch: [payload: PpSupplierOrderLineUpdatePayload];
}>();

const placedQtyDraft = ref<number | null>(props.line.placed_qty);

watch(
  () => props.line.placed_qty,
  (value) => {
    placedQtyDraft.value = value;
  },
);

const placementOptions = computed(() => ppSupplierPlacementSelectOptions(props.line.placement_status));

const placementSelectValue = computed(
  (): PpOrderLinePlacementStatus =>
    props.line.placement_status === 'none' ? 'requested' : props.line.placement_status,
);

const canEditPlacedQty = computed(() => canSupplierEditPlacedQty(props.line.placement_status));
const canChangePlacement = computed(() => canSupplierChangePlacement(props.line.placement_status));

const hostLabel = computed(() => ppOrderLineHostLabel(props.line.url));
const storeLabel = computed(() => hostLabel.value);

const titleLabel = computed(() => {
  const name = props.line.product_name?.trim();
  if (name) return name;
  return hostLabel.value || '—';
});

const linkLabel = computed(() => {
  const host = hostLabel.value;
  if (!host) return 'View link';
  if (!props.line.product_name?.trim()) return 'View link';
  return host;
});

const priceLabel = computed(() => {
  const price = props.line.unit_price;
  if (price == null || Number.isNaN(Number(price))) return '—';
  return Number(price).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  });
});

const customerDescription = computed(() => props.line.description?.trim() || '');

const placedQtyDisplay = computed(() =>
  placedQtyDraft.value == null ? '' : placedQtyDraft.value,
);

const receivedQtyDisplay = computed(() =>
  props.line.received_qty == null ? '' : props.line.received_qty,
);

const parseOptionalQty = (value: string | number | null | undefined): number | null => {
  if (value === '' || value == null) return null;
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return n;
};

const onPlacedQtyInput = (value: string | number | null) => {
  placedQtyDraft.value = parseOptionalQty(value);
};

const savePlacedQty = () => {
  const next = placedQtyDraft.value;
  if (next != null && (!Number.isFinite(next) || next < 0)) {
    placedQtyDraft.value = props.line.placed_qty;
    return;
  }
  if (next === props.line.placed_qty) return;
  emit('patch', buildPpSupplierOrderLineUpdate(props.line, { placed_qty: next }));
};

const onPlacementChange = (value: string | number | null) => {
  if (typeof value !== 'string') return;
  const placement = value as PpOrderLinePlacementStatus;
  if (placement === props.line.placement_status) return;
  emit('patch', buildPpSupplierOrderLineUpdate(props.line, { placement_status: placement }));
};

const trackingUrl = computed(() => props.line.tracking_url?.trim() ?? '');
const trackingLabel = computed(() => trackingUrl.value || '—');
const trackingUrlOpenable = computed(() => trackingUrl.value.length > 0);

const placementCellClass = computed(() => ppPlacementCellClass(props.line.placement_status));
</script>

<style scoped>
.pp-supplier-order-line-row {
  min-width: 0;
}

.pp-supplier-order-line-row__grid {
  display: grid;
  grid-template-columns:
    minmax(15rem, 2.4fr)
    minmax(11rem, 1.2fr)
    minmax(6.5rem, 0.65fr)
    minmax(11rem, 1.25fr)
    4.25rem
    minmax(8.5rem, 0.85fr)
    minmax(6.75rem, 0.75fr);
  align-items: stretch;
  min-width: 0;
}

.pp-supplier-order-line-row__cell {
  min-width: 0;
  padding: 0.4rem 0.5rem;
  border-right: 1px solid var(--tf-neutral-border);
  font-size: 12px;
  color: var(--tf-neutral-ink);
  align-self: stretch;
  display: flex;
  align-items: center;
}

.pp-supplier-order-line-row__cell--center {
  justify-content: center;
  text-align: center;
}

.pp-supplier-order-line-row__cell:last-child {
  border-right: none;
}

.pp-supplier-order-line-row__cell--product {
  align-items: center;
}

.pp-supplier-order-line-row__product {
  gap: 0.5rem;
  width: 100%;
}

.pp-supplier-order-line-row__thumb {
  width: 1in;
  flex-shrink: 0;
}

.pp-supplier-order-line-row__thumb-img,
.pp-supplier-order-line-row__thumb-placeholder {
  width: 1in;
  height: 1in;
  border-radius: 4px;
  overflow: hidden;
  border: 1px solid var(--tf-neutral-border);
}

.pp-supplier-order-line-row__thumb-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--tf-disabled-bg);
}

.pp-supplier-order-line-row__thumb-placeholder .q-icon {
  font-size: 1.25rem;
}

.pp-supplier-order-line-row__title {
  line-height: 1.25;
  word-break: break-word;
}

.pp-supplier-order-line-row__meta {
  gap: 0.25rem;
  margin-top: 0.15rem;
  color: var(--tf-neutral-muted);
  font-size: 11px;
}

.pp-supplier-order-line-row__description,
.pp-supplier-order-line-row__store-text,
.pp-supplier-order-line-row__tracking-text {
  word-break: break-word;
}

.pp-supplier-order-line-row__empty {
  color: var(--tf-neutral-muted);
}

.pp-supplier-order-line-row__qty-tier {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 6px;
  min-width: 0;
}

.pp-supplier-order-line-row__qty-tier-label {
  flex: 0 0 4.5rem;
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--tf-neutral-muted);
  text-align: left;
  line-height: 1.2;
}

.pp-supplier-order-line-row__cell--quantities {
  flex-direction: column;
  justify-content: center;
  align-items: stretch;
  gap: 3px;
  padding-top: 0.35rem;
  padding-bottom: 0.35rem;
  padding-left: 0.2rem;
  padding-right: 0.2rem;
}

.pp-supplier-order-line-row__tracking-row {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  width: 100%;
  min-width: 0;
}

.pp-supplier-order-line-row__cell--placement {
  padding: 0;
  overflow: hidden;
}

.pp-supplier-order-line-row__qty-tier .pp-supplier-order-line-row__qty-input {
  flex: 1 1 auto;
  min-width: 0;
  width: auto;
}

.pp-supplier-order-line-row__qty-tier :deep(.q-field) {
  width: 100%;
}

.pp-supplier-order-line-row__cell--quantities :deep(.q-field__control) {
  min-height: 28px !important;
  height: 28px !important;
  padding: 0 4px !important;
  border-radius: 6px;
}

.pp-supplier-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control) {
  border: none !important;
  background-color: transparent !important;
  transition: background-color 0.1s ease-in-out, border-color 0.1s ease-in-out;
}

.pp-supplier-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control:before),
.pp-supplier-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

.pp-supplier-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint .q-field__control) {
  background-color: color-mix(in srgb, var(--tf-ops-hue-qty) 42%, var(--tf-neutral-surface)) !important;
}

.pp-supplier-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint:hover .q-field__control) {
  background-color: color-mix(in srgb, var(--tf-ops-hue-qty) 55%, var(--tf-neutral-surface)) !important;
}

.pp-supplier-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint.q-field--focused .q-field__control) {
  background-color: color-mix(in srgb, var(--tf-ops-hue-qty) 55%, var(--tf-neutral-surface)) !important;
  border: 1.5px solid var(--tf-ops-accent-qty) !important;
}

.pp-supplier-order-line-row__cell--quantities :deep(.excel-cell-input-native) {
  font-size: 12px;
  font-weight: 700;
  padding: 0 !important;
}
</style>