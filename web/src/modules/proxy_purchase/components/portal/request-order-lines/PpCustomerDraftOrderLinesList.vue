<template>
  <div class="pp-customer-draft-order-lines column q-gutter-y-xs">
    <PpOrderLineCustomerCard v-for="line in lines" :key="line.id" :line="line">
      <template #actions>
        <TfBtn
          variant="icon"
          icon="ph ph-pencil"
          aria-label="Edit item"
          @click="$emit('edit', line)"
        />
        <TfBtn
          variant="icon"
          icon="ph ph-trash"
          color="negative"
          aria-label="Delete item"
          :loading="deletingLineId === line.id"
          @click="$emit('delete', line)"
        />
      </template>
    </PpOrderLineCustomerCard>
  </div>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import PpOrderLineCustomerCard from './PpOrderLineCustomerCard.vue';
import type { PpOrderLine } from '../../../types/ppPurchaseRequest';

defineProps<{
  lines: PpOrderLine[];
  deletingLineId?: number | null;
}>();

defineEmits<{
  edit: [line: PpOrderLine];
  delete: [line: PpOrderLine];
}>();
</script>