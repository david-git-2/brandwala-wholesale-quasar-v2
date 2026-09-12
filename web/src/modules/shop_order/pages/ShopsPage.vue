<template>
  <q-page class="shops-page q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-sm overflow-hidden">
      <q-card flat class="shops-toolbar floating-surface flex-shrink-0">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-md row items-center q-gutter-sm">
            <q-input
              v-model="search"
              clearable
              debounce="350"
              dense
              outlined
              class="shops-search col"
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

      <div class="col scroll shops-content">
        <q-banner v-if="isError" class="text-white bg-negative q-mb-sm" rounded>
          {{ error?.message || 'An error occurred while fetching shops.' }}
        </q-banner>

        <q-card flat class="floating-surface shops-table-card column no-wrap">
          <q-table
            flat
            class="shops-table"
            :rows="shops ?? []"
            :columns="columns"
            row-key="id"
            :loading="isLoading"
            :grid="$q.screen.lt.md"
            :no-data-label="$t('shop_admin.no_shops_found')"
            :pagination="{ rowsPerPage: 20 }"
            hide-pagination
          >
            <template #body="props">
              <q-tr
                :props="props"
                class="shops-table__row cursor-pointer"
                @click="goToSetup(props.row.id)"
              >
                <q-td key="shop" :props="props">
                  <div class="row items-center no-wrap q-gutter-sm min-width-0">
                    <q-avatar
                      size="40px"
                      class="shops-table__avatar"
                      icon="ph ph-storefront"
                    />
                    <div class="min-width-0">
                      <div class="shops-table__title-row ellipsis">
                        <span class="text-weight-bold text-grey-9">{{ props.row.name }}</span>
                        <span class="shops-table__dot" aria-hidden="true">·</span>
                        <span class="text-grey-6">{{ props.row.slug }}</span>
                      </div>
                      <div
                        v-if="props.row.description"
                        class="text-caption text-grey-6 ellipsis q-mt-xs"
                        :title="props.row.description"
                      >
                        {{ props.row.description }}
                      </div>
                    </div>
                  </div>
                </q-td>

                <q-td key="status" :props="props">
                  <span
                    class="shops-status"
                    :class="props.row.is_active ? 'shops-status--public' : 'shops-status--draft'"
                  >
                    <span class="shops-status__dot" aria-hidden="true" />
                    {{ props.row.is_active ? $t('shop_admin.public') : $t('shop_admin.draft') }}
                  </span>
                </q-td>

                <q-td key="type" :props="props">
                  <span class="shops-tag">{{ shopTypeLabel(props.row.shop_type) }}</span>
                </q-td>

                <q-td key="vendors" :props="props">
                  <div v-if="shopVendorLabels(props.row).length" class="row items-center q-gutter-xs">
                    <span
                      v-for="vendor in shopVendorLabels(props.row)"
                      :key="vendor"
                      class="shops-tag"
                    >
                      {{ vendor }}
                    </span>
                  </div>
                  <span v-else class="text-grey-5">—</span>
                </q-td>

                <q-td key="created_at" :props="props">
                  <span class="text-grey-7">{{ formatCreatedAt(props.row.created_at) }}</span>
                </q-td>

                <q-td key="actions" :props="props" class="text-right">
                  <q-btn
                    flat
                    dense
                    no-caps
                    color="primary"
                    class="shops-open-btn"
                    icon-right="ph ph-arrow-right"
                    :label="$t('shop_admin.manage')"
                    :aria-label="$t('shop_admin.manage')"
                    @click.stop="goToSetup(props.row.id)"
                  />
                </q-td>
              </q-tr>
            </template>

            <template #item="props">
              <div class="col-12 q-pa-xs">
                <q-card
                  flat
                  bordered
                  class="shops-grid-card cursor-pointer"
                  @click="goToSetup(props.row.id)"
                >
                  <q-card-section class="q-pb-sm">
                    <div class="row items-start justify-between q-col-gutter-sm">
                      <div class="row items-center q-gutter-sm min-width-0 col">
                        <q-avatar
                          size="40px"
                          class="shops-table__avatar"
                          icon="ph ph-storefront"
                        />
                        <div class="min-width-0">
                          <div class="text-subtitle2 text-weight-bold ellipsis">{{ props.row.name }}</div>
                          <div class="text-caption text-grey-6 ellipsis">{{ props.row.slug }}</div>
                        </div>
                      </div>
                      <span
                        class="shops-status"
                        :class="props.row.is_active ? 'shops-status--public' : 'shops-status--draft'"
                      >
                        <span class="shops-status__dot" aria-hidden="true" />
                        {{ props.row.is_active ? $t('shop_admin.public') : $t('shop_admin.draft') }}
                      </span>
                    </div>

                    <p
                      v-if="props.row.description"
                      class="text-body2 text-grey-7 q-mt-sm q-mb-none ellipsis-2-lines"
                    >
                      {{ props.row.description }}
                    </p>

                    <div class="row items-center q-gutter-xs q-mt-sm">
                      <span class="shops-tag">{{ shopTypeLabel(props.row.shop_type) }}</span>
                      <span
                        v-for="vendor in shopVendorLabels(props.row)"
                        :key="vendor"
                        class="shops-tag"
                      >
                        {{ vendor }}
                      </span>
                    </div>

                    <div class="text-caption text-grey-6 q-mt-sm">
                      {{ formatCreatedAt(props.row.created_at) }}
                    </div>
                  </q-card-section>

                  <q-separator />

                  <q-card-actions align="right">
                    <q-btn
                      flat
                      dense
                      no-caps
                      color="primary"
                      icon-right="ph ph-arrow-right"
                      :label="$t('shop_admin.manage')"
                      @click.stop="goToSetup(props.row.id)"
                    />
                  </q-card-actions>
                </q-card>
              </div>
            </template>

            <template #no-data>
              <div class="column items-center justify-center text-center text-grey-6 q-pa-xl full-width">
                <q-icon name="ph ph-storefront" size="48px" class="q-mb-sm block text-grey-4" />
                <div class="text-subtitle1 text-weight-medium">{{ $t('shop_admin.no_shops_found') }}</div>
                <p class="text-caption text-grey-6 q-mt-xs q-mb-none">
                  {{ $t('shop_admin.shops_subtitle') }}
                </p>
                <q-btn
                  class="q-mt-md shops-create-btn text-weight-bold"
                  color="primary"
                  :label="$t('shop_admin.create_first_shop')"
                  unelevated
                  no-caps
                  icon="ph ph-plus"
                  @click="openCreate"
                />
              </div>
            </template>
          </q-table>
        </q-card>
      </div>
    </div>

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
import { useQuasar, date } from 'quasar';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ShopFormDialog from 'src/modules/shop_order/components/ShopFormDialog.vue';
import { useShopListQuery } from '../composables/useShopQuery';
import { useSaveShopMutation } from '../composables/useShopMutations';
import { showErrorNotification } from 'src/utils/appFeedback';
import type { Shop, ShopType, CreateShopPayload } from 'src/modules/shop_order/types';

const $q = useQuasar();
const authStore = useAuthStore();
const router = useRouter();
const { t } = useI18n();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const search = ref<string>('');
const activeFilter = ref<boolean | null>(null);

const queryParams = computed(() => ({
  tenantId: tenantId.value,
  search: search.value || null,
  active: activeFilter.value,
}));

const { data: shops, isLoading, isError, error } = useShopListQuery(queryParams);
const { mutate: saveShopMutation, isPending: isSaving } = useSaveShopMutation();

const filterOptions = computed(() => [
  { value: null, label: t('shop_admin.all') },
  { value: true, label: t('shop_admin.public') },
  { value: false, label: t('shop_admin.draft') },
]);

const columns = computed<QTableColumn[]>(() => [
  {
    name: 'shop',
    label: t('shop_admin.col_name'),
    field: 'name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'status',
    label: t('shop_admin.status'),
    field: 'is_active',
    align: 'left',
    sortable: true,
  },
  {
    name: 'type',
    label: t('shop_admin.col_type'),
    field: 'shop_type',
    align: 'left',
    sortable: true,
  },
  {
    name: 'vendors',
    label: t('shop_admin.col_vendor'),
    field: (row: Shop) => shopVendorLabels(row).join(', '),
    align: 'left',
  },
  {
    name: 'created_at',
    label: t('shop_admin.col_created'),
    field: 'created_at',
    align: 'left',
    sortable: true,
  },
  {
    name: 'actions',
    label: '',
    field: 'id',
    align: 'right',
  },
]);

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
.shops-content {
  min-height: 0;
}

.floating-surface {
  background: var(--bw-theme-surface, #ffffff);
  border-radius: 12px;
  border: 1px solid color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 80%, transparent);
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.04);
}

body.body--dark .floating-surface {
  background: #1c1c1c;
  border-color: rgb(255 255 255 / 0.08);
}

.shops-toolbar {
  padding: 10px 12px;
}

.shops-search :deep(.q-field__control) {
  border-radius: 10px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 92%, #f8fafc 8%);
}

.shops-search :deep(.q-field__control:before) {
  border-color: color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 90%, transparent);
}

.shops-segmented {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  padding: 3px;
  border-radius: 10px;
  background: color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 35%, #f8fafc 65%);
}

.shops-segmented__item {
  border: none;
  background: transparent;
  color: #64748b;
  font-size: 13px;
  font-weight: 500;
  line-height: 1.2;
  padding: 7px 12px;
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
  border-radius: 10px;
  min-height: 40px;
}

.shops-table-card {
  min-height: 0;
  overflow: hidden;
}

.shops-table :deep(.q-table__top),
.shops-table :deep(.q-table__bottom) {
  display: none;
}

.shops-table :deep(thead tr th) {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: #64748b;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 88%, #f8fafc 12%);
  border-bottom: 1px solid color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 85%, transparent);
}

.shops-table__row:hover {
  background: color-mix(in srgb, #f8fafc 70%, transparent);
}

body.body--dark .shops-table__row:hover {
  background: rgb(255 255 255 / 0.04);
}

.shops-table__avatar {
  background: color-mix(in srgb, var(--bw-theme-primary-soft, #eef2ff) 70%, #fff 30%);
  color: var(--bw-theme-primary, #4f46e5);
}

.shops-table__title-row {
  font-size: 14px;
  line-height: 1.35;
}

.shops-table__dot {
  margin: 0 6px;
  color: #cbd5e1;
}

.shops-status {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
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
  background: #f8fafc;
  color: #64748b;
}

.shops-status--draft .shops-status__dot {
  background: #94a3b8;
}

.shops-tag {
  display: inline-flex;
  align-items: center;
  padding: 4px 8px;
  border-radius: 8px;
  background: color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 28%, #f4f4f5 72%);
  color: #3f3f46;
  font-size: 12px;
  font-weight: 500;
  line-height: 1.2;
  white-space: nowrap;
}

body.body--dark .shops-tag {
  background: rgb(255 255 255 / 0.08);
  color: #e4e4e7;
}

.shops-open-btn {
  border-radius: 8px;
}

.shops-grid-card {
  border-radius: 12px;
  border-color: color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 85%, transparent);
  transition: background-color 0.15s ease, border-color 0.15s ease;
}

.shops-grid-card:hover {
  background: color-mix(in srgb, #f8fafc 65%, transparent);
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
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

body.body--dark .shops-status--public {
  background: rgb(16 185 129 / 0.14);
  color: #6ee7b7;
}

body.body--dark .shops-status--draft {
  background: rgb(148 163 184 / 0.12);
  color: #cbd5e1;
}
</style>
