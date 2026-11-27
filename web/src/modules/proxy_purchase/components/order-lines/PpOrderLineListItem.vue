<template>
  <article class="pp-order-line-item row no-wrap items-center">
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
            v-if="showMetaRow"
            class="pp-order-line-item__meta row items-baseline no-wrap"
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
              class="pp-order-line-item__host-link"
              :aria-label="`Open product link for line ${line.id}`"
              @click="openPpOrderLineUrl(line.url)"
            />
            <span
              v-if="showPrice && (showId || (showUrl && line.url.trim()))"
              class="pp-order-line-item__meta-dot"
              aria-hidden="true"
            >·</span>
            <span v-if="showPrice" class="pp-order-line-item__fact">
              <span class="pp-order-line-item__fact-label">Price</span>
              <span class="pp-order-line-item__fact-value tf-num">{{ priceLabel }}</span>
            </span>
          </div>
          <div
            v-if="showDetailRow"
            class="pp-order-line-item__detail row items-baseline min-width-0"
          >
            <span v-if="showQty" class="pp-order-line-item__qty">
              <span class="pp-order-line-item__fact-label">Qty</span>
              <span class="pp-order-line-item__qty-value tf-num">{{ line.needed_qty }}</span>
            </span>
            <span
              v-if="showQty && showDescription && descriptionText"
              class="pp-order-line-item__detail-divider"
              aria-hidden="true"
            >|</span>
            <p
              v-if="showDescription && descriptionText"
              class="pp-order-line-item__description q-mb-none col min-width-0"
            >
              {{ descriptionText }}
            </p>
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
    showDescription?: boolean;
  }>(),
  {
    showId: true,
    showImage: true,
    showName: true,
    showUrl: true,
    showQty: true,
    showPrice: true,
    showStatus: true,
    showDescription: true,
  },
);

const descriptionText = computed(() => props.line.description?.trim() || '');

const displayStatus = computed(() => ppOrderLineDisplayStatus(props.line));

const showMetaRow = computed(
  () =>
    props.showId
    || (props.showUrl && props.line.url.trim())
    || props.showPrice,
);

const showDetailRow = computed(
  () => props.showQty || (props.showDescription && Boolean(descriptionText.value)),
);

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
  width: 1in;
  flex-shrink: 0;
}

.pp-order-line-item__thumb-img,
.pp-order-line-item__thumb-placeholder {
  width: 1in;
  height: 1in;
  border-radius: 4px;
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
  flex-wrap: nowrap;
  justify-content: flex-start;
}

.pp-order-line-item__detail {
  margin-top: 6px;
  gap: 8px;
  min-width: 0;
}

.pp-order-line-item__detail-divider {
  flex-shrink: 0;
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-muted);
  user-select: none;
}

.pp-order-line-item__description {
  font-size: 12px;
  font-weight: 600;
  line-height: 1.4;
  color: var(--tf-neutral-ink);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  word-break: break-word;
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

.pp-order-line-item__host-link {
  flex: 0 1 auto;
  min-width: 0;
  max-width: 100%;
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

.pp-order-line-item__qty {
  display: inline-flex;
  flex-wrap: nowrap;
  align-items: baseline;
  gap: 5px;
  flex-shrink: 0;
  white-space: nowrap;
}

.pp-order-line-item__qty-value {
  font-size: 20px;
  font-weight: 800;
  line-height: 1;
  color: var(--tf-neutral-ink);
  font-variant-numeric: tabular-nums;
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
