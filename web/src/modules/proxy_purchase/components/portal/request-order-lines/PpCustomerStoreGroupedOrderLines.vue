<template>
  <div class="pp-store-grouped-lines column q-gutter-y-md">
    <section
      v-for="section in sections"
      :key="section.key"
      class="pp-store-grouped-lines__section column q-gutter-y-xs"
    >
      <div
        v-if="section.lines.length"
        class="pp-store-grouped-lines__store text-weight-bold"
      >
        {{ section.label }}
      </div>
      <PpRequestInstructionCard
        v-if="section.instruction"
        :instruction="section.instruction"
        :show-actions="isDraft"
        :delete-loading="deletingInstructionStore === section.instruction.store"
        @edit="emit('edit-instruction', $event)"
        @delete="emit('delete-instruction', $event)"
      />
      <PpOrderLineListItem
        v-for="line in section.lines"
        :key="line.id"
        :line="line"
        :show-image="showItemImage"
        :show-name="showItemName"
        :show-price="showItemPrice"
      >
        <template v-if="isDraft" #actions>
          <TfBtn
            variant="icon"
            icon="ph ph-pencil"
            aria-label="Edit item"
            @click="emit('edit-line', line)"
          />
          <TfBtn
            variant="icon"
            icon="ph ph-trash"
            color="negative"
            aria-label="Delete item"
            :loading="deletingLineId === line.id"
            @click="emit('delete-line', line)"
          />
        </template>
      </PpOrderLineListItem>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import PpOrderLineListItem from '../../../components/order-lines/PpOrderLineListItem.vue';
import type { PpBucketInstruction, PpOrderLine } from '../../../types/ppPurchaseRequest';
import { groupPpRequestLinesByStore } from '../../../utils/ppBucketInstructions';
import PpRequestInstructionCard from './PpRequestInstructionCard.vue';

const props = withDefaults(
  defineProps<{
    lines: PpOrderLine[];
    instructions?: PpBucketInstruction[] | null;
    isDraft?: boolean;
    deletingLineId?: number | null;
    deletingInstructionStore?: string | null;
  }>(),
  {
    instructions: () => [],
    isDraft: false,
    deletingLineId: null,
    deletingInstructionStore: null,
  },
);

const emit = defineEmits<{
  'edit-line': [line: PpOrderLine];
  'delete-line': [line: PpOrderLine];
  'edit-instruction': [store: string];
  'delete-instruction': [store: string];
}>();

const sections = computed(() =>
  groupPpRequestLinesByStore(props.lines, props.instructions ?? []),
);

const showItemImage = computed(() => !props.isDraft);
const showItemName = computed(() => !props.isDraft);
const showItemPrice = computed(() => !props.isDraft);
</script>

<style scoped>
.pp-store-grouped-lines__store {
  font-size: 14px;
  line-height: 1.35;
  color: var(--tf-neutral-ink);
  padding: 0 2px;
}
</style>