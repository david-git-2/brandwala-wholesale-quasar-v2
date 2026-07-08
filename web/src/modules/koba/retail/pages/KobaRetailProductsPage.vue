<template>
  <q-page class="bw-page">
    <!-- Page Header -->
    <div class="koba-header q-mb-md">
      <div>
        <div class="text-h5 text-weight-bold">Koba Retail</div>
        <div class="text-caption text-grey-7">{{ store.meta.total }} products</div>
      </div>
      <div v-if="isAdminOrSuper" class="row items-center q-gutter-sm">
        <q-btn
          flat
          no-caps
          color="primary"
          icon="settings"
          label="Settings"
          :to="{ name: 'app-koba-retail-settings-page' }"
        />
      </div>
    </div>

    <!-- Filter Toolbar -->
    <div class="row items-center q-gutter-sm q-mb-md">
      <!-- Search -->
      <q-input
        v-model="searchDraft"
        outlined
        dense
        class="soft-input"
        style="min-width: 220px; flex: 1 1 220px; max-width: 340px"
        placeholder="Search by name, SKU, barcode…"
        clearable
        debounce="350"
        @update:model-value="onSearchChange"
        @clear="onSearchClear"
      >
        <template #prepend><q-icon name="search" size="18px" /></template>
      </q-input>

      <!-- Sidebar Toggle Button -->
      <q-btn
        flat
        round
        dense
        icon="filter_alt"
        color="primary"
        aria-label="Filters"
        @click="filterDrawerOpen = true"
      >
        <q-badge v-if="drawerFilterCount > 0" color="primary" rounded floating>
          {{ drawerFilterCount }}
        </q-badge>
      </q-btn>

      <!-- Active filter count + clear -->
      <div v-if="drawerFilterCount > 0" class="row items-center q-gutter-xs">
        <q-chip
          dense
          color="primary"
          text-color="white"
          :label="`${drawerFilterCount} filter${drawerFilterCount > 1 ? 's' : ''}`"
        />
        <q-btn
          flat
          dense
          no-caps
          size="sm"
          icon="close"
          label="Clear"
          color="grey-7"
          @click="onClearDrawerFilters"
        />
      </div>
    </div>

    <!-- Filter Sidebar Drawer -->
    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <!-- Brand filter -->
      <q-select
        v-model="selectedBrandId"
        :options="brandOptions"
        outlined
        dense
        label="Brand"
        class="soft-input q-mb-sm"
        emit-value
        map-options
        clearable
        :loading="store.loadingLookups"
      />

      <!-- Category filter -->
      <q-select
        v-model="selectedCategoryId"
        :options="categoryOptions"
        outlined
        dense
        label="Category"
        class="soft-input q-mb-md"
        emit-value
        map-options
        clearable
        :loading="store.loadingLookups"
      />

      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetDrawerFilters" />
        <q-btn flat no-caps label="Apply" color="primary" @click="onApplyDrawerFilters" />
      </div>
    </FilterSidebar>

    <!-- Loading -->
    <PageInitialLoader v-if="store.loading" />

    <!-- Empty State -->
    <div v-else-if="store.items.length === 0" class="empty-banner q-mb-md">
      No products match your search or filters.
    </div>

    <!-- Card Grid -->
    <template v-else>
      <div class="row q-col-gutter-sm">
        <div v-for="item in store.items" :key="item.id" class="col-6 col-sm-4 col-md-3 col-lg-2">
          <ProductCard :product="item" />
        </div>
      </div>

      <!-- Pagination -->
      <div v-if="store.meta.total_pages > 1" class="row justify-center q-mt-lg q-mb-sm">
        <q-pagination
          v-model="currentPage"
          :max="store.meta.total_pages"
          :max-pages="8"
          boundary-numbers
          direction-links
          @update:model-value="onPageChange"
        />
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useKobaRetailStore } from 'src/modules/koba/retail/stores/kobaRetailStore';
import { useKobaCartStore } from 'src/modules/koba/retail/stores/kobaCartStore';
import { useKobaSettingsStore } from 'src/modules/koba/retail/stores/kobaSettingsStore';
import ProductCard from 'src/modules/koba/retail/components/ProductCard.vue';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';

const store = useKobaRetailStore();
const cartStore = useKobaCartStore();
const authStore = useAuthStore();
const settingsStore = useKobaSettingsStore();

const isAdminOrSuper = computed(() => {
  const role = authStore.matchedRole;
  return role === 'admin' || role === 'superadmin';
});

// ─── UI state ────────────────────────────────────────────────────────────────

const searchDraft = ref('');
const selectedBrandId = ref<number | null>(null);
const selectedCategoryId = ref<number | null>(null);
const currentPage = ref(1);
const filterDrawerOpen = ref(false);

// ─── Computed options for selects ─────────────────────────────────────────────

const brandOptions = computed(() => store.brands.map((b) => ({ label: b.name, value: b.id })));

const categoryOptions = computed(() =>
  store.categories.map((c) => ({ label: c.name, value: c.id })),
);

const drawerFilterCount = computed(
  () => (selectedBrandId.value ? 1 : 0) + (selectedCategoryId.value ? 1 : 0),
);

// ─── Filter handlers ─────────────────────────────────────────────────────────

async function onSearchChange(val: string | number | null) {
  await store.applyFilters({ search: String(val ?? '').trim() });
  currentPage.value = 1;
}

async function onSearchClear() {
  await store.applyFilters({ search: '' });
  currentPage.value = 1;
}

async function onApplyDrawerFilters() {
  filterDrawerOpen.value = false;
  await store.applyFilters({
    brand_id: selectedBrandId.value,
    category_id: selectedCategoryId.value,
  });
  currentPage.value = 1;
}

function onResetDrawerFilters() {
  selectedBrandId.value = null;
  selectedCategoryId.value = null;
}

async function onClearDrawerFilters() {
  selectedBrandId.value = null;
  selectedCategoryId.value = null;
  filterDrawerOpen.value = false;
  await store.applyFilters({
    brand_id: null,
    category_id: null,
  });
  currentPage.value = 1;
}

// ─── Pagination ───────────────────────────────────────────────────────────────

async function onPageChange(page: number) {
  currentPage.value = page;
  await store.fetchProducts(page);
}

// ─── Initial load ─────────────────────────────────────────────────────────────

onMounted(async () => {
  const promises: Promise<unknown>[] = [
    store.fetchLookups(),
    store.fetchProducts(1),
    settingsStore.fetchSettings(),
  ];
  if (!isAdminOrSuper.value) {
    promises.push(cartStore.fetchCart());
  }
  await Promise.all(promises);
});
</script>

<style scoped>
.koba-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(6px);
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.empty-banner {
  padding: 16px 20px;
  background: #fff9ef;
  color: #5b4c33;
  border: 1px solid #e8dbbf;
  border-radius: 12px;
}

@media (max-width: 599px) {
  .koba-header {
    flex-wrap: wrap;
    align-items: flex-start;
  }
}
</style>
