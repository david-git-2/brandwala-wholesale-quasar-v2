<template>
  <div>
    <!-- Header Skeleton -->
    <q-card v-if="isLoading" flat class="floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col min-width-0">
            <q-skeleton type="text" width="200px" height="24px" class="q-mb-xs" />
            <q-skeleton type="QInput" width="220px" height="32px" />
          </div>
          <div class="col-auto row q-gutter-xs items-center">
            <q-skeleton type="QBtn" width="110px" height="32px" />
            <q-skeleton type="QBtn" width="90px" height="32px" />
            <q-skeleton type="QBtn" width="32px" height="32px" />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Loaded Header -->
    <q-card v-else flat class="floating-surface hero-surface shadow-1 costing-file-header-card">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col min-width-0">
            <div class="row items-center q-gutter-x-xs no-wrap">
              <template v-if="isEditingName">
                <q-input
                  ref="nameInputRef"
                  v-model="editingNameValue"
                  dense
                  outlined
                  hide-bottom-space
                  autofocus
                  class="text-h6 text-weight-bold name-inline-input col"
                  :loading="savingName"
                  @blur="saveInlineName"
                  @keyup.enter="saveInlineName"
                  @keyup.esc="cancelInlineName"
                />
              </template>
              <div
                v-else
                class="text-h6 text-weight-bold ellipsis cursor-pointer name-inline-edit row items-center q-gutter-x-xs no-wrap"
                :title="$t('product_based_costing.click_to_edit_name')"
                @click="startInlineNameEdit"
              >
                <span class="ellipsis">{{ file?.name ?? $t('product_based_costing.costing_file_default') }}</span>
                <q-icon name="ph ph-pencil-simple" size="14px" class="edit-icon text-grey-6 flex-shrink-0" />
              </div>
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
                    class="square-btn q-px-sm q-mt-xs"
                    @click="openCreateBillingProfileDialog"
                  />
                </q-item>
              </template>
            </q-select>
          </div>

          <div class="col-auto row q-gutter-xs items-center flex-shrink-0 header-actions">
            <q-btn
              color="primary"
              unelevated
              no-caps
              size="sm"
              icon="ph ph-plus"
              :label="$t('product_based_costing.add_products')"
              class="square-btn slim-btn"
              @click="$emit('open-catalog')"
            />
            <q-btn
              outline
              color="primary"
              no-caps
              size="sm"
              icon="ph ph-columns"
              :label="$t('product_based_costing.columns')"
              class="square-btn slim-btn"
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
                no-caps
                size="sm"
                icon="ph ph-file-pdf"
                :label="$t('product_based_costing.offer_pdf_screenshot')"
                class="square-btn slim-btn"
                :disable="itemCount === 0"
                @click="$emit('open-preview')"
              />
              <q-tooltip v-if="itemCount === 0">{{
                $t('product_based_costing.add_product_first_tooltip')
              }}</q-tooltip>
            </span>
            <q-btn
              outline
              color="primary"
              no-caps
              size="sm"
              icon="ph ph-sparkle"
              label="V2 View"
              class="square-btn slim-btn"
              @click="goToV2"
            >
              <q-tooltip>Open experimental V2 details view</q-tooltip>
            </q-btn>
            <q-btn
              flat
              dense
              icon="ph ph-dots-three-vertical"
              class="square-btn icon-only-btn"
              :aria-label="$t('product_based_costing.more_file_actions')"
            >
              <q-tooltip>{{ $t('product_based_costing.more_file_actions') }}</q-tooltip>
              <q-menu style="min-width: 200px">
                <q-list dense>
                  <q-item clickable v-close-popup @click="goToV2">
                    <q-item-section avatar>
                      <q-icon name="ph ph-sparkle" color="primary" />
                    </q-item-section>
                    <q-item-section>Switch to V2 View</q-item-section>
                  </q-item>
                  <q-separator />
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
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
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

const router = useRouter();

function goToV2() {
  if (!props.file?.id) return;
  const tenantSlug = tenantStore.selectedTenant?.slug;
  if (tenantSlug) {
    void router.push({
      name: 'product-based-costing-file-details-v2-page',
      params: { tenantSlug, id: props.file.id },
    });
  } else {
    void router.push({
      name: 'product-based-costing-file-details-v2-page',
      params: { id: props.file.id },
    });
  }
}
</script>

<style scoped lang="scss">
.costing-file-header-card {
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

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.icon-only-btn {
  min-width: 32px;
  padding: 0;
}
</style>
