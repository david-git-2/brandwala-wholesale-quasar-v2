<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden invoice-list-stack">
      <TfDrawerSectionTabs
        v-model="deskTab"
        :tabs="deskTabs"
        aria-label="Payments desk view"
        class="shrink-0"
      />

      <PaymentsRecentList v-if="deskTab === 'recent'" />

      <template v-else>
        <ProcurementOpsListToolbar
          :search="searchText"
          search-placeholder="Search profile…"
          :filter-count="0"
          @update:search="onSearchTextUpdate"
        >
          <template #pills>
            <TfDrawerSectionTabs
              v-model="entityTab"
              :tabs="typeSectionTabs"
              aria-label="Payment profile type"
              @update:model-value="setEntityTab"
            />
          </template>
        </ProcurementOpsListToolbar>

        <div v-if="listError" class="tf-status-banner bg-negative text-white q-pa-sm rounded-borders">
          {{ listError }}
        </div>

        <div v-if="isPending && !rows.length" class="invoice-list-card col">
          <div class="invoice-list-scroll">
            <div v-for="n in 6" :key="n" class="invoice-list-item invoice-list-item--skeleton">
              <q-skeleton type="text" width="60%" />
            </div>
          </div>
        </div>

        <div
          v-else-if="!rows.length"
          class="column items-center justify-center q-pa-xl text-grey-6 col invoice-list-card"
        >
          <q-icon name="ph ph-users" size="48px" class="q-mb-sm text-grey-4" />
          <div class="text-subtitle1 text-weight-bold text-slate-800">No profiles</div>
        </div>

        <div v-else class="invoice-list-card payments-list-card">
          <div class="invoice-list-scroll">
            <div
              v-for="row in rows"
              :key="`${row.entity_type}-${row.entity_id}`"
              class="profile-row-wrap"
            >
              <CashbookEntityRow :row="row" @open="selectProfile" />
            </div>
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ProcurementOpsListToolbar from 'src/modules/procurement_stock/components/ProcurementOpsListToolbar.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import CashbookEntityRow from '../components/CashbookEntityRow.vue';
import PaymentsRecentList from '../components/PaymentsRecentList.vue';
import {
  cashbookRepository,
  type CashbookEntityRow as EntityRow,
} from '../repositories/cashbookRepository';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

type DeskTab = 'profiles' | 'recent';
type EntityTab = 'tenant' | 'customer' | 'courier' | 'vendor';

const deskTab = ref<DeskTab>('profiles');
const deskTabs = [
  { name: 'profiles' as const, label: 'Profiles' },
  { name: 'recent' as const, label: 'Recent pays' },
];

const searchText = ref('');
const debouncedSearch = ref('');
const entityTab = ref<EntityTab>('customer');
const rows = ref<EntityRow[]>([]);
const isPending = ref(false);
const listError = ref<string | null>(null);

const typeTabs: { label: string; value: EntityTab }[] = [
  { label: 'Tenant', value: 'tenant' },
  { label: 'Customer', value: 'customer' },
  { label: 'Courier', value: 'courier' },
  { label: 'Vendor', value: 'vendor' },
];

const typeSectionTabs = typeTabs.map((tab) => ({ name: tab.value, label: tab.label }));

const operatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});

const loadRows = async () => {
  if (!operatingTenantId.value) return;
  isPending.value = true;
  listError.value = null;
  try {
    if (entityTab.value === 'tenant') {
      rows.value = [
        await cashbookRepository.getTenantCashRow(operatingTenantId.value, booksTenantId.value),
      ];
    } else {
      rows.value = await cashbookRepository.listEntities({
        tenantId: operatingTenantId.value,
        entityType: entityTab.value,
        search: debouncedSearch.value || undefined,
        limit: 200,
      });
    }
  } catch (e) {
    listError.value = e instanceof Error ? e.message : 'Could not load profiles.';
    rows.value = [];
  } finally {
    isPending.value = false;
  }
};

watch(debouncedSearch, () => {
  if (deskTab.value === 'profiles') void loadRows();
});

watch(deskTab, (tab) => {
  if (tab === 'profiles') void loadRows();
});

const setEntityTab = (value: string | number) => {
  const next = value as EntityTab;
  if (entityTab.value === next) return;
  entityTab.value = next;
  void loadRows();
};

void loadRows();

let searchTimer: ReturnType<typeof setTimeout> | null = null;
const onSearchTextUpdate = (value: string | null | undefined) => {
  searchText.value = value ?? '';
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    debouncedSearch.value = (value ?? '').trim();
  }, 300);
};

const selectProfile = (row: EntityRow) => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-payment-profile-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      entityType: row.entity_type,
      entityId: String(row.entity_id),
    },
  });
};
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.payments-list-card {
  flex: 0 1 auto;
  align-self: stretch;
  max-height: 100%;
  min-height: 0;
}
.payments-list-card .invoice-list-scroll {
  flex: 0 1 auto;
  max-height: calc(100vh - 11rem);
  overflow-y: auto;
}
</style>
