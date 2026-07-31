<script setup lang="ts">
import LearnMoreHelpBtn from '@/modules/help/components/LearnMoreHelpBtn.vue';

defineEmits<{
  (e: 'register-stock'): void;
}>();
</script>

<template>
  <section class="row items-center justify-between q-col-gutter-md">
    <div class="col">
      <div class="text-overline text-primary">Thrift</div>
      <h1 class="text-h5 text-weight-bold q-my-none">Thrift Stock</h1>
    </div>
    <div class="col-auto row items-center q-gutter-sm">
      <LearnMoreHelpBtn guide-id="thrift_stock" tab="workflows" />
      <q-btn
        color="primary"
        unelevated
        no-caps
        icon="ph ph-plus"
        label="Register Stock"
        @click="$emit('register-stock')"
      />
    </div>
  </section>
</template>
