<template>
  <q-page class="page-fixed-layout" style="height: calc(100vh - 55px); overflow: hidden">
    <div class="column full-height q-pa-md q-gutter-y-md">
      <!-- Top Header & Search Bar -->
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-left"
            color="grey-8"
            @click="navigateBack"
          >
            <q-tooltip>Back to Wallets</q-tooltip>
          </q-btn>
          <div>
            <div class="text-overline text-primary text-weight-bold leading-tight">
              WALLET SELECTION
            </div>
            <h1 class="text-h5 text-weight-bolder text-grey-9 q-my-none">
              {{ pageTitle }}
            </h1>
            <p class="text-caption text-grey-7 q-mb-none">
              Pick a name to open their wallet.
            </p>
          </div>
        </div>

        <!-- Search Input -->
        <div class="col-xs-12 col-sm-5 col-md-4">
          <q-input
            v-model="searchText"
            outlined
            rounded
            dense
            clearable
            placeholder="Search by name, code or contact..."
            class="bg-white search-input"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" class="text-grey-6" />
            </template>
          </q-input>
        </div>
      </div>

      <!-- Scrollable List Container -->
      <div class="col full-width overflow-hidden bg-white rounded-borders border-grey-3 shadow-1 column">
        <!-- Skeleton Loader -->
        <div v-if="loading" class="q-pa-md q-gutter-y-sm col overflow-hidden">
          <q-card v-for="i in 6" :key="i" flat bordered class="q-pa-sm">
            <div class="row items-center justify-between">
              <div class="row items-center q-gutter-x-md col">
                <q-skeleton type="QAvatar" size="40px" />
                <div class="col">
                  <q-skeleton type="text" width="40%" height="20px" />
                  <q-skeleton type="text" width="60%" height="14px" />
                </div>
              </div>
              <q-skeleton type="rect" width="80px" height="24px" />
            </div>
          </q-card>
        </div>

        <!-- Empty State -->
        <div
          v-else-if="filteredRows.length === 0"
          class="col row items-center justify-center text-center q-pa-xl text-grey-6"
        >
          <div>
            <q-icon name="ph ph-user-minus" size="48px" class="q-mb-sm text-grey-4" />
            <div class="text-subtitle1 text-weight-medium">No wallets found</div>
            <div class="text-caption">
              {{ searchText ? 'Try adjusting your search query' : 'No accounts available for this category' }}
            </div>
          </div>
        </div>

        <!-- Accounts List -->
        <q-list v-else separator class="col overflow-auto scroll-y">
          <q-item
            v-for="row in filteredRows"
            :key="row.id"
            clickable
            v-ripple
            class="q-py-md q-px-md wallet-row-item"
            @click="openWalletDetail(row)"
          >
            <q-item-section avatar>
              <q-avatar color="grey-3" text-color="grey-9" font-size="18px">
                <q-icon :name="entityIcon" />
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <q-item-label class="text-subtitle1 text-weight-bold text-grey-9">
                {{ row.name }}
                <q-chip
                  v-if="row.code"
                  dense
                  square
                  size="11px"
                  class="bg-grey-2 text-grey-8 text-weight-medium q-ml-xs"
                >
                  {{ row.code }}
                </q-chip>
              </q-item-label>
              <q-item-label v-if="row.caption" caption class="text-grey-7">
                {{ row.caption }}
              </q-item-label>
            </q-item-section>

            <q-item-section side class="text-right">
              <div class="text-subtitle1 text-weight-bolder" :class="balanceColorClass(row.totalBalance)">
                ৳ {{ formatCurrency(row.totalBalance) }}
              </div>
              <div class="text-caption text-grey-6 row items-center justify-end q-gutter-x-xs">
                <span>Total balance</span>
                <q-icon name="ph ph-caret-right" size="14px" />
              </div>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { walletRepository } from '../repositories/walletRepository';
import { getEntityTypeFromSlug } from '../utils/walletSlugMap';

interface WalletEntityRow {
  id: number;
  name: string;
  code?: string | undefined;
  caption?: string | undefined;
  totalBalance: number;
}

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const loading = ref<boolean>(true);
const searchText = ref<string>('');
const rowsWithBalances = ref<WalletEntityRow[]>([]);

const slug = computed<string>(() => (route.params.walletType as string) || '');

const pageTitle = computed(() => {
  switch (slug.value) {
    case 'customers': return 'Customer wallets';
    case 'suppliers': return 'Supplier wallets';
    case 'cargo':     return 'Cargo wallets';
    case 'couriers':  return 'Courier wallets';
    case 'investors': return 'Investor wallets';
    default:          return `${slug.value.charAt(0).toUpperCase() + slug.value.slice(1)} wallets`;
  }
});

const entityIcon = computed(() => {
  switch (slug.value) {
    case 'customers': return 'ph ph-users-three';
    case 'suppliers': return 'ph ph-truck-trailer';
    case 'cargo':     return 'ph ph-package';
    case 'couriers':  return 'ph ph-moped';
    case 'investors': return 'ph ph-chart-line-up';
    default:         return 'ph ph-wallet';
  }
});

const filteredRows = computed(() => {
  if (!searchText.value) return rowsWithBalances.value;
  const query = searchText.value.toLowerCase();
  return rowsWithBalances.value.filter(
    (r) =>
      r.name.toLowerCase().includes(query) ||
      (r.code && r.code.toLowerCase().includes(query)) ||
      (r.caption && r.caption.toLowerCase().includes(query)),
  );
});

function formatCurrency(val: number | undefined | null): string {
  if (val == null) return '0.00';
  return Number(val).toLocaleString('en-BD', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function balanceColorClass(balance: number): string {
  if (balance > 0) return 'text-positive';
  if (balance < 0) return 'text-negative';
  return 'text-grey-8';
}

function navigateBack() {
  void router.push({
    name: 'app-wallet-home-page',
    params: route.params,
  });
}

function openWalletDetail(row: WalletEntityRow) {
  void router.push({
    name: 'app-universal-wallet-page',
    params: {
      ...route.params,
      walletType: slug.value,
      entityId: row.id,
    },
  });
}

async function loadEntitiesAndBalances() {
  const currentSlug = slug.value;
  if (currentSlug === 'company') {
    const activeTenantId = authStore.selectedTenant?.id || 1;
    void router.replace({
      name: 'app-wallet-company-detail',
      params: { ...route.params, tenantId: activeTenantId },
    });
    return;
  }

  const entityType = getEntityTypeFromSlug(currentSlug);
  if (!entityType) {
    loading.value = false;
    return;
  }

  const tenantId = authStore.selectedTenant?.id || 1;
  loading.value = true;

  try {
    const rows = await walletRepository.listEntitiesForStaff(
      tenantId,
      entityType,
      searchText.value || null,
      100,
      0,
    );

    rowsWithBalances.value = rows.map((row) => ({
      id: Number(row.entity_id),
      name: String(row.name),
      code: row.code ? String(row.code) : undefined,
      caption: row.caption ? String(row.caption) : undefined,
      totalBalance: Number(row.total_balance || 0),
    }));
  } catch (err) {
    console.error('[WalletEntityListPage] Error loading list data:', err);
    rowsWithBalances.value = [];
  } finally {
    loading.value = false;
  }
}

watch(() => route.params.walletType, () => {
  void loadEntitiesAndBalances();
});

onMounted(() => {
  void loadEntitiesAndBalances();
});
</script>

<style scoped lang="scss">
.wallet-row-item {
  transition: background-color 0.15s ease;

  &:hover {
    background-color: var(--q-primary-1, #f0f7ff);
  }
}

.border-grey-3 {
  border: 1px solid #e2e8f0;
}
</style>
