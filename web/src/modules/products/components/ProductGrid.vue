<template>
  <div>
    <div v-if="error" class="text-negative">error: {{ error?.message }}</div>

    <q-banner v-else-if="!products.length" class="bg-grey-2 text-grey-8">
      No products found.
    </q-banner>

    <div v-else class="row q-col-gutter-md products-card-grid">
      <div v-for="product in products" :key="product.id" class="products-card-item">
        <q-card flat class="floating-surface shadow-1 product-card">
          <div class="product-image-wrap">
            <q-chip
              dense
              square
              :color="product.is_available ? 'green-1' : 'red-1'"
              :text-color="product.is_available ? 'green-9' : 'red-9'"
              size="xs"
              class="status-badge text-weight-bold q-ma-none"
            >
              {{ product.is_available ? 'Available' : 'Not Available' }}
            </q-chip>
            <SmartImage
              v-model:src="product.image_url"
              :product-id="product.id"
              :alt="product.name ?? 'Product image'"
              imgClass="product-image"
              fallbackClass="product-image-fallback"
            />
          </div>

          <q-card-section class="q-pt-sm q-pb-sm">
            <div class="product-name cursor-pointer" @click="emit('selectProduct', product.id)">
              {{ product.name ?? '-' }}
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <div v-if="totalPages > 1" class="row justify-center q-mt-md">
      <q-pagination
        :model-value="page"
        :max="totalPages"
        :max-pages="$q.screen.xs ? 4 : 8"
        boundary-numbers
        direction-links
        @update:model-value="(val) => emit('update:page', val)"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { useQuasar } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import type { Product } from '../types';

defineProps<{
  products: Product[];
  isLoading: boolean;
  error: Error | null;
  page: number;
  totalPages: number;
}>();

const emit = defineEmits<{
  (e: 'update:page', page: number): void;
  (e: 'selectProduct', productId: number): void;
}>();

const $q = useQuasar();
</script>

<style scoped>
.product-card {
  width: 200px;
  height: 100%;
  min-height: 260px;
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

.product-image-wrap {
  position: relative;
  height: 190px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
  background: #fff;
}

.status-badge {
  position: absolute;
  top: 8px;
  left: 8px;
  z-index: 2;
  font-weight: 700;
}

.product-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

.product-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #eef2f6;
}

.product-name {
  min-height: 52px;
  font-size: 13px;
  font-weight: 400;
  line-height: 1.3;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
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

  .product-card {
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

  .product-image-wrap {
    width: 1.2in;
    height: 1.2in;
    flex: 0 0 1.2in;
    border-bottom: none;
    border-right: none;
    border-radius: 4px;
    overflow: hidden;
  }

  .product-image-fallback {
    border-radius: 4px;
  }

  .product-card :deep(.q-card__section) {
    flex: 1;
    padding: 0 0 0 12px !important;
    display: flex;
    align-items: center;
  }

  .product-name {
    min-height: unset;
    font-size: 13px;
    line-height: 1.35;
    -webkit-line-clamp: 3;
    margin: 0;
  }
}
</style>
