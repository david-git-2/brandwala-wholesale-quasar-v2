<template>
  <q-page class="bw-page q-pa-md">
    <section class="bw-page__stack">
      <q-banner v-if="isError" class="text-white bg-negative" rounded>
        {{ error?.message || $t('shop_admin.shop_setup_load_failed') }}
      </q-banner>

      <ShopSettingsSkeleton v-if="isLoading" is-loading />

      <template v-else-if="shop">
        <div class="shop-settings-header row items-center no-wrap">
          <q-tabs
            v-model="activeTab"
            inline-label
            dense
            no-caps
            align="left"
            active-color="primary"
            indicator-color="primary"
            class="shop-settings-tabs col min-width-0 text-grey-8"
            narrow-indicator
            outside-arrows
            mobile-arrows
          >
            <q-tab name="setup" icon="ph ph-gear" :label="$t('shop_admin.shop_tab_setup')" />
            <q-tab
              v-if="showAccessTab"
              name="access"
              icon="ph ph-shield"
              :label="$t('shop_admin.shop_tab_access')"
            />
            <q-tab
              v-if="showStorefrontTab"
              name="storefront"
              icon="ph ph-storefront"
              :label="$t('shop_admin.shop_tab_storefront')"
            />
            <q-tab
              v-if="showListingsTab"
              name="listings"
              icon="ph ph-tag"
              :label="$t('shop_admin.shop_tab_listings')"
            />
          </q-tabs>
          <div class="col-auto row items-center q-gutter-sm no-wrap q-pl-sm">
            <q-btn
              v-if="shop.slug"
              flat
              dense
              no-caps
              outline
              color="primary"
              icon="ph ph-copy"
              :label="$t('shop_admin.shop_catalog_url_copy')"
              data-test="shop-catalog-url-copy"
              @click="copyShopUrl"
            />
            <q-btn
              v-if="activeTab === 'setup'"
              color="primary"
              unelevated
              dense
              no-caps
              style="border-radius: 8px"
              :label="$t('shop_admin.save')"
              :loading="isSaving"
              @click="onSave"
            />
          </div>
        </div>

        <q-tab-panels v-model="activeTab" animated class="bg-transparent">
          <q-tab-panel name="setup" class="q-pa-none q-pt-md">
            <DropshipShopReadinessCard
              v-if="shop.shop_type === 'dropship'"
              class="q-mb-md"
              :shop-id="shop.id"
              :tenant-slug="tenantSlug"
            />
            <ShopSettingsForm ref="formRef" :shop="shop" />

            <q-card flat class="shop-danger-zone q-mt-md">
              <q-card-section>
                <div class="text-subtitle2 text-weight-bold text-negative">
                  {{ $t('shop_admin.danger_zone_title') }}
                </div>
                <p class="text-body2 text-grey-8 q-mt-xs q-mb-none">
                  {{ $t('shop_admin.danger_zone_delete_caption') }}
                </p>
                <p class="text-caption text-grey-7 q-mt-sm q-mb-md">
                  {{ $t('shop_admin.delete_shop_confirm_msg', { name: shop.name }) }}
                </p>

                <div class="row q-col-gutter-md">
                  <div class="col-12 col-md-6">
                    <q-input
                      v-model="deleteKeyword"
                      outlined
                      dense
                      autocomplete="off"
                      :label="$t('shop_admin.danger_zone_type_delete')"
                      data-test="shop-delete-keyword"
                    />
                  </div>
                  <div class="col-12 col-md-6">
                    <q-input
                      v-model="deleteShopName"
                      outlined
                      dense
                      autocomplete="off"
                      :label="$t('shop_admin.danger_zone_type_shop_name', { name: shop.name })"
                      data-test="shop-delete-name"
                    />
                  </div>
                </div>

                <div class="row justify-end q-mt-md">
                  <q-btn
                    color="negative"
                    unelevated
                    no-caps
                    icon="ph ph-trash"
                    :label="$t('shop_admin.danger_zone_delete_btn')"
                    :loading="isDeleting"
                    :disable="!canDeleteShop || isDeleting"
                    data-test="shop-delete-submit"
                    @click="deleteShop"
                  />
                </div>
              </q-card-section>
            </q-card>
          </q-tab-panel>

          <q-tab-panel v-if="showAccessTab" name="access" class="q-pa-none q-pt-md">
            <ShopAccessMatrixPage v-if="activeTab === 'access'" embedded :shop="shop" />
          </q-tab-panel>

          <q-tab-panel v-if="showStorefrontTab" name="storefront" class="q-pa-none q-pt-md">
            <section class="row items-center q-col-gutter-sm no-wrap">
              <div class="col min-width-0">
                <q-input
                  v-model="storefrontSearch"
                  clearable
                  dense
                  outlined
                  :placeholder="$t('shop_admin.storefront_search_placeholder')"
                >
                  <template #prepend>
                    <q-icon name="ph ph-magnifying-glass" />
                  </template>
                </q-input>
              </div>
              <div class="col-auto">
                <q-btn
                  color="primary"
                  icon="ph ph-plus"
                  :label="$t('shop_admin.storefront_add_product')"
                  unelevated
                  no-caps
                  @click="storefrontAddProductDrawerOpen = true"
                />
              </div>
            </section>

            <div class="theme-shop storefront-preview q-mt-md">
              <div v-if="filteredStorefrontProducts.length > 0" class="row q-col-gutter-md storefront-product-grid">
                <div
                  v-for="item in filteredStorefrontProducts"
                  :key="`${item.product_id}-${item.stock_grade?.slug ?? 'none'}-${item.global_stock_id}`"
                  class="col-xs-12 col-sm-6 col-md-4 col-lg-3 storefront-product-grid-item"
                >
                  <StorefrontProductCard
                    :item="item"
                    :permissions="storefrontPreviewPermissions"
                    :shop-type="shop.shop_type"
                    :format-money="formatStorefrontMoney"
                    :show-actions="false"
                    :show-unit-price="false"
                    :show-quantity-breakdown="true"
                    :show-calculate-sell-price="true"
                    :show-avg-cost="true"
                    :show-grade-chip="true"
                    :show-copy-grade-variant="true"
                    :show-listing-status-toggle="true"
                    :show-remove-product="true"
                    :available-grade-variants="availableGradesForProduct(item)"
                    @calculate-sell-price="openCalculateSellPriceDrawer"
                    @copy-grade-variant="copyProductWithGrade"
                    @toggle-listing-status="toggleStorefrontListingStatus"
                    @remove-product="removeStorefrontProduct"
                  />
                </div>
              </div>

              <div
                v-else
                class="column items-center justify-center storefront-preview-empty q-pa-xl text-center"
              >
                <q-icon name="ph ph-tote" size="64px" color="grey-5" class="q-mb-md" />
                <div class="text-h6 text-weight-bold text-grey-8">
                  {{ $t('shop_admin.storefront_no_products') }}
                </div>
              </div>
            </div>
          </q-tab-panel>

          <q-tab-panel v-if="showListingsTab" name="listings" class="q-pa-none q-pt-sm">
            <ShopPricingPage v-if="activeTab === 'listings'" embedded :shop="shop" />
          </q-tab-panel>
        </q-tab-panels>

        <ShopStorefrontAddProductDrawer v-model="storefrontAddProductDrawerOpen" />
        <ShopStorefrontCalculateSellPriceDrawer
          v-model="calculateSellPriceDrawerOpen"
          :product="calculateSellPriceProduct"
          :shop-type="shop.shop_type"
        />
      </template>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, defineAsyncComponent, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { copyToClipboard } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import ShopSettingsForm from 'src/modules/shop_order/components/ShopSettingsForm.vue';
import ShopSettingsSkeleton from 'src/modules/shop_order/components/ShopSettingsSkeleton.vue';
import DropshipShopReadinessCard from 'src/modules/shop_order/components/DropshipShopReadinessCard.vue';
import StorefrontProductCard from 'src/modules/shop_order/components/StorefrontProductCard.vue';
import ShopStorefrontAddProductDrawer from 'src/modules/shop_order/components/ShopStorefrontAddProductDrawer.vue';
import ShopStorefrontCalculateSellPriceDrawer from 'src/modules/shop_order/components/ShopStorefrontCalculateSellPriceDrawer.vue';
import { useShopDetailQuery } from '../composables/useShopQuery';
import { useSaveShopMutation, useDeleteShopMutation } from '../composables/useShopMutations';
import { shopCatalogPath } from '../utils/catalogShop';
import { showSuccessNotification, showErrorNotification, requestConfirmation } from 'src/utils/appFeedback';
import type { CustomerShopPermissions } from '../composables/useCustomerShopPermissionsQuery';
import type {
  ShopCatalogItem,
  ShopCatalogPrice,
  ShopCatalogStockGrade,
  UpdateShopPayload,
} from 'src/modules/shop_order/types';

const ShopAccessMatrixPage = defineAsyncComponent(
  () => import('src/modules/shop_order/pages/ShopAccessMatrixPage.vue'),
);
const ShopPricingPage = defineAsyncComponent(
  () => import('src/modules/shop_order/pages/ShopPricingPage.vue'),
);

type ShopDetailTab = 'setup' | 'access' | 'storefront' | 'listings';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const authStore = useAuthStore();
const { hasModuleAccess } = useModulePermissions();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');
const shopId = computed(() => Number(route.params.shopId));

const { data: shop, isLoading, isError, error } = useShopDetailQuery(tenantId, shopId);
const { mutate: saveShopMutation, isPending: isSaving } = useSaveShopMutation();
const { mutate: deleteShopMutation, isPending: isDeleting } = useDeleteShopMutation();

const formRef = ref<{ buildPayload: () => UpdateShopPayload | null } | null>(null);
const deleteKeyword = ref('');
const deleteShopName = ref('');
const storefrontSearch = ref('');
const storefrontAddProductDrawerOpen = ref(false);
const calculateSellPriceDrawerOpen = ref(false);
const calculateSellPriceProduct = ref<ShopCatalogItem | null>(null);

const storefrontPreviewPermissions: CustomerShopPermissions = {
  can_browse: true,
  can_see_buy_price: true,
  can_see_sell_price: true,
  can_see_resell_minimum_price: true,
  can_add_to_cart: true,
  can_place_order: true,
  can_view_quantity: true,
};

const dummyCatalogPrice = (amount: number): ShopCatalogPrice => ({
  amount,
  currency_id: 1,
  code: 'BDT',
  symbol: '৳',
});

const STOREFRONT_WAREHOUSE_GRADES: ShopCatalogStockGrade[] = [
  { slug: 'standard', label: 'Standard', color: '#22c55e' },
  { slug: 'open_box', label: 'Open box', color: '#3b82f6' },
  { slug: 'box_damage', label: 'Box damage', color: '#f59e0b' },
  { slug: 'box_less', label: 'Box less', color: '#8b5cf6' },
];

const createInitialStorefrontProducts = (): ShopCatalogItem[] => [
  {
    product_id: 1001,
    product_name: 'Premium Cotton T-Shirt — Navy Blue',
    product_image_url: null,
    product_barcode: '8901234567890',
    product_code: 'TSH-NVY-001',
    product_brand: 'BrandWala',
    product_category: 'Apparel',
    vendor_code: 'BW',
    is_available: true,
    unit_price: dummyCatalogPrice(450),
    avg_cost: dummyCatalogPrice(418.5),
    sell_price: dummyCatalogPrice(620),
    resell_minimum_price: dummyCatalogPrice(580),
    available_units: 100,
    real_available_units: 120,
    display_quantity_override: 100,
    listing_status: 'active',
    stock_grade: { slug: 'standard', label: 'Standard', color: '#22c55e' },
    global_stock_allocation_id: null,
    global_stock_id: 5001,
    minimum_order_quantity: 1,
  },
  {
    product_id: 1002,
    product_name: 'Wireless Bluetooth Earbuds Pro',
    product_image_url: null,
    product_barcode: '8901234567891',
    product_code: 'AUD-BT-200',
    product_brand: 'SoundMax',
    product_category: 'Electronics',
    vendor_code: 'SM',
    is_available: true,
    unit_price: dummyCatalogPrice(1250),
    avg_cost: dummyCatalogPrice(1188.75),
    sell_price: dummyCatalogPrice(1699),
    resell_minimum_price: dummyCatalogPrice(1550),
    available_units: 48,
    real_available_units: 48,
    display_quantity_override: null,
    listing_status: 'active',
    stock_grade: { slug: 'standard', label: 'Standard', color: '#22c55e' },
    global_stock_allocation_id: null,
    global_stock_id: 5002,
    minimum_order_quantity: 1,
  },
  {
    product_id: 1003,
    product_name: 'Stainless Steel Water Bottle 1L',
    product_image_url: null,
    product_barcode: '8901234567892',
    product_code: 'BTL-SS-1L',
    product_brand: 'HydroLife',
    product_category: 'Home & Kitchen',
    vendor_code: 'HL',
    is_available: true,
    unit_price: dummyCatalogPrice(320),
    avg_cost: dummyCatalogPrice(305.2),
    sell_price: dummyCatalogPrice(449),
    resell_minimum_price: dummyCatalogPrice(400),
    available_units: 150,
    real_available_units: 200,
    display_quantity_override: 150,
    listing_status: 'active',
    stock_grade: { slug: 'standard', label: 'Standard', color: '#22c55e' },
    global_stock_allocation_id: null,
    global_stock_id: 5003,
    minimum_order_quantity: 2,
  },
  {
    product_id: 1004,
    product_name: 'Organic Green Tea — 100 Bags',
    product_image_url: null,
    product_barcode: '8901234567893',
    product_code: 'TEA-GRN-100',
    product_brand: 'Leaf & Co',
    product_category: 'Grocery',
    vendor_code: 'LC',
    is_available: true,
    unit_price: dummyCatalogPrice(280),
    avg_cost: dummyCatalogPrice(265),
    sell_price: dummyCatalogPrice(385),
    resell_minimum_price: dummyCatalogPrice(350),
    available_units: 0,
    real_available_units: 0,
    display_quantity_override: null,
    listing_status: 'active',
    stock_grade: { slug: 'standard', label: 'Standard', color: '#22c55e' },
    global_stock_allocation_id: null,
    global_stock_id: 5004,
    minimum_order_quantity: 1,
  },
];

const dummyStorefrontProducts = ref<ShopCatalogItem[]>(createInitialStorefrontProducts());
let nextStorefrontStockId = 5005;

const formatStorefrontMoney = (amount: unknown, symbol?: string | null) => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '—';
  const sym = symbol?.trim() || '৳';
  const formatted = n.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${sym} ${formatted}`;
};

const filteredStorefrontProducts = computed(() => {
  const query = storefrontSearch.value.trim().toLowerCase();
  const products = dummyStorefrontProducts.value;
  if (!query) return products;

  return products.filter((item) => {
    const haystack = [
      item.product_name,
      item.product_brand,
      item.product_code,
      item.product_barcode,
      item.product_category,
      item.stock_grade?.label,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    return haystack.includes(query);
  });
});

const storefrontProductGradeKey = (productId: number, gradeSlug: string | null | undefined) =>
  `${productId}:${gradeSlug ?? ''}`;

const isStorefrontProductGradeTaken = (
  productId: number,
  gradeSlug: string | null | undefined,
): boolean => {
  if (!gradeSlug) return false;
  const key = storefrontProductGradeKey(productId, gradeSlug);
  return dummyStorefrontProducts.value.some(
    (row) => storefrontProductGradeKey(row.product_id, row.stock_grade?.slug) === key,
  );
};

const availableGradesForProduct = (item: ShopCatalogItem): ShopCatalogStockGrade[] =>
  STOREFRONT_WAREHOUSE_GRADES.filter(
    (grade) => !isStorefrontProductGradeTaken(item.product_id, grade.slug),
  );

const copyProductWithGrade = (source: ShopCatalogItem, grade: ShopCatalogStockGrade) => {
  if (!grade.slug) {
    showErrorNotification(t('shop_admin.storefront_grade_variant_duplicate'));
    return;
  }

  if (isStorefrontProductGradeTaken(source.product_id, grade.slug)) {
    showErrorNotification(t('shop_admin.storefront_grade_variant_duplicate'));
    return;
  }

  const copy: ShopCatalogItem = {
    ...source,
    global_stock_id: nextStorefrontStockId++,
    stock_grade: { ...grade },
    listing_status: 'active',
  };

  dummyStorefrontProducts.value = [...dummyStorefrontProducts.value, copy];
  showSuccessNotification(
    t('shop_admin.storefront_grade_variant_added', { grade: grade.label }),
  );
};

const openCalculateSellPriceDrawer = (item: ShopCatalogItem) => {
  calculateSellPriceProduct.value = item;
  calculateSellPriceDrawerOpen.value = true;
};

const toggleStorefrontListingStatus = (item: ShopCatalogItem, isActive: boolean) => {
  dummyStorefrontProducts.value = dummyStorefrontProducts.value.map((row) =>
    row.global_stock_id === item.global_stock_id
      ? { ...row, listing_status: isActive ? 'active' : 'inactive' }
      : row,
  );
};

const storefrontProductLabel = (item: ShopCatalogItem) =>
  [item.product_name, item.stock_grade?.label].filter(Boolean).join(' · ');

const removeStorefrontProduct = async (item: ShopCatalogItem) => {
  const confirmed = await requestConfirmation(
    t('shop_admin.storefront_remove_product_confirm', {
      name: storefrontProductLabel(item),
    }),
    t('shop_admin.storefront_remove_product_title'),
    t('shop_admin.storefront_remove_product'),
  );
  if (!confirmed) return;

  dummyStorefrontProducts.value = dummyStorefrontProducts.value.filter(
    (row) => row.global_stock_id !== item.global_stock_id,
  );

  if (calculateSellPriceProduct.value?.global_stock_id === item.global_stock_id) {
    calculateSellPriceDrawerOpen.value = false;
    calculateSellPriceProduct.value = null;
  }

  showSuccessNotification(t('shop_admin.storefront_remove_product_success'));
};

watch(shopId, () => {
  deleteKeyword.value = '';
  deleteShopName.value = '';
  storefrontSearch.value = '';
  storefrontAddProductDrawerOpen.value = false;
  calculateSellPriceDrawerOpen.value = false;
  calculateSellPriceProduct.value = null;
  dummyStorefrontProducts.value = createInitialStorefrontProducts();
  nextStorefrontStockId = 5005;
});

const canDeleteShop = computed(() => {
  const name = shop.value?.name?.trim() ?? '';
  return deleteKeyword.value.trim() === 'DELETE' && deleteShopName.value.trim() === name && name.length > 0;
});

const showAccessTab = computed(() => hasModuleAccess('shop_permissions'));
const showStorefrontTab = computed(
  () => shop.value?.shop_type === 'fixed_price' || shop.value?.shop_type === 'dropship',
);
const showListingsTab = computed(
  () => shop.value?.shop_type !== 'vendor_catalog' && hasModuleAccess('shop_pricing'),
);

const isValidTab = (tab: string): tab is ShopDetailTab => {
  if (tab === 'setup') return true;
  if (tab === 'access') return showAccessTab.value;
  if (tab === 'storefront') return showStorefrontTab.value;
  if (tab === 'listings') return showListingsTab.value;
  return false;
};

const activeTab = computed({
  get(): ShopDetailTab {
    const tab = typeof route.query.tab === 'string' ? route.query.tab : 'setup';
    return isValidTab(tab) ? tab : 'setup';
  },
  set(tab: ShopDetailTab) {
    void router.replace({
      params: route.params,
      query: { ...route.query, tab },
    });
  },
});

const onSave = () => {
  const payload = formRef.value?.buildPayload();
  if (!payload) return;
  saveShopMutation(payload, {
    onSuccess: () => {
      showSuccessNotification(t('shop_admin.shop_setup_saved'));
    },
    onError: (err: Error) => {
      showErrorNotification(err.message || t('shop_admin.shop_setup_save_failed'));
    },
  });
};

const copyShopUrl = async () => {
  if (!shop.value?.slug) return;
  const origin = typeof window === 'undefined' ? '' : window.location.origin;
  const url = `${origin}${shopCatalogPath(tenantSlug.value, shop.value.slug).path}`;
  try {
    await copyToClipboard(url);
    showSuccessNotification(t('shop_admin.shop_catalog_url_copied'));
  } catch {
    showErrorNotification(t('shop_admin.shop_catalog_url_copy_failed'));
  }
};

const deleteShop = () => {
  if (!canDeleteShop.value || !shop.value) return;

  deleteShopMutation(
    { shopId: shopId.value, tenantId: tenantId.value },
    {
      onSuccess: () => {
        showSuccessNotification(t('shop_admin.delete_shop_success'));
        void router.push({
          name: 'app-shop-shops-list-page',
          params: { tenantSlug: tenantSlug.value },
        });
      },
      onError: (err: Error) => {
        showErrorNotification(err.message || t('shop_admin.delete_shop_failed'));
      },
    },
  );
};
</script>

<style scoped>
.shop-settings-header {
  min-height: 38px;
  border-bottom: 1px solid rgba(226, 232, 240, 0.9);
}

.shop-settings-tabs :deep(.q-tab__icon) {
  font-size: 18px;
}

.shop-danger-zone {
  background: #fff5f5;
  border-radius: 8px;
  border: 1px solid rgba(239, 68, 68, 0.25);
  box-shadow: none;
}

body.body--dark .shop-settings-header {
  border-bottom-color: #2e2e2e;
}

body.body--dark .shop-danger-zone {
  background: rgba(127, 29, 29, 0.12);
  border-color: rgba(248, 113, 113, 0.28);
}

@media (min-width: 600px) {
  .storefront-product-grid {
    display: grid !important;
    grid-template-columns: repeat(auto-fill, minmax(220px, 250px));
    justify-content: center;
    gap: 16px;
    margin: 0 !important;
  }

  .storefront-product-grid-item {
    width: 100% !important;
    max-width: none !important;
    padding: 0 !important;
  }
}

.storefront-preview-empty {
  min-height: 280px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 60%, transparent);
  border-radius: 16px;
  border: 1px dashed var(--bw-theme-border, rgba(34, 56, 101, 0.12));
}
</style>
