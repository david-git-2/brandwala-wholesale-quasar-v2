<template>
  <article class="pp-order-line-card">
    <div class="pp-order-line-card__top row items-center no-wrap justify-between">
      <div class="pp-order-line-card__lead col min-width-0 row items-center no-wrap q-gutter-x-xs">
        <span class="pp-order-line-card__no shrink-0">#{{ line.id }}</span>
        <TfBtn
          variant="link"
          size="sm"
          :label="ppOrderLineUrlLabel(line.url)"
          icon="ph ph-arrow-square-out"
          class="pp-order-line-card__url col min-width-0"
          @click="openPpOrderLineUrl(line.url)"
        />
      </div>
      <div v-if="$slots.actions" class="pp-order-line-card__actions row no-wrap q-gutter-xs shrink-0">
        <slot name="actions" />
      </div>
    </div>

    <div class="pp-order-line-card__facts row q-col-gutter-sm items-start">
      <div class="col-auto pp-order-line-card__qty">
        <span class="pp-order-line-card__qty-label">Qty</span>
        <span class="pp-order-line-card__qty-value tf-num">{{ line.needed_qty }}</span>
      </div>
      <div class="col min-width-0 pp-order-line-card__desc">
        <span v-if="line.description?.trim()" class="pp-order-line-card__desc-text">
          {{ line.description }}
        </span>
        <span v-else class="pp-order-line-card__desc-empty">No description</span>
      </div>
    </div>
  </article>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import { openPpOrderLineUrl, ppOrderLineUrlLabel } from '../../../utils/ppOrderLineUrl';
import type { PpOrderLine } from '../../../types/ppPurchaseRequest';

defineProps<{
  line: PpOrderLine;
}>();
</script>

<style scoped>
.pp-order-line-card {
  border: 1px solid var(--tf-neutral-border);
  border-radius: 8px;
  background: var(--tf-neutral-surface);
  padding: 10px 12px;
}

.pp-order-line-card__top {
  gap: 8px;
  min-width: 0;
}

.pp-order-line-card__lead {
  min-width: 0;
  justify-content: flex-start;
}

.pp-order-line-card__no {
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-muted);
  font-variant-numeric: tabular-nums;
  font-family: var(--tf-font-mono);
  padding-left: 0;
  margin-left: 0;
  text-align: left;
}

.pp-order-line-card__actions {
  flex-shrink: 0;
}

.pp-order-line-card__url {
  flex: 1 1 auto;
  min-height: 28px;
  min-width: 0;
  max-width: 100%;
  font-size: 13px;
}

.pp-order-line-card__url :deep(.q-btn) {
  width: 100%;
  justify-content: flex-start;
  padding-left: 0;
  padding-right: 0;
}

.pp-order-line-card__url :deep(.q-btn__content) {
  flex-wrap: nowrap;
  justify-content: flex-start;
  min-width: 0;
  max-width: 100%;
  width: 100%;
  text-align: left;
}

.pp-order-line-card__url :deep(.q-btn__content > span:not(.q-icon)) {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pp-order-line-card__facts {
  margin-top: 6px;
}

.pp-order-line-card__qty {
  display: flex;
  align-items: baseline;
  gap: 6px;
  padding-right: 8px;
  border-right: 1px solid var(--tf-neutral-border);
}

.pp-order-line-card__qty-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  color: var(--tf-neutral-muted);
}

.pp-order-line-card__qty-value {
  font-size: 15px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
  line-height: 1.2;
}

.pp-order-line-card__desc-text {
  font-size: 13px;
  line-height: 1.4;
  color: var(--tf-neutral-ink);
  white-space: pre-wrap;
}

.pp-order-line-card__desc-empty {
  font-size: 12px;
  color: var(--tf-neutral-muted);
  line-height: 1.4;
}

@media (max-width: 420px) {
  .pp-order-line-card__facts {
    flex-direction: column;
  }

  .pp-order-line-card__qty {
    border-right: 0;
    padding-right: 0;
    padding-bottom: 4px;
  }
}
</style>