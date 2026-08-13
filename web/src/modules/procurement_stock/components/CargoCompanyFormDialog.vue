<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: 520px; max-width: 90vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">{{ isEdit ? 'Edit cargo company' : 'Add cargo company' }}</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-form @submit.prevent="onSubmit">
        <q-card-section class="q-gutter-y-md">
          <q-input
            v-model="form.name"
            label="Name *"
            dense
            outlined
            class="soft-input"
            :rules="[(v) => !!String(v || '').trim() || 'Name is required']"
          >
            <template #prepend>
              <q-icon name="ph ph-truck" />
            </template>
          </q-input>

          <q-input
            v-model="form.code"
            label="Code *"
            dense
            outlined
            class="soft-input"
            maxlength="40"
            :disable="codeLocked"
            :loading="checkingCode"
            :hint="codeLocked ? 'System default code cannot be changed' : 'Unique per tenant'"
            :rules="[(v) => !!String(v || '').trim() || 'Code is required']"
            @update:model-value="onCodeInput"
          >
            <template #prepend>
              <q-icon name="ph ph-identification-badge" />
            </template>
            <template #append>
              <q-icon
                v-if="normalizedCode && !checkingCode && codeAvailable === true && !codeLocked"
                name="ph ph-check-circle"
                color="positive"
              />
              <q-icon
                v-else-if="normalizedCode && !checkingCode && codeAvailable === false"
                name="ph ph-warning-circle"
                color="negative"
              />
            </template>
          </q-input>

          <q-banner
            v-if="normalizedCode === 'DEFAULT' && !codeLocked"
            rounded
            class="bg-warning text-dark"
          >
            Code DEFAULT is reserved for the system default.
          </q-banner>

          <q-banner
            v-else-if="normalizedCode && !checkingCode && codeAvailable === false"
            rounded
            class="bg-negative text-white"
          >
            This code is already in use.
          </q-banner>

          <q-input v-model="form.email" label="Email" dense outlined class="soft-input">
            <template #prepend>
              <q-icon name="ph ph-envelope-simple" />
            </template>
          </q-input>
          <q-input v-model="form.phone" label="Phone" dense outlined class="soft-input">
            <template #prepend>
              <q-icon name="ph ph-phone" />
            </template>
          </q-input>
          <q-input
            v-model="form.address"
            label="Address"
            type="textarea"
            autogrow
            dense
            outlined
            class="soft-input"
          >
            <template #prepend>
              <q-icon name="ph ph-map-pin" />
            </template>
          </q-input>
          <q-input
            v-model="form.notes"
            label="Notes"
            type="textarea"
            autogrow
            dense
            outlined
            class="soft-input"
          />
          <q-toggle
            v-if="isEdit && !initialData?.is_default"
            v-model="form.is_active"
            label="Active"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
          <q-btn
            type="submit"
            color="primary"
            unelevated
            no-caps
            :label="isEdit ? 'Save' : 'Add'"
            :loading="saving"
            :disable="!canSubmit"
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import type { CargoCompany } from '../types/cargoCompany';

type FormState = {
  name: string;
  code: string;
  email: string;
  phone: string;
  address: string;
  notes: string;
  is_active: boolean;
};

const props = defineProps<{
  modelValue: boolean;
  initialData?: CargoCompany | null;
  tenantId: number;
  saving?: boolean;
  checkCodeAvailability: (code: string, excludeId?: number | null) => Promise<boolean>;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (
    e: 'save',
    value: {
      id?: number;
      name: string;
      code: string;
      email: string | null;
      phone: string | null;
      address: string | null;
      notes: string | null;
      is_active?: boolean;
    },
  ): void;
}>();

const form = reactive<FormState>({
  name: '',
  code: '',
  email: '',
  phone: '',
  address: '',
  notes: '',
  is_active: true,
});

const checkingCode = ref(false);
const codeAvailable = ref<boolean | null>(null);
const originalCode = ref('');
let debounceTimer: ReturnType<typeof setTimeout> | null = null;

const isEdit = computed(() => typeof props.initialData?.id === 'number');
const codeLocked = computed(() => Boolean(props.initialData?.is_default));
const normalizedCode = computed(() => form.code.trim().toUpperCase());
const canSubmit = computed(
  () =>
    Boolean(form.name.trim()) &&
    Boolean(normalizedCode.value) &&
    normalizedCode.value !== 'DEFAULT' &&
    !checkingCode.value &&
    codeAvailable.value !== false,
);

const normalizeCode = (value: string) =>
  value
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9_-]/g, '');

const onCodeInput = () => {
  form.code = normalizeCode(form.code);
};

const runCodeCheck = () => {
  if (!normalizedCode.value || codeLocked.value) {
    codeAvailable.value = codeLocked.value ? true : null;
    return;
  }
  if (isEdit.value && normalizedCode.value === originalCode.value) {
    codeAvailable.value = true;
    return;
  }
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    void (async () => {
      checkingCode.value = true;
      try {
        codeAvailable.value = await props.checkCodeAvailability(
          normalizedCode.value,
          props.initialData?.id ?? null,
        );
      } catch {
        codeAvailable.value = null;
      } finally {
        checkingCode.value = false;
      }
    })();
  }, 300);
};

watch(
  () => [props.modelValue, props.initialData] as const,
  ([open]) => {
    if (!open) return;
    form.name = props.initialData?.name ?? '';
    form.code = props.initialData?.code ?? '';
    form.email = props.initialData?.email ?? '';
    form.phone = props.initialData?.phone ?? '';
    form.address = props.initialData?.address ?? '';
    form.notes = props.initialData?.notes ?? '';
    form.is_active = props.initialData?.is_active ?? true;
    originalCode.value = (props.initialData?.code ?? '').toUpperCase();
    codeAvailable.value = isEdit.value ? true : null;
  },
);

watch(normalizedCode, () => {
  if (props.modelValue) runCodeCheck();
});

const onSubmit = () => {
  if (!canSubmit.value) return;
  emit('save', {
    id: props.initialData?.id,
    name: form.name.trim(),
    code: normalizedCode.value,
    email: form.email.trim() || null,
    phone: form.phone.trim() || null,
    address: form.address.trim() || null,
    notes: form.notes.trim() || null,
    ...(isEdit.value ? { is_active: form.is_active } : {}),
  });
};
</script>
