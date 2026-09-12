<template>
  <div v-if="initial" class="storefront-loading">
    <q-card flat bordered class="q-mb-md q-pa-md">
      <q-skeleton type="text" width="180px" height="28px" />
      <q-skeleton type="text" width="280px" class="q-mt-xs" />
    </q-card>
    <div class="bw-entity-grid">
      <q-card
        v-for="n in 8"
        :key="n"
        flat
        bordered
        class="product-card product-card-sk"
      >
        <div class="product-image-wrapper">
          <q-skeleton type="rect" class="full-width full-height" />
        </div>
        <div class="product-body">
          <q-skeleton type="text" width="80%" />
          <q-skeleton type="text" width="50%" class="q-mt-xs" />
          <q-skeleton type="text" width="30%" class="q-mt-md" />
        </div>
      </q-card>
    </div>
  </div>

  <div v-else class="bw-entity-grid q-mt-xs">
    <q-card
      v-for="n in 4"
      :key="'sk-more-' + n"
      flat
      bordered
      class="product-card product-card-sk"
    >
      <div class="product-image-wrapper">
        <q-skeleton type="rect" class="full-width full-height" />
      </div>
      <div class="product-body">
        <q-skeleton type="text" width="80%" />
        <q-skeleton type="text" width="50%" class="q-mt-xs" />
        <q-skeleton type="text" width="30%" class="q-mt-md" />
      </div>
    </q-card>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    initial?: boolean;
  }>(),
  {
    initial: false,
  },
);
</script>

<style scoped>
.product-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  border-radius: var(--bw-radius-md);
  background: color-mix(in srgb, var(--bw-theme-surface) 90%, var(--bw-shop-mauve, #996888) 10%);
  border-color: var(--bw-theme-border);
  color: var(--bw-theme-ink);
  overflow: hidden;
}

.product-image-wrapper {
  position: relative;
  height: 200px;
  flex: 0 0 200px;
  background: var(--bw-theme-surface);
  border-bottom: 1px solid var(--bw-theme-border);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
}

.product-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 10px 12px 12px;
}

@media (max-width: 599px) {
  .product-card {
    display: grid;
    grid-template-columns: 96px minmax(0, 1fr);
    align-items: start;
    column-gap: 10px;
    height: auto;
    margin: 0 0 10px;
    padding: 10px;
    border-radius: var(--bw-radius-md);
    border: none !important;
  }
  .product-image-wrapper {
    width: 96px;
    height: 96px;
    flex: none;
    margin: 0;
    padding: 0;
    border-bottom: none;
    border-radius: var(--bw-radius-md);
  }
  .product-body {
    padding: 0;
  }
}
</style>
