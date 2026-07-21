<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <h1 class="text-h5 q-my-none">Dropship Service Catalog &amp; Return Policies</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage supported courier partners, COD fees, delivery charges, and return policies.
          </p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            icon="add"
            label="Add Courier Service"
            no-caps
            class="pill-btn"
            @click="openAddDialog"
          />
        </div>
      </section>

      <!-- Tabs for Catalog / Policy -->
      <q-card flat bordered class="form-card">
        <q-tabs v-model="tab" dense class="text-grey-8" active-color="primary" indicator-color="primary" align="left">
          <q-tab name="couriers" icon="local_shipping" label="Courier Services" />
          <q-tab name="policies" icon="assignment_return" label="Return Policy" />
        </q-tabs>

        <q-separator />

        <div v-if="loading" class="row justify-center q-my-xl">
          <q-spinner color="primary" size="3em" />
        </div>

        <q-tab-panels v-else v-model="tab" animated>
          <!-- Tab 1: Courier Services Catalog -->
          <q-tab-panel name="couriers" class="q-pa-none">
            <q-markup-table flat borderless class="q-mb-none soft-table">
              <thead>
                <tr>
                  <th class="text-left">Courier Name</th>
                  <th class="text-left">Code</th>
                  <th class="text-left">COD Mode &amp; Rate</th>
                  <th class="text-left">Status</th>
                  <th class="text-left">Notes</th>
                  <th class="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="couriers.length === 0">
                  <td colspan="6" class="text-center text-grey-6 q-pa-md">
                    No courier services found. Click "Add Courier Service" to add one.
                  </td>
                </tr>
                <tr v-for="c in couriers" :key="c.id" class="hover-row">
                  <td>
                    <div class="text-weight-bold text-grey-9">{{ c.name }}</div>
                  </td>
                  <td><q-chip dense outline size="sm">{{ c.code }}</q-chip></td>
                  <td>
                    <span class="text-weight-medium">
                      {{ c.cod_fee_mode === 'percent_of_collect' ? `${c.cod_fee_percent}%` : `${c.cod_fee_flat_amount} BDT` }}
                    </span>
                  </td>
                  <td>
                    <q-chip
                      dense
                      :color="c.is_active ? 'green-1' : 'grey-2'"
                      :text-color="c.is_active ? 'positive' : 'grey-7'"
                    >
                      {{ c.is_active ? 'Active' : 'Inactive' }}
                    </q-chip>
                  </td>
                  <td><span class="text-caption text-grey-7">{{ c.notes }}</span></td>
                  <td class="text-right">
                    <q-btn flat round dense icon="edit" color="primary" @click="openEditDialog(c)" />
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-tab-panel>

          <!-- Tab 2: Courier Return Policies -->
          <q-tab-panel name="policies" class="q-pa-md">
            <div v-if="couriers.length === 0" class="text-center text-grey-6 q-pa-md">
              No courier return policies configured.
            </div>
            <div v-else class="row q-col-gutter-md">
              <div v-for="c in couriers" :key="'pol-' + c.id" class="col-12 col-md-4">
                <q-card flat bordered class="q-pa-md rounded-borders">
                  <div class="row items-center justify-between q-mb-sm">
                    <div class="text-subtitle1 text-weight-bold text-grey-9">{{ c.name }}</div>
                    <q-chip dense color="blue-1" text-color="primary" size="sm">
                      {{ c.code }}
                    </q-chip>
                  </div>
                  <q-separator class="q-mb-sm" />
                  <div class="q-gutter-y-xs text-body2">
                    <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Delivery Fees</div>
                    <div class="row justify-between">
                      <span class="text-grey-7">Inside Dhaka:</span>
                      <span class="text-weight-medium">{{ c.inside_dhaka_fee }} BDT</span>
                    </div>
                    <div class="row justify-between">
                      <span class="text-grey-7">Outside Dhaka:</span>
                      <span class="text-weight-medium">{{ c.outside_dhaka_fee }} BDT</span>
                    </div>
                    <q-separator class="q-my-xs" />
                    <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Return Fees</div>
                    <div class="row justify-between">
                      <span class="text-grey-7">Inside Dhaka Return:</span>
                      <span class="text-weight-medium">{{ c.inside_dhaka_return_fee ?? 30 }} BDT</span>
                    </div>
                    <div class="row justify-between">
                      <span class="text-grey-7">Outside Dhaka Return:</span>
                      <span class="text-weight-medium">{{ c.outside_dhaka_return_fee ?? 60 }} BDT</span>
                    </div>
                    <q-separator class="q-my-xs" />
                    <div class="row justify-between">
                      <span class="text-grey-7">Max Delivery Attempts:</span>
                      <span class="text-weight-medium">{{ c.delivery_attempt_count }}</span>
                    </div>
                    <div class="row justify-between">
                      <span class="text-grey-7">Hub Hold Limit:</span>
                      <span class="text-weight-medium">{{ c.hub_hold_days }} Days</span>
                    </div>
                    <div class="row justify-between items-center q-mt-xs">
                      <span class="text-grey-7">Open-Box Permitted:</span>
                      <q-icon
                        :name="c.open_box_default_allowed ? 'check_circle' : 'cancel'"
                        :color="c.open_box_default_allowed ? 'positive' : 'negative'"
                        size="18px"
                      />
                    </div>
                  </div>
                </q-card>
              </div>
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </q-card>

      <!-- Edit / Add Courier Dialog -->
      <q-dialog v-model="dialogOpen" persistent>
        <q-card style="width: 560px; max-width: 90vw; border-radius: 12px">
          <q-card-section class="row items-center justify-between q-pb-sm">
            <div class="text-h6 text-weight-bold text-grey-9">
              {{ editId ? 'Edit Courier Service & Policy' : 'Add Courier Service & Policy' }}
            </div>
            <q-btn flat round dense icon="close" color="grey-7" v-close-popup />
          </q-card-section>

          <q-separator />

          <q-card-section class="q-pa-md q-gutter-y-md">
            <!-- Basic Details -->
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input v-model="form.name" label="Courier Name *" outlined dense hide-bottom-space />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model="form.code" label="Courier Code *" outlined dense hide-bottom-space />
              </div>
            </div>

            <!-- COD Settings -->
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="form.cod_fee_mode"
                  :options="[
                    { label: 'Percentage (%)', value: 'percent_of_collect' },
                    { label: 'Flat (BDT)', value: 'flat' },
                    { label: 'None', value: 'none' }
                  ]"
                  emit-value
                  map-options
                  label="COD Mode *"
                  outlined
                  dense
                  hide-bottom-space
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-if="form.cod_fee_mode === 'percent_of_collect'"
                  v-model.number="form.cod_fee_percent"
                  type="number"
                  label="COD Rate (%) *"
                  outlined
                  dense
                  hide-bottom-space
                />
                <q-input
                  v-else-if="form.cod_fee_mode === 'flat'"
                  v-model.number="form.cod_fee_flat_amount"
                  type="number"
                  label="COD Amount (BDT) *"
                  outlined
                  dense
                  hide-bottom-space
                />
              </div>
            </div>

            <q-separator />

            <!-- Delivery Charges Section -->
            <div>
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-xs">
                Delivery Charges
              </div>
              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.inside_dhaka_fee"
                    type="number"
                    label="Inside Dhaka (BDT)"
                    outlined
                    dense
                    hide-bottom-space
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.outside_dhaka_fee"
                    type="number"
                    label="Outside Dhaka (BDT)"
                    outlined
                    dense
                    hide-bottom-space
                  />
                </div>
              </div>
            </div>

            <!-- Return Policy Section -->
            <div>
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-xs">
                Return Policy Charges &amp; Rules
              </div>
              <div class="row q-col-gutter-sm q-mb-sm">
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.inside_dhaka_return_fee"
                    type="number"
                    label="Inside Dhaka Return Fee (BDT)"
                    outlined
                    dense
                    hide-bottom-space
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.outside_dhaka_return_fee"
                    type="number"
                    label="Outside Dhaka Return Fee (BDT)"
                    outlined
                    dense
                    hide-bottom-space
                  />
                </div>
              </div>

              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.delivery_attempt_count"
                    type="number"
                    label="Max Attempts"
                    outlined
                    dense
                    hide-bottom-space
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.hub_hold_days"
                    type="number"
                    label="Hub Hold Days"
                    outlined
                    dense
                    hide-bottom-space
                  />
                </div>
              </div>
            </div>

            <!-- Toggles & Notes -->
            <div class="column q-gutter-y-xs">
              <q-toggle v-model="form.open_box_default_allowed" label="Allow Open-Box Parcel Inspection" color="primary" dense />
              <q-toggle v-model="form.is_active" label="Courier Service Active" color="positive" dense />
            </div>

            <q-input
              v-model="form.notes"
              label="Notes / Instructions"
              outlined
              dense
              type="textarea"
              rows="2"
              hide-bottom-space
            />
          </q-card-section>

          <q-separator />

          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat label="Cancel" color="grey-7" v-close-popup no-caps />
            <q-btn color="primary" label="Save Service & Policy" :loading="saving" @click="saveCourier" no-caps unelevated />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import {
  dropshipCourierService
} from '../services/dropshipCourierService';
import type { CourierServiceRow, CreateCourierServicePayload } from '../repositories/dropshipCourierRepository';

const $q = useQuasar();
const tab = ref<'couriers' | 'policies'>('couriers');
const loading = ref(false);
const saving = ref(false);
const dialogOpen = ref(false);
const editId = ref<string | null>(null);

const couriers = ref<CourierServiceRow[]>([]);

const form = reactive<CreateCourierServicePayload>({
  name: '',
  code: '',
  tenant_id: null,
  is_active: true,
  cod_fee_mode: 'percent_of_collect',
  cod_fee_percent: 1,
  cod_fee_flat_amount: 0,
  cod_fee_notes: null,
  deduct_cod_from_margin_default: false,
  inside_dhaka_fee: 60,
  outside_dhaka_fee: 120,
  inside_dhaka_return_fee: 30,
  outside_dhaka_return_fee: 60,
  return_fee_mode: 'flat',
  return_fee_percent: 0,
  delivery_attempt_count: 2,
  hub_hold_days: 3,
  open_box_default_allowed: true,
  notes: '',
});

const loadCouriers = async () => {
  loading.value = true;
  const res = await dropshipCourierService.fetchCouriers();
  loading.value = false;
  if (res.success) {
    couriers.value = res.data;
  } else {
    $q.notify({
      type: 'negative',
      message: res.error || 'Failed to load courier services',
    });
  }
};

onMounted(() => {
  void loadCouriers();
});

const openAddDialog = () => {
  editId.value = null;
  form.name = '';
  form.code = '';
  form.tenant_id = null;
  form.is_active = true;
  form.cod_fee_mode = 'percent_of_collect';
  form.cod_fee_percent = 1;
  form.cod_fee_flat_amount = 0;
  form.cod_fee_notes = null;
  form.deduct_cod_from_margin_default = false;
  form.inside_dhaka_fee = 60;
  form.outside_dhaka_fee = 120;
  form.inside_dhaka_return_fee = 30;
  form.outside_dhaka_return_fee = 60;
  form.return_fee_mode = 'flat';
  form.return_fee_percent = 0;
  form.delivery_attempt_count = 2;
  form.hub_hold_days = 3;
  form.open_box_default_allowed = true;
  form.notes = '';
  dialogOpen.value = true;
};

const openEditDialog = (c: CourierServiceRow) => {
  editId.value = c.id;
  form.name = c.name;
  form.code = c.code;
  form.tenant_id = c.tenant_id;
  form.is_active = c.is_active;
  form.cod_fee_mode = c.cod_fee_mode;
  form.cod_fee_percent = c.cod_fee_percent;
  form.cod_fee_flat_amount = c.cod_fee_flat_amount;
  form.cod_fee_notes = c.cod_fee_notes;
  form.deduct_cod_from_margin_default = c.deduct_cod_from_margin_default;
  form.inside_dhaka_fee = c.inside_dhaka_fee;
  form.outside_dhaka_fee = c.outside_dhaka_fee;
  form.inside_dhaka_return_fee = c.inside_dhaka_return_fee;
  form.outside_dhaka_return_fee = c.outside_dhaka_return_fee;
  form.return_fee_mode = c.return_fee_mode;
  form.return_fee_percent = c.return_fee_percent;
  form.delivery_attempt_count = c.delivery_attempt_count;
  form.hub_hold_days = c.hub_hold_days;
  form.open_box_default_allowed = c.open_box_default_allowed;
  form.notes = c.notes || '';
  dialogOpen.value = true;
};

const saveCourier = async () => {
  if (!form.name.trim() || !form.code.trim()) {
    $q.notify({
      type: 'warning',
      message: 'Courier name and code are required.',
    });
    return;
  }

  saving.value = true;
  if (editId.value) {
    const res = await dropshipCourierService.updateCourier(editId.value, { ...form });
    saving.value = false;
    if (res.success) {
      $q.notify({ type: 'positive', message: 'Courier service updated successfully.' });
      dialogOpen.value = false;
      await loadCouriers();
    } else {
      $q.notify({ type: 'negative', message: res.error || 'Failed to update courier service.' });
    }
  } else {
    const res = await dropshipCourierService.createCourier({ ...form });
    saving.value = false;
    if (res.success) {
      $q.notify({ type: 'positive', message: 'Courier service created successfully.' });
      dialogOpen.value = false;
      await loadCouriers();
    } else {
      $q.notify({ type: 'negative', message: res.error || 'Failed to create courier service.' });
    }
  }
};
</script>

