<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Vendor</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Vendor Management</h1>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Add Vendor"
            @click="onClickAddVendor"
          />
        </div>
      </section>

      <!-- Skeleton Loading State -->
      <VendorSkeleton v-if="loading" />

      <!-- Error State -->
      <div v-else-if="error" class="text-negative">
        <q-banner class="bg-negative text-white q-mb-md" rounded>
          {{ error }}
        </q-banner>
      </div>

      <!-- Loaded Content -->
      <template v-else>
        <!-- Toolbar Card -->
        <q-card flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm-4 row items-center q-gutter-sm toolbar-left">
              <q-btn
                v-if="!showSearchInput"
                flat
                round
                dense
                icon="ph ph-magnifying-glass"
                aria-label="Show search"
                @click="showSearchInput = true"
              />

              <q-input
                v-else
                v-model="searchText"
                outlined
                dense
                class="soft-input toolbar-search"
                label="Search vendors"
                clearable
                autofocus
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" />
                </template>
                <template #append>
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-x"
                    aria-label="Hide search"
                    @click="onCloseSearch"
                  />
                </template>
              </q-input>
            </div>
          </div>
        </q-card>

        <!-- Empty State -->
        <div v-if="filteredItems.length === 0" class="text-grey-7 q-pa-md text-center">
          No vendors found.
        </div>

        <!-- Card View Only -->
        <VendorCardView
          v-else
          :vendors="filteredItems"
          @select="onClickVendorCard"
          @wallet="onClickWallet"
        />
      </template>

      <!-- Add / Edit Dialog -->
      <AddVendorDialog
        v-model="openEditDialog"
        :initial-data="selectedVendor"
        :tenant-id="resolvedTenantId"
        :markets="markets"
        :check-code-availability="checkVendorCodeAvailability"
        @save="handleSaveVendor"
      />

      <!-- Vendor Wallet Pockets Dialog -->
      <VendorWalletDialog
        v-if="openWalletDialog"
        v-model="openWalletDialog"
        :vendor="walletVendor"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import AddVendorDialog from '../components/AddVendorDialog.vue';
import VendorCardView from '../components/VendorCardView.vue';
import VendorSkeleton from '../components/VendorSkeleton.vue';
import VendorWalletDialog from '../components/VendorWalletDialog.vue';
import { useVendorStore } from '../stores/vendorStore';
import type { Vendor, VendorCreateInput, VendorUpdateInput } from '../types';

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const router = useRouter();
const route = useRoute();
const { items, markets, loading, error } = storeToRefs(vendorStore);

const openEditDialog = ref(false);
const selectedVendor = ref<Vendor | null>(null);
const openWalletDialog = ref(false);
const walletVendor = ref<Vendor | null>(null);
const showSearchInput = ref(false);
const searchText = ref('');

const resolvedTenantId = computed(() =>
  authStore.scope === 'platform' ? null : authStore.tenantId,
);

const filteredItems = computed(() => {
  const term = searchText.value.trim().toLowerCase();
  if (!term) return items.value;

  return items.value.filter((vendor) =>
    [vendor.name, vendor.code, vendor.market_code, vendor.email, vendor.phone]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(term)),
  );
});

const refresh = async () => {
  await Promise.all([vendorStore.fetchMarkets(), vendorStore.fetchVendors(resolvedTenantId.value)]);
};

const onClickAddVendor = () => {
  selectedVendor.value = null;
  openEditDialog.value = true;
};

const onCloseSearch = () => {
  showSearchInput.value = false;
  searchText.value = '';
};

const onClickVendorCard = (row: Vendor) => {
  const routeName =
    authStore.scope === 'platform' ? 'platform-vendor-details-page' : 'app-vendor-details-page';
  void router.push({ name: routeName, params: { ...route.params, id: row.id } });
};

const onClickWallet = (row: Vendor) => {
  walletVendor.value = row;
  openWalletDialog.value = true;
};

const checkVendorCodeAvailability = async (code: string, excludeId?: number | null) => {
  const result = await vendorStore.checkCodeAvailability(code, resolvedTenantId.value, excludeId);
  return Boolean(result.success && result.data);
};

const handleSaveVendor = async (payload: VendorCreateInput & { id?: number }) => {
  if (typeof payload.id === 'number') {
    const updatePayload: VendorUpdateInput = {
      id: payload.id,
      ...payload,
    };
    await vendorStore.updateVendor(updatePayload);
    return;
  }

  const createPayload: VendorCreateInput = {
    ...payload,
  };
  await vendorStore.createVendor(createPayload);
};

onMounted(() => {
  void refresh();
});
</script>

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(34, 56, 101, 0.08);
}

.toolbar-search {
  width: min(320px, 75vw);
}
</style>
