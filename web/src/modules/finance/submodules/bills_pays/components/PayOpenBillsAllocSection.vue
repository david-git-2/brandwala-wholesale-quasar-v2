<template>
  <div v-if="rows.length" class="pay-alloc-section q-gutter-y-xs">
    <div class="row items-center justify-between">
      <div class="text-caption text-weight-medium text-grey-8">Allocate to bills (optional)</div>
      <q-btn flat dense no-caps size="sm" label="Oldest first" @click="emit('fillOldest')" />
    </div>
    <q-list dense bordered separator class="rounded-borders">
      <q-item v-for="bill in rows" :key="bill.id" dense>
        <q-item-section side>
          <q-checkbox v-model="bill.selected" dense />
        </q-item-section>
        <q-item-section>
          <q-item-label>{{ bill.invoice_no }}</q-item-label>
          <q-item-label caption>Due {{ formatAmountBdt(bill.due_amount) }}</q-item-label>
        </q-item-section>
        <q-item-section side>
          <q-input
            v-model.number="bill.allocAmount"
            dense
            outlined
            type="number"
            min="0"
            :max="bill.due_amount"
            class="pay-alloc-input"
            :disable="!bill.selected"
          />
        </q-item-section>
      </q-item>
    </q-list>
  </div>
</template>

<script setup lang="ts">
import { formatAmountBdt } from 'src/utils/currency';
import type { OpenBillAllocRow } from '../composables/useOpenBillAllocations';

defineProps<{
  rows: OpenBillAllocRow[];
}>();

const emit = defineEmits<{
  fillOldest: [];
}>();
</script>

<style scoped>
.pay-alloc-input {
  width: 96px;
}
</style>
