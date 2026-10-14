<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: min(480px, 92vw)">
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

        <div class="text-subtitle2 text-weight-medium q-mt-sm">Currency pots</div>
        <div class="text-caption text-grey-7">
          Each pot holds on-hand cash in one currency. BDT is included by default; add more if needed.
        </div>

        <div v-if="potsLoading" class="row items-center q-gutter-sm text-grey-7">
          <q-spinner size="20px" color="primary" />
          <span class="text-caption">Loading pots…</span>
        </div>

        <div v-else class="column q-gutter-y-xs">
          <div
            v-for="(row, index) in potRows"
            :key="row.key"
            class="row items-center q-gutter-xs no-wrap"
          >
            <q-select
              v-model="row.currencyCode"
              :options="currencyOptionsForRow(index)"
              emit-value
              map-options
              outlined
              dense
              class="col"
              label="Currency"
              :disable="row.locked"
            />
            <q-btn
              flat
              round
              dense
              icon="ph ph-trash"
              color="negative"
              aria-label="Remove pot"
              :disable="potRows.length <= 1 || row.locked"
              @click="removePotRow(index)"
            />
          </div>
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-plus"
            label="Add currency pot"
            class="self-start"
            :disable="!canAddPot"
            @click="addPotRow"
          />
        </div>
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
          :disable="!canSave || deleting || potsLoading"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { requestConfirmation, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import {
  CASHBOOK_POINT_KIND_OPTIONS,
  type CashbookPointKind,
} from '../constants/cashbookPointKinds';
import { cashbookRepository, type CashbookPointRow } from '../repositories/cashbookRepository';

type PotRow = {
  key: string;
  currencyCode: string;
  locked: boolean;
};

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

const { data: currenciesData } = useGlobalCurrenciesQuery();

const saving = ref(false);
const deleting = ref(false);
const potsLoading = ref(false);
const potRows = ref<PotRow[]>([]);
let potKeySeq = 0;

const isEdit = computed(() => props.mode === 'edit');

const form = reactive({
  name: '',
  kind: 'drawer' as CashbookPointKind,
  isActive: true,
});

const currencyOptions = computed(() =>
  (currenciesData.value ?? [])
    .filter((c) => c.is_active)
    .map((c) => ({
      label: `${c.code} (${c.symbol})`,
      value: c.code.toUpperCase(),
    })),
);

const selectedCurrencyCodes = computed(() =>
  potRows.value.map((r) => r.currencyCode.trim().toUpperCase()).filter(Boolean),
);

const currencyOptionsForRow = (index: number) => {
  const taken = new Set(selectedCurrencyCodes.value);
  const own = potRows.value[index]?.currencyCode?.toUpperCase();
  if (own) taken.delete(own);
  return currencyOptions.value.filter((o) => !taken.has(o.value));
};

const canAddPot = computed(() => {
  if (!currencyOptions.value.length) return false;
  return selectedCurrencyCodes.value.length < currencyOptions.value.length;
});

const defaultPotRows = (): PotRow[] => [
  { key: `pot-${++potKeySeq}`, currencyCode: 'BDT', locked: false },
];

const resetPotRows = (codes?: string[]) => {
  const list = codes?.length ? codes : ['BDT'];
  potRows.value = list.map((code) => ({
    key: `pot-${++potKeySeq}`,
    currencyCode: code.toUpperCase(),
    locked: false,
  }));
};

const loadPotsForEdit = async () => {
  if (!props.point) {
    resetPotRows();
    return;
  }
  potsLoading.value = true;
  try {
    const pots = await cashbookRepository.listCashbookPointPots(props.point.id);
    if (pots.length) {
      resetPotRows(pots.map((p) => p.currency_code));
    } else {
      resetPotRows(['BDT']);
    }
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Could not load pots.');
    resetPotRows(['BDT']);
  } finally {
    potsLoading.value = false;
  }
};

const resetForm = async () => {
  if (props.mode === 'edit' && props.point) {
    form.name = props.point.name;
    form.kind = props.point.kind;
    form.isActive = props.point.is_active;
    await loadPotsForEdit();
  } else {
    form.name = '';
    form.kind = 'drawer';
    form.isActive = true;
    resetPotRows(['BDT']);
  }
};

watch(
  () => [props.modelValue, props.mode, props.point?.id] as const,
  ([open]) => {
    if (open) void resetForm();
  },
);

const potCurrencyCodesValid = computed(() => {
  const codes = selectedCurrencyCodes.value;
  if (!codes.length) return false;
  return codes.length === new Set(codes).size && codes.every((c) => c.length >= 3);
});

const canSave = computed(
  () =>
    !!props.cashbookAccountId &&
    form.name.trim().length > 0 &&
    potCurrencyCodesValid.value &&
    !saving.value,
);

const close = () => emit('update:modelValue', false);

const addPotRow = () => {
  const next = currencyOptionsForRow(potRows.value.length)[0]?.value;
  if (!next) return;
  potRows.value.push({ key: `pot-${++potKeySeq}`, currencyCode: next, locked: false });
};

const removePotRow = (index: number) => {
  if (potRows.value.length <= 1) return;
  potRows.value.splice(index, 1);
};

const onSubmit = async () => {
  if (!props.cashbookAccountId || !canSave.value) return;
  saving.value = true;
  try {
    const name = form.name.trim();
    const currencyCodes = selectedCurrencyCodes.value;
    if (props.mode === 'add') {
      await cashbookRepository.createCashbookPoint({
        parentTenantId: props.parentTenantId,
        cashbookAccountId: props.cashbookAccountId,
        name,
        kind: form.kind,
        currencyCodes,
      });
      showSuccessNotification('Cash point added.');
    } else if (props.point) {
      await cashbookRepository.updateCashbookPoint(props.point.id, props.cashbookAccountId, {
        name,
        kind: form.kind,
        is_active: form.isActive,
      });
      await cashbookRepository.syncCashbookPointPots(props.parentTenantId, props.point.id, currencyCodes);
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
