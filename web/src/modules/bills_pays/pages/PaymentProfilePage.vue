<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Payments" @click="goBack" />
    </div>

    <div v-if="profileQuery.isPending.value && !profileQuery.data.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="profileQuery.isError.value" class="col flex flex-center text-negative">
      {{ profileError }}
    </div>

    <div v-else class="col column no-wrap overflow-hidden q-gutter-y-sm">
      <div class="profile-header q-pa-md">
        <div class="text-h6 text-weight-bold">{{ partyName }}</div>
        <div class="row q-gutter-md q-mt-sm text-body2">
          <span>They have <strong>{{ formatAmountBdt(available) }}</strong></span>
          <span>They owe <strong>{{ formatAmountBdt(dueTotal) }}</strong></span>
        </div>
        <div class="row q-gutter-sm q-mt-md">
          <q-btn
            unelevated
            dense
            no-caps
            color="primary"
            label="Pay in"
            @click="openPayDialog('in')"
          />
          <q-btn
            outline
            dense
            no-caps
            color="primary"
            label="Pay out"
            @click="openPayDialog('out')"
          />
        </div>
      </div>

      <ProfilePayDialog
        v-model="payDialogOpen"
        :direction="payDirection"
        :entity-type="entityType"
        :party-name="partyName"
        :party-id="entityId"
        :tenant-id="tenantId"
        :books-tenant-id="booksTenantId"
        :tenant-name="tenantName"
        :available="available"
        :due-total="dueTotal"
        @posted="onPayPosted"
      />

      <div class="text-subtitle2 text-weight-medium q-px-xs">Transaction history</div>

      <div
        v-if="!payRows.length && !ledgerRows.length && profileQuery.isFetching.value"
        class="col flex flex-center"
      >
        <q-spinner color="primary" size="28px" />
      </div>

      <div
        v-else-if="!payRows.length && !ledgerRows.length"
        class="col column items-center justify-center text-grey-6 q-pa-lg"
      >
        No transactions yet.
      </div>

      <div v-else class="col overflow-auto invoice-list-card column q-gutter-y-sm q-pa-xs">
        <PayListRow v-for="row in payRows" :key="`pay-${row.id}`" :row="row" @open="openPay" />
        <q-markup-table v-if="ledgerRows.length" flat dense class="full-width">
          <thead>
            <tr>
              <th class="text-left">Date</th>
              <th class="text-left">Type</th>
              <th class="text-right">Amount</th>
              <th class="text-left">Point</th>
              <th class="text-left">Source</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="line in ledgerRows" :key="`ledger-${line.id}`">
              <td class="text-caption">{{ formatCashbookLedgerDate(line.created_at) }}</td>
              <td>
                <span>{{ formatCashbookLedgerType(line.type) }}</span>
                <q-badge
                  v-if="line.is_reversal"
                  dense
                  color="orange-2"
                  text-color="orange-9"
                  label="Reversal"
                  class="q-ml-xs"
                />
              </td>
              <td
                class="text-right"
                :class="{ 'text-negative': isCashbookLedgerDeduction(line.type) }"
              >
                {{ formatAmountBdt(line.amount) }}
              </td>
              <td class="text-caption">{{ line.cashbook_point_name || '—' }}</td>
              <td class="text-caption">
                <CashbookLedgerSourceCell :line="line" @open-pay="openPayById" />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
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
import type { PayListRow as PayRow } from '../repositories/paysRepository';
import PayListRow from '../components/PayListRow.vue';
import CashbookLedgerSourceCell from '../components/CashbookLedgerSourceCell.vue';
import ProfilePayDialog from '../components/ProfilePayDialog.vue';
import { paymentsPageRoute } from '../utils/paymentsNavigation';
import {
  formatCashbookLedgerDate,
  formatCashbookLedgerType,
  isCashbookLedgerDeduction,
} from '../utils/cashbookLedgerDisplay';
import { usePaymentProfileQuery } from '../composables/usePaymentProfileQuery';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';

import type { PayTransferEntityType } from '../types/payTransferParty';

const ALLOWED_TYPES = new Set(['tenant', 'customer', 'courier', 'vendor']);

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const queryClient = useQueryClient();

const payDialogOpen = ref(false);
const payDirection = ref<'in' | 'out'>('in');

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});

const entityType = computed(() => {
  const raw = route.params.entityType;
  const t = typeof raw === 'string' ? raw : '';
  return (ALLOWED_TYPES.has(t) ? t : 'customer') as PayTransferEntityType;
});

const entityId = computed(() => {
  const raw = route.params.entityId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : 0;
});

const profileParams = computed(() => ({
  tenantId: tenantId.value,
  entityType: entityType.value,
  entityId: entityId.value,
  ledgerLimit: 50,
  paysLimit: 50,
}));

const profileQuery = usePaymentProfileQuery(profileParams);

const profileError = computed(() => {
  const err = profileQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load profile.';
});

const partyName = computed(() => profileQuery.data.value?.detail.name ?? '—');
const available = computed(() => profileQuery.data.value?.detail.available_balance ?? 0);
const dueTotal = computed(() => profileQuery.data.value?.dueTotal ?? 0);
const payRows = computed(() => profileQuery.data.value?.pays ?? []);
const ledgerRows = computed(() => profileQuery.data.value?.ledger ?? []);

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined,
);
const tenantName = computed(() => authStore.selectedTenant?.name ?? 'Company');

const routeParams = () => (tenantSlug.value ? { tenantSlug: tenantSlug.value } : {});

const goBack = () => {
  router.push(paymentsPageRoute(tenantSlug.value, 'in'));
};

const openPayDialog = (direction: 'in' | 'out') => {
  payDirection.value = direction;
  payDialogOpen.value = true;
};

const invalidateProfile = () => {
  void queryClient.invalidateQueries({
    queryKey: cashbookQueryKeys.paymentProfile(
      tenantId.value,
      entityType.value,
      entityId.value,
      { ledgerLimit: 50, paysLimit: 50 },
    ),
  });
};

const onPayPosted = () => {
  invalidateProfile();
};

const openPay = (row: PayRow) => {
  openPayById(row.id);
};

const openPayById = (payId: number) => {
  router.push({
    name: 'app-pay-detail-page',
    params: { ...routeParams(), payId: String(payId) },
  });
};

const openPayFromRouteQuery = () => {
  const action = route.query.action;
  if (action === 'pay-in') openPayDialog('in');
  else if (action === 'pay-out') openPayDialog('out');
};

watch(() => route.query.action, () => {
  openPayFromRouteQuery();
}, { immediate: true });
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.profile-header {
  background: var(--tf-neutral-canvas, #f7f4ef);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
}
</style>
