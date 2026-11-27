<template>
  <article class="pp-order-line-item row no-wrap items-start">
    <div v-if="showImage" class="pp-order-line-item__thumb shrink-0">
      <q-img
        v-if="line.image_url?.trim()"
        :src="line.image_url"
        ratio="1"
        class="pp-order-line-item__thumb-img"
      />
      <div v-else class="pp-order-line-item__thumb-placeholder">
        <q-icon name="ph ph-image" size="22px" color="grey-6" aria-hidden="true" />
      </div>
    </div>

    <div class="pp-order-line-item__main col min-width-0 column">
      <div class="pp-order-line-item__head row items-start no-wrap">
        <div class="col min-width-0">
          <div
            v-if="showTitle"
            class="pp-order-line-item__title text-weight-medium"
          >
            {{ titleLabel }}
          </div>
          <div
            v-if="showId || (showUrl && line.url.trim())"
            class="pp-order-line-item__meta row items-center no-wrap"
          >
            <span v-if="showId" class="pp-order-line-item__id">#{{ line.id }}</span>
            <span
              v-if="showId && showUrl && line.url.trim()"
              class="pp-order-line-item__meta-dot"
              aria-hidden="true"
            >·</span>
            <TfBtn
              v-if="showUrl && line.url.trim()"
              variant="link"
              size="sm"
              :label="hostLinkLabel"
              icon="ph ph-arrow-square-out"
              class="pp-order-line-item__host-link col min-width-0"
              :aria-label="`Open product link for line ${line.id}`"
              @click="openPpOrderLineUrl(line.url)"
            />
          </div>
        </div>
        <div class="pp-order-line-item__head-end row items-center no-wrap shrink-0 q-gutter-x-xs">
          <TfStatusBadge
            v-if="showStatus"
            class="pp-order-line-item__status"
            :status="line.status"
            :label="displayStatus"
          />
          <div v-if="$slots.actions" class="pp-order-line-item__actions row no-wrap">
            <slot name="actions" />
          </div>
        </div>
      </div>

      <div
        v-if="showQty || showPrice"
        class="pp-order-line-item__facts row items-center justify-between"
      >
        <span v-if="showQty" class="pp-order-line-item__fact">
          <span class="pp-order-line-item__fact-label">Qty</span>
          <span class="pp-order-line-item__fact-value tf-num">{{ line.needed_qty }}</span>
        </span>
        <span v-if="showPrice" class="pp-order-line-item__fact">
          <span class="pp-order-line-item__fact-label">Price</span>
          <span class="pp-order-line-item__fact-value tf-num">{{ priceLabel }}</span>
        </span>
      </div>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import {
  openPpOrderLineUrl,
  ppOrderLineHostLabel,
} from '../../utils/ppOrderLineUrl';
import { ppOrderLineDisplayStatus } from '../../utils/ppOrderLineDisplayStatus';
import type { PpOrderLine } from '../../types/ppPurchaseRequest';

const props = withDefaults(
  defineProps<{
    line: PpOrderLine;
    showId?: boolean;
    showImage?: boolean;
    showName?: boolean;
    showUrl?: boolean;
    showQty?: boolean;
    showPrice?: boolean;
    showStatus?: boolean;
  }>(),
  {
    showId: true,
    showImage: true,
    showName: true,
    showUrl: true,
    showQty: true,
    showPrice: true,
    showStatus: true,
  },
);

const displayStatus = computed(() => ppOrderLineDisplayStatus(props.line));

const hostLabel = computed(() => ppOrderLineHostLabel(props.line.url));

const showTitle = computed(() => {
  if (!props.showName) return false;
  const name = props.line.product_name?.trim();
  const host = hostLabel.value;
  return Boolean(name || (props.showUrl && host));
});

const titleLabel = computed(() => {
  const name = props.line.product_name?.trim();
  if (name) return name;
  const host = hostLabel.value;
  if (host) return host;
  return '—';
});

const hostLinkLabel = computed(() => {
  const host = hostLabel.value;
  if (!host) return 'Open link';
  const titleUsesHost =
    !props.line.product_name?.trim() && props.showName && showTitle.value;
  if (titleUsesHost) return 'View link';
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
</script>

<style scoped>
.pp-order-line-item {
  gap: 10px;
  border: 1px solid var(--tf-neutral-border);
  border-radius: 10px;
  background: var(--tf-neutral-surface);
  padding: 10px 12px;
}

.pp-order-line-item__thumb {
  width: 64px;
}

.pp-order-line-item__thumb-img,
.pp-order-line-item__thumb-placeholder {
  width: 64px;
  height: 64px;
  border-radius: 8px;
  overflow: hidden;
}

.pp-order-line-item__thumb-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--tf-disabled-bg);
  border: 1px solid var(--tf-neutral-border);
}

.pp-order-line-item__main {
  gap: 6px;
  min-width: 0;
}

.pp-order-line-item__head {
  gap: 8px;
  min-width: 0;
}

.pp-order-line-item__head-end {
  align-self: flex-start;
  max-width: 50%;
}

.pp-order-line-item__title {
  font-size: 14px;
  line-height: 1.35;
  color: var(--tf-neutral-ink);
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
  word-break: break-word;
}

.pp-order-line-item__meta {
  margin-top: 2px;
  gap: 4px;
  min-width: 0;
}

.pp-order-line-item__id {
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 600;
  color: var(--tf-neutral-muted);
  font-variant-numeric: tabular-nums;
  font-family: var(--tf-font-mono);
}

.pp-order-line-item__meta-dot {
  color: var(--tf-neutral-muted);
  font-size: 11px;
  user-select: none;
}

.pp-order-line-item__host-link :deep(.q-btn) {
  max-width: 100%;
  min-height: 24px;
  padding: 0;
  font-size: 12px;
  justify-content: flex-start;
}

.pp-order-line-item__host-link :deep(.q-btn__content) {
  min-width: 0;
}

.pp-order-line-item__host-link :deep(.q-btn__content > span:not(.q-icon)) {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pp-order-line-item__status {
  max-width: 100%;
}

.pp-order-line-item__facts {
  padding-top: 4px;
  border-top: 1px solid var(--tf-neutral-border);
  gap: 12px;
}

.pp-order-line-item__fact {
  display: inline-flex;
  align-items: baseline;
  gap: 6px;
  font-size: 12px;
}

.pp-order-line-item__fact-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--tf-neutral-muted);
}

.pp-order-line-item__fact-value {
  font-size: 13px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
}

@media (max-width: 420px) {
  .pp-order-line-item__head-end {
    max-width: 42%;
  }

  .pp-order-line-item__head-end .pp-order-line-item__status :deep(span) {
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 7rem;
  }
}
</style>
