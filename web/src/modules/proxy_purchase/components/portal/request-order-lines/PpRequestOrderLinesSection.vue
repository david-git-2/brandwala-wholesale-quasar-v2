<template>
  <section class="pp-request-order-lines-section" data-test="pp-request-order-lines-section">
    <div v-if="loading" class="pp-request-order-lines-section__loading">
      <q-skeleton type="rect" height="120px" />
    </div>

    <TfEmptyState
      v-else-if="showDraftEmpty"
      class="pp-request-order-lines-section__empty"
      title="No items yet"
      message="Add a product URL and quantity to build this request."
      icon="ph ph-link"
    >
      <TfBtn variant="primary" size="md" label="Add item" class="q-mt-sm" @click="$emit('add-item')" />
    </TfEmptyState>

    <TfEmptyState
      v-else-if="showPostedEmpty"
      class="pp-request-order-lines-section__empty"
      title="No items"
      message="This request has no lines."
      icon="ph ph-link"
    />

    <PpCustomerStoreGroupedOrderLines
      v-else-if="viewKey === 'customer_draft'"
      :lines="lines"
      :instructions="instructions"
      :is-draft="true"
      :deleting-line-id="deletingLineId"
      :deleting-instruction-store="deletingInstructionStore"
      @edit-line="$emit('edit-line', $event)"
      @delete-line="$emit('delete-line', $event)"
      @edit-instruction="$emit('edit-instruction', $event)"
      @delete-instruction="$emit('delete-instruction', $event)"
    />

    <PpCustomerStoreGroupedOrderLines
      v-else-if="viewKey === 'customer_posted'"
      :lines="lines"
      :instructions="instructions"
      :is-draft="false"
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
import { computed } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import type { PpBucketInstruction, PpOrderLine } from '../../../types/ppPurchaseRequest';
import { groupPpRequestLinesByStore } from '../../../utils/ppBucketInstructions';
import type { PpRequestOrderLinesViewKey } from '../../../types/ppRequestOrderLinesView';
import PpCustomerStoreGroupedOrderLines from './PpCustomerStoreGroupedOrderLines.vue';

const props = defineProps<{
  viewKey: PpRequestOrderLinesViewKey;
  lines: PpOrderLine[];
  instructions?: PpBucketInstruction[] | null;
  loading?: boolean;
  deletingLineId?: number | null;
  deletingInstructionStore?: string | null;
}>();

defineEmits<{
  'add-item': [];
  'edit-line': [line: PpOrderLine];
  'delete-line': [line: PpOrderLine];
  'edit-instruction': [store: string];
  'delete-instruction': [store: string];
}>();

const groupedSections = computed(() =>
  groupPpRequestLinesByStore(props.lines, props.instructions ?? []),
);

const showDraftEmpty = computed(
  () =>
    props.viewKey === 'customer_draft'
    && !props.loading
    && !props.lines.length
    && !groupedSections.value.length,
);

const showPostedEmpty = computed(
  () => props.viewKey === 'customer_posted' && !props.loading && !props.lines.length,
);
</script>

<style scoped>
.pp-request-order-lines-section__empty :deep(.tf-empty) {
  justify-content: flex-start;
  padding: 16px 8px 24px;
}
</style>