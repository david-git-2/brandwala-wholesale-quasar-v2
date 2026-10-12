<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: min(440px, 92vw)">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">{{ isEdit ? 'Edit cash point' : 'Add cash point' }}</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-card-section class="column q-gutter-y-sm q-pt-sm">
        <q-input v-model="form.name" outlined dense label="Name" autofocus />
        <q-select
          v-model="form.kind"
          :options="CASHBOOK_POINT_KIND_OPTIONS"
          emit-value
          map-options
          outlined
          dense
          label="Kind"
        />
        <q-checkbox v-if="isEdit" v-model="form.isActive" dense label="Active" />
      </q-card-section>

      <q-card-actions class="q-px-md q-pb-md row items-center">
        <q-btn
          v-if="isEdit"
          flat
          no-caps
          color="negative"
          icon="ph ph-trash"
          label="Delete"
          :loading="deleting"
          :disable="saving"
          @click="onDelete"
        />
        <q-space v-if="isEdit" />
        <q-btn flat no-caps label="Cancel" :disable="saving || deleting" @click="close" />
        <q-btn
          color="primary"
          unelevated
          no-caps
          :label="isEdit ? 'Save' : 'Add'"
          :loading="saving"
          :disable="!canSave || deleting"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { requestConfirmation, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import {
  CASHBOOK_POINT_KIND_OPTIONS,
  type CashbookPointKind,
} from '../constants/cashbookPointKinds';
import { cashbookRepository, type CashbookPointRow } from '../repositories/cashbookRepository';

const props = defineProps<{
  modelValue: boolean;
  mode: 'add' | 'edit';
  point: CashbookPointRow | null;
  cashbookAccountId: number | null;
  parentTenantId: number;
  operatingTenantId: number;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  saved: [];
}>();

const saving = ref(false);
const deleting = ref(false);
const isEdit = computed(() => props.mode === 'edit');

const form = reactive({
  name: '',
  kind: 'drawer' as CashbookPointKind,
  isActive: true,
});

const resetForm = () => {
  if (props.mode === 'edit' && props.point) {
    form.name = props.point.name;
    form.kind = props.point.kind;
    form.isActive = props.point.is_active;
  } else {
    form.name = '';
    form.kind = 'drawer';
    form.isActive = true;
  }
};

watch(
  () => [props.modelValue, props.mode, props.point?.id] as const,
  ([open]) => {
    if (open) resetForm();
  },
);

const canSave = computed(
  () => !!props.cashbookAccountId && form.name.trim().length > 0 && !saving.value,
);

const close = () => emit('update:modelValue', false);

const onSubmit = async () => {
  if (!props.cashbookAccountId || !canSave.value) return;
  saving.value = true;
  try {
    const name = form.name.trim();
    if (props.mode === 'add') {
      await cashbookRepository.createCashbookPoint({
        parentTenantId: props.parentTenantId,
        cashbookAccountId: props.cashbookAccountId,
        name,
        kind: form.kind,
      });
      showSuccessNotification('Cash point added.');
    } else if (props.point) {
      await cashbookRepository.updateCashbookPoint(props.point.id, props.cashbookAccountId, {
        name,
        kind: form.kind,
        is_active: form.isActive,
      });
      showSuccessNotification('Cash point updated.');
    }
    emit('saved');
    close();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Could not save point.');
  } finally {
    saving.value = false;
  }
};

const onDelete = async () => {
  if (!props.cashbookAccountId || !props.point) return;
  const ok = await requestConfirmation(
    'Ledger lines keep their history; only the point tag is cleared.',
    `Delete “${props.point.name}”?`,
    'Delete',
  );
  if (!ok) return;
  deleting.value = true;
  try {
    await cashbookRepository.deleteCashbookPoint(props.operatingTenantId, props.point.id);
    showSuccessNotification('Cash point deleted.');
    emit('saved');
    close();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Could not delete point.');
  } finally {
    deleting.value = false;
  }
};
</script>
