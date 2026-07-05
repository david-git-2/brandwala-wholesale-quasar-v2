<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Tenant</div>
          <h1 class="text-h5 q-my-none">Investor Profiles</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage capital partner records, currencies, notes, and login memberships.
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
        <q-card-section v-if="loadingInvestors" class="text-grey-7">
          Loading investor profiles...
        </q-card-section>
        <q-card-section v-else-if="investors.length === 0" class="text-grey-7">
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
            <q-td :props="props" class="text-right text-weight-bold text-primary">
              {{ formatAmount(props.row.available_balance) }}
            </q-td>
          </template>

          <template #body-cell-is_active="props">
            <q-td :props="props">
              <q-chip
                dense
                square
                :color="props.row.is_active ? 'green-1' : 'grey-2'"
                :text-color="props.row.is_active ? 'green-9' : 'grey-7'"
                class="text-weight-bold text-xs"
              >
                {{ props.row.is_active ? 'Active' : 'Inactive' }}
              </q-chip>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn icon="more_vert" flat round dense>
                <q-menu auto-close>
                  <q-list dense style="min-width: 160px">
                    <q-item clickable v-ripple @click="goToMembershipAccess(props.row)">
                      <q-item-section class="text-primary">Manage Portal Login</q-item-section>
                    </q-item>
                    <q-item clickable v-ripple @click="onClickEditInvestor(props.row)">
                      <q-item-section>Edit Profile</q-item-section>
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
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import type { QTableColumn } from 'quasar'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import InvestorProfileDialog from '../../components/InvestorProfileDialog.vue'
import { useInvestorCapitalStore } from 'src/modules/investor_capital/stores/investorCapitalStore'
import type { Investor, InvestorCreateInput, InvestorDeleteInput, InvestorUpdateInput } from 'src/modules/investor_capital/types'
import { formatAmountBdt } from 'src/utils/currency'

const authStore = useAuthStore()
const router = useRouter()
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
  { name: 'address', label: 'Address', field: 'address', align: 'left' },
  { name: 'currency_code', label: 'Currency', field: 'currency_code', align: 'left' },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'left' },
  { name: 'available_balance', label: 'Available Balance', field: 'available_balance', align: 'right', sortable: true },
  { name: 'notes', label: 'Notes', field: 'notes', align: 'left' },
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

const goToMembershipAccess = (row: any) => {
  const slug = authStore.tenantSlug
  void router.push({
    name: 'admin-tenant-investors',
    params: {
      tenantSlug: slug || undefined,
      id: resolvedTenantId.value,
    },
    query: {
      investor_id: String(row.investor_id),
    },
  })
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
