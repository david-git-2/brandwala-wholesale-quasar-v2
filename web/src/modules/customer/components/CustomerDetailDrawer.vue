<template>
  <q-drawer
    :model-value="modelValue"
    side="right"
    overlay
    bordered
    :width="600"
    class="bg-surface customer-drawer"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div v-if="customer" class="column full-height no-wrap">
      <!-- 1. Drawer Header -->
      <div class="q-pa-md border-bottom row items-center justify-between header-surface">
        <div class="row items-center no-wrap">
          <q-avatar
            size="40px"
            text-color="white"
            class="q-mr-sm text-weight-bold flex-shrink-0"
            :style="{ backgroundColor: form.accent_color || '#B45F34' }"
          >
            {{ getInitials(form.group_name) }}
          </q-avatar>
          <div class="ellipsis">
            <div class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
              {{ form.group_name }}
            </div>
            <div class="text-caption text-grey-7">Customer Details &amp; Member Access</div>
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" @click="$emit('update:modelValue', false)" />
      </div>

      <!-- 2. Tabs Navigation -->
      <div class="border-bottom bg-white">
        <q-tabs
          v-model="activeTab"
          dense
          align="left"
          active-color="primary"
          indicator-color="primary"
          class="text-grey-7"
        >
          <q-tab name="general" label="General Info" icon="ph ph-user-circle" no-caps />
          <q-tab name="members" label="Members" icon="ph ph-users-three" no-caps>
            <q-badge v-if="members.length" color="primary" rounded floating>
              {{ members.length }}
            </q-badge>
          </q-tab>
          <q-tab name="wallet" label="Wallet Ledger" icon="ph ph-wallet" no-caps />
        </q-tabs>
      </div>

      <!-- 3. Tab Panels Content -->
      <div class="col scroll q-pa-md">
        <q-tab-panels v-model="activeTab" animated class="bg-transparent">
          <!-- TAB 1: General Info (Editable) -->
          <q-tab-panel name="general" class="q-pa-none">
            <q-form ref="generalFormRef" class="column q-gutter-y-md" @submit.prevent="saveGeneralInfo">
              <!-- Group Name -->
              <div>
                <label class="text-caption text-weight-medium text-grey-8 q-mb-xs block">
                  Company / Group Name *
                </label>
                <q-input
                  v-model="form.group_name"
                  outlined
                  dense
                  class="rounded-field"
                  :rules="[(val) => !!val?.trim() || 'Company name is required']"
                />
              </div>

              <!-- Admin Contact Name -->
              <div>
                <label class="text-caption text-weight-medium text-grey-8 q-mb-xs block">
                  Primary Contact / Admin Name *
                </label>
                <q-input
                  v-model="form.admin_name"
                  outlined
                  dense
                  class="rounded-field"
                  :rules="[(val) => !!val?.trim() || 'Admin contact name is required']"
                />
              </div>

              <!-- Email & Phone -->
              <div class="row q-col-gutter-sm">
                <div class="col-6">
                  <label class="text-caption text-weight-medium text-grey-8 q-mb-xs block">Email</label>
                  <q-input
                    v-model="form.email"
                    outlined
                    dense
                    type="email"
                    class="rounded-field"
                  />
                </div>
                <div class="col-6">
                  <label class="text-caption text-weight-medium text-grey-8 q-mb-xs block">Phone</label>
                  <q-input
                    v-model="form.phone"
                    outlined
                    dense
                    class="rounded-field"
                  />
                </div>
              </div>

              <!-- Address -->
              <div>
                <label class="text-caption text-weight-medium text-grey-8 q-mb-xs block">
                  Address
                </label>
                <q-input
                  v-model="form.address"
                  outlined
                  dense
                  type="textarea"
                  rows="2"
                  class="rounded-field"
                />
              </div>

              <!-- Accent Color -->
              <div>
                <label class="text-caption text-weight-medium text-grey-8 q-mb-xs block">
                  Accent Color
                </label>
                <q-input v-model="form.accent_color" outlined dense class="rounded-field">
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
              </div>

              <!-- Status Toggle -->
              <div class="row items-center justify-between q-pa-sm rounded-borders bg-grey-1">
                <div>
                  <div class="text-caption text-weight-bold text-grey-9">Active Status</div>
                  <div class="text-caption text-grey-6">Enable or disable access for this customer account</div>
                </div>
                <q-toggle v-model="form.is_active" color="positive" />
              </div>

              <!-- Save Button -->
              <div class="row justify-end q-mt-md">
                <q-btn
                  unelevated
                  color="primary"
                  icon="ph ph-check"
                  label="Save Changes"
                  no-caps
                  class="action-btn text-weight-bold"
                  :loading="isSavingGeneral"
                  type="submit"
                />
              </div>
            </q-form>
          </q-tab-panel>

          <!-- TAB 2: Members Management -->
          <q-tab-panel name="members" class="q-pa-none">
            <div class="column q-gutter-y-md">
              <!-- Add Member Action Bar -->
              <div class="row items-center justify-between">
                <div class="text-caption text-weight-bold text-grey-8">
                  Storefront &amp; Access Members
                </div>
                <q-btn
                  unelevated
                  color="primary"
                  icon="ph ph-user-plus"
                  label="Add Member"
                  no-caps
                  size="sm"
                  class="action-btn text-weight-bold"
                  @click="openAddMemberDialog"
                />
              </div>

              <!-- Members Table / List -->
              <q-card flat bordered class="rounded-borders">
                <q-markup-table flat dense wrap-cells>
                  <thead>
                    <tr>
                      <th class="text-left">Name / Email</th>
                      <th class="text-center">Role</th>
                      <th class="text-center">Active</th>
                      <th class="text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-if="!members.length && !membersQuery.isLoading.value">
                      <td colspan="4" class="text-center q-pa-lg text-caption text-grey-6">
                        No members added to this customer group yet.
                      </td>
                    </tr>
                    <tr v-for="member in members" :key="member.id">
                      <td>
                        <div class="text-weight-bold text-grey-9">{{ member.name }}</div>
                        <div class="text-caption text-grey-7">{{ member.email }}</div>
                      </td>
                      <td class="text-center">
                        <q-chip dense square color="blue-1" text-color="blue-9" class="text-caption text-weight-bold q-ma-none">
                          {{ member.role }}
                        </q-chip>
                      </td>
                      <td class="text-center">
                        <q-icon
                          :name="member.is_active ? 'ph ph-check-circle' : 'ph ph-x-circle'"
                          :color="member.is_active ? 'positive' : 'grey-5'"
                          size="18px"
                        />
                      </td>
                      <td class="text-right">
                        <q-btn
                          flat
                          round
                          dense
                          icon="ph ph-pencil-simple"
                          size="sm"
                          color="grey-7"
                          @click="openEditMemberDialog(member)"
                        />
                        <q-btn
                          flat
                          round
                          dense
                          icon="ph ph-trash"
                          size="sm"
                          color="negative"
                          :loading="deletingMemberId === member.id"
                          @click="deleteMember(member)"
                        />
                      </td>
                    </tr>
                  </tbody>
                </q-markup-table>
              </q-card>
            </div>
          </q-tab-panel>

          <!-- TAB 3: Universal Wallet Summary -->
          <q-tab-panel name="wallet" class="q-pa-none">
            <div class="column q-gutter-y-md">
              <q-card flat bordered class="bg-primary text-white q-pa-md rounded-borders">
                <div class="text-caption text-uppercase opacity-80">Available Net Balance</div>
                <div class="text-h4 text-weight-bolder q-my-xs">
                  {{ formatBdt(customer.wallet_available_balance) }}
                </div>
                <div class="text-caption opacity-90">
                  Universal double-entry ledger account linked to Billing Profile #{{ customer.billing_profile_id || customer.customer_group_id }}
                </div>
              </q-card>

              <div class="text-caption text-grey-7 text-center q-pa-md">
                Ledger transactions post automatically on Wholesale &amp; Retail invoice issue/collections.
              </div>
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </div>
    </div>

    <!-- Member Create / Edit Dialog -->
    <q-dialog v-model="memberDialogOpen" persistent>
      <q-card style="min-width: 360px" class="rounded-borders q-pa-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">
          {{ isEditingMember ? 'Edit Member' : 'Add Storefront Member' }}
        </div>
        <q-form ref="memberFormRef" class="q-gutter-y-sm" @submit.prevent="saveMember">
          <q-input
            v-model="memberForm.name"
            outlined
            dense
            label="Member Name *"
            class="rounded-field"
            :rules="[(val) => !!val?.trim() || 'Name is required']"
          />
          <q-input
            v-model="memberForm.email"
            outlined
            dense
            type="email"
            label="Email Address *"
            class="rounded-field"
            :rules="[
              (val) => !!val?.trim() || 'Email is required',
              (val) => /.+@.+\..+/.test(val) || 'Enter valid email'
            ]"
          />
          <q-select
            v-model="memberForm.role"
            outlined
            dense
            label="Role *"
            :options="['admin', 'manager', 'staff']"
            class="rounded-field"
          />
          <div class="row items-center justify-between q-pt-xs">
            <span class="text-caption text-grey-8">Active Member</span>
            <q-toggle v-model="memberForm.is_active" color="positive" />
          </div>

          <div class="row justify-end q-gutter-sm q-mt-md">
            <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
            <q-btn
              unelevated
              color="primary"
              :label="isEditingMember ? 'Save' : 'Add'"
              no-caps
              type="submit"
              :loading="isSavingMember"
              class="action-btn text-weight-bold"
            />
          </div>
        </q-form>
      </q-card>
    </q-dialog>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import type { CustomerAccount, CustomerGroupMember } from '../types/customer';
import { useCustomerMembersQuery, useCustomerMutations } from '../composables/useCustomerQuery';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  customer: CustomerAccount | null;
  tenantId: number;
}>();

defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const activeTab = ref<'general' | 'members' | 'wallet'>('general');
const { updateCustomerMutation, createMemberMutation, updateMemberMutation, deleteMemberMutation } =
  useCustomerMutations();

const customerGroupId = computed(() => props.customer?.customer_group_id ?? null);
const membersQuery = useCustomerMembersQuery(customerGroupId);
const members = computed(() => membersQuery.data.value ?? []);

const isSavingGeneral = ref(false);
const memberDialogOpen = ref(false);
const isEditingMember = ref(false);
const isSavingMember = ref(false);
const deletingMemberId = ref<number | null>(null);
const selectedMemberId = ref<number | null>(null);

const form = reactive({
  group_name: '',
  admin_name: '',
  email: '',
  phone: '',
  address: '',
  accent_color: '#B45F34',
  is_active: true,
});

const memberForm = reactive({
  name: '',
  email: '',
  role: 'staff' as 'admin' | 'manager' | 'staff',
  is_active: true,
});

watch(
  () => props.customer,
  (newCust) => {
    if (newCust) {
      form.group_name = newCust.group_name;
      form.admin_name = newCust.admin_name;
      form.email = newCust.email || '';
      form.phone = newCust.phone || '';
      form.address = newCust.address || '';
      form.accent_color = newCust.accent_color || '#B45F34';
      form.is_active = newCust.is_active ?? true;
    }
  },
  { immediate: true }
);

const getInitials = (name?: string | null) => {
  if (!name) return 'C';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'C';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'C';
};

const formatBdt = (val?: number | null) => {
  const num = Number(val) || 0;
  return `${num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} BDT`;
};

const saveGeneralInfo = async () => {
  if (!props.customer) return;
  isSavingGeneral.value = true;
  try {
    await updateCustomerMutation.mutateAsync({
      id: props.customer.id,
      tenant_id: props.tenantId,
      customer_group_id: props.customer.customer_group_id,
      group_name: form.group_name.trim(),
      admin_name: form.admin_name.trim(),
      email: form.email.trim() || null,
      phone: form.phone.trim() || null,
      address: form.address.trim() || null,
      accent_color: form.accent_color.trim() || '#B45F34',
      is_active: form.is_active,
    });
    showSuccessNotification('Customer details updated successfully.');
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to update customer details.');
  } finally {
    isSavingGeneral.value = false;
  }
};

const openAddMemberDialog = () => {
  isEditingMember.value = false;
  selectedMemberId.value = null;
  memberForm.name = '';
  memberForm.email = '';
  memberForm.role = 'staff';
  memberForm.is_active = true;
  memberDialogOpen.value = true;
};

const openEditMemberDialog = (member: CustomerGroupMember) => {
  isEditingMember.value = true;
  selectedMemberId.value = member.id;
  memberForm.name = member.name;
  memberForm.email = member.email;
  memberForm.role = member.role;
  memberForm.is_active = member.is_active;
  memberDialogOpen.value = true;
};

const saveMember = async () => {
  if (!props.customer) return;
  isSavingMember.value = true;
  try {
    if (isEditingMember.value && selectedMemberId.value) {
      await updateMemberMutation.mutateAsync({
        id: selectedMemberId.value,
        customer_group_id: props.customer.customer_group_id,
        name: memberForm.name.trim(),
        email: memberForm.email.trim().toLowerCase(),
        role: memberForm.role,
        is_active: memberForm.is_active,
      });
      showSuccessNotification('Member updated successfully.');
    } else {
      await createMemberMutation.mutateAsync({
        customer_group_id: props.customer.customer_group_id,
        name: memberForm.name.trim(),
        email: memberForm.email.trim().toLowerCase(),
        role: memberForm.role,
        is_active: memberForm.is_active,
      });
      showSuccessNotification('Member added successfully.');
    }
    memberDialogOpen.value = false;
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to save member.');
  } finally {
    isSavingMember.value = false;
  }
};

const deleteMember = async (member: CustomerGroupMember) => {
  if (!props.customer) return;
  deletingMemberId.value = member.id;
  try {
    await deleteMemberMutation.mutateAsync({
      id: member.id,
      customer_group_id: props.customer.customer_group_id,
    });
    showSuccessNotification('Member deleted successfully.');
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to delete member.');
  } finally {
    deletingMemberId.value = null;
  }
};
</script>

<style scoped>
.customer-drawer {
  background: #ffffff;
}

.header-surface {
  background: #f8fafc;
}

.border-bottom {
  border-bottom: 1px solid rgba(226, 232, 240, 0.9);
}

.action-btn {
  border-radius: 8px !important;
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

/* Dark mode */
body.body--dark .customer-drawer,
body.body--dark .header-surface {
  background: #1c1c1c;
  border-color: #2e2e2e;
}
</style>
