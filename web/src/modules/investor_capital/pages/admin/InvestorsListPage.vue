<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-banner v-if="error" class="bw-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ error }}
      </q-banner>

      <q-card flat bordered class="q-pa-xs flex-shrink-0 list-toolbar-card">
        <div class="row items-center justify-between q-col-gutter-xs">
          <div class="col-12 col-md-grow row items-center q-gutter-x-xs">
            <q-input
              v-model="searchText"
              outlined
              dense
              debounce="300"
              clearable
              style="min-width: 220px"
              class="col-grow col-sm-auto dense-search-input"
              placeholder="Search investors..."
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" class="text-slate-400" />
              </template>
            </q-input>
            <span v-if="!loadingInvestors" class="text-caption text-grey-7">
              {{ filteredInvestors.length }} investor{{ filteredInvestors.length === 1 ? '' : 's' }}
            </span>
          </div>
          <div class="col-auto">
            <q-btn
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Add investor"
              style="border-radius: 8px"
              @click="onClickAddInvestor"
            />
          </div>
        </div>
      </q-card>

      <div class="col overflow-auto bg-surface">
        <div v-if="loadingInvestors" class="text-grey-7 q-pa-md">Loading investors...</div>

        <div
          v-else-if="filteredInvestors.length === 0"
          class="flex flex-center text-grey-7 text-body2 q-pa-xl full-height"
        >
          {{ searchText ? 'No investors match your search.' : 'No investors yet. Add one to get started.' }}
        </div>

        <q-markup-table v-else flat class="sticky-header-table full-width">
          <thead>
            <tr>
              <th class="text-left" style="width: 56px">#</th>
              <th class="text-left">Name</th>
              <th class="text-left">Phone</th>
              <th class="text-left">Email</th>
              <th class="text-left">Status</th>
              <th class="text-right">Available</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(row, index) in filteredInvestors"
              :key="row.investor_id"
              class="cursor-pointer"
              @click="goToInvestorDetail(row)"
            >
              <td class="text-grey-7">{{ index + 1 }}</td>
              <td class="text-weight-medium">{{ row.name }}</td>
              <td>{{ row.phone || '—' }}</td>
              <td>{{ row.email || '—' }}</td>
              <td>
                <q-chip
                  dense
                  square
                  :color="row.is_active ? 'green-1' : 'grey-2'"
                  :text-color="row.is_active ? 'green-9' : 'grey-7'"
                  class="text-weight-bold text-xs"
                >
                  {{ row.is_active ? 'Active' : 'Inactive' }}
                </q-chip>
              </td>
              <td class="text-right text-weight-bold text-primary">
                {{ formatAmount(row.available_balance) }}
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>
    </div>

    <InvestorProfileDialog
      v-model="openDialog"
      :tenant-id="resolvedTenantId"
      :initial-data="selectedInvestor"
      @save="handleSaveInvestor"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import InvestorProfileDialog from '../../components/InvestorProfileDialog.vue';
import { useInvestorCapitalStore } from 'src/modules/investor_capital/stores/investorCapitalStore';
import type {
  Investor,
  InvestorBalance,
  InvestorCreateInput,
  InvestorUpdateInput,
} from 'src/modules/investor_capital/types';
import { formatAmountBdt } from 'src/utils/currency';

const authStore = useAuthStore();
const router = useRouter();
const capitalStore = useInvestorCapitalStore();
const { investors, loadingInvestors, error } = storeToRefs(capitalStore);

const searchText = ref('');
const openDialog = ref(false);
const selectedInvestor = ref<Investor | null>(null);

const resolvedTenantId = computed(() => authStore.tenantId ?? 0);

const filteredInvestors = computed(() => {
  const query = searchText.value.trim().toLowerCase();
  if (!query) {
    return investors.value;
  }

  return investors.value.filter((row) => {
    const haystack = [
      row.name,
      row.phone,
      row.email,
      row.address,
      row.notes,
      String(row.investor_id),
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();

    return haystack.includes(query);
  });
});

const refresh = async () => {
  if (!resolvedTenantId.value) return;
  await capitalStore.fetchInvestorsByTenant(resolvedTenantId.value);
};

watch(
  resolvedTenantId,
  (tenantId) => {
    if (tenantId > 0) {
      void refresh();
    }
  },
  { immediate: true },
);

const onClickAddInvestor = () => {
  selectedInvestor.value = null;
  openDialog.value = true;
};

const goToInvestorDetail = (row: InvestorBalance) => {
  void router.push({
    name: 'app-capital-investor-general',
    params: {
      tenantSlug: authStore.tenantSlug || undefined,
      id: String(row.investor_id),
    },
  });
};

const formatAmount = (value: number) => formatAmountBdt(value);

const handleSaveInvestor = async (payload: InvestorCreateInput & { id?: number }) => {
  if (typeof payload.id === 'number') {
    const updatePayload: InvestorUpdateInput = {
      id: payload.id,
      tenant_id: payload.tenant_id,
      name: payload.name,
      phone: payload.phone ?? null,
      email: payload.email ?? null,
      address: payload.address ?? null,
      is_active: payload.is_active ?? true,
      currency_code: payload.currency_code || 'BDT',
      notes: payload.notes ?? null,
    };

    await capitalStore.updateInvestor(updatePayload);
    return;
  }

  const createPayload: InvestorCreateInput = {
    tenant_id: payload.tenant_id,
    name: payload.name,
    phone: payload.phone ?? null,
    email: payload.email ?? null,
    address: payload.address ?? null,
    is_active: payload.is_active ?? true,
    currency_code: payload.currency_code || 'BDT',
    notes: payload.notes ?? null,
  };

  await capitalStore.createInvestor(createPayload);
};
</script>
