<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header following PAGE_HEADER.md standard -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="ph ph-arrow-left" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">{{ $t('navigation.shops') }}</div>
              <h1 class="text-h5 q-my-none">
                Add Product Listings
              </h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Select listable parent stock rows assigned to this shop.
              </p>
            </div>
          </div>
        </div>
        <div v-if="selectedCandidates.length > 0" class="col-auto">
          <q-btn
            color="primary"
            icon="ph ph-plus-circle"
            :label="`Add Selected (${selectedCandidates.length})`"
            :loading="isBatchAdding"
            @click="addSelectedListings"
          />
        </div>
      </section>

      <!-- Toolbar Search & Filters -->
      <section class="row items-center q-col-gutter-md">
        <div class="col-12 col-sm-4">
          <q-input
            v-model="search"
            clearable
            dense
            outlined
            placeholder="Search candidate products..."
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
            label="Filter by Shipment"
          >
            <template #prepend>
              <q-icon name="ph ph-package" color="grey-6" />
            </template>
          </q-select>
        </div>

        <div class="col-12 col-sm-4">
          <q-select
            v-model="selectedBrand"
            :options="brandOptions"
            emit-value
            map-options
            dense
            outlined
            options-dense
            label="Filter by Brand"
          >
            <template #prepend>
              <q-icon name="ph ph-tag" color="grey-6" />
            </template>
          </q-select>
        </div>
      </section>

      <!-- Candidates Table -->
      <q-card flat bordered>
        <q-card-section v-if="isLoading" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          Loading unlisted allocations...
        </q-card-section>

        <q-card-section
          v-else-if="filteredCandidates.length === 0"
          class="text-grey-6 text-center q-pa-xl"
        >
          <q-icon name="ph ph-check-circle" size="48px" class="q-mb-sm block" color="positive" />
          All allocated stock pools have already been published!
        </q-card-section>

        <q-table
          v-else
          v-model:selected="selectedCandidates"
          flat
          selection="multiple"
          row-key="global_stock_id"
          :rows="filteredCandidates"
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
                  <q-icon v-else name="ph ph-image" color="grey-6" />
                </q-avatar>
                <div class="ellipsis" style="max-width: 250px">
                  <div class="text-weight-bold text-grey-9">{{ props.row.product_name }}</div>
                  <div class="text-caption text-grey-6">
                    {{ props.row.product_brand }} | {{ props.row.product_category }}
                  </div>
                </div>
              </div>
            </q-td>
          </template>

          <!-- Shipment Badge -->
          <template #body-cell-shipment_id="props">
            <q-td :props="props" class="text-center">
              <q-chip
                v-if="props.row.shipment_id"
                dense
                size="sm"
                color="deep-purple-1"
                text-color="deep-purple-8"
                icon="ph ph-package"
              >
                Shipment #{{ props.row.shipment_id }}
              </q-chip>
              <span v-else class="text-grey-5">—</span>
            </q-td>
          </template>

          <!-- Cost Floor -->
          <template #body-cell-minimum_sell_price="props">
            <q-td :props="props">
              <div class="text-weight-medium text-grey-9">
                {{ props.row.minimum_sell_price_amount ? formatMoney(props.row.minimum_sell_price_amount) : '—' }}
              </div>
            </q-td>
          </template>

          <!-- Allocated Qty -->
          <template #body-cell-allocated_quantity="props">
            <q-td :props="props" class="text-center">
              <q-badge color="blue-2" text-color="blue-9" class="text-weight-bold">
                {{ props.row.allocated_quantity }}
              </q-badge>
            </q-td>
          </template>

          <!-- Quick Add Action -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn
                unelevated
                color="primary"
                dense
                size="sm"
                icon="ph ph-plus"
                label="Quick Add"
                :loading="addingId === props.row.global_stock_id"
                @click="quickAddListing(props.row)"
              />
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  useShopPricingCandidatesQuery,
  useShopPricingRuleQuery,
  useShopCurrenciesQuery,
} from '../composables/useShopPricingQuery';
import { useSaveShopListingMutation } from '../composables/useShopPricingMutations';
import type { CandidateAllocation } from '../types';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');
const shopId = computed(() => Number(route.params.shopId));

const search = ref('');
const selectedShipment = ref<number | 'all'>('all');
const selectedBrand = ref<string>('all');
const selectedCandidates = ref<CandidateAllocation[]>([]);
const addingId = ref<number | null>(null);
const isBatchAdding = ref(false);
const addedAllocationIds = ref<Set<number>>(new Set());

const { data: rawCandidates, isLoading } = useShopPricingCandidatesQuery(tenantId, shopId);
const { data: pricingRule } = useShopPricingRuleQuery(shopId);
const { data: rawCurrencies } = useShopCurrenciesQuery();
const { mutateAsync: saveListingAsync } = useSaveShopListingMutation();

const candidates = computed(() => rawCandidates.value ?? []);
const currencies = computed(() => rawCurrencies.value ?? []);

const shipmentOptions = computed(() => {
  const set = new Set<number>();
  for (const c of candidates.value) {
    if (c.shipment_id) {
      set.add(c.shipment_id);
    }
  }
  const sorted = Array.from(set).sort((a, b) => a - b);
  return [
    { label: 'All Shipments', value: 'all' as const },
    ...sorted.map((id) => ({ label: `Shipment #${id}`, value: id })),
  ];
});

const brandOptions = computed(() => {
  const set = new Set<string>();
  for (const c of candidates.value) {
    if (c.product_brand) {
      set.add(c.product_brand);
    }
  }
  const sorted = Array.from(set).sort();
  return [
    { label: 'All Brands', value: 'all' as const },
    ...sorted.map((brand) => ({ label: brand, value: brand })),
  ];
});

const columns = [
  { name: 'product_name', label: 'Product', field: 'product_name', align: 'left' as const, sortable: true },
  { name: 'product_code', label: 'Code', field: 'product_code', align: 'left' as const, sortable: true },
  { name: 'shipment_id', label: 'Shipment', field: 'shipment_id', align: 'center' as const, sortable: true },
  { name: 'minimum_sell_price', label: 'Landed Cost / Floor', field: 'minimum_sell_price_amount', align: 'left' as const },
  { name: 'allocated_quantity', label: 'ATP', field: 'allocated_quantity', align: 'center' as const, sortable: true },
  { name: 'actions', label: '', field: 'global_stock_id', align: 'right' as const },
];

const filteredCandidates = computed(() => {
  let list = candidates.value.filter((c) => !addedAllocationIds.value.has(c.global_stock_id));

  if (selectedShipment.value !== 'all') {
    list = list.filter((c) => c.shipment_id === selectedShipment.value);
  }

  if (selectedBrand.value !== 'all') {
    list = list.filter(
      (c) => c.product_brand && c.product_brand.toLowerCase() === (selectedBrand.value as string).toLowerCase()
    );
  }

  const query = search.value.trim().toLowerCase();
  if (query) {
    list = list.filter(
      (c) =>
        c.product_name.toLowerCase().includes(query) ||
        (c.product_code && c.product_code.toLowerCase().includes(query)) ||
        (c.product_brand && c.product_brand.toLowerCase().includes(query)) ||
        (c.shipment_id && c.shipment_id.toString().includes(query))
    );
  }
  return list;
});

const formatMoney = (amount: number): string => {
  return `${Number(amount).toFixed(2)}`;
};

const buildPayload = (candidate: CandidateAllocation) => {
  const markup = pricingRule.value?.markup_percentage ?? 0;
  const landedCost = candidate.minimum_sell_price_amount ?? 0;
  const sellPrice = landedCost ? Number((landedCost * (1 + markup / 100)).toFixed(2)) : 0;
  const defaultCurrId = candidate.minimum_sell_price_currency_id || currencies.value[0]?.id || 1;

  return {
    tenant_id: tenantId.value,
    shop_id: shopId.value,
    global_stock_id: candidate.global_stock_id,
    sell_price_amount: sellPrice,
    sell_price_currency_id: defaultCurrId,
    minimum_sell_price_amount: landedCost || null,
    minimum_sell_price_currency_id: candidate.minimum_sell_price_currency_id || null,
    show_quantity: pricingRule.value?.default_show_quantity ?? true,
    display_quantity_override: null,
    is_active: true,
    is_price_locked: false,
    is_quantity_locked: false,
  };
};

const quickAddListing = async (candidate: CandidateAllocation) => {
  addingId.value = candidate.global_stock_id;
  try {
    await saveListingAsync(buildPayload(candidate));
    addedAllocationIds.value.add(candidate.global_stock_id);
    selectedCandidates.value = selectedCandidates.value.filter(
      (c) => c.global_stock_id !== candidate.global_stock_id
    );
  } catch (err: any) {
    $q.notify({
      type: 'negative',
      message: err?.message || 'Failed to add listing',
    });
  } finally {
    addingId.value = null;
  }
};

const addSelectedListings = async () => {
  if (selectedCandidates.value.length === 0) return;
  isBatchAdding.value = true;
  let successCount = 0;

  for (const candidate of [...selectedCandidates.value]) {
    try {
      await saveListingAsync(buildPayload(candidate));
      addedAllocationIds.value.add(candidate.global_stock_id);
      successCount++;
    } catch (err: any) {
      console.error(`Failed to add stock #${candidate.global_stock_id}`, err);
    }
  }

  $q.notify({
    type: 'positive',
    message: `Successfully added ${successCount} product listing(s).`,
  });

  selectedCandidates.value = [];
  isBatchAdding.value = false;
};

const goBack = () => {
  void router.push({
    name: 'app-shop-settings-page',
    params: { tenantSlug: tenantSlug.value, shopId: shopId.value },
    query: { tab: 'stock' },
  });
};
</script>
