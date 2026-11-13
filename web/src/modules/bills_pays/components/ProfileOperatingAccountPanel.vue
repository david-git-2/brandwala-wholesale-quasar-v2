<template>
  <div class="column no-wrap q-gutter-y-sm profile-operating-panel">
    <div v-if="profileQuery.isPending.value && !profileQuery.data.value" class="row justify-center q-py-lg">
      <q-spinner color="primary" size="2em" />
    </div>

    <div v-else-if="profileQuery.isError.value" class="text-center text-negative q-pa-md">
      {{ errorMessage }}
    </div>

    <template v-else-if="bundle">
      <div class="profile-operating-panel__header q-pa-md">
        <div class="text-subtitle1 text-weight-bold">{{ partyName }}</div>
        <div class="row q-gutter-md q-mt-xs text-body2">
          <span v-if="entityType !== 'tenant'">
            Has with us <strong>{{ formatAmountBdt(available) }}</strong>
          </span>
          <span v-else>
            Cash <strong>{{ formatAmountBdt(available) }}</strong>
          </span>
          <span v-if="entityType !== 'tenant' && dueTotal > 0">
            Open due <strong>{{ formatAmountBdt(dueTotal) }}</strong>
          </span>
        </div>
      </div>

      <q-tabs
        v-model="activeKind"
        dense
        class="text-grey-8"
        active-color="primary"
        indicator-color="primary"
        align="left"
      >
        <q-tab name="payments" label="Transactions" />
        <q-tab name="custody" label="Custody" />
        <q-tab name="bills" label="Bills" />
      </q-tabs>

      <q-tab-panels v-model="activeKind" animated class="col overflow-auto">
        <q-tab-panel name="payments" class="q-pa-none">
          <PayListRow
            v-for="row in displayPays"
            :key="`pay-${row.id}`"
            :row="row"
            :perspective="payListPerspective"
            @open="openPay(row)"
          />
          <div v-if="!displayPays.length" class="text-caption text-grey-6 text-center q-py-lg">
            No transactions yet.
          </div>
        </q-tab-panel>
        <q-tab-panel name="custody" class="q-pa-none">
          <q-markup-table v-if="displayLedger.length" flat dense class="full-width">
            <tbody>
              <tr v-for="line in displayLedger" :key="`ledger-${line.id}`">
                <td class="text-caption">{{ formatCashbookLedgerDate(line.created_at) }}</td>
                <td>{{ formatCashbookLedgerType(line.type) }}</td>
                <td
                  class="text-right"
                  :class="{ 'text-negative': isCashbookLedgerDeduction(line.type) }"
                >
                  {{ formatAmountBdt(line.amount) }}
                </td>
              </tr>
            </tbody>
          </q-markup-table>
          <div v-else class="text-caption text-grey-6 text-center q-py-lg">No custody lines yet.</div>
        </q-tab-panel>
        <q-tab-panel name="bills" class="q-pa-none">
          <q-list v-if="billItems.length" bordered separator>
            <q-item
              v-for="bill in billItems"
              :key="`bill-${bill.bill_id}`"
              clickable
              dense
              @click="openBill(bill.bill_id)"
            >
              <q-item-section>
                <q-item-label>{{ bill.invoice_no }}</q-item-label>
                <q-item-label caption>
                  Due {{ formatAmountBdt(Number(bill.open_books ?? 0)) }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
          <div v-else class="text-caption text-grey-6 text-center q-py-lg">No bills.</div>
        </q-tab-panel>
      </q-tab-panels>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { formatAmountBdt } from 'src/utils/currency';
import PayListRow from './PayListRow.vue';
import { usePaymentProfileQuery } from '../composables/usePaymentProfileQuery';
import { useProfileActivityQuery } from '../composables/useProfileActivityQuery';
import type { ProfileActivityKind } from '../repositories/cashbookRepository';
import type { PayListRow as PayRow } from '../repositories/paysRepository';
import type { CashbookLedgerRow } from '../repositories/cashbookRepository';
import {
  formatCashbookLedgerDate,
  formatCashbookLedgerType,
  isCashbookLedgerDeduction,
} from '../utils/cashbookLedgerDisplay';
import type { PayTransferEntityType } from '../types/payTransferParty';

const props = withDefaults(
  defineProps<{
    tenantId: number;
    booksTenantId: number;
    entityType: PayTransferEntityType | 'investor' | 'cargo_company';
    entityId: number;
    partyName?: string;
    tenantName?: string;
    active?: boolean;
    showActions?: boolean;
    tenantSlug?: string;
  }>(),
  {
    partyName: '—',
    tenantName: 'Company',
    active: true,
    showActions: true,
    tenantSlug: undefined,
  },
);

const router = useRouter();
const activeKind = ref<ProfileActivityKind>('payments');

const profileParams = computed(() => ({
  tenantId: props.tenantId,
  entityType: props.entityType,
  entityId: props.entityId,
  ledgerLimit: 50,
  paysLimit: 50,
}));

const profileQuery = usePaymentProfileQuery(profileParams);

const activityParams = computed(() => ({
  tenantId: props.tenantId,
  entityType: props.entityType,
  entityId: props.entityId,
  kind: activeKind.value,
  limit: 50,
}));

const activityEnabled = computed(() => !!props.active && props.entityId > 0);
const activityQuery = useProfileActivityQuery(activityParams, activityEnabled);

const payListPerspective = computed((): 'tenant' | 'party' =>
  props.entityType === 'tenant' ? 'tenant' : 'party',
);

const bundle = computed(() => profileQuery.data.value);
const available = computed(() => bundle.value?.detail.available_balance ?? 0);
const dueTotal = computed(() => bundle.value?.dueTotal ?? 0);

const errorMessage = computed(() => {
  const err = profileQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load operating account.';
});

const displayPays = computed((): PayRow[] => {
  const pages = activityQuery.data.value?.pages ?? [];
  if (activeKind.value === 'payments' && pages.length) {
    return pages.flatMap((p) =>
      (p.items as Record<string, unknown>[]).map((row) => ({
        id: Number(row.id),
        payment_date: String(row.payment_date ?? ''),
        amount: Number(row.amount ?? 0),
        unallocated_amount: Number(row.unallocated_amount ?? 0),
        source: String(row.source ?? ''),
        direction: row.direction === 'out' ? 'out' : row.direction === 'in' ? 'in' : undefined,
        method: (row.method as string | null) ?? null,
        reference: (row.reference as string | null) ?? null,
        note: (row.note as string | null) ?? null,
        voided_at: (row.voided_at as string | null) ?? null,
        profile_id: row.profile_id == null ? null : Number(row.profile_id),
        profile_name: (row.profile_name as string | null) ?? null,
        shop_order_id: row.shop_order_id == null ? null : Number(row.shop_order_id),
        settlement_currency_code: String(row.settlement_currency_code ?? 'BDT'),
        foreign_amount: row.foreign_amount == null ? null : Number(row.foreign_amount),
        exchange_rate: Number(row.exchange_rate ?? 1),
        counterparty_name: (row.counterparty_name as string | null) ?? null,
        cashbook_point_name: (row.cashbook_point_name as string | null) ?? null,
        related_invoice_no: (row.related_invoice_no as string | null) ?? null,
        perspective:
          (row.perspective as 'tenant' | 'party' | undefined) ?? payListPerspective.value,
      })),
    );
  }
  return bundle.value?.pays ?? [];
});

const displayLedger = computed(() => {
  const pages = activityQuery.data.value?.pages ?? [];
  if (!pages.length) return bundle.value?.ledger ?? [];
  return pages.flatMap((p) => (p.items as CashbookLedgerRow[]) ?? []);
});

type BillActivityRow = {
  bill_id: number;
  invoice_no: string;
  open_books: number;
};

const billItems = computed(() => {
  const pages = activityQuery.data.value?.pages ?? [];
  return pages.flatMap((p) => (p.items as BillActivityRow[]) ?? []);
});

watch(activeKind, () => {
  if (activeKind.value !== 'payments') {
    void activityQuery.refetch();
  }
});

const openPay = (row: PayRow) => {
  if (!props.tenantSlug) return;
  router.push({
    name: 'app-pay-detail-page',
    params: { tenantSlug: props.tenantSlug, payId: String(row.id) },
  });
};

const openBill = (billId: number) => {
  if (!props.tenantSlug) return;
  router.push({
    name: 'app-bill-detail-page',
    params: { tenantSlug: props.tenantSlug, billId: String(billId) },
  });
};
</script>

<style scoped lang="scss">
.profile-operating-panel__header {
  background: var(--tf-neutral-canvas, #f7f4ef);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
}
</style>
