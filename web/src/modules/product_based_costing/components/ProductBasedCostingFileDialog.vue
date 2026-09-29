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
            v-model="selectedCustomer"
            :options="customerOptions"
            option-label="group_name"
            :label="$t('product_based_costing.customer')"
            outlined
            dense
            clearable
            use-input
            input-debounce="300"
            :loading="loadingCustomers"
            :rules="[
              (val) => !!val || $t('product_based_costing.customer_required'),
            ]"
            @filter="filterCustomers"
            @update:model-value="onCustomerChange"
          >
            <template #no-option>
              <q-item dense class="column items-center q-py-md q-gutter-y-xs">
                <div class="text-caption text-grey-7">
                  {{ $t('product_based_costing.no_customers') }}
                </div>
                <q-btn
                  color="primary"
                  unelevated
                  dense
                  no-caps
                  size="sm"
                  icon="ph ph-plus"
                  :label="$t('product_based_costing.create_customer')"
                  class="q-px-sm q-mt-xs"
                  @click="showCreateCustomerDialog = true"
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

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.buy_currency_id"
                :options="currencyOptions"
                :label="$t('product_based_costing.buy_currency_label')"
                outlined
                dense
                emit-value
                map-options
                :loading="loadingCurrencies"
                :rules="[(val) => val != null || $t('product_based_costing.buy_currency_label')]"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.sell_currency_id"
                :options="currencyOptions"
                :label="$t('product_based_costing.sell_currency_label')"
                outlined
                dense
                emit-value
                map-options
                :loading="loadingCurrencies"
                :rules="[(val) => val != null || $t('product_based_costing.sell_currency_label')]"
              />
            </div>
          </div>

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

    <CreateCustomerDialog
      v-if="tenantId"
      v-model="showCreateCustomerDialog"
      :tenant-id="tenantId"
      :saving="createCustomerMutation.isPending.value"
      @create="handleCreateCustomer"
    />
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { customerRepository } from 'src/modules/customer/repositories/customerRepository';
import { useCustomerMutations } from 'src/modules/customer/composables/useCustomerQuery';
import CreateCustomerDialog from 'src/modules/customer/components/CreateCustomerDialog.vue';
import type { CustomerAccount } from 'src/modules/customer/types/customer';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';

interface CostingFileForm {
  id: number | null;
  name: string;
  order_for: string;
  customer_group_id: number | null;
  note: string;
  vendor_code: string | null;
  market_code: string | null;
  buy_currency_id: number | null;
  sell_currency_id: number | null;
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

const { t } = useI18n();
const formRef = ref<FormRef | null>(null);

const emptyForm = (): CostingFileForm => ({
  id: null,
  name: '',
  order_for: '',
  customer_group_id: null,
  note: '',
  vendor_code: null,
  market_code: null,
  buy_currency_id: null,
  sell_currency_id: null,
});

const form = reactive(emptyForm());
const selectedCustomer = ref<CustomerAccount | null>(null);
const customerOptions = ref<CustomerAccount[]>([]);
const allCustomers = ref<CustomerAccount[]>([]);
const loadingCustomers = ref(false);
const showCreateCustomerDialog = ref(false);

const isEditMode = computed(() => !!props.data?.id);

const localOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
});

const tenantStore = useTenantStore();
const tenantId = computed(() => tenantStore.selectedTenant?.id ?? null);
const { createCustomerMutation } = useCustomerMutations();
const { data: currenciesData, isLoading: loadingCurrencies } = useGlobalCurrenciesQuery();

const currencyOptions = computed(() =>
  (currenciesData.value ?? []).map((c) => ({
    label: `${c.code} (${c.symbol}) - ${c.name}`,
    value: c.id,
  })),
);

function defaultCurrencyIds() {
  const list = currenciesData.value ?? [];
  const gbp = list.find((c) => c.code === 'GBP')?.id ?? null;
  const bdt = list.find((c) => c.code === 'BDT')?.id ?? null;
  return { gbp, bdt };
}

function applyDefaultCurrenciesIfCreate() {
  if (isEditMode.value) return;
  const { gbp, bdt } = defaultCurrencyIds();
  if (form.buy_currency_id == null && gbp != null) {
    form.buy_currency_id = gbp;
  }
  if (form.sell_currency_id == null && bdt != null) {
    form.sell_currency_id = bdt;
  }
}

async function loadCustomers(search?: string) {
  const id = tenantId.value;
  if (!id) {
    allCustomers.value = [];
    customerOptions.value = [];
    return;
  }

  loadingCustomers.value = true;
  try {
    allCustomers.value = await customerRepository.listCustomers(id, search);
    customerOptions.value = allCustomers.value;
    syncSelectedCustomer();
  } catch (err: unknown) {
    showErrorNotification(
      err instanceof Error ? err.message : t('product_based_costing.create_customer_failed'),
    );
  } finally {
    loadingCustomers.value = false;
  }
}

function syncSelectedCustomer() {
  if (form.customer_group_id) {
    const found = allCustomers.value.find(
      (row) => row.customer_group_id === form.customer_group_id,
    );
    if (found) {
      selectedCustomer.value = found;
      return;
    }
  }
  selectedCustomer.value = null;
}

function filterCustomers(val: string, update: (fn: () => void) => void) {
  update(() => {
    if (!val.trim()) {
      customerOptions.value = allCustomers.value;
    } else {
      const needle = val.toLowerCase();
      customerOptions.value = allCustomers.value.filter((row) =>
        row.group_name.toLowerCase().includes(needle),
      );
    }
  });
}

function onCustomerChange(val: CustomerAccount | null) {
  if (val) {
    form.customer_group_id = val.customer_group_id;
    if (!form.order_for || form.order_for.trim() === '') {
      form.order_for = val.group_name;
    }
  } else {
    form.customer_group_id = null;
  }
}

async function handleCreateCustomer(payload: {
  group_name: string;
  phone: string;
  phone_country_code: string;
}) {
  const id = tenantId.value;
  if (!id) {
    showErrorNotification(t('product_based_costing.no_active_tenant'));
    return;
  }

  try {
    const created = await createCustomerMutation.mutateAsync({
      tenant_id: id,
      group_name: payload.group_name,
      phone: payload.phone,
      phone_country_code: payload.phone_country_code,
    });
    showSuccessNotification(
      t('product_based_costing.customer_created', { name: created.group_name }),
    );
    showCreateCustomerDialog.value = false;
    await loadCustomers();
    selectedCustomer.value = created;
    onCustomerChange(created);
  } catch (err: unknown) {
    showErrorNotification(
      err instanceof Error ? err.message : t('product_based_costing.create_customer_failed'),
    );
  }
}

function fillForm(source: CostingFileForm | null) {
  const values = source || emptyForm();

  form.id = values.id ?? null;
  form.name = values.name ?? '';
  form.order_for = values.order_for ?? '';
  form.customer_group_id = values.customer_group_id ?? null;
  form.note = values.note ?? '';
  form.vendor_code = values.vendor_code ?? null;
  form.market_code = values.market_code ?? null;
  form.buy_currency_id = values.buy_currency_id ?? null;
  form.sell_currency_id = values.sell_currency_id ?? null;
  syncSelectedCustomer();
  applyDefaultCurrenciesIfCreate();
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
      void loadCustomers();
      applyDefaultCurrenciesIfCreate();
    }
  },
);

watch(currenciesData, () => {
  if (props.modelValue) {
    applyDefaultCurrenciesIfCreate();
  }
});

async function handleSubmit() {
  const isValid = await formRef.value?.validate();

  if (!isValid) return;

  emit('submit', {
    id: form.id,
    name: form.name,
    order_for: form.order_for,
    customer_group_id: form.customer_group_id,
    note: form.note,
    vendor_code: form.vendor_code,
    market_code: form.market_code,
    buy_currency_id: form.buy_currency_id,
    sell_currency_id: form.sell_currency_id,
  });

  emit('update:modelValue', false);
}

function onDialogHide() {
  fillForm(props.data);
}
</script>
