<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center justify-end q-pb-sm shrink-0">
      <q-btn
        v-if="pay && !pay.voided_at"
        outline
        dense
        no-caps
        color="negative"
        label="Void receipt"
        :loading="voidMutation.isPending.value"
        @click="openVoidDialog"
      />
    </div>

    <div v-if="detailQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>
    <div v-else-if="pay" class="col overflow-auto">
      <div class="pay-form-card q-pa-md q-gutter-y-sm">
        <div class="text-h6 text-weight-bold">Pay #{{ pay.id }}</div>
        <div class="text-caption text-grey-7">{{ pay.payment_date }} · {{ pay.source }}</div>
        <div v-if="pay.voided_at" class="text-negative text-weight-medium">Voided</div>
        <div>Profile: {{ pay.profile_name || '—' }}</div>
        <div>Amount: {{ formatAmountBdt(pay.amount) }}</div>
        <div v-if="pay.unallocated_amount > 0">Leftover: {{ formatAmountBdt(pay.unallocated_amount) }}</div>
        <div v-if="pay.reference">Ref: {{ pay.reference }}</div>
        <div v-if="pay.note">Note: {{ pay.note }}</div>

        <div v-if="pay.instruments.length" class="q-mt-md">
          <div class="text-weight-medium">Instruments</div>
          <div v-for="inst in pay.instruments" :key="inst.id" class="text-body2">
            {{ inst.payment_method_code }} — {{ formatAmountBdt(inst.amount) }}
          </div>
        </div>

        <div v-if="pay.allocations.length" class="q-mt-md">
          <div class="text-weight-medium">Allocations</div>
          <div v-for="alloc in pay.allocations" :key="alloc.id" class="text-body2">
            {{ alloc.invoice_no || alloc.global_invoice_id }} — {{ formatAmountBdt(alloc.amount) }}
          </div>
        </div>

        <template v-if="canAllocateLater">
          <q-separator class="q-mt-md" />
          <div class="row items-center justify-between q-mt-md">
            <div class="text-weight-medium">Apply leftover to bills</div>
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              label="Fill oldest first"
              :disable="!openBills.length"
              @click="fillOldestFirst"
            />
          </div>
          <div v-if="loadingBills" class="text-grey-7 q-py-sm">Loading bills…</div>
          <div v-else-if="!openBills.length" class="text-grey-7 q-py-sm">No open bills for this profile.</div>
          <q-list v-else bordered separator class="rounded-borders q-mt-sm">
            <q-item v-for="bill in openBills" :key="bill.id">
              <q-item-section side top>
                <q-checkbox
                  :model-value="bill.selected"
                  dense
                  @update:model-value="(v) => onBillSelected(bill, !!v)"
                />
              </q-item-section>
              <q-item-section>
                <q-item-label>{{ bill.invoice_no }}</q-item-label>
                <q-item-label v-if="bill.sourceLabel" caption>{{ bill.sourceLabel }}</q-item-label>
                <q-item-label caption>Due {{ formatAmountBdt(bill.due_amount) }}</q-item-label>
              </q-item-section>
              <q-item-section side top>
                <q-input
                  v-model.number="bill.allocAmount"
                  type="number"
                  outlined
                  dense
                  label="Amount"
                  style="width: 112px"
                  :disable="!bill.selected"
                />
              </q-item-section>
            </q-item>
          </q-list>
          <q-banner
            v-if="allocOverLeftover"
            dense
            rounded
            class="bg-orange-1 text-orange-10 q-mt-sm"
          >
            Selections exceed leftover {{ formatAmountBdt(pay.unallocated_amount) }}.
          </q-banner>
          <q-btn
            unelevated
            color="primary"
            no-caps
            class="full-width q-mt-md"
            label="Apply leftover"
            :loading="allocateMutation.isPending.value"
            :disable="!canApplyLeftover"
            @click="applyLeftover"
          />
        </template>
      </div>
    </div>

    <q-dialog v-model="voidDialogOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-weight-bold">Void receipt?</q-card-section>
        <q-card-section>
          <q-input v-model="voidReason" outlined dense label="Reason" type="textarea" autogrow />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn unelevated no-caps color="negative" label="Void" @click="confirmVoid" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { paySourceToListSide, paymentsPageRoute } from '../utils/paymentsNavigation';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { paysRepository } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { useVoidPayMutation } from '../composables/useVoidPayMutation';
import { useAllocatePayMutation } from '../composables/useAllocatePayMutation';
import { fifoFillByOldest } from '../utils/fifoBillAlloc';

type BillAlloc = {
  id: number;
  invoice_no: string;
  invoice_date: string;
  due_amount: number;
  selected: boolean;
  allocAmount: number;
  sourceLabel: string | null;
};

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const voidMutation = useVoidPayMutation();
const allocateMutation = useAllocatePayMutation();

const payId = computed(() => {
  const raw = route.params.payId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);

const detailQuery = useQuery({
  queryKey: computed(() => paysQueryKeys.detail(payId.value)),
  queryFn: () => paysRepository.getPayById(payId.value!),
  enabled: computed(() => payId.value != null),
});

const pay = computed(() => detailQuery.data.value);

const canAllocateLater = computed(
  () =>
    !!pay.value &&
    !pay.value.voided_at &&
    pay.value.unallocated_amount > 0 &&
    (pay.value.source === 'customer_cash' || pay.value.source === 'bank') &&
    pay.value.profile_id != null,
);

const openBills = ref<BillAlloc[]>([]);
const loadingBills = ref(false);

watch(
  () => [pay.value?.id, pay.value?.unallocated_amount, pay.value?.profile_id] as const,
  async () => {
    openBills.value = [];
    if (!canAllocateLater.value || !pay.value?.profile_id) return;
    loadingBills.value = true;
    try {
      const { data } = await invoiceRepository.listGlobalInvoices({
        parentTenantId: pay.value.tenant_id,
        billingProfileId: pay.value.profile_id,
        invoiceStatus: 'issued',
        quickFilter: 'unpaid',
        pageSize: 100,
      });
      openBills.value = data.map((b) => ({
        id: b.id,
        invoice_no: b.invoice_no,
        invoice_date: b.invoice_date,
        due_amount: b.due_amount,
        selected: false,
        allocAmount: b.due_amount,
        sourceLabel: b.source_context_label ?? null,
      }));
    } finally {
      loadingBills.value = false;
    }
  },
);

const leftoverLines = computed(() =>
  openBills.value
    .filter((b) => b.selected && b.allocAmount > 0)
    .map((b) => ({ bill_id: b.id, amount: Number(b.allocAmount) })),
);

const leftoverAllocTotal = computed(() => leftoverLines.value.reduce((s, r) => s + r.amount, 0));

const allocOverLeftover = computed(
  () => leftoverAllocTotal.value > (pay.value?.unallocated_amount ?? 0),
);

const remainingLeftoverExcluding = (billId: number) => {
  const pool = pay.value?.unallocated_amount ?? 0;
  const used = openBills.value
    .filter((b) => b.selected && b.id !== billId)
    .reduce((sum, b) => sum + (Number(b.allocAmount) || 0), 0);
  return Math.max(0, pool - used);
};

const onBillSelected = (bill: BillAlloc, selected: boolean) => {
  if (!selected) {
    bill.selected = false;
    bill.allocAmount = bill.due_amount;
    return;
  }
  const take = Math.min(bill.due_amount, remainingLeftoverExcluding(bill.id));
  if (take <= 0) {
    bill.selected = false;
    bill.allocAmount = bill.due_amount;
    return;
  }
  bill.selected = true;
  bill.allocAmount = take;
};

watch(
  () => pay.value?.unallocated_amount,
  () => {
    let remaining = pay.value?.unallocated_amount ?? 0;
    for (const bill of openBills.value) {
      if (!bill.selected) continue;
      const take = Math.min(bill.due_amount, Number(bill.allocAmount) || 0, remaining);
      if (take <= 0) {
        bill.selected = false;
        bill.allocAmount = bill.due_amount;
      } else {
        bill.allocAmount = take;
        remaining -= take;
      }
    }
  },
);

const canApplyLeftover = computed(
  () => leftoverLines.value.length > 0 && leftoverAllocTotal.value <= (pay.value?.unallocated_amount ?? 0),
);

const fillOldestFirst = () => {
  if (!pay.value) return;
  const filled = fifoFillByOldest(openBills.value, pay.value.unallocated_amount);
  openBills.value = openBills.value.map((bill) => {
    const take = filled.get(bill.id);
    if (take == null) {
      return { ...bill, selected: false, allocAmount: bill.due_amount };
    }
    return { ...bill, selected: true, allocAmount: take };
  });
};

const applyLeftover = async () => {
  if (!pay.value || !canApplyLeftover.value) return;
  await allocateMutation.mutateAsync({
    tenantId: pay.value.tenant_id,
    paymentId: pay.value.id,
    lines: leftoverLines.value,
  });
};

const voidDialogOpen = ref(false);
const voidReason = ref('Corrected entry');

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  const side = paySourceToListSide(pay.value?.source);
  router.push(paymentsPageRoute(tenantSlug, side));
};

const openVoidDialog = () => {
  voidReason.value = 'Corrected entry';
  voidDialogOpen.value = true;
};

const confirmVoid = async () => {
  if (!payId.value || !voidReason.value.trim()) return;
  await voidMutation.mutateAsync({
    tenantId: tenantId.value,
    paymentId: payId.value,
    reason: voidReason.value.trim(),
  });
  voidDialogOpen.value = false;
  goBack();
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.pay-form-card {
  max-width: 720px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: 8px;
}
</style>
