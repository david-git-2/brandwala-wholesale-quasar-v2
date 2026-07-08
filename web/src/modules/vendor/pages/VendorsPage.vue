<template>
  <q-page class="q-pa-md vendor-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Vendor Management</div>
            <div class="text-caption text-grey-8">Manage vendors and maintain supplier details</div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              label="Add Vendor"
              @click="onClickAddVendor"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <q-card flat class="q-mb-md floating-surface shadow-1">
      <q-card-section>
        <div class="row items-center q-gutter-sm toolbar-left">
          <q-btn
            v-if="!showSearchInput"
            flat
            round
            dense
            icon="search"
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
              <q-icon name="search" />
            </template>
            <template #append>
              <q-btn
                flat
                round
                dense
                icon="close"
                aria-label="Hide search"
                @click="onCloseSearch"
              />
            </template>
          </q-input>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-card-section>
        <div v-if="loading" class="text-grey-7">Loading vendors...</div>
        <div v-else-if="filteredItems.length === 0" class="text-grey-7">No vendors found.</div>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="filteredItems"
          :columns="columns"
          :dense="$q.screen.lt.md"
          :pagination="{ rowsPerPage: 0 }"
          hide-pagination
          @row-click="onClickRow"
          class="cursor-pointer"
        >
          <template #body-cell-code="props">
            <q-td :props="props">
              <q-chip dense square color="primary" text-color="white" class="vendor-code-chip">
                {{ props.row.code }}
              </q-chip>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <AddVendorDialog
      v-model="openEditDialog"
      :initial-data="selectedVendor"
      :tenant-id="resolvedTenantId"
      :markets="markets"
      :check-code-availability="checkVendorCodeAvailability"
      @save="handleSaveVendor"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import AddVendorDialog from '../components/AddVendorDialog.vue';
import { useVendorStore } from '../stores/vendorStore';
import type { Vendor, VendorCreateInput, VendorUpdateInput } from '../types';

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const router = useRouter();
const route = useRoute();
const { items, markets, loading, error } = storeToRefs(vendorStore);

const openEditDialog = ref(false);
const selectedVendor = ref<Vendor | null>(null);
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

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'market_code', label: 'Market', field: 'market_code', align: 'left', sortable: true },
  { name: 'email', label: 'Email', field: 'email', align: 'left' },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
];

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

const onClickRow = (evt: Event, row: Vendor) => {
  const routeName =
    authStore.scope === 'platform' ? 'platform-vendor-details-page' : 'app-vendor-details-page';
  void router.push({ name: routeName, params: { ...route.params, id: row.id } });
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

.vendor-code-chip {
  border-radius: 8px;
}
</style>
