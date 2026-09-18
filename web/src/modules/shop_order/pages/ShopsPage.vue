<template>
  <q-page class="shops-page q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <!-- Toolbar -->
      <q-card flat bordered class="shops-toolbar q-pa-xs flex-shrink-0">
        <div class="row items-center justify-between q-col-gutter-xs">
          <div class="col-12 col-md row items-center q-gutter-x-xs wrap">
            <q-input
              v-model="search"
              clearable
              debounce="350"
              dense
              outlined
              rounded
              class="shops-search col-grow col-sm-auto"
              style="min-width: 240px"
              :placeholder="$t('shop_admin.search_shops_placeholder')"
              data-test="shops-search"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-6" />
              </template>
            </q-input>

            <div class="shops-segmented col-auto" role="tablist" :aria-label="$t('shop_admin.status')">
              <button
                v-for="option in filterOptions"
                :key="String(option.value)"
                type="button"
                class="shops-segmented__item"
                :class="{ 'shops-segmented__item--active': activeFilter === option.value }"
                @click="activeFilter = option.value"
              >
                {{ option.label }}
              </button>
            </div>
          </div>

          <div class="col-auto">
            <q-btn
              color="primary"
              unelevated
              no-caps
              class="shops-create-btn text-weight-bold"
              icon="ph ph-plus"
              :label="$t('shop_admin.new_shop')"
              data-test="shops-create"
              @click="openCreate"
            />
          </div>
        </div>
      </q-card>

      <!-- Content Area -->
      <div class="col column no-wrap min-height-0 overflow-hidden">
        <q-banner v-if="isError" class="text-white bg-negative q-mb-sm flex-shrink-0" rounded>
          {{ error?.message || 'An error occurred while fetching shops.' }}
        </q-banner>

        <!-- Skeleton Loading State -->
        <div v-if="isLoading && !shops.length" class="clean-list-card col column no-wrap overflow-hidden">
          <div class="shops-list-meta-bar row items-center justify-between q-px-md q-py-xs flex-shrink-0">
            <q-skeleton type="text" width="80px" height="18px" />
            <q-skeleton type="text" width="140px" height="14px" />
          </div>
          <div class="clean-list-scroll col">
            <div
              v-for="n in 6"
              :key="n"
              class="clean-list-item clean-list-item--skeleton"
            >
              <div class="item-main-info row items-center no-wrap">
                <q-skeleton type="QAvatar" size="36px" class="rounded-borders q-mr-sm" />
                <div class="item-info">
                  <q-skeleton type="text" width="160px" height="16px" class="q-mb-xs" />
                  <div class="row items-center q-gutter-x-xs">
                    <q-skeleton type="rect" width="60px" height="18px" class="rounded-borders" />
                    <q-skeleton type="rect" width="70px" height="18px" class="rounded-borders" />
                  </div>
                </div>
              </div>
              <div class="item-aside row items-center q-gutter-x-sm">
                <q-skeleton type="QBadge" width="65px" height="22px" class="rounded-borders" />
                <q-skeleton type="QBtn" width="32px" height="32px" class="rounded-borders" />
              </div>
            </div>
          </div>
        </div>

        <!-- Empty State (No Shops Found) -->
        <div
          v-else-if="!shops.length"
          class="clean-list-card col column items-center justify-center text-center q-pa-xl"
        >
          <q-avatar size="56px" color="grey-3" text-color="grey-9" class="q-mb-md">
            <q-icon name="ph ph-storefront" size="28px" />
          </q-avatar>
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">
            {{ isFiltered ? $t('shop_admin.no_shops_found') : $t('shop_admin.no_shops_found') }}
          </div>
          <p class="text-caption text-grey-6 q-mb-md" style="max-width: 360px">
            {{ isFiltered ? 'Try adjusting your search query or status filter.' : $t('shop_admin.shops_subtitle') }}
          </p>
          <q-btn
            v-if="isFiltered"
            flat
            no-caps
            color="primary"
            icon="ph ph-arrow-counter-clockwise"
            label="Clear filters"
            class="clear-filters-btn"
            @click="clearFilters"
          />
          <q-btn
            v-else
            unelevated
            no-caps
            color="primary"
            icon="ph ph-plus"
            :label="$t('shop_admin.create_first_shop')"
            class="shops-create-btn text-weight-bold"
            @click="openCreate"
          />
        </div>

        <!-- Linear List -->
        <div v-else class="clean-list-card col column no-wrap overflow-hidden">
          <!-- List Summary / Meta Bar -->
          <div class="shops-list-meta-bar row items-center justify-between q-px-md q-py-xs flex-shrink-0">
            <div class="row items-center q-gutter-x-sm">
              <span class="text-caption text-weight-bold text-grey-8 font-mono">
                {{ totalShops }} {{ totalShops === 1 ? 'shop' : 'shops' }}
              </span>
              <span v-if="activeCount > 0" class="meta-count-chip meta-count-chip--public">
                <span class="meta-dot-indicator bg-positive" />
                {{ activeCount }} {{ $t('shop_admin.public') }}
              </span>
              <span v-if="draftCount > 0" class="meta-count-chip meta-count-chip--draft">
                <span class="meta-dot-indicator bg-grey-6" />
                {{ draftCount }} {{ $t('shop_admin.draft') }}
              </span>
            </div>
            <div class="text-caption text-grey-5 text-xxs">
              Click any shop to manage storefront
            </div>
          </div>

          <!-- Scrollable List Container -->
          <div class="clean-list-scroll col">
            <div
              v-for="shop in shops"
              :key="shop.id"
              class="clean-list-item row items-center justify-between no-wrap cursor-pointer"
              :class="shop.is_active ? 'shop-row--public' : 'shop-row--draft'"
              :data-test="`shop-item-${shop.id}`"
              tabindex="0"
              role="button"
              @click="goToSetup(shop.id)"
              @keydown.enter="goToSetup(shop.id)"
              @keydown.space.prevent="goToSetup(shop.id)"
            >
              <!-- Left Section: Avatar, Title, Slug & Metadata -->
              <div class="item-main-info row items-center no-wrap min-width-0 col">
                <q-avatar
                  size="36px"
                  class="shop-avatar flex-shrink-0 q-mr-sm"
                  icon="ph ph-storefront"
                />

                <div class="item-info column min-width-0 col">
                  <!-- Title Row -->
                  <div class="row items-center no-wrap q-gutter-x-xs ellipsis q-mb-xs">
                    <span class="shop-name text-weight-bold text-grey-9 ellipsis">
                      {{ shop.name }}
                    </span>
                    <span class="shop-dot" aria-hidden="true">·</span>
                    <span class="shop-slug text-grey-6 font-mono ellipsis">
                      {{ shop.slug }}
                    </span>
                    <span
                      v-if="isParentTenant && shop.tenant_name"
                      class="tenant-tag q-ml-xs flex-shrink-0"
                    >
                      <q-icon name="ph ph-buildings" size="11px" class="q-mr-xs text-grey-6" />
                      {{ shop.tenant_name }}
                    </span>
                  </div>

                  <!-- Description / Meta Strip -->
                  <div class="row items-center wrap q-gutter-xs text-caption">
                    <!-- Shop Type Pill -->
                    <span class="meta-pill meta-pill--type">
                      {{ shopTypeLabel(shop.shop_type) }}
                    </span>

                    <!-- Vendor Filters Pill -->
                    <template v-if="shopVendorLabels(shop).length">
                      <span
                        v-for="vendor in shopVendorLabels(shop)"
                        :key="vendor"
                        class="meta-pill meta-pill--vendor"
                      >
                        <q-icon name="ph ph-tag" size="11px" class="q-mr-xs text-grey-6" />
                        {{ vendor }}
                      </span>
                    </template>

                    <!-- Created Date -->
                    <span class="text-grey-5 meta-date">
                      {{ formatCreatedAt(shop.created_at) }}
                    </span>

                    <!-- Description Preview if present -->
                    <span
                      v-if="shop.description"
                      class="text-grey-6 shop-desc-preview ellipsis"
                      :title="shop.description"
                    >
                      · {{ shop.description }}
                    </span>
                  </div>
                </div>
              </div>

              <!-- Right Section: Status Pill + Manage Action -->
              <div class="item-aside row items-center no-wrap flex-shrink-0 q-gutter-x-sm">
                <!-- Status Badge -->
                <span
                  class="shops-status"
                  :class="shop.is_active ? 'shops-status--public' : 'shops-status--draft'"
                >
                  <span class="shops-status__dot" aria-hidden="true" />
                  {{ shop.is_active ? $t('shop_admin.public') : $t('shop_admin.draft') }}
                </span>

                <!-- Manage Button -->
                <q-btn
                  flat
                  dense
                  no-caps
                  color="primary"
                  class="shop-manage-btn"
                  :label="$t('shop_admin.manage')"
                  :aria-label="$t('shop_admin.manage')"
                  @click.stop="goToSetup(shop.id)"
                />
              </div>
            </div>

            <!-- Load More Button -->
            <div v-if="hasNextPage" class="row justify-center q-py-sm">
              <q-btn
                flat
                dense
                no-caps
                :loading="isFetchingNextPage"
                class="load-more-btn text-weight-medium q-px-md"
                label="Load more"
                icon="ph ph-arrow-down"
                @click="fetchNextPage()"
              />
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Create Shop Dialog -->
    <ShopFormDialog
      v-model="dialogOpen"
      :tenant-id="tenantId"
      :saving="isSaving"
      :save-error="dialogError"
      @save="onSave"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { date } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ShopFormDialog from 'src/modules/shop_order/components/ShopFormDialog.vue';
import { useInfiniteShopListQuery } from '../composables/useShopQuery';
import { useSaveShopMutation } from '../composables/useShopMutations';
import type { Shop, ShopType, CreateShopPayload } from 'src/modules/shop_order/types';

const authStore = useAuthStore();
const router = useRouter();
const { t } = useI18n();

const tenantId = computed(() => authStore.tenantId as number);
const parentTenantId = computed(() => authStore.selectedTenant?.parent_id ?? authStore.tenantId);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const search = ref<string>('');
const activeFilter = ref<boolean | null>(null);

const queryParams = computed(() => ({
  tenantId: tenantId.value,
  parentTenantId: parentTenantId.value,
  search: search.value || null,
  active: activeFilter.value,
}));

const {
  shops,
  totalShops,
  isLoading,
  isError,
  error,
  hasNextPage,
  isFetchingNextPage,
  fetchNextPage,
} = useInfiniteShopListQuery(queryParams, 20);

const { mutate: saveShopMutation, isPending: isSaving } = useSaveShopMutation();

const isParentTenant = computed(() => {
  if (!tenantId.value) return false;
  const pId = authStore.selectedTenant?.parent_id ?? tenantId.value;
  return Number(pId) === Number(tenantId.value);
});

const isFiltered = computed(() => {
  return Boolean(search.value.trim() || activeFilter.value !== null);
});

const clearFilters = () => {
  search.value = '';
  activeFilter.value = null;
};

const filterOptions = computed(() => [
  { value: null, label: t('shop_admin.all') },
  { value: true, label: t('shop_admin.public') },
  { value: false, label: t('shop_admin.draft') },
]);

const activeCount = computed(() => {
  return shops.value.filter((s) => s.is_active).length;
});

const draftCount = computed(() => {
  return shops.value.filter((s) => !s.is_active).length;
});

const dialogOpen = ref(false);
const dialogError = ref<string | null>(null);

const openCreate = () => {
  dialogError.value = null;
  dialogOpen.value = true;
};

const goToSetup = (shopId: number) => {
  void router.push({
    name: 'app-shop-settings-page',
    params: { tenantSlug: tenantSlug.value, shopId: String(shopId) },
  });
};

const onSave = (payload: CreateShopPayload) => {
  dialogError.value = null;
  saveShopMutation(payload, {
    onSuccess: (shop) => {
      dialogOpen.value = false;
      goToSetup(shop.id);
    },
    onError: (err: Error) => {
      dialogError.value = err.message || t('shop_admin.shop_setup_save_failed');
    },
  });
};

const shopTypeLabel = (type: ShopType) => {
  const map: Record<ShopType, string> = {
    vendor_catalog: t('shop_admin.create_type_catalog'),
    fixed_price: t('shop_admin.create_type_stock'),
    dropship: t('shop_admin.create_type_dropship'),
  };
  return map[type] ?? type;
};

const shopVendorLabels = (shop: Shop): string[] => {
  const fromFilters = (shop.vendor_filters ?? [])
    .map((vf) => vf.vendor_code?.trim())
    .filter((code): code is string => !!code);

  if (fromFilters.length > 0) {
    return [...new Set(fromFilters)];
  }

  const legacy = shop.vendor_code?.trim();
  return legacy ? [legacy] : [];
};

const formatCreatedAt = (value?: string | null) => {
  if (!value) return '—';
  return date.formatDate(value, 'D MMM YYYY');
};
</script>

<style scoped>
.min-height-0 {
  min-height: 0;
}

.shops-toolbar {
  background: var(--bw-theme-surface, #ffffff);
  border-radius: var(--bw-radius-md, 10px);
  border-color: var(--bw-theme-border, #e2e8f0);
}

.shops-search :deep(.q-field__control) {
  border-radius: 9999px;
}

.shops-segmented {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  padding: 3px;
  border-radius: 10px;
  background: color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 40%, #f8fafc 60%);
}

.shops-segmented__item {
  border: none;
  background: transparent;
  color: #64748b;
  font-size: 13px;
  font-weight: 500;
  line-height: 1.2;
  padding: 6px 12px;
  border-radius: 8px;
  cursor: pointer;
  transition: background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
  white-space: nowrap;
}

.shops-segmented__item--active {
  background: var(--bw-theme-surface, #ffffff);
  color: #0f172a;
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.08);
}

.shops-create-btn {
  border-radius: var(--bw-radius-sm, 8px);
  min-height: 36px;
}

/* Linear List Card & Scroll Structure */
.clean-list-card {
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  border-radius: var(--bw-radius-md, 10px);
}

.shops-list-meta-bar {
  background: var(--bw-neutral-surface, #f8fafc);
  border-bottom: 1px solid var(--bw-theme-border, #e2e8f0);
  min-height: 34px;
}

.meta-count-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 1.5px 7px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
}

.meta-dot-indicator {
  width: 5px;
  height: 5px;
  border-radius: 50%;
}

.meta-count-chip--public {
  background: #ecfdf5;
  color: #047857;
}

.meta-count-chip--draft {
  background: #f1f5f9;
  color: #64748b;
}

.clean-list-scroll {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.clean-list-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--bw-theme-border, #f1f5f9);
  cursor: pointer;
  transition: all 0.15s ease;
  min-height: 54px;
}

.clean-list-item:last-child {
  border-bottom: none;
}

.clean-list-item:hover {
  background: color-mix(in srgb, #f8fafc 80%, transparent);
}

.clean-list-item:hover .shop-name {
  color: var(--bw-theme-primary, #4f46e5);
}

/* Status Row Accents */
.shop-row--public {
  background: #ffffff;
}

.shop-row--draft {
  background: #ffffff;
}

.shop-avatar {
  background: color-mix(in srgb, var(--bw-theme-primary-soft, #eef2ff) 70%, #fff 30%);
  color: var(--bw-theme-primary, #4f46e5);
  border-radius: var(--bw-radius-sm, 8px);
}

.shop-name {
  font-size: 13.5px;
  line-height: 1.3;
}

.shop-slug {
  font-size: 12px;
}

.shop-dot {
  color: #cbd5e1;
}

.tenant-tag {
  display: inline-flex;
  align-items: center;
  font-size: 11px;
  font-weight: 600;
  padding: 1.5px 6px;
  border-radius: 4px;
  background: #f1f5f9;
  color: #475569;
  border: 1px solid #e2e8f0;
  line-height: 1.2;
}

.meta-pill {
  display: inline-flex;
  align-items: center;
  font-size: 11px;
  font-weight: 500;
  padding: 2px 7px;
  border-radius: 6px;
  line-height: 1.2;
  white-space: nowrap;
}

.meta-pill--type {
  background: color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 28%, #f4f4f5 72%);
  color: #3f3f46;
}

.meta-pill--vendor {
  background: #eff6ff;
  color: #1d4ed8;
  border: 1px solid #dbeafe;
}

.meta-date {
  font-size: 11px;
}

.shop-desc-preview {
  max-width: 260px;
  font-size: 11.5px;
}

.item-aside {
  margin-left: 1rem;
}

.shops-status {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 3px 8px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 600;
  line-height: 1.2;
  white-space: nowrap;
}

.shops-status__dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}

.shops-status--public {
  background: #ecfdf5;
  color: #047857;
}

.shops-status--public .shops-status__dot {
  background: #10b981;
}

.shops-status--draft {
  background: #f1f5f9;
  color: #64748b;
}

.shops-status--draft .shops-status__dot {
  background: #94a3b8;
}

.shop-manage-btn {
  border-radius: var(--bw-radius-sm, 8px);
  font-size: 12px;
}

.load-more-btn {
  background: #f1f5f9;
  color: #334155;
  border-radius: var(--bw-radius-sm, 8px);
  font-size: 12px;
  transition: all 0.15s ease;
}

.load-more-btn:hover {
  background: #e2e8f0;
  color: #0f172a;
}

.clear-filters-btn {
  border-radius: var(--bw-radius-sm, 8px);
  font-size: 12px;
}

.clean-list-item--skeleton {
  cursor: default;
}

.clean-list-item--skeleton:hover {
  background: transparent;
}

.text-xxs {
  font-size: 11px;
}

/* Dark mode support */
body.body--dark .shops-toolbar {
  background: #1c1917;
  border-color: #2a2622;
}

body.body--dark .clean-list-card {
  background: #1c1917;
  border-color: #2a2622;
}

body.body--dark .shops-list-meta-bar {
  background: #24201d;
  border-color: #2a2622;
}

body.body--dark .clean-list-item {
  border-color: #2a2622;
}

body.body--dark .clean-list-item:hover {
  background: rgba(255, 255, 255, 0.04);
}

body.body--dark .shop-row--public {
  background: #1c1917;
}

body.body--dark .shop-row--draft {
  background: #1c1917;
}

body.body--dark .shop-avatar {
  background: rgba(255, 255, 255, 0.08);
  color: #a5b4fc;
}

body.body--dark .shops-segmented {
  background: rgb(255 255 255 / 0.06);
}

body.body--dark .shops-segmented__item {
  color: #94a3b8;
}

body.body--dark .shops-segmented__item--active {
  background: #262626;
  color: #f8fafc;
}

body.body--dark .tenant-tag {
  background: rgba(255, 255, 255, 0.08);
  color: #cbd5e1;
  border-color: rgba(255, 255, 255, 0.12);
}

body.body--dark .meta-pill--type {
  background: rgb(255 255 255 / 0.08);
  color: #e4e4e7;
}

body.body--dark .meta-pill--vendor {
  background: rgba(59, 130, 246, 0.15);
  color: #93c5fd;
  border-color: rgba(59, 130, 246, 0.25);
}

body.body--dark .shops-status--public {
  background: rgb(16 185 129 / 0.14);
  color: #6ee7b7;
}

body.body--dark .shops-status--draft {
  background: rgb(148 163 184 / 0.12);
  color: #cbd5e1;
}

body.body--dark .load-more-btn {
  background: #262626;
  color: #f1f5f9;
}

body.body--dark .load-more-btn:hover {
  background: #333333;
}
</style>
