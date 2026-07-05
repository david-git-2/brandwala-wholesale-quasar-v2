<template>
  <q-page class="q-pa-md invoice-brands-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Invoice Brands</div>
            <div class="text-caption text-grey-8">Manage company/brand details and addresses used for customizable invoices</div>
          </div>
          <div class="col-auto">
            <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Create Brand" icon="add" @click="openCreateDialog" />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div class="row items-center justify-between q-mb-md">
      <div class="row items-center q-gutter-sm toolbar-left">
        <q-input
          v-model="searchText"
          filled
          dense
          clearable
          class="soft-input toolbar-search"
          placeholder="Search Brand Name or Address"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
        </q-input>
      </div>
    </div>

    <q-card flat class="floating-surface shadow-1">
      <q-markup-table flat wrap-cells class="invoice-brands-table">
        <thead>
          <tr>
            <th class="text-left">Brand Name</th>
            <th class="text-left">Address</th>
            <th class="text-left">Tenant Workspace</th>
            <th class="text-right" style="width: 120px">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="invoiceStore.loading && !invoiceStore.brands.length">
            <td colspan="4" class="text-center text-grey-7 q-py-lg">
              <q-spinner color="primary" size="2em" />
              <div class="q-mt-xs">Loading brands...</div>
            </td>
          </tr>
          <tr v-else-if="!filteredBrands.length">
            <td colspan="4" class="text-center text-grey-7 q-py-xl">No brands found.</td>
          </tr>
          <tr v-for="row in filteredBrands" :key="row.id" v-else>
            <td>
              <div class="text-weight-bold text-black">{{ row.name }}</div>
            </td>
            <td>
              <div style="white-space: pre-wrap;" class="text-grey-9">{{ row.address }}</div>
            </td>
            <td>
              <q-chip dense outline size="sm" color="purple" class="text-weight-medium">
                {{ row.tenants?.name || 'Loading...' }}
              </q-chip>
            </td>
            <td class="text-right">
              <q-btn flat round dense icon="more_vert">
                <q-menu auto-close>
                  <q-list dense style="min-width: 140px">
                    <q-item clickable @click="openEditDialog(row)">
                      <q-item-section>Edit</q-item-section>
                    </q-item>
                    <q-item clickable class="text-negative" @click="openDeleteDialog(row)">
                      <q-item-section>Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>

    <!-- Create/Edit Dialog -->
    <q-dialog v-model="dialogOpen" backdrop-filter="blur(4px)">
      <q-card style="width: 480px; max-width: 90vw;" class="floating-surface shadow-2 q-pa-sm">
        <q-card-section class="row items-center justify-between q-py-sm">
          <div class="text-h6 text-weight-bold text-black">
            {{ isEdit ? 'Edit Invoice Brand' : 'Create Invoice Brand' }}
          </div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator class="q-mx-md" />

        <q-card-section class="q-gutter-md q-pt-md">
          <q-select
            v-model="form.tenant_id"
            :options="tenantOptions"
            option-value="id"
            option-label="name"
            emit-value
            map-options
            label="Tenant Workspace *"
            outlined
            dense
            :rules="[val => !!val || 'Tenant is required']"
            :disable="isEdit"
            class="soft-input"
          />

          <q-input
            v-model="form.name"
            label="Brand Name *"
            outlined
            dense
            :rules="[val => !!val && !!val.trim() || 'Brand Name is required']"
            class="soft-input"
            autofocus
          />

          <q-input
            v-model="form.address"
            label="Address *"
            type="textarea"
            outlined
            dense
            :rules="[val => !!val && !!val.trim() || 'Address is required']"
            class="soft-input"
            rows="4"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            no-caps
            :label="isEdit ? 'Save Changes' : 'Create Brand'"
            :loading="invoiceStore.saving"
            @click="handleSubmit"
            class="pill-btn q-px-md"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Delete Dialog -->
    <q-dialog v-model="deleteOpen">
      <q-card style="min-width: 320px;" class="floating-surface q-pa-sm">
        <q-card-section class="text-h6 text-weight-bold text-black">Delete Brand</q-card-section>
        <q-card-section class="q-py-none">
          Are you sure you want to delete the brand <strong class="text-black">"{{ selectedBrand?.name }}"</strong>? This cannot be undone.
        </q-card-section>
        <q-card-actions align="right" class="q-pt-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="negative" no-caps label="Delete" :loading="invoiceStore.saving" @click="handleDelete" class="pill-btn q-px-md" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvoiceStore } from '../stores/invoiceStore'
import { supabase } from 'src/boot/supabase'
import type { InvoiceBrand } from '../repositories/invoiceRepository'
import { showWarningDialog } from 'src/utils/appFeedback'

const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()

const searchText = ref('')
const dialogOpen = ref(false)
const deleteOpen = ref(false)
const isEdit = ref(false)
const selectedBrand = ref<InvoiceBrand | null>(null)

interface TenantOption {
  id: number
  name: string
  slug: string
}
const tenantOptions = ref<TenantOption[]>([])

const form = ref({
  id: 0,
  tenant_id: 0,
  name: '',
  address: '',
})

const filteredBrands = computed(() => {
  const query = searchText.value.trim().toLowerCase()
  if (!query) return invoiceStore.brands

  return invoiceStore.brands.filter(
    (b) =>
      b.name.toLowerCase().includes(query) ||
      b.address.toLowerCase().includes(query)
  )
})

const loadTenants = async () => {
  try {
    const { data, error } = await supabase.rpc('list_my_admin_tenants')
    if (error) throw error
    tenantOptions.value = (data as TenantOption[]) || []
  } catch (error) {
    console.error('Error loading admin tenants:', error)
  }
}

const loadBrands = async () => {
  await invoiceStore.fetchInvoiceBrands()
}

const openCreateDialog = () => {
  isEdit.value = false
  form.value = {
    id: 0,
    tenant_id: authStore.tenantId ?? 0,
    name: '',
    address: '',
  }
  dialogOpen.value = true
}

const openEditDialog = (brand: InvoiceBrand) => {
  isEdit.value = true
  selectedBrand.value = brand
  form.value = {
    id: brand.id,
    tenant_id: brand.tenant_id,
    name: brand.name,
    address: brand.address,
  }
  dialogOpen.value = true
}

const openDeleteDialog = (brand: InvoiceBrand) => {
  selectedBrand.value = brand
  deleteOpen.value = true
}

const handleSubmit = async () => {
  if (!form.value.name.trim() || !form.value.address.trim()) {
    showWarningDialog('Please fill in all required fields.')
    return
  }

  if (isEdit.value) {
    const res = await invoiceStore.updateInvoiceBrand({
      id: form.value.id,
      patch: {
        name: form.value.name.trim(),
        address: form.value.address.trim(),
      },
    })
    if (res.success) {
      dialogOpen.value = false
      await loadBrands()
    }
  } else {
    const res = await invoiceStore.createInvoiceBrand({
      tenant_id: form.value.tenant_id,
      name: form.value.name.trim(),
      address: form.value.address.trim(),
    })
    if (res.success) {
      dialogOpen.value = false
      await loadBrands()
    }
  }
}

const handleDelete = async () => {
  if (!selectedBrand.value) return
  const res = await invoiceStore.deleteInvoiceBrand({ id: selectedBrand.value.id })
  if (res.success) {
    deleteOpen.value = false
    selectedBrand.value = null
  }
}

onMounted(async () => {
  await Promise.all([loadBrands(), loadTenants()])
})
</script>

<style scoped>
.invoice-brands-page {
  background: transparent;
}
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
.hero-surface {
  border-radius: 16px;
}
.pill-btn {
  border-radius: 999px;
}
.slim-btn {
  min-height: 32px;
  padding-left: 12px;
  padding-right: 12px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
.toolbar-left {
  min-width: 0;
}
.toolbar-search {
  width: min(360px, 85vw);
}
.invoice-brands-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
  font-weight: 700;
  color: #1a253c;
}
</style>
