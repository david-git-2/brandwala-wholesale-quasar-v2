<template>
  <component :is="embedded ? 'div' : 'q-page'" :class="embedded ? '' : 'bw-page'">
    <section :class="embedded ? 'column q-gutter-y-md' : 'bw-page__stack'">
      <section v-if="!embedded" class="row items-center q-gutter-x-sm">
        <q-btn flat round icon="ph ph-arrow-left" color="grey-7" @click="goBack" />
        <div>
          <div class="text-overline">{{ $t('navigation.shops') }}</div>
          <h1 class="text-h5 q-my-none">{{ $t('shop_admin.shop_stock_title') }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ $t('shop_admin.shop_stock_subtitle') }}
          </p>
        </div>
      </section>

      <section class="row items-center q-col-gutter-md">
        <div class="col-12 col-sm-5">
          <q-input
            v-model="search"
            clearable
            dense
            outlined
            :placeholder="$t('shop_admin.shop_stock_search_placeholder')"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </div>
        <div class="col-12 col-sm-4">
          <q-select
            v-model="selectedShipment"
            :options="shipmentOptions"
            emit-value
            map-options
            dense
            outlined
            options-dense
            :label="$t('shop_admin.shop_stock_filter_shipment')"
          >
            <template #prepend>
              <q-icon name="ph ph-package" color="grey-6" />
            </template>
          </q-select>
        </div>
        <div class="col-12 col-sm-3">
          <q-select
            v-model="listedFilter"
            :options="listedFilterOptions"
            emit-value
            map-options
            dense
            outlined
            options-dense
            :label="$t('shop_admin.shop_stock_filter_listed')"
          />
        </div>
      </section>

      <q-card flat bordered class="q-pa-none">
        <q-card-section v-if="isLoading" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          {{ $t('shop_admin.shop_stock_loading') }}
        </q-card-section>

        <q-card-section
          v-else-if="isError"
          class="text-negative text-center q-pa-xl"
        >
          {{ error?.message || $t('shop_admin.shop_stock_load_failed') }}
        </q-card-section>

        <q-card-section
          v-else-if="filteredRows.length === 0"
          class="text-grey-6 text-center q-pa-xl"
        >
          <q-icon name="ph ph-warehouse" size="48px" class="q-mb-sm block" />
          {{ $t('shop_admin.shop_stock_empty') }}
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="global_stock_id"
          :rows="filteredRows"
          :columns="columns"
          :pagination="{ rowsPerPage: 25 }"
          :dense="$q.screen.lt.md"
          class="shop-warehouse-stock-table"
        >
          <template #body-cell-product="props">
            <q-td :props="props">
              <div class="row items-center no-wrap q-gutter-x-sm">
                <q-avatar size="40px" square class="bg-grey-2 rounded-borders">
                  <img v-if="props.row.image_url" :src="props.row.image_url" :alt="props.row.item_name" />
                  <q-icon v-else name="ph ph-package" color="grey-6" />
                </q-avatar>
                <div class="min-width-0">
                  <div class="text-weight-medium ellipsis">{{ props.row.item_name }}</div>
                  <div class="text-caption text-grey-7 ellipsis">
                    {{ [props.row.product_code, props.row.barcode].filter(Boolean).join(' · ') }}
                  </div>
                </div>
              </div>
            </q-td>
          </template>

          <template #body-cell-grade="props">
            <q-td :props="props">
              <q-chip
                v-if="props.row.stock_grade?.label"
                dense
                size="sm"
                text-color="white"
                :style="gradeStyle(props.row.stock_grade?.color)"
              >
                {{ props.row.stock_grade.label }}
              </q-chip>
              <span v-else class="text-grey-6">—</span>
            </q-td>
          </template>

          <template #body-cell-shipment="props">
            <q-td :props="props">
              <div class="text-weight-medium">{{ props.row.shipment_name }}</div>
              <div class="text-caption text-grey-7">#{{ props.row.shipment_id }}</div>
            </q-td>
          </template>

          <template #body-cell-atp="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="props.row.available_atp > 0 ? 'blue-2' : 'grey-3'"
                :text-color="props.row.available_atp > 0 ? 'blue-9' : 'grey-8'"
                class="text-weight-bold"
              >
                {{ props.row.available_atp }}
              </q-badge>
            </q-td>
          </template>

          <template #body-cell-unit_cost="props">
            <q-td :props="props" class="text-right">
              {{ formatMoney(props.row.unit_cost_amount) }}
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props">
              <q-chip
                v-if="props.row.is_listed_on_shop"
                dense
                size="sm"
                color="positive"
                text-color="white"
                icon="ph ph-check"
              >
                {{ $t('shop_admin.shop_stock_listed') }}
              </q-chip>
              <q-chip v-else dense size="sm" color="grey-3" text-color="grey-8">
                {{ $t('shop_admin.shop_stock_not_listed') }}
              </q-chip>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn
                v-if="!props.row.is_listed_on_shop && props.row.available_atp > 0"
                unelevated
                dense
                no-caps
                size="sm"
                color="primary"
                icon="ph ph-plus"
                :label="$t('shop_admin.shop_stock_add_to_storefront')"
                :loading="addingStockId === props.row.global_stock_id"
                @click="addToStorefront(props.row)"
              />
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>
  </component>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useI18n } from 'vue-i18n';
import { useQueryClient } from '@tanstack/vue-query';
import type { Shop, ShopAllocatedStockRow } from '../types';
import type { CandidateAllocation } from '../types/pricing';
import { useShopAllocatedStockQuery } from '../composables/useShopAllocatedStockQuery';
import { useShopPricingRuleQuery } from '../composables/useShopPricingQuery';
import { useAddShopStorefrontListingMutation } from '../composables/useShopStorefrontAdminMutations';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const props = withDefaults(
  defineProps<{
    embedded?: boolean;
    shop: Shop;
    tenantId: number;
    enabled?: boolean;
  }>(),
  {
    embedded: false,
    enabled: true,
  },
);

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const { t } = useI18n();
const queryClient = useQueryClient();

const shopId = computed(() => props.shop.id);
const shopIdRef = computed(() => shopId.value);
const enabledRef = computed(() => props.enabled);

const search = ref('');
const selectedShipment = ref<number | 'all'>('all');
const listedFilter = ref<'all' | 'listed' | 'unlisted'>('all');
const addingStockId = ref<number | null>(null);

const { data: stockResult, isLoading, isError, error } = useShopAllocatedStockQuery(
  shopIdRef,
  search,
  enabledRef,
);
const { data: pricingRule } = useShopPricingRuleQuery(shopIdRef);
const { mutate: addListing } = useAddShopStorefrontListingMutation();

const rows = computed(() => stockResult.value?.data ?? []);

const shipmentOptions = computed(() => {
  const ids = new Set<number>();
  rows.value.forEach((row) => {
    if (row.shipment_id) ids.add(row.shipment_id);
  });
  return [
    { label: t('shop_admin.shop_stock_all_shipments'), value: 'all' as const },
    ...[...ids].sort((a, b) => a - b).map((id) => ({
      label: t('shop_admin.shop_stock_shipment_no', { id }),
      value: id,
    })),
  ];
});

const listedFilterOptions = computed(() => [
  { label: t('shop_admin.shop_stock_filter_all'), value: 'all' as const },
  { label: t('shop_admin.shop_stock_filter_listed_only'), value: 'listed' as const },
  { label: t('shop_admin.shop_stock_filter_unlisted_only'), value: 'unlisted' as const },
]);

const columns = computed(() => [
  {
    name: 'product',
    label: t('shop_admin.shop_stock_col_product'),
    field: 'item_name',
    align: 'left' as const,
    sortable: true,
  },
  {
    name: 'grade',
    label: t('shop_admin.shop_stock_col_grade'),
    field: 'stock_grade',
    align: 'left' as const,
  },
  {
    name: 'shipment',
    label: t('shop_admin.shop_stock_col_shipment'),
    field: 'shipment_name',
    align: 'left' as const,
    sortable: true,
  },
  {
    name: 'atp',
    label: t('shop_admin.shop_stock_col_atp'),
    field: 'available_atp',
    align: 'center' as const,
    sortable: true,
  },
  {
    name: 'unit_cost',
    label: t('shop_admin.shop_stock_col_unit_cost'),
    field: 'unit_cost_amount',
    align: 'right' as const,
    sortable: true,
  },
  {
    name: 'status',
    label: t('shop_admin.shop_stock_col_status'),
    field: 'is_listed_on_shop',
    align: 'left' as const,
  },
  {
    name: 'actions',
    label: '',
    field: 'global_stock_id',
    align: 'right' as const,
  },
]);

const filteredRows = computed(() => {
  let list = rows.value;

  if (selectedShipment.value !== 'all') {
    list = list.filter((row) => row.shipment_id === selectedShipment.value);
  }

  if (listedFilter.value === 'listed') {
    list = list.filter((row) => row.is_listed_on_shop);
  } else if (listedFilter.value === 'unlisted') {
    list = list.filter((row) => !row.is_listed_on_shop);
  }

  return list;
});

const gradeStyle = (color?: string | null) => {
  const c = color?.trim();
  return c ? { backgroundColor: c } : undefined;
};

const formatMoney = (amount: number) => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '—';
  return n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};

const toCandidate = (row: ShopAllocatedStockRow): CandidateAllocation => ({
  global_stock_id: row.global_stock_id,
  stock_id: row.global_stock_id,
  product_id: row.product_id,
  product_name: row.item_name,
  product_image_url: row.image_url,
  product_barcode: row.barcode,
  product_code: row.product_code,
  product_brand: row.product_brand,
  product_category: row.product_category,
  allocated_quantity: row.available_atp,
  unit_cost_amount: row.unit_cost_amount,
  shipment_item_id: row.shipment_item_id,
  shipment_id: row.shipment_id,
  stock_grade: row.stock_grade,
});

const addToStorefront = (row: ShopAllocatedStockRow) => {
  addingStockId.value = row.global_stock_id;
  addListing(
    {
      mode: 'stock',
      shopId: shopId.value,
      tenantId: props.tenantId,
      stock: toCandidate(row),
      sellCurrencyId: props.shop.sell_currency_id,
      shopType: props.shop.shop_type,
      markupPercentage: Number(props.shop.markup_percentage ?? pricingRule.value?.markup_percentage ?? 0),
      dropshipMarkupPercentage: Number(pricingRule.value?.dropship_markup_percentage ?? 0),
    },
    {
      onSuccess: () => {
        addingStockId.value = null;
        showSuccessNotification(t('shop_admin.storefront_listing_added'));
        void queryClient.invalidateQueries({
          queryKey: ['shopOrder', 'shopAllocatedStock'],
        });
        void queryClient.invalidateQueries({
          queryKey: ['shopOrder', 'storefrontAdminListings', { shopId: shopId.value }],
        });
      },
      onError: (err: Error) => {
        addingStockId.value = null;
        showErrorNotification(err.message || t('shop_admin.storefront_listing_add_failed'));
      },
    },
  );
};

const goBack = () => {
  void router.push({
    name: 'app-shop-settings-page',
    params: route.params,
    query: { tab: 'storefront' },
  });
};
</script>

<style scoped>
.shop-warehouse-stock-table :deep(thead tr th) {
  font-weight: 600;
}
</style>
