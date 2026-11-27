<template>
  <PpCustomerOrderLineList
    :lines="lines"
    :show-image="false"
    :show-name="false"
    :show-price="false"
  >
    <template #actions="{ line }">
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
  </PpCustomerOrderLineList>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import PpCustomerOrderLineList from '../../../components/order-lines/PpCustomerOrderLineList.vue';
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