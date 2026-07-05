<template>
  <q-page class="q-pa-md">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold text-black">Global Investors</div>
            <div class="text-caption text-grey-8">Parent-managed investor capital and profiles</div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              icon="add"
              label="Add Investor"
              no-caps
              unelevated
              class="pill-btn slim-btn"
              @click="onClickAddInvestor"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="loadingInvestors && !investors.length" />

    <q-banner v-else-if="error" class="bg-negative text-white q-mb-md" rounded>{{ error }}</q-banner>

    <q-card v-else flat class="floating-surface shadow-1">
      <q-card-section v-if="!investors.length" class="text-grey-7 text-center q-py-xl">
        No investor profiles found.
      </q-card-section>

      <q-table
        v-else
        flat
        row-key="investor_id"
        :rows="investors"
        :columns="columns"
        :pagination="{ rowsPerPage: 20 }"
        :dense="$q.screen.lt.md"
      >
        <template #body-cell-id="props">
          <q-td :props="props">
            #{{ props.row.investor_id }}
          </q-td>
        </template>

        <template #body-cell-available_balance="props">
          <q-td :props="props" class="text-right">
            {{ formatAmount(props.row.available_balance) }}
          </q-td>
        </template>

        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn icon="more_vert" flat round dense>
              <q-menu auto-close>
                <q-list dense style="min-width: 140px">
                  <q-item clickable v-ripple @click="onClickEditInvestor(props.row)">
                    <q-item-section>Edit</q-item-section>
                  </q-item>
                  <q-item clickable v-ripple @click="onClickDeleteInvestor(props.row)">
                    <q-item-section class="text-negative">Delete</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <InvestorProfileDialog
      v-model="openDialog"
      :tenant-id="resolvedTenantId"
      :initial-data="selectedInvestor"
      @save="handleSaveInvestor"
    />

    <q-dialog v-model="openDeleteDialog" persistent>
      <q-card style="min-width: 350px" class="floating-surface shadow-2">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete <strong>{{ investorToDelete?.name }}</strong>?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteInvestor" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import type { QTableColumn } from 'quasar'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import InvestorProfileDialog from 'src/modules/investor_capital/components/InvestorProfileDialog.vue'
import { useInvestorCapitalStore } from 'src/modules/investor_capital/stores/investorCapitalStore'
import type { Investor, InvestorCreateInput, InvestorDeleteInput, InvestorUpdateInput } from 'src/modules/investor_capital/types'
import { formatAmountBdt } from 'src/utils/currency'

const authStore = useAuthStore()
const capitalStore = useInvestorCapitalStore()
const { investors, loadingInvestors, error } = storeToRefs(capitalStore)

const openDialog = ref(false)
const openDeleteDialog = ref(false)
const selectedInvestor = ref<Investor | null>(null)
const investorToDelete = ref<any>(null)

const resolvedTenantId = computed(() => authStore.tenantId ?? 0)

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'investor_id', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'email', label: 'Email', field: 'email', align: 'left' },
  { name: 'available_balance', label: 'Available Balance', field: 'available_balance', align: 'right', sortable: true },
  { name: 'actions', label: 'Actions', field: 'investor_id', align: 'right' },
]

const refresh = async () => {
  if (!resolvedTenantId.value) return
  await capitalStore.fetchInvestorsByTenant(resolvedTenantId.value)
}

const onClickAddInvestor = () => {
  selectedInvestor.value = null
  openDialog.value = true
}

const onClickEditInvestor = (row: any) => {
  selectedInvestor.value = {
    id: row.investor_id,
    tenant_id: resolvedTenantId.value,
    name: row.name,
    phone: row.phone,
    email: row.email,
    address: row.address,
    is_active: row.is_active,
    currency_code: row.currency_code || 'BDT',
    notes: row.notes,
    created_at: '',
    updated_at: '',
  }
  openDialog.value = true
}

const onClickDeleteInvestor = (row: any) => {
  investorToDelete.value = row
  openDeleteDialog.value = true
}

const formatAmount = (value: number) => formatAmountBdt(value)

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
    }
    await capitalStore.updateInvestor(updatePayload)
    return
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
  }
  await capitalStore.createInvestor(createPayload)
}

const confirmDeleteInvestor = async () => {
  if (!investorToDelete.value) return

  const payload: InvestorDeleteInput = {
    id: investorToDelete.value.investor_id,
    tenant_id: resolvedTenantId.value,
  }

  await capitalStore.deleteInvestor(payload)
  investorToDelete.value = null
  openDeleteDialog.value = false
}

onMounted(() => {
  void refresh()
})
</script>
