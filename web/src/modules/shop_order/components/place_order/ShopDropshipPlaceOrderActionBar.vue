<template>
  <q-card
    flat
    bordered
    class="dropship-wizard-actions"
    :class="{ 'dropship-wizard-actions--sticky': sticky }"
  >
    <q-card-section class="q-pa-sm row items-center justify-end q-gutter-sm">
      <q-btn
        v-if="showBack"
        flat
        no-caps
        size="md"
        color="primary"
        class="dropship-wizard-actions__btn"
        icon="ph ph-arrow-left"
        :label="$t('shop.go_back')"
        @click="$emit('back')"
      />
      <TfBtn
        v-if="showNext"
        size="md"
        class="dropship-wizard-actions__btn dropship-wizard-actions__btn--primary"
        icon-right="ph ph-arrow-right"
        :label="$t('shop.next')"
        :disable="!canNext"
        @click="$emit('next')"
      />
      <TfBtn
        v-if="showPlaceOrder"
        size="md"
        class="dropship-wizard-actions__btn dropship-wizard-actions__btn--primary"
        icon-right="ph ph-check"
        :label="$t('shop.place_order')"
        :disable="!canPlaceOrder"
        :loading="isSubmitting"
        @click="$emit('place-order')"
      />
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';

withDefaults(
  defineProps<{
    showBack?: boolean;
    showNext?: boolean;
    showPlaceOrder?: boolean;
    canNext?: boolean;
    canPlaceOrder?: boolean;
    isSubmitting?: boolean;
    sticky?: boolean;
  }>(),
  {
    showBack: false,
    showNext: true,
    showPlaceOrder: false,
    canNext: true,
    canPlaceOrder: false,
    isSubmitting: false,
    sticky: false,
  },
);

defineEmits<{
  (e: 'back'): void;
  (e: 'next'): void;
  (e: 'place-order'): void;
}>();
</script>

<style scoped>
.dropship-wizard-actions__btn {
  flex: 0 0 auto;
  width: auto;
  min-width: 7rem;
  max-width: 14rem;
  min-height: 2.75rem;
  padding-left: 1.15rem;
  padding-right: 1.15rem;
  font-size: 0.9375rem;
  font-weight: 600;
}

.dropship-wizard-actions__btn--primary {
  min-width: 8.5rem;
}

.dropship-wizard-actions--sticky {
  position: sticky;
  bottom: 0;
  z-index: 2;
  padding-bottom: env(safe-area-inset-bottom, 0px);
  background: var(--tf-theme-surface, #fff);
}
</style>