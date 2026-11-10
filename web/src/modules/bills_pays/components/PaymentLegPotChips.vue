<template>
  <div class="payment-leg-pot-chips">
    <div class="text-caption text-grey-7">{{ legLabel }}</div>
    <div class="text-body2 text-weight-medium q-mt-xs">{{ partyName }}</div>
    <div v-if="loading" class="row justify-center q-py-sm">
      <q-spinner color="primary" size="1.5em" />
    </div>
    <div v-else-if="!options.length" class="text-caption text-grey-6 q-mt-sm">
      No cash points for this party yet.
    </div>
    <div v-else class="row q-gutter-xs q-mt-sm flex-wrap">
      <q-chip
        v-for="opt in options"
        :key="opt.value"
        clickable
        :ripple="false"
        :outline="modelValue !== opt.value"
        :color="modelValue === opt.value ? 'primary' : undefined"
        :text-color="modelValue === opt.value ? 'white' : undefined"
        @click="emit('update:modelValue', opt.value)"
      >
        {{ opt.label }}
      </q-chip>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { CashbookLegPotChipOption } from '../composables/useCashbookLegPots';

defineProps<{
  legLabel: string;
  partyName: string;
  options: CashbookLegPotChipOption[];
  modelValue: number | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: number];
}>();
</script>

<style scoped lang="scss">
.payment-leg-pot-chips {
  padding: var(--tf-space-sm, 8px) 0;
  border-bottom: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.12));
}
</style>
