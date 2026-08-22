<template>
  <q-page class="create-customer-page page-fixed-layout q-pa-md">
    <div class="column no-wrap full-height">
      <!-- 1. Top Action Toolbar: Back Link / Breadcrumb Action & Header Details -->
      <div class="create-toolbar floating-surface shadow-1 q-pa-sm q-mb-md">
        <div class="row items-center justify-between no-wrap">
          <div class="row items-center q-gutter-sm">
            <q-btn
              flat
              round
              dense
              icon="ph ph-arrow-left"
              color="grey-8"
              @click="goBack"
            >
              <q-tooltip>Back to Customers</q-tooltip>
            </q-btn>
            <div class="text-subtitle1 text-weight-bold text-grey-9">
              Create New Customer
            </div>
          </div>

          <div class="row items-center q-gutter-sm">
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
              label="Save Customer"
              no-caps
              class="action-btn text-weight-bold"
              :loading="isSaving"
              @click="submitForm"
            />
          </div>
        </div>
      </div>

      <!-- 2. Main Form Container (Centered Scrollable Form Card) -->
      <div class="col scroll-container flex flex-center">
        <q-form ref="formRef" class="customer-form-card floating-surface shadow-1 q-pa-lg full-width" @submit.prevent="submitForm">
          <div class="row q-col-gutter-lg">
            <!-- Left Column: Business & Contact Info -->
            <div class="col-12 col-md-7 column q-gutter-y-md">
              <div class="section-title text-caption text-uppercase text-weight-bold text-primary">
                Customer &amp; Account Identity
              </div>

              <!-- Group Name -->
              <div>
                <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Group / Company Name *</label>
                <q-input
                  v-model="form.group_name"
                  outlined
                  dense
                  placeholder="e.g. Acme Retailers / Dhaka Wholesale House"
                  class="rounded-field"
                  :rules="[(val) => !!val?.trim() || 'Group / Company name is required']"
                >
                  <template #prepend>
                    <q-icon name="ph ph-buildings" size="18px" class="text-grey-6" />
                  </template>
                </q-input>
              </div>

              <!-- Admin Name -->
              <div>
                <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Primary Contact / Admin Name *</label>
                <q-input
                  v-model="form.admin_name"
                  outlined
                  dense
                  placeholder="e.g. Rahim Chowdhury"
                  class="rounded-field"
                  :rules="[(val) => !!val?.trim() || 'Admin contact name is required']"
                >
                  <template #prepend>
                    <q-icon name="ph ph-user" size="18px" class="text-grey-6" />
                  </template>
                </q-input>
              </div>

              <!-- Email & Phone in 2-cols (Optional) -->
              <div class="row q-col-gutter-md">
                <div class="col-12 col-sm-6">
                  <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Admin Email</label>
                  <q-input
                    v-model="form.admin_email"
                    outlined
                    dense
                    type="email"
                    placeholder="admin@customer.com (optional)"
                    class="rounded-field"
                    :rules="[
                      (val) => !val || /.+@.+\..+/.test(val) || 'Enter a valid email address'
                    ]"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-envelope" size="18px" class="text-grey-6" />
                    </template>
                  </q-input>
                </div>

                <div class="col-12 col-sm-6">
                  <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Phone Number</label>
                  <q-input
                    v-model="form.phone"
                    outlined
                    dense
                    placeholder="e.g. +8801712345678 (optional)"
                    class="rounded-field"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-phone" size="18px" class="text-grey-6" />
                    </template>
                  </q-input>
                </div>
              </div>

              <!-- Address -->
              <div>
                <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Billing &amp; Delivery Address</label>
                <q-input
                  v-model="form.address"
                  outlined
                  dense
                  type="textarea"
                  rows="3"
                  placeholder="Office / shop address (optional)"
                  class="rounded-field"
                >
                  <template #prepend>
                    <q-icon name="ph ph-map-pin" size="18px" class="text-grey-6" />
                  </template>
                </q-input>
              </div>
            </div>

            <!-- Right Column: Accent Color & Automated Provisioning Summary -->
            <div class="col-12 col-md-5 column q-gutter-y-md">
              <div class="section-title text-caption text-uppercase text-weight-bold text-primary">
                Brand &amp; System Configuration
              </div>

              <!-- Accent Color Picker -->
              <div>
                <label class="field-label text-weight-medium text-grey-8 q-mb-xs block">Brand Accent Color *</label>
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

                <!-- Preset Swatches -->
                <div class="row items-center q-gutter-xs q-mt-xs">
                  <span class="text-caption text-grey-6 q-mr-xs">Quick Set:</span>
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

              <!-- Automated Provisioning Info Card -->
              <div class="provisioning-card q-pa-md rounded-borders">
                <div class="row items-center q-gutter-xs q-mb-xs text-weight-bold text-grey-9">
                  <q-icon name="ph ph-sparkle" color="primary" size="18px" />
                  <span>Automated Setup</span>
                </div>
                <div class="text-caption text-grey-7 q-mb-sm">
                  Upon saving, the system will automatically:
                </div>
                <ul class="q-pl-md q-my-none text-caption text-grey-8 q-gutter-y-xs">
                  <li>Provision <strong>Customer Group</strong> access tier</li>
                  <li>Link <strong>Admin Member</strong> for storefront auth</li>
                  <li>Create <strong>Billing Profile</strong> for wholesale &amp; retail invoicing</li>
                  <li>Anchor a zero-balance <strong>Universal Wallet Ledger</strong></li>
                </ul>
              </div>
            </div>
          </div>
        </q-form>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerMutations } from '../composables/useCustomerQuery';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const { createCustomerMutation } = useCustomerMutations();

const formRef = ref<any>(null);
const isSaving = ref(false);

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
  group_name: '',
  admin_name: '',
  admin_email: '',
  phone: '',
  address: '',
  accent_color: '#B45F34',
});

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const goBack = () => {
  void router.push(`${getTenantPrefix()}/app/customers`);
};

const submitForm = async () => {
  if (!formRef.value) return;
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
      admin_email: form.admin_email.trim() || null,
      phone: form.phone.trim() || null,
      address: form.address.trim() || null,
      accent_color: form.accent_color.trim() || '#B45F34',
    });

    showSuccessNotification('Customer account, billing profile & wallet created successfully.');
    goBack();
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to create customer account.');
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
  max-width: 900px;
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

.provisioning-card {
  background: #f8fafc;
  border: 1px dashed rgba(203, 213, 225, 0.9);
}

/* Dark mode */
body.body--dark .create-customer-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .create-toolbar,
body.body--dark .customer-form-card {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

body.body--dark .provisioning-card {
  background: #232323;
  border-color: #383838;
}
</style>
