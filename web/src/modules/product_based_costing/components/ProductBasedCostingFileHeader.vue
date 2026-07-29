<template>
  <div>
    <!-- Header Skeleton -->
    <section v-if="isLoading" class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-skeleton type="QBtn" size="32px" flat />
          <div>
            <q-skeleton type="text" width="130px" height="14px" class="q-mb-xs" />
            <q-skeleton type="text" width="240px" height="32px" />
            <q-skeleton type="text" width="160px" height="14px" class="q-mt-xs" />
          </div>
        </div>
      </div>
      <div class="col-auto row q-gutter-sm items-center">
        <q-skeleton type="QBtn" width="100px" height="36px" />
        <q-skeleton type="QBtn" width="36px" height="36px" />
      </div>
    </section>

    <!-- Loaded Header -->
    <section v-else class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="$emit('go-back')" />
          <div>
            <div class="text-overline text-primary">Product Based Costing</div>
            <div class="row items-center q-gutter-x-xs">
              <template v-if="isEditingName">
                <q-input
                  ref="nameInputRef"
                  v-model="editingNameValue"
                  dense
                  outlined
                  autofocus
                  class="text-h5 text-weight-bold name-inline-input"
                  style="min-width: 220px; max-width: 380px;"
                  :loading="savingName"
                  @blur="saveInlineName"
                  @keyup.enter="saveInlineName"
                  @keyup.esc="cancelInlineName"
                />
              </template>
              <template v-else>
                <h1
                  class="text-h5 text-weight-bold q-my-none cursor-pointer name-inline-edit row items-center q-gutter-x-xs"
                  title="Click to edit name"
                  @click="startInlineNameEdit"
                >
                  <span>{{ file?.name ?? 'Costing File' }}</span>
                  <q-icon name="ph ph-pencil-simple" size="18px" class="q-ml-xs edit-icon text-grey-6" />
                </h1>
              </template>
            </div>
            <div class="row items-center q-gutter-x-xs q-mt-xs text-body2 text-grey-7">
              <span>Created for</span>
              <q-select
                v-model="selectedBillingProfile"
                :options="billingProfileOptions"
                option-label="name"
                option-value="id"
                dense
                borderless
                use-input
                hide-dropdown-icon
                input-debounce="300"
                :loading="loadingProfiles || savingBillingProfile"
                class="billing-profile-select-pill"
                @filter="filterBillingProfiles"
                @update:model-value="onBillingProfileChange"
              >
                <template #selected>
                  <div
                    class="row items-center text-primary text-weight-bold cursor-pointer profile-picker-chip"
                    title="Click to change billing profile"
                  >
                    <q-icon name="ph ph-user-circle" size="16px" class="q-mr-xs" />
                    <span>{{ selectedBillingProfile?.name ?? 'Select Billing Profile' }}</span>
                    <q-icon name="ph ph-caret-down" size="14px" class="q-ml-xs text-primary" />
                  </div>
                </template>

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
                  <q-item dense>
                    <q-item-section class="text-grey caption">No billing profiles found</q-item-section>
                  </q-item>
                </template>
              </q-select>
            </div>
          </div>
        </div>
      </div>
      <div class="col-auto row q-gutter-sm items-center">
        <q-btn
          v-if="file?.billing_profile_id"
          outline
          color="primary"
          no-caps
          icon="ph ph-tray"
          label="Backlog"
          :loading="backlogLoading"
          @click="$emit('open-backlog')"
        >
          <q-badge
            v-if="backlogCount > 0"
            color="orange-9"
            floating
            rounded
          >
            {{ backlogCount }}
          </q-badge>
        </q-btn>
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Add Item"
          @click="$emit('open-create-item')"
        />
        <q-btn flat dense icon="ph ph-dots-three-vertical" aria-label="Actions">
          <q-menu style="min-width: 200px">
            <q-list dense>
              <q-item clickable v-close-popup @click="$emit('open-edit-file')">
                <q-item-section avatar>
                  <q-icon name="ph ph-pencil-simple" />
                </q-item-section>
                <q-item-section>Edit File Details</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="$emit('open-bulk-paste')">
                <q-item-section avatar>
                  <q-icon name="ph ph-clipboard" />
                </q-item-section>
                <q-item-section>Bulk Paste</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="$emit('open-catalog')">
                <q-item-section avatar>
                  <q-icon name="ph ph-shopping-cart" />
                </q-item-section>
                <q-item-section>Add from Catalog</q-item-section>
              </q-item>
              <q-item clickable>
                <q-item-section avatar>
                  <q-icon name="ph ph-columns" />
                </q-item-section>
                <q-item-section>Columns</q-item-section>
                <q-item-section side>
                  <q-icon name="ph ph-caret-right" />
                </q-item-section>
                <q-menu anchor="top end" self="top start">
                  <q-list style="min-width: 240px">
                    <q-item>
                      <q-item-section>
                        <div class="text-subtitle2">Show Columns</div>
                      </q-item-section>
                    </q-item>
                    <q-item clickable>
                      <q-item-section>
                        <q-checkbox
                          v-model="allSelectableColumnsSelected"
                          label="Select / Deselect All"
                        />
                      </q-item-section>
                    </q-item>
                    <q-item>
                      <q-item-section>
                        <q-option-group
                          v-model="localVisibleColumns"
                          type="checkbox"
                          :options="columnSelectorOptions"
                        />
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-item>
              <q-separator />
              <q-item clickable v-close-popup @click="$emit('open-preview')">
                <q-item-section avatar>
                  <q-icon name="ph ph-eye" />
                </q-item-section>
                <q-item-section>Preview & Print</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="$emit('download-excel')">
                <q-item-section avatar>
                  <q-icon name="ph ph-table" />
                </q-item-section>
                <q-item-section>Download Excel</q-item-section>
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
import type { ProductBasedCostingFile } from '../types';
import type { BillingProfile } from 'src/modules/sales_invoice/repositories/billingProfileRepository';
import {
  alwaysVisibleColumns,
  columnSelectorOptions,
} from '../composables/useProductBasedCostingFileDetailsState';

const props = defineProps<{
  file: ProductBasedCostingFile | null;
  isLoading: boolean;
  backlogCount: number;
  backlogLoading: boolean;
  visibleColumns: string[];
  allBillingProfiles: BillingProfile[];
  loadingProfiles: boolean;
  savingBillingProfile: boolean;
}>();

const emit = defineEmits<{
  (e: 'go-back'): void;
  (e: 'open-backlog'): void;
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

const selectableColumnValues = columnSelectorOptions.map((option) => option.value);

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
.name-inline-edit {
  border-bottom: 1px dashed transparent;
  transition: all 0.2s ease;
  border-radius: 4px;
  padding: 2px 4px;
}

.name-inline-edit:hover {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.06);
  border-bottom-color: var(--q-primary);
}

.profile-picker-chip {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.08);
  padding: 2px 10px;
  border-radius: 12px;
  transition: all 0.2s ease;
  border: 1px solid rgba(var(--q-primary-rgb, 15, 98, 254), 0.2);
}

.profile-picker-chip:hover {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.15);
  border-color: var(--q-primary);
}
</style>
