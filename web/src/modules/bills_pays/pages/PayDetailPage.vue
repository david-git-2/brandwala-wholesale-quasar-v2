<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="detailQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>
    <div v-else-if="pay" class="col overflow-auto">
      <div class="pay-detail-shell">
        <TfBtn
          variant="tertiary"
          size="sm"
          icon="ph ph-arrow-left"
          label="Back to payments"
          class="q-mb-sm"
          @click="goBack"
        />

        <q-card flat bordered class="pay-detail-card">
          <div class="pay-detail-header">
            <div class="pay-detail-header__main">
              <div class="row items-center wrap q-gutter-xs">
                <span class="pay-detail-title">Pay #{{ pay.id }}</span>
                <span class="pay-detail-type-chip">{{ paySourceLabel }}</span>
                <TfStatusBadge v-if="pay.voided_at" status="cancelled" label="Voided" />
              </div>
              <div class="pay-detail-meta">
                <span>{{ pay.payment_date }}</span>
                <span class="pay-detail-meta-dot" aria-hidden="true">·</span>
                <span>{{ pay.profile_name || 'No profile' }}</span>
              </div>
            </div>
            <div v-if="!pay.voided_at" class="pay-detail-header__actions row q-gutter-sm">
              <TfBtn
                v-if="canCorrectPayment"
                variant="primary"
                size="sm"
                icon="ph ph-arrows-clockwise"
                label="Correct amount or rate"
                :loading="correctPaymentVoiding"
                @click="onOpenCorrectPayment"
              />
              <TfBtn
                v-if="canVoidPayment"
                variant="danger-trigger"
                size="sm"
                :label="voidButtonLabel"
                :loading="voidMutation.isPending.value"
                @click="openVoidDialog"
              />
            </div>
          </div>

          <div
            v-if="payCorrectionHint"
            class="pay-detail-hint"
            :class="payCorrectionHintTone === 'blocked' ? 'pay-detail-hint--blocked' : 'pay-detail-hint--info'"
          >
            <q-icon
              :name="payCorrectionHintTone === 'blocked' ? 'ph ph-lock' : 'ph ph-info'"
              size="18px"
              class="pay-detail-hint__icon"
            />
            <span>{{ payCorrectionHint }}</span>
          </div>

          <div class="pay-detail-amount">
            <div v-if="isFxPay" class="pay-detail-amount__stack">
              <div class="pay-detail-amount__primary tf-num">
                {{ formatSettlementCurrencyAmount(pay.foreign_amount, pay.settlement_currency_code) }}
              </div>
              <div class="pay-detail-amount__fx tf-num">
                {{ formatBdtTaka(pay.amount) }}
                <span class="pay-detail-amount__rate">
                  @ {{ pay.exchange_rate }} BDT/{{ pay.settlement_currency_code }}
                </span>
              </div>
            </div>
            <div v-else class="pay-detail-amount__primary tf-num">
              {{ formatBdtTaka(pay.amount) }}
            </div>
            <div v-if="pay.unallocated_amount > 0" class="pay-detail-leftover">
              Unallocated {{ formatAmountBdt(pay.unallocated_amount) }}
            </div>
          </div>

          <dl v-if="pay.reference || pay.note" class="pay-detail-meta-grid">
            <template v-if="pay.reference">
              <dt>Reference</dt>
              <dd>{{ pay.reference }}</dd>
            </template>
            <template v-if="pay.note">
              <dt>Note</dt>
              <dd>{{ pay.note }}</dd>
            </template>
          </dl>

          <section v-if="pay.instruments.length" class="pay-detail-section">
            <div class="pay-detail-section__label">Instruments</div>
            <q-markup-table flat dense bordered class="pay-detail-table">
              <thead>
                <tr>
                  <th class="text-left">Method</th>
                  <th class="text-right">Amount</th>
                  <th class="text-right">Action</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="inst in pay.instruments" :key="inst.id">
                  <td>
                    <span class="text-weight-medium">{{ inst.payment_method_code }}</span>
                    <span v-if="inst.cheque_number" class="pay-detail-table__sub">
                      · {{ inst.cheque_number }}
                    </span>
                    <TfStatusBadge
                      v-if="inst.bounced_at"
                      status="cancelled"
                      label="Bounced"
                      class="q-ml-xs"
                    />
                  </td>
                  <td class="text-right tf-num">{{ formatAmountBdt(inst.amount) }}</td>
                  <td class="text-right">
                    <TfBtn
                      v-if="canBounceInstrument(inst)"
                      variant="danger-trigger"
                      size="sm"
                      label="Mark bounced"
                      :loading="bounceMutation.isPending.value"
                      @click="openBounceDialog(inst.id)"
                    />
                    <span v-else class="pay-detail-table__muted">—</span>
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </section>

          <section v-if="pay.allocations.length" class="pay-detail-section">
            <div class="pay-detail-section__label">Applied to bills</div>
            <q-list bordered separator class="rounded-borders pay-detail-alloc-list">
              <q-item v-for="alloc in pay.allocations" :key="alloc.id" dense>
                <q-item-section>
                  <TfBtn
                    v-if="alloc.global_invoice_id"
                    variant="link"
                    size="sm"
                    :label="alloc.invoice_no || `Bill #${alloc.global_invoice_id}`"
                    @click="goToBill(alloc.global_invoice_id)"
                  />
                  <span v-else>{{ alloc.invoice_no || alloc.global_invoice_id }}</span>
                </q-item-section>
                <q-item-section side class="tf-num text-weight-medium">
                  {{ formatAllocAmount(alloc.amount) }}
                </q-item-section>
              </q-item>
            </q-list>
          </section>

          <section v-if="canDispenseShopPayout" class="pay-detail-section">
            <div class="pay-detail-hint pay-detail-hint--info q-mb-sm" style="margin: 0">
              <q-icon name="ph ph-info" size="18px" class="pay-detail-hint__icon" />
              <span>Remittance profit is on the shop cashbook. Pay it out here — do not allocate to another bill.</span>
            </div>
          <q-select
            v-model="shopPayFromPotId"
            :options="shopPayFromOptions"
            emit-value
            map-options
            outlined
            dense
            label="Pay from (location & currency)"
            class="q-mt-sm"
            :loading="shopPayFromLoading"
          />
          <q-input
            v-model.number="shopPayoutAmount"
            type="number"
            outlined
            dense
            label="Pay out to shop (BDT)"
            class="q-mt-sm"
          />
          <q-select
            v-model="shopPayoutMethod"
            :options="shopPayoutMethodOptions"
            emit-value
            map-options
            outlined
            dense
            label="Payout method"
            class="q-mt-sm"
          />
          <q-input
            v-model="shopPayoutNotes"
            outlined
            dense
            label="Reference notes"
            type="textarea"
            autogrow
            class="q-mt-sm"
          />
          <TfBtn
            variant="primary"
            class="full-width q-mt-md"
            label="Pay out to shop"
            :loading="shopPayoutSubmitting"
            :disable="!canSubmitShopPayout"
            @click="submitShopPayout"
          />
          </section>

        <section v-if="canAllocateLater" class="pay-detail-section">
          <div class="row items-center justify-between q-mb-sm">
            <div class="pay-detail-section__label q-mb-none">Apply leftover to bills</div>
            <TfBtn
              variant="link"
              size="sm"
              label="Fill oldest first"
              :disable="!openBills.length"
              @click="fillOldestFirst"
            />
          </div>
          <div v-if="loadingBills" class="text-body2" style="color: var(--tf-neutral-muted)">Loading bills…</div>
          <div v-else-if="!openBills.length" class="text-body2" style="color: var(--tf-neutral-muted)">
            No open bills for this profile.
          </div>
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
          <div
            v-if="allocOverLeftover"
            class="pay-detail-hint pay-detail-hint--blocked q-mt-sm"
            style="margin-left: 0; margin-right: 0"
          >
            Selections exceed leftover {{ formatAmountBdt(pay.unallocated_amount) }}.
          </div>
          <TfBtn
            variant="primary"
            class="full-width q-mt-md"
            label="Apply leftover"
            :loading="allocateMutation.isPending.value"
            :disable="!canApplyLeftover"
            @click="applyLeftover"
          />
        </section>
        </q-card>
      </div>
    </div>

    <q-dialog v-model="voidDialogOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-weight-bold">{{ voidDialogTitle }}</q-card-section>
        <q-card-section>
          <q-input v-model="voidReason" outlined dense label="Reason" type="textarea" autogrow />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn unelevated no-caps color="negative" label="Void" @click="confirmVoid" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="bounceDialogOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-weight-bold">Mark cheque bounced?</q-card-section>
        <q-card-section class="text-body2">
          <template v-if="bounceWillBePartial">
            Only this cheque slice is reversed. Other tender on the receipt stays; bill due goes up for the bounced portion.
          </template>
          <template v-else>
            The whole payment will be reversed. Bills stay issued; amounts due go back up.
          </template>
        </q-card-section>
        <q-card-section>
          <q-input v-model="bounceReason" outlined dense label="Reason" type="textarea" autogrow />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            unelevated
            no-caps
            color="negative"
            label="Bounce cheque"
            :loading="bounceMutation.isPending.value"
            @click="confirmBounce"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <CorrectPaymentDialog
      v-model="correctPaymentDialogOpen"
      :pay="correctPaymentDisplayPay"
      :loading="correctPaymentVoiding"
      @confirm="onConfirmCorrectPaymentVoid"
      @cancel="onCancelCorrectPayment"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { paySourceToListSide, paymentsPageRoute } from '../utils/paymentsNavigation';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt, formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';
import { billsRepository } from '../repositories/billsRepository';
import { paysRepository } from '../repositories/paysRepository';
import type { PayDetail } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { useVoidPayMutation } from '../composables/useVoidPayMutation';
import { useBounceChequeMutation } from '../composables/useBounceChequeMutation';
import { useAllocatePayMutation } from '../composables/useAllocatePayMutation';
import CorrectPaymentDialog from '../components/CorrectPaymentDialog.vue';
import { useCorrectPaymentFlow } from '../composables/useCorrectPaymentFlow';
import { usePaymentsVoidAccess } from '../composables/usePaymentsVoidAccess';
import { isPayVoidable } from '../utils/payVoidability';
import type { PayCorrectionSnapshot } from '../types/payCorrectionSnapshot';
import { fifoFillByOldest } from '../utils/fifoBillAlloc';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { useCashbookPointsQuery } from '../composables/useCashbookPointsQuery';
import { useCashbookPayFromPotSelect } from '../composables/useCashbookPayFromPotSelect';

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
const bounceMutation = useBounceChequeMutation();
const allocateMutation = useAllocatePayMutation();
const queryClient = useQueryClient();

const shopPayoutAmount = ref<number | null>(null);
const shopPayoutMethod = ref('bank_transfer');
const shopPayoutNotes = ref('');
const shopPayoutSubmitting = ref(false);
const shopOrderPayoutSettled = ref(false);

const shopPayoutMethodOptions = [
  { label: 'Bank transfer', value: 'bank_transfer' },
  { label: 'bKash', value: 'bkash' },
  { label: 'Cash', value: 'cash' },
];

const payId = computed(() => {
  const raw = route.params.payId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const parentTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t?.id) return 0;
  return t.parent_id ?? t.id;
});
const detailQuery = useQuery({
  queryKey: computed(() => paysQueryKeys.detail(payId.value)),
  queryFn: () => paysRepository.getPayById(payId.value!),
  enabled: computed(() => payId.value != null),
});

const pay = computed(() => detailQuery.data.value);

const paymentsVoidAccess = usePaymentsVoidAccess();

const primaryBillId = computed(() => pay.value?.allocations[0]?.global_invoice_id ?? null);

const {
  dialogOpen: correctPaymentDialogOpen,
  voiding: correctPaymentVoiding,
  displayPay: correctPaymentDisplayPay,
  openCorrect: openCorrectPayment,
  closeDialog: closeCorrectPaymentDialog,
  confirmVoid: confirmCorrectPaymentVoid,
} = useCorrectPaymentFlow({
  billId: primaryBillId,
  onVoided: async (snapshot: PayCorrectionSnapshot) => {
    const billId = primaryBillId.value;
    const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
    if (billId) {
      await router.push({
        name: 'app-bill-detail-page',
        params: {
          ...(tenantSlug ? { tenantSlug } : {}),
          billId: String(billId),
        },
        state: { payCorrectionPrefill: snapshot },
      });
      return;
    }
    goBack();
  },
});

const payIsVoidableBySource = computed(() => {
  const p = pay.value;
  if (!p) return false;
  return isPayVoidable({ source: p.source, method: p.method, voidedAt: p.voided_at });
});

const canVoidPayment = computed(() => paymentsVoidAccess.value && payIsVoidableBySource.value);

const canCorrectPayment = computed(() => canVoidPayment.value);

const paySourceLabel = computed(() => {
  const s = pay.value?.source;
  if (s === 'ap_payout') return 'AP pay out';
  if (s === 'courier_remittance') return 'Remittance';
  if (s === 'commission') return 'Commission payout';
  if (s === 'store_credit') return 'Store credit';
  if (s === 'bank') return 'Bank receipt';
  if (s === 'customer_cash') return 'Customer receipt';
  return s?.replace(/_/g, ' ') ?? 'Payment';
});

const payCorrectionHint = computed(() => {
  const p = pay.value;
  if (!p || p.voided_at) return null;
  if (p.source === 'store_credit' || p.method === 'wallet_credit') {
    return 'Store-credit payments cannot be corrected on this screen.';
  }
  if (!paymentsVoidAccess.value && payIsVoidableBySource.value) {
    return 'You need payments void permission to correct this pay.';
  }
  if (canCorrectPayment.value) {
    return 'Posted payments cannot be edited inline. Correct amount or rate voids this pay and opens the bill to enter again.';
  }
  return null;
});

const payCorrectionHintTone = computed((): 'info' | 'blocked' => {
  const p = pay.value;
  if (!p) return 'info';
  if (p.source === 'store_credit' || p.method === 'wallet_credit') return 'blocked';
  if (!paymentsVoidAccess.value && payIsVoidableBySource.value) return 'blocked';
  return 'info';
});

const voidButtonLabel = computed(() => {
  const src = pay.value?.source;
  if (src === 'ap_payout' || src === 'commission') return 'Void payout';
  if (src === 'courier_remittance') return 'Void remittance';
  return 'Void receipt';
});

const voidDialogTitle = computed(() => {
  const src = pay.value?.source;
  if (src === 'ap_payout' || src === 'commission') return 'Void payout?';
  if (src === 'courier_remittance') return 'Void remittance?';
  return 'Void receipt?';
});

type PayInstrumentRow = PayDetail['instruments'][number];

const canBounceInstrument = (inst: PayInstrumentRow) => {
  if (!pay.value || pay.value.voided_at) return false;
  if (inst.bounced_at) return false;
  return String(inst.payment_method_code ?? '').toUpperCase() === 'CHEQUE';
};

const bounceWillBePartial = computed(() => {
  const inst = pay.value?.instruments ?? [];
  const active = inst.filter((i) => !i.bounced_at);
  return active.length > 1;
});

const isFxPay = computed(() => {
  const p = pay.value;
  if (!p) return false;
  const code = (p.settlement_currency_code ?? 'BDT').toUpperCase();
  return code !== 'BDT' && Number(p.exchange_rate) > 0 && p.foreign_amount != null;
});

const formatAllocAmount = (allocBdt: number) => {
  const p = pay.value;
  if (!p || !isFxPay.value) return formatBdtTaka(allocBdt);
  const rate = Number(p.exchange_rate) || 1;
  const fx = Math.round((allocBdt / rate) * 100) / 100;
  return formatSettlementCurrencyAmount(fx, p.settlement_currency_code ?? 'BDT');
};

const canDispenseShopPayout = computed(
  () =>
    !!pay.value &&
    !pay.value.voided_at &&
    pay.value.source === 'courier_remittance' &&
    pay.value.profile_id != null &&
    pay.value.unallocated_amount > 0 &&
    !shopOrderPayoutSettled.value,
);

const shopPayoutPointsContext = computed(() => ({
  booksTenantId: parentTenantId.value,
  entityType: 'tenant',
  entityId: parentTenantId.value,
  enabled: parentTenantId.value > 0 && canDispenseShopPayout.value,
}));
const { pointsQuery: shopPayoutPointsQuery } = useCashbookPointsQuery(shopPayoutPointsContext);
const shopPayoutPoints = computed(() => shopPayoutPointsQuery.data.value);
const shopPayFromEnabled = computed(() => canDispenseShopPayout.value && parentTenantId.value > 0);
const {
  selectedPotId: shopPayFromPotId,
  payFromOptions: shopPayFromOptions,
  cashbookPointId: shopCashbookPointId,
  loading: shopPayFromLoading,
} = useCashbookPayFromPotSelect(shopPayoutPoints, shopPayFromEnabled);

watch(
  () => pay.value?.shop_order_id,
  async (orderId) => {
    shopOrderPayoutSettled.value = false;
    if (!orderId) return;
    const { data } = await supabase
      .from('shop_orders')
      .select('payout_settlement_status')
      .eq('id', orderId)
      .maybeSingle();
    shopOrderPayoutSettled.value = data?.payout_settlement_status === 'paid';
  },
  { immediate: true },
);

const canSubmitShopPayout = computed(
  () =>
    canDispenseShopPayout.value &&
    !!shopPayFromPotId.value &&
    !!shopCashbookPointId.value &&
    !shopPayFromLoading.value &&
    (shopPayoutAmount.value ?? 0) > 0 &&
    (shopPayoutAmount.value ?? 0) <= (pay.value?.unallocated_amount ?? 0),
);

watch(
  () => pay.value?.unallocated_amount,
  (amt) => {
    if (amt != null && amt > 0 && canDispenseShopPayout.value) {
      shopPayoutAmount.value = amt;
    }
  },
  { immediate: true },
);

const canAllocateLater = computed(
  () =>
    !!pay.value &&
    !pay.value.voided_at &&
    pay.value.unallocated_amount > 0 &&
    (pay.value.source === 'customer_cash' ||
      pay.value.source === 'bank' ||
      pay.value.source === 'ap_payout') &&
    pay.value.profile_id != null,
);

const submitShopPayout = async () => {
  if (!pay.value?.profile_id || !canSubmitShopPayout.value) return;
  shopPayoutSubmitting.value = true;
  try {
    if (!shopCashbookPointId.value || !shopPayFromPotId.value) return;
    await paysRepository.postMoneyOut({
      tenant_id: pay.value.tenant_id,
      profile_id: pay.value.profile_id,
      amount: Number(shopPayoutAmount.value),
      payout_method: shopPayoutMethod.value,
      note: shopPayoutNotes.value || null,
      cashbook_point_id: shopCashbookPointId.value,
      cashbook_point_pot_id: shopPayFromPotId.value,
      source_type: 'commission',
      source: 'commission',
    });
    showSuccessNotification('Shop payout recorded.');
    shopOrderPayoutSettled.value = true;
    void queryClient.invalidateQueries({ queryKey: paysQueryKeys.detail(pay.value.id) });
    void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Shop payout failed.');
  } finally {
    shopPayoutSubmitting.value = false;
  }
};

const openBills = ref<BillAlloc[]>([]);
const loadingBills = ref(false);

watch(
  () => [pay.value?.id, pay.value?.unallocated_amount, pay.value?.profile_id] as const,
  async () => {
    openBills.value = [];
    if (!canAllocateLater.value || !pay.value?.profile_id) return;
    loadingBills.value = true;
    try {
      const isApPayout = pay.value.source === 'ap_payout';
      const { data } = await billsRepository.listBills({
        parentTenantId: pay.value.tenant_id,
        profileId: pay.value.profile_id,
        invoiceStatus: 'issued',
        quickFilter: 'unpaid',
        pageSize: 100,
        invoiceType: isApPayout ? 'ap' : undefined,
        arSide: isApPayout ? 'we_owe' : 'they_owe',
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
    lines: leftoverLines.value.map((line) => ({
      bill_id: line.bill_id,
      amount: line.amount,
      allocator_kind: 'pay' as const,
      allocator_id: pay.value!.id,
    })),
  });
};

const voidDialogOpen = ref(false);
const voidReason = ref('Corrected entry');
const bounceDialogOpen = ref(false);
const bounceInstrumentId = ref<number | null>(null);
const bounceReason = ref('Cheque returned by bank');

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  const side = paySourceToListSide(pay.value?.source);
  router.push(paymentsPageRoute(tenantSlug, side));
};

const goToBill = (billId: number) => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-bill-detail-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(billId),
    },
  });
};

const onOpenCorrectPayment = () => {
  if (!payId.value) return;
  void openCorrectPayment(payId.value);
};

const onConfirmCorrectPaymentVoid = (reason: string) => {
  void confirmCorrectPaymentVoid(reason);
};

const onCancelCorrectPayment = () => {
  closeCorrectPaymentDialog();
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
    source: pay.value?.source,
  });
  voidDialogOpen.value = false;
  goBack();
};

const openBounceDialog = (instrumentId: number) => {
  bounceInstrumentId.value = instrumentId;
  bounceReason.value = 'Cheque returned by bank';
  bounceDialogOpen.value = true;
};

const confirmBounce = async () => {
  if (!bounceInstrumentId.value || !bounceReason.value.trim() || !pay.value) return;
  const result = await bounceMutation.mutateAsync({
    tenantId: pay.value.tenant_id,
    instrumentId: bounceInstrumentId.value,
    reason: bounceReason.value.trim(),
  });
  bounceDialogOpen.value = false;
  if ((result as { partial?: boolean } | null)?.partial !== true) {
    goBack();
  }
};
</script>

<style scoped lang="scss">
.page-fixed-layout {
  height: calc(100vh - 55px);
}

.pay-detail-shell {
  max-width: 640px;
  margin: 0 auto;
  padding-bottom: var(--tf-space-md, 16px);
}

.pay-detail-card {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-sm, 8px);
  overflow: hidden;
}

.pay-detail-header {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 16px;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.pay-detail-title {
  font-size: 18px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
  letter-spacing: -0.02em;
}

.pay-detail-type-chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-chrome-text);
  background: var(--tf-neutral-canvas);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
}

.pay-detail-meta {
  margin-top: 4px;
  font-size: 13px;
  color: var(--tf-neutral-muted);
}

.pay-detail-meta-dot {
  margin: 0 6px;
  opacity: 0.6;
}

.pay-detail-header__actions {
  flex-shrink: 0;
}

.pay-detail-hint {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin: 12px 16px 0;
  padding: 10px 12px;
  font-size: 13px;
  line-height: 1.45;
  border-radius: var(--tf-radius-sm, 8px);
  border: 1px solid var(--tf-neutral-border);
}

.pay-detail-hint--info {
  background: var(--tf-progress-soft, var(--tf-neutral-canvas));
  color: var(--tf-neutral-ink);
}

.pay-detail-hint--blocked {
  background: var(--tf-attention-soft);
  color: var(--tf-neutral-ink);
}

.pay-detail-hint__icon {
  flex-shrink: 0;
  margin-top: 1px;
  opacity: 0.85;
}

.pay-detail-amount {
  padding: 16px;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.pay-detail-amount__primary {
  font-size: 22px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
  line-height: 1.2;
}

.pay-detail-amount__fx {
  margin-top: 6px;
  font-size: 15px;
  font-weight: 500;
  color: var(--tf-neutral-ink);
}

.pay-detail-amount__rate {
  font-size: 13px;
  font-weight: 400;
  color: var(--tf-neutral-muted);
}

.pay-detail-leftover {
  margin-top: 10px;
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-chrome-text);
}

.pay-detail-meta-grid {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 4px 16px;
  margin: 0;
  padding: 12px 16px;
  border-bottom: 1px solid var(--tf-neutral-border);
  font-size: 13px;
}

.pay-detail-meta-grid dt {
  margin: 0;
  color: var(--tf-neutral-muted);
  font-weight: 500;
}

.pay-detail-meta-grid dd {
  margin: 0;
  color: var(--tf-neutral-ink);
}

.pay-detail-section {
  padding: 16px;
  border-bottom: 1px solid var(--tf-neutral-border);

  &:last-child {
    border-bottom: none;
  }
}

.pay-detail-section__label {
  margin-bottom: 8px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-chrome-text);
}

.pay-detail-table {
  background: var(--tf-neutral-surface);

  :deep(thead tr th) {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--tf-neutral-chrome-text);
    background: var(--tf-neutral-canvas);
  }
}

.pay-detail-table__sub {
  font-size: 12px;
  color: var(--tf-neutral-muted);
}

.pay-detail-table__muted {
  font-size: 12px;
  color: var(--tf-neutral-muted);
}

.pay-detail-alloc-list {
  background: var(--tf-neutral-surface);
}
</style>
