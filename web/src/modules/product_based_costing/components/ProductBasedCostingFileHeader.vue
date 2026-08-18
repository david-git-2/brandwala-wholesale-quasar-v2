<template>
  <div>
    <!-- Header Skeleton -->
    <section v-if="isLoading" class="row items-center justify-between q-col-gutter-sm">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-skeleton type="QBtn" size="28px" flat />
          <div>
            <q-skeleton type="text" width="110px" height="10px" class="q-mb-xs" />
            <q-skeleton type="text" width="160px" height="22px" />
            <q-skeleton type="text" width="180px" height="32px" class="q-mt-xs" />
          </div>
        </div>
      </div>
      <div class="col-auto row q-gutter-xs items-center">
        <q-skeleton type="QBtn" width="100px" height="32px" />
        <q-skeleton type="QBtn" width="32px" height="32px" />
      </div>
    </section>

    <!-- Loaded Header -->
    <section v-else class="row items-center justify-between q-col-gutter-sm costing-file-header">
      <div class="col">
        <div class="row items-center q-gutter-x-sm no-wrap">
          <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="$emit('go-back')" />
          <div class="col">
            <div class="text-caption text-primary text-weight-medium">
              {{ $t('product_based_costing.title') }}
            </div>
            <div class="row items-center q-gutter-x-xs">
              <template v-if="isEditingName">
                <q-input
                  ref="nameInputRef"
                  v-model="editingNameValue"
                  dense
                  outlined
                  hide-bottom-space
                  autofocus
                  class="text-subtitle1 text-weight-bold name-inline-input"
                  style="min-width: 180px; max-width: 320px;"
                  :loading="savingName"
                  @blur="saveInlineName"
                  @keyup.enter="saveInlineName"
                  @keyup.esc="cancelInlineName"
                />
              </template>
              <h1
                v-else
                class="text-subtitle1 text-weight-bold q-my-none cursor-pointer name-inline-edit row items-center q-gutter-x-xs"
                :title="$t('product_based_costing.click_to_edit_name')"
                @click="startInlineNameEdit"
              >
                <span>{{ file?.name ?? $t('product_based_costing.costing_file_default') }}</span>
                <q-icon name="ph ph-pencil-simple" size="14px" class="q-ml-xs edit-icon text-grey-6" />
              </h1>
            </div>
            <q-select
              v-model="selectedBillingProfile"
              :options="billingProfileOptions"
              option-label="name"
              option-value="id"
              :label="$t('product_based_costing.billing_profile')"
              dense
              outlined
              hide-bottom-space
              clearable
              use-input
              input-debounce="300"
              :loading="loadingProfiles || savingBillingProfile"
              class="billing-profile-select q-mt-xs"
              @filter="filterBillingProfiles"
              @update:model-value="onBillingProfileChange"
            >
              <template #option="scope">
                <q-item v-bind="scope.itemProps" dense class="rounded-borders q-my-xs">
                  <q-item-section avatar style="min-width: 28px">
                    <q-icon name="ph ph-user text-primary" size="16px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-medium">{{ scope.opt.name }}</q-item-label>
                    <q-item-label v-if="scope.opt.email" caption class="text-grey-6">{{ scope.opt.email }}</q-item-label>
                  </q-item-section>
                </q-item>
              </template>

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
          </div>
        </div>
      </div>
      <div class="col-auto row q-gutter-xs items-center">
        <q-btn
          color="primary"
          unelevated
          dense
          no-caps
          icon="ph ph-plus"
          :label="$t('product_based_costing.add_products')"
          @click="$emit('open-catalog')"
        />
        <q-btn
          outline
          color="primary"
          dense
          no-caps
          icon="ph ph-columns"
          :label="$t('product_based_costing.columns')"
        >
          <q-menu>
            <q-list style="min-width: 260px; max-height: 400px" class="q-pa-xs">
              <q-item class="q-pb-none">
                <q-item-section>
                  <div class="text-subtitle2 q-mb-xs">{{ $t('product_based_costing.show_columns') }}</div>
                  <q-input
                    v-model="columnSearchQuery"
                    dense
                    outlined
                    :placeholder="$t('product_based_costing.search_columns')"
                    clearable
                  >
                    <template #prepend>
                      <q-icon name="ph ph-magnifying-glass" size="16px" />
                    </template>
                  </q-input>
                </q-item-section>
              </q-item>
              <q-item clickable class="q-py-xs">
                <q-item-section>
                  <q-checkbox
                    v-model="allSelectableColumnsSelected"
                    :label="$t('product_based_costing.select_deselect_all')"
                  />
                </q-item-section>
              </q-item>
              <q-separator class="q-my-xs" />
              <q-item class="q-py-none">
                <q-item-section>
                  <div v-if="!filteredColumnSelectorOptions.length" class="text-caption text-grey-6 q-pa-sm">
                    {{ $t('product_based_costing.no_matching_columns') }}
                  </div>
                  <q-option-group
                    v-else
                    v-model="localVisibleColumns"
                    type="checkbox"
                    :options="filteredColumnSelectorOptions"
                  />
                </q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
        <span>
          <q-btn
            outline
            color="primary"
            dense
            no-caps
            icon="ph ph-file-pdf"
            :label="$t('product_based_costing.offer_pdf_screenshot')"
            :disable="itemCount === 0"
            @click="$emit('open-preview')"
          />
          <q-tooltip v-if="itemCount === 0">{{
            $t('product_based_costing.add_product_first_tooltip')
          }}</q-tooltip>
        </span>
        <q-btn
          flat
          dense
          icon="ph ph-dots-three-vertical"
          :aria-label="$t('product_based_costing.more_file_actions')"
        >
          <q-tooltip>{{ $t('product_based_costing.more_file_actions') }}</q-tooltip>
          <q-menu style="min-width: 200px">
            <q-list dense>
              <q-item clickable v-close-popup @click="$emit('open-edit-file')">
                <q-item-section avatar>
                  <q-icon name="ph ph-pencil-simple" />
                </q-item-section>
                <q-item-section>{{ $t('product_based_costing.edit_file_details') }}</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="$emit('open-bulk-paste')">
                <q-item-section avatar>
                  <q-icon name="ph ph-clipboard" />
                </q-item-section>
                <q-item-section>{{ $t('product_based_costing.bulk_paste') }}</q-item-section>
              </q-item>
              <q-separator />
              <q-item clickable v-close-popup @click="$emit('download-excel')">
                <q-item-section avatar>
                  <q-icon name="ph ph-table" />
                </q-item-section>
                <q-item-section>{{ $t('product_based_costing.download_excel') }}</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useI18n } from 'vue-i18n';
import type { ProductBasedCostingFile } from '../types';
import type { BillingProfile } from 'src/modules/sales_invoice/repositories/billingProfileRepository';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useBillingProfileMutations } from 'src/modules/sales_invoice/composables/useBillingProfileMutations';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import {
  alwaysVisibleColumns,
  columnSelectorOptions,
} from '../composables/useProductBasedCostingFileDetailsState';

const props = withDefaults(
  defineProps<{
    file: ProductBasedCostingFile | null;
    isLoading: boolean;
    visibleColumns: string[];
    allBillingProfiles: BillingProfile[];
    loadingProfiles: boolean;
    savingBillingProfile: boolean;
    itemCount?: number;
  }>(),
  { itemCount: 0 },
);

const emit = defineEmits<{
  (e: 'go-back'): void;
  (e: 'open-create-item'): void;
  (e: 'open-edit-file'): void;
  (e: 'open-bulk-paste'): void;
  (e: 'open-catalog'): void;
  (e: 'open-preview'): void;
  (e: 'download-excel'): void;
  (e: 'update:visibleColumns', columns: string[]): void;
  (e: 'save-inline-name', name: string): void;
  (e: 'update-billing-profile', profile: BillingProfile | null): void;
}>();

const $q = useQuasar();
const { t } = useI18n();
const tenantStore = useTenantStore();
const { createBillingProfileMutation } = useBillingProfileMutations();
const billingProfileSearchText = ref('');

const isEditingName = ref(false);
const editingNameValue = ref('');
const savingName = ref(false);
const nameInputRef = ref<HTMLInputElement | { focus: () => void; select: () => void } | null>(null);

const selectedBillingProfile = ref<BillingProfile | null>(null);
const billingProfileOptions = ref<BillingProfile[]>([]);

const localVisibleColumns = computed({
  get: () => props.visibleColumns,
  set: (val: string[]) => emit('update:visibleColumns', val),
});

const columnSearchQuery = ref('');
const filteredColumnSelectorOptions = computed(() => {
  const query = columnSearchQuery.value.trim().toLowerCase();
  if (!query) return columnSelectorOptions;
  return localizedColumnSelectorOptions.value.filter((opt) =>
    opt.label.toLowerCase().includes(query),
  );
});

const localizedColumnSelectorOptions = computed(() =>
  columnSelectorOptions.map((option) => ({
    ...option,
    label: t(`product_based_costing.table_col_${option.value}`),
  })),
);

const selectableColumnValues = localizedColumnSelectorOptions.value.map((option) => option.value);

const allSelectableColumnsSelected = computed({
  get: () => selectableColumnValues.every((value) => localVisibleColumns.value.includes(value)),
  set: (checked: boolean) => {
    emit(
      'update:visibleColumns',
      checked ? [...alwaysVisibleColumns, ...selectableColumnValues] : [...alwaysVisibleColumns],
    );
  },
});

watch(
  () => props.allBillingProfiles,
  (profiles) => {
    billingProfileOptions.value = profiles;
    syncSelectedBillingProfile();
  },
  { immediate: true },
);

watch(
  () => props.file?.billing_profile_id,
  () => {
    syncSelectedBillingProfile();
  },
  { immediate: true },
);

function syncSelectedBillingProfile() {
  if (props.file?.billing_profile_id) {
    const found = props.allBillingProfiles.find((p) => p.id === props.file?.billing_profile_id);
    if (found) {
      selectedBillingProfile.value = found;
      return;
    }
  }
  selectedBillingProfile.value = null;
}

function filterBillingProfiles(val: string, update: (fn: () => void) => void) {
  billingProfileSearchText.value = val;
  update(() => {
    if (!val.trim()) {
      billingProfileOptions.value = props.allBillingProfiles;
    } else {
      const needle = val.toLowerCase();
      billingProfileOptions.value = props.allBillingProfiles.filter(
        (p) =>
          p.name.toLowerCase().includes(needle) ||
          (p.email && p.email.toLowerCase().includes(needle)),
      );
    }
  });
}

function openCreateBillingProfileDialog() {
  $q.dialog({
    title: t('product_based_costing.create_billing_profile_title'),
    message: t('product_based_costing.create_billing_profile_message'),
    prompt: {
      model: billingProfileSearchText.value.trim(),
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
        showSuccessNotification(
          t('product_based_costing.billing_profile_created', { name: created.name }),
        );
        onBillingProfileChange(created);
      } catch (err: unknown) {
        showErrorNotification(
          err instanceof Error ? err.message : t('product_based_costing.create_billing_profile_failed'),
        );
      }
    })();
  });
}

function startInlineNameEdit() {
  editingNameValue.value = props.file?.name ?? '';
  isEditingName.value = true;
  void nextTick(() => {
    if (nameInputRef.value && 'focus' in nameInputRef.value) {
      nameInputRef.value.focus();
    }
  });
}

function cancelInlineName() {
  isEditingName.value = false;
  editingNameValue.value = '';
}

function saveInlineName() {
  if (!isEditingName.value || savingName.value) return;
  const trimmed = editingNameValue.value.trim();
  const currentName = props.file?.name ?? '';

  if (!trimmed || trimmed === currentName) {
    cancelInlineName();
    return;
  }

  savingName.value = true;
  emit('save-inline-name', trimmed);
  isEditingName.value = false;
  savingName.value = false;
}

function onBillingProfileChange(val: BillingProfile | null) {
  emit('update-billing-profile', val);
}
</script>

<style scoped lang="scss">
.costing-file-header {
  min-width: 0;
}

.billing-profile-select {
  min-width: 200px;
  max-width: 280px;
}

.name-inline-edit {
  border-bottom: 1px dashed transparent;
  transition: all 0.2s ease;
  border-radius: 4px;
  padding: 0 2px;
}

.name-inline-edit:hover {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.06);
  border-bottom-color: var(--q-primary);
}
</style>
