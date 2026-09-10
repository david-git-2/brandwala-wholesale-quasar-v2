<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="create-customer-dialog">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-subtitle1 text-weight-bold">Create customer</div>
        <q-space />
        <q-btn v-close-popup icon="ph ph-x" flat round dense aria-label="Close" />
      </q-card-section>

      <q-card-section class="q-pt-md column q-gutter-y-md">
        <div>
          <label class="text-weight-medium text-grey-8 q-mb-xs block">Phone *</label>
          <div class="row no-wrap q-gutter-sm">
            <q-select
              v-model="countryDial"
              outlined
              dense
              emit-value
              map-options
              use-input
              input-debounce="0"
              :options="filteredCountries"
              class="country-select"
              data-test="create-customer-country"
              @filter="filterCountries"
              @update:model-value="onPhoneChanged"
            />
            <q-input
              :model-value="phoneNational"
              outlined
              dense
              class="col"
              placeholder="National number — press Enter"
              inputmode="tel"
              data-test="create-customer-phone"
              :loading="isCheckingPhone"
              @update:model-value="onPhoneNationalInput"
              @keyup.enter.prevent="checkPhone"
              @blur="checkPhone"
            />
          </div>
          <q-banner
            v-if="phoneConflictName"
            dense
            rounded
            class="bg-orange-1 text-grey-9 q-mt-sm"
            data-test="create-customer-phone-conflict"
          >
            A customer already uses this phone:
            <strong>{{ phoneConflictName }}</strong>
          </q-banner>
        </div>

        <div>
          <label class="text-weight-medium text-grey-8 q-mb-xs block">Group / company name *</label>
          <q-input
            v-model="groupName"
            outlined
            dense
            placeholder="Company name — press Enter"
            data-test="create-customer-name"
            :loading="isCheckingName"
            @keyup.enter.prevent="checkName"
            @blur="checkName"
          />
          <q-banner
            v-if="nameConflictName"
            dense
            rounded
            class="bg-orange-1 text-grey-9 q-mt-sm"
            data-test="create-customer-name-conflict"
          >
            A customer group already uses this name:
            <strong>{{ nameConflictName }}</strong>
          </q-banner>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn v-close-popup flat no-caps label="Cancel" />
        <q-btn
          unelevated
          color="primary"
          no-caps
          class="action-btn text-weight-bold"
          label="Create"
          :loading="saving"
          :disable="!canSubmit"
          data-test="create-customer-submit"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { QSelectProps } from 'quasar';
import {
  DEFAULT_PHONE_COUNTRY_DIAL,
  nationalPhoneDigits,
  phoneCountrySelectOptions,
} from 'src/utils/phoneCountryCodes';
import { customerRepository } from '../repositories/customerRepository';

const props = defineProps<{
  modelValue: boolean;
  tenantId: number;
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (
    e: 'create',
    payload: { group_name: string; phone: string; phone_country_code: string },
  ): void;
}>();

const countryDial = ref(DEFAULT_PHONE_COUNTRY_DIAL);
const phoneNational = ref('');
const groupName = ref('');
const phoneConflictName = ref<string | null>(null);
const nameConflictName = ref<string | null>(null);
const isCheckingPhone = ref(false);
const isCheckingName = ref(false);
const filteredCountries = ref(phoneCountrySelectOptions);

const canSubmit = computed(() => {
  return (
    !!groupName.value.trim() &&
    !!nationalPhoneDigits(phoneNational.value) &&
    !phoneConflictName.value &&
    !nameConflictName.value
  );
});

const resetForm = () => {
  countryDial.value = DEFAULT_PHONE_COUNTRY_DIAL;
  phoneNational.value = '';
  groupName.value = '';
  phoneConflictName.value = null;
  nameConflictName.value = null;
  filteredCountries.value = phoneCountrySelectOptions;
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) resetForm();
  },
);

watch([phoneNational, countryDial], () => {
  phoneConflictName.value = null;
});

watch(groupName, () => {
  nameConflictName.value = null;
});

const filterCountries: QSelectProps['onFilter'] = (val, update) => {
  update(() => {
    const needle = val.trim().toLowerCase();
    if (!needle) {
      filteredCountries.value = phoneCountrySelectOptions;
      return;
    }
    filteredCountries.value = phoneCountrySelectOptions.filter(
      (row) =>
        row.dial.toLowerCase().includes(needle) ||
        row.name.toLowerCase().includes(needle),
    );
  });
};

const onPhoneNationalInput = (val: string | number | null) => {
  phoneNational.value = nationalPhoneDigits(String(val ?? ''));
};

const onPhoneChanged = () => {
  phoneConflictName.value = null;
};

const checkPhone = async () => {
  const phone = nationalPhoneDigits(phoneNational.value);
  if (!phone || !props.tenantId) {
    phoneConflictName.value = null;
    return;
  }
  isCheckingPhone.value = true;
  try {
    const result = await customerRepository.findCreateConflict(props.tenantId, {
      phone,
      phone_country_code: countryDial.value,
    });
    phoneConflictName.value = result.phone_group_name;
  } finally {
    isCheckingPhone.value = false;
  }
};

const checkName = async () => {
  const name = groupName.value.trim();
  if (!name || !props.tenantId) {
    nameConflictName.value = null;
    return;
  }
  isCheckingName.value = true;
  try {
    const taken = await customerRepository.isGroupNameTaken(props.tenantId, name);
    nameConflictName.value = taken ? name : null;
  } finally {
    isCheckingName.value = false;
  }
};

const onSubmit = async () => {
  await checkPhone();
  await checkName();
  if (!canSubmit.value) return;
  emit('create', {
    group_name: groupName.value.trim(),
    phone: nationalPhoneDigits(phoneNational.value),
    phone_country_code: countryDial.value,
  });
};
</script>

<style scoped>
.create-customer-dialog {
  width: min(480px, 92vw);
  border-radius: 12px;
}

.country-select {
  width: 148px;
  flex: 0 0 148px;
}

.action-btn {
  border-radius: 8px;
}
</style>
