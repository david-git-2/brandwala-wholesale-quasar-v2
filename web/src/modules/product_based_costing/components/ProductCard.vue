<template>
  <q-card class="product-card">
    <div class="media-box">
      <template v-if="!imageHidden">
        <SmartImage
    :src="product.image_url"
    :alt="product.name || 'Product image'"
    img-class="product-card__image"
    fallback-class="fallback-image"
  />
      </template>

      <template v-else>
        <div class="fallback-image">
          No Image
        </div>
      </template>
    </div>

    <q-card-section>
      <div class="text-weight-bold" style="font-size: 12px; height: 70px;">
        {{ product.name || 'Unnamed Product' }}
      </div>

      <div class="text-h6 q-mt-sm">
        £{{ formatPrice(product.price_gbp) }}
      </div>

      <div class="q-mt-md text-body2">
        <div><strong>Brand:</strong> {{ product.brand || '-' }}</div>
        <div><strong>Country:</strong> {{ product.country_of_origin || '-' }}</div>
        <div><strong>Barcode:</strong> {{ product.barcode || '-' }}</div>
        <div><strong>Product Code:</strong> {{ product.product_code || '-' }}</div>
      </div>
    </q-card-section>

    <q-card-actions align="right">
      <q-btn
  :icon="isAlreadyAdded ? 'remove_shopping_cart' : 'local_grocery_store'"
  :color="isAlreadyAdded ? 'negative' : 'primary'"
  round
  flat
  unelevated
  @click="isAlreadyAdded ? handleDelete() : handleConsole()"
/>
    </q-card-actions>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'
import { useRoute } from 'vue-router'
import SmartImage from 'src/components/SmartImage.vue'
import type { Product } from 'src/modules/products/types'
const route = useRoute()
type ProductCardProduct = Product & {
  product_weight?: number | null
  package_weight?: number | null
}

const props = defineProps<{
  product: ProductCardProduct
}>()

const fallbackImage =
  'data:image/svg+xml;charset=UTF-8,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 800 450%27%3E%3Crect width=%27800%27 height=%27450%27 fill=%27%23f3efe9%27/%3E%3Ctext x=%27400%27 y=%27228%27 text-anchor=%27middle%27 font-family=%27Arial, sans-serif%27 font-size=%2732%27 fill=%27%23746655%27%3ENo Image%3C/text%3E%3C/svg%3E'

const imageAttempt = ref(0)
const imageHidden = ref(false)

const formatPrice = (price: number | null) => {
  if (price == null) return '0.00'
  return Number(price).toFixed(2)
}

const getDriveFileId = (url: string) => {
  const m1 = url.match(/[?&]id=([^&]+)/)
  const m2 = url.match(/\/file\/d\/([^/]+)/)
  return m1?.[1] || m2?.[1] || null
}

const toDirectGoogleImageUrl = (url: string | null | undefined) => {
  if (!url) return ''
  const fileId = getDriveFileId(url)
  if (!fileId) return url
  return `https://lh3.googleusercontent.com/d/${fileId}`
}

const imageCandidates = computed(() => {
  const original = props.product.image_url || ''
  const direct = toDirectGoogleImageUrl(original)

  const candidates = [direct, original, fallbackImage].filter(Boolean)

  return [...new Set(candidates)]
})

const currentImageSrc = computed(() => {
  return imageCandidates.value[imageAttempt.value] || fallbackImage
})

watch(
  () => [props.product.id, props.product.image_url],
  () => {
    imageAttempt.value = 0
    imageHidden.value = false
  },
  { immediate: true }
)

const costingFileStore = useProductBasedCostingStore()

const handleConsole = () => {
  console.log('Product:', props.product)
  void costingFileStore.createProductBasedCostingItem({
    name: props.product.name || '',
    image_url: props.product.image_url || '',
    quantity: 1,
    barcode: props.product.barcode || '',
    product_code: props.product.product_code || '',
    vendor_code: props.product.vendor_code || null,
    market_code: props.product.market_code || null,
    price_gbp: props.product.price_gbp || 0,
    product_weight: props.product.product_weight || 0,
    web_link: '',
    package_weight: props.product.package_weight || 0,
    status: 'pending',
    product_based_costing_file_id: route.params.id ? Number(route.params.id) : null,
    product_id: props.product.id,
    input_type: 'product_list',
  })
  console.log('Image candidates:', props.product.id)
  console.log('Current image src:', currentImageSrc.value)
}

const matchedCostingItem = computed(() => {
  return costingFileStore.costingItems.find((item) => {
    return (
      item.barcode === props.product.barcode &&
      item.product_code === props.product.product_code
    )
  })
})

const isAlreadyAdded = computed(() => !!matchedCostingItem.value)

const handleDelete = () => {
  if (!matchedCostingItem.value) return
  void costingFileStore.deleteProductBasedCostingItem(matchedCostingItem.value.id)
}
</script>

<style scoped>
.product-card {
  width: 100%;
  max-width: 320px;
  border-radius: 16px;
}

.media-box {
  width: 100%;
  height: 150px;
  background: #ffffff;
  border-top-left-radius: 16px;
  border-top-right-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.product-card__image {
  width: 88%;
  height: 88%;
  object-fit: contain;
  display: block;
}

.fallback-image {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #746655;
  background: #f3efe9;
  font-size: 0.95rem;
}


</style>
