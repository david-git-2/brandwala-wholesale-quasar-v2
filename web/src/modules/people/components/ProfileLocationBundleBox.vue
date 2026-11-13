<template>
  <div class="cash-bundle-box column q-pa-sm bg-white">
    <div class="row items-center no-wrap justify-between q-gutter-x-xs">
      <span class="text-caption text-weight-bold text-grey-8">{{ bundle.currencyCode }}</span>
      <TfBtn
        variant="icon"
        icon="ph ph-trash"
        color="negative"
        dense
        :aria-label="`Remove ${bundle.currencyCode} bundle`"
        :loading="deleting"
        :disable="deleting"
        @click="$emit('delete')"
      />
    </div>
    <div class="text-body2 text-weight-medium text-grey-9 q-mt-xs">
      {{ balanceLabel }}
    </div>
    <div
      v-if="showBooksRate"
      class="text-caption text-grey-7 q-mt-xs"
    >
      @ {{ bundle.booksRate }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import { formatAmountBdt } from 'src/utils/currency';
import type { ProfileCashbookBundleRow } from '../types/profileCashbookBundle';

const props = defineProps<{
  bundle: ProfileCashbookBundleRow;
  deleting?: boolean;
}>();

defineEmits<{ delete: [] }>();

const balanceLabel = computed(() => formatAmountBdt(props.bundle.amount));

const showBooksRate = computed(
  () =>
    props.bundle.currencyCode !== 'BDT'
    || Math.abs(props.bundle.booksRate - 1) > 0.000001,
);
</script>

<style scoped>
.cash-bundle-box {
  min-width: 6.5rem;
  border: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.1));
  border-radius: 8px;
}
</style>
