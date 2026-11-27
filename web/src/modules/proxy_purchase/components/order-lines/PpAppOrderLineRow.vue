<template>
  <div class="pp-app-order-line-row">
    <div class="pp-app-order-line-row__grid">
      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--select">
        <q-checkbox
          dense
          :model-value="selected"
          :aria-label="`Select line ${line.id}`"
          @update:model-value="emit('toggle-select', line.id, Boolean($event))"
        />
      </div>

      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--product">
        <div class="pp-app-order-line-row__product row items-center">
          <div class="pp-app-order-line-row__thumb shrink-0">
            <q-img
              v-if="line.image_url?.trim()"
              :src="line.image_url"
              ratio="1"
              class="pp-app-order-line-row__thumb-img"
            />
            <div v-else class="pp-app-order-line-row__thumb-placeholder">
              <q-icon name="ph ph-image" size="16px" color="grey-6" aria-hidden="true" />
            </div>
          </div>
          <div class="col min-width-0">
            <div class="pp-app-order-line-row__title text-weight-medium">
              {{ titleLabel }}
            </div>
            <div class="pp-app-order-line-row__meta row items-center wrap">
              <span class="pp-app-order-line-row__id">#{{ line.id }}</span>
              <span v-if="line.url.trim()" class="pp-app-order-line-row__dot" aria-hidden="true">·</span>
              <TfBtn
                v-if="line.url.trim()"
                variant="link"
                size="sm"
                :label="linkLabel"
                icon="ph ph-arrow-square-out"
                class="pp-app-order-line-row__link"
                :aria-label="`Open product link for line ${line.id}`"
                @click="openPpOrderLineUrl(line.url)"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--description">
        <div v-if="customerDescription" class="pp-app-order-line-row__description">
          {{ customerDescription }}
        </div>
        <span v-else class="pp-app-order-line-row__empty">—</span>
      </div>

      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--store">
        <span v-if="storeLabel" class="pp-app-order-line-row__store-text">{{ storeLabel }}</span>
        <span v-else class="pp-app-order-line-row__empty">—</span>
      </div>

      <div
        class="pp-app-order-line-row__cell pp-app-order-line-row__cell--quantities tf-num"
        @click.stop
      >
        <div class="pp-app-order-line-row__qty-tier">
          <span class="pp-app-order-line-row__qty-tier-label">Customer</span>
          <q-input
            :model-value="neededQtyDraft"
            type="number"
            min="1"
            step="1"
            dense
            borderless
            hide-bottom-space
            input-class="font-mono text-center excel-cell-input-native"
            class="excel-cell-input excel-cell-input--qty-tint pp-app-order-line-row__qty-input"
            :disable="updating"
            @update:model-value="onNeededQtyInput"
            @blur="saveNeededQty"
            @keydown.enter="(e) => (e.target as HTMLInputElement).blur()"
          />
        </div>
        <div class="pp-app-order-line-row__qty-tier">
          <span class="pp-app-order-line-row__qty-tier-label">Ordered</span>
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
            class="excel-cell-input excel-cell-input--qty-tint pp-app-order-line-row__qty-input"
            :disable="updating"
            @update:model-value="onPlacedQtyInput"
            @blur="savePlacedQty"
            @keydown.enter="(e) => (e.target as HTMLInputElement).blur()"
          />
        </div>
        <div class="pp-app-order-line-row__qty-tier">
          <span class="pp-app-order-line-row__qty-tier-label">Received</span>
          <q-input
            :model-value="receivedQtyDisplay"
            type="number"
            min="0"
            step="1"
            dense
            borderless
            hide-bottom-space
            placeholder="—"
            input-class="font-mono text-center excel-cell-input-native"
            class="excel-cell-input excel-cell-input--qty-tint pp-app-order-line-row__qty-input"
            :disable="updating"
            @update:model-value="onReceivedQtyInput"
            @blur="saveReceivedQty"
            @keydown.enter="(e) => (e.target as HTMLInputElement).blur()"
          />
        </div>
      </div>

      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--center pp-app-order-line-row__cell--price tf-num">
        {{ priceLabel }}
      </div>

      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--center pp-app-order-line-row__cell--customer">
        <span class="pp-app-order-line-row__customer-text">{{ customerLabel }}</span>
      </div>

      <div
        class="pp-app-order-line-row__cell pp-app-order-line-row__cell--tracking"
        @click.stop
      >
        <div class="pp-app-order-line-row__tracking-row">
          <q-input
            :model-value="trackingUrlDraft"
            dense
            borderless
            hide-bottom-space
            placeholder="—"
            input-class="excel-cell-input-native"
            class="excel-cell-input pp-app-order-line-row__tracking-input"
            :disable="updating"
            @update:model-value="onTrackingUrlInput"
            @blur="saveTrackingUrl"
            @keydown.enter="(e) => (e.target as HTMLInputElement).blur()"
          />
          <TfBtn
            v-if="trackingUrlOpenable"
            variant="icon"
            size="sm"
            icon="ph ph-arrow-square-out"
            class="pp-app-order-line-row__tracking-open shrink-0"
            :aria-label="`Open tracking link for line ${line.id}`"
            @click="openPpOrderLineUrl(trackingUrlDraft)"
          />
        </div>
      </div>

      <div
        class="pp-app-order-line-row__cell pp-app-order-line-row__cell--center pp-app-order-line-row__cell--placement"
        :class="placementCellClass"
      >
        <q-select
          :model-value="placementSelectValue"
          dense
          borderless
          emit-value
          map-options
          options-dense
          :options="placementOptions"
          :disable="updating"
          dropdown-icon="none"
          class="pp-app-order-line-row__select pp-app-order-line-row__select--center"
          @update:model-value="onPlacementChange"
        />
      </div>

      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--center pp-app-order-line-row__cell--supplier">
        <q-select
          :model-value="line.pp_supplier_group_id"
          dense
          borderless
          emit-value
          map-options
          options-dense
          :options="supplierOptions"
          :loading="supplierLoading"
          :disable="updating"
          dropdown-icon="none"
          class="pp-app-order-line-row__select pp-app-order-line-row__select--center"
          @update:model-value="onSupplierChange"
        />
      </div>

      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--center pp-app-order-line-row__cell--shipment">
        <q-select
          :model-value="line.shipment_id"
          dense
          borderless
          emit-value
          map-options
          options-dense
          :options="shipmentOptions"
          :loading="shipmentLoading"
          :disable="updating"
          dropdown-icon="none"
          class="pp-app-order-line-row__select pp-app-order-line-row__select--center pp-app-order-line-row__select--shipment"
          @update:model-value="onShipmentChange"
        >
          <template #option="scope">
            <q-item v-bind="scope.itemProps" class="pp-shipment-opt-item">
              <q-item-section>
                <div class="pp-shipment-opt">
                  <div class="pp-shipment-opt__name">{{ scope.opt.name }}</div>
                  <div
                    v-if="scope.opt.value != null"
                    class="pp-shipment-opt__id"
                  >
                    #{{ scope.opt.value }}
                  </div>
                </div>
              </q-item-section>
            </q-item>
          </template>
          <template #selected-item="scope">
            <div
              v-if="scope.opt"
              class="pp-shipment-opt pp-shipment-opt--selected"
            >
              <div class="pp-shipment-opt__name">{{ scope.opt.name }}</div>
              <div
                v-if="scope.opt.value != null"
                class="pp-shipment-opt__id"
              >
                #{{ scope.opt.value }}
              </div>
            </div>
          </template>
        </q-select>
      </div>

      <div class="pp-app-order-line-row__cell pp-app-order-line-row__cell--actions">
        <TfBtn
          variant="icon"
          icon="ph ph-pencil"
          aria-label="Edit item"
          @click="emit('edit', line)"
        />
      </div>
    </div>

    <div
      v-if="requestInstructions"
      class="pp-app-order-line-row__instructions-band"
    >
      <span class="pp-app-order-line-row__instructions-label">Request</span>
      <span class="pp-app-order-line-row__instructions-text">{{ requestInstructions }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import {
  openPpOrderLineUrl,
  ppOrderLineHostLabel,
} from '../../utils/ppOrderLineUrl';
import { PP_ORDER_LINE_STAFF_PLACEMENT_OPTIONS } from '../../utils/ppOrderLinePlacement';
import { ppPlacementCellClass } from '../../utils/ppOrderLineSelectTones';
import { buildPpStaffOrderLineUpdate } from '../../utils/ppStaffOrderLineUpdate';
import type { PpShipmentSelectOption } from '../../types/ppShipment';
import type {
  PpOrderLine,
  PpOrderLinePlacementStatus,
  PpStaffOrderLineUpdatePayload,
} from '../../types/ppPurchaseRequest';

type SelectOption = { label: string; value: number | string | null };

const props = defineProps<{
  line: PpOrderLine;
  selected?: boolean;
  updating?: boolean;
  supplierOptions: SelectOption[];
  shipmentOptions: PpShipmentSelectOption[];
  supplierLoading?: boolean;
  shipmentLoading?: boolean;
}>();

const emit = defineEmits<{
  edit: [line: PpOrderLine];
  patch: [payload: PpStaffOrderLineUpdatePayload];
  'toggle-select': [lineId: number, selected: boolean];
}>();

const placementOptions = PP_ORDER_LINE_STAFF_PLACEMENT_OPTIONS;

const placementSelectValue = computed((): PpOrderLinePlacementStatus =>
  props.line.placement_status === 'none' ? 'requested' : props.line.placement_status,
);

const placementCellClass = computed(() => ppPlacementCellClass(props.line.placement_status));

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

const customerLabel = computed(() => {
  const name = props.line.customer_group_name?.trim();
  if (name) return name;
  return `#${props.line.pp_customer_group_id}`;
});

const customerDescription = computed(() => props.line.description?.trim() || '');

const requestInstructions = computed(
  () => props.line.request_bucket_description?.trim() || '',
);

const neededQtyDraft = ref<number>(props.line.needed_qty);
const placedQtyDraft = ref<number | null>(props.line.placed_qty);
const receivedQtyDraft = ref<number | null>(props.line.received_qty);
const trackingUrlDraft = ref(props.line.tracking_url?.trim() ?? '');

const trackingUrlOpenable = computed(() => trackingUrlDraft.value.trim().length > 0);

const placedQtyDisplay = computed(() =>
  placedQtyDraft.value == null ? '' : placedQtyDraft.value,
);

const receivedQtyDisplay = computed(() =>
  receivedQtyDraft.value == null ? '' : receivedQtyDraft.value,
);

watch(
  () => props.line.needed_qty,
  (value) => {
    neededQtyDraft.value = value;
  },
);

watch(
  () => props.line.placed_qty,
  (value) => {
    placedQtyDraft.value = value;
  },
);

watch(
  () => props.line.received_qty,
  (value) => {
    receivedQtyDraft.value = value;
  },
);

watch(
  () => props.line.tracking_url,
  (value) => {
    trackingUrlDraft.value = value?.trim() ?? '';
  },
);

const parseOptionalQty = (value: string | number | null | undefined): number | null => {
  if (value === '' || value == null) return null;
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return n;
};

const onNeededQtyInput = (value: string | number | null) => {
  const n = parseOptionalQty(value);
  neededQtyDraft.value = n == null ? props.line.needed_qty : n;
};

const onPlacedQtyInput = (value: string | number | null) => {
  placedQtyDraft.value = parseOptionalQty(value);
};

const onReceivedQtyInput = (value: string | number | null) => {
  receivedQtyDraft.value = parseOptionalQty(value);
};

const saveNeededQty = () => {
  const next = Number(neededQtyDraft.value);
  if (!Number.isFinite(next) || next < 1) {
    neededQtyDraft.value = props.line.needed_qty;
    return;
  }
  if (next === props.line.needed_qty) return;
  emit('patch', buildPpStaffOrderLineUpdate(props.line, { needed_qty: next }));
};

const savePlacedQty = () => {
  const next = placedQtyDraft.value;
  if (next != null && (!Number.isFinite(next) || next < 0)) {
    placedQtyDraft.value = props.line.placed_qty;
    return;
  }
  if (next === props.line.placed_qty) return;
  emit('patch', buildPpStaffOrderLineUpdate(props.line, { placed_qty: next }));
};

const saveReceivedQty = () => {
  const next = receivedQtyDraft.value;
  if (next != null && (!Number.isFinite(next) || next < 0)) {
    receivedQtyDraft.value = props.line.received_qty;
    return;
  }
  if (next === props.line.received_qty) return;
  emit('patch', buildPpStaffOrderLineUpdate(props.line, { received_qty: next }));
};

const onTrackingUrlInput = (value: string | number | null) => {
  trackingUrlDraft.value = value == null ? '' : String(value);
};

const normalizeTrackingUrl = (raw: string): string | null => {
  const trimmed = raw.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const saveTrackingUrl = () => {
  const next = normalizeTrackingUrl(trackingUrlDraft.value);
  const prev = props.line.tracking_url?.trim() || null;
  if (next === prev) return;
  trackingUrlDraft.value = next ?? '';
  emit('patch', buildPpStaffOrderLineUpdate(props.line, { tracking_url: next }));
};

const onPlacementChange = (value: PpOrderLinePlacementStatus) => {
  if (value === placementSelectValue.value) return;
  emit('patch', buildPpStaffOrderLineUpdate(props.line, { placement_status: value }));
};

const onSupplierChange = (value: number | null) => {
  const next = value == null ? null : Number(value);
  if (next === props.line.pp_supplier_group_id) return;
  emit('patch', buildPpStaffOrderLineUpdate(props.line, { pp_supplier_group_id: next }));
};

const onShipmentChange = (value: number | null) => {
  const next = value == null ? null : Number(value);
  if (next === props.line.shipment_id) return;
  emit('patch', buildPpStaffOrderLineUpdate(props.line, { shipment_id: next }));
};

</script>

<style scoped>
.pp-app-order-line-row {
  min-width: 0;
}

.pp-app-order-line-row__grid {
  display: grid;
  grid-template-columns:
    2.5rem
    minmax(15rem, 2.4fr)
    minmax(11rem, 1.2fr)
    minmax(6.5rem, 0.65fr)
    minmax(11rem, 1.25fr)
    4.25rem
    minmax(6.5rem, 0.72fr)
    minmax(8.5rem, 0.85fr)
    minmax(6.75rem, 0.75fr)
    minmax(6.5rem, 0.72fr)
    minmax(11rem, 1.15fr)
    2.75rem;
  align-items: stretch;
  min-width: 0;
}

.pp-app-order-line-row__cell {
  min-width: 0;
  padding: 0.4rem 0.5rem;
  border-right: 1px solid var(--tf-neutral-border);
  font-size: 12px;
  color: var(--tf-neutral-ink);
  align-self: stretch;
  display: flex;
  align-items: center;
}

.pp-app-order-line-row__cell--center {
  justify-content: center;
  text-align: center;
}

.pp-app-order-line-row__cell--description {
  align-items: flex-start;
  padding-top: 0.45rem;
  padding-bottom: 0.45rem;
}

.pp-app-order-line-row__cell--product {
  align-items: center;
  padding-top: 0.45rem;
  padding-bottom: 0.45rem;
}

.pp-app-order-line-row__cell:last-child {
  border-right: none;
}

.pp-app-order-line-row__cell--quantities,
.pp-app-order-line-row__cell--price {
  font-weight: 600;
}

.pp-app-order-line-row__cell--actions,
.pp-app-order-line-row__cell--select {
  display: flex;
  justify-content: center;
  align-items: center;
  padding-left: 0.25rem;
  padding-right: 0.25rem;
}

.pp-app-order-line-row__product {
  gap: 8px;
  min-width: 0;
}

.pp-app-order-line-row__thumb {
  width: 1in;
  flex-shrink: 0;
}

.pp-app-order-line-row__thumb-img,
.pp-app-order-line-row__thumb-placeholder {
  width: 1in;
  height: 1in;
  border-radius: 4px;
  overflow: hidden;
}

.pp-app-order-line-row__thumb-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--tf-disabled-bg);
  border: 1px solid var(--tf-neutral-border);
}

.pp-app-order-line-row__thumb-placeholder .q-icon {
  font-size: 1.25rem;
}

.pp-app-order-line-row__title {
  font-size: 12px;
  line-height: 1.35;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.pp-app-order-line-row__description {
  font-size: 12px;
  font-weight: 600;
  line-height: 1.4;
  color: var(--tf-neutral-ink);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.pp-app-order-line-row__empty {
  color: var(--tf-neutral-muted);
}

.pp-app-order-line-row__instructions-band {
  width: 100%;
  padding: 0.45rem 0.65rem;
  border-top: 1px solid var(--tf-neutral-border);
  background: color-mix(in srgb, var(--tf-disabled-bg) 45%, var(--tf-neutral-surface));
  font-size: 11px;
  line-height: 1.4;
  color: var(--tf-neutral-ink);
}

.pp-app-order-line-row__instructions-label {
  display: inline-block;
  margin-right: 6px;
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--tf-neutral-muted);
  vertical-align: top;
}

.pp-app-order-line-row__instructions-text {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.pp-app-order-line-row__meta {
  gap: 4px;
  margin-top: 1px;
  min-width: 0;
}

.pp-app-order-line-row__id,
.pp-app-order-line-row__dot {
  flex-shrink: 0;
  font-size: 10px;
  color: var(--tf-neutral-muted);
}

.pp-app-order-line-row__id {
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  font-family: var(--tf-font-mono);
}

.pp-app-order-line-row__link :deep(.q-btn) {
  max-width: 100%;
  min-height: 18px;
  height: auto;
  padding: 0;
  font-size: 10px;
  justify-content: flex-start;
  white-space: normal;
  text-align: left;
}

.pp-app-order-line-row__link :deep(.q-btn__content) {
  min-width: 0;
  flex-wrap: wrap;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.pp-app-order-line-row__link :deep(.q-btn__content > span:not(.q-icon)) {
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.pp-app-order-line-row__cell--quantities {
  flex-direction: column;
  justify-content: center;
  align-items: stretch;
  gap: 3px;
  padding-top: 0.35rem;
  padding-bottom: 0.35rem;
}

.pp-app-order-line-row__qty-tier {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 6px;
  min-width: 0;
}

.pp-app-order-line-row__qty-tier-label {
  flex: 0 0 4.5rem;
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--tf-neutral-muted);
  text-align: left;
  line-height: 1.2;
}

.pp-app-order-line-row__customer-text {
  width: 100%;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.35;
}

.pp-app-order-line-row__cell--customer {
  font-size: 11px;
  font-weight: 600;
}

.pp-app-order-line-row__cell--store {
  align-items: flex-start;
  padding-top: 0.45rem;
  padding-bottom: 0.45rem;
}

.pp-app-order-line-row__store-text {
  font-size: 11px;
  font-weight: 600;
  line-height: 1.35;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.pp-app-order-line-row__cell--tracking {
  align-items: center;
  padding-left: 0.35rem;
  padding-right: 0.35rem;
}

.pp-app-order-line-row__tracking-row {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 2px;
  width: 100%;
  min-width: 0;
}

.pp-app-order-line-row__tracking-input {
  flex: 1 1 auto;
  min-width: 0;
}

.pp-app-order-line-row__tracking-input :deep(.q-field__control) {
  min-height: 28px !important;
  height: auto !important;
  padding: 0 2px !important;
}

.pp-app-order-line-row__tracking-input :deep(.excel-cell-input-native) {
  font-size: 11px;
  line-height: 1.3;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.pp-app-order-line-row__cell--placement {
  transition: background-color 0.15s ease, color 0.15s ease;
  font-weight: 700;
}

.pp-app-order-line-row__cell--placement :deep(.q-field__control) {
  background: transparent !important;
}

.pp-app-order-line-row__cell--placement :deep(.q-field__native),
.pp-app-order-line-row__cell--placement :deep(.q-field__append) {
  color: inherit;
  font-weight: 700;
}

.pp-app-order-line-row__select {
  width: 100%;
}

.pp-app-order-line-row__select :deep(.q-field__control) {
  min-height: 28px;
  height: auto;
  padding: 2px 0;
}

.pp-app-order-line-row__select :deep(.q-field__native),
.pp-app-order-line-row__select :deep(.q-field__input) {
  min-height: 28px;
  padding: 0;
  font-size: 11px;
  line-height: 1.3;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.pp-app-order-line-row__select :deep(.q-select__dropdown-icon),
.pp-app-order-line-row__select :deep(.q-field__append .q-icon.q-select__dropdown-icon) {
  display: none !important;
}

.pp-app-order-line-row__select :deep(.q-field__append:not(:has(.q-icon:not(.q-select__dropdown-icon)))) {
  display: none;
  width: 0;
  min-width: 0;
  padding: 0;
  margin: 0;
}

.pp-app-order-line-row__select--center :deep(.q-field__control) {
  justify-content: center;
  padding-left: 0.25rem;
  padding-right: 0.25rem;
}

.pp-app-order-line-row__select--center :deep(.q-field__control-container) {
  justify-content: center;
  flex: 1 1 auto;
}

.pp-app-order-line-row__select--center :deep(.q-field__native),
.pp-app-order-line-row__select--center :deep(.q-field__input) {
  text-align: center;
  justify-content: center;
}

.pp-app-order-line-row__select--shipment :deep(.q-field__control) {
  min-height: 32px;
}

.pp-app-order-line-row__select--shipment :deep(.q-field__native) {
  min-height: 32px;
  padding-top: 2px;
  padding-bottom: 2px;
}

.pp-shipment-opt {
  width: 100%;
  line-height: 1.25;
}

.pp-shipment-opt--selected {
  text-align: center;
}

.pp-shipment-opt__name {
  font-size: 11px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.pp-shipment-opt__id {
  margin-top: 1px;
  font-size: 9px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  font-family: var(--tf-font-mono);
  color: var(--tf-neutral-muted);
}

.pp-shipment-opt-item {
  min-height: 36px;
}

.pp-app-order-line-row__cell--quantities {
  padding-left: 0.2rem;
  padding-right: 0.2rem;
}

.pp-app-order-line-row__qty-tier .pp-app-order-line-row__qty-input {
  flex: 1 1 auto;
  min-width: 0;
  width: auto;
}

.pp-app-order-line-row__qty-tier :deep(.q-field) {
  width: 100%;
}

.pp-app-order-line-row__cell--quantities :deep(.q-field__control),
.pp-app-order-line-row__cell--quantities :deep(.q-field__control) {
  min-height: 28px !important;
  height: 28px !important;
  padding: 0 4px !important;
  border-radius: 6px;
}

.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control),
.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control) {
  border: none !important;
  background-color: transparent !important;
  transition: background-color 0.1s ease-in-out, border-color 0.1s ease-in-out;
}

.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control:before),
.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control:after),
.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control:before),
.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint .q-field__control),
.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint .q-field__control) {
  background-color: color-mix(in srgb, var(--tf-ops-hue-qty) 42%, var(--tf-neutral-surface)) !important;
}

.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint:hover .q-field__control),
.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint:hover .q-field__control) {
  background-color: color-mix(in srgb, var(--tf-ops-hue-qty) 55%, var(--tf-neutral-surface)) !important;
}

.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint.q-field--focused .q-field__control),
.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input--qty-tint.q-field--focused .q-field__control) {
  background-color: color-mix(in srgb, var(--tf-ops-hue-qty) 55%, var(--tf-neutral-surface)) !important;
  border: 1.5px solid var(--tf-ops-accent-qty) !important;
}

.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input-native),
.pp-app-order-line-row__cell--quantities :deep(.excel-cell-input-native) {
  font-size: 12px;
  font-weight: 700;
  padding: 0 !important;
}
</style>

<style>
/* Cell-only fulfillment tones (dropdown menus stay plain) */
.pp-order-line-tone--placement-none {
  background: #e2e8f0;
  color: #334155;
}

.pp-order-line-tone--placement-draft {
  background: #cbd5e1;
  color: #1e293b;
}

.pp-order-line-tone--placement-requested {
  background: #fdba74;
  color: #9a3412;
}

.pp-order-line-tone--placement-processing {
  background: #93c5fd;
  color: #1d4ed8;
}

.pp-order-line-tone--placement-cancelled {
  background: #fca5a5;
  color: #991b1b;
}

.pp-order-line-tone--placement-added_to_cart {
  background: #fcd34d;
  color: #92400e;
}

.pp-order-line-tone--placement-order_placed {
  background: #7dd3fc;
  color: #0c4a6e;
}

.pp-order-line-tone--placement-cargo_warehouse {
  background: #a5b4fc;
  color: #312e81;
}

.pp-order-line-tone--placement-in_flight {
  background: #c4b5fd;
  color: #4c1d95;
}

.pp-order-line-tone--placement-local_warehouse {
  background: #86efac;
  color: #14532d;
}

.pp-order-line-tone--placement-delivered {
  background: #4ade80;
  color: #14532d;
}

.pp-order-line-tone--placement-lost {
  background: #fca5a5;
  color: #7f1d1d;
}
</style>
