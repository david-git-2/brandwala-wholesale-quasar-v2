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
      :show-app-details="resolvedAppDetails"
    >
      <template v-if="showAppActions || $slots.actions" #actions>
        <slot v-if="$slots.actions" name="actions" :line="line" />
        <template v-else-if="showAppActions">
          <TfBtn
            variant="icon"
            icon="ph ph-pencil"
            aria-label="Edit item"
            @click="emit('edit', line)"
          />
          <TfBtn
            variant="icon"
            icon="ph ph-trash"
            color="negative"
            aria-label="Delete item"
            :loading="deletingLineId === line.id"
            @click="emit('delete', line)"
          />
        </template>
      </template>
    </PpOrderLineListItem>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import PpOrderLineListItem from './PpOrderLineListItem.vue';
import type { PpOrderLine } from '../../types/ppPurchaseRequest';

const props = withDefaults(
  defineProps<{
    lines: PpOrderLine[];
    showId?: boolean;
    showImage?: boolean;
    showName?: boolean;
    showUrl?: boolean;
    showQty?: boolean;
    showPrice?: boolean;
    showStatus?: boolean;
    /** App staff list: edit/delete row actions (hidden on proxy portal). */
    showAppActions?: boolean;
    showAppDetails?: boolean;
    deletingLineId?: number | null;
  }>(),
  {
    showId: true,
    showImage: true,
    showName: true,
    showUrl: true,
    showQty: true,
    showPrice: true,
    showStatus: true,
    showAppActions: false,
    showAppDetails: false,
    deletingLineId: null,
  },
);

// App list shows full row detail alongside staff actions unless overridden.
const resolvedAppDetails = computed(
  () => props.showAppDetails || props.showAppActions,
);

const emit = defineEmits<{
  edit: [line: PpOrderLine];
  delete: [line: PpOrderLine];
}>();
</script>