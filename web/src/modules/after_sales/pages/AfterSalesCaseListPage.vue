<template>
  <q-page class="bw-page after-sales-case-list-page">
    <section class="bw-page__stack">
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-3">
            <q-input
              v-model="search"
              dense
              outlined
              clearable
              debounce="300"
              placeholder="Search case, customer, invoice…"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-6 col-md-2">
            <q-select
              v-model="statusFilter"
              dense
              outlined
              clearable
              emit-value
              map-options
              :options="statusOptions"
              label="Status"
            />
          </div>
          <div class="col-6 col-md-2">
            <q-select
              v-model="reasonFilter"
              dense
              outlined
              clearable
              emit-value
              map-options
              :options="reasonOptions"
              label="Reason"
            />
          </div>
          <div class="col-6 col-md-2">
            <q-select
              v-model="channelFilter"
              dense
              outlined
              clearable
              emit-value
              map-options
              :options="channelOptions"
              label="Channel"
            />
          </div>
          <div v-if="showChildFilter" class="col-12 col-md-3">
            <q-select
              v-model="childTenantFilter"
              dense
              outlined
              clearable
              emit-value
              map-options
              :options="childTenantOptions"
              label="Operating tenant"
            />
          </div>
        </div>
      </q-card>

      <AfterSalesCaseTable
        :rows="tableRows"
        :loading="casesQuery.isLoading.value"
        @row-click="onRowClick"
      />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useInvoiceWorkspace } from 'src/modules/sales_invoice/composables/useInvoiceWorkspace';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import AfterSalesCaseTable, { type AfterSalesCaseTableRow } from '../components/AfterSalesCaseTable.vue';
import { useAfterSalesCasesQuery } from '../composables/useAfterSalesCasesQuery';
import { MOCK_CHILD_TENANTS } from '../fixtures/mockAfterSales';
import type { AfterSalesCaseListFilters, AfterSalesCaseStatus, AfterSalesReasonCode, AfterSalesSourceChannel } from '../types/afterSales.types';

const props = defineProps<{
  channelPreset?: AfterSalesSourceChannel | null;
  pageTitle?: string;
  pageCaption?: string;
}>();

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const { isParentTenant: isParentWorkspace } = useInvoiceWorkspace();

const pageTitle = computed(() => props.pageTitle ?? 'All cases');

usePageBreadcrumbs(() => {
  const tenantSlug =
    tenantStore.selectedTenant?.slug ||
    authStore.selectedTenant?.slug ||
    (route.params.tenantSlug as string | undefined);
  const hubPath = tenantSlug ? `/${tenantSlug}/app/after-sales` : '/app/after-sales';

  return [
    {
      label: tenantStore.selectedTenant?.name || authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    { label: 'Returns', to: hubPath },
    { label: pageTitle.value },
  ];
});

const search = ref('');
const statusFilter = ref<AfterSalesCaseStatus | null>(null);
const reasonFilter = ref<AfterSalesReasonCode | null>(null);
const channelFilter = ref<AfterSalesSourceChannel | null>(props.channelPreset ?? null);
const childTenantFilter = ref<number | null>(null);

const tenantId = computed(() => tenantStore.selectedTenant?.id ?? null);
const showChildFilter = computed(() => isParentWorkspace.value);

const filters = computed<AfterSalesCaseListFilters>(() => ({
  channel: channelFilter.value,
  status: statusFilter.value,
  reason: reasonFilter.value,
  search: search.value,
  operating_tenant_id: childTenantFilter.value,
}));

const casesQuery = useAfterSalesCasesQuery(tenantId, filters);

const tableRows = computed<AfterSalesCaseTableRow[]>(() => {
  const now = Date.now();
  return (casesQuery.data.value ?? []).map((row) => ({
    ...row,
    age_days: Math.max(0, Math.floor((now - new Date(row.opened_at).getTime()) / 86400000)),
  }));
});

const childTenantOptions = computed(() =>
  MOCK_CHILD_TENANTS.map((t) => ({ label: t.name, value: t.id })),
);

const statusOptions = [
  'pending_approval',
  'awaiting_receipt',
  'inspecting',
  'executing',
  'closed',
  'rejected',
].map((value) => ({ label: value.replace(/_/g, ' '), value }));

const reasonOptions = ['unused', 'wrong_item', 'doa', 'warranty', 'other'].map((value) => ({
  label: value.replace(/_/g, ' '),
  value,
}));

const channelOptions = [
  { label: 'Wholesale', value: 'wholesale' as const },
  { label: 'Dropship', value: 'dropship' as const },
];

watch(
  () => route.query.status,
  (raw) => {
    if (typeof raw === 'string' && raw) {
      statusFilter.value = raw as AfterSalesCaseStatus;
    }
  },
  { immediate: true },
);

watch(
  () => route.query.channel,
  (raw) => {
    if (typeof raw === 'string' && (raw === 'wholesale' || raw === 'dropship')) {
      channelFilter.value = raw;
    }
  },
  { immediate: true },
);

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const onRowClick = (row: AfterSalesCaseTableRow) => {
  void router.push(`${getTenantPrefix()}/app/after-sales/${row.id}`);
};
</script>
