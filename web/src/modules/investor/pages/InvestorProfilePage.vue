<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Tenant</div>
          <h1 class="text-h5 q-my-none">Investor Profile</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage investor profiles for this tenant.
          </p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" icon="add" label="Add Investor" unelevated @click="onClickAddInvestor" />
        </div>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Investor Profiles</div>
        </q-card-section>

        <q-card-section v-if="loadingInvestors" class="text-grey-7">
          Loading investor profiles...
        </q-card-section>
        <q-card-section v-else-if="investors.length === 0" class="text-grey-7">
          No investor profiles found.
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="investors"
          :columns="columns"
          :pagination="{ rowsPerPage: 0 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-available_balance="props">
            <q-td :props="props" class="text-right">
              {{ formatAmount(getAvailableBalance(props.row.id)) }}
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
    </section>

    <InvestorProfileDialog
      v-model="openDialog"
      :tenant-id="resolvedTenantId"
      :initial-data="selectedInvestor"
      @save="handleSaveInvestor"
    />

    <q-dialog v-model="openDeleteDialog" persistent>
      <q-card style="min-width: 350px">
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

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import InvestorProfileDialog from '../components/InvestorProfileDialog.vue'
import { useInvestorStore } from '../stores/investorStore'
import type { Investor, InvestorCreateInput, InvestorDeleteInput, InvestorUpdateInput } from '../types'

const authStore = useAuthStore()
const investorStore = useInvestorStore()
const { investors, balancesByInvestorId, loadingInvestors, error } = storeToRefs(investorStore)

const openDialog = ref(false)
const openDeleteDialog = ref(false)
const selectedInvestor = ref<Investor | null>(null)
const investorToDelete = ref<Investor | null>(null)

const resolvedTenantId = computed(() => authStore.tenantId ?? 0)
const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'email', label: 'Email', field: 'email', align: 'left' },
  { name: 'address', label: 'Address', field: 'address', align: 'left' },
  { name: 'available_balance', label: 'Available Balance', field: 'id', align: 'right' },
  { name: 'actions', label: 'Actions', field: 'id', align: 'right' },
]

const refresh = async () => {
  if (!resolvedTenantId.value) {
    return
  }

  await investorStore.fetchInvestorsByTenant(resolvedTenantId.value)
}

const onClickAddInvestor = () => {
  selectedInvestor.value = null
  openDialog.value = true
}

const onClickEditInvestor = (investor: Investor) => {
  selectedInvestor.value = { ...investor }
  openDialog.value = true
}

const onClickDeleteInvestor = (investor: Investor) => {
  investorToDelete.value = investor
  openDeleteDialog.value = true
}

const getAvailableBalance = (investorId: number) =>
  Number(balancesByInvestorId.value[investorId]?.available_balance ?? 0)

const formatAmount = (value: number) => value.toFixed(2)

const handleSaveInvestor = async (payload: InvestorCreateInput & { id?: number }) => {
  if (typeof payload.id === 'number') {
    const updatePayload: InvestorUpdateInput = {
      id: payload.id,
      tenant_id: payload.tenant_id,
      name: payload.name,
      phone: payload.phone ?? null,
      email: payload.email ?? null,
      address: payload.address ?? null,
    }

    await investorStore.updateInvestor(updatePayload)
    return
  }

  const createPayload: InvestorCreateInput = {
    tenant_id: payload.tenant_id,
    name: payload.name,
    phone: payload.phone ?? null,
    email: payload.email ?? null,
    address: payload.address ?? null,
  }

  await investorStore.createInvestor(createPayload)
}

const confirmDeleteInvestor = async () => {
  if (!investorToDelete.value) {
    return
  }

  const payload: InvestorDeleteInput = {
    id: investorToDelete.value.id,
    tenant_id: resolvedTenantId.value,
  }

  await investorStore.deleteInvestor(payload)
  investorToDelete.value = null
  openDeleteDialog.value = false
}

onMounted(() => {
  void refresh()
})
</script>
