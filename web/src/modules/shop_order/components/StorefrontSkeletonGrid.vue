<template>
  <div v-if="initial" class="storefront-loading">
    <q-card flat bordered class="q-mb-md q-pa-md">
      <q-skeleton type="text" width="180px" height="28px" />
      <q-skeleton type="text" width="280px" class="q-mt-xs" />
    </q-card>
    <div class="row q-col-gutter-md product-grid">
      <div v-for="n in 8" :key="n" class="col-xs-12 col-sm-6 col-md-4 col-lg-3 product-grid-item">
        <q-card flat bordered class="product-card product-card-sk">
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
  </div>

  <div v-else class="row q-col-gutter-md product-grid q-mt-xs">
    <div v-for="n in 4" :key="'sk-more-' + n" class="col-xs-12 col-sm-6 col-md-4 col-lg-3 product-grid-item">
      <q-card flat bordered class="product-card product-card-sk">
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
@media (min-width: 600px) {
  .product-grid {
    display: grid !important;
    grid-template-columns: repeat(auto-fill, minmax(220px, 250px));
    justify-content: center;
    gap: 16px;
    margin: 0 !important;
  }
  .product-grid-item {
    width: 100% !important;
    max-width: none !important;
    padding: 0 !important;
  }
}

.product-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  border-radius: 20px;
  background: color-mix(in srgb, #ffffff 90%, var(--bw-shop-mauve, #996888) 10%);
  border-color: var(--bw-theme-border, rgb(42 43 42 / 0.1));
  color: var(--bw-theme-ink, #2a2b2a);
  overflow: hidden;
}

.product-image-wrapper {
  position: relative;
  height: 200px;
  flex: 0 0 200px;
  background: #ffffff;
  border-bottom: 1px solid var(--bw-theme-border, rgb(42 43 42 / 0.06));
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
  .product-grid {
    margin-left: 0 !important;
    margin-right: 0 !important;
    row-gap: 0 !important;
  }
  .product-grid-item {
    padding: 0 !important;
  }
  .product-card {
    display: grid;
    grid-template-columns: 96px minmax(0, 1fr);
    align-items: start;
    column-gap: 10px;
    height: auto;
    margin: 0 0 10px;
    padding: 10px;
    border-radius: 16px;
    border: none !important;
  }
  .product-image-wrapper {
    width: 96px;
    height: 96px;
    flex: none;
    margin: 0;
    padding: 0;
    border-bottom: none;
    border-radius: 12px;
  }
  .product-body {
    padding: 0;
  }
}
</style>
