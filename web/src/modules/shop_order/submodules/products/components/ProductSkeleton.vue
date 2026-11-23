<template>
  <div class="row q-col-gutter-md products-card-grid">
    <div v-for="n in 12" :key="n" class="products-card-item">
      <q-card flat class="product-skeleton-card">
        <div class="product-image-skeleton-wrap">
          <q-skeleton type="QBadge" width="70px" height="18px" class="status-skeleton-badge" />
          <q-skeleton type="rect" class="product-image-skeleton" />
        </div>
        <q-card-section class="q-pt-sm q-pb-sm">
          <q-skeleton type="text" width="85%" height="16px" class="q-mb-xs" />
          <q-skeleton type="text" width="60%" height="16px" />
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>

<style scoped>
.product-skeleton-card {
  width: 200px;
  height: 100%;
  min-height: 260px;
  border-radius: 12px;
  overflow: hidden;
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.products-card-grid {
  justify-content: center;
  row-gap: 16px;
  column-gap: 16px;
}

.products-card-item {
  width: 200px;
  max-width: 200px;
  flex: 0 0 200px;
}

.product-image-skeleton-wrap {
  position: relative;
  height: 190px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.status-skeleton-badge {
  position: absolute;
  top: 8px;
  left: 8px;
  z-index: 2;
}

.product-image-skeleton {
  width: 100%;
  height: 100%;
}

@media (max-width: 599px) {
  .products-card-grid {
    margin-left: 0 !important;
    margin-right: 0 !important;
    margin-top: 0 !important;
    row-gap: 0px !important;
  }

  .products-card-grid > .products-card-item {
    width: 100%;
    max-width: 100%;
    flex: 0 0 100%;
    padding: 0 !important;
  }

  .product-skeleton-card {
    width: 100%;
    min-height: unset;
    height: auto;
    display: flex;
    flex-direction: row;
    align-items: center;
    border-radius: 0;
    border: none;
    border-bottom: 1px solid rgba(34, 56, 101, 0.08);
    background: #fff;
    padding: 12px 8px;
    margin-bottom: 0px;
  }

  .product-image-skeleton-wrap {
    width: 1.2in;
    height: 1.2in;
    flex: 0 0 1.2in;
    border-bottom: none;
    border-radius: 4px;
    overflow: hidden;
  }

  .product-skeleton-card :deep(.q-card__section) {
    flex: 1;
    padding: 0 0 0 12px !important;
    display: flex;
    flex-direction: column;
    justify-content: center;
  }
}
</style>
