<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Payments" @click="goBack" />
    </div>
    <div class="col overflow-auto">
      <div class="pay-form-card q-pa-md q-gutter-y-md">
        <q-tabs v-model="mode" dense align="left" active-color="primary" indicator-color="primary">
          <q-tab name="ap" label="Shipment AP" />
          <q-tab name="merchant" label="Merchant leftover" />
        </q-tabs>
        <q-separator />

        <q-tab-panels v-model="mode" animated>
          <q-tab-panel name="ap" class="q-pa-none q-gutter-y-md">
            <p class="text-caption text-grey-7 q-ma-none">Pay vendor, cargo, or local AP bills from inbound shipments.</p>
            <q-input
              v-model="apSearch"
              outlined
              dense
              label="Search party"
              debounce="300"
              @update:model-value="loadApProfiles"
            />
            <q-list bordered separator class="rounded-borders">
              <q-item
                v-for="row in apProfiles"
                :key="row.profile_id"
                clickable
                :active="selectedApProfileId === row.profile_id"
                @click="selectApProfile(row)"
              >
                <q-item-section>
                  <q-item-label>{{ row.name }}</q-item-label>
                  <q-item-label caption>
                    {{ row.profile_type }} · Due {{ formatAmountBdt(row.total_due) }}
                  </q-item-label>
                </q-item-section>
              </q-item>
            </q-list>

            <template v-if="selectedApProfileId && apBills.length">
              <div class="text-subtitle2 text-weight-medium">Open AP bills</div>
              <q-list bordered separator class="rounded-borders">
                <q-item v-for="bill in apBills" :key="bill.id">
                  <q-item-section>
                    <q-item-label>{{ bill.invoice_no }}</q-item-label>
                    <q-item-label caption>{{ bill.note || bill.ap_kind }}</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-item-label>{{ formatAmountBdt(bill.due_amount) }}</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
              <q-input v-model.number="apAmount" outlined dense label="Payment amount" type="number" />
              <q-select
                v-model="apMethod"
                :options="methodOptions"
                emit-value
                map-options
                outlined
                dense
                label="Method"
                :loading="loadingPaymentMeta"
              />
              <PaymentInstrumentExtrasFields
                :method-code="apMethod"
                :method-options="methodOptions"
                :bd-bank-options="bdBankOptions"
                :loading="loadingPaymentMeta"
                :bd-bank-id="apBdBankId"
                :cheque-number="apChequeNumber"
                :instrument-date="apInstrumentDate"
                :instrument-reference="apInstrumentReference"
                @update:bd-bank-id="apBdBankId = $event"
                @update:cheque-number="apChequeNumber = $event"
                @update:instrument-date="apInstrumentDate = $event"
                @update:instrument-reference="apInstrumentReference = $event"
              />
              <q-input v-model="apReference" outlined dense clearable label="Payment reference (optional)" />
              <q-input v-model="apNotes" outlined dense label="Notes" type="textarea" autogrow />
              <div class="pay-submit-wrap full-width">
                <q-btn
                  unelevated
                  color="primary"
                  no-caps
                  class="full-width"
                  label="Post AP pay out"
                  :loading="submitting"
                  :disable="!canSubmitAp || submitting"
                  @click="submitAp"
                />
                <q-tooltip v-if="apSubmitDisabledReason" anchor="top middle" self="bottom middle">
                  {{ apSubmitDisabledReason }}
                </q-tooltip>
              </div>
            </template>
          </q-tab-panel>

          <q-tab-panel name="merchant" class="q-pa-none q-gutter-y-md">
            <p class="text-caption text-grey-7 q-ma-none">Settles shop cashbook. Not a bill allocation.</p>
            <q-input v-model="search" outlined dense label="Search shop / group" debounce="300" @update:model-value="loadSummary" />
            <q-list bordered separator class="rounded-borders">
              <q-item
                v-for="row in summary"
                :key="row.customer_group_id"
                clickable
                :active="selectedGroupId === row.customer_group_id"
                @click="selectGroup(row)"
              >
                <q-item-section>
                  <q-item-label>{{ row.name }}</q-item-label>
                  <q-item-label caption>Payable {{ formatAmountBdt(row.payable_balance) }}</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
            <template v-if="selectedProfile">
              <div class="text-body2">
                Profile: <strong>{{ selectedProfile.name }}</strong> · Balance
                {{ formatAmountBdt(selectedProfile.payable_balance) }}
              </div>
              <q-input v-model.number="amount" outlined dense label="Payout amount" type="number" />
              <q-select
                v-model="method"
                :options="methodOptions"
                emit-value
                map-options
                outlined
                dense
                label="Method"
                :loading="loadingPaymentMeta"
              />
              <q-input v-model="notes" outlined dense label="Notes" type="textarea" autogrow />
              <q-btn
                unelevated
                color="primary"
                no-caps
                label="Pay out"
                :loading="submitting"
                :disable="!canSubmitMerchant"
                @click="submitMerchant"
              />
            </template>
          </q-tab-panel>
        </q-tab-panels>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import {
  paysRepository,
  type ApPayProfileSummary,
  type CustomerGroupPayoutSummary,
  type OpenApBillRow,
} from '../repositories/paysRepository';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import PaymentInstrumentExtrasFields from '../components/PaymentInstrumentExtrasFields.vue';
import { useWholesalePaymentMethodMeta } from '../composables/useWholesalePaymentMethodMeta';
import {
  buildWholesalePaymentInstrument,
  paymentInstrumentExtrasBlockReason,
  paymentMethodFieldFlags,
} from '../utils/paymentInstrumentFields';
import { paymentsPageRoute } from '../utils/paymentsNavigation';
import { paysQueryKeys } from '../services/paysQueryKeys';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const queryClient = useQueryClient();

const mode = ref<'ap' | 'merchant'>('ap');
const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const parentTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t?.id) return 0;
  return t.parent_id ?? t.id;
});

const search = ref('');
const summary = ref<CustomerGroupPayoutSummary[]>([]);
const selectedGroupId = ref<number | null>(null);
const selectedProfile = ref<{ billing_profile_id: number; name: string; payable_balance: number } | null>(null);
const amount = ref<number | null>(null);
const method = ref('bank_transfer');
const notes = ref('');

const apSearch = ref('');
const apProfiles = ref<ApPayProfileSummary[]>([]);
const selectedApProfileId = ref<number | null>(null);
const apBills = ref<OpenApBillRow[]>([]);
const apAmount = ref<number | null>(null);
const apMethod = ref('bank_transfer');
const apReference = ref('');
const apNotes = ref('');
const apBdBankId = ref<number | null>(null);
const apChequeNumber = ref('');
const apInstrumentDate = ref('');
const apInstrumentReference = ref('');

const submitting = ref(false);
const { loadingPaymentMeta, methodOptions, bdBankOptions, loadPaymentMeta } =
  useWholesalePaymentMethodMeta('bank_transfer');

const resetApInstrumentFields = () => {
  apBdBankId.value = null;
  apChequeNumber.value = '';
  apInstrumentDate.value = '';
  apInstrumentReference.value = '';
};

watch(apMethod, () => {
  resetApInstrumentFields();
});

const apMethodFieldFlags = computed(() => {
  const row = methodOptions.value.find((m) => m.value === apMethod.value);
  const meta = row
    ? { code: row.code, category: row.category }
    : { code: apMethod.value.toUpperCase(), category: '' };
  return paymentMethodFieldFlags(meta);
});

const apInstrumentFields = computed(() => ({
  bdBankId: apBdBankId.value,
  chequeNumber: apChequeNumber.value,
  instrumentDate: apInstrumentDate.value,
  instrumentReference: apInstrumentReference.value,
}));

const canSubmitMerchant = computed(
  () =>
    !!selectedProfile.value &&
    (amount.value ?? 0) > 0 &&
    (amount.value ?? 0) <= (selectedProfile.value?.payable_balance ?? 0),
);

const apDueTotal = computed(() => apBills.value.reduce((s, b) => s + (Number(b.due_amount) || 0), 0));

const apSubmitDisabledReason = computed((): string | null => {
  if (selectedApProfileId.value == null) return 'Select a party to pay';
  if (!apBills.value.length) return 'No open AP bills for this party';
  if ((apAmount.value ?? 0) <= 0) return 'Enter a payment amount';
  if ((apAmount.value ?? 0) > apDueTotal.value) {
    return 'Payment amount cannot exceed total due on open bills';
  }
  return paymentInstrumentExtrasBlockReason(apMethodFieldFlags.value, apInstrumentFields.value);
});

const canSubmitAp = computed(() => apSubmitDisabledReason.value === null);

const loadSummary = async () => {
  if (!tenantId.value) return;
  summary.value = await paysRepository.listCustomerGroupsPayoutSummary(tenantId.value, {
    search: search.value,
    onlyWithPayable: true,
  });
};

const loadApProfiles = async () => {
  if (!parentTenantId.value) return;
  apProfiles.value = await paysRepository.listApPayProfileSummaries(parentTenantId.value, apSearch.value);
};

const selectApProfile = async (row: ApPayProfileSummary) => {
  selectedApProfileId.value = row.profile_id;
  apBills.value = await paysRepository.listOpenApBillsForProfile(parentTenantId.value, row.profile_id);
  apAmount.value = apBills.value.reduce((s, b) => s + Number(b.due_amount), 0);
};

const selectGroup = (row: CustomerGroupPayoutSummary) => {
  selectedGroupId.value = row.customer_group_id;
  const profiles = row.billing_profiles ?? [];
  selectedProfile.value = profiles[0] ?? null;
  amount.value = selectedProfile.value?.payable_balance ?? null;
};

const tenantSlugParam = () =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;

const goBack = () => {
  router.push(paymentsPageRoute(tenantSlugParam(), 'out'));
};

const buildApAllocations = (payAmount: number) => {
  let remaining = payAmount;
  const allocations: Array<{ bill_id: number; amount: number }> = [];
  for (const bill of apBills.value) {
    if (remaining <= 0) break;
    const due = Number(bill.due_amount) || 0;
    if (due <= 0) continue;
    const slice = Math.min(due, remaining);
    allocations.push({ bill_id: bill.id, amount: slice });
    remaining -= slice;
  }
  return allocations;
};

const submitAp = async () => {
  if (!canSubmitAp.value || selectedApProfileId.value == null) return;
  const payAmount = Number(apAmount.value);
  const allocations = buildApAllocations(payAmount);
  const allocSum = allocations.reduce((s, a) => s + a.amount, 0);
  if (allocSum !== payAmount) {
    showErrorNotification('Payment must fully allocate to open AP bills.');
    return;
  }
  submitting.value = true;
  try {
    await paysRepository.postApPayoutWithAllocations({
      tenant_id: tenantId.value,
      profile_id: selectedApProfileId.value,
      reference: apReference.value || null,
      note: apNotes.value || null,
      instruments: [
        buildWholesalePaymentInstrument({
          payment_method_code: apMethod.value,
          amount: payAmount,
          instrument_reference: apInstrumentReference.value,
          bd_bank_id: apBdBankId.value,
          cheque_number: apChequeNumber.value,
          instrument_date: apInstrumentDate.value,
        }),
      ],
      allocations,
    });
    showSuccessNotification('AP pay out recorded.');
    void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
    goBack();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'AP pay out failed.');
  } finally {
    submitting.value = false;
  }
};

const submitMerchant = async () => {
  if (!selectedProfile.value || !canSubmitMerchant.value) return;
  submitting.value = true;
  try {
    await paysRepository.dispenseMiddlemanPayout({
      tenant_id: tenantId.value,
      billing_profile_id: selectedProfile.value.billing_profile_id,
      amount: Number(amount.value),
      payout_method: method.value,
      reference_notes: notes.value || null,
    });
    showSuccessNotification('Payout recorded.');
    void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
    goBack();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Payout failed.');
  } finally {
    submitting.value = false;
  }
};

void loadSummary();
void loadApProfiles();
void loadPaymentMeta((code) => {
  if (mode.value === 'ap') apMethod.value = code;
  else method.value = code;
});
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
.pay-submit-wrap {
  display: inline-block;
  width: 100%;
  cursor: default;
}
.pay-submit-wrap :deep(.q-btn.disabled),
.pay-submit-wrap :deep(.q-btn--disabled) {
  pointer-events: none;
}
</style>
