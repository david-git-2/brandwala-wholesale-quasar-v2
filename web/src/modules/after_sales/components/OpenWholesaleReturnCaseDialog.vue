<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 520px; max-width: 720px; width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">Open wholesale return case</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>

      <q-card-section v-if="!effectiveContext" class="text-body2 text-grey-7">
        Search for an issued wholesale invoice, or open this dialog from invoice details for a prefilled case.
        <q-input
          v-model="invoiceSearch"
          class="q-mt-md"
          dense
          outlined
          label="Invoice number (mock)"
          hint="Try WS-20260820-0123"
        />
        <q-btn
          class="q-mt-sm"
          flat
          color="primary"
          no-caps
          label="Use demo invoice"
          @click="loadDemoInvoice"
        />
      </q-card-section>

      <q-card-section v-else class="q-gutter-y-md">
        <div class="text-subtitle2 text-weight-bold">{{ effectiveContext.invoiceNo }}</div>
        <div class="text-caption text-grey-7">{{ effectiveContext.customerName }}</div>

        <q-select
          v-model="reasonCode"
          :options="reasonOptions"
          outlined
          dense
          emit-value
          map-options
          label="Reason"
        />

        <div v-for="line in lineDrafts" :key="line.invoice_item_id" class="row q-col-gutter-sm items-center">
          <div class="col">{{ line.product_name }}</div>
          <div class="col-auto" style="width: 100px">
            <q-input
              v-model.number="line.requested_qty"
              type="number"
              dense
              outlined
              min="0"
              :max="line.max_qty"
              label="Qty"
            />
          </div>
        </div>

        <q-card v-if="policyPreview" flat bordered class="bg-blue-1">
          <q-card-section class="q-py-sm">
            <div class="text-caption text-weight-bold text-primary">Policy preview (mock)</div>
            <div class="text-body2">
              Program: {{ policyPreview.policy_name }} · Window: {{ policyPreview.window_days }} days
            </div>
            <div class="text-body2">
              Restock fee: {{ formatBdt(policyPreview.suggested_restock_fee) }}
              <span v-if="policyPreview.requires_approval"> · Needs approval</span>
            </div>
            <q-banner v-if="!policyPreview.within_window" dense class="bg-warning text-dark q-mt-sm">
              Outside policy window — manager override required in live flow.
            </q-banner>
          </q-card-section>
        </q-card>
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Create case"
          :disable="!canSubmit"
          :loading="submitting"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { afterSalesRepositoryStub } from '../repositories/afterSalesRepository.stub';
import { resolveMockPolicyPreview } from '../services/mockPolicyResolver';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import { formatAmountBdt } from 'src/utils/currency';
import type { AfterSalesReasonCode, PolicyPreviewResult } from '../types/afterSales.types';

export type WholesaleCaseDialogContext = {
  salesInvoiceId: number;
  invoiceNo: string;
  customerName: string;
  billingProfileId: number | null;
  lines: Array<{ invoice_item_id: number; product_name: string; max_qty: number }>;
};

const props = defineProps<{
  modelValue: boolean;
  invoiceContext?: WholesaleCaseDialogContext | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'created', caseId: string): void;
}>();

const router = useRouter();
const route = useRoute();
const tenantStore = useTenantStore();

const invoiceSearch = ref('');
const reasonCode = ref<AfterSalesReasonCode>('unused');
const policyPreview = ref<PolicyPreviewResult | null>(null);
const submitting = ref(false);

const lineDrafts = ref<Array<{ invoice_item_id: number; product_name: string; requested_qty: number; max_qty: number }>>([]);
const demoContext = ref<WholesaleCaseDialogContext | null>(null);

const effectiveContext = computed(() => props.invoiceContext ?? demoContext.value);

const reasonOptions = [
  { label: 'Unused / change of mind', value: 'unused' },
  { label: 'Wrong item', value: 'wrong_item' },
  { label: 'DOA', value: 'doa' },
  { label: 'Warranty', value: 'warranty' },
  { label: 'Other', value: 'other' },
];

const formatBdt = (val: number) => formatAmountBdt(val);

const canSubmit = computed(() => {
  if (!effectiveContext.value) return false;
  return lineDrafts.value.some((line) => line.requested_qty > 0);
});

const loadDemoInvoice = () => {
  demoContext.value = {
    salesInvoiceId: 9001,
    invoiceNo: 'WS-20260820-0123',
    customerName: 'Metro Traders Ltd',
    billingProfileId: 201,
    lines: [
      { invoice_item_id: 10001, product_name: 'Premium Cotton Tee — Navy L', max_qty: 5 },
    ],
  };
  syncFromContext();
};

const syncFromContext = () => {
  const ctx = effectiveContext.value;
  if (!ctx) {
    lineDrafts.value = [];
    policyPreview.value = null;
    return;
  }
  lineDrafts.value = ctx.lines.map((line) => ({
    ...line,
    requested_qty: line.max_qty > 0 ? 1 : 0,
  }));
};

watch(
  () => [props.modelValue, props.invoiceContext, demoContext.value] as const,
  ([open]) => {
    if (open) syncFromContext();
    if (!open) demoContext.value = null;
  },
);

watch(reasonCode, async (reason) => {
  const firstLine = lineDrafts.value[0];
  if (!firstLine) return;
  policyPreview.value = await resolveMockPolicyPreview(firstLine.invoice_item_id, reason);
});

watch(
  () => props.modelValue,
  async (open) => {
    if (open && lineDrafts.value[0]) {
      policyPreview.value = await resolveMockPolicyPreview(lineDrafts.value[0].invoice_item_id, reasonCode.value);
    }
  },
);

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const onSubmit = async () => {
  const ctx = effectiveContext.value;
  const tenant = tenantStore.selectedTenant;
  if (!ctx || !tenant) return;

  submitting.value = true;
  try {
    const parentId = tenant.parent_id ?? tenant.id;
    const created = await afterSalesRepositoryStub.createWholesaleCase({
      parent_tenant_id: parentId,
      operating_tenant_id: tenant.id,
      operating_tenant_name: tenant.name,
      sales_invoice_id: ctx.salesInvoiceId,
      sales_invoice_no: ctx.invoiceNo,
      billing_profile_id: ctx.billingProfileId,
      customer_name: ctx.customerName,
      reason_code: reasonCode.value,
      lines: lineDrafts.value
        .filter((line) => line.requested_qty > 0)
        .map((line) => ({
          invoice_item_id: line.invoice_item_id,
          product_name: line.product_name,
          requested_qty: line.requested_qty,
        })),
    });

    showSuccessNotification(`Case ${created.case_no} created (mock).`);
    emit('update:modelValue', false);
    emit('created', created.id);
    void router.push(`${getTenantPrefix()}/app/after-sales/${created.id}`);
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Could not create case.');
  } finally {
    submitting.value = false;
  }
};
</script>
