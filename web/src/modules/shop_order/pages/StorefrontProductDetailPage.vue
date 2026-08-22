<template>
  <q-page class="q-pa-md product-detail-page theme-shop">
    <PageInitialLoader v-if="isLoading" />

    <div
      v-else-if="isError || !product"
      class="column items-center justify-center text-center q-pa-xl"
    >
      <q-icon name="ph ph-package" size="64px" color="grey-5" class="q-mb-md" />
      <div class="text-h6 text-weight-bold">{{ $t('shop.product_detail_not_found') }}</div>
      <q-btn
        color="primary"
        no-caps
        class="q-mt-md"
        :label="$t('shop.product_detail_back_catalog')"
        @click="goCatalog"
      />
    </div>

    <template v-else>
      <div class="product-detail">
        <div class="row q-col-gutter-lg product-detail__hero">
          <div class="col-12 col-md-5">
            <div class="product-detail__gallery rounded-borders overflow-hidden">
              <img
                v-if="product.product_image_url"
                :src="product.product_image_url"
                :alt="product.product_name || 'Product'"
                class="product-detail__image"
              />
              <div v-else class="product-detail__image-fallback column flex-center">
                <q-icon name="ph ph-image-square" size="48px" color="grey-4" />
                <span class="text-caption text-grey-6 q-mt-xs">{{ $t('shop.no_image_available') }}</span>
              </div>
            </div>
          </div>

          <div class="col-12 col-md-7">
            <div class="product-detail__summary">
              <div class="row items-start justify-between q-mb-xs">
                <span class="text-caption text-uppercase text-weight-medium text-grey-7">
                  {{ product.product_brand || 'Generic' }}
                </span>
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-link"
                  color="grey-7"
                  :aria-label="$t('shop.product_detail_copy_link')"
                  @click="copyLink"
                >
                  <q-tooltip>{{ $t('shop.product_detail_copy_link') }}</q-tooltip>
                </q-btn>
              </div>

              <h1 class="product-detail__title text-h5 text-weight-bold q-my-none">
                {{ product.product_name }}
              </h1>

              <dl class="product-detail__specs q-mt-md q-mb-md">
                <div v-if="product.product_brand" class="product-detail__spec-row">
                  <dt>{{ $t('shop.brand') }}</dt>
                  <dd>{{ product.product_brand }}</dd>
                </div>
                <div v-if="product.product_category" class="product-detail__spec-row">
                  <dt>{{ $t('shop.category') }}</dt>
                  <dd>{{ product.product_category }}</dd>
                </div>
                <div v-if="product.country_of_origin" class="product-detail__spec-row">
                  <dt>{{ $t('shop.product_detail_origin') }}</dt>
                  <dd>{{ product.country_of_origin }}</dd>
                </div>
                <div v-if="product.expire_date" class="product-detail__spec-row">
                  <dt>{{ $t('shop.product_detail_expires') }}</dt>
                  <dd>{{ product.expire_date }}</dd>
                </div>
                <div class="product-detail__spec-row">
                  <dt>{{ $t('shop.product_detail_moq') }}</dt>
                  <dd>{{ product.minimum_order_quantity || 1 }}</dd>
                </div>
                <div v-if="product.product_code" class="product-detail__spec-row">
                  <dt>{{ $t('shop.product_detail_code') }}</dt>
                  <dd class="text-mono">{{ product.product_code }}</dd>
                </div>
                <div v-if="product.product_barcode" class="product-detail__spec-row">
                  <dt>{{ $t('shop.product_detail_barcode') }}</dt>
                  <dd class="text-mono">{{ product.product_barcode }}</dd>
                </div>
              </dl>

              <q-card
                v-if="permissions?.see_price && product.unit_price_amount != null"
                flat
                bordered
                class="q-pa-sm q-mb-sm product-detail__price-card"
              >
                <div class="text-caption text-grey-7 text-weight-medium">
                  {{ shopType === 'dropship' ? $t('shop.wholesale_price') : $t('shop.unit_price') }}
                </div>
                <div class="text-h5 text-weight-bold text-primary">
                  {{ formatMoney(product.unit_price_amount, product.unit_price_currency_symbol) }}
                </div>
                <div
                  v-if="product.minimum_sell_price_amount != null"
                  class="text-body2 text-grey-8 q-mt-xs"
                >
                  {{ $t('shop.min_sell_price') }}
                  <span class="text-weight-bold">
                    {{
                      formatMoney(
                        product.minimum_sell_price_amount,
                        product.minimum_sell_price_currency_symbol,
                      )
                    }}
                  </span>
                </div>
              </q-card>

              <q-badge
                v-if="permissions?.can_view_quantity && product.available_units != null"
                :color="product.available_units > 0 ? 'positive' : 'negative'"
                outline
                class="text-weight-bold q-mb-sm"
              >
                {{ product.available_units }} {{ $t('shop.avail') }}
              </q-badge>

              <q-banner
                v-if="moq > 1"
                dense
                rounded
                class="bg-warning-soft text-warning-dark q-mt-sm"
              >
                <template #avatar>
                  <q-icon name="ph ph-info" color="warning" />
                </template>
                <span class="text-caption text-weight-medium">
                  {{ $t('shop.moq_notice', { count: moq }) }}
                </span>
              </q-banner>
            </div>
          </div>
        </div>

        <section class="product-detail__related q-mt-xl">
          <div class="text-subtitle1 text-weight-bold q-mb-xs">
            {{ $t('shop.product_detail_related') }}
          </div>
          <p class="text-caption text-grey-6 q-mb-md">{{ $t('shop.product_detail_related_soon') }}</p>
          <div class="row q-col-gutter-md">
            <div v-for="n in 4" :key="n" class="col-6 col-sm-3">
              <q-card flat bordered class="product-detail__related-card">
                <q-skeleton type="rect" height="96px" square />
                <div class="q-pa-sm">
                  <q-skeleton type="text" width="60%" />
                  <q-skeleton type="text" width="40%" class="q-mt-xs" />
                </div>
              </q-card>
            </div>
          </div>
        </section>
      </div>

      <div class="product-detail__action-bar">
        <div class="product-detail__action-inner row items-center q-col-gutter-sm">
          <div class="col-auto">
            <div class="row items-center no-wrap quantity-stepper">
              <q-btn
                flat
                dense
                round
                icon="ph ph-minus"
                size="sm"
                :disable="quantity <= moq"
                @click="decrementQty"
              />
              <span class="text-weight-bold q-px-sm">{{ quantity }}</span>
              <q-btn flat dense round icon="ph ph-plus" size="sm" @click="incrementQty" />
            </div>
          </div>
          <div class="col">
            <q-btn
              color="primary"
              unelevated
              no-caps
              class="full-width"
              icon="ph ph-shopping-cart"
              :label="cartItem ? $t('shop.update_cart') : $t('shop.add_to_cart')"
              :loading="cartSaving"
              :disable="!permissions?.can_add_to_cart || product.available_units === 0"
              @click="onAddToCart"
            />
          </div>
        </div>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { showSuccessNotification } from 'src/utils/appFeedback';
import { useShopProductDetailQuery } from '../composables/useShopProductDetailQuery';
import { useShopCartQuery } from '../composables/useShopCartQuery';
import { useShopCartMutations } from '../composables/useShopCartMutations';
import { shopCatalogPath } from '../utils/catalogShop';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const authStore = useAuthStore();

const quantity = ref(1);

const shopSlug = computed(() => String(route.params.shopSlug ?? ''));
const productId = computed(() => {
  const raw = Number(route.params.productId);
  return Number.isFinite(raw) && raw > 0 ? raw : null;
});
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : authStore.tenantSlug,
);

const {
  product,
  shopDetails,
  permissions,
  isLoading,
  isError,
} = useShopProductDetailQuery(shopSlug, productId);

const activeShopId = computed(() => shopDetails.value?.id ?? null);
const { items: cartItems } = useShopCartQuery(activeShopId);
const { addItemMutation, updateQtyMutation } = useShopCartMutations();

const shopName = computed(() => shopDetails.value?.name || shopSlug.value);
const shopType = computed(() => shopDetails.value?.shop_type ?? null);
const moq = computed(() => product.value?.minimum_order_quantity || 1);

const cartSaving = computed(
  () => addItemMutation.isPending.value || updateQtyMutation.isPending.value,
);

const cartItem = computed(() => {
  if (!product.value) return null;
  return (
    cartItems.value.find(
      (item) =>
        item.product_id === product.value?.product_id &&
        item.global_stock_id === product.value?.global_stock_id,
    ) ?? null
  );
});

usePageBreadcrumbs(() => {
  const catalogTo = shopCatalogPath(tenantSlug.value, shopSlug.value);
  const items = [
    {
      label: authStore.tenant?.name || t('shop.title'),
      icon: 'ph ph-storefront',
      to: undefined,
    },
    {
      label: shopName.value,
      to: catalogTo,
    },
  ];
  if (product.value?.product_category) {
    items.push({
      label: product.value.product_category,
      to: catalogTo,
    });
  }
  items.push({
    label: product.value?.product_name || t('shop.product_detail_not_found'),
    to: undefined,
  });
  return items;
});

watch(
  [product, cartItem],
  ([p, cart]) => {
    if (!p) return;
    quantity.value = cart?.quantity ?? (p.minimum_order_quantity || 1);
  },
  { immediate: true },
);

function formatMoney(amount?: number | null, symbol?: string | null): string {
  if (amount == null || Number.isNaN(amount)) return '-';
  const sym = symbol?.trim() || '৳';
  const formatted = Number(amount).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${sym} ${formatted}`;
}

function goCatalog() {
  void router.push(shopCatalogPath(tenantSlug.value, shopSlug.value));
}

async function copyLink() {
  try {
    await navigator.clipboard.writeText(window.location.href);
    showSuccessNotification(t('shop.product_detail_link_copied'));
  } catch {
    showSuccessNotification(window.location.href);
  }
}

function decrementQty() {
  if (quantity.value > moq.value) {
    quantity.value -= moq.value;
  }
}

function incrementQty() {
  const max = product.value?.available_units;
  const step = moq.value;
  if (max == null || quantity.value + step <= max) {
    quantity.value += step;
  }
}

async function onAddToCart() {
  if (!product.value || !shopDetails.value) return;
  if (cartItem.value) {
    await updateQtyMutation.mutateAsync({
      cartItemId: cartItem.value.id,
      quantity: quantity.value,
      shopId: shopDetails.value.id,
    });
    return;
  }
  await addItemMutation.mutateAsync({
    shopId: shopDetails.value.id,
    productId: product.value.product_id,
    globalStockAllocationId: product.value.global_stock_id ?? null,
    globalStockId: product.value.global_stock_id ?? null,
    quantity: quantity.value,
  });
}
</script>

<style scoped>
.product-detail-page {
  padding-bottom: 88px;
}

.product-detail__gallery {
  background: color-mix(in srgb, var(--bw-theme-base, #fafafa) 90%, var(--bw-theme-surface, #fff) 10%);
  border: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.12));
  min-height: 280px;
}

.product-detail__image {
  width: 100%;
  max-height: 360px;
  object-fit: contain;
  display: block;
  padding: 16px;
}

.product-detail__image-fallback {
  min-height: 280px;
}

.product-detail__title {
  color: var(--bw-theme-ink, #1f2937);
  line-height: 1.3;
}

.product-detail__specs {
  margin: 0;
}

.product-detail__spec-row {
  display: grid;
  grid-template-columns: minmax(120px, 38%) 1fr;
  gap: 8px 12px;
  padding: 6px 0;
  border-bottom: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08));
}

.product-detail__spec-row dt {
  margin: 0;
  font-size: 0.8125rem;
  color: var(--bw-theme-muted, #6b7280);
}

.product-detail__spec-row dd {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--bw-theme-ink, #1f2937);
}

.product-detail__price-card {
  border-radius: 10px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 92%, var(--bw-theme-primary-soft, #eff6ff) 8%);
}

.product-detail__related-card {
  border-radius: 12px;
  overflow: hidden;
}

.bg-warning-soft {
  background: rgba(245, 158, 11, 0.1);
}

.text-warning-dark {
  color: #b45309;
}

.quantity-stepper {
  border: 1.5px solid var(--bw-theme-border, rgba(34, 56, 101, 0.18));
  border-radius: 8px;
  padding: 2px 4px;
}

.product-detail__action-bar {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 100;
  padding: 12px 16px;
  padding-bottom: max(12px, env(safe-area-inset-bottom));
  background: var(--bw-theme-surface, #fff);
  border-top: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.12));
  box-shadow: 0 -4px 16px rgba(15, 23, 42, 0.06);
}

.product-detail__action-inner {
  max-width: 960px;
  margin: 0 auto;
}

@media (min-width: 1024px) {
  .product-detail-page {
    padding-bottom: 24px;
  }

  .product-detail__action-bar {
    position: sticky;
    bottom: 0;
    margin-top: 24px;
    border-radius: 12px;
    box-shadow: var(--bw-theme-shadow, 0 8px 24px rgba(15, 23, 42, 0.08));
  }
}
</style>
