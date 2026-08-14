<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Procurement & Stock</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Cargo companies</h1>
          <div class="text-body2 text-grey-7 q-mt-xs">
            Freight agents used on inbound shipments.
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            v-if="canCreate && store.items.length > 0"
            color="primary"
            unelevated
            no-caps
            label="Add cargo company"
            @click="openCreate"
          />
        </div>
      </section>

      <q-banner v-if="store.error" class="bw-status-banner bg-negative text-white">
        <div class="row items-center justify-between q-gutter-sm">
          <div>{{ store.error }}</div>
          <q-btn flat dense no-caps color="white" label="Retry" @click="reload" />
        </div>
      </q-banner>

      <CargoCompaniesSkeleton v-if="store.loading && !store.items.length" />

      <template v-else>
        <q-card flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-input
                v-model="searchText"
                dense
                outlined
                clearable
                class="soft-input"
                placeholder="Search name or code"
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" />
                </template>
              </q-input>
            </div>
            <div class="col-auto">
              <q-toggle v-model="showInactive" label="Show inactive" dense />
            </div>
          </div>
        </q-card>

        <div v-if="filteredRows.length === 0" class="text-center text-grey-7 q-pa-lg">
          <q-icon name="ph ph-airplane-tilt" size="48px" class="q-mb-sm text-grey-4" />
          <div class="text-subtitle1 text-weight-medium q-mb-xs">
            {{ store.items.length === 0 ? 'No cargo companies yet' : 'No cargo companies found' }}
          </div>
          <div v-if="store.items.length === 0" class="text-body2 q-mb-md">
            Add a freight agent to use on inbound shipments.
          </div>
          <q-btn
            v-if="canCreate && store.items.length === 0"
            color="primary"
            unelevated
            no-caps
            label="Add cargo company"
            @click="openCreate"
          />
        </div>

        <q-card v-else flat bordered>
          <q-table
            flat
            :rows="filteredRows"
            :columns="columns"
            row-key="id"
            hide-pagination
            :pagination="{ rowsPerPage: 0 }"
          >
            <template #body-cell-name="props">
              <q-td :props="props">
                <div class="row items-center q-gutter-x-sm no-wrap">
                  <span class="text-weight-medium">{{ props.row.name }}</span>
                  <q-badge v-if="props.row.is_default" color="primary" outline label="Default" />
                  <q-badge v-if="!props.row.is_active" color="grey" outline label="Inactive" />
                </div>
              </q-td>
            </template>
            <template #body-cell-actions="props">
              <q-td :props="props" class="text-right">
                <q-btn
                  v-if="canEdit"
                  flat
                  dense
                  round
                  icon="ph ph-pencil-simple"
                  aria-label="Edit"
                  @click="openEdit(props.row)"
                />
                <q-btn
                  v-if="canDelete && !props.row.is_default"
                  flat
                  dense
                  round
                  color="negative"
                  icon="ph ph-trash"
                  aria-label="Delete"
                  @click="onDelete(props.row)"
                />
              </q-td>
            </template>
          </q-table>
        </q-card>
      </template>

      <CargoCompanyFormDialog
        v-if="tenantId"
        v-model="dialogOpen"
        :initial-data="editing"
        :tenant-id="tenantId"
        :saving="store.saving"
        :check-code-availability="checkCode"
        @save="onSave"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import CargoCompaniesSkeleton from '../components/CargoCompaniesSkeleton.vue';
import CargoCompanyFormDialog from '../components/CargoCompanyFormDialog.vue';
import { cargoCompanyRepository } from '../repositories/cargoCompanyRepository';
import { useCargoCompanyStore } from '../stores/cargoCompanyStore';
import type { CargoCompany } from '../types/cargoCompany';

const authStore = useAuthStore();
const store = useCargoCompanyStore();
const { hasModuleAccess } = useModulePermissions();

const canCreate = computed(() => hasModuleAccess('cargo_company', 'create'));
const canEdit = computed(() => hasModuleAccess('cargo_company', 'edit'));
const canDelete = computed(() => hasModuleAccess('cargo_company', 'delete'));

const tenantId = computed(() => authStore.tenantId);
const searchText = ref('');
const showInactive = ref(true);
const dialogOpen = ref(false);
const editing = ref<CargoCompany | null>(null);

const columns: QTableColumn[] = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'code', label: 'Code', field: 'code', align: 'left' },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'email', label: 'Email', field: 'email', align: 'left' },
  { name: 'actions', label: '', field: 'id', align: 'right' },
];

const filteredRows = computed(() => {
  const term = searchText.value.trim().toLowerCase();
  return store.items.filter((row) => {
    if (!showInactive.value && !row.is_active) return false;
    if (!term) return true;
    return [row.name, row.code, row.email, row.phone]
      .filter(Boolean)
      .some((v) => String(v).toLowerCase().includes(term));
  });
});

const reload = async () => {
  if (!tenantId.value) return;
  try {
    await store.fetchCompanies(tenantId.value, true);
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to load cargo companies');
  }
};

const openCreate = () => {
  editing.value = null;
  dialogOpen.value = true;
};

const openEdit = (row: CargoCompany) => {
  editing.value = row;
  dialogOpen.value = true;
};

const checkCode = (code: string, excludeId?: number | null) => {
  if (!tenantId.value) return Promise.resolve(false);
  return cargoCompanyRepository.isCodeAvailable(code, tenantId.value, excludeId);
};

const onSave = async (payload: {
  id?: number;
  name: string;
  code: string;
  email: string | null;
  phone: string | null;
  address: string | null;
  notes: string | null;
  is_active?: boolean;
}) => {
  if (!tenantId.value) return;
  try {
    if (payload.id != null) {
      await store.updateCompany({
        id: payload.id,
        tenant_id: tenantId.value,
        name: payload.name,
        code: payload.code,
        email: payload.email,
        phone: payload.phone,
        address: payload.address,
        notes: payload.notes,
        is_active: payload.is_active,
      });
      showSuccessNotification('Cargo company updated');
    } else {
      await store.createCompany({
        tenant_id: tenantId.value,
        name: payload.name,
        code: payload.code,
        email: payload.email,
        phone: payload.phone,
        address: payload.address,
        notes: payload.notes,
      });
      showSuccessNotification('Cargo company created');
    }
    dialogOpen.value = false;
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || store.error || 'Failed to save cargo company');
  }
};

const onDelete = async (row: CargoCompany) => {
  if (!tenantId.value || row.is_default) return;
  const ok = await requestConfirmation(
    `Delete “${row.name}”? This cannot be undone if wallet balance is zero.`,
    'Delete cargo company',
    'Delete',
  );
  if (!ok) return;
  try {
    await store.deleteCompany(row.id, tenantId.value);
    showSuccessNotification('Cargo company deleted');
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || store.error || 'Failed to delete cargo company');
  }
};

onMounted(() => {
  void reload();
});

watch(tenantId, () => {
  void reload();
});
</script>
