<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5 text-weight-bold">Invoices</div>
      <q-btn color="primary" no-caps label="Add Invoice" @click="createOpen = true" />
    </div>

    <div v-if="!invoiceStore.invoices.length && !invoiceStore.loading" class="text-center text-grey-7 q-py-xl">
      No invoices found.
    </div>

    <div v-else class="row q-col-gutter-md">
      <div v-for="row in invoiceStore.invoices" :key="row.id" class="col-12 col-sm-6 col-lg-4">
        <q-card flat bordered class="full-height cursor-pointer" @click="goToDetails(row.id)">
          <q-card-section>
            <div class="row items-start justify-between">
              <div>
                <div class="text-subtitle1 text-weight-medium">{{ row.invoice_no }}</div>
                <div class="text-caption text-grey-7">
                  {{ billingProfileNameMap[row.billing_profile_id ?? -1] ?? '-' }}
                </div>
              </div>
              <div class="row items-center q-gutter-xs">
                <q-badge color="primary" outline class="text-capitalize">{{ row.status }}</q-badge>
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
          <q-separator />
          <q-card-section class="q-gutter-xs">
            <div class="text-caption text-grey-7">Date</div>
            <div class="text-body2">{{ row.invoice_date }}</div>
            <div class="text-caption text-grey-7 q-mt-sm">Total</div>
            <div class="text-body1 text-weight-bold">{{ row.total_amount }}</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <q-dialog v-model="createOpen">
      <q-card style="min-width: 420px; max-width: 95vw">
        <q-card-section class="text-h6">Create Invoice</q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="form.name"
            label="Name"
            outlined
            dense
            :rules="[(value: string) => Boolean(value?.trim()) || 'Name is required']"
          />
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
            :rules="[(value: number | null) => value != null || 'Billing profile is required']"
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
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
      <q-card style="min-width: 420px; max-width: 95vw">
        <q-card-section class="text-h6">Edit Invoice</q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="editForm.name" label="Name" outlined dense />
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
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
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
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Invoice</q-card-section>
        <q-card-section>Are you sure you want to delete this invoice?</q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            no-caps
            label="Delete"
            :loading="invoiceStore.saving"
            @click="onDeleteInvoice"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useBillingProfileStore } from '../stores/billingProfileStore'
import { useInvoiceStore } from '../stores/invoiceStore'

const router = useRouter()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const billingProfileStore = useBillingProfileStore()

const createOpen = ref(false)
const editOpen = ref(false)
const deleteOpen = ref(false)
const selectedInvoiceId = ref<number | null>(null)
const form = reactive({
  name: '',
  billingProfileId: null as number | null,
})
const editForm = reactive({
  name: '',
  billingProfileId: null as number | null,
})

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
      page_size: 50,
      sortBy: 'created_at',
      sortOrder: 'desc',
    }),
  ])
}

const resetForm = () => {
  form.name = ''
  form.billingProfileId = null
}
const resetEditForm = () => {
  editForm.name = ''
  editForm.billingProfileId = null
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

onMounted(load)
</script>
