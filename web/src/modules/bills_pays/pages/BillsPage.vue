<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap">
    <div class="column no-wrap full-height bills-page-root">
      <q-card flat bordered class="q-pa-xs flex-shrink-0 bills-page-toolbar">
        <div class="row items-center justify-between bills-toolbar-row">
          <div class="row items-center bills-toolbar-actions">
            <q-btn-toggle
              v-model="cardLayout"
              unelevated
              dense
              no-caps
              toggle-color="primary"
              :options="layoutOptions"
              class="bills-layout-toggle"
            />
          </div>
          <div class="row items-center bills-toolbar-actions">
            <q-btn
              flat
              round
              dense
              icon="ph ph-funnel"
              class="text-slate-500"
              aria-label="Filters"
              @click="filterDrawerOpen = true"
            >
              <q-badge v-if="filterCount > 0" color="primary" rounded floating>
                {{ filterCount }}
              </q-badge>
              <q-tooltip>Filters</q-tooltip>
            </q-btn>
            <q-btn
              unelevated
              round
              dense
              color="primary"
              icon="ph ph-plus"
              aria-label="Bill"
            >
              <q-tooltip>Bill</q-tooltip>
            </q-btn>
            <q-btn flat dense no-caps label="Brands" class="text-slate-600" />
          </div>
        </div>
      </q-card>

      <div class="bills-page-tabs flex-shrink-0 min-width-0">
        <TfDrawerSectionTabs
          v-model="toProfileTab"
          :tabs="toProfileTabs"
          aria-label="Payee profile type"
        />
      </div>

      <div v-if="listQuery.isError.value" class="tf-status-banner bg-negative text-white q-pa-sm rounded-borders">
        {{ listErrorMessage }}
      </div>

      <div
        v-if="listQuery.isPending.value && !rows.length"
        class="col min-width-0 bills-content-col"
        :class="{ 'bills-content-col--list': cardLayout === 'list' }"
      >
        <div v-if="cardLayout === 'list'" class="invoice-list-card">
          <div class="invoice-list-scroll">
            <div
              v-for="n in 8"
              :key="n"
              class="invoice-list-item invoice-list-item--skeleton"
            >
              <q-skeleton type="text" width="55%" />
            </div>
          </div>
        </div>
        <div v-else class="bills-cards-scroll bills-cards--grid">
          <q-skeleton
            v-for="n in 6"
            :key="n"
            type="rect"
            height="88px"
            class="rounded-borders bills-card-skeleton"
          />
        </div>
      </div>

      <div
        v-else-if="!rows.length"
        class="column items-center justify-center q-pa-xl text-grey-6 col"
      >
        <q-icon name="ph ph-receipt" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-bold text-slate-800">No bills match</div>
        <div class="text-caption text-grey-6 q-mt-xs">Try another payee tab or filter.</div>
      </div>

      <div
        v-else
        class="col min-width-0 bills-content-col"
        :class="{ 'bills-content-col--list': cardLayout === 'list' }"
      >
        <div v-if="cardLayout === 'list'" class="invoice-list-card">
          <div class="invoice-list-scroll">
            <BillListRow
              v-for="row in rows"
              :key="row.id"
              :row="row"
              @open="openBill"
            />
            <div v-if="hasMore" class="row justify-center q-py-sm">
              <q-btn
                flat
                dense
                no-caps
                class="load-more-btn q-px-md"
                :loading="listQuery.isFetchingNextPage.value"
                label="Load more"
                icon="ph ph-arrow-down"
                @click="loadMore"
              />
            </div>
          </div>
        </div>
        <div v-else class="bills-cards-scroll bills-cards--grid">
          <BillListCard
            v-for="row in rows"
            :key="row.id"
            :row="row"
            @open="openBill"
          />
          <div v-if="hasMore" class="bills-load-more row justify-center q-py-sm">
            <q-btn
              flat
              dense
              no-caps
              :loading="listQuery.isFetchingNextPage.value"
              label="Load more"
              icon="ph ph-arrow-down"
              @click="loadMore"
            />
          </div>
        </div>
      </div>
    </div>

    <BillsListFilterDrawer
      v-model="filterDrawerOpen"
      :status="statusPill"
      :from-profile-id="fromProfileId"
      :from-options="partyOptions"
      @apply="onApplyFilters"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useMembershipPreference } from 'src/modules/membership/composables/useMembershipPreference';
import { MEMBERSHIP_UI_PATHS } from 'src/modules/membership/types/preferences';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import BillListCard from '../components/BillListCard.vue';
import BillListRow from '../components/BillListRow.vue';
import BillsListFilterDrawer from '../components/BillsListFilterDrawer.vue';
import { useBillsListInfiniteQuery } from '../composables/useBillsListInfiniteQuery';
import { useDeskBillPartyOptions } from '../composables/useDeskBillPartyOptions';
import type {
  BillListRow as BillListRowData,
  BillToProfileTypeTab,
  StatusPill,
} from '../types/billList';
import { billOpensOnDetailNotComposeDesk } from '../utils/billRoutes';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

type CardLayoutMode = 'grid' | 'list';

const filterDrawerOpen = ref(false);
const { value: cardLayout } = useMembershipPreference<CardLayoutMode>({
  path: MEMBERSHIP_UI_PATHS.billsPaysListCardLayout,
  defaultValue: 'list',
});
watch(
  cardLayout,
  (mode) => {
    if (mode !== 'grid' && mode !== 'list') {
      cardLayout.value = 'list';
    }
  },
  { flush: 'sync' },
);
const layoutOptions = [
  { value: 'grid' as const, icon: 'ph ph-squares-four' },
  { value: 'list' as const, icon: 'ph ph-list' },
];
const toProfileTab = ref<BillToProfileTypeTab>('all');
const statusPill = ref<StatusPill>('all');
const fromProfileId = ref<number | null>(null);

const toProfileTabs = [
  { name: 'all', label: 'All' },
  { name: 'tenant', label: 'Tenant' },
  { name: 'customer', label: 'Customer' },
  { name: 'company', label: 'Company' },
  { name: 'vendor', label: 'Vendor' },
  { name: 'cargo', label: 'Cargo' },
  { name: 'courier', label: 'Courier' },
  { name: 'investor', label: 'Investor' },
] as const;

const parentTenantId = computed(() => {
  const tenant = authStore.selectedTenant;
  if (!tenant?.id) return null;
  return tenant.parent_id ?? tenant.id;
});

const partyQuery = useDeskBillPartyOptions(parentTenantId);
const partyOptions = computed(() => partyQuery.data.value ?? []);

const filterCount = computed(() => {
  let n = 0;
  if (statusPill.value !== 'all') n += 1;
  if (fromProfileId.value != null) n += 1;
  return n;
});

const listParams = computed(() => {
  const base = {
    parentTenantId: parentTenantId.value,
    toProfileType: toProfileTab.value,
    fromProfileId: fromProfileId.value,
  };
  switch (statusPill.value) {
    case 'draft':
      return { ...base, invoiceStatus: 'draft' };
    case 'due':
      return { ...base, invoiceStatus: 'issued', paymentStatus: 'due' };
    case 'partial':
      return { ...base, paymentStatus: 'partially_paid' };
    case 'paid':
      return { ...base, quickFilter: 'paid' as const };
    case 'voided':
      return { ...base, invoiceStatus: 'voided' };
    default:
      return base;
  }
});

const listQuery = useBillsListInfiniteQuery(listParams);
const rows = listQuery.rows;
const hasMore = listQuery.hasMore;

const listErrorMessage = computed(() => {
  const err = listQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load bills.';
});

const onApplyFilters = (payload: { status: StatusPill; fromProfileId: number | null }) => {
  statusPill.value = payload.status;
  fromProfileId.value = payload.fromProfileId;
};

const loadMore = () => {
  if (!hasMore.value || listQuery.isFetchingNextPage.value) return;
  void listQuery.fetchNextPage();
};

const tenantSlugParam = () =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;

const openBill = (row: BillListRowData) => {
  const tenantSlug = tenantSlugParam();
  const detailRoute = {
    name: 'app-bill-detail-page' as const,
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(row.id),
    },
  };

  if (
    billOpensOnDetailNotComposeDesk({
      invoice_status: row.invoice_status,
      invoice_type: row.invoice_type,
      source_type: row.kind === 'shipment_cost_ap' ? 'shipment_cost' : null,
      ap_kind: row.ap_kind,
    })
  ) {
    void router.push(detailRoute);
    return;
  }

  const isDraft =
    row.invoice_status === 'draft' || row.invoice_status === 'proforma_generated';
  if (isDraft && row.invoice_type !== 'ap') {
    void router.push({
      name: 'app-bill-compose-page',
      params: tenantSlug ? { tenantSlug } : {},
      query: { id: String(row.id) },
    });
    return;
  }
  void router.push(detailRoute);
};
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';

.bills-content-col {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.bills-content-col--list .invoice-list-card {
  flex: 1 1 0%;
  min-height: 0;
}

.page-fixed-layout {
  height: calc(100vh - 55px);
  width: 100%;
  min-width: 0;
  max-width: 100%;
  overflow-x: clip;
  box-sizing: border-box;
}

.bills-page-root {
  flex: 1;
  min-height: 0;
  min-width: 0;
  max-width: 100%;
  overflow-x: clip;
  gap: 8px;
}

.bills-page-toolbar {
  min-width: 0;
  max-width: 100%;
  overflow-x: clip;
}

.bills-toolbar-row {
  flex-wrap: wrap;
  gap: 8px;
  min-width: 0;
  max-width: 100%;
}

.bills-toolbar-actions {
  flex-wrap: wrap;
  gap: 4px;
  min-width: 0;
}

.bills-page-tabs {
  min-width: 0;
  max-width: 100%;
  overflow-x: clip;

  :deep(.tf-drawer-section-tabs__scroll) {
    overflow-x: clip;
    max-width: 100%;
    width: 100%;
  }

  :deep(.tf-drawer-section-tabs__track) {
    display: flex;
    flex-wrap: wrap;
    width: 100%;
    min-width: 0;
    max-width: 100%;
    box-sizing: border-box;
  }
}

.bills-cards-scroll {
  overflow-x: clip;
  overflow-y: auto;
  min-width: 0;
  max-width: 100%;
  width: 100%;
  align-content: start;
  box-sizing: border-box;
}

.bills-cards--grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(0, 1fr));
  gap: 8px;
}

@media (min-width: 520px) {
  .bills-cards--grid {
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  }
}

.bills-card-skeleton {
  min-width: 0;
  max-width: 100%;
}

.bills-layout-toggle :deep(.q-btn) {
  min-width: 32px;
  padding: 4px 6px;
}

.bills-load-more {
  grid-column: 1 / -1;
  width: 100%;
}
</style>
