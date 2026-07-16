<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Shop &amp; Order</div>
          <h1 class="text-h5 q-my-none">Shops</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Create and manage shops — type, order mode, stock display, and vendor link.
          </p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" icon="add" label="New Shop" unelevated @click="openCreate" />
        </div>
      </section>

      <!-- Toolbar -->
      <section class="row items-center q-col-gutter-md">
        <div class="col-12 col-sm-5">
          <q-input
            v-model="search"
            clearable
            debounce="350"
            dense
            outlined
            placeholder="Search by name or slug…"
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
            :options="[
              { value: null, label: 'All' },
              { value: true, label: 'Active' },
              { value: false, label: 'Inactive' },
            ]"
            @update:model-value="onFilterChange"
          />
        </div>
      </section>

      <!-- Error banner -->
      <q-banner v-if="store.error" class="text-white bg-negative" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" label="Dismiss" @click="store.clearError()" />
        </template>
      </q-banner>

      <!-- Table -->
      <q-card flat bordered>
        <q-card-section v-if="store.loadingShops" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          Loading shops…
        </q-card-section>

        <q-card-section
          v-else-if="store.shops.length === 0"
          class="text-grey-6 text-center q-pa-xl"
        >
          <q-icon name="storefront" size="48px" class="q-mb-sm block" />
          No shops found.
          <br />
          <q-btn
            class="q-mt-md"
            color="primary"
            label="Create your first shop"
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
          <!-- shop_type chip -->
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

          <!-- order_mode chip -->
          <template #body-cell-order_mode="props">
            <q-td :props="props">
              <q-chip dense outline :label="orderModeLabel(props.row.order_mode)" />
            </q-td>
          </template>

          <!-- is_active indicator -->
          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-icon
                :name="props.row.is_active ? 'check_circle' : 'cancel'"
                :color="props.row.is_active ? 'positive' : 'grey-5'"
                size="20px"
              />
            </q-td>
          </template>

          <!-- is_negotiable indicator -->
          <template #body-cell-is_negotiable="props">
            <q-td :props="props" class="text-center">
              <q-icon
                :name="props.row.is_negotiable ? 'check_circle' : 'remove'"
                :color="props.row.is_negotiable ? 'positive' : 'grey-4'"
                size="18px"
              />
            </q-td>
          </template>

          <!-- Actions -->
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
                <q-tooltip>Manage Product Listings &amp; Pricing</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="security"
                color="teal"
                @click="goToAccessMatrix(props.row.id)"
              >
                <q-tooltip>Manage Access Matrix</q-tooltip>
              </q-btn>
              <q-btn flat round dense icon="edit" color="primary" @click="openEdit(props.row)">
                <q-tooltip>Edit</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <!-- Create / Edit dialog -->
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

// ---- auth / store --------------------------------------------------

const authStore = useAuthStore();
const store = useShopOrderStore();
const router = useRouter();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

// ---- vendors -------------------------------------------------------

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

// ---- table columns -------------------------------------------------

const columns = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const, sortable: true },
  { name: 'slug', label: 'Slug', field: 'slug', align: 'left' as const, sortable: true },
  { name: 'shop_type', label: 'Type', field: 'shop_type', align: 'left' as const },
  {
    name: 'vendor_name',
    label: 'Vendor',
    field: (row: Shop) => getVendorName(row.vendor_code),
    align: 'left' as const,
    sortable: true,
  },
  { name: 'order_mode', label: 'Order mode', field: 'order_mode', align: 'left' as const },
  { name: 'is_negotiable', label: 'Negotiable', field: 'is_negotiable', align: 'center' as const },
  { name: 'is_active', label: 'Active', field: 'is_active', align: 'center' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
];

// ---- filters -------------------------------------------------------

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

// ---- dialog --------------------------------------------------------

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
    params: {
      tenantSlug: tenantSlug.value,
      shopId: String(shopId),
    },
  });
};

const goToPricing = (shopId: number) => {
  void router.push({
    name: 'app-shop-pricing-page',
    params: {
      tenantSlug: tenantSlug.value,
      shopId: String(shopId),
    },
  });
};

// ---- label helpers -------------------------------------------------

const shopTypeLabel = (t: ShopType) =>
  ({
    vendor_catalog: 'Vendor Catalog',
    fixed_price: 'Fixed Price',
    dropship: 'Dropship',
  })[t] ?? t;

const shopTypeColor = (t: ShopType) =>
  ({
    vendor_catalog: 'indigo',
    fixed_price: 'teal',
    dropship: 'deep-orange',
  })[t] ?? 'grey';

const orderModeLabel = (m: ShopOrderMode) =>
  ({
    procurement_intent: 'Procurement Intent',
    checkout_fixed: 'Checkout Fixed',
    checkout_wholesale: 'Checkout Wholesale',
  })[m] ?? m;
</script>
