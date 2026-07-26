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

      <q-markup-table v-if="isLoading" flat bordered>
        <thead>
          <tr>
            <th><q-skeleton type="text" width="100px" /></th>
            <th><q-skeleton type="text" width="80px" /></th>
            <th><q-skeleton type="text" width="90px" /></th>
            <th><q-skeleton type="text" width="110px" /></th>
            <th><q-skeleton type="text" width="100px" /></th>
            <th class="text-center"><q-skeleton type="text" width="70px" class="q-mx-auto" /></th>
            <th class="text-center"><q-skeleton type="text" width="50px" class="q-mx-auto" /></th>
            <th class="text-right"><q-skeleton type="text" width="80px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 5" :key="n">
            <td><q-skeleton type="text" width="85%" /></td>
            <td><q-skeleton type="text" width="70%" /></td>
            <td><q-skeleton type="QBadge" width="80px" height="24px" /></td>
            <td><q-skeleton type="text" width="75%" /></td>
            <td><q-skeleton type="QBadge" width="100px" height="24px" /></td>
            <td class="text-center"><q-skeleton type="QAvatar" size="20px" class="q-mx-auto" /></td>
            <td class="text-center"><q-skeleton type="QAvatar" size="20px" class="q-mx-auto" /></td>
            <td class="text-right row justify-end q-gutter-x-xs">
              <q-skeleton v-for="i in 4" :key="i" type="QAvatar" size="28px" />
            </td>
          </tr>
        </tbody>
      </q-markup-table>

      <q-card v-else flat bordered>
        <q-card-section
          v-if="!shops || shops.length === 0"
          class="text-grey-6 text-center q-pa-xl"
        >
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
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="shops"
          :columns="columns"
          :pagination="{ rowsPerPage: 25 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-shop_type="props">
            <q-td :props="props">
              <q-chip
                dense
                :color="shopTypeColor(props.row.shop_type)"
                text-color="white"
                :label="shopTypeLabel(props.row.shop_type)"
              />
            </q-td>
          </template>

          <template #body-cell-order_mode="props">
            <q-td :props="props">
              <q-chip dense outline :label="orderModeLabel(props.row.order_mode)" />
            </q-td>
          </template>

          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-icon
                :name="props.row.is_active ? 'check_circle' : 'cancel'"
                :color="props.row.is_active ? 'positive' : 'grey-5'"
                size="20px"
              />
            </q-td>
          </template>

          <template #body-cell-is_negotiable="props">
            <q-td :props="props" class="text-center">
              <q-icon
                :name="props.row.is_negotiable ? 'check_circle' : 'remove'"
                :color="props.row.is_negotiable ? 'positive' : 'grey-4'"
                size="18px"
              />
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="q-gutter-x-sm">
              <q-btn
                v-if="props.row.shop_type !== 'vendor_catalog'"
                flat
                round
                dense
                icon="ph ph-tag"
                color="orange"
                @click="goToPricing(props.row.id)"
              >
                <q-tooltip>{{ $t('shop_admin.manage_pricing') }}</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="ph ph-shield"
                color="teal"
                @click="goToAccessMatrix(props.row.id)"
              >
                <q-tooltip>{{ $t('shop_admin.manage_access_matrix') }}</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="ph ph-eye"
                color="indigo"
                @click="goToPreview(props.row.id)"
              >
                <q-tooltip>Preview Storefront</q-tooltip>
              </q-btn>
              <q-btn flat round dense icon="ph ph-pencil-simple" color="primary" @click="openEdit(props.row)">
                <q-tooltip>{{ $t('shop_admin.edit') }}</q-tooltip>
              </q-btn>
              <q-btn flat round dense icon="ph ph-trash" color="negative" @click="confirmDeleteShop(props.row)">
                <q-tooltip>{{ $t('shop_admin.delete') }}</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
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

const columns = computed(() => [
  { name: 'name', label: t('shop_admin.col_name'), field: 'name', align: 'left' as const, sortable: true },
  { name: 'slug', label: t('shop_admin.slug'), field: 'slug', align: 'left' as const, sortable: true },
  { name: 'shop_type', label: t('shop_admin.col_type'), field: 'shop_type', align: 'left' as const },
  {
    name: 'vendor_name',
    label: t('shop_admin.col_vendor'),
    field: (row: Shop) => getVendorName(row.vendor_code),
    align: 'left' as const,
    sortable: true,
  },
  { name: 'order_mode', label: t('shop_admin.col_order_mode'), field: 'order_mode', align: 'left' as const },
  { name: 'is_negotiable', label: t('shop_admin.col_negotiable'), field: 'is_negotiable', align: 'center' as const },
  { name: 'is_active', label: t('shop_admin.active'), field: 'is_active', align: 'center' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
]);

const filterOptions = computed(() => [
  { value: null, label: t('shop_admin.all') },
  { value: true, label: t('shop_admin.active') },
  { value: false, label: t('shop_admin.inactive') },
]);

const dialogOpen = ref(false);
const editingShop = ref<Shop | null>(null);
const dialogError = ref<string | null>(null);

const goToPreview = (shopId: number) => {
  void router.push({
    name: 'app-shop-preview-page',
    params: { tenantSlug: tenantSlug.value, shopId: String(shopId) },
  });
};

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
