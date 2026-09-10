<template>
  <q-page class="create-customer-page page-fixed-layout q-pa-md" data-test="create-customer-page">
    <div class="column no-wrap full-height">
      <div class="create-toolbar floating-surface shadow-1 q-pa-sm q-mb-md">
        <div class="row items-center q-gutter-sm">
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-left"
            color="grey-8"
            aria-label="Back to customers"
            @click="goBack"
          >
            <q-tooltip>Back to Customers</q-tooltip>
          </q-btn>
          <div class="text-subtitle1 text-weight-bold text-grey-9">
            Create Customer Group
          </div>
        </div>
      </div>

      <div class="col scroll-container flex flex-center">
        <q-form
          ref="formRef"
          class="customer-form-card floating-surface shadow-1 q-pa-lg full-width"
          @submit.prevent="submitForm"
        >
          <div class="section-title text-caption text-uppercase text-weight-bold text-primary q-mb-md">
            Admin email lookup
          </div>

          <div class="email-lookup-wrap q-mb-lg">
            <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Admin email *</label>
            <q-input
              v-model="form.admin_email"
              outlined
              dense
              type="email"
              placeholder="admin@company.com — press Enter to search"
              class="rounded-field"
              :loading="isSearchingEmail"
              data-test="create-customer-admin-email"
              :rules="emailRules"
              @update:model-value="onAdminEmailInput"
              @keyup.enter="onAdminEmailSearch"
              @blur="hideSuggestions"
              @focus="showSuggestions = emailSuggestions.length > 0"
            >
              <template #prepend>
                <q-icon name="ph ph-envelope" size="18px" class="text-grey-6" />
              </template>
              <template #append>
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-magnifying-glass"
                  color="grey-7"
                  aria-label="Search admin email"
                  :loading="isSearchingEmail"
                  @click="onAdminEmailSearch"
                />
              </template>
            </q-input>

            <q-card
              v-if="showSuggestions && emailSuggestions.length"
              flat
              bordered
              class="email-suggestions floating-surface q-mt-xs"
            >
              <q-list dense separator>
                <q-item
                  v-for="suggestion in emailSuggestions"
                  :key="`${suggestion.customer_group_id}-${suggestion.email}`"
                  v-close-popup
                  clickable
                  @click="selectEmailSuggestion(suggestion)"
                >
                  <q-item-section>
                    <q-item-label>{{ suggestion.email }}</q-item-label>
                    <q-item-label caption>
                      Admin of {{ suggestion.group_name }} · {{ suggestion.admin_name }}
                    </q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <span
                      class="customer-group-chip"
                      :style="{ backgroundColor: suggestion.accent_color || '#B45F34' }"
                    />
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card>
          </div>

          <q-banner
            v-if="existingAdminGroup"
            rounded
            class="bg-orange-1 text-grey-9 q-mb-lg"
            data-test="create-customer-existing-admin-banner"
          >
            <template #avatar>
              <q-icon name="ph ph-warning" color="orange-9" />
            </template>
            This email is already admin of
            <strong>{{ existingAdminGroup }}</strong>.
            Use a different admin email to create a new customer group.
          </q-banner>

          <template v-if="isFormEnabled">
            <div class="section-title text-caption text-uppercase text-weight-bold text-primary q-mb-md">
              New customer group
            </div>

            <div class="column q-gutter-y-md">
              <div>
                <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Group / company name *</label>
                <q-input
                  v-model="form.group_name"
                  outlined
                  dense
                  placeholder="e.g. Acme Retailers"
                  class="rounded-field"
                  :rules="[(val) => !!val?.trim() || 'Group name is required']"
                >
                  <template #prepend>
                    <q-icon name="ph ph-buildings" size="18px" class="text-grey-6" />
                  </template>
                </q-input>
              </div>

              <div>
                <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Admin name *</label>
                <q-input
                  v-model="form.admin_name"
                  outlined
                  dense
                  placeholder="e.g. Rahim Chowdhury"
                  class="rounded-field"
                  :rules="[(val) => !!val?.trim() || 'Admin name is required']"
                >
                  <template #prepend>
                    <q-icon name="ph ph-user" size="18px" class="text-grey-6" />
                  </template>
                </q-input>
              </div>

              <div>
                <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Brand accent color *</label>
                <q-input
                  v-model="form.accent_color"
                  outlined
                  dense
                  class="rounded-field q-mb-sm"
                  :rules="[(val) => !!val?.trim() || 'Accent color is required']"
                >
                  <template #prepend>
                    <div
                      class="color-preview-badge shadow-1"
                      :style="{ backgroundColor: form.accent_color || '#B45F34' }"
                    >
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-color v-model="form.accent_color" no-header-tabs />
                      </q-popup-proxy>
                    </div>
                  </template>
                  <template #append>
                    <q-icon name="ph ph-palette" class="cursor-pointer text-grey-6">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-color v-model="form.accent_color" no-header-tabs />
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>

                <div class="row items-center q-gutter-xs q-mt-xs">
                  <span class="text-caption text-grey-6 q-mr-xs">Quick set:</span>
                  <div
                    v-for="color in presetColors"
                    :key="color"
                    class="cursor-pointer preset-swatch shadow-1"
                    :class="{ 'preset-swatch--active': form.accent_color === color }"
                    :style="{ backgroundColor: color }"
                    @click="form.accent_color = color"
                  >
                    <q-tooltip>{{ color }}</q-tooltip>
                  </div>
                </div>
              </div>
            </div>

            <div class="form-actions row items-center justify-end q-gutter-sm q-mt-lg q-pt-md">
              <q-btn
                flat
                no-caps
                label="Cancel"
                color="grey-7"
                class="action-btn text-weight-medium"
                @click="goBack"
              />
              <q-btn
                unelevated
                color="primary"
                icon="ph ph-check"
                label="Create Group"
                no-caps
                type="submit"
                class="action-btn text-weight-bold"
                :loading="isSaving"
                :disable="!canCreate"
              />
            </div>
          </template>

          <div
            v-else-if="!existingAdminGroup && form.admin_email.trim()"
            class="text-caption text-grey-7 q-mt-md"
          >
            Enter a valid admin email that is not already used as a group admin.
          </div>
        </q-form>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerMutations } from '../composables/useCustomerQuery';
import { customerRepository } from '../repositories/customerRepository';
import type { CustomerAccount } from '../types/customer';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const { createCustomerMutation } = useCustomerMutations();

const formRef = ref<{ validate: () => Promise<boolean> } | null>(null);
const isSaving = ref(false);
const isSearchingEmail = ref(false);
const showSuggestions = ref(false);
const emailSuggestions = ref<CustomerAccount[]>([]);
const existingAdminGroup = ref<string | null>(null);

const presetColors = [
  '#B45F34',
  '#2563EB',
  '#059669',
  '#7C3AED',
  '#DB2777',
  '#D97706',
  '#0D9488',
  '#4B5563',
];

const form = reactive({
  admin_email: '',
  group_name: '',
  admin_name: '',
  accent_color: '#B45F34',
});

const emailRules = [
  (val: string) => !!val?.trim() || 'Admin email is required',
  (val: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val?.trim() || '') || 'Enter a valid email',
];

const isValidEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());

const isFormEnabled = computed(
  () => isValidEmail(form.admin_email) && !existingAdminGroup.value && !isSearchingEmail.value,
);

const canCreate = computed(
  () =>
    isFormEnabled.value &&
    !!form.group_name.trim() &&
    !!form.admin_name.trim() &&
    !!form.accent_color.trim() &&
    !isSaving.value,
);

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const goBack = () => {
  void router.push(`${getTenantPrefix()}/app/customers/list`);
};

const resetLookupState = () => {
  existingAdminGroup.value = null;
  emailSuggestions.value = [];
  showSuggestions.value = false;
};

const lookupAdminEmail = async (email: string) => {
  const tenantId = authStore.tenantId;
  if (!tenantId || !isValidEmail(email)) {
    resetLookupState();
    return;
  }

  isSearchingEmail.value = true;
  try {
    const [conflictGroup, suggestions] = await Promise.all([
      customerRepository.findAdminEmailConflict(tenantId, email),
      customerRepository.searchCustomersByAdminEmail(tenantId, email),
    ]);

    existingAdminGroup.value = conflictGroup;
    emailSuggestions.value = suggestions;
    showSuggestions.value = suggestions.length > 0 && !conflictGroup;
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to search admin email.';
    showErrorNotification(message);
    resetLookupState();
  } finally {
    isSearchingEmail.value = false;
  }
};

const onAdminEmailInput = (value: string | number | null) => {
  const email = String(value ?? '');
  if (!email.trim()) {
    resetLookupState();
    return;
  }

  existingAdminGroup.value = null;
  emailSuggestions.value = [];
  showSuggestions.value = false;
};

const onAdminEmailSearch = () => {
  void lookupAdminEmail(form.admin_email);
};

const selectEmailSuggestion = (suggestion: CustomerAccount) => {
  form.admin_email = suggestion.email || '';
  existingAdminGroup.value = suggestion.group_name;
  emailSuggestions.value = [];
  showSuggestions.value = false;
};

const hideSuggestions = () => {
  showSuggestions.value = false;
};

const submitForm = async () => {
  if (!formRef.value || !canCreate.value) return;

  const valid = await formRef.value.validate();
  if (!valid) return;

  const tenantId = authStore.tenantId;
  if (!tenantId) {
    showErrorNotification('Active tenant context not found.');
    return;
  }

  isSaving.value = true;
  try {
    await createCustomerMutation.mutateAsync({
      tenant_id: tenantId,
      group_name: form.group_name.trim(),
      admin_name: form.admin_name.trim(),
      admin_email: form.admin_email.trim(),
      accent_color: form.accent_color.trim() || '#B45F34',
    });

    showSuccessNotification('Customer group, billing profile, and wallet created.');
    goBack();
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to create customer group.';
    showErrorNotification(message);
  } finally {
    isSaving.value = false;
  }
};
</script>

<style scoped>
.create-customer-page {
  background: var(--bw-brand-base, #eef0f4);
  height: calc(100vh - 55px);
  overflow: hidden;
}

.create-toolbar {
  border-radius: 8px;
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.action-btn {
  border-radius: 8px !important;
}

.scroll-container {
  min-height: 0;
  flex: 1 1 0%;
  overflow-y: auto;
}

.customer-form-card {
  max-width: 640px;
  border-radius: 8px;
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid rgba(226, 232, 240, 0.8);
  box-shadow: 0 4px 12px -2px rgba(51, 65, 85, 0.05);
}

.email-lookup-wrap {
  position: relative;
}

.email-suggestions {
  position: absolute;
  left: 0;
  right: 0;
  z-index: 2;
  max-height: 240px;
  overflow-y: auto;
}

.rounded-field :deep(.q-field__control) {
  border-radius: 8px;
}

.color-preview-badge {
  width: 22px;
  height: 22px;
  border-radius: 6px;
  cursor: pointer;
  border: 1px solid rgba(0, 0, 0, 0.1);
}

.preset-swatch {
  width: 24px;
  height: 24px;
  border-radius: 6px;
  transition: transform 0.15s ease;
}

.preset-swatch:hover {
  transform: scale(1.15);
}

.preset-swatch--active {
  outline: 2px solid var(--q-primary, #1976d2);
  outline-offset: 2px;
}

.customer-group-chip {
  display: inline-block;
  width: 14px;
  height: 14px;
  border-radius: 4px;
}

.form-actions {
  border-top: 1px solid rgba(226, 232, 240, 0.8);
}

body.body--dark .form-actions {
  border-top-color: #2e2e2e;
}

body.body--dark .create-customer-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .create-toolbar,
body.body--dark .customer-form-card {
  background: #1c1c1c;
  border-color: #2e2e2e;
}
</style>
