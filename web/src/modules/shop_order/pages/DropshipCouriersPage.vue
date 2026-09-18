<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <h1 class="text-h5 q-my-none">Couriers</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">Name and code only. Used when assigning a courier on an order.</p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" icon="ph ph-plus" label="Add courier" no-caps class="pill-btn" @click="openAddDialog" />
        </div>
      </section>

      <q-card flat bordered class="form-card">
        <div v-if="loading" class="row justify-center q-my-xl">
          <q-spinner color="primary" size="3em" />
        </div>
        <q-markup-table v-else flat borderless class="q-mb-none soft-table">
          <thead>
            <tr>
              <th class="text-left">Name</th>
              <th class="text-left">Code</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="couriers.length === 0">
              <td colspan="3" class="text-center text-grey-6 q-pa-md">No couriers yet.</td>
            </tr>
            <tr v-for="c in couriers" :key="c.id" class="hover-row">
              <td class="text-weight-bold text-grey-9">{{ c.name }}</td>
              <td><q-chip dense outline size="sm">{{ c.code }}</q-chip></td>
              <td class="text-right">
                <q-btn
                  flat
                  round
                  dense
                  icon="ph ph-pencil-simple"
                  color="primary"
                  aria-label="Edit courier"
                  @click="openEditDialog(c)"
                />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>

      <q-dialog v-model="dialogOpen" persistent>
        <q-card style="width: 420px; max-width: 90vw; border-radius: 12px">
          <q-card-section class="row items-center justify-between q-pb-sm">
            <div class="text-h6 text-weight-bold text-grey-9">{{ editId ? 'Edit courier' : 'Add courier' }}</div>
            <q-btn v-close-popup flat round dense icon="ph ph-x" color="grey-7" />
          </q-card-section>
          <q-separator />
          <q-card-section class="q-gutter-y-sm">
            <q-input v-model="form.name" label="Name *" outlined dense hide-bottom-space />
            <q-input v-model="form.code" label="Code *" outlined dense hide-bottom-space />
          </q-card-section>
          <q-separator />
          <q-card-actions align="right" class="q-pa-md">
            <q-btn v-close-popup flat label="Cancel" color="grey-7" no-caps />
            <q-btn color="primary" label="Save" :loading="saving" no-caps unelevated @click="saveCourier" />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { useQuasar } from 'quasar';
import { dropshipCourierService } from '../services/dropshipCourierService';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';

const $q = useQuasar();
const loading = ref(false);
const saving = ref(false);
const dialogOpen = ref(false);
const editId = ref<string | null>(null);
const couriers = ref<CourierServiceRow[]>([]);
const form = reactive({ name: '', code: '' });

const loadCouriers = async () => {
  loading.value = true;
  const res = await dropshipCourierService.fetchCouriers({ forceRefresh: true });
  loading.value = false;
  if (res.success) {
    couriers.value = res.data;
  } else {
    $q.notify({ type: 'negative', message: res.error || 'Failed to load couriers' });
  }
};

onMounted(() => {
  void loadCouriers();
});

const openAddDialog = () => {
  editId.value = null;
  form.name = '';
  form.code = '';
  dialogOpen.value = true;
};

const openEditDialog = (c: CourierServiceRow) => {
  editId.value = c.id;
  form.name = c.name;
  form.code = c.code;
  dialogOpen.value = true;
};

const saveCourier = async () => {
  const name = form.name.trim();
  const code = form.code.trim();
  if (!name || !code) {
    $q.notify({ type: 'warning', message: 'Name and code are required.' });
    return;
  }

  saving.value = true;
  const res = editId.value
    ? await dropshipCourierService.updateCourier(editId.value, { name, code })
    : await dropshipCourierService.createCourier({ name, code });
  saving.value = false;

  if (!res.success) {
    $q.notify({ type: 'negative', message: res.error || 'Failed to save courier.' });
    return;
  }
  $q.notify({ type: 'positive', message: 'Courier saved.' });
  dialogOpen.value = false;
  await loadCouriers();
};
</script>
