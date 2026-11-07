<template>
  <q-card flat bordered class="q-pa-xs flex-shrink-0">
    <div class="row items-center q-gutter-x-xs no-wrap full-width justify-end">
      <div
        class="row items-center no-wrap q-gutter-x-xs flex-shrink-0"
        :class="{ 'col-grow': searchFieldOpen }"
      >
        <q-btn
          v-if="!searchFieldOpen"
          flat
          round
          dense
          icon="ph ph-magnifying-glass"
          class="text-grey-7"
          :aria-label="$t('shop_admin.search_orders', 'Search orders')"
          data-test="shop-orders-search-toggle"
          @click="openSearchField"
        >
          <q-tooltip :delay="400">
            {{
              $t(
                'shop_admin.search_orders_tooltip',
                'Search by order number, recipient, or shop',
              )
            }}
          </q-tooltip>
        </q-btn>
        <q-input
          v-else
          ref="searchInputRef"
          :model-value="search"
          clearable
          dense
          outlined
          hide-bottom-space
          style="min-width: 220px"
          class="col-grow orders-toolbar-search"
          :placeholder="$t('shop_admin.search_orders_placeholder', 'Search by Order No, recipient, shop...')"
          data-test="shop-orders-search"
          @update:model-value="onSearchInput"
          @keyup.enter="emit('apply-search')"
          @clear="emit('apply-search')"
          @blur="onSearchBlur"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-6" />
          </template>
        </q-input>
        <q-btn
          flat
          round
          dense
          icon="ph ph-funnel"
          class="text-grey-7"
          :aria-label="$t('shop_admin.filter_orders', 'Filter orders')"
          data-test="shop-orders-filter-menu"
        >
          <q-badge
            v-if="activeFilterCount > 0"
            color="primary"
            rounded
            floating
            :label="String(activeFilterCount)"
          />
          <q-tooltip :delay="400">
            {{
              $t(
                'shop_admin.filter_orders_tooltip',
                'Filter by shop, customer profile, and order status',
              )
            }}
          </q-tooltip>
          <q-menu
            v-model="filterMenuOpen"
            anchor="bottom right"
            self="top right"
            @before-show="syncDraftFromApplied"
          >
            <div class="orders-filter-menu q-pa-sm column q-gutter-y-sm">
              <q-select
                v-model="draftShopId"
                dense
                outlined
                hide-bottom-space
                emit-value
                map-options
                use-input
                input-debounce="200"
                :label="$t('shop_admin.filter_by_shop', 'Shop')"
                :options="filteredShopOptions"
                :loading="shopsLoading"
                data-test="shop-orders-shop-filter"
                @filter="filterShops"
              >
                <template #prepend>
                  <q-icon name="ph ph-storefront" size="16px" class="text-grey-6" />
                </template>
                <template #no-option>
                  <q-item>
                    <q-item-section class="text-grey-6">
                      {{ shopsLoading ? $t('shop_admin.loading_orders') : $t('shop_admin.no_shops_found') }}
                    </q-item-section>
                  </q-item>
                </template>
              </q-select>

              <q-select
                v-model="draftProfileId"
                dense
                outlined
                hide-bottom-space
                emit-value
                map-options
                use-input
                input-debounce="200"
                :label="$t('shop_admin.filter_by_profile', 'Profile')"
                :options="filteredProfileOptions"
                :loading="profilesLoading"
                data-test="shop-orders-profile-filter"
                @filter="filterProfiles"
              >
                <template #prepend>
                  <q-icon name="ph ph-user" size="16px" class="text-grey-6" />
                </template>
                <template #no-option>
                  <q-item>
                    <q-item-section class="text-grey-6">
                      {{
                        profilesLoading
                          ? $t('shop_admin.loading_orders')
                          : $t('shop_admin.no_profiles_found', 'No profiles found')
                      }}
                    </q-item-section>
                  </q-item>
                </template>
              </q-select>

              <q-select
                v-if="showStatusFilter"
                v-model="draftStatusFilter"
                dense
                outlined
                hide-bottom-space
                emit-value
                map-options
                :label="$t('shop_admin.filter_by_status', 'Status')"
                :options="statusOptions"
                data-test="shop-orders-status-filter"
              >
                <template #prepend>
                  <q-icon name="ph ph-flag" size="16px" class="text-grey-6" />
                </template>
              </q-select>

              <div class="row items-center justify-end q-gutter-x-xs q-pt-xs">
                <TfBtn
                  flat
                  size="sm"
                  :label="$t('common.reset', 'Reset')"
                  data-test="shop-orders-filter-reset"
                  @click="resetDraftFilters"
                />
                <TfBtn
                  color="primary"
                  size="sm"
                  :label="$t('shop_admin.apply_filters', 'Apply filters')"
                  data-test="shop-orders-filter-apply"
                  @click="applyDraftFilters"
                />
              </div>
            </div>
          </q-menu>
        </q-btn>

        <q-btn
          v-if="showCancelledDeleteEntry"
          flat
          round
          dense
          icon="ph ph-trash"
          color="negative"
          :aria-label="$t('shop_admin.delete', 'Delete')"
          data-test="shop-orders-open-cancelled-delete"
          @click="emit('open-cancelled-delete')"
        >
          <q-tooltip :delay="400">
            {{
              $t(
                'shop_admin.delete_cancelled_orders_tooltip',
                'Open the page to permanently delete cancelled orders',
              )
            }}
          </q-tooltip>
        </q-btn>

        <q-btn
          v-if="showCreateActions"
          flat
          round
          dense
          color="primary"
          icon="ph ph-plus"
          :aria-label="$t('shop_admin.create_order', 'Create order')"
          data-test="shop-orders-create-menu"
        >
          <q-tooltip :delay="400">
            {{
              $t(
                'shop_admin.create_order_tooltip',
                'Create order — choose catalog or dropship',
              )
            }}
          </q-tooltip>
          <q-menu anchor="bottom right" self="top right">
            <q-list dense>
              <q-item
                v-close-popup
                clickable
                data-test="shop-orders-create-catalog"
                @click="emit('create-catalog')"
              >
                <q-item-section avatar>
                  <q-icon name="ph ph-clipboard-text" />
                </q-item-section>
                <q-item-section>{{ $t('shop_admin.create_catalog_order', 'Create catalog order') }}</q-item-section>
              </q-item>
              <q-item
                v-close-popup
                clickable
                data-test="shop-orders-create-dropship"
                @click="emit('create-dropship')"
              >
                <q-item-section avatar>
                  <q-icon name="ph ph-package" />
                </q-item-section>
                <q-item-section>{{ $t('shop_admin.create_dropship_order', 'Create dropship order') }}</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>

        <q-btn
          flat
          round
          dense
          icon="ph ph-arrows-clockwise"
          class="text-grey-7"
          :loading="refreshing"
          :aria-label="$t('common.refresh', 'Refresh')"
          data-test="shop-orders-refresh"
          @click="emit('refresh')"
        >
          <q-tooltip :delay="400">
            {{ $t('shop_admin.reload_orders_tooltip', 'Reload the order list') }}
          </q-tooltip>
        </q-btn>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';
import type { QInput } from 'quasar';
import { useI18n } from 'vue-i18n';
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { CustomerProfile } from 'src/modules/sales_invoice/repositories/customerProfileRepository';
import type { StaffOrdersPageShop } from '../types';

const props = withDefaults(
  defineProps<{
    shops: StaffOrdersPageShop[];
    profiles: CustomerProfile[];
    selectedShopId: number | null;
    selectedProfileId: number | null;
    search: string;
    statusFilter: string | null;
    shopsLoading?: boolean;
    profilesLoading?: boolean;
    refreshing?: boolean;
    showStatusFilter?: boolean;
    showCreateActions?: boolean;
    showCancelledDeleteEntry?: boolean;
  }>(),
  {
    showStatusFilter: true,
    showCreateActions: true,
    showCancelledDeleteEntry: true,
  },
);

const emit = defineEmits<{
  (e: 'refresh'): void;
  (e: 'create-dropship'): void;
  (e: 'create-catalog'): void;
  (e: 'open-cancelled-delete'): void;
  (e: 'apply-search'): void;
  (e: 'update:selectedShopId', value: number | null): void;
  (e: 'update:selectedProfileId', value: number | null): void;
  (e: 'update:search', value: string): void;
  (e: 'update:statusFilter', value: string | null): void;
}>();

const onSearchInput = (val: string | number | null) => {
  const next = (val as string) || '';
  emit('update:search', next);
  if (!next) {
    emit('apply-search');
  }
};

const searchFieldOpen = ref(Boolean(props.search.trim()));
const searchInputRef = ref<QInput | null>(null);

watch(
  () => props.search,
  (value) => {
    if (value.trim()) {
      searchFieldOpen.value = true;
    }
  },
);

const openSearchField = () => {
  searchFieldOpen.value = true;
  void nextTick(() => {
    searchInputRef.value?.focus();
  });
};

const onSearchBlur = () => {
  if (!props.search.trim()) {
    searchFieldOpen.value = false;
  }
};

const { t } = useI18n();

const filterMenuOpen = ref(false);
const draftShopId = ref<number | null>(null);
const draftProfileId = ref<number | null>(null);
const draftStatusFilter = ref<string | null>(null);

const syncDraftFromApplied = () => {
  draftShopId.value = props.selectedShopId;
  draftProfileId.value = props.selectedProfileId;
  draftStatusFilter.value = props.statusFilter;
};

const resetDraftFilters = () => {
  draftShopId.value = null;
  draftProfileId.value = null;
  draftStatusFilter.value = null;
};

const applyDraftFilters = () => {
  emit('update:selectedShopId', draftShopId.value);
  emit('update:selectedProfileId', draftProfileId.value);
  emit('update:statusFilter', draftStatusFilter.value);
  filterMenuOpen.value = false;
};

const activeFilterCount = computed(() => {
  let n = 0;
  if (props.selectedShopId !== null) n += 1;
  if (props.selectedProfileId !== null) n += 1;
  if (props.showStatusFilter && props.statusFilter) n += 1;
  return n;
});

const shopSearch = ref('');
const profileSearch = ref('');

const formatProfileLabel = (profile: CustomerProfile) => {
  const name = (profile.name || '').trim() || `Profile #${profile.id}`;
  const phone = (profile.phone || '').trim();
  const email = (profile.email || '').trim();
  const secondary = phone || email;
  return secondary ? `${name} (${secondary})` : name;
};

const statusOptions = computed(() => [
  { label: t('shop_admin.all_statuses'), value: null },
  { label: t('shop_admin.status_submitted'), value: 'submitted' },
  { label: t('shop_admin.status_costing_pending'), value: 'costing_pending' },
  { label: t('shop_admin.status_priced'), value: 'priced' },
  { label: t('shop_admin.status_countered'), value: 'countered' },
  { label: t('shop_admin.status_final_offered'), value: 'final_offered' },
  { label: t('shop_admin.status_confirmed'), value: 'confirmed' },
  { label: t('shop_admin.status_procuring'), value: 'procuring' },
  { label: t('shop_admin.status_packed'), value: 'packed' },
  { label: t('shop_admin.status_delivered'), value: 'delivered' },
  { label: t('shop_admin.status_processing'), value: 'processing' },
  { label: t('shop_admin.status_shipped'), value: 'shipped' },
  { label: t('shop_admin.status_payment_received'), value: 'payment_received' },
  { label: t('shop_admin.status_negotiating'), value: 'negotiating' },
  { label: t('shop_admin.status_placed'), value: 'placed' },
  { label: t('shop_admin.status_fulfilled'), value: 'fulfilled' },
  { label: t('shop_admin.status_cancelled'), value: 'cancelled' },
]);

const allShopsOption = computed(() => ({
  label: t('shop_admin.all_shops'),
  value: null as number | null,
}));

const shopOptions = computed(() => [
  allShopsOption.value,
  ...props.shops.map((shop) => ({
    label: shop.tenant_name ? `${shop.name} (${shop.tenant_name})` : shop.name,
    value: shop.id,
  })),
]);

const filteredShopOptions = computed(() => {
  const needle = shopSearch.value.trim().toLowerCase();
  if (!needle) {
    return shopOptions.value;
  }
  const matchesAll = allShopsOption.value.label.toLowerCase().includes(needle);
  const shopMatches = shopOptions.value
    .slice(1)
    .filter((opt) => opt.label.toLowerCase().includes(needle));
  return matchesAll ? [allShopsOption.value, ...shopMatches] : shopMatches;
});

const filterShops = (val: string, update: (cb: () => void) => void) => {
  update(() => {
    shopSearch.value = val;
  });
};

const allProfilesOption = computed(() => ({
  label: t('shop_admin.all_profiles', 'All profiles'),
  value: null as number | null,
}));

const profileOptions = computed(() => [
  allProfilesOption.value,
  ...props.profiles.map((profile) => ({
    label: formatProfileLabel(profile),
    value: profile.id,
  })),
]);

const filteredProfileOptions = computed(() => {
  const needle = profileSearch.value.trim().toLowerCase();
  if (!needle) {
    return profileOptions.value;
  }
  const matchesAll = allProfilesOption.value.label.toLowerCase().includes(needle);
  const profileMatches = profileOptions.value
    .slice(1)
    .filter((opt) => opt.label.toLowerCase().includes(needle));
  return matchesAll ? [allProfilesOption.value, ...profileMatches] : profileMatches;
});

const filterProfiles = (val: string, update: (cb: () => void) => void) => {
  update(() => {
    profileSearch.value = val;
  });
};
</script>

<style scoped>
.orders-filter-menu {
  min-width: 280px;
  max-width: min(360px, 92vw);
}

.orders-toolbar-search {
  min-width: 0;
  max-width: 100%;
}
</style>
