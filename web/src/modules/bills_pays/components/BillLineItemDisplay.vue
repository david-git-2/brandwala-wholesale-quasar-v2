<template>
  <div class="bill-line-item">
    <SmartImage
      v-if="showThumbnail"
      :src="imageUrl"
      :alt="name"
      img-class="bill-line-item__thumb"
      fallback-class="bill-line-item__thumb bill-line-item__thumb--fallback"
      :enable-lightbox="false"
      :enable-edit="false"
    />
    <div class="bill-line-item__text">
      <span class="bill-line-item__name">{{ name }}</span>
      <span v-if="refsCaption" class="bill-line-item__refs font-mono text-caption text-grey-7">
        {{ refsCaption }}
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import SmartImage from 'src/components/SmartImage.vue';

const props = withDefaults(
  defineProps<{
    name: string;
    imageUrl?: string | null;
    /** Thumbnails only on compose; issued bill detail/preview are text-only. */
    showThumbnail?: boolean;
    globalStockId?: number | null;
    shipmentItemId?: number | null;
    shipmentId?: number | null;
  }>(),
  { showThumbnail: false },
);

const refsCaption = computed(() => {
  const parts: string[] = [];
  const stock = props.globalStockId;
  if (stock != null && Number(stock) > 0) {
    parts.push(`Stock #${stock}`);
  }
  const si = props.shipmentItemId;
  if (si != null && Number(si) > 0) {
    parts.push(`SI #${si}`);
  }
  const ship = props.shipmentId;
  if (ship != null && Number(ship) > 0 && parts.every((p) => !p.startsWith('Shipment'))) {
    parts.push(`Shipment #${ship}`);
  }
  return parts.length ? parts.join(' · ') : null;
});
</script>

<style scoped lang="scss">
.bill-line-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  min-width: 0;
  max-width: 280px;
}

.bill-line-item__text {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.bill-line-item__name {
  white-space: normal;
  word-break: break-word;
  overflow-wrap: anywhere;
  line-height: 1.35;
  font-size: inherit;
}

.bill-line-item__refs {
  line-height: 1.3;
  margin-top: 2px;
}

:deep(.bill-line-item__thumb) {
  width: 48px;
  height: 48px;
  min-width: 48px;
  object-fit: contain;
  border-radius: 4px;
  background: #f1f5f9;
}

:deep(.bill-line-item__thumb--fallback) {
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 9px;
  color: #94a3b8;
  text-align: center;
}
</style>