<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 520px; max-width: 90vw" class="bulk-paste-modal">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="text-h6 text-weight-bold flex items-center gap-2">
          <q-icon name="content_paste" color="primary" size="24px" />
          <span>Bulk Select Orders by Tracking / AWB</span>
        </div>
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-md">
        <div class="text-body2 text-grey-7 q-mb-sm">
          Paste Order Numbers, Tracking Numbers, or AWB Numbers copied from Courier CSV/Excel statements (separated by lines, spaces, or commas).
        </div>

        <q-input
          v-model="pastedText"
          type="textarea"
          rows="8"
          outlined
          placeholder="e.g.&#10;ORD-2026-0001&#10;AWB-99882211&#10;TRACK-1029384"
          autofocus
        />

        <!-- Match Status Feedback -->
        <div v-if="matchResult" class="q-mt-sm">
          <q-banner dense rounded class="bg-blue-1 text-primary border-blue">
            <template #avatar>
              <q-icon name="info" color="primary" />
            </template>
            <div>
              Found <strong>{{ matchResult.matched.length }}</strong> matching orders out of
              <strong>{{ matchResult.totalTokens }}</strong> pasted entries.
            </div>
            <div v-if="matchResult.unmatchedTokens.length > 0" class="text-caption text-negative q-mt-xs">
              Unmatched tokens ({{ matchResult.unmatchedTokens.length }}):
              {{ matchResult.unmatchedTokens.slice(0, 5).join(', ') }}
              <span v-if="matchResult.unmatchedTokens.length > 5">... and {{ matchResult.unmatchedTokens.length - 5 }} more</span>
            </div>
          </q-banner>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat label="Cancel" color="grey-7" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          icon="search"
          label="Process Paste"
          :disable="!pastedText.trim()"
          @click="handleProcessPaste"
        />
        <q-btn
          v-if="matchResult && matchResult.matched.length > 0"
          color="positive"
          unelevated
          icon="check_circle"
          label="Apply Selection"
          @click="applySelection"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { ShopOrder } from '../types';

const props = defineProps<{
  modelValue: boolean;
  availableOrders: ShopOrder[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'applySelection', matchedOrderIds: number[]): void;
}>();

const pastedText = ref('');
const matchResult = ref<{
  totalTokens: number;
  matched: number[];
  unmatchedTokens: string[];
} | null>(null);

watch(
  () => props.modelValue,
  (val) => {
    if (val) {
      pastedText.value = '';
      matchResult.value = null;
    }
  },
);

function handleProcessPaste() {
  const tokens = pastedText.value
    .split(/[\n,\t\s]+/)
    .map((t) => t.trim().toLowerCase())
    .filter(Boolean);

  const uniqueTokens = Array.from(new Set(tokens));

  const matchedIds: number[] = [];
  const unmatched: string[] = [];

  const orderMapByNo = new Map<string, ShopOrder>();
  const orderMapByAwb = new Map<string, ShopOrder>();

  props.availableOrders.forEach((order) => {
    orderMapByNo.set(order.order_no.toLowerCase(), order);
    if (order.courier_awb_number) {
      orderMapByAwb.set(order.courier_awb_number.toLowerCase(), order);
    }
  });

  uniqueTokens.forEach((token) => {
    const matched = orderMapByNo.get(token) || orderMapByAwb.get(token);
    if (matched) {
      matchedIds.push(matched.id);
    } else {
      unmatched.push(token);
    }
  });

  matchResult.value = {
    totalTokens: uniqueTokens.length,
    matched: Array.from(new Set(matchedIds)),
    unmatchedTokens: unmatched,
  };
}

function applySelection() {
  if (matchResult.value && matchResult.value.matched.length > 0) {
    emit('applySelection', matchResult.value.matched);
    emit('update:modelValue', false);
  }
}
</script>

<style scoped lang="scss">
.bulk-paste-modal {
  border-radius: 12px;
}
.border-blue {
  border: 1px solid rgba(25, 118, 210, 0.3);
}
</style>
