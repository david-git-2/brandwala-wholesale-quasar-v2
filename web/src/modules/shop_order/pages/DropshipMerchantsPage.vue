<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Shop &amp; Order — Dropship</div>
          <h1 class="text-h5 q-my-none">Merchant &amp; Sender Pickup Profiles</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage merchants, store brands, and pickup address profiles for easy parcel dispatch tasks.
          </p>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            color="primary"
            icon="add"
            label="Add Merchant Profile"
            no-caps
            class="pill-btn"
            @click="openAddDialog"
          />
        </div>
      </section>

      <!-- Filters & Search -->
      <q-card flat bordered class="form-card q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-md">
          <div class="col-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              placeholder="Search merchant name, phone, district..."
              clearable
            >
              <template #prepend>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>
          <div class="col-auto row q-gutter-xs items-center">
            <q-chip
              clickable
              :outline="statusFilter !== 'all'"
              :color="statusFilter === 'all' ? 'primary' : 'grey-4'"
              :text-color="statusFilter === 'all' ? 'white' : 'grey-9'"
              @click="statusFilter = 'all'"
            >
              All ({{ merchants.length }})
            </q-chip>
            <q-chip
              clickable
              :outline="statusFilter !== 'active'"
              :color="statusFilter === 'active' ? 'positive' : 'grey-4'"
              :text-color="statusFilter === 'active' ? 'white' : 'grey-9'"
              @click="statusFilter = 'active'"
            >
              Active ({{ activeCount }})
            </q-chip>
            <q-chip
              clickable
              :outline="statusFilter !== 'inactive'"
              :color="statusFilter === 'inactive' ? 'grey-7' : 'grey-4'"
              :text-color="statusFilter === 'inactive' ? 'white' : 'grey-9'"
              @click="statusFilter = 'inactive'"
            >
              Inactive ({{ inactiveCount }})
            </q-chip>
          </div>
        </div>
      </q-card>

      <!-- Table Card -->
      <q-card flat bordered class="form-card">
        <div v-if="loading" class="row justify-center q-py-xl">
          <q-spinner color="primary" size="3em" />
        </div>

        <q-markup-table v-else flat borderless class="q-mb-none soft-table">
          <thead>
            <tr>
              <th class="text-left">Merchant / Brand</th>
              <th class="text-left">Contact Info</th>
              <th class="text-left">Pickup Address</th>
              <th class="text-left">Location (District / Thana)</th>
              <th class="text-left">Status</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="filteredMerchants.length === 0">
              <td colspan="6" class="text-center text-grey-6 q-pa-lg">
                No merchant profiles found. Click "Add Merchant Profile" to create one.
              </td>
            </tr>
            <tr v-for="m in filteredMerchants" :key="m.id" class="hover-row">
              <td>
                <div class="text-weight-bold text-grey-9">{{ m.merchant_name }}</div>
                <div class="text-caption text-grey-7">{{ m.store_name || '—' }}</div>
              </td>
              <td>
                <div class="text-weight-medium">{{ m.phone_primary }}</div>
                <div v-if="m.phone_secondary" class="text-caption text-grey-7">
                  Alt: {{ m.phone_secondary }}
                </div>
              </td>
              <td>
                <div class="text-body2 text-grey-9" style="max-width: 250px; white-space: normal;">
                  {{ m.pickup_address }}
                </div>
              </td>
              <td>
                <q-chip dense outline size="sm" color="blue-8">
                  {{ m.district || 'Dhaka' }} / {{ m.thana || 'Dhanmondi' }}
                </q-chip>
              </td>
              <td>
                <q-chip
                  dense
                  :color="m.is_active ? 'green-1' : 'grey-2'"
                  :text-color="m.is_active ? 'positive' : 'grey-7'"
                >
                  {{ m.is_active ? 'Active' : 'Inactive' }}
                </q-chip>
              </td>
              <td class="text-right">
                <q-btn flat round dense icon="edit" color="primary" @click="openEditDialog(m)">
                  <q-tooltip>Edit Profile</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  round
                  dense
                  :icon="m.is_active ? 'block' : 'check_circle'"
                  :color="m.is_active ? 'negative' : 'positive'"
                  @click="toggleMerchantStatus(m)"
                >
                  <q-tooltip>{{ m.is_active ? 'Deactivate' : 'Activate' }}</q-tooltip>
                </q-btn>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>
    </section>

    <!-- Dialog: Add / Edit Merchant -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="min-width: 500px; max-width: 90vw;" class="q-pa-sm">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">
            {{ editingId ? 'Edit Merchant Profile' : 'Add New Merchant Profile' }}
          </div>
          <q-btn v-close-popup flat round dense icon="close" />
        </q-card-section>

        <q-separator />

        <q-card-section class="q-gutter-y-md">
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.merchant_name"
                label="Merchant / Sender Name *"
                dense
                outlined
                :rules="[(val) => !!val || 'Name is required']"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.store_name"
                label="Store / Brand Name"
                dense
                outlined
                placeholder="e.g. Fashion BD"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.phone_primary"
                label="Primary Phone *"
                dense
                outlined
                placeholder="017xxxxxxxx"
                :rules="[(val) => !!val || 'Primary phone is required']"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.phone_secondary"
                label="Secondary Phone"
                dense
                outlined
                placeholder="Optional"
              />
            </div>
          </div>

          <q-input
            v-model="form.pickup_address"
            label="Pickup Address *"
            type="textarea"
            rows="2"
            dense
            outlined
            placeholder="Full street address for courier pickup"
            :rules="[(val) => !!val || 'Pickup address is required']"
          />

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.district"
                label="District *"
                dense
                outlined
                placeholder="e.g. Dhaka"
                :rules="[(val) => !!val || 'District is required']"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.thana"
                label="Thana / Area *"
                dense
                outlined
                placeholder="e.g. Dhanmondi"
                :rules="[(val) => !!val || 'Thana is required']"
              />
            </div>
          </div>

          <q-input
            v-model="form.notes"
            label="Internal Notes"
            dense
            outlined
            placeholder="Special instructions or contact notes"
          />

          <q-toggle v-model="form.is_active" label="Active Profile" color="positive" />
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-pa-md">
          <q-btn v-close-popup flat label="Cancel" no-caps />
          <q-btn
            color="primary"
            :label="editingId ? 'Save Changes' : 'Create Merchant'"
            no-caps
            class="pill-btn"
            @click="saveMerchant"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { dropshipMerchantService } from '../services/dropshipMerchantService';
import type { MerchantProfileRow } from '../repositories/dropshipMerchantRepository';

export interface MerchantProfile {
  id: string;
  merchant_name: string;
  store_name?: string | undefined;
  phone_primary: string;
  phone_secondary?: string | undefined;
  pickup_address: string;
  district: string;
  thana: string;
  notes?: string | undefined;
  is_active: boolean;
}

const $q = useQuasar();
const authStore = useAuthStore();
const loading = ref(false);
const searchQuery = ref('');
const statusFilter = ref<'all' | 'active' | 'inactive'>('all');

const dialogOpen = ref(false);
const editingId = ref<string | null>(null);

const form = ref<Omit<MerchantProfile, 'id'>>({
  merchant_name: '',
  store_name: '',
  phone_primary: '',
  phone_secondary: '',
  pickup_address: '',
  district: 'Dhaka',
  thana: '',
  notes: '',
  is_active: true,
});

const merchants = ref<MerchantProfile[]>([]);

const activeCount = computed(() => merchants.value.filter((m) => m.is_active).length);
const inactiveCount = computed(() => merchants.value.filter((m) => !m.is_active).length);

const filteredMerchants = computed(() => {
  return merchants.value.filter((m) => {
    const matchesSearch =
      !searchQuery.value ||
      m.merchant_name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      (m.store_name && m.store_name.toLowerCase().includes(searchQuery.value.toLowerCase())) ||
      m.phone_primary.includes(searchQuery.value) ||
      m.district.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      m.thana.toLowerCase().includes(searchQuery.value.toLowerCase());

    const matchesStatus =
      statusFilter.value === 'all' ||
      (statusFilter.value === 'active' && m.is_active) ||
      (statusFilter.value === 'inactive' && !m.is_active);

    return matchesSearch && matchesStatus;
  });
});

async function loadMerchants() {
  loading.value = true;
  const res = await dropshipMerchantService.fetchMerchants({ forceRefresh: true });
  loading.value = false;

  if (res.success && res.data) {
    merchants.value = res.data.map((row: MerchantProfileRow) => ({
      id: row.id,
      merchant_name: row.merchant_name,
      store_name: row.store_name || undefined,
      phone_primary: row.phone_primary,
      phone_secondary: row.phone_secondary || undefined,
      pickup_address: row.pickup_address,
      district: row.district,
      thana: row.thana,
      notes: row.notes || undefined,
      is_active: row.is_active,
    }));
  } else if (!res.success) {
    $q.notify({
      type: 'negative',
      message: res.error || 'Failed to load merchant profiles.',
    });
  }
}

onMounted(() => {
  void loadMerchants();
});

function openAddDialog() {
  editingId.value = null;
  form.value = {
    merchant_name: '',
    store_name: '',
    phone_primary: '',
    phone_secondary: '',
    pickup_address: '',
    district: 'Dhaka',
    thana: '',
    notes: '',
    is_active: true,
  };
  dialogOpen.value = true;
}

function openEditDialog(m: MerchantProfile) {
  editingId.value = m.id;
  form.value = {
    merchant_name: m.merchant_name,
    store_name: m.store_name || '',
    phone_primary: m.phone_primary,
    phone_secondary: m.phone_secondary || '',
    pickup_address: m.pickup_address,
    district: m.district,
    thana: m.thana,
    notes: m.notes || '',
    is_active: m.is_active,
  };
  dialogOpen.value = true;
}

async function toggleMerchantStatus(m: MerchantProfile) {
  const newStatus = !m.is_active;
  const res = await dropshipMerchantService.updateMerchant(m.id, { is_active: newStatus });
  if (res.success) {
    m.is_active = newStatus;
    $q.notify({
      type: 'positive',
      message: `Merchant ${m.merchant_name} set to ${newStatus ? 'Active' : 'Inactive'}`,
    });
  } else {
    $q.notify({
      type: 'negative',
      message: res.error || 'Failed to update merchant status.',
    });
  }
}

async function saveMerchant() {
  if (!form.value.merchant_name || !form.value.phone_primary || !form.value.pickup_address || !form.value.district || !form.value.thana) {
    $q.notify({
      type: 'warning',
      message: 'Please fill in all required fields.',
    });
    return;
  }

  const currentTenantId = authStore.selectedTenant?.id;
  if (!currentTenantId) {
    $q.notify({
      type: 'negative',
      message: 'Tenant context is missing. Please select a store/tenant.',
    });
    return;
  }

  if (editingId.value) {
    const res = await dropshipMerchantService.updateMerchant(editingId.value, {
      merchant_name: form.value.merchant_name,
      store_name: form.value.store_name || null,
      phone_primary: form.value.phone_primary,
      phone_secondary: form.value.phone_secondary || null,
      pickup_address: form.value.pickup_address,
      district: form.value.district,
      thana: form.value.thana,
      notes: form.value.notes || null,
      is_active: form.value.is_active,
    });

    if (res.success) {
      $q.notify({ type: 'positive', message: 'Merchant profile updated successfully.' });
      dialogOpen.value = false;
      await loadMerchants();
    } else {
      $q.notify({ type: 'negative', message: res.error || 'Failed to update merchant.' });
    }
  } else {
    const res = await dropshipMerchantService.createMerchant({
      tenant_id: Number(currentTenantId),
      merchant_name: form.value.merchant_name,
      store_name: form.value.store_name || null,
      phone_primary: form.value.phone_primary,
      phone_secondary: form.value.phone_secondary || null,
      pickup_address: form.value.pickup_address,
      district: form.value.district,
      thana: form.value.thana,
      notes: form.value.notes || null,
      is_active: form.value.is_active,
    });

    if (res.success) {
      $q.notify({ type: 'positive', message: 'Merchant profile added successfully.' });
      dialogOpen.value = false;
      await loadMerchants();
    } else {
      $q.notify({ type: 'negative', message: res.error || 'Failed to create merchant.' });
    }
  }
}
</script>

<style scoped>
.bw-page {
  padding: 16px;
}
.bw-page__stack {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.form-card {
  border-radius: 8px;
}
.soft-table th {
  font-weight: 600;
  color: #555;
}
.hover-row:hover {
  background-color: #f9fafb;
}
.pill-btn {
  border-radius: 20px;
}
</style>
