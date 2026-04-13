<template>
  <div class="product-grid">
    <q-card
      v-for="item in items"
      :key="item.id"
      class="product-card"
      flat
      bordered
    >
      <div class="image-wrapper">
        <SmartImage
          :src="item.image_url"
          :alt="item.name"
          img-class="product-image"
          fallback-class="product-image-fallback"
        />

        <q-btn
          v-if="showInfo"
          class="info-btn"
          round
          dense
          color="white"
          text-color="primary"
          icon="info"
          @click="openDetails(item)"
        />
      </div>

      <q-card-section class="card-content">
        <div class="product-name ellipsis-3-lines">
          {{ item.name }}
        </div>

        <div class="product-meta q-mt-sm">
          <div>Origin: {{ item.country_of_origin || '-' }}</div>
          <div>Available Units: {{ item.available_units ?? 0 }}</div>
          <div v-if="showPrice" class="product-price">Price: £{{ formatPrice(item.price_gbp) }}</div>
        </div>
      </q-card-section>

      <q-space />

      <q-card-section
        v-if="showCart"
        class="q-pt-none"
      >
        <div class="cart-row">
          <div class="qty-box">
            <q-btn
              flat
              round
              dense
              icon="remove"
              @click="decrementQty(item)"
            />

            <div class="quantity-value">
              {{ getQty(item) }}
            </div>

            <q-btn
              flat
              round
              dense
              icon="add"
              @click="incrementQty(item)"
            />
          </div>

          <q-btn
            round
            color="primary"
            icon="shopping_cart"
            @click="handleAddToCart(item)"
          />
        </div>

        <div class="moq-text q-mt-xs">
          MOQ: {{ getStep(item) }}
        </div>
      </q-card-section>
    </q-card>
  </div>

  <q-dialog v-model="detailsOpen">
    <q-card class="details-card">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6">Product Details</div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-separator />

      <template v-if="selectedItem">
        <q-card-section class="details-image-wrap">
          <SmartImage
            :src="selectedItem.image_url"
            :alt="selectedItem.name"
            img-class="details-image"
            fallback-class="details-image-fallback"
          />
        </q-card-section>

        <q-card-section class="details-grid">
          <div class="detail-item">
            <div class="detail-label">Name</div>
            <div class="detail-value">{{ selectedItem.name || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Brand</div>
            <div class="detail-value">{{ selectedItem.brand || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Barcode</div>
            <div class="detail-value">{{ selectedItem.barcode || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Category</div>
            <div class="detail-value">{{ selectedItem.category || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Languages</div>
            <div class="detail-value">{{ selectedItem.languages || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Market Code</div>
            <div class="detail-value">{{ selectedItem.market_code || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Tariff Code</div>
            <div class="detail-value">{{ selectedItem.tariff_code || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Vendor Code</div>
            <div class="detail-value">{{ selectedItem.vendor_code || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Product Code</div>
            <div class="detail-value">{{ selectedItem.product_code || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Country of Origin</div>
            <div class="detail-value">{{ selectedItem.country_of_origin || '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Available</div>
            <div class="detail-value">{{ selectedItem.is_available ? 'Yes' : 'No' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Available Units</div>
            <div class="detail-value">{{ selectedItem.available_units ?? 0 }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Minimum Order Quantity</div>
            <div class="detail-value">{{ selectedItem.minimum_order_quantity ?? '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Package Weight</div>
            <div class="detail-value">{{ selectedItem.package_weight ?? '-' }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Product Weight</div>
            <div class="detail-value">{{ selectedItem.product_weight ?? '-' }}</div>
          </div>

          <div
            v-if="showPrice"
            class="detail-item"
          >
            <div class="detail-label">Price GBP</div>
            <div class="detail-value">£{{ formatPrice(selectedItem.price_gbp) }}</div>
          </div>

          <div class="detail-item">
            <div class="detail-label">Expire Date</div>
            <div class="detail-value">{{ selectedItem.expire_date || '-' }}</div>
          </div>

          <div class="detail-item detail-item-full">
            <div class="detail-label">Batch / Manufacture Date</div>
            <div class="detail-value">{{ selectedItem.batch_code_manufacture_date || '-' }}</div>
          </div>
        </q-card-section>
      </template>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import SmartImage from 'src/components/SmartImage.vue'
import { ref } from 'vue'

type ProductItem = {
  id: number
  name: string
  brand?: string | null
  barcode?: string | null
  category?: string | null
  image_url?: string | null
  languages?: string | null
  price_gbp?: number | null
  tenant_id?: number
  created_at?: string
  updated_at?: string
  expire_date?: string | null
  market_code?: string | null
  tariff_code?: string | null
  vendor_code?: string | null
  is_available?: boolean
  product_code?: string | null
  package_weight?: number | null
  product_weight?: number | null
  available_units?: number | null
  country_of_origin?: string | null
  minimum_order_quantity?: number | null
  batch_code_manufacture_date?: string | null
}

const props = withDefaults(defineProps<{
  items: ProductItem[]
  showPrice?: boolean
  showCart?: boolean
  showInfo?: boolean
  storeId?: number | null
}>(), {
  showPrice: true,
  showCart: true,
  showInfo: true,
  storeId: null,
})

const detailsOpen = ref(false)
const selectedItem = ref<ProductItem | null>(null)
const quantities = ref<Record<number, number>>({})

const getStep = (item: ProductItem) => {
  const moq = Number(item.minimum_order_quantity ?? 1)
  return moq > 0 ? moq : 1
}

const getQty = (item: ProductItem) => {
  if (!quantities.value[item.id]) {
    quantities.value[item.id] = getStep(item)
  }
  return quantities.value[item.id]
}

const incrementQty = (item: ProductItem) => {
  const step = getStep(item)
  const current = getQty(item)
  quantities.value[item.id] = current + step
}

const decrementQty = (item: ProductItem) => {
  const step = getStep(item)
  const current = getQty(item)
  const next = current - step
  quantities.value[item.id] = next < step ? step : next
}

const openDetails = (item: ProductItem) => {
  selectedItem.value = item
  detailsOpen.value = true
}

const handleAddToCart = (item: ProductItem) => {
  const quantity = getQty(item)

  console.log('add to cart', {
    store_id: props.storeId,
    ...item,
    quantity,
  })
}

const formatPrice = (value?: number | null) => {
  if (value == null) return '0.00'
  return Number(value).toFixed(2)
}

const showPrice = props.showPrice
const showCart = props.showCart
</script>

<style scoped>
.product-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  justify-content: center;
}

.product-card {
  width: 280px;
  min-width: 280px;
  max-width: 280px;
  display: flex;
  flex-direction: column;
  border-radius: 12px;
  overflow: hidden;
}

.image-wrapper {
  position: relative;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 12px;
  background: #f5f5f5;
  border-top-left-radius: 12px;
  border-top-right-radius: 12px;
  overflow: hidden;
}

:deep(.product-image) {
  width: 100%;
  height: 180px;
  object-fit: contain;
  display: block;
}

:deep(.product-image-fallback) {
  width: 100%;
  height: 180px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #757575;
}

.info-btn {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 2;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  background: white;
}

.card-content {
  padding-top: 12px;
}

.product-name {
  min-height: 56px;
  font-size: 13px;
  line-height: 1.35;
  font-weight: 400;
  color: #333;
}

.product-meta {
  line-height: 1.7;
  font-size: 13px;
  font-weight: 400;
  color: #555;
}

.product-price {
  font-size: 18px;
  font-weight: 700;
  color: #111;
}

.cart-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.qty-box {
  display: flex;
  align-items: center;
  gap: 6px;
}

.quantity-value {
  min-width: 36px;
  text-align: center;
  font-weight: 500;
  font-size: 14px;
}

.moq-text {
  font-size: 12px;
  color: #777;
}

.ellipsis-3-lines {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.details-card {
  min-width: 720px;
  max-width: 92vw;
}

.details-image-wrap {
  display: flex;
  justify-content: center;
  padding-bottom: 8px;
}

:deep(.details-image) {
  width: 100%;
  max-width: 260px;
  height: 220px;
  object-fit: contain;
  display: block;
}

:deep(.details-image-fallback) {
  width: 100%;
  max-width: 260px;
  height: 220px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #757575;
  background: #f5f5f5;
}

.details-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px 18px;
}

.detail-item {
  min-width: 0;
}

.detail-item-full {
  grid-column: 1 / -1;
}

.detail-label {
  font-size: 12px;
  color: #777;
  margin-bottom: 4px;
}

.detail-value {
  font-size: 14px;
  font-weight: 400;
  color: #222;
  word-break: break-word;
}

@media (max-width: 700px) {
  .details-card {
    min-width: 92vw;
  }

  .details-grid {
    grid-template-columns: 1fr;
  }
}
</style>
