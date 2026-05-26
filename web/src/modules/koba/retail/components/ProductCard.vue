<template>
  <q-card flat class="product-card">

    <!-- Image Area -->
    <div class="product-image-wrap">
      <!-- Details Info Button -->
      <q-btn
        flat round dense
        color="grey-7"
        icon="info"
        size="sm"
        class="info-btn"
        @click.stop="detailsOpen = true"
      />

      <!-- Brand chip -->
      <span v-if="brandLabel" class="brand-chip">{{ brandLabel }}</span>

      <img
        v-if="imageUrl"
        :src="imageUrl"
        :alt="product.name"
        class="product-img"
        loading="lazy"
        referrerpolicy="no-referrer"
        @error="onImageError"
      />
      <div v-else class="no-image-placeholder">
        <q-icon name="image_not_supported" size="28px" color="grey-5" />
        <span class="text-caption text-grey-5 q-mt-xs">No image</span>
      </div>
    </div>

    <!-- Content -->
    <q-card-section class="product-body">

      <!-- Name -->
      <div class="product-name ellipsis-2-lines q-mb-sm">{{ product.name }}</div>

      <!-- Price + Commission -->
      <div class="q-mb-sm">
        <div class="product-price">৳{{ formattedPrice }}</div>
        <div v-if="product.commission != null" class="text-caption text-grey-6 q-mt-xs">
          Commission: <span class="text-weight-medium text-grey-8">৳{{ formattedCommission }}</span>
        </div>
      </div>

      <!-- Add to cart / Remove -->
      <div v-if="!isAdminOrSuper" class="product-actions q-mt-auto">
        <template v-if="!inCart">
          <!-- Qty stepper -->
          <div class="qty-stepper">
            <q-btn
              flat dense round
              icon="remove"
              size="xs"
              :disable="qty <= step"
              @click.stop="qty = Math.max(step, qty - step)"
            />
            <span class="qty-value">{{ qty }}</span>
            <q-btn
              flat dense round
              icon="add"
              size="xs"
              @click.stop="qty += step"
            />
          </div>

          <q-btn
            unelevated
            no-caps
            dense
            color="primary"
            icon="shopping_cart"
            label="Add"
            class="add-btn"
            :loading="addBusy"
            @click.stop="onAdd"
          />
        </template>

        <template v-else>
          <div class="in-cart-label">
            <q-icon name="check_circle" color="positive" size="16px" />
            <span class="text-caption text-positive q-ml-xs">In cart</span>
          </div>
          <q-btn
            flat dense round
            color="negative"
            icon="delete"
            size="sm"
            :loading="removeBusy"
            @click.stop="onRemove"
          />
        </template>
      </div>

    </q-card-section>
  </q-card>

  <!-- Details Dialog -->
  <q-dialog v-model="detailsOpen">
    <q-card class="details-card">
      <q-card-section class="row items-center justify-between q-py-md q-px-lg">
        <div class="text-h6 text-weight-bold text-grey-9">Product Details</div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-separator />

      <q-card-section class="details-image-wrap">
        <img
          v-if="imageUrl"
          :src="imageUrl"
          :alt="product.name"
          class="details-image"
          referrerpolicy="no-referrer"
        />
        <div v-else class="no-image-placeholder q-py-lg">
          <q-icon name="image_not_supported" size="48px" color="grey-4" />
          <span class="text-caption text-grey-5 q-mt-xs">No image available</span>
        </div>
      </q-card-section>

      <q-card-section class="details-grid">
        <div class="detail-item detail-item-full">
          <div class="detail-label">Product Name</div>
          <div class="detail-value text-weight-semibold">{{ product.name }}</div>
        </div>

        <div class="detail-item">
          <div class="detail-label">Brand</div>
          <div class="detail-value">{{ product.brand || '—' }}</div>
        </div>

        <div class="detail-item">
          <div class="detail-label">Category</div>
          <div class="detail-value">{{ product.category || '—' }}</div>
        </div>

        <div class="detail-item">
          <div class="detail-label">SKU</div>
          <div class="detail-value">{{ product.sku || '—' }}</div>
        </div>

        <div class="detail-item">
          <div class="detail-label">Barcode</div>
          <div class="detail-value">{{ product.barcode || '—' }}</div>
        </div>

        <div class="detail-item">
          <div class="detail-label">Stock Status</div>
          <div class="detail-value">
            <q-badge
              :color="product.stock_quantity && product.stock_quantity > 0 ? 'positive' : 'negative'"
              :label="product.stock_quantity && product.stock_quantity > 0 ? 'In Stock' : 'Out of Stock'"
            />
            <span class="q-ml-sm text-weight-medium" v-if="product.stock_quantity != null">
              ({{ product.stock_quantity }} units)
            </span>
          </div>
        </div>

        <div class="detail-item">
          <div class="detail-label">Price (BDT)</div>
          <div class="detail-value text-primary text-weight-bold">৳{{ formattedPrice }}</div>
        </div>

        <div v-if="product.commission != null" class="detail-item">
          <div class="detail-label">Commission (BDT)</div>
          <div class="detail-value text-weight-semibold text-secondary">
            ৳{{ formattedCommission }}
            <span v-if="product.commission_percentage != null" class="text-caption text-grey-6 text-weight-regular q-ml-xs">
              ({{ product.commission_percentage }}%)
            </span>
          </div>
        </div>

        <div v-if="product.regular_price != null && Number(product.regular_price) !== Number(product.price || product.price_gbp)" class="detail-item">
          <div class="detail-label">Regular Price</div>
          <div class="detail-value text-strike text-grey-5">৳{{ Number(product.regular_price).toFixed(2) }}</div>
        </div>

        <div v-if="product.description" class="detail-item detail-item-full q-mt-xs">
          <div class="detail-label">Description</div>
          <div class="detail-value text-grey-8 text-weight-regular details-desc" v-html="parsedDescription">
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { marked } from 'marked'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useKobaCartStore } from 'src/modules/koba/retail/stores/kobaCartStore'

const authStore = useAuthStore()

const isAdminOrSuper = computed(() => {
  const role = authStore.matchedRole
  return role === 'admin' || role === 'superadmin'
})

interface KobaProduct {
  id: string
  name: string
  image_url?: string | null
  price_gbp?: number | null
  price?: number | null
  commission?: number | null
  commission_percentage?: number | null
  brand?: string | null
  category?: string | null
  case_size?: number | null
  minimum_quantity?: number | null
  sku?: string | null
  barcode?: string | null
  description?: string | null
  stock_quantity?: number | null
  in_stock?: boolean | null
  regular_price?: number | null
  sale_price?: number | null
}

const props = defineProps<{ product: KobaProduct }>()

const detailsOpen = ref(false)

const cartStore = useKobaCartStore()

// --- image ---
const imageFailed = ref(false)

function toGoogleDirectUrl(url: string | null | undefined): string {
  if (!url) return ''
  const m1 = url.match(/[?&]id=([^&]+)/)
  const m2 = url.match(/\/file\/d\/([^/]+)/)
  const fileId = m1?.[1] || m2?.[1]
  if (!fileId) return url
  return `https://lh3.googleusercontent.com/d/${fileId}`
}

const imageUrl = computed(() => {
  if (imageFailed.value || !props.product.image_url) return ''
  return toGoogleDirectUrl(props.product.image_url)
})

function onImageError() {
  imageFailed.value = true
}

// --- labels ---
const brandLabel = computed(() => props.product.brand?.trim() ?? '')

const formattedPrice = computed(() => {
  const price = props.product.price_gbp ?? props.product.price ?? 0
  return Number(price).toFixed(2)
})

const formattedCommission = computed(() => {
  return Number(props.product.commission ?? 0).toFixed(2)
})

// --- qty stepper ---
const step = computed(() => Math.max(1, props.product.case_size ?? props.product.minimum_quantity ?? 1))
const qty = ref(step.value)

// --- parsed description ---
const parsedDescription = ref('')

watch(
  () => props.product.description,
  async (newVal) => {
    if (!newVal) {
      parsedDescription.value = ''
      return
    }
    try {
      parsedDescription.value = await marked.parse(newVal)
    } catch {
      parsedDescription.value = newVal
    }
  },
  { immediate: true }
)

// --- cart state ---
const inCart = computed(() => {
  if (isAdminOrSuper.value) return false
  return cartStore.items.some((item) => String(item.koba_product_id) === String(props.product.id))
})

// --- actions ---
const addBusy = ref(false)
const removeBusy = ref(false)

async function onAdd() {
  addBusy.value = true
  try {
    await cartStore.addToCart(props.product, qty.value)
  } finally {
    addBusy.value = false
  }
}

async function onRemove() {
  removeBusy.value = true
  try {
    const cartItem = cartStore.items.find((item) => String(item.koba_product_id) === String(props.product.id))
    if (cartItem) {
      await cartStore.removeItem(cartItem.id)
    }
  } finally {
    removeBusy.value = false
  }
}
</script>

<style scoped>
.product-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  width: 280px;
  max-width: 100%;
  margin: 0 auto;
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.06);
  background: rgba(255, 255, 255, 0.95);
  overflow: hidden;
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}

.product-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.09) !important;
}

/* Image */
.product-image-wrap {
  position: relative;
  height: 160px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #ffffff;
  border-bottom: 1px solid rgba(0, 0, 0, 0.04);
  padding: 8px;
}

.product-img {
  max-height: 88%;
  max-width: 88%;
  object-fit: contain;
  transition: transform 0.3s ease;
}

.product-card:hover .product-img {
  transform: scale(1.04);
}

.no-image-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #9ca3af;
}

/* Brand chip */
.brand-chip {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 1;
  background: var(--bw-theme-primary, #1b4d3e);
  color: #ffffff;
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  padding: 3px 7px;
  border-radius: 6px;
}

/* Body */
.product-body {
  display: flex;
  flex-direction: column;
  flex: 1;
  padding: 10px 10px 12px;
}

.product-name {
  font-size: 12.5px;
  font-weight: 600;
  line-height: 1.4;
  color: #0f172a;
  min-height: 2.5em;
}

.product-price {
  font-size: 16px;
  font-weight: 800;
  color: #0f172a;
  line-height: 1;
}

/* Actions row */
.product-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  margin-top: 10px;
}

/* Qty stepper pill */
.qty-stepper {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 4px;
  border: 1px solid #e5e7eb;
  border-radius: 999px;
  background: #f9fafb;
}

.qty-value {
  min-width: 26px;
  text-align: center;
  font-size: 12px;
  font-weight: 700;
  color: #0f172a;
}

/* Add button */
.add-btn {
  border-radius: 999px;
  padding: 0 12px;
  font-size: 11px;
  font-weight: 700;
  min-height: 30px;
}

/* In-cart row */
.in-cart-label {
  display: flex;
  align-items: center;
}

/* Info button floating in image wrap */
.info-btn {
  position: absolute;
  top: 8px;
  left: 8px;
  z-index: 2;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
  background: rgba(255, 255, 255, 0.9);
  color: var(--bw-theme-primary, #1b4d3e) !important;
  transition: transform 0.2s ease, background-color 0.2s ease;
}

.info-btn:hover {
  transform: scale(1.08);
  background: #ffffff;
}

/* Details Dialog */
.details-card {
  min-width: 600px;
  max-width: 92vw;
  border-radius: 16px !important;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

.details-image-wrap {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 24px;
  background: #f8fafc;
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
}

.details-image {
  max-height: 180px;
  max-width: 100%;
  object-fit: contain;
}

.details-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
  padding: 20px 24px 28px;
}

.detail-item {
  min-width: 0;
}

.detail-item-full {
  grid-column: 1 / -1;
}

.detail-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.8px;
  color: #64748b;
  margin-bottom: 4px;
}

.detail-value {
  font-size: 13.5px;
  font-weight: 500;
  color: #1e293b;
  word-break: break-word;
  line-height: 1.4;
}

.details-desc {
  max-height: 140px;
  overflow-y: auto;
  padding-right: 6px;
}

.details-desc :deep(h1),
.details-desc :deep(h2),
.details-desc :deep(h3),
.details-desc :deep(h4),
.details-desc :deep(h5),
.details-desc :deep(h6) {
  margin-top: 8px;
  margin-bottom: 4px;
  font-weight: 600;
  font-size: 14px;
}

.details-desc :deep(ul),
.details-desc :deep(ol) {
  margin-top: 4px;
  margin-bottom: 8px;
  padding-left: 20px;
}

.details-desc :deep(li) {
  margin-bottom: 2px;
}

.details-desc::-webkit-scrollbar {
  width: 4px;
}

.details-desc::-webkit-scrollbar-track {
  background: transparent;
}

.details-desc::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 99px;
}

@media (max-width: 599px) {
  .details-card {
    min-width: 92vw;
  }
  .details-grid {
    grid-template-columns: 1fr;
    gap: 12px;
  }
}
</style>
