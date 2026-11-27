<template>
  <div class="pp-order-line-list column q-gutter-y-xs">
    <PpOrderLineListItem
      v-for="line in lines"
      :key="line.id"
      :line="line"
      :show-id="showId"
      :show-image="showImage"
      :show-name="showName"
      :show-url="showUrl"
      :show-qty="showQty"
      :show-price="showPrice"
      :show-status="showStatus"
    >
      <template v-if="$slots.actions" #actions>
        <slot name="actions" :line="line" />
      </template>
    </PpOrderLineListItem>
  </div>
</template>

<script setup lang="ts">
import type { PpOrderLine } from '../../types/ppPurchaseRequest';
import PpOrderLineListItem from './PpOrderLineListItem.vue';

withDefaults(
  defineProps<{
    lines: PpOrderLine[];
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
</script>