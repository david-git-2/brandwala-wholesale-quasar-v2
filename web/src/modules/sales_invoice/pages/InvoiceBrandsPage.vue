<template>
  <q-page class="invoice-brands-page page-fixed-layout q-pa-md">
    <div class="brands-container column no-wrap full-height">
      <!-- 1. Top Unified Toolbar: Zero In-Page Headers, Search & Brand Count (Left), Create Brand (Right) -->
      <div class="brands-toolbar floating-surface shadow-1 q-pa-sm q-mb-md">
        <div class="row items-center justify-between q-col-gutter-sm no-wrap">
          <!-- Left: Outlined Rounded Search Box & Count Badge -->
          <div class="col-auto row items-center q-gutter-sm">
            <q-input
              v-model="searchText"
              outlined
              rounded
              dense
              placeholder="Search brand name or address..."
              class="search-box"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-6" />
              </template>
              <template #append v-if="searchText">
                <q-icon
                  name="ph ph-x-circle"
                  size="16px"
                  class="cursor-pointer text-grey-5"
                  @click="searchText = ''"
                />
              </template>
            </q-input>

            <q-chip dense square color="grey-2" text-color="grey-8" class="text-weight-bold text-caption q-ma-none">
              {{ brands.length }} {{ brands.length === 1 ? 'Brand' : 'Brands' }}
            </q-chip>
          </div>

          <!-- Right: Refresh & Primary Create Brand Action Button -->
          <div class="col-auto row items-center q-gutter-sm">
            <q-btn
              flat
              round
              dense
              icon="ph ph-arrow-clockwise"
              color="grey-7"
              :loading="brandsQuery.isFetching.value"
              @click="brandsQuery.refetch()"
            >
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>

            <q-btn
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Create Brand"
              no-caps
              class="action-btn text-weight-bold"
              @click="openCreateDialog"
            />
          </div>
        </div>
      </div>

      <!-- 2. Brands Table Wrapper with Internal Scroll -->
      <div class="col treasury-table-wrap floating-surface shadow-1">
        <q-markup-table flat wrap-cells class="invoice-brands-table full-height">
          <thead>
            <tr>
              <th class="text-left" style="width: 280px">Brand Name</th>
              <th class="text-left">Address</th>
              <th class="text-left" style="width: 220px">Tenant Workspace</th>
              <th class="text-right" style="width: 100px">Actions</th>
            </tr>
          </thead>
          <tbody>
            <!-- Loading State -->
            <tr v-if="brandsQuery.isLoading.value && !brands.length">
              <td colspan="4" class="text-center text-grey-7 q-py-xl">
                <q-spinner color="primary" size="2.5em" />
                <div class="q-mt-sm text-caption text-grey-6">Loading invoice brands...</div>
              </td>
            </tr>

            <!-- Empty State -->
            <tr v-else-if="!filteredBrands.length">
              <td colspan="4" class="text-center text-grey-6 q-py-xl">
                <q-icon name="ph ph-paint-brush" size="48px" class="text-grey-4 q-mb-xs" />
                <div class="text-subtitle2 text-weight-medium">No invoice brands found</div>
                <div class="text-caption text-grey-5">
                  {{ searchText ? 'Try adjusting your search criteria.' : 'Create your first brand template to customize invoice print headers.' }}
                </div>
              </td>
            </tr>

            <!-- Rows -->
            <tr v-for="row in filteredBrands" :key="row.id" v-else class="brand-row">
              <td>
                <div class="row items-center no-wrap q-gutter-x-sm">
                  <q-avatar size="32px" color="grey-3" text-color="grey-9" class="text-weight-bold">
                    {{ row.name.slice(0, 2).toUpperCase() }}
                  </q-avatar>
                  <div class="text-weight-bold text-grey-9">{{ row.name }}</div>
                </div>
              </td>
              <td>
                <div style="white-space: pre-wrap" class="text-grey-8 text-caption">{{ row.address }}</div>
              </td>
              <td>
                <q-chip dense square color="purple-1" text-color="purple-9" class="text-weight-bold text-xxs q-ma-none">
                  {{ row.tenants?.name || 'Workspace' }}
                </q-chip>
              </td>
              <td class="text-right">
                <q-btn flat round dense icon="ph ph-dots-three-vertical" color="grey-7" size="sm">
                  <q-menu auto-close>
                    <q-list dense style="min-width: 140px">
                      <q-item clickable @click="openEditDialog(row)">
                        <q-item-section avatar min-width="24px">
                          <q-icon name="ph ph-pencil-simple" size="16px" />
                        </q-item-section>
                        <q-item-section>Edit</q-item-section>
                      </q-item>
                      <q-item clickable class="text-negative" @click="openDeleteDialog(row)">
                        <q-item-section avatar min-width="24px">
                          <q-icon name="ph ph-trash" color="negative" size="16px" />
                        </q-item-section>
                        <q-item-section>Delete</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>

      <!-- Create/Edit Dialog -->
      <q-dialog v-model="dialogOpen" backdrop-filter="blur(4px)">
        <q-card style="width: 480px; max-width: 90vw" class="floating-surface shadow-2 q-pa-sm">
          <q-card-section class="row items-center justify-between q-py-sm">
            <div class="text-subtitle1 text-weight-bold text-grey-9">
              {{ isEdit ? 'Edit Invoice Brand' : 'Create Invoice Brand' }}
            </div>
            <q-btn flat round dense icon="ph ph-x" v-close-popup />
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
              :rules="[(val) => !!val || 'Tenant is required']"
              :disable="isEdit"
              class="soft-input"
            />

            <q-input
              v-model="form.name"
              label="Brand Name *"
              outlined
              dense
              :rules="[(val) => (!!val && !!val.trim()) || 'Brand Name is required']"
              class="soft-input"
              autofocus
            />

            <q-input
              v-model="form.address"
              label="Address *"
              type="textarea"
              outlined
              dense
              :rules="[(val) => (!!val && !!val.trim()) || 'Address is required']"
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
              :loading="createMutation.isPending.value || updateMutation.isPending.value"
              @click="handleSubmit"
              class="action-btn q-px-md text-weight-bold"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <!-- Delete Dialog -->
      <q-dialog v-model="deleteOpen">
        <q-card style="min-width: 320px" class="floating-surface q-pa-sm">
          <q-card-section class="text-subtitle1 text-weight-bold text-grey-9">Delete Brand</q-card-section>
          <q-card-section class="q-py-none text-grey-8">
            Are you sure you want to delete the brand
            <strong class="text-grey-9">"{{ selectedBrand?.name }}"</strong>? This cannot be undone.
          </q-card-section>
          <q-card-actions align="right" class="q-pt-md">
            <q-btn flat no-caps label="Cancel" v-close-popup />
            <q-btn
              color="negative"
              no-caps
              label="Delete"
              :loading="deleteMutation.isPending.value"
              @click="handleDelete"
              class="action-btn q-px-md text-weight-bold"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { supabase } from 'src/boot/supabase';
import { invoiceRepository, type InvoiceBrand } from '../repositories/invoiceRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import { showWarningDialog, showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const tenantStore = useTenantStore();
const queryClient = useQueryClient();

const effectiveTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  if (!current) return authStore.tenantId;
  return current.id;
});

const searchText = ref('');
const dialogOpen = ref(false);
const deleteOpen = ref(false);
const isEdit = ref(false);
const selectedBrand = ref<InvoiceBrand | null>(null);

interface TenantOption {
  id: number;
  name: string;
  slug: string;
}
const tenantOptions = ref<TenantOption[]>([]);

const form = ref({
  id: 0,
  tenant_id: 0,
  name: '',
  address: '',
});

// 1. TanStack Query for Brands
const brandsQuery = useQuery({
  queryKey: computed(() => salesInvoiceQueryKeys.brands(effectiveTenantId.value)),
  queryFn: async () => {
    return invoiceRepository.listInvoiceBrands({
      tenant_id: effectiveTenantId.value ?? undefined,
    });
  },
  enabled: computed(() => !!effectiveTenantId.value),
  placeholderData: (prev) => prev,
});

const brands = computed(() => brandsQuery.data.value ?? []);

const filteredBrands = computed(() => {
  const query = searchText.value.trim().toLowerCase();
  if (!query) return brands.value;

  return brands.value.filter(
    (b) => b.name.toLowerCase().includes(query) || b.address.toLowerCase().includes(query),
  );
});

// 2. TanStack Mutations
const createMutation = useMutation({
  mutationFn: async (payload: { tenant_id: number; name: string; address: string }) => {
    return invoiceRepository.createInvoiceBrand(payload);
  },
  onSuccess: (newBrand) => {
    // Optimistic / Cache-first update
    queryClient.setQueryData(
      salesInvoiceQueryKeys.brands(effectiveTenantId.value),
      (old: any[] = []) => [...old, newBrand],
    );
    void queryClient.invalidateQueries({
      queryKey: salesInvoiceQueryKeys.brands(effectiveTenantId.value),
    });
    dialogOpen.value = false;
    showSuccessNotification('Brand created successfully.');
  },
  onError: (err: any) => {
    showErrorNotification(err?.message || 'Failed to create invoice brand.');
  },
});

const updateMutation = useMutation({
  mutationFn: async (payload: { id: number; name: string; address: string }) => {
    return invoiceRepository.updateInvoiceBrand({
      id: payload.id,
      patch: {
        name: payload.name,
        address: payload.address,
      },
    });
  },
  onSuccess: (updatedBrand) => {
    queryClient.setQueryData(
      salesInvoiceQueryKeys.brands(effectiveTenantId.value),
      (old: any[] = []) => old.map((b) => (b.id === updatedBrand.id ? { ...b, ...updatedBrand } : b)),
    );
    void queryClient.invalidateQueries({
      queryKey: salesInvoiceQueryKeys.brands(effectiveTenantId.value),
    });
    dialogOpen.value = false;
    showSuccessNotification('Brand updated successfully.');
  },
  onError: (err: any) => {
    showErrorNotification(err?.message || 'Failed to update invoice brand.');
  },
});

const deleteMutation = useMutation({
  mutationFn: async (id: number) => {
    return invoiceRepository.deleteInvoiceBrand({ id });
  },
  onSuccess: (_, id) => {
    queryClient.setQueryData(
      salesInvoiceQueryKeys.brands(effectiveTenantId.value),
      (old: any[] = []) => old.filter((b) => b.id !== id),
    );
    void queryClient.invalidateQueries({
      queryKey: salesInvoiceQueryKeys.brands(effectiveTenantId.value),
    });
    deleteOpen.value = false;
    selectedBrand.value = null;
    showSuccessNotification('Brand deleted successfully.');
  },
  onError: (err: any) => {
    showErrorNotification(err?.message || 'Failed to delete invoice brand.');
  },
});

const loadTenants = async () => {
  try {
    const { data, error } = await supabase.rpc('list_my_admin_tenants');
    if (error) throw error;
    tenantOptions.value = (data as TenantOption[]) || [];
  } catch (error) {
    console.error('Error loading admin tenants:', error);
  }
};

const openCreateDialog = () => {
  isEdit.value = false;
  form.value = {
    id: 0,
    tenant_id: effectiveTenantId.value ?? 0,
    name: '',
    address: '',
  };
  dialogOpen.value = true;
};

const openEditDialog = (brand: InvoiceBrand) => {
  isEdit.value = true;
  selectedBrand.value = brand;
  form.value = {
    id: brand.id,
    tenant_id: brand.tenant_id,
    name: brand.name,
    address: brand.address,
  };
  dialogOpen.value = true;
};

const openDeleteDialog = (brand: InvoiceBrand) => {
  selectedBrand.value = brand;
  deleteOpen.value = true;
};

const handleSubmit = async () => {
  if (!form.value.name.trim() || !form.value.address.trim()) {
    showWarningDialog('Please fill in all required fields.');
    return;
  }

  if (isEdit.value) {
    updateMutation.mutate({
      id: form.value.id,
      name: form.value.name.trim(),
      address: form.value.address.trim(),
    });
  } else {
    createMutation.mutate({
      tenant_id: form.value.tenant_id,
      name: form.value.name.trim(),
      address: form.value.address.trim(),
    });
  }
};

const handleDelete = async () => {
  if (!selectedBrand.value) return;
  deleteMutation.mutate(selectedBrand.value.id);
};

onMounted(async () => {
  await loadTenants();
});
</script>

<style scoped>
.invoice-brands-page {
  background: var(--bw-brand-base, #eef0f4);
  height: calc(100vh - 55px);
  overflow: hidden;
}

.brands-container {
  height: 100%;
}

.brands-toolbar {
  border-radius: 8px;
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.action-btn {
  border-radius: 8px !important;
}

.search-box {
  width: 280px;
}

.treasury-table-wrap {
  min-height: 0;
  flex: 1 1 0%;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid rgba(226, 232, 240, 0.8);
  box-shadow: 0 4px 12px -2px rgba(51, 65, 85, 0.05);
}

.invoice-brands-table {
  background: #ffffff;
}

.invoice-brands-table :deep(.q-table__middle) {
  overflow-y: auto;
}

.invoice-brands-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  color: #0f172a;
  font-weight: 700;
  background: #f8fafc;
  border-bottom: 1px solid rgba(226, 232, 240, 0.9);
}

.brand-row {
  transition: background 0.15s ease;
}

.brand-row:hover {
  background: #f8fafc;
}

.text-xxs {
  font-size: 11px;
  line-height: 14px;
}

/* Dark mode adjustments */
body.body--dark .invoice-brands-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .brands-toolbar,
body.body--dark .invoice-brands-table {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

body.body--dark .invoice-brands-table :deep(thead tr th) {
  background: #222222;
  color: #a1a1aa;
  border-bottom-color: #2e2e2e;
}

body.body--dark .brand-row:hover {
  background: #262626;
}
</style>

