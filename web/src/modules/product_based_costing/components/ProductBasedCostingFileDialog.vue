<template>
  <q-dialog v-model="localOpen" persistent @hide="onDialogHide">
    <q-card style="min-width: 500px; max-width: 90vw">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6">
          {{
            isEditMode
              ? $t('product_based_costing.edit_costing_file')
              : $t('product_based_costing.create_file')
          }}
        </div>

        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-separator />

      <q-card-section>
        <q-form ref="formRef" @submit.prevent="handleSubmit" class="q-gutter-md">
          <q-input
            v-model="form.name"
            :label="$t('product_based_costing.col_name')"
            outlined
            dense
            clearable
            :rules="[(val) => !!val || $t('product_based_costing.name_required')]"
          />

          <q-select
            v-model="selectedProfile"
            :options="profileOptions"
            option-label="name"
            option-value="id"
            :label="$t('product_based_costing.billing_profile_customer')"
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
              <q-item dense class="column items-center q-py-md q-gutter-y-xs">
                <div class="text-caption text-grey-7">
                  {{ $t('product_based_costing.no_billing_profiles') }}
                </div>
                <q-btn
                  color="primary"
                  unelevated
                  dense
                  no-caps
                  size="sm"
                  icon="ph ph-plus"
                  :label="$t('product_based_costing.create_billing_profile')"
                  class="q-px-sm q-mt-xs"
                  @click="openCreateBillingProfileDialog"
                />
              </q-item>
            </template>
          </q-select>

          <q-input
            v-model="form.order_for"
            :label="$t('product_based_costing.col_created_for')"
            :hint="$t('product_based_costing.created_for_pdf_hint')"
            outlined
            dense
            clearable
            :rules="[(val) => !!val || $t('product_based_costing.created_for_required')]"
          />

          <q-input
            v-model="form.note"
            :label="$t('product_based_costing.note')"
            type="textarea"
            autogrow
            outlined
            dense
          />
        </q-form>
      </q-card-section>

      <q-separator />

      <q-card-actions align="right">
        <q-btn flat :label="$t('product_based_costing.cancel')" color="grey-7" v-close-popup />
        <q-btn
          unelevated
          color="primary"
          :label="
            isEditMode ? $t('product_based_costing.update') : $t('product_based_costing.create')
          "
          @click="handleSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch, ref } from 'vue';
import { useQuasar } from 'quasar';
import { useI18n } from 'vue-i18n';
import {
  type BillingProfile,
} from 'src/modules/sales_invoice/repositories/billingProfileRepository';
import { useBillingProfilesQuery } from 'src/modules/sales_invoice/composables/useBillingProfileQuery';
import { useBillingProfileMutations } from 'src/modules/sales_invoice/composables/useBillingProfileMutations';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

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

const $q = useQuasar();
const { t } = useI18n();
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
const profileSearchText = ref('');

const isEditMode = computed(() => !!props.data?.id);

const localOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
});

const tenantStore = useTenantStore();
const tenantIdRef = computed(() => tenantStore.selectedTenant?.id);
const { data: billingProfilesResult, isLoading: loadingProfiles } = useBillingProfilesQuery(tenantIdRef);
const { createBillingProfileMutation } = useBillingProfileMutations();

const allProfiles = computed(() => billingProfilesResult.value?.data ?? []);
const profileOptions = ref<BillingProfile[]>([]);

watch(
  allProfiles,
  (profiles) => {
    profileOptions.value = profiles;
    syncSelectedProfile();
  },
  { immediate: true },
);

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
  profileSearchText.value = val;
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

function openCreateBillingProfileDialog() {
  $q.dialog({
    title: t('product_based_costing.create_billing_profile_title'),
    message: t('product_based_costing.create_billing_profile_message'),
    prompt: {
      model: profileSearchText.value.trim(),
      type: 'text',
      label: t('product_based_costing.profile_name'),
      isValid: (val) => Boolean(val && val.trim().length > 0),
    },
    cancel: true,
    persistent: true,
  }).onOk((name: string) => {
    void (async () => {
      const tenantId = tenantStore.selectedTenant?.id;
      if (!tenantId) {
        showErrorNotification(t('product_based_costing.no_active_tenant'));
        return;
      }
      try {
        const created = await createBillingProfileMutation.mutateAsync({
          tenant_id: tenantId,
          name: name.trim(),
        });
        showSuccessNotification(t('product_based_costing.billing_profile_created', { name: created.name }));
        selectedProfile.value = created;
        onProfileChange(created);
      } catch (err: unknown) {
        showErrorNotification(
          err instanceof Error ? err.message : t('product_based_costing.create_billing_profile_failed'),
        );
      }
    })();
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
