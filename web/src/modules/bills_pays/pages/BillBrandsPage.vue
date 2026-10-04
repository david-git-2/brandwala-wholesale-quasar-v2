<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center justify-between q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Bills" @click="goBack" />
      <q-btn unelevated dense no-caps color="primary" icon="ph ph-plus" label="Add brand" @click="openCreate" />
    </div>

    <div v-if="brandsQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else class="col overflow-auto">
      <q-markup-table flat bordered class="brands-table">
        <thead>
          <tr>
            <th class="text-left">Name</th>
            <th class="text-left">Address</th>
            <th class="text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="brand in brands" :key="brand.id">
            <td>{{ brand.name }}</td>
            <td class="text-grey-8">{{ brand.address }}</td>
            <td class="text-right">
              <q-btn flat dense round icon="ph ph-pencil-simple" @click="openEdit(brand)" />
              <q-btn flat dense round icon="ph ph-trash" color="negative" @click="confirmDelete(brand)" />
            </td>
          </tr>
          <tr v-if="!brands.length">
            <td colspan="3" class="text-center text-grey-6 q-pa-lg">No brands yet. Add one for print letterhead.</td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="min-width: 360px">
        <q-card-section>
          <div class="text-h6">{{ editingId ? 'Edit brand' : 'New brand' }}</div>
        </q-card-section>
        <q-card-section class="q-gutter-y-md">
          <q-input v-model="formName" outlined dense label="Name *" />
          <q-input v-model="formAddress" outlined dense label="Address" type="textarea" autogrow />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            unelevated
            color="primary"
            no-caps
            label="Save"
            :loading="saving"
            :disable="!formName.trim()"
            @click="saveBrand"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  invoiceRepository,
  type InvoiceBrand,
} from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { requestConfirmation, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const queryClient = useQueryClient();

const parentTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return null;
  return t.parent_id ?? t.id;
});

const brandsQuery = useQuery({
  queryKey: computed(() => ['invoice_brands', parentTenantId.value]),
  queryFn: () =>
    invoiceRepository.listInvoiceBrands({ parent_tenant_id: parentTenantId.value! }),
  enabled: computed(() => parentTenantId.value != null),
});

const brands = computed(() => brandsQuery.data.value ?? []);

const dialogOpen = ref(false);
const editingId = ref<number | null>(null);
const formName = ref('');
const formAddress = ref('');
const saving = ref(false);

const openCreate = () => {
  editingId.value = null;
  formName.value = '';
  formAddress.value = '';
  dialogOpen.value = true;
};

const openEdit = (brand: InvoiceBrand) => {
  editingId.value = brand.id;
  formName.value = brand.name;
  formAddress.value = brand.address;
  dialogOpen.value = true;
};

const invalidate = () => {
  void queryClient.invalidateQueries({ queryKey: ['invoice_brands'] });
};

const saveBrand = async () => {
  if (!parentTenantId.value || !formName.trim()) return;
  saving.value = true;
  try {
    if (editingId.value) {
      await invoiceRepository.updateInvoiceBrand({
        id: editingId.value,
        patch: { name: formName.value.trim(), address: formAddress.value.trim() },
      });
      showSuccessNotification('Brand updated.');
    } else {
      await invoiceRepository.createInvoiceBrand({
        parent_tenant_id: parentTenantId.value,
        name: formName.value.trim(),
        address: formAddress.value.trim(),
      });
      showSuccessNotification('Brand created.');
    }
    dialogOpen.value = false;
    invalidate();
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Could not save brand.');
  } finally {
    saving.value = false;
  }
};

const confirmDelete = async (brand: InvoiceBrand) => {
  const ok = await requestConfirmation(`Delete “${brand.name}”?`, 'Delete brand');
  if (!ok) return;
  try {
    await invoiceRepository.deleteInvoiceBrand({ id: brand.id });
    showSuccessNotification('Brand deleted.');
    invalidate();
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Could not delete brand.');
  }
};

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({ name: 'app-bills-page', params: tenantSlug ? { tenantSlug } : {} });
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.brands-table {
  max-width: 720px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
}
</style>
