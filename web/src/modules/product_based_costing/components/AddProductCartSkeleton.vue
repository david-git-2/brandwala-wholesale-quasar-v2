<template>
  <div class="add-product-cart-grid">
    <q-card v-for="n in 8" :key="n" flat bordered class="add-product-cart-card-sk">
      <q-skeleton type="rect" class="add-product-cart-card-sk__image" />
      <q-card-section class="q-pt-sm q-pb-sm">
        <q-skeleton type="text" width="90%" />
        <q-skeleton type="text" width="60%" class="q-mt-xs" />
        <q-skeleton type="text" width="75%" class="q-mt-xs" />
        <q-skeleton type="QBtn" width="100%" height="32px" class="q-mt-sm" />
      </q-card-section>
    </q-card>
  </div>
</template>

<style scoped>
.add-product-cart-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 1rem;
}

.add-product-cart-card-sk {
  border-radius: var(--bw-radius-md, 12px);
  overflow: hidden;
}

.add-product-cart-card-sk__image {
  height: 180px;
}
</style>
