<template>
  <q-page class="bw-page after-sales-case-detail-page">
    <div v-if="caseQuery.isLoading.value" class="case-detail-loading">
      <q-spinner color="primary" size="40px" />
    </div>

    <div v-else-if="!caseRow" class="case-detail-loading bw-text-muted">Case not found.</div>

    <section v-else class="bw-page__stack case-detail-stack">
      <q-card flat bordered class="q-pa-md">
        <div class="case-detail-header">
          <div class="case-detail-header__title">{{ caseRow.case_no }}</div>
          <div class="row items-center q-gutter-xs q-mt-xs">
            <q-badge
              :color="caseRow.source_channel === 'wholesale' ? 'purple-2' : 'teal-2'"
              :text-color="caseRow.source_channel === 'wholesale' ? 'purple-9' : 'teal-9'"
              :label="caseRow.source_channel"
            />
            <q-badge :color="statusColor" :label="caseRow.status.replace(/_/g, ' ')" />
          </div>
          <div class="case-detail-header__meta q-mt-sm">
            {{ caseRow.customer_name }}
            <span v-if="caseRow.sales_invoice_no"> · Invoice {{ caseRow.sales_invoice_no }}</span>
            <span v-if="caseRow.shop_order_no"> · Order {{ caseRow.shop_order_no }}</span>
          </div>
        </div>
      </q-card>

      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-8 q-gutter-y-md">
          <q-card flat bordered>
            <q-card-section class="text-subtitle2 text-weight-bold">Lines</q-card-section>
            <q-markup-table flat dense>
              <thead>
                <tr>
                  <th class="text-left">Product</th>
                  <th class="text-right">Req</th>
                  <th class="text-right">Rcvd</th>
                  <th class="text-left">Outcome</th>
                  <th class="text-right">Fee</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="line in editableLines" :key="line.id">
                  <td>{{ line.product_name }}</td>
                  <td class="text-right">{{ line.requested_qty }}</td>
                  <td class="text-right">{{ line.received_qty }}</td>
                  <td>
                    <q-select
                      v-if="caseRow.status === 'inspecting'"
                      v-model="line.outcome"
                      dense
                      outlined
                      emit-value
                      map-options
                      :options="outcomeOptions"
                    />
                    <span v-else>{{ line.outcome }}</span>
                  </td>
                  <td class="text-right">{{ formatBdt(line.restock_fee_amount) }}</td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>

          <q-card v-if="caseRow.source_channel === 'dropship'" flat bordered>
            <q-card-section class="text-subtitle2 text-weight-bold">Intake</q-card-section>
            <q-card-section class="q-pt-none text-body2">
              <div>Source: {{ caseRow.intake_source }} · Reported to: {{ caseRow.reported_to }}</div>
              <div>Reporter: {{ caseRow.reporter_name }} ({{ caseRow.reporter_phone }})</div>
              <div class="q-mt-sm">{{ caseRow.intake_note }}</div>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-md-4">
          <q-card flat bordered>
            <q-card-section class="text-subtitle2 text-weight-bold">Timeline</q-card-section>
            <q-card-section class="q-pt-none">
              <AfterSalesCaseTimeline :events="caseRow.events" />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </section>

    <div
      v-if="caseRow && footerActions.length"
      class="case-detail-footer bw-inline-actions"
    >
      <q-btn
        v-for="action in footerActions"
        :key="action.key"
        :color="action.color"
        :outline="action.outline"
        unelevated
        no-caps
        style="border-radius: 8px"
        :label="action.label"
        :loading="action.loading"
        @click="action.onClick"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import { formatAmountBdt } from 'src/utils/currency';
import AfterSalesCaseTimeline from '../components/AfterSalesCaseTimeline.vue';
import {
  useAfterSalesCaseMutations,
  useAfterSalesCaseQuery,
} from '../composables/useAfterSalesCaseMutations';
import type { AfterSalesCaseLine, AfterSalesOutcome } from '../types/afterSales.types';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

const caseId = computed(() => {
  const raw = route.params.id;
  return typeof raw === 'string' ? raw : null;
});

const parentTenantId = computed(() => {
  const tenant = tenantStore.selectedTenant;
  if (!tenant) return null;
  return tenant.parent_id ?? tenant.id;
});

const caseQuery = useAfterSalesCaseQuery(caseId);
const mutations = useAfterSalesCaseMutations(parentTenantId);

const caseRow = computed(() => caseQuery.data.value ?? null);
const editableLines = ref<AfterSalesCaseLine[]>([]);

usePageBreadcrumbs(() => {
  const tenantSlug =
    tenantStore.selectedTenant?.slug ||
    authStore.selectedTenant?.slug ||
    (route.params.tenantSlug as string | undefined);
  const hubPath = tenantSlug ? `/${tenantSlug}/app/after-sales` : '/app/after-sales';
  const listPath = tenantSlug ? `/${tenantSlug}/app/after-sales/cases` : '/app/after-sales/cases';

  return [
    {
      label: tenantStore.selectedTenant?.name || authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    { label: 'After Sales Service', to: hubPath },
    { label: 'All cases', to: listPath },
    { label: caseRow.value?.case_no || 'Case detail' },
  ];
});

watch(
  caseRow,
  (row) => {
    if (!row) return;
    editableLines.value = row.lines.map((line) => ({ ...line }));
  },
  { immediate: true },
);

const formatBdt = (val: number) => formatAmountBdt(val);

const statusColor = computed(() => {
  const status = caseRow.value?.status;
  if (status === 'closed') return 'positive';
  if (status === 'rejected') return 'negative';
  if (status === 'pending_approval') return 'warning';
  return 'primary';
});

const outcomeOptions: { label: string; value: AfterSalesOutcome }[] = [
  { label: 'Credit', value: 'credit' },
  { label: 'Replace', value: 'replace' },
  { label: 'Repair', value: 'repair' },
  { label: 'Reject', value: 'reject' },
];

const runMutation = async (fn: () => Promise<unknown>, successMsg: string) => {
  try {
    await fn();
    await caseQuery.refetch();
    showSuccessNotification(successMsg);
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Action failed.');
  }
};

const footerActions = computed(() => {
  const row = caseRow.value;
  const id = caseId.value;
  if (!row || !id) return [];

  if (row.status === 'pending_approval') {
    return [
      {
        key: 'reject',
        label: 'Reject',
        color: 'negative',
        outline: true,
        loading: mutations.reject.isPending.value,
        onClick: () => void runMutation(() => mutations.reject.mutateAsync(id), 'Case rejected (mock).'),
      },
      {
        key: 'approve',
        label: 'Approve',
        color: 'primary',
        outline: false,
        loading: mutations.approve.isPending.value,
        onClick: () => void runMutation(() => mutations.approve.mutateAsync(id), 'Case approved (mock).'),
      },
    ];
  }

  if (row.status === 'awaiting_receipt') {
    return [
      {
        key: 'received',
        label: 'Mark received',
        color: 'primary',
        outline: false,
        loading: mutations.markReceived.isPending.value,
        onClick: () => void runMutation(() => mutations.markReceived.mutateAsync(id), 'Goods marked received (mock).'),
      },
    ];
  }

  if (row.status === 'inspecting') {
    return [
      {
        key: 'inspect',
        label: 'Save outcomes & continue',
        color: 'primary',
        outline: false,
        loading: mutations.updateLines.isPending.value,
        onClick: () =>
          void runMutation(
            () => mutations.updateLines.mutateAsync({ caseId: id, lines: editableLines.value }),
            'Inspection saved (mock).',
          ),
      },
    ];
  }

  if (row.status === 'executing') {
    if (row.source_channel === 'wholesale' && row.sales_invoice_id) {
      return [
        {
          key: 'execute-credit',
          label: 'Execute credit',
          color: 'primary',
          outline: false,
          loading: false,
          onClick: () => {
            void router.push({
              name: 'app-global-invoice-return-page',
              params: {
                tenantSlug: route.params.tenantSlug,
                id: String(row.sales_invoice_id),
              },
              query: { case_id: row.id },
            });
          },
        },
      ];
    }

    if (row.source_channel === 'dropship' && row.shop_order_id) {
      return [
        {
          key: 'finalize',
          label: 'Proceed to return finalize',
          color: 'teal',
          outline: false,
          loading: false,
          onClick: () => {
            void router.push({
              name: 'app-shop-dropship-return-page',
              params: {
                tenantSlug: route.params.tenantSlug,
                id: String(row.shop_order_id),
              },
              query: { case_id: row.id },
            });
          },
        },
      ];
    }
  }

  return [];
});
</script>

<style scoped>
.case-detail-stack {
  padding-bottom: 88px;
}

.case-detail-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 240px;
}

.case-detail-header__title {
  font-size: 1.25rem;
  font-weight: 800;
  color: var(--bw-theme-ink);
}

.case-detail-header__meta {
  font-size: 0.82rem;
  color: var(--bw-theme-muted);
}

.case-detail-footer {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 10;
  justify-content: flex-end;
  padding: 0.65rem clamp(1rem, 2.4vw, 2rem);
  background: color-mix(in srgb, var(--bw-theme-surface) 94%, var(--bw-theme-base) 6%);
  border-top: 1px solid var(--bw-theme-border);
}
</style>
