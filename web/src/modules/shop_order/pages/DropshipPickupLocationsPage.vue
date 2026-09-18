<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <h1 class="text-h5 q-my-none">Pickup locations</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Warehouse or shop addresses the courier picks up from. Not the reseller.
          </p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            icon="ph ph-plus"
            label="Add pickup location"
            no-caps
            class="pill-btn"
            @click="openAddDialog"
          />
        </div>
      </section>

      <q-card flat bordered class="form-card">
        <div v-if="loading" class="row justify-center q-my-xl">
          <q-spinner color="primary" size="3em" />
        </div>
        <q-markup-table v-else flat borderless class="q-mb-none soft-table">
          <thead>
            <tr>
              <th class="text-left">Location</th>
              <th class="text-left">Phone</th>
              <th class="text-left">Address</th>
              <th class="text-left">Status</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="locations.length === 0">
              <td colspan="5" class="text-center text-grey-6 q-pa-md">
                No pickup locations yet. Add the warehouse the courier collects from.
              </td>
            </tr>
            <tr v-for="row in locations" :key="row.id" class="hover-row">
              <td>
                <div class="text-weight-bold text-grey-9">{{ row.location_name }}</div>
                <div v-if="row.store_name" class="text-caption text-grey-7">{{ row.store_name }}</div>
              </td>
              <td>{{ row.phone_primary }}</td>
              <td class="text-grey-8">{{ row.pickup_address }}</td>
              <td>
                <q-chip
                  dense
                  :color="row.is_active ? 'green-1' : 'grey-2'"
                  :text-color="row.is_active ? 'positive' : 'grey-7'"
                >
                  {{ row.is_active ? 'Active' : 'Inactive' }}
                </q-chip>
              </td>
              <td class="text-right">
                <q-btn
                  flat
                  round
                  dense
                  icon="ph ph-pencil-simple"
                  color="primary"
                  aria-label="Edit pickup location"
                  @click="openEditDialog(row)"
                />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>

      <q-dialog v-model="dialogOpen" persistent>
        <q-card style="width: 520px; max-width: 90vw; border-radius: 12px">
          <q-card-section class="row items-center justify-between q-pb-sm">
            <div class="text-h6 text-weight-bold text-grey-9">
              {{ editId ? 'Edit pickup location' : 'Add pickup location' }}
            </div>
            <q-btn v-close-popup flat round dense icon="ph ph-x" />
          </q-card-section>
          <q-separator />
          <q-card-section class="q-gutter-y-sm">
            <q-input v-model="form.location_name" label="Location name *" outlined dense hide-bottom-space />
            <q-input v-model="form.store_name" label="Label (optional)" outlined dense hide-bottom-space />
            <q-input v-model="form.phone_primary" label="Pickup phone *" outlined dense hide-bottom-space />
            <q-input
              v-model="form.pickup_address"
              label="Pickup address *"
              type="textarea"
              outlined
              dense
              autogrow
              hide-bottom-space
            />
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input v-model="form.district" label="District *" outlined dense hide-bottom-space />
              </div>
              <div class="col-6">
                <q-input v-model="form.thana" label="Thana *" outlined dense hide-bottom-space />
              </div>
            </div>
            <q-toggle v-model="form.is_active" label="Active" color="positive" dense />
          </q-card-section>
          <q-separator />
          <q-card-actions align="right" class="q-pa-md">
            <q-btn v-close-popup flat label="Cancel" no-caps />
            <q-btn color="primary" label="Save" no-caps unelevated :loading="saving" @click="saveLocation" />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { pickupLocationService } from '../services/pickupLocationService';
import type { PickupLocationRow } from '../repositories/pickupLocationRepository';

const $q = useQuasar();
const authStore = useAuthStore();
const loading = ref(false);
const saving = ref(false);
const dialogOpen = ref(false);
const editId = ref<string | null>(null);
const locations = ref<PickupLocationRow[]>([]);

const form = reactive({
  location_name: '',
  store_name: '',
  phone_primary: '',
  pickup_address: '',
  district: 'Dhaka',
  thana: '',
  is_active: true,
});

const loadLocations = async () => {
  loading.value = true;
  const res = await pickupLocationService.fetchLocations({ forceRefresh: true });
  loading.value = false;
  if (res.success) {
    locations.value = res.data;
  } else {
    $q.notify({ type: 'negative', message: res.error || 'Failed to load pickup locations' });
  }
};

onMounted(() => {
  void loadLocations();
});

const resetForm = () => {
  form.location_name = '';
  form.store_name = '';
  form.phone_primary = '';
  form.pickup_address = '';
  form.district = 'Dhaka';
  form.thana = '';
  form.is_active = true;
};

const openAddDialog = () => {
  editId.value = null;
  resetForm();
  dialogOpen.value = true;
};

const openEditDialog = (row: PickupLocationRow) => {
  editId.value = row.id;
  form.location_name = row.location_name;
  form.store_name = row.store_name ?? '';
  form.phone_primary = row.phone_primary;
  form.pickup_address = row.pickup_address;
  form.district = row.district;
  form.thana = row.thana;
  form.is_active = row.is_active;
  dialogOpen.value = true;
};

const saveLocation = async () => {
  const tenantId = authStore.selectedTenant?.id ? Number(authStore.selectedTenant.id) : null;
  if (!tenantId) {
    $q.notify({ type: 'negative', message: 'No tenant selected' });
    return;
  }
  if (!form.location_name.trim() || !form.phone_primary.trim() || !form.pickup_address.trim() || !form.thana.trim()) {
    $q.notify({ type: 'negative', message: 'Name, phone, address, and thana are required' });
    return;
  }

  saving.value = true;
  const payload = {
    tenant_id: tenantId,
    location_name: form.location_name.trim(),
    store_name: form.store_name.trim() || null,
    phone_primary: form.phone_primary.trim(),
    phone_secondary: null as string | null,
    pickup_address: form.pickup_address.trim(),
    district: form.district.trim() || 'Dhaka',
    thana: form.thana.trim(),
    notes: null as string | null,
    is_active: form.is_active,
  };

  const res = editId.value
    ? await pickupLocationService.updateLocation(editId.value, payload)
    : await pickupLocationService.createLocation(payload);

  saving.value = false;
  if (!res.success) {
    $q.notify({ type: 'negative', message: res.error || 'Save failed' });
    return;
  }
  dialogOpen.value = false;
  $q.notify({ type: 'positive', message: 'Pickup location saved' });
  await loadLocations();
};
</script>
