<template>
  <div>
    <ProcurementOpsListToolbar
      :search="search"
      :search-placeholder="$t('shop_admin.search_orders_placeholder', 'Search by Order No, recipient, shop...')"
      :filter-count="activeFilterCount"
      icon-search
      search-on-enter
      data-test="shop-orders-toolbar"
      @update:search="onToolbarSearch"
      @open-filters="filterDrawerOpen = true"
    >
      <template #trailing>
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
      </template>
    </ProcurementOpsListToolbar>

    <div
      v-if="hasVisibleChips"
      class="row items-center q-gutter-xs q-px-xs flex-shrink-0 wrap shop-orders-active-filters"
    >
      <q-chip
        v-if="search.trim()"
        removable
        dense
        outline
        color="primary"
        data-test="shop-orders-chip-search"
        @remove="clearSearchChip"
      >
        {{ $t('shop_admin.filter_chip_search', 'Search') }}: {{ search.trim() }}
      </q-chip>
      <q-chip
        v-if="selectedShopId !== null && selectedShopLabel"
        removable
        dense
        outline
        color="primary"
        data-test="shop-orders-chip-shop"
        @remove="emit('update:selectedShopId', null)"
      >
        {{ $t('shop_admin.filter_by_shop', 'Shop') }}: {{ selectedShopLabel }}
      </q-chip>
      <q-chip
        v-if="selectedProfileId !== null && selectedProfileLabel"
        removable
        dense
        outline
        color="primary"
        data-test="shop-orders-chip-profile"
        @remove="emit('update:selectedProfileId', null)"
      >
        {{ $t('shop_admin.filter_by_profile', 'Profile') }}: {{ selectedProfileLabel }}
      </q-chip>
      <q-chip
        v-if="showStatusFilter && statusFilter && statusFilterLabel"
        removable
        dense
        outline
        color="primary"
        data-test="shop-orders-chip-status"
        @remove="emit('update:statusFilter', null)"
      >
        {{ $t('shop_admin.filter_by_status', 'Status') }}: {{ statusFilterLabel }}
      </q-chip>
    </div>

    <FilterSidebar
      v-model="filterDrawerOpen"
      :title="$t('shop_admin.filter_orders', 'Filter orders')"
      width="360px"
      :max-width="400"
      :resizable="false"
      storage-key="shop-staff-orders-filter"
    >
      <div class="column q-gutter-y-md">
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
        />
      </div>

      <template #footer>
        <div class="column full-width q-gutter-sm shop-orders-filter-drawer__footer">
          <q-btn
            unelevated
            no-caps
            color="primary"
            class="full-width"
            padding="10px 16px"
            :label="$t('shop_admin.apply_filters', 'Apply filters')"
            data-test="shop-orders-filter-apply"
            @click="applyDraftFilters"
          />
          <q-btn
            flat
            no-caps
            color="grey-7"
            class="full-width"
            :label="$t('common.reset', 'Reset')"
            data-test="shop-orders-filter-reset"
            @click="resetDraftFilters"
          />
        </div>
      </template>
    </FilterSidebar>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import ProcurementOpsListToolbar from 'src/modules/procurement_stock/components/ProcurementOpsListToolbar.vue';
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

const onToolbarSearch = (value: string | null | undefined) => {
  const next = (value ?? '').trim();
  emit('update:search', next);
  emit('apply-search');
};

const clearSearchChip = () => {
  emit('update:search', '');
  emit('apply-search');
};

const { t } = useI18n();

const filterDrawerOpen = ref(false);
const draftShopId = ref<number | null>(null);
const draftProfileId = ref<number | null>(null);
const draftStatusFilter = ref<string | null>(null);

watch(filterDrawerOpen, (open) => {
  if (open) {
    syncDraftFromApplied();
  }
});

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
  filterDrawerOpen.value = false;
};

const activeFilterCount = computed(() => {
  let n = 0;
  if (props.selectedShopId !== null) n += 1;
  if (props.selectedProfileId !== null) n += 1;
  if (props.showStatusFilter && props.statusFilter) n += 1;
  return n;
});

const hasVisibleChips = computed(
  () =>
    Boolean(props.search.trim()) ||
    props.selectedShopId !== null ||
    props.selectedProfileId !== null ||
    (props.showStatusFilter && Boolean(props.statusFilter)),
);

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

const selectedShopLabel = computed(() => {
  if (props.selectedShopId === null) return '';
  const shop = props.shops.find((s) => s.id === props.selectedShopId);
  if (!shop) return `#${props.selectedShopId}`;
  return shop.tenant_name ? `${shop.name} (${shop.tenant_name})` : shop.name;
});

const selectedProfileLabel = computed(() => {
  if (props.selectedProfileId === null) return '';
  const profile = props.profiles.find((p) => p.id === props.selectedProfileId);
  return profile ? formatProfileLabel(profile) : `#${props.selectedProfileId}`;
});

const statusFilterLabel = computed(() => {
  if (!props.statusFilter) return '';
  const opt = statusOptions.value.find((o) => o.value === props.statusFilter);
  return opt?.label ?? props.statusFilter;
});

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
.shop-orders-active-filters {
  min-width: 0;
}

.shop-orders-filter-drawer__footer :deep(.q-btn) {
  min-height: 42px;
  font-weight: 600;
}
</style>
