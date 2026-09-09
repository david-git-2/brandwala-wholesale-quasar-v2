<template>
  <q-page class="bw-page after-sales-policy-list-page">
    <section class="bw-page__stack">
      <div class="bw-page-toolbar">
        <div class="bw-page-toolbar__left">
          <h1 class="bw-page-toolbar__title">{{ pageHeading }}</h1>
        </div>
        <div v-if="isParentWorkspace" class="bw-page-toolbar__actions">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus-circle"
            label="Create policy"
            style="border-radius: 8px"
            @click="goToCreate"
          />
        </div>
      </div>

      <q-banner v-if="!isParentWorkspace" rounded class="after-sales-note-banner">
        Managed by parent company. You can view policies here but cannot edit them.
      </q-banner>

      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-4">
            <q-input
              v-model="search"
              dense
              outlined
              clearable
              debounce="300"
              placeholder="Search policy name…"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-6 col-md-3">
            <q-select
              v-model="programFilter"
              dense
              outlined
              clearable
              emit-value
              map-options
              :options="programOptions"
              label="Program type"
            />
          </div>
          <div class="col-6 col-md-3">
            <q-toggle v-model="activeOnly" label="Active only" dense />
          </div>
        </div>
      </q-card>

      <q-card flat bordered class="treasury-table-wrap">
        <q-table
          flat
          row-key="id"
          :rows="filteredRows"
          :columns="columns"
          :loading="policiesQuery.isLoading.value"
          :rows-per-page-options="[10, 25, 50]"
          @row-click="onRowClick"
        >
          <template #body-cell-program="props">
            <q-td :props="props">
              <q-badge
                outline
                :color="programBadgeColor(props.row.program)"
                :label="formatProgramType(props.row.program)"
              />
            </q-td>
          </template>

          <template #body-cell-window="props">
            <q-td :props="props">
              {{ props.row.window_days }}d · {{ formatAnchor(props.row.window_anchor) }}
            </q-td>
          </template>

          <template #body-cell-restock_fee="props">
            <q-td :props="props">
              {{ formatRestockFee(props.row) }}
            </q-td>
          </template>

          <template #body-cell-approval="props">
            <q-td :props="props">
              <span v-if="props.row.requires_approval">
                Yes<span v-if="props.row.approval_threshold_bdt"> · ৳{{ props.row.approval_threshold_bdt }}</span>
              </span>
              <span v-else class="bw-text-muted">No</span>
            </q-td>
          </template>

          <template #body-cell-is_active="props">
            <q-td :props="props">
              <q-badge
                :color="props.row.is_active ? 'positive' : 'grey-6'"
                :label="props.row.is_active ? 'Active' : 'Inactive'"
              />
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import type { QTableColumn } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useInvoiceWorkspace } from 'src/modules/sales_invoice/composables/useInvoiceWorkspace';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { useAfterSalesPoliciesQuery } from '../composables/useAfterSalesCaseMutations';
import type { AfterSalesPolicyProgram, AfterSalesProgram } from '../types/afterSales.types';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const { isParentTenant: isParentWorkspace } = useInvoiceWorkspace();

const pageHeading = computed(() =>
  isParentWorkspace.value ? 'Return policies' : 'View parent policies',
);

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
    { label: 'After Sales Service', to: hubPath },
    { label: pageHeading.value },
  ];
});

const search = ref('');
const programFilter = ref<AfterSalesProgram | null>(null);
const activeOnly = ref(false);

const parentTenantId = computed(() => {
  const tenant = tenantStore.selectedTenant;
  if (!tenant) return null;
  return tenant.parent_id ?? tenant.id;
});

const policiesQuery = useAfterSalesPoliciesQuery(parentTenantId);

const programOptions = [
  { label: 'Return credit', value: 'return_credit' as const },
  { label: 'DOA', value: 'doa' as const },
  { label: 'Replacement', value: 'replacement' as const },
  { label: 'Warranty', value: 'warranty' as const },
];

const columns: QTableColumn<AfterSalesPolicyProgram>[] = [
  { name: 'name', label: 'Policy name', field: 'name', align: 'left', sortable: true },
  { name: 'program', label: 'Type', field: 'program', align: 'left', sortable: true },
  { name: 'window', label: 'Window', field: 'window_days', align: 'left' },
  { name: 'restock_fee', label: 'Restock fee', field: 'restock_fee_type', align: 'left' },
  { name: 'approval', label: 'Approval', field: 'requires_approval', align: 'left' },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'left', sortable: true },
];

const filteredRows = computed(() => {
  let rows = policiesQuery.data.value ?? [];
  if (programFilter.value) {
    rows = rows.filter((row) => row.program === programFilter.value);
  }
  if (activeOnly.value) {
    rows = rows.filter((row) => row.is_active);
  }
  if (search.value.trim()) {
    const q = search.value.trim().toLowerCase();
    rows = rows.filter((row) => row.name.toLowerCase().includes(q));
  }
  return rows;
});

const formatProgramType = (program: AfterSalesProgram) =>
  program.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

const programBadgeColor = (program: AfterSalesProgram) => {
  if (program === 'return_credit') return 'purple';
  if (program === 'doa') return 'orange';
  if (program === 'replacement') return 'blue';
  return 'teal';
};

const formatAnchor = (anchor: AfterSalesPolicyProgram['window_anchor']) =>
  anchor === 'invoice_date' ? 'Invoice date' : 'Delivery date';

const formatRestockFee = (policy: AfterSalesPolicyProgram) => {
  if (policy.restock_fee_type === 'none') return 'None';
  if (policy.restock_fee_type === 'percent') return `${policy.restock_fee_value}%`;
  return `৳${policy.restock_fee_value}`;
};

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const goToCreate = () => {
  void router.push(`${getTenantPrefix()}/app/after-sales/policy/new`);
};

const onRowClick = (_event: Event, row: AfterSalesPolicyProgram) => {
  void router.push(`${getTenantPrefix()}/app/after-sales/policy/${row.id}`);
};
</script>

<style scoped>
.after-sales-note-banner {
  background: color-mix(in srgb, var(--bw-theme-muted) 12%, var(--bw-theme-surface));
  color: var(--bw-theme-ink);
  border: 1px solid var(--bw-theme-border);
}

:deep(.q-table tbody tr) {
  cursor: pointer;
}
</style>
