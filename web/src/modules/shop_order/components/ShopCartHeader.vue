<template>
  <section class="cart-page-header row items-center no-wrap q-col-gutter-sm">
    <div class="col min-width-0">
      <div class="row items-center q-gutter-x-sm no-wrap">
        <h1 class="cart-page-header__title text-subtitle1 text-weight-bold q-my-none ellipsis">
          <template v-if="showCartPicker">{{ $t('shop.cart_select_title') }}</template>
          <template v-else>{{ $t('shop.cart_title') }}</template>
        </h1>
        <q-chip
          v-if="!showCartPicker && itemCount > 0"
          dense
          size="sm"
          class="cart-page-header__count"
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

<style scoped>
.cart-page-header {
  min-height: 40px;
}

.cart-page-header__title {
  color: var(--bw-theme-ink, #1f2937);
  line-height: 1.25;
}

.cart-page-header__count {
  min-height: 22px;
  font-size: 11px;
  font-weight: 700;
  padding: 0 8px;
}
</style>
