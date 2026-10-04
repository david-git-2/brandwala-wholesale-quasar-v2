<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Payments" @click="goBack" />
    </div>
    <div class="col overflow-auto">
      <div class="pay-form-card q-pa-md q-gutter-y-md">
        <div class="text-subtitle1 text-weight-bold">Pay in — customer</div>
        <p class="text-caption text-grey-7 q-ma-none">Money they pay you against your sales bills. Vendor/cargo AP uses Pay out.</p>

        <q-input v-model="groupSearch" outlined dense label="Search customer group" debounce="300" @update:model-value="loadGroups" />
        <q-toggle v-model="onlyWithDue" dense label="Only with open bills" @update:model-value="loadGroups" />

        <q-list bordered separator class="rounded-borders">
          <q-item
            v-for="g in groups"
            :key="g.id"
            clickable
            :active="selectedGroupId === g.id"
            @click="selectGroup(g.id)"
          >
            <q-item-section>
              <q-item-label>{{ g.name }}</q-item-label>
              <q-item-label caption>Due {{ formatAmountBdt(g.total_due) }} · {{ g.open_invoice_count }} open</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>

        <q-select
          v-if="profiles.length"
          v-model="billingProfileId"
          :options="profiles"
          option-value="id"
          option-label="name"
          emit-value
          map-options
          outlined
          dense
          label="Bill-to profile"
        />

        <template v-if="billingProfileId">
          <div class="text-weight-medium">Open bills</div>
          <div v-if="loadingBills" class="text-grey-7">Loading bills…</div>
          <div v-for="bill in openBills" :key="bill.id" class="row items-center q-gutter-sm">
            <q-checkbox v-model="bill.selected" dense />
            <div class="col">
              <div class="text-body2">{{ bill.invoice_no }}</div>
              <div class="text-caption text-grey-7">Due {{ formatAmountBdt(bill.due_amount) }}</div>
            </div>
            <q-input
              v-model.number="bill.allocAmount"
              type="number"
              outlined
              dense
              style="max-width: 120px"
              :disable="!bill.selected"
            />
          </div>

          <q-input v-model="receivedOn" outlined dense label="Received on" type="date" />
          <q-input v-model="reference" outlined dense label="Reference" />
          <q-input v-model="note" outlined dense label="Note" type="textarea" autogrow />

          <q-input v-model.number="cashAmount" outlined dense label="Cash / bank amount" type="number" />
          <q-select
            v-model="methodCode"
            :options="methodOptions"
            emit-value
            map-options
            outlined
            dense
            label="Method"
          />

          <q-btn
            unelevated
            color="primary"
            no-caps
            label="Post receipt"
            :loading="collectMutation.isPending.value"
            :disable="!canSubmit"
            @click="submit"
          />
        </template>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { paysRepository, type CustomerGroupPaymentSummary } from '../repositories/paysRepository';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { useCollectPayMutation } from '../composables/useCollectPayMutation';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const collectMutation = useCollectPayMutation();

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const parentTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return null;
  return t.parent_id ?? t.id;
});

const groupSearch = ref('');
const onlyWithDue = ref(true);
const groups = ref<CustomerGroupPaymentSummary[]>([]);
const selectedGroupId = ref<number | null>(null);
const profiles = ref<Array<{ id: number; name: string }>>([]);
const billingProfileId = ref<number | null>(null);
const loadingBills = ref(false);

type BillAlloc = { id: number; invoice_no: string; due_amount: number; selected: boolean; allocAmount: number };
const openBills = ref<BillAlloc[]>([]);

const receivedOn = ref(new Date().toISOString().slice(0, 10));
const reference = ref('');
const note = ref('');
const cashAmount = ref<number | null>(null);
const methodCode = ref('cash');
const methodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'Bank transfer', value: 'bank_transfer' },
  { label: 'Cheque', value: 'cheque' },
  { label: 'bKash', value: 'bkash' },
];

const loadGroups = async () => {
  if (!tenantId.value) return;
  groups.value = await paysRepository.listCustomerGroupsPaymentSummary(tenantId.value, {
    search: groupSearch.value,
    onlyWithDue: onlyWithDue.value,
  });
};

const selectGroup = async (groupId: number) => {
  selectedGroupId.value = groupId;
  profiles.value = await paysRepository.listBillingProfilesForGroup(groupId);
  billingProfileId.value = profiles.value[0]?.id ?? null;
};

watch(billingProfileId, async (profileId) => {
  openBills.value = [];
  if (!profileId || !parentTenantId.value) return;
  loadingBills.value = true;
  try {
    const { data } = await invoiceRepository.listGlobalInvoices({
      parentTenantId: parentTenantId.value,
      billingProfileId: profileId,
      invoiceStatus: 'issued',
      quickFilter: 'unpaid',
      pageSize: 100,
    });
    openBills.value = data.map((b) => ({
      id: b.id,
      invoice_no: b.invoice_no,
      due_amount: b.due_amount,
      selected: false,
      allocAmount: b.due_amount,
    }));
  } finally {
    loadingBills.value = false;
  }
});

const allocations = computed(() =>
  openBills.value
    .filter((b) => b.selected && b.allocAmount > 0)
    .map((b) => ({ bill_id: b.id, amount: Number(b.allocAmount) })),
);

const canSubmit = computed(
  () =>
    !!billingProfileId.value &&
    (cashAmount.value ?? 0) > 0 &&
    allocations.value.length > 0 &&
    allocations.value.reduce((s, a) => s + a.amount, 0) <= (cashAmount.value ?? 0),
);

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({ name: 'app-payments-page', params: tenantSlug ? { tenantSlug } : {} });
};

const submit = async () => {
  if (!billingProfileId.value || !canSubmit.value) return;
  await collectMutation.mutateAsync({
    tenantId: tenantId.value,
    billingProfileId: billingProfileId.value,
    receivedOn: receivedOn.value,
    note: note.value || null,
    reference: reference.value || null,
    instruments: [
      {
        payment_method_code: methodCode.value,
        amount: Number(cashAmount.value),
        reference: reference.value || null,
      },
    ],
    allocations: allocations.value,
  });
  goBack();
};

void loadGroups();
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
