<template>
  <q-page class="q-pa-md invoice-list-page">
    <PageInitialLoader v-if="invoiceStore.loading" />
    <template v-else>
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold text-black">Invoices</div>
            <div class="text-caption text-grey-8">Manage invoices and customer payment tracking</div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              label="Add Invoice"
              @click="createOpen = true"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div class="row items-center justify-between q-mb-md">
      <div class="row items-center q-gutter-sm toolbar-left">
        <q-btn
          v-if="!showSearchInput"
          flat
          round
          dense
          icon="search"
          aria-label="Show search"
          @click="showSearchInput = true"
        />
        <q-input
          v-else
          v-model="searchText"
          filled
          dense
          clearable
          class="soft-input toolbar-search"
          label="Search Invoices"
          @clear="onSearchChange"
          @keyup.enter="onSearchChange"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
          <template #append>
            <q-btn flat round dense icon="close" aria-label="Hide search" @click="onCloseSearch" />
          </template>
        </q-input>

        <q-btn flat round dense icon="filter_alt" aria-label="Filters" @click="filterDrawerOpen = true">
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>
    </div>

    <div v-if="!filteredInvoices.length && !invoiceStore.loading" class="text-center text-grey-7 q-py-xl">
      No invoices found.
    </div>

    <div v-else class="row q-col-gutter-md">
      <div v-for="row in filteredInvoices" :key="row.id" class="col-12 col-sm-6 col-lg-4">
        <q-card
          flat
          class="full-height cursor-pointer floating-surface shadow-1 card-hover"
          :style="invoiceCardStyle(row)"
          @click="goToDetails(row.id)"
        >
          <q-card-section class="q-pb-xs">
            <div class="row items-start justify-between">
              <div>
                <div class="text-subtitle1 text-weight-bold text-black">{{ row.invoice_no }}</div>
                <div class="text-caption text-black text-weight-medium">
                  {{ billingProfileNameMap[row.billing_profile_id ?? -1] ?? '-' }}
                </div>
              </div>
              <div class="row items-center q-gutter-xs">
                <!-- Premium Dot Status Chip -->
                <q-chip
                  dense
                  square
                  :style="statusChipStyle(row.status)"
                  class="costing-file-status-chip q-px-sm"
                >
                  <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(row.status) }" />
                  <span class="text-capitalize text-weight-bold">{{ row.status.replace('_', ' ') }}</span>
                </q-chip>

                <q-btn flat round dense icon="more_vert" @click.stop>
                  <q-menu auto-close>
                    <q-list dense style="min-width: 140px">
                      <q-item clickable @click="openEdit(row.id)">
                        <q-item-section>Edit</q-item-section>
                      </q-item>
                      <q-item clickable class="text-negative" @click="openDelete(row.id)">
                        <q-item-section>Delete</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </div>
            </div>
          </q-card-section>
          <q-separator class="separator-light" />
          <q-card-section class="q-gutter-xs q-pt-sm">
            <div class="text-caption text-grey-8 text-weight-medium">Date</div>
            <div class="text-body2 text-black text-weight-medium">{{ row.invoice_date }}</div>
            <div class="text-caption text-grey-8 text-weight-medium q-mt-sm">Total</div>
            <div class="text-body1 text-weight-bolder text-black">{{ formatAmountBdt(row.total_amount) }}</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Filter Drawer -->
    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="statusFilter"
        :options="statusFilterOptions"
        label="Status"
        outlined
        dense
        clearable
        emit-value
        map-options
        class="soft-input q-mb-sm"
        @update:model-value="onSearchChange"
      >
        <template #selected-item="scope">
          <span class="text-black text-weight-medium">{{ scope.opt.label }}</span>
        </template>
      </q-select>
      <q-select
        v-model="billingProfileFilter"
        :options="billingProfileOptions"
        label="Billing Profile"
        outlined
        dense
        clearable
        emit-value
        map-options
        class="soft-input q-mb-md"
        @update:model-value="onSearchChange"
      >
        <template #selected-item="scope">
          <span class="text-black text-weight-medium">{{ scope.opt.label }}</span>
        </template>
      </q-select>
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" class="text-black text-weight-bold" @click="onResetFilters" />
      </div>
    </FilterSidebar>

    <q-dialog v-model="createOpen">
      <q-card style="min-width: 420px; max-width: 95vw" class="floating-surface shadow-2 q-pa-sm">
        <q-card-section class="text-h6 text-weight-bold text-black">Create Invoice</q-card-section>

        <q-card-section class="q-gutter-md">
          <q-select
            v-model="form.billingProfileId"
            :options="billingProfileOptions"
            label="Billing Profile"
            outlined
            dense
            emit-value
            map-options
            option-value="value"
            option-label="label"
            class="soft-input"
            :rules="[(value: number | null) => value != null || 'Billing profile is required']"
          />
          <q-input
            v-model="form.name"
            label="Invoice Name"
            outlined
            dense
            class="soft-input"
            :rules="[(value: string) => Boolean(value?.trim()) || 'Name is required']"
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" class="text-black text-weight-bold" v-close-popup />
          <q-btn
            color="primary"
            class="pill-btn slim-btn"
            no-caps
            label="Create"
            :loading="invoiceStore.saving"
            :disable="!canSubmit"
            @click="onCreateInvoice"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="editOpen">
      <q-card style="min-width: 420px; max-width: 95vw" class="floating-surface shadow-2 q-pa-sm">
        <q-card-section class="text-h6 text-weight-bold text-black">Edit Invoice</q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="editForm.name" label="Invoice Name" outlined dense class="soft-input" />
          <q-select
            v-model="editForm.billingProfileId"
            :options="billingProfileOptions"
            label="Billing Profile"
            outlined
            dense
            emit-value
            map-options
            option-value="value"
            option-label="label"
            class="soft-input"
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" class="text-black text-weight-bold" v-close-popup />
          <q-btn
            color="primary"
            class="pill-btn slim-btn"
            no-caps
            label="Update"
            :loading="invoiceStore.saving"
            :disable="!canSubmitEdit"
            @click="onEditInvoice"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteOpen">
      <q-card style="min-width: 320px" class="floating-surface shadow-2 q-pa-sm">
        <q-card-section class="text-h6 text-weight-bold text-black">Delete Invoice</q-card-section>
        <q-card-section class="text-black text-weight-medium">Are you sure you want to delete this invoice?</q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" class="text-black text-weight-bold" v-close-popup />
          <q-btn
            color="negative"
            class="pill-btn slim-btn"
            no-caps
            label="Delete"
            :loading="invoiceStore.saving"
            @click="onDeleteInvoice"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useBillingProfileStore } from '../stores/billingProfileStore'
import { useInvoiceStore } from '../stores/invoiceStore'
import type { Invoice } from '../types/index'
import { formatAmountBdt } from 'src/utils/currency'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const router = useRouter()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const billingProfileStore = useBillingProfileStore()

const createOpen = ref(false)
const editOpen = ref(false)
const deleteOpen = ref(false)
const selectedInvoiceId = ref<number | null>(null)
const lastAutoFilledInvoiceName = ref('')
const lastAutoFilledEditInvoiceName = ref('')

const showSearchInput = ref(false)
const filterDrawerOpen = ref(false)
const searchText = ref('')
const statusFilter = ref<string | null>(null)
const billingProfileFilter = ref<number | null>(null)

const form = reactive({
  name: '',
  billingProfileId: null as number | null,
})
const editForm = reactive({
  name: '',
  billingProfileId: null as number | null,
})

const statusFilterOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'Issued', value: 'issued' },
  { label: 'Partially Paid', value: 'partially_paid' },
  { label: 'Paid', value: 'paid' },
  { label: 'Overdue', value: 'overdue' },
  { label: 'Cancelled', value: 'cancelled' },
]

const billingProfileOptions = computed(() =>
  billingProfileStore.items.map((profile) => ({
    label: profile.name,
    value: profile.id,
  })),
)

const billingProfileNameMap = computed<Record<number, string>>(() =>
  billingProfileStore.items.reduce<Record<number, string>>((acc, profile) => {
    acc[profile.id] = profile.name
    return acc
  }, {}),
)

const getCurrentMonthYearLabel = () =>
  new Intl.DateTimeFormat('en-US', {
    month: 'long',
    year: 'numeric',
  }).format(new Date())

const buildDefaultInvoiceName = (billingProfileId: number | null) => {
  if (billingProfileId == null) return ''
  const billingProfileName = billingProfileNameMap.value[billingProfileId]?.trim()
  if (!billingProfileName) return ''
  return `Invoice - ${billingProfileName} - ${getCurrentMonthYearLabel()}`
}

const activeFilterCount = computed(() => {
  let count = 0
  if (statusFilter.value) count += 1
  if (billingProfileFilter.value) count += 1
  return count
})

const filteredInvoices = computed(() => {
  const search = searchText.value.trim().toLowerCase()
  const status = statusFilter.value
  const bp = billingProfileFilter.value

  return invoiceStore.invoices.filter((row) => {
    const matchesSearch =
      !search ||
      row.invoice_no.toLowerCase().includes(search) ||
      (row.note ?? '').toLowerCase().includes(search) ||
      (billingProfileNameMap.value[row.billing_profile_id ?? -1] ?? '')
        .toLowerCase()
        .includes(search)

    const matchesStatus = !status || row.status === status
    const matchesBp = !bp || row.billing_profile_id === bp

    return matchesSearch && matchesStatus && matchesBp
  })
})

const canSubmit = computed(
  () => Boolean(authStore.tenantId) && Boolean(form.name.trim()) && form.billingProfileId != null,
)
const canSubmitEdit = computed(
  () => Boolean(editForm.name.trim()) && editForm.billingProfileId != null && selectedInvoiceId.value != null,
)

const load = async () => {
  if (!authStore.tenantId) return

  await Promise.all([
    billingProfileStore.fetchBillingProfiles({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 100,
      sortBy: 'name',
      sortOrder: 'asc',
    }),
    invoiceStore.fetchInvoices({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 100,
      sortBy: 'created_at',
      sortOrder: 'desc',
    }),
  ])
}

const resetForm = () => {
  form.name = ''
  form.billingProfileId = null
  lastAutoFilledInvoiceName.value = ''
}
const resetEditForm = () => {
  editForm.name = ''
  editForm.billingProfileId = null
  lastAutoFilledEditInvoiceName.value = ''
}

const goToDetails = async (invoiceId: number) => {
  await router.push({ name: 'app-invoice-details-page', params: { tenantSlug: authStore.tenantSlug ?? undefined, invoiceId } })
}

const openEdit = (invoiceId: number) => {
  const row = invoiceStore.invoices.find((invoice) => invoice.id === invoiceId)
  if (!row) return
  selectedInvoiceId.value = row.id
  editForm.name = row.invoice_no
  editForm.billingProfileId = row.billing_profile_id
  lastAutoFilledEditInvoiceName.value = row.invoice_no
  editOpen.value = true
}

const openDelete = (invoiceId: number) => {
  selectedInvoiceId.value = invoiceId
  deleteOpen.value = true
}

const onCreateInvoice = async () => {
  if (!authStore.tenantId || !canSubmit.value) return

  const selectedBillingProfile = billingProfileStore.items.find(
    (profile) => profile.id === form.billingProfileId,
  )

  const result = await invoiceStore.createInvoice({
    tenant_id: authStore.tenantId,
    invoice_no: form.name.trim(),
    billing_profile_id: form.billingProfileId,
    customer_group_id: selectedBillingProfile?.customer_group_id ?? null,
    source_type: 'order',
    source_id: 0,
    payment_status: 'due',
    status: 'draft',
    subtotal_amount: 0,
    discount_amount: 0,
    total_amount: 0,
    paid_amount: 0,
  })

  if (result.success) {
    createOpen.value = false
    resetForm()
  }
}

const onEditInvoice = async () => {
  if (!selectedInvoiceId.value || !canSubmitEdit.value) return

  const selectedBillingProfile = billingProfileStore.items.find(
    (profile) => profile.id === editForm.billingProfileId,
  )

  const result = await invoiceStore.updateInvoice({
    id: selectedInvoiceId.value,
    patch: {
      invoice_no: editForm.name.trim(),
      billing_profile_id: editForm.billingProfileId,
      customer_group_id: selectedBillingProfile?.customer_group_id ?? null,
    },
  })

  if (result.success) {
    editOpen.value = false
    selectedInvoiceId.value = null
    resetEditForm()
  }
}

const onDeleteInvoice = async () => {
  if (!selectedInvoiceId.value) return
  const result = await invoiceStore.deleteInvoice(selectedInvoiceId.value)
  if (result.success) {
    deleteOpen.value = false
    selectedInvoiceId.value = null
  }
}

const onSearchChange = () => {
  // client side filter
}

const onCloseSearch = () => {
  showSearchInput.value = false
  searchText.value = ''
}

const onResetFilters = () => {
  statusFilter.value = null
  billingProfileFilter.value = null
}

const invoiceCardStyle = (invoice: Invoice) => {
  const billingProfile = billingProfileStore.items.find(
    (p) => p.id === invoice.billing_profile_id,
  )
  const color = billingProfile?.color
  if (color) {
    return {
      borderLeft: `6px solid ${color}`,
    }
  }
  return {}
}

const statusChipStyle = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase()
  if (value === 'paid') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    }
  }
  if (value === 'partially_paid') {
    return {
      backgroundColor: '#fff3cd',
      color: '#856404',
      border: '1px solid #ffeeba',
    }
  }
  if (value === 'overdue') {
    return {
      backgroundColor: '#f8d7da',
      color: '#721c24',
      border: '1px solid #f5c6cb',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#e2e3e5',
      color: '#383d41',
      border: '1px solid #d6d8db',
    }
  }
  if (value === 'issued') {
    return {
      backgroundColor: '#d1ecf1',
      color: '#0c5460',
      border: '1px solid #bee5eb',
    }
  }
  // draft or fallback
  return {
    backgroundColor: '#e2e3e5',
    color: '#383d41',
    border: '1px solid #d6d8db',
  }
}

const statusDotColor = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase()
  if (value === 'paid') return '#2f8b5d'
  if (value === 'partially_paid') return '#ffc107'
  if (value === 'overdue') return '#dc3545'
  if (value === 'cancelled') return '#6c757d'
  if (value === 'issued') return '#17a2b8'
  return '#6c757d'
}

onMounted(load)

watch(
  () => form.billingProfileId,
  (billingProfileId) => {
    const defaultName = buildDefaultInvoiceName(billingProfileId)
    if (!defaultName) return

    const currentName = form.name.trim()
    if (!currentName || currentName === lastAutoFilledInvoiceName.value) {
      form.name = defaultName
      lastAutoFilledInvoiceName.value = defaultName
    }
  },
)

watch(
  () => editForm.billingProfileId,
  (billingProfileId) => {
    const defaultName = buildDefaultInvoiceName(billingProfileId)
    if (!defaultName) return

    const currentName = editForm.name.trim()
    if (!currentName || currentName === lastAutoFilledEditInvoiceName.value) {
      editForm.name = defaultName
      lastAutoFilledEditInvoiceName.value = defaultName
    }
  },
)

watch(
  () => createOpen.value,
  (open) => {
    if (!open) {
      lastAutoFilledInvoiceName.value = ''
    }
  },
)

watch(
  () => editOpen.value,
  (open) => {
    if (!open) {
      lastAutoFilledEditInvoiceName.value = ''
    }
  },
)

</script>

<style scoped>
.invoice-list-page { background: transparent; }
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
.hero-surface { border-radius: 16px; }
.pill-btn { border-radius: 999px; }
.slim-btn { min-height: 32px; padding-left: 10px; padding-right: 10px; }
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
.toolbar-left { min-width: 0; }
.toolbar-search { width: min(320px, 75vw); }

.costing-file-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
}
.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
.separator-light {
  background: rgba(34, 56, 101, 0.08);
}
.card-hover {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.12) !important;
}
</style>
