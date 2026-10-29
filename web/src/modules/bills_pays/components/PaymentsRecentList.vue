<template>
  <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden invoice-list-stack">
    <ProcurementOpsListToolbar
      :search="searchText"
      search-placeholder="Pay #, reference, note…"
      :show-filters="false"
      search-on-enter
      @update:search="onSearchApply"
    >
      <template #pills>
        <TfDrawerSectionTabs
          v-model="sideTab"
          :tabs="sideTabs"
          aria-label="Payment direction"
          @update:model-value="onSideTabChange"
        />
      </template>
    </ProcurementOpsListToolbar>

    <div v-if="listError" class="tf-status-banner bg-negative text-white q-pa-sm rounded-borders">
      {{ listError }}
    </div>

    <div v-if="isPending && !rows.length" class="invoice-list-card col">
      <div class="invoice-list-scroll">
        <div v-for="n in 6" :key="n" class="invoice-list-item invoice-list-item--skeleton">
          <q-skeleton type="text" width="60%" />
        </div>
      </div>
    </div>

    <div
      v-else-if="!rows.length"
      class="column items-center justify-center q-pa-xl text-grey-6 col invoice-list-card"
    >
      <q-icon name="ph ph-receipt" size="48px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-bold">No payments</div>
    </div>

    <div v-else class="invoice-list-card payments-list-card col overflow-hidden">
      <div class="invoice-list-scroll">
        <PayListRow v-for="row in rows" :key="row.id" :row="row" @open="onOpenPay" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ProcurementOpsListToolbar from 'src/modules/procurement_stock/components/ProcurementOpsListToolbar.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import PayListRow from './PayListRow.vue';
import { paysRepository, type PayListRow as PayRow } from '../repositories/paysRepository';
import type { PaymentsListSide } from '../utils/paymentsNavigation';

const emit = defineEmits<{ openPay: [id: number] }>();

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

type SideTab = PaymentsListSide;

const searchText = ref('');
const sideTab = ref<SideTab>('in');
const rows = ref<PayRow[]>([]);
const isPending = ref(false);
const listError = ref<string | null>(null);

const sideTabs = [
  { name: 'in' as const, label: 'Receive' },
  { name: 'out' as const, label: 'Pay out' },
];

const operatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});

const onSearchApply = (value: string | null | undefined) => {
  searchText.value = (value ?? '').trim();
};

const onSideTabChange = (value: string | number) => {
  sideTab.value = value === 'out' ? 'out' : 'in';
};

const loadRows = async () => {
  if (!operatingTenantId.value || !booksTenantId.value) return;
  isPending.value = true;
  listError.value = null;
  try {
    const { data } = await paysRepository.listPays({
      tenantId: operatingTenantId.value,
      booksTenantId: booksTenantId.value,
      side: sideTab.value,
      search: searchText.value || undefined,
      page: 1,
      pageSize: 50,
    });
    rows.value = data;
  } catch (e) {
    listError.value = e instanceof Error ? e.message : 'Could not load payments.';
    rows.value = [];
  } finally {
    isPending.value = false;
  }
};

watch([operatingTenantId, booksTenantId, sideTab, searchText], () => {
  void loadRows();
});

onMounted(() => {
  void loadRows();
});

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined,
);

const onOpenPay = (row: PayRow) => {
  emit('openPay', row.id);
  router.push({
    name: 'app-pay-detail-page',
    params: {
      ...(tenantSlug.value ? { tenantSlug: tenantSlug.value } : {}),
      payId: String(row.id),
    },
  });
};
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
.payments-list-card {
  min-height: 0;
}
</style>
