<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Cashbook" @click="goBack" />
    </div>

    <div v-if="detailQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="detailQuery.isError.value" class="col flex flex-center text-negative">
      {{ detailError }}
    </div>

    <div v-else class="col column no-wrap overflow-hidden q-gutter-y-sm">
      <div class="cashbook-header q-pa-md">
        <div class="text-h6 text-weight-bold">{{ detail?.name }}</div>
        <div v-if="detail?.caption" class="text-caption text-grey-7">{{ detail.caption }}</div>
        <div class="row q-gutter-md q-mt-sm text-body2">
          <span>Available <strong>{{ formatAmountBdt(detail?.available_balance ?? 0) }}</strong></span>
          <span>Pending {{ formatAmountBdt(detail?.pending_balance ?? 0) }}</span>
          <span>Locked {{ formatAmountBdt(detail?.locked_balance ?? 0) }}</span>
        </div>
        <div v-if="entityType === 'customer' && entityId" class="q-mt-sm">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-hand-coins"
            label="Pay in (collect)"
            @click="goCollect"
          />
        </div>
      </div>

      <q-input
        v-model="searchText"
        outlined
        dense
        class="q-px-sm shrink-0"
        placeholder="Search ledger…"
        @update:model-value="onSearch"
      />

      <div class="col overflow-auto invoice-list-card">
        <q-markup-table flat dense class="full-width">
          <thead>
            <tr>
              <th class="text-left">Date</th>
              <th class="text-left">Type</th>
              <th class="text-right">Amount</th>
              <th class="text-right">Balance</th>
              <th class="text-left">Source</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="line in ledgerRows" :key="line.id">
              <td>{{ formatDate(line.created_at) }}</td>
              <td>
                <span>{{ line.type }}</span>
                <q-badge v-if="line.is_reversal" dense color="orange-2" text-color="orange-9" label="Reversal" class="q-ml-xs" />
              </td>
              <td class="text-right">{{ formatAmountBdt(line.amount) }}</td>
              <td class="text-right">{{ line.balance_after == null ? '—' : formatAmountBdt(line.balance_after) }}</td>
              <td class="text-caption">{{ line.source_type || '—' }}</td>
            </tr>
          </tbody>
        </q-markup-table>
        <div v-if="!ledgerRows.length && !ledgerQuery.isPending.value" class="q-pa-lg text-center text-grey-7">
          No ledger entries.
        </div>
        <div v-if="hasMoreLedger" class="row justify-center q-py-sm">
          <q-btn flat dense no-caps label="Load more" icon="ph ph-arrow-down" @click="ledgerOffset += LEDGER_PAGE" />
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { useCashbookPartyQuery } from '../composables/useCashbookPartyQuery';
import type { CashbookLedgerRow } from '../repositories/cashbookRepository';

const LEDGER_PAGE = 50;
const ALLOWED_TYPES = new Set(['tenant', 'customer', 'courier', 'vendor']);

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const searchText = ref('');
const debouncedSearch = ref('');
const ledgerOffset = ref(0);
const accumulatedLedger = ref<CashbookLedgerRow[]>([]);

const operatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);

const entityType = computed(() => {
  const raw = route.params.entityType;
  const t = typeof raw === 'string' ? raw : '';
  return ALLOWED_TYPES.has(t) ? t : 'customer';
});

const entityId = computed(() => {
  const raw = route.params.entityId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : 0;
});

const partyParams = computed(() => ({
  tenantId: operatingTenantId.value,
  entityType: entityType.value,
  entityId: entityId.value,
  search: debouncedSearch.value || undefined,
  ledgerOffset: ledgerOffset.value,
  ledgerLimit: LEDGER_PAGE,
}));

const { detailQuery, ledgerQuery } = useCashbookPartyQuery(partyParams);

const detail = computed(() => detailQuery.data.value);
const detailError = computed(() => {
  const err = detailQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load party.';
});

watch(
  () => ledgerQuery.data.value,
  (rows) => {
    const list = rows ?? [];
    if (ledgerOffset.value === 0) accumulatedLedger.value = list;
    else {
      const ids = new Set(accumulatedLedger.value.map((r) => r.id));
      accumulatedLedger.value = [...accumulatedLedger.value, ...list.filter((r) => !ids.has(r.id))];
    }
  },
);

watch(debouncedSearch, () => {
  ledgerOffset.value = 0;
  accumulatedLedger.value = [];
});

const ledgerRows = computed(() => accumulatedLedger.value);
const hasMoreLedger = computed(() => (ledgerQuery.data.value?.length ?? 0) >= LEDGER_PAGE);

let searchTimer: ReturnType<typeof setTimeout> | null = null;
const onSearch = (value: string | number | null) => {
  const v = String(value ?? '');
  searchText.value = v;
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    debouncedSearch.value = v.trim();
  }, 300);
};

const formatDate = (iso: string) => {
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
};

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({ name: 'app-cashbook-page', params: tenantSlug ? { tenantSlug } : {} });
};

const goCollect = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-collect-pay-page',
    params: tenantSlug ? { tenantSlug } : {},
    query: { billingProfileId: String(entityId.value) },
  });
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.cashbook-header {
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: 8px;
  max-width: 960px;
  margin: 0 auto;
  width: 100%;
}
.invoice-list-card {
  max-width: 960px;
  margin: 0 auto;
  width: 100%;
}
</style>
