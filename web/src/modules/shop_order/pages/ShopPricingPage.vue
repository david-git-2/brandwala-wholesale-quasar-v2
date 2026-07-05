<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">Shops</div>
              <h1 class="text-h5 q-my-none">Shop Pricing: {{ shopName }}</h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Manage product listings, set sell/dropship pricing, and configure display quantities.
              </p>
            </div>
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            icon="add"
            label="Add Product Listing"
            unelevated
            @click="openPickDialog"
          />
        </div>
      </section>

      <!-- Toolbar / Search -->
      <section class="row items-center q-col-gutter-md">
        <div class="col-12 col-sm-5">
          <q-input
            v-model="search"
            clearable
            dense
            outlined
            placeholder="Search listed products…"
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
          </q-input>
        </div>
      </section>

      <!-- Error banner -->
      <q-banner v-if="store.error" class="text-white bg-negative" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" label="Dismiss" @click="store.clearError()" />
        </template>
      </q-banner>

      <!-- Listings Table -->
      <q-card flat bordered>
        <q-card-section v-if="store.loadingListings" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          Loading product listings…
        </q-card-section>

        <q-card-section v-else-if="filteredListings.length === 0" class="text-grey-6 text-center q-pa-xl">
          <q-icon name="list_alt" size="48px" class="q-mb-sm block" />
          No products listed on this shop. Click "Add Product Listing" to start.
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="filteredListings"
          :columns="columns"
          :pagination="{ rowsPerPage: 25 }"
          :dense="$q.screen.lt.md"
        >
          <!-- Product info -->
          <template #body-cell-product_name="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <q-avatar size="36px" rounded class="q-mr-sm bg-grey-3">
                  <q-img v-if="props.row.product_image_url" :src="props.row.product_image_url" />
                  <q-icon v-else name="image" color="grey-6" />
                </q-avatar>
                <div class="ellipsis" style="max-width: 250px;">
                  <div class="text-weight-bold text-grey-9">{{ props.row.product_name }}</div>
                  <div class="text-caption text-grey-6">{{ props.row.product_brand }} | {{ props.row.product_category }}</div>
                </div>
              </div>
            </q-td>
          </template>

          <!-- Sell Price -->
          <template #body-cell-sell_price="props">
            <q-td :props="props">
              <div class="text-weight-medium text-grey-9">
                {{ formatMoney(props.row.sell_price_amount, props.row.sell_price_currency_id) }}
              </div>
            </q-td>
          </template>

          <!-- Dropship floor -->
          <template #body-cell-min_sell_price="props">
            <q-td :props="props">
              <div v-if="shopType === 'dropship'" class="text-grey-8">
                {{ formatMoney(props.row.minimum_sell_price_amount, props.row.minimum_sell_price_currency_id) }}
              </div>
              <div v-else class="text-grey-4">—</div>
            </q-td>
          </template>

          <!-- Display Qty -->
          <template #body-cell-display_quantity="props">
            <q-td :props="props" class="text-center">
              <div v-if="props.row.display_quantity_override !== null" class="text-primary text-weight-bold">
                {{ props.row.display_quantity_override }}
                <q-tooltip>Marketing override (Actual: {{ props.row.available_to_sell }})</q-tooltip>
              </div>
              <div v-else class="text-grey-8">
                {{ props.row.available_to_sell }}
              </div>
            </q-td>
          </template>

          <!-- Visibility -->
          <template #body-cell-show_quantity="props">
            <q-td :props="props" class="text-center">
              <q-badge :color="props.row.show_quantity === null ? 'grey-5' : (props.row.show_quantity ? 'positive' : 'negative')">
                {{ props.row.show_quantity === null ? 'Inherit' : (props.row.show_quantity ? 'Show' : 'Hide') }}
              </q-badge>
            </q-td>
          </template>

          <!-- Status -->
          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-icon
                :name="props.row.is_active ? 'check_circle' : 'cancel'"
                :color="props.row.is_active ? 'positive' : 'grey-5'"
                size="20px"
              />
            </q-td>
          </template>

          <!-- Actions -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn
                flat
                round
                dense
                icon="edit"
                color="primary"
                @click="openEditListing(props.row)"
              >
                <q-tooltip>Edit settings</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <!-- Candidate Allocation Pick Dialog -->
    <AllocationPickDialog
      v-model="pickDialogOpen"
      :candidates="store.candidates"
      @pick="onAllocationPicked"
    />

    <!-- Create / Edit Listing Form Dialog -->
    <q-dialog v-model="editDialogOpen">
      <q-card style="width: 500px; max-width: 90vw;">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">{{ form.id ? 'Edit Listing' : 'Add Listing' }}</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-gutter-y-md q-pt-md">
          <div class="bg-grey-1 q-pa-md rounded-borders">
            <div class="text-weight-bold text-grey-8">{{ selectedProductName }}</div>
            <div class="text-caption text-grey-6">{{ selectedProductDetails }}</div>
          </div>

          <!-- Sell Price -->
          <div class="row q-col-gutter-md">
            <div class="col-7">
              <q-input
                v-model.number="form.sell_price_amount"
                type="number"
                step="0.01"
                label="Sell Price Amount"
                outlined
                dense
                :rules="[val => !!val || 'Amount is required']"
              />
            </div>
            <div class="col-5">
              <q-select
                v-model="form.sell_price_currency_id"
                label="Currency"
                outlined
                dense
                emit-value
                map-options
                option-value="id"
                option-label="code"
                :options="store.currencies"
                :rules="[val => !!val || 'Currency is required']"
              />
            </div>
          </div>

          <!-- Minimum Sell Price (dropship only) -->
          <div v-if="shopType === 'dropship'" class="row q-col-gutter-md">
            <div class="col-7">
              <q-input
                v-model.number="form.minimum_sell_price_amount"
                type="number"
                step="0.01"
                label="Minimum Dropship Price"
                outlined
                dense
                :rules="[val => !!val || 'Min dropship floor amount is required']"
              />
            </div>
            <div class="col-5">
              <q-select
                v-model="form.minimum_sell_price_currency_id"
                label="Currency"
                outlined
                dense
                emit-value
                map-options
                option-value="id"
                option-label="code"
                :options="store.currencies"
                :rules="[val => !!val || 'Currency is required']"
              />
            </div>
          </div>

          <!-- Display Qty Override -->
          <div class="row q-col-gutter-md">
            <div class="col-12">
              <q-input
                v-model.number="form.display_quantity_override"
                type="number"
                label="Display Quantity Override"
                outlined
                dense
                clearable
                placeholder="Inherits available quantity"
              />
            </div>
          </div>

          <!-- Show Qty Override -->
          <div class="row q-col-gutter-md">
            <div class="col-12">
              <q-select
                v-model="form.show_quantity"
                label="Show Quantity to Customer"
                outlined
                dense
                emit-value
                map-options
                :options="[
                  { label: 'Inherit Shop Settings', value: null },
                  { label: 'Force Show', value: true },
                  { label: 'Force Hide', value: false }
                ]"
              />
            </div>
          </div>

          <!-- Active Switch -->
          <q-toggle
            v-model="form.is_active"
            label="Listing Active"
            color="primary"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md border-top bg-grey-1">
          <q-btn flat label="Cancel" color="grey-7" v-close-popup />
          <q-btn
            unelevated
            label="Save Listing"
            color="primary"
            :loading="store.saving"
            @click="onSaveListing"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShopPricingStore } from '../stores/shopPricingStore'
import AllocationPickDialog from '../components/AllocationPickDialog.vue'
import type { ShopProductListing, CandidateAllocation, UpsertListingPayload } from '../types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const store = useShopPricingStore()

const tenantId = computed(() => authStore.tenantId as number)
const shopId = computed(() => Number(route.params.shopId))
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '')

const shopName = ref<string>('')
const shopType = ref<string>('')
const search = ref<string>('')

// Form & Dialog controls
const pickDialogOpen = ref(false)
const editDialogOpen = ref(false)
const selectedProductName = ref('')
const selectedProductDetails = ref('')

const form = ref<UpsertListingPayload>({
  tenant_id: 0,
  shop_id: 0,
  global_stock_allocation_id: 0,
  sell_price_amount: 0,
  sell_price_currency_id: 0,
  minimum_sell_price_amount: null,
  minimum_sell_price_currency_id: null,
  show_quantity: null,
  display_quantity_override: null,
  is_active: true,
  id: null,
})

const columns = [
  { name: 'product_name', label: 'Product', field: 'product_name', align: 'left' as const, sortable: true },
  { name: 'product_code', label: 'Code', field: 'product_code', align: 'left' as const, sortable: true },
  { name: 'product_barcode', label: 'Barcode', field: 'product_barcode', align: 'left' as const },
  { name: 'sell_price', label: 'Sell Price', field: 'sell_price_amount', align: 'left' as const },
  { name: 'min_sell_price', label: 'Dropship Floor', field: 'minimum_sell_price_amount', align: 'left' as const },
  { name: 'display_quantity', label: 'Display Qty', field: 'display_quantity_override', align: 'center' as const },
  { name: 'show_quantity', label: 'Quantity Visibility', field: 'show_quantity', align: 'center' as const },
  { name: 'is_active', label: 'Active', field: 'is_active', align: 'center' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
]

const formatMoney = (amount: number | null, currencyId: number | null): string => {
  if (amount === null || currencyId === null) return '—'
  const curr = store.currencies.find(c => c.id === currencyId)
  const code = curr ? curr.code : ''
  return `${Number(amount).toFixed(2)} ${code}`
}

const filteredListings = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return store.listings

  return store.listings.filter((l) => {
    return (
      l.product_name.toLowerCase().includes(query) ||
      (l.product_code && l.product_code.toLowerCase().includes(query)) ||
      (l.product_barcode && l.product_barcode.toLowerCase().includes(query)) ||
      (l.product_brand && l.product_brand.toLowerCase().includes(query)) ||
      (l.product_category && l.product_category.toLowerCase().includes(query))
    )
  })
})

const load = async () => {
  if (!tenantId.value || !shopId.value) return

  // Fetch shop metadata
  const { data: shopData } = await supabase
    .from('shops')
    .select('name, shop_type, default_currency_id')
    .eq('id', shopId.value)
    .single()
  if (shopData) {
    shopName.value = shopData.name
    shopType.value = shopData.shop_type
    form.value.sell_price_currency_id = shopData.default_currency_id || 0
    form.value.minimum_sell_price_currency_id = shopData.default_currency_id || null
  }

  void store.fetchListings(shopId.value)
  void store.fetchCurrencies()
}

const openPickDialog = async () => {
  if (!tenantId.value || !shopId.value) return
  await store.fetchCandidates(tenantId.value, shopId.value)
  pickDialogOpen.value = true
}

const onAllocationPicked = (alloc: CandidateAllocation) => {
  selectedProductName.value = alloc.product_name
  selectedProductDetails.value = `${alloc.product_brand} | ${alloc.product_category} | Allocated: ${alloc.allocated_quantity}`

  form.value = {
    tenant_id: tenantId.value,
    shop_id: shopId.value,
    global_stock_allocation_id: alloc.allocation_id,
    sell_price_amount: 0,
    sell_price_currency_id: form.value.sell_price_currency_id ?? null,
    minimum_sell_price_amount: null,
    minimum_sell_price_currency_id: form.value.minimum_sell_price_currency_id ?? null,
    show_quantity: null,
    display_quantity_override: null,
    is_active: true,
    id: null,
  }
  editDialogOpen.value = true
}

const openEditListing = (listing: ShopProductListing) => {
  selectedProductName.value = listing.product_name
  selectedProductDetails.value = `${listing.product_brand} | ${listing.product_category} | Allocated: ${listing.allocated_quantity}`

  form.value = {
    id: listing.id,
    tenant_id: tenantId.value,
    shop_id: shopId.value,
    global_stock_allocation_id: listing.global_stock_allocation_id,
    sell_price_amount: Number(listing.sell_price_amount),
    sell_price_currency_id: listing.sell_price_currency_id,
    minimum_sell_price_amount: listing.minimum_sell_price_amount ? Number(listing.minimum_sell_price_amount) : null,
    minimum_sell_price_currency_id: listing.minimum_sell_price_currency_id,
    show_quantity: listing.show_quantity,
    display_quantity_override: listing.display_quantity_override,
    is_active: listing.is_active,
  }
  editDialogOpen.value = true
}

const onSaveListing = async () => {
  // Guard dropship currency rules
  if (shopType.value === 'dropship' && form.value.minimum_sell_price_amount) {
    if (!form.value.minimum_sell_price_currency_id) {
      form.value.minimum_sell_price_currency_id = form.value.sell_price_currency_id
    }
  } else {
    form.value.minimum_sell_price_amount = null
    form.value.minimum_sell_price_currency_id = null
  }

  const res = await store.saveListing(form.value)
  if (res.success) {
    editDialogOpen.value = false
  }
}

const goBack = () => {
  void router.push({
    name: 'app-shop-shops-page',
    params: { tenantSlug: tenantSlug.value },
  })
}

onMounted(load)
</script>
