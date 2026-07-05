<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Tenant</div>
          <h1 class="text-h5 q-my-none">Investor Transaction</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage investor transactions for this tenant.
          </p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" icon="add" label="Add Transaction" unelevated @click="onClickAddTransaction" />
        </div>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Investor Transactions</div>
        </q-card-section>

        <q-card-section v-if="loadingTransactions" class="text-grey-7">
          Loading investor transactions...
        </q-card-section>
        <q-card-section v-else-if="transactions.length === 0" class="text-grey-7">
          No investor transactions found.
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="transactions"
          :columns="columns"
          :pagination="{ rowsPerPage: 0 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-investor_id="props">
            <q-td :props="props">
              {{ investorNameById(props.row.investor_id) }}
            </q-td>
          </template>

          <template #body-cell-amount="props">
            <q-td :props="props">{{ formatAmountBdt(props.row.amount) }}</q-td>
          </template>

          <template #body-cell-type="props">
            <q-td :props="props">{{ formatLabel(props.row.type) }}</q-td>
          </template>

          <template #body-cell-method="props">
            <q-td :props="props">{{ formatLabel(props.row.method) }}</q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <InvestorTransactionDialog
      v-model="openDialog"
      :tenant-id="resolvedTenantId"
      :investors="investors"
      @save="handleSaveTransaction"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import type { QTableColumn } from 'quasar'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import InvestorTransactionDialog from '../../components/InvestorTransactionDialog.vue'
import { useInvestorStore } from 'src/modules/investor/stores/investorStore'
import type { InvestorTransactionCreateInput } from 'src/modules/investor/types'
import { formatAmountBdt } from 'src/utils/currency'

const authStore = useAuthStore()
const investorStore = useInvestorStore()
const { investors, transactions, loadingTransactions, error } = storeToRefs(investorStore)

const openDialog = ref(false)
const resolvedTenantId = computed(() => authStore.tenantId ?? 0)

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'date', label: 'Date', field: 'date', align: 'left', sortable: true },
  { name: 'investor_id', label: 'Investor', field: 'investor_id', align: 'left', sortable: true },
  { name: 'type', label: 'Type', field: 'type', align: 'left', sortable: true },
  { name: 'method', label: 'Method', field: 'method', align: 'left', sortable: true },
  { name: 'amount', label: 'Amount', field: 'amount', align: 'right', sortable: true },
  { name: 'note', label: 'Note', field: 'note', align: 'left' },
]

const refresh = async () => {
  if (!resolvedTenantId.value) {
    return
  }

  await Promise.all([
    investorStore.fetchInvestorsByTenant(resolvedTenantId.value),
    investorStore.fetchTransactionsByTenant(resolvedTenantId.value),
  ])
}

const investorNameById = (id: number) => {
  return investors.value.find((item) => item.id === id)?.name ?? `#${id}`
}

const formatLabel = (value: string) =>
  value
    .split('_')
    .map((item) => item.charAt(0).toUpperCase() + item.slice(1))
    .join(' ')

const onClickAddTransaction = () => {
  openDialog.value = true
}

const handleSaveTransaction = async (payload: InvestorTransactionCreateInput) => {
  await investorStore.createTransaction({
    ...payload,
    tenant_id: resolvedTenantId.value,
  })
}

onMounted(() => {
  void refresh()
})
</script>
