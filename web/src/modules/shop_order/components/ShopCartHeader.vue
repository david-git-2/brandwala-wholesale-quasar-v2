<template>
  <section class="row items-center no-wrap q-col-gutter-sm">
    <div class="col min-width-0">
      <div class="row items-center q-gutter-x-sm no-wrap">
        <h1 class="text-subtitle1 text-weight-bold q-my-none ellipsis">
          <template v-if="showCartPicker">{{ $t('shop.cart_select_title') }}</template>
          <template v-else>{{ $t('shop.cart_title') }}</template>
        </h1>
        <q-chip
          v-if="!showCartPicker && itemCount > 0"
          dense
          size="sm"
          color="primary"
          text-color="white"
        >
          {{ itemCount }}
        </q-chip>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  showCartPicker: boolean;
  itemCount: number;
}>();
</script>
