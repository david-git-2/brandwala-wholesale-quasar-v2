<template>
  <q-dialog v-model="localOpen" persistent @hide="onDialogHide">
    <q-card style="min-width: 500px; max-width: 90vw">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6">
          {{ isEditMode ? 'Edit Costing File' : 'Create Costing File' }}
        </div>

        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-separator />

      <q-card-section>
        <q-form ref="formRef" @submit.prevent="handleSubmit" class="q-gutter-md">
          <q-input
            v-model="form.name"
            label="Name"
            outlined
            dense
            clearable
            :rules="[(val) => !!val || 'Name is required']"
          />

          <q-select
            v-model="selectedProfile"
            :options="profileOptions"
            option-label="name"
            option-value="id"
            label="Billing Profile (Customer)"
            outlined
            dense
            clearable
            use-input
            input-debounce="300"
            :loading="loadingProfiles"
            @filter="filterProfiles"
            @update:model-value="onProfileChange"
          >
            <template #no-option>
              <q-item>
                <q-item-section class="text-grey">No billing profiles found</q-item-section>
              </q-item>
            </template>
          </q-select>

          <q-input
            v-model="form.order_for"
            label="Created For"
            outlined
            dense
            clearable
            :rules="[(val) => !!val || 'Created For is required']"
          />

          <q-input v-model="form.note" label="Note" type="textarea" autogrow outlined dense />
        </q-form>
      </q-card-section>

      <q-separator />

      <q-card-actions align="right">
        <q-btn flat label="Cancel" color="grey-7" v-close-popup />
        <q-btn
          unelevated
          color="primary"
          :label="isEditMode ? 'Update' : 'Create'"
          @click="handleSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch, ref, onMounted } from 'vue';
import {
  billingProfileRepository,
  type BillingProfile,
} from 'src/modules/sales_invoice/repositories/billingProfileRepository';

interface CostingFileForm {
  id: number | null;
  name: string;
  order_for: string;
  billing_profile_id: number | null;
  note: string;
  vendor_code: string | null;
  market_code: string | null;
}

const props = defineProps<{
  modelValue: boolean;
  data: CostingFileForm | null;
}>();

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void;
  (event: 'submit', value: CostingFileForm): void;
}>();

type FormRef = {
  validate: () => boolean | Promise<boolean>;
};

const formRef = ref<FormRef | null>(null);

const emptyForm = (): CostingFileForm => ({
  id: null,
  name: '',
  order_for: '',
  billing_profile_id: null,
  note: '',
  vendor_code: null,
  market_code: null,
});

const form = reactive(emptyForm());
const selectedProfile = ref<BillingProfile | null>(null);
const profileOptions = ref<BillingProfile[]>([]);
const allProfiles = ref<BillingProfile[]>([]);
const loadingProfiles = ref(false);

const isEditMode = computed(() => !!props.data?.id);

const localOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
});

async function loadBillingProfiles() {
  loadingProfiles.value = true;
  try {
    const res = await billingProfileRepository.listBillingProfiles({ page_size: 100 });
    allProfiles.value = res.data;
    profileOptions.value = res.data;
    syncSelectedProfile();
  } catch (err) {
    console.error('Failed to load billing profiles', err);
  } finally {
    loadingProfiles.value = false;
  }
}

function syncSelectedProfile() {
  if (form.billing_profile_id) {
    const found = allProfiles.value.find((p) => p.id === form.billing_profile_id);
    if (found) {
      selectedProfile.value = found;
      return;
    }
  }
  selectedProfile.value = null;
}

function filterProfiles(val: string, update: (fn: () => void) => void) {
  update(() => {
    if (!val.trim()) {
      profileOptions.value = allProfiles.value;
    } else {
      const needle = val.toLowerCase();
      profileOptions.value = allProfiles.value.filter((p) =>
        p.name.toLowerCase().includes(needle),
      );
    }
  });
}

function onProfileChange(val: BillingProfile | null) {
  if (val) {
    form.billing_profile_id = val.id;
    if (!form.order_for || form.order_for.trim() === '') {
      form.order_for = val.name;
    }
  } else {
    form.billing_profile_id = null;
  }
}

function fillForm(source: CostingFileForm | null) {
  const values = source || emptyForm();

  form.id = values.id ?? null;
  form.name = values.name ?? '';
  form.order_for = values.order_for ?? '';
  form.billing_profile_id = values.billing_profile_id ?? null;
  form.note = values.note ?? '';
  form.vendor_code = values.vendor_code ?? null;
  form.market_code = values.market_code ?? null;
  syncSelectedProfile();
}

onMounted(() => {
  void loadBillingProfiles();
});

watch(
  () => props.data,
  (val) => fillForm(val),
  { immediate: true },
);

watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      fillForm(props.data);
    }
  },
);

async function handleSubmit() {
  const isValid = await formRef.value?.validate();

  if (!isValid) return;

  emit('submit', {
    id: form.id,
    name: form.name,
    order_for: form.order_for,
    billing_profile_id: form.billing_profile_id,
    note: form.note,
    vendor_code: form.vendor_code,
    market_code: form.market_code,
  });

  emit('update:modelValue', false);
}

function onDialogHide() {
  fillForm(props.data);
}
</script>
