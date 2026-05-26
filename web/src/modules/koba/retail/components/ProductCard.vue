<template>
  <q-card flat class="product-card group shadow-1">
    <!-- Brand Chip -->
    <span v-if="brandLabel" class="brand-chip absolute-top-right z-top shadow-1">
      {{ brandLabel }}
    </span>

    <!-- Product Image -->
    <div class="product-image-container relative-position bg-white q-pa-sm flex flex-center">
      <img v-if="imageUrl" :src="imageUrl" :alt="product.name" class="product-img transition-3s" @error="onImageError" />
      <div v-else class="column items-center q-gutter-xs text-grey-6 text-caption">
        <q-icon name="image_not_supported" size="28px" />
        <span>No image</span>
      </div>
    </div>

    <!-- Details Section -->
    <q-card-section class="q-pa-sm col flex flex-column justify-between items-stretch">
      <div>
        <!-- Title -->
        <div class="product-title text-weight-bold text-subtitle2 ellipsis-2-lines q-mb-xs">
          {{ product.name }}
        </div>
        <!-- SKU / Barcode -->
        <div class="text-[10px] text-grey-6 q-mb-sm row items-center q-gutter-x-xs">
          <span>SKU: {{ product.sku || '-' }}</span>
          <span class="text-grey-4">|</span>
          <span>Barcode: {{ product.barcode || '-' }}</span>
        </div>
        <div class="text-[10px] text-grey-6 q-mb-sm">
          Origin: {{ product.country_of_origin || '-' }}
        </div>
        <div class="text-[10px] text-grey-6 q-mb-sm">
          Available Units: {{ product.available_units ?? product.stock_quantity ?? 0 }}
        </div>
      </div>

      <div class="q-mt-auto">
        <!-- Price -->
        <div v-if="props.showPrice" class="row items-baseline justify-between q-mb-xs">
          <span class="text-h6 text-weight-bolder text-primary">
            {{ formattedPrice }}
          </span>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'

interface Brand { name: string }
interface Category { name: string }
interface Product {
  id: string
  name: string
  sku?: string
  barcode?: string
  image_url?: string
  price: number
  price_gbp?: number
  price_bdt?: number
  currency?: string
  stock_quantity?: number
  brand?: Brand | null
  category?: Category | null
  country_of_origin?: string
  available_units?: number
}

const props = withDefaults(defineProps<{
  product: Product
  showPrice?: boolean
  priceField?: 'price_gbp' | 'price_bdt'
  priceSymbol?: string
}>(), {
  showPrice: true,
  priceField: 'price_gbp',
  priceSymbol: '£'
})

const authStore = useAuthStore()

const imageFailed = ref(false)

const isAdmin = computed(() => {
  const role = authStore.matchedRole?.toLowerCase()
  return role === 'admin' || role === 'superadmin'
})

const brandLabel = computed(() => props.product.brand?.name || '')

const imageUrl = computed(() => {
  if (imageFailed.value || !props.product.image_url) return ''
  return toDirectGoogleImageUrl(props.product.image_url)
})

const formattedPrice = computed(() => {
  const field = props.priceField === 'price_bdt' ? 'price_bdt' : 'price_gbp'
  const price = (props.product as any)[field] ?? props.product.price
  const symbol = props.priceSymbol ?? (props.priceField === 'price_bdt' ? '৳' : '£')
  return `${symbol}${Number(price || 0).toFixed(2)}`
})

function toDirectGoogleImageUrl(url: string | null | undefined): string {
  if (!url) return ''
  const m1 = url.match(/[?\&]id=([^\&]+)/)
  const m2 = url.match(/\/file\/d\/([^/]+)/)
  const fileId = m1?.[1] || m2?.[1]
  if (!fileId) return url
  return `https://lh3.googleusercontent.com/d/${fileId}`
}

const onImageError = () => {
  imageFailed.value = true
}
</script>

<script lang="ts">
export default { name: 'ProductCard' }
</script>

<style scoped>
.product-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(0, 0, 0, 0.06);
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}
.product-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 10px 20px rgba(0, 0, 0, 0.08) !important;
}
.product-image-container {
  height: 180px;
  background: #ffffff;
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
}
.product-img {
  max-height: 88%;
  max-width: 88%;
  object-fit: contain;
}
.product-card:hover .product-img {
  transform: scale(1.04);
}
.brand-chip {
  background: #0f766e;
  color: #ffffff;
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  padding: 3px 8px;
  border-radius: 6px;
  margin: 8px;
}
.product-title {
  color: #1f2937;
  font-size: 13px;
  line-height: 1.4;
  height: 2.8em;
}
</style>
