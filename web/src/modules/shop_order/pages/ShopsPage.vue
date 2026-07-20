<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">{{ $t('shop_admin.shop_and_order') }}</div>
          <h1 class="text-h5 q-my-none">{{ $t('navigation.shops') }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ $t('shop_admin.shops_subtitle') }}
          </p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            icon="add"
            :label="$t('shop_admin.new_shop')"
            unelevated
            @click="openCreate"
          />
        </div>
      </section>

      <section class="row items-center q-col-gutter-md">
        <div class="col-12 col-sm-5">
          <q-input
            v-model="search"
            clearable
            debounce="350"
            dense
            outlined
            :placeholder="$t('shop_admin.search_shops_placeholder')"
            prepend-icon="search"
            @update:model-value="onSearchChange"
          >
            <template #prepend>
              <q-icon name="search" />
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
            @update:model-value="onFilterChange"
          />
        </div>
      </section>

      <q-banner v-if="store.error" class="text-white bg-negative" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" :label="$t('shop_admin.dismiss')" @click="store.clearError()" />
        </template>
      </q-banner>

      <q-card flat bordered>
        <q-card-section v-if="store.loadingShops" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          {{ $t('shop_admin.loading_shops') }}
        </q-card-section>

        <q-card-section
          v-else-if="store.shops.length === 0"
          class="text-grey-6 text-center q-pa-xl"
        >
          <q-icon name="storefront" size="48px" class="q-mb-sm block" />
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
          :rows="store.shops"
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
                icon="sell"
                color="orange"
                @click="goToPricing(props.row.id)"
              >
                <q-tooltip>{{ $t('shop_admin.manage_pricing') }}</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="security"
                color="teal"
                @click="goToAccessMatrix(props.row.id)"
              >
                <q-tooltip>{{ $t('shop_admin.manage_access_matrix') }}</q-tooltip>
              </q-btn>
              <q-btn flat round dense icon="edit" color="primary" @click="openEdit(props.row)">
                <q-tooltip>{{ $t('shop_admin.edit') }}</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <ShopFormDialog
      v-model="dialogOpen"
      :initial-data="editingShop"
      :tenant-id="tenantId"
      :saving="store.saving"
      :save-error="dialogError"
      @save="onSave"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopOrderStore } from 'src/modules/shop_order/stores/shopOrderStore';
import ShopFormDialog from 'src/modules/shop_order/components/ShopFormDialog.vue';
import { vendorService } from 'src/modules/vendor/services/vendorService';
import type { Vendor } from 'src/modules/vendor/types';
import type {
  Shop,
  ShopType,
  ShopOrderMode,
  CreateShopPayload,
  UpdateShopPayload,
} from 'src/modules/shop_order/types';

const authStore = useAuthStore();
const store = useShopOrderStore();
const router = useRouter();
const { t } = useI18n();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const vendors = ref<Vendor[]>([]);

const loadVendors = async () => {
  if (!tenantId.value) return;
  const result = await vendorService.listVendors(tenantId.value);
  vendors.value = result.success && result.data ? result.data : [];
};

const getVendorName = (code: string | null) => {
  if (!code) return '—';
  const vendor = vendors.value.find((v) => v.code === code);
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

const search = ref<string>('');
const activeFilter = ref<boolean | null>(null);

const load = () => {
  if (!tenantId.value) return;
  void store.fetchShopsByTenant(tenantId.value, {
    search: search.value || null,
    active: activeFilter.value,
  });
  void loadVendors();
};

const onSearchChange = () => load();
const onFilterChange = () => load();

onMounted(load);
watch(tenantId, (v) => {
  if (v) load();
});

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

const onSave = async (payload: CreateShopPayload | UpdateShopPayload) => {
  dialogError.value = null;
  const isEdit = 'id' in payload;
  const result = isEdit ? await store.updateShop(payload) : await store.createShop(payload);
  if (!result) return;
  if (result.success) {
    dialogOpen.value = false;
  } else {
    dialogError.value = result.error;
  }
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
