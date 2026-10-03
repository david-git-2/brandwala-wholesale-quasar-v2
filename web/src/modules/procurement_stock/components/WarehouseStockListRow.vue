<template>
  <div class="warehouse-list-item">
    <div class="warehouse-list-sl text-caption font-mono shrink-0">{{ index }}</div>
    <div class="warehouse-list-thumb shrink-0">
      <q-avatar
        square
        class="warehouse-list-thumb__avatar avatar-soft-sq bg-grey-2 border-grey overflow-hidden"
      >
        <SmartImage
          :src="row.image_url"
          :alt="row.item_name"
          class="warehouse-list-thumb__img"
          :enable-edit="false"
        />
      </q-avatar>
    </div>
    <div class="warehouse-list-info">
      <div class="warehouse-title-line">
        <span class="warehouse-name">{{ row.item_name }}</span>
      </div>
      <div class="warehouse-meta-line">
        <span v-if="row.product_code" class="meta-item font-mono">{{ row.product_code }}</span>
        <span v-if="row.product_code && row.barcode" class="meta-dot">·</span>
        <span v-if="row.barcode" class="meta-item font-mono">{{ row.barcode }}</span>
        <span v-if="(row.product_code || row.barcode) && row.shipment_name" class="meta-dot">·</span>
        <span v-if="row.shipment_name" class="meta-item">{{ row.shipment_name }}</span>
        <span v-if="row.shipment_status" class="meta-dot">·</span>
        <span v-if="row.shipment_status" class="meta-item">{{ shipmentStatusLabel }}</span>
      </div>
      <div class="warehouse-meta-line warehouse-meta-line--secondary">
        <span v-if="row.outcome_reason" class="meta-item meta-inbound">
          Received: {{ outcomeLabel }}
        </span>
        <span v-if="row.outcome_reason" class="meta-dot">·</span>
        <span class="meta-item">Condition: {{ gradeLabel }}</span>
        <span class="meta-dot">·</span>
        <span class="meta-item">Sell: {{ availabilityLabel }}</span>
        <span class="meta-dot">·</span>
        <q-icon name="ph ph-map-pin" size="11px" color="grey-6" class="shrink-0" />
        <span class="meta-item">
          {{ row.location_name || (row.location_id ? `#${row.location_id}` : '—') }}
        </span>
      </div>
    </div>
    <div class="warehouse-list-aside">
      <div class="warehouse-metric warehouse-metric--cost font-mono">
        <div class="text-weight-bold" style="font-size: 12px">{{ unitCostLabel }}</div>
        <div class="text-caption bw-text-muted" style="font-size: 10px">T: {{ lineTotalLabel }}</div>
      </div>
      <div class="warehouse-metric warehouse-metric--qty font-mono text-weight-bold">
        {{ row.quantity }}
      </div>
      <div v-if="!readOnly" class="warehouse-list-actions row items-center no-wrap q-gutter-x-xs">
        <q-btn
          flat
          round
          dense
          icon="ph ph-map-pin-line"
          size="sm"
          color="grey-7"
          @click.stop="emit('location', row)"
        >
          <q-tooltip>Stock location</q-tooltip>
        </q-btn>
        <q-btn
          flat
          round
          dense
          icon="ph ph-tag"
          size="sm"
          color="grey-7"
          @click.stop="emit('condition', row)"
        >
          <q-tooltip>Condition & sell status</q-tooltip>
        </q-btn>
        <q-btn
          v-if="row.product_code"
          flat
          round
          dense
          icon="ph ph-copy"
          size="sm"
          color="grey-7"
          @click.stop="emit('copy-code', row.product_code!)"
        >
          <q-tooltip>Copy code</q-tooltip>
        </q-btn>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import SmartImage from 'src/components/SmartImage.vue';
import type { GlobalStock } from '../repositories/globalStockRepository';

defineProps<{
  row: GlobalStock;
  index: number;
  readOnly?: boolean;
  gradeLabel: string;
  availabilityLabel: string;
  shipmentStatusLabel: string;
  outcomeLabel: string;
  unitCostLabel: string;
  lineTotalLabel: string;
}>();

const emit = defineEmits<{
  location: [row: GlobalStock];
  condition: [row: GlobalStock];
  'copy-code': [code: string];
}>();
</script>

<style scoped>
.warehouse-list-item {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 0.55rem 1rem;
  border-bottom: 1px solid var(--bw-neutral-border, #f1f5f9);
  transition: background 0.15s ease;
  min-height: calc(1in + 8px);
}

.warehouse-list-item:hover {
  background: #f8fafc;
}

.warehouse-list-sl {
  width: 28px;
  text-align: center;
  color: var(--bw-neutral-chrome, #64748b);
}

.border-grey {
  border: 1px solid var(--bw-neutral-border, #e2e8f0);
  border-radius: 8px;
}

.avatar-soft-sq {
  border-radius: 6px;
}

.warehouse-list-thumb__avatar {
  width: 1in;
  height: 1in;
  font-size: 1in;
}

.warehouse-list-thumb :deep(.warehouse-list-thumb__img),
.warehouse-list-thumb :deep(.smart-image-wrapper) {
  display: block;
  width: 100%;
  height: 100%;
}

.warehouse-list-thumb :deep(.smart-image__img),
.warehouse-list-thumb :deep(img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.warehouse-list-thumb :deep(.smart-image__fallback) {
  font-size: 10px;
  text-align: center;
  padding: 2px;
}

.warehouse-list-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  flex: 1 1 auto;
}

.warehouse-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--bw-neutral-ink, #1e293b);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.warehouse-meta-line {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px 6px;
  font-size: 11.5px;
  color: var(--bw-neutral-muted, #64748b);
}

.warehouse-meta-line--secondary {
  font-size: 11px;
}

.meta-inbound {
  color: var(--bw-info, #2563eb);
  font-weight: 500;
}

.meta-dot {
  color: #94a3b8;
}

.warehouse-list-aside {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.warehouse-metric {
  text-align: center;
  padding: 2px 4px;
  min-width: 52px;
}

.warehouse-metric--cost {
  color: var(--bw-neutral-ink, #1e293b);
}

.warehouse-metric--qty {
  font-size: 13px;
  min-width: 1in;
  color: var(--bw-neutral-ink, #1e293b);
}
</style>
