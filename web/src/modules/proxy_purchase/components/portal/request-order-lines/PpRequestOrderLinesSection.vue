<template>
  <section class="pp-request-order-lines-section" data-test="pp-request-order-lines-section">
    <div v-if="loading" class="pp-request-order-lines-section__loading">
      <q-skeleton type="rect" height="120px" />
    </div>

    <TfEmptyState
      v-else-if="!lines.length && viewKey === 'customer_draft'"
      class="pp-request-order-lines-section__empty"
      title="No items yet"
      message="Add a product URL and quantity to build this request."
      icon="ph ph-link"
    >
      <TfBtn variant="primary" size="md" label="Add item" class="q-mt-sm" @click="$emit('add-item')" />
    </TfEmptyState>

    <TfEmptyState
      v-else-if="!lines.length"
      class="pp-request-order-lines-section__empty"
      title="No items"
      message="This request has no lines."
      icon="ph ph-link"
    />

    <PpCustomerDraftOrderLinesList
      v-else-if="viewKey === 'customer_draft'"
      :lines="lines"
      :deleting-line-id="deletingLineId"
      @edit="$emit('edit-line', $event)"
      @delete="$emit('delete-line', $event)"
    />

    <PpCustomerOrderLineList
      v-else-if="viewKey === 'customer_posted'"
      :lines="lines"
    />

    <TfEmptyState
      v-else
      title="Items"
      message="This view is not available for your role or request state yet."
      icon="ph ph-list-dashes"
    />
  </section>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import PpCustomerOrderLineList from '../../order-lines/PpCustomerOrderLineList.vue';
import PpCustomerDraftOrderLinesList from './PpCustomerDraftOrderLinesList.vue';
import type { PpOrderLine } from '../../../types/ppPurchaseRequest';
import type { PpRequestOrderLinesViewKey } from '../../../types/ppRequestOrderLinesView';

defineProps<{
  viewKey: PpRequestOrderLinesViewKey;
  lines: PpOrderLine[];
  loading?: boolean;
  deletingLineId?: number | null;
}>();

defineEmits<{
  'add-item': [];
  'edit-line': [line: PpOrderLine];
  'delete-line': [line: PpOrderLine];
}>();
</script>

<style scoped>
.pp-request-order-lines-section__empty :deep(.tf-empty) {
  justify-content: flex-start;
  padding: 16px 8px 24px;
}
</style>