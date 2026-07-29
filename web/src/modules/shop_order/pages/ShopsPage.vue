<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">{{ $t('shop_admin.shop_and_order') }}</div>
          <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('navigation.shops') }}</h1>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            class="pill-btn"
            icon="ph ph-plus"
            :label="$t('shop_admin.new_shop')"
            @click="openCreate"
          />
        </div>
      </section>

      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm-5 row items-center q-gutter-sm">
            <q-input
              v-model="search"
              clearable
              debounce="350"
              dense
              outlined
              class="full-width"
              :placeholder="$t('shop_admin.search_shops_placeholder')"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-auto">
            <q-btn-toggle
              v-model="activeFilter"
              dense
              no-caps
              rounded
              unelevated
              toggle-color="primary"
              :options="filterOptions"
            />
          </div>
        </div>
      </q-card>

      <q-banner v-if="isError" class="text-white bg-negative" rounded>
        {{ error?.message || 'An error occurred while fetching shops.' }}
      </q-banner>

      <div v-if="isLoading" class="q-gutter-y-md">
        <q-card v-for="n in 3" :key="n" flat bordered class="q-pa-md">
          <div class="row items-center justify-between q-mb-sm">
            <q-skeleton type="text" width="40%" height="24px" />
            <q-skeleton type="QBadge" width="80px" height="24px" />
          </div>
          <q-skeleton type="text" width="20%" class="q-mb-sm" />
          <q-separator class="q-my-sm" />
          <div class="row items-center justify-between">
            <q-skeleton type="text" width="30%" />
            <q-skeleton type="QAvatar" size="28px" />
          </div>
        </q-card>
      </div>

      <div v-else>
        <q-card v-if="!shops || shops.length === 0" flat bordered class="q-pa-xl text-center text-grey-6">
          <q-icon name="ph ph-storefront" size="48px" class="q-mb-sm block" />
          {{ $t('shop_admin.no_shops_found') }}
          <br />
          <q-btn
            class="q-mt-md"
            color="primary"
            :label="$t('shop_admin.create_first_shop')"
            unelevated
            @click="openCreate"
          />
        </q-card>

        <div v-else class="q-gutter-y-md">
          <q-card v-for="shop in shops" :key="shop.id" flat bordered class="shop-card full-width">
            <q-card-section>
              <div class="row items-center justify-between q-col-gutter-sm">
                <div class="col-12 col-md-4">
                  <div class="row items-center q-gutter-x-sm">
                    <div class="text-subtitle1 text-weight-bold" :title="shop.name">
                      {{ shop.name }}
                    </div>
                    <q-chip
                      dense
                      size="sm"
                      :color="shopTypeColor(shop.shop_type)"
                      text-color="white"
                      class="text-weight-medium"
                    >
                      {{ shopTypeLabel(shop.shop_type) }}
                    </q-chip>
                  </div>
                  <div class="text-caption text-grey-6 font-monospace q-mt-xs">/{{ shop.slug }}</div>
                </div>

                <div class="col-12 col-md-5">
                  <div class="row items-center q-gutter-x-md text-caption">
                    <div>
                      <span class="text-grey-7">{{ $t('shop_admin.col_vendor') }}: </span>
                      <span class="text-weight-medium">{{ getVendorName(shop.vendor_code) }}</span>
                    </div>
                    <div>
                      <span class="text-grey-7">{{ $t('shop_admin.col_order_mode') }}: </span>
                      <q-chip dense outline size="xs" :label="orderModeLabel(shop.order_mode)" />
                    </div>
                  </div>
                  <div class="row items-center q-gutter-x-md text-caption q-mt-xs">
                    <div class="row items-center q-gutter-x-xs">
                      <span class="text-grey-7">{{ $t('shop_admin.col_negotiable') }}:</span>
                      <q-icon
                        :name="shop.is_negotiable ? 'check_circle' : 'remove'"
                        :color="shop.is_negotiable ? 'positive' : 'grey-4'"
                        size="16px"
                      />
                    </div>
                    <div class="row items-center q-gutter-x-xs">
                      <span class="text-grey-7">{{ $t('shop_admin.active') }}:</span>
                      <q-chip
                        dense
                        size="xs"
                        :color="shop.is_active ? 'positive' : 'grey-5'"
                        text-color="white"
                      >
                        {{ shop.is_active ? $t('shop_admin.active') : $t('shop_admin.inactive') }}
                      </q-chip>
                    </div>
                  </div>
                </div>

                <div class="col-12 col-md-3 row items-center justify-end q-gutter-x-xs">
                  <q-btn
                    v-if="shop.shop_type !== 'vendor_catalog'"
                    flat
                    round
                    dense
                    icon="ph ph-tag"
                    color="orange"
                    @click="goToPricing(shop.id)"
                  >
                    <q-tooltip>{{ $t('shop_admin.manage_pricing') }}</q-tooltip>
                  </q-btn>

                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-shield"
                    color="teal"
                    @click="goToAccessMatrix(shop.id)"
                  >
                    <q-tooltip>{{ $t('shop_admin.manage_access_matrix') }}</q-tooltip>
                  </q-btn>

                  <q-btn flat round dense icon="ph ph-dots-three-vertical" color="grey-7">
                    <q-menu auto-close anchor="bottom right" self="top right">
                      <q-list style="min-width: 140px">
                        <q-item clickable @click="openEdit(shop)">
                          <q-item-section avatar min-width="24px">
                            <q-icon name="ph ph-pencil-simple" color="primary" size="18px" />
                          </q-item-section>
                          <q-item-section>{{ $t('shop_admin.edit') }}</q-item-section>
                        </q-item>

                        <q-item clickable @click="confirmDeleteShop(shop)">
                          <q-item-section avatar min-width="24px">
                            <q-icon name="ph ph-trash" color="negative" size="18px" />
                          </q-item-section>
                          <q-item-section class="text-negative">{{ $t('shop_admin.delete') }}</q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-btn>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>

    <ShopFormDialog
      v-model="dialogOpen"
      :initial-data="editingShop"
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
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ShopFormDialog from 'src/modules/shop_order/components/ShopFormDialog.vue';
import { useShopListQuery, useVendorListQuery } from '../composables/useShopQuery';
import { useSaveShopMutation, useDeleteShopMutation } from '../composables/useShopMutations';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import type {
  Shop,
  ShopType,
  ShopOrderMode,
  CreateShopPayload,
  UpdateShopPayload,
} from 'src/modules/shop_order/types';

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
const { data: vendors } = useVendorListQuery(tenantId);
const { mutate: saveShopMutation, isPending: isSaving } = useSaveShopMutation();
const { mutate: deleteShopMutation } = useDeleteShopMutation();

const getVendorName = (code: string | null) => {
  if (!code) return '—';
  const vendor = vendors.value?.find((v) => v.code === code);
  return vendor ? `${vendor.name} (${code})` : code;
};

const filterOptions = computed(() => [
  { value: null, label: t('shop_admin.all') },
  { value: true, label: t('shop_admin.active') },
  { value: false, label: t('shop_admin.inactive') },
]);

const dialogOpen = ref(false);
const editingShop = ref<Shop | null>(null);
const dialogError = ref<string | null>(null);

const openCreate = () => {
  editingShop.value = null;
  dialogError.value = null;
  dialogOpen.value = true;
};

const openEdit = (shop: Shop) => {
  editingShop.value = shop;
  dialogError.value = null;
  dialogOpen.value = true;
};

const confirmDeleteShop = (shop: Shop) => {
  $q.dialog({
    title: t('shop_admin.delete_shop_title'),
    message: t('shop_admin.delete_shop_confirm_msg', { name: shop.name }),
    cancel: {
      label: t('shop_admin.cancel'),
      flat: true,
      color: 'grey-7',
    },
    ok: {
      label: t('shop_admin.delete'),
      unelevated: true,
      color: 'negative',
    },
    persistent: true,
  }).onOk(() => {
    deleteShopMutation(
      { shopId: shop.id, tenantId: tenantId.value },
      {
        onSuccess: () => {
          showSuccessNotification(t('shop_admin.delete_shop_success'));
        },
        onError: (err: Error) => {
          showErrorNotification(err.message || t('shop_admin.delete_shop_failed'));
        },
      },
    );
  });
};

const onSave = (payload: CreateShopPayload | UpdateShopPayload) => {
  dialogError.value = null;
  saveShopMutation(payload, {
    onSuccess: () => {
      dialogOpen.value = false;
    },
    onError: (err: Error) => {
      dialogError.value = err.message || 'Failed to save shop.';
    },
  });
};

const goToAccessMatrix = (shopId: number) => {
  void router.push({
    name: 'app-shop-access-matrix-page',
    params: { tenantSlug: tenantSlug.value, shopId: String(shopId) },
  });
};

const goToPricing = (shopId: number) => {
  void router.push({
    name: 'app-shop-pricing-page',
    params: { tenantSlug: tenantSlug.value, shopId: String(shopId) },
  });
};

const shopTypeLabel = (type: ShopType) => {
  const map: Record<ShopType, string> = {
    vendor_catalog: t('shop_admin.shop_type_vendor_catalog'),
    fixed_price: t('shop_admin.shop_type_fixed_price'),
    dropship: t('shop_admin.shop_type_dropship'),
  };
  return map[type] ?? type;
};

const shopTypeColor = (type: ShopType) =>
  ({
    vendor_catalog: 'indigo',
    fixed_price: 'teal',
    dropship: 'deep-orange',
  })[type] ?? 'grey';

const orderModeLabel = (mode: ShopOrderMode) => {
  const map: Record<ShopOrderMode, string> = {
    procurement_intent: t('shop_admin.order_mode_procurement_intent'),
    checkout_fixed: t('shop_admin.order_mode_checkout_fixed'),
    checkout_wholesale: t('shop_admin.order_mode_checkout_wholesale'),
  };
  return map[mode] ?? mode;
};
</script>
