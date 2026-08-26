<template>
  <q-drawer
    v-model="isOpen"
    side="right"
    overlay
    elevated
    :width="drawerWidth"
    class="shop-storefront-add-product-drawer bg-white"
  >
    <div class="column full-height">
      <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
        <div class="row items-center q-gutter-x-sm min-width-0">
          <q-btn
            v-if="showCreateForm"
            flat
            round
            dense
            icon="ph ph-arrow-left"
            @click="closeCreateForm"
          />
          <div class="min-width-0">
            <div class="text-subtitle1 text-weight-bold row items-center">
              <q-icon
                :name="showCreateForm ? 'ph ph-package' : 'ph ph-plus-circle'"
                class="q-mr-xs text-primary"
                size="20px"
              />
              <span class="ellipsis">
                {{
                  showCreateForm
                    ? $t('shop_admin.storefront_add_new_product')
                    : $t('shop_admin.storefront_add_product')
                }}
              </span>
            </div>
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense @click="isOpen = false" />
      </div>

      <q-separator />

      <div v-if="!showCreateForm" class="col column min-height-0">
        <div class="q-pa-md">
          <q-input
            v-model="search"
            outlined
            dense
            clearable
            autofocus
            class="full-width"
            :placeholder="$t('shop_admin.storefront_add_product_search_placeholder')"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </div>

        <div class="col scroll q-px-md q-pb-md relative-position min-width-0">
          <q-inner-loading :showing="isSearching" color="primary" />

          <div
            v-if="search.trim().length === 0"
            class="text-center text-grey-6 q-pa-lg"
          >
            {{ $t('shop_admin.storefront_search_to_find_products') }}
          </div>

          <div
            v-else-if="!isSearching && searchResults.length === 0"
            class="column q-gutter-y-md"
          >
            <div class="text-center text-grey-6 q-pa-lg">
              {{ $t('shop_admin.storefront_no_products_found') }}
            </div>
            <q-card flat bordered class="add-product-create-card" clickable @click="openCreateForm()">
              <q-card-section class="row items-center no-wrap q-col-gutter-sm">
                <div class="col-auto">
                  <q-avatar square color="primary" text-color="white" icon="ph ph-plus" size="48px" />
                </div>
                <div class="col min-width-0">
                  <div class="text-weight-medium ellipsis">{{ createNewProductLabel }}</div>
                  <div class="text-caption text-grey-7">
                    {{ $t('shop_admin.storefront_cant_find_create_product') }}
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>

          <div v-else class="column q-gutter-y-sm full-width">
            <q-card
              v-for="product in searchResults"
              :key="product.id"
              flat
              bordered
              class="add-product-result-card"
            >
              <q-card-section class="row items-center no-wrap q-col-gutter-sm">
                <div class="col-auto">
                  <q-avatar square size="48px" class="bg-grey-2 rounded-borders">
                    <img
                      v-if="product.image_url"
                      :src="product.image_url"
                      :alt="product.name ?? ''"
                    />
                    <q-icon v-else name="ph ph-package" color="grey-6" />
                  </q-avatar>
                </div>
                <div class="col min-width-0">
                  <div class="text-weight-medium ellipsis-2-lines">{{ product.name }}</div>
                  <div class="text-caption text-grey-7 ellipsis">
                    {{ [product.product_code, product.barcode].filter(Boolean).join(' · ') }}
                  </div>
                </div>
                <div class="col-auto">
                  <q-btn
                    unelevated
                    dense
                    round
                    color="primary"
                    icon="ph ph-plus"
                    :loading="addingProductId === product.id"
                    @click="onAddProduct(product)"
                  >
                    <q-tooltip>{{ $t('shop_admin.storefront_add_product') }}</q-tooltip>
                  </q-btn>
                </div>
              </q-card-section>
            </q-card>

            <q-card flat bordered class="add-product-create-card" clickable @click="openCreateForm()">
              <q-card-section class="row items-center no-wrap q-col-gutter-sm">
                <div class="col-auto">
                  <q-avatar square color="primary" text-color="white" icon="ph ph-plus" size="48px" />
                </div>
                <div class="col min-width-0">
                  <div class="text-weight-medium ellipsis">{{ createNewProductLabel }}</div>
                  <div class="text-caption text-grey-7">
                    {{ $t('shop_admin.storefront_cant_find_create_product') }}
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>

      <div v-else class="col scroll q-pa-md">
        <ShopStorefrontCreateProductForm
          :initial-name="createFormInitialName"
          :tenant-id="tenantId"
          @cancel="closeCreateForm"
          @saved="onProductCreated"
        />
      </div>

      <template v-if="!showCreateForm">
        <q-separator />
        <div class="q-pa-md bg-grey-1 row items-center justify-end">
          <q-btn
            flat
            :label="$t('shop_admin.cancel')"
            color="grey-8"
            no-caps
            @click="isOpen = false"
          />
        </div>
      </template>
    </div>

    <q-dialog v-model="gradePickerOpen">
      <q-card style="min-width: 320px">
        <q-card-section>
          <div class="text-subtitle1 text-weight-bold">
            {{ $t('shop_admin.storefront_pick_grade_title') }}
          </div>
          <div class="text-caption text-grey-7 q-mt-xs">
            {{ $t('shop_admin.storefront_pick_grade_hint') }}
          </div>
        </q-card-section>
        <q-separator />
        <q-list dense>
          <q-item
            v-for="row in gradePickerOptions"
            :key="row.global_stock_id"
            clickable
            v-close-popup
            @click="confirmAddWithStock(row)"
          >
            <q-item-section>
              <q-item-label>{{ row.stock_grade?.label ?? $t('shop_admin.storefront_grade_standard') }}</q-item-label>
              <q-item-label caption>
                {{ $t('shop_admin.storefront_qty_available', { qty: row.allocated_quantity }) }}
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
        <q-card-actions align="right">
          <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import type { Product } from 'src/modules/products/types';
import type { ShopType } from '../types';
import type { CandidateAllocation } from '../types/pricing';
import ShopStorefrontCreateProductForm from './ShopStorefrontCreateProductForm.vue';
import { useShopStorefrontCatalogSearchQuery } from '../composables/useShopStorefrontCatalogSearchQuery';
import { useShopPricingCandidatesQuery, useShopPricingRuleQuery } from '../composables/useShopPricingQuery';
import { useAddShopStorefrontListingMutation } from '../composables/useShopStorefrontAdminMutations';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  shopId: number | null;
  tenantId: number | null;
  shopType?: ShopType | null;
  sellCurrencyId?: number | null;
  markupPercentage?: number | null;
  listedGradeKeys?: string[];
  listedProductIds?: number[];
}>();

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void;
  (event: 'saved'): void;
}>();

const { t } = useI18n();

const search = ref('');
const showCreateForm = ref(false);
const createFormInitialName = ref('');
const addingProductId = ref<number | null>(null);
const gradePickerOpen = ref(false);
const gradePickerOptions = ref<CandidateAllocation[]>([]);

const shopIdRef = computed(() => props.shopId);
const tenantIdRef = computed(() => props.tenantId);
const drawerEnabled = computed(() => props.modelValue);

const { data: catalogResult, isFetching: isSearching } = useShopStorefrontCatalogSearchQuery(
  tenantIdRef,
  search,
  drawerEnabled,
);

const { data: candidates } = useShopPricingCandidatesQuery(
  tenantIdRef,
  shopIdRef,
  drawerEnabled,
);

const { data: pricingRule } = useShopPricingRuleQuery(shopIdRef);

const { mutate: addListing, isPending: isAddingListing } = useAddShopStorefrontListingMutation();

const isOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const drawerWidth = computed(() => (showCreateForm.value ? 720 : 520));

const searchResults = computed(() => catalogResult.value?.data ?? []);

const listedGradeKeySet = computed(() => new Set(props.listedGradeKeys ?? []));
const listedProductIdSet = computed(() => new Set(props.listedProductIds ?? []));

const createNewProductLabel = computed(() => {
  const query = search.value.trim();
  return query
    ? t('shop_admin.storefront_create_named_product', { name: query })
    : t('shop_admin.storefront_add_new_product');
});

const gradeKey = (productId: number, gradeSlug: string | null | undefined) =>
  `${productId}:${gradeSlug ?? 'standard'}`;

const availableStockForProduct = (productId: number): CandidateAllocation[] => {
  const rows = (candidates.value ?? []).filter((row) => row.product_id === productId);
  return rows.filter((row) => !listedGradeKeySet.value.has(gradeKey(productId, row.stock_grade?.slug)));
};

const submitStockListing = (stock: CandidateAllocation) => {
  if (!props.shopId || !props.tenantId || props.sellCurrencyId == null) return;

  addListing(
    {
      mode: 'stock',
      shopId: props.shopId,
      tenantId: props.tenantId,
      stock,
      sellCurrencyId: props.sellCurrencyId,
      shopType: props.shopType ?? 'fixed_price',
      markupPercentage: Number(props.markupPercentage ?? pricingRule.value?.markup_percentage ?? 0),
      dropshipMarkupPercentage: Number(pricingRule.value?.dropship_markup_percentage ?? 0),
    },
    {
      onSuccess: () => {
        addingProductId.value = null;
        showSuccessNotification(t('shop_admin.storefront_listing_added'));
        emit('saved');
        isOpen.value = false;
      },
      onError: (error: Error) => {
        addingProductId.value = null;
        showErrorNotification(error.message || t('shop_admin.storefront_listing_add_failed'));
      },
    },
  );
};

const submitProductListing = (product: Product) => {
  if (!props.shopId || !props.tenantId || props.sellCurrencyId == null) return;

  addListing(
    {
      mode: 'product',
      shopId: props.shopId,
      tenantId: props.tenantId,
      product,
      sellCurrencyId: props.sellCurrencyId,
    },
    {
      onSuccess: () => {
        addingProductId.value = null;
        showSuccessNotification(t('shop_admin.storefront_listing_added_inactive'));
        emit('saved');
        isOpen.value = false;
      },
      onError: (error: Error) => {
        addingProductId.value = null;
        showErrorNotification(error.message || t('shop_admin.storefront_listing_add_failed'));
      },
    },
  );
};

const confirmAddWithStock = (stock: CandidateAllocation) => {
  if (isAddingListing.value) return;
  submitStockListing(stock);
};

const onAddProduct = (product: Product) => {
  if (!props.shopId || !props.tenantId) return;

  addingProductId.value = product.id;
  const available = availableStockForProduct(product.id);

  if (available.length > 1) {
    addingProductId.value = null;
    gradePickerOptions.value = available;
    gradePickerOpen.value = true;
    return;
  }

  if (available.length === 1) {
    submitStockListing(available[0]!);
    return;
  }

  if (listedProductIdSet.value.has(product.id)) {
    addingProductId.value = null;
    showErrorNotification(t('shop_admin.storefront_product_already_listed'));
    return;
  }

  submitProductListing(product);
};

const openCreateForm = () => {
  createFormInitialName.value = search.value.trim();
  showCreateForm.value = true;
};

const closeCreateForm = () => {
  showCreateForm.value = false;
  createFormInitialName.value = '';
};

const onProductCreated = (_product: Product) => {
  showSuccessNotification(t('shop_admin.storefront_product_created_no_stock'));
  closeCreateForm();
  search.value = _product.name ?? '';
};

const resetDrawer = () => {
  search.value = '';
  showCreateForm.value = false;
  createFormInitialName.value = '';
  addingProductId.value = null;
  gradePickerOpen.value = false;
  gradePickerOptions.value = [];
};

watch(isOpen, (open) => {
  if (!open) {
    resetDrawer();
  }
});
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.add-product-result-card,
.add-product-create-card {
  border-radius: 8px;
  width: 100%;
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
}
</style>

<style>
.shop-storefront-add-product-drawer .q-drawer__content {
  overflow: hidden;
}
</style>
