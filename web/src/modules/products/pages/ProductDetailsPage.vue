<template>
  <q-page class="q-pa-md product-details-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center q-gutter-sm">
          <q-badge color="primary" outline class="text-weight-medium">#{{ product?.id ?? '-' }}</q-badge>
          <div class="text-h6 text-weight-bold">{{ product?.name ?? 'Product Details' }}</div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="loading" />
    <div v-else-if="error" class="text-negative">{{ error }}</div>

    <q-card v-else-if="product" flat class="floating-surface shadow-1">
      <q-card-section>
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-4">
            <div class="details-image-wrap">
              <SmartImage
                :src="product.image_url"
                :alt="product.name ?? 'Product image'"
                imgClass="details-image"
                fallbackClass="details-image-fallback"
              />
            </div>
          </div>
          <div class="col-12 col-md-8">
            <div class="row q-col-gutter-sm">
              <div v-for="row in detailRows" :key="row.label" class="col-12 col-sm-6">
                <q-card flat bordered class="q-pa-sm">
                  <div class="text-caption text-grey-7">{{ row.label }}</div>
                  <div class="text-body2 text-weight-medium">{{ row.value }}</div>
                </q-card>
              </div>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import SmartImage from 'src/components/SmartImage.vue'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import type { Product } from '../types'
import { productService } from '../services/productService'

const route = useRoute()
const loading = ref(false)
const error = ref<string | null>(null)
const product = ref<Product | null>(null)

const detailRows = computed(() => {
  const item = product.value
  if (!item) return []

  return [
    { label: 'Product Code', value: item.product_code ?? '-' },
    { label: 'Barcode', value: item.barcode ?? '-' },
    { label: 'Brand', value: item.brand ?? '-' },
    { label: 'Category', value: item.category ?? '-' },
    { label: 'Price GBP', value: item.price_gbp == null ? '-' : `£${Number(item.price_gbp).toFixed(2)}` },
    { label: 'Available Units', value: item.available_units ?? '-' },
    { label: 'Minimum Order Quantity', value: item.minimum_order_quantity ?? '-' },
    { label: 'Country Of Origin', value: item.country_of_origin ?? '-' },
    { label: 'Tariff Code', value: item.tariff_code ?? '-' },
    { label: 'Languages', value: item.languages ?? '-' },
    { label: 'Batch Code / MFG Date', value: item.batch_code_manufacture_date ?? '-' },
    { label: 'Expire Date', value: item.expire_date ?? '-' },
    { label: 'Product Weight', value: item.product_weight ?? '-' },
    { label: 'Package Weight', value: item.package_weight ?? '-' },
    { label: 'Vendor', value: item.vendor_code ?? '-' },
    { label: 'Market', value: item.market_code ?? '-' },
    { label: 'Status', value: item.is_available ? 'Available' : 'Unavailable' },
    { label: 'Updated At', value: item.updated_at ?? '-' },
  ]
})

onMounted(async () => {
  const id = Number(route.params.id)
  if (!Number.isFinite(id) || id <= 0) {
    error.value = 'Invalid product id.'
    return
  }

  loading.value = true
  error.value = null

  try {
    const result = await productService.getProductById(id)
    if (!result.success) {
      error.value = result.error ?? 'Failed to load product.'
      return
    }
    product.value = result.data ?? null
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.product-details-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.details-image-wrap {
  border: 1px solid rgba(34, 56, 101, 0.12);
  border-radius: 12px;
  overflow: hidden;
  background: #fff;
  height: 320px;
}

.details-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.details-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #eef2f6;
}
</style>
