<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Payments" @click="goBack" />
    </div>

    <div v-if="loadingHeader" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="headerError" class="col flex flex-center text-negative">
      {{ headerError }}
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

      <div v-if="historyError" class="text-negative q-px-sm">{{ historyError }}</div>

      <div v-else-if="historyLoading && !payRows.length && !ledgerRows.length" class="col flex flex-center">
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
              <td class="text-caption">{{ line.source_type || '—' }}</td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import {
  cashbookRepository,
  type CashbookLedgerRow,
} from '../repositories/cashbookRepository';
import { paysRepository, type PayListRow as PayRow } from '../repositories/paysRepository';
import { billsRepository } from '../repositories/billsRepository';
import PayListRow from '../components/PayListRow.vue';
import ProfilePayDialog from '../components/ProfilePayDialog.vue';
import { paymentsPageRoute } from '../utils/paymentsNavigation';
import {
  formatCashbookLedgerDate,
  formatCashbookLedgerType,
  isCashbookLedgerDeduction,
} from '../utils/cashbookLedgerDisplay';

import type { PayTransferEntityType } from '../types/payTransferParty';

const ALLOWED_TYPES = new Set(['tenant', 'customer', 'courier', 'vendor']);

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const loadingHeader = ref(true);
const headerError = ref<string | null>(null);
const partyName = ref('');
const available = ref(0);
const dueTotal = ref(0);
const payRows = ref<PayRow[]>([]);
const ledgerRows = ref<CashbookLedgerRow[]>([]);
const historyLoading = ref(false);
const historyError = ref<string | null>(null);
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

const onPayPosted = () => {
  void loadHeader();
  void loadHistory();
};

const openPay = (row: PayRow) => {
  router.push({
    name: 'app-pay-detail-page',
    params: { ...routeParams(), payId: String(row.id) },
  });
};

const loadHeader = async () => {
  if (!tenantId.value || !entityId.value) return;
  loadingHeader.value = true;
  headerError.value = null;
  try {
    const detail = await cashbookRepository.getPartyDetail(
      tenantId.value,
      entityType.value,
      entityId.value,
    );
    partyName.value = detail.name;
    available.value = detail.available_balance;
    dueTotal.value = 0;
    if (entityType.value !== 'tenant' && booksTenantId.value) {
      const { data } = await billsRepository.listBills({
        parentTenantId: booksTenantId.value,
        profileId: entityId.value,
        invoiceStatus: 'issued',
        quickFilter: 'unpaid',
        pageSize: 100,
      });
      dueTotal.value = data.reduce((sum, bill) => sum + (Number(bill.due_amount) || 0), 0);
    }
  } catch (e) {
    headerError.value = e instanceof Error ? e.message : 'Could not load profile.';
  } finally {
    loadingHeader.value = false;
  }
};

const loadHistory = async () => {
  if (!tenantId.value || !entityId.value) {
    payRows.value = [];
    ledgerRows.value = [];
    return;
  }
  historyLoading.value = true;
  historyError.value = null;
  try {
    const ledgerEntityId =
      entityType.value === 'tenant' ? booksTenantId.value : entityId.value;
    ledgerRows.value = await cashbookRepository.listLedger({
      tenantId: tenantId.value,
      entityType: entityType.value,
      entityId: ledgerEntityId,
      limit: 50,
    });

    if (entityType.value === 'customer') {
      const { data } = await paysRepository.listPays({
        tenantId: tenantId.value,
        booksTenantId: booksTenantId.value,
        profileId: entityId.value,
        page: 1,
        pageSize: 50,
      });
      payRows.value = data;
    } else if (entityType.value === 'vendor' || entityType.value === 'courier') {
      const { data } = await paysRepository.listPays({
        tenantId: tenantId.value,
        booksTenantId: booksTenantId.value,
        profileId: entityId.value,
        side: 'out',
        page: 1,
        pageSize: 50,
      });
      payRows.value = data;
    } else {
      payRows.value = [];
    }
  } catch (e) {
    historyError.value = e instanceof Error ? e.message : 'Could not load history.';
    payRows.value = [];
    ledgerRows.value = [];
  } finally {
    historyLoading.value = false;
  }
};

watch([entityType, entityId], () => {
  void loadHeader();
  void loadHistory();
});

const openPayFromRouteQuery = () => {
  const action = route.query.action;
  if (action === 'pay-in') openPayDialog('in');
  else if (action === 'pay-out') openPayDialog('out');
};

watch(() => route.query.action, () => {
  openPayFromRouteQuery();
});

onMounted(() => {
  void loadHeader();
  void loadHistory();
  openPayFromRouteQuery();
});
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
