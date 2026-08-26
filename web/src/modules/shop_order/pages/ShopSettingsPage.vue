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
              v-if="showStockTab"
              name="stock"
              icon="ph ph-warehouse"
              :label="$t('shop_admin.shop_tab_stock')"
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

            <div class="theme-shop storefront-preview q-mt-md relative-position">
              <q-inner-loading :showing="storefrontLoading" color="primary" />
              <div
                v-if="storefrontProducts.length > 0"
                class="row q-col-gutter-md storefront-product-grid"
              >
                <div
                  v-for="item in storefrontProducts"
                  :key="`${item.product_id}-${item.stock_grade?.slug ?? 'none'}-${item.listing_id}`"
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
                v-else-if="storefrontIsError"
                class="column items-center justify-center storefront-preview-empty q-pa-xl text-center"
              >
                <q-icon name="ph ph-warning-circle" size="64px" color="negative" class="q-mb-md" />
                <div class="text-body1 text-grey-8">
                  {{ storefrontError?.message || $t('shop_admin.storefront_load_failed') }}
                </div>
              </div>

              <div
                v-else-if="!storefrontLoading"
                class="column items-center justify-center storefront-preview-empty q-pa-xl text-center"
              >
                <q-icon name="ph ph-tote" size="64px" color="grey-5" class="q-mb-md" />
                <div class="text-h6 text-weight-bold text-grey-8">
                  {{ $t('shop_admin.storefront_no_products') }}
                </div>
              </div>
            </div>
          </q-tab-panel>

          <q-tab-panel v-if="showStockTab" name="stock" class="q-pa-none q-pt-md">
            <ShopWarehouseStockPage
              v-if="activeTab === 'stock' && shop"
              embedded
              :shop="shop"
              :tenant-id="tenantId"
            />
          </q-tab-panel>
        </q-tab-panels>

        <ShopStorefrontAddProductDrawer
          v-model="storefrontAddProductDrawerOpen"
          :shop-id="shopId"
          :tenant-id="tenantId"
          :shop-type="shop?.shop_type"
          :sell-currency-id="shop?.sell_currency_id ?? null"
          :markup-percentage="shop?.markup_percentage ?? null"
          :listed-grade-keys="storefrontListedGradeKeys"
          :listed-product-ids="storefrontListedProductIds"
          @saved="onStorefrontListingAdded"
        />
        <ShopStorefrontCalculateSellPriceDrawer
          v-model="calculateSellPriceDrawerOpen"
          :shop-id="shopId"
          :tenant-id="tenantId"
          :listing-id="calculateSellPriceListingId"
          :shop-type="shop.shop_type"
          @saved="onStorefrontPricingSaved"
        />
      </template>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, defineAsyncComponent, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useQueryClient } from '@tanstack/vue-query';
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
import { useShopStorefrontAdminListingsQuery } from '../composables/useShopStorefrontAdminQuery';
import {
  patchStorefrontListingActive,
  useCopyShopStorefrontGradeMutation,
  useDeleteShopStorefrontListingMutation,
  useToggleShopStorefrontListingMutation,
} from '../composables/useShopStorefrontAdminMutations';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopCatalogPath } from '../utils/catalogShop';
import { showSuccessNotification, showErrorNotification, requestConfirmation } from 'src/utils/appFeedback';
import type { CustomerShopPermissions } from '../composables/useCustomerShopPermissionsQuery';
import type {
  ShopCatalogStockGrade,
  ShopStorefrontAdminListing,
  UpdateShopPayload,
} from 'src/modules/shop_order/types';

const ShopAccessMatrixPage = defineAsyncComponent(
  () => import('src/modules/shop_order/pages/ShopAccessMatrixPage.vue'),
);
const ShopWarehouseStockPage = defineAsyncComponent(
  () => import('src/modules/shop_order/pages/ShopWarehouseStockPage.vue'),
);

type ShopDetailTab = 'setup' | 'access' | 'storefront' | 'stock';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const queryClient = useQueryClient();
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
const calculateSellPriceListingId = ref<number | null>(null);

const isStorefrontTabActive = computed(() => {
  const tab = typeof route.query.tab === 'string' ? route.query.tab : 'setup';
  return tab === 'storefront';
});
const {
  data: storefrontListingsResult,
  isLoading: storefrontLoading,
  isError: storefrontIsError,
  error: storefrontError,
} = useShopStorefrontAdminListingsQuery(shopId, storefrontSearch, isStorefrontTabActive);

const { mutate: toggleStorefrontListingMutation } = useToggleShopStorefrontListingMutation();
const { mutate: deleteStorefrontListingMutation, isPending: isDeletingStorefrontListing } =
  useDeleteShopStorefrontListingMutation();
const { mutate: copyStorefrontGradeMutation } = useCopyShopStorefrontGradeMutation();

const storefrontProducts = computed(
  () => storefrontListingsResult.value?.data ?? [],
);

const storefrontPreviewPermissions: CustomerShopPermissions = {
  can_browse: true,
  can_see_buy_price: true,
  can_see_sell_price: true,
  can_see_resell_minimum_price: true,
  can_add_to_cart: true,
  can_place_order: true,
  can_view_quantity: true,
};

const STOREFRONT_WAREHOUSE_GRADES: ShopCatalogStockGrade[] = [
  { slug: 'standard', label: 'Standard', color: '#22c55e' },
  { slug: 'open_box', label: 'Open box', color: '#3b82f6' },
  { slug: 'box_damage', label: 'Box damage', color: '#f59e0b' },
  { slug: 'box_less', label: 'Box less', color: '#8b5cf6' },
];

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

const storefrontSearchParam = computed(() => storefrontSearch.value.trim() || null);

const catalogGradeOptions = computed(() => {
  const bySlug = new Map<string, ShopCatalogStockGrade>();
  STOREFRONT_WAREHOUSE_GRADES.forEach((grade) => bySlug.set(grade.slug, grade));
  storefrontProducts.value.forEach((item) => {
    if (item.stock_grade?.slug) {
      bySlug.set(item.stock_grade.slug, item.stock_grade);
    }
  });
  return [...bySlug.values()];
});

const storefrontProductGradeKey = (productId: number, gradeSlug: string | null | undefined) =>
  `${productId}:${gradeSlug ?? ''}`;

const isStorefrontProductGradeTaken = (
  productId: number,
  gradeSlug: string | null | undefined,
): boolean => {
  if (!gradeSlug) return false;
  const key = storefrontProductGradeKey(productId, gradeSlug);
  return storefrontProducts.value.some(
    (row) => storefrontProductGradeKey(row.product_id, row.stock_grade?.slug) === key,
  );
};

const availableGradesForProduct = (item: ShopStorefrontAdminListing): ShopCatalogStockGrade[] =>
  catalogGradeOptions.value.filter(
    (grade) => !isStorefrontProductGradeTaken(item.product_id, grade.slug),
  );

const buildStorefrontListingUpsertPayload = (
  item: ShopStorefrontAdminListing,
  isActive: boolean,
) => ({
  id: item.listing_id,
  tenant_id: tenantId.value,
  shop_id: shopId.value,
  global_stock_id: item.global_stock_id ?? undefined,
  product_id: item.global_stock_id == null ? item.product_id : undefined,
  sell_price_amount: Number(item.sell_price_amount ?? item.sell_price?.amount ?? 0),
  sell_price_currency_id: Number(
    item.sell_price_currency_id ?? item.sell_price?.currency_id ?? 0,
  ),
  minimum_sell_price_amount: item.minimum_sell_price_amount ?? null,
  minimum_sell_price_currency_id: item.minimum_sell_price_currency_id ?? null,
  show_quantity: item.show_quantity ?? true,
  display_quantity_override: item.display_quantity_override ?? null,
  is_active: isActive,
});

const copyProductWithGrade = (source: ShopStorefrontAdminListing, grade: ShopCatalogStockGrade) => {
  if (!grade.slug || isStorefrontProductGradeTaken(source.product_id, grade.slug)) {
    showErrorNotification(t('shop_admin.storefront_grade_variant_duplicate'));
    return;
  }

  copyStorefrontGradeMutation(
    {
      shopId: shopId.value,
      tenantId: tenantId.value,
      source,
      grade,
    },
    {
      onSuccess: () => {
        showSuccessNotification(
          t('shop_admin.storefront_grade_variant_added', { grade: grade.label }),
        );
      },
    },
  );
};

const openCalculateSellPriceDrawer = (item: ShopStorefrontAdminListing) => {
  calculateSellPriceListingId.value = item.listing_id;
  calculateSellPriceDrawerOpen.value = true;
};

const storefrontListedGradeKeys = computed(() =>
  storefrontProducts.value.map(
    (row) => `${row.product_id}:${row.stock_grade?.slug ?? 'standard'}`,
  ),
);

const storefrontListedProductIds = computed(() =>
  storefrontProducts.value.map((row) => row.product_id),
);

const onStorefrontListingAdded = () => {
  void queryClient.invalidateQueries({
    queryKey: ['shopOrder', 'storefrontAdminListings', { shopId: shopId.value }],
  });
};

const onStorefrontPricingSaved = () => {
  void queryClient.invalidateQueries({
    queryKey: ['shopOrder', 'storefrontAdminListings', { shopId: shopId.value }],
  });
};

const toggleStorefrontListingStatus = (item: ShopStorefrontAdminListing, isActive: boolean) => {
  const search = storefrontSearchParam.value;
  patchStorefrontListingActive(queryClient, shopId.value, search, item.listing_id, isActive);
  toggleStorefrontListingMutation(buildStorefrontListingUpsertPayload(item, isActive), {
    onError: () => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.storefrontAdminListings(shopId.value, search),
      });
    },
  });
};

const storefrontProductLabel = (item: ShopStorefrontAdminListing) =>
  [item.product_name, item.stock_grade?.label].filter(Boolean).join(' · ');

const removeStorefrontProduct = async (item: ShopStorefrontAdminListing) => {
  const confirmed = await requestConfirmation(
    t('shop_admin.storefront_remove_product_confirm', {
      name: storefrontProductLabel(item),
    }),
    t('shop_admin.storefront_remove_product_title'),
    t('shop_admin.storefront_remove_product'),
  );
  if (!confirmed || isDeletingStorefrontListing.value) return;

  deleteStorefrontListingMutation(
    {
      listingId: item.listing_id,
      tenantId: tenantId.value,
      shopId: shopId.value,
      search: storefrontSearchParam.value,
    },
    {
      onSuccess: () => {
        if (calculateSellPriceListingId.value === item.listing_id) {
          calculateSellPriceDrawerOpen.value = false;
          calculateSellPriceListingId.value = null;
        }
        showSuccessNotification(t('shop_admin.storefront_remove_product_success'));
      },
    },
  );
};

watch(shopId, () => {
  deleteKeyword.value = '';
  deleteShopName.value = '';
  storefrontSearch.value = '';
  storefrontAddProductDrawerOpen.value = false;
  calculateSellPriceDrawerOpen.value = false;
  calculateSellPriceListingId.value = null;
});

const canDeleteShop = computed(() => {
  const name = shop.value?.name?.trim() ?? '';
  return deleteKeyword.value.trim() === 'DELETE' && deleteShopName.value.trim() === name && name.length > 0;
});

const showAccessTab = computed(() => hasModuleAccess('shop_permissions'));
const showStorefrontTab = computed(
  () => shop.value?.shop_type === 'fixed_price' || shop.value?.shop_type === 'dropship',
);
const showStockTab = computed(
  () => shop.value?.shop_type === 'fixed_price' || shop.value?.shop_type === 'dropship',
);

const isValidTab = (tab: string): tab is ShopDetailTab => {
  if (tab === 'setup') return true;
  if (tab === 'access') return showAccessTab.value;
  if (tab === 'storefront') return showStorefrontTab.value;
  if (tab === 'stock') return showStockTab.value;
  return false;
};

const activeTab = computed({
  get(): ShopDetailTab {
    const raw = typeof route.query.tab === 'string' ? route.query.tab : 'setup';
    const tab = raw === 'listings' ? 'stock' : raw;
    return isValidTab(tab) ? tab : 'setup';
  },
  set(tab: ShopDetailTab) {
    void router.replace({
      params: route.params,
      query: { ...route.query, tab },
    });
  },
});

watch(
  () => route.query.tab,
  (tab) => {
    if (tab === 'listings') {
      void router.replace({
        params: route.params,
        query: { ...route.query, tab: 'stock' },
      });
    }
  },
  { immediate: true },
);

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
