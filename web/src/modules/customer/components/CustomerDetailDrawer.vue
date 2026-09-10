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
      <div class="drawer-tabs q-px-md q-pt-sm q-pb-md border-bottom">
        <div class="drawer-tabs__track">
          <button
            v-for="tab in drawerTabs"
            :key="tab.name"
            type="button"
            class="drawer-tabs__item"
            :class="{ 'drawer-tabs__item--active': activeTab === tab.name }"
            @click="activeTab = tab.name"
          >
            <q-icon :name="tab.icon" size="14px" />
            <span>{{ tab.label }}</span>
            <span v-if="tab.name === 'members' && members.length" class="drawer-tabs__badge">
              {{ members.length }}
            </span>
          </button>
        </div>
      </div>

      <!-- 3. Tab Panels Content -->
      <div class="col scroll q-pa-md">
        <q-tab-panels v-model="activeTab" animated class="bg-transparent">
          <!-- TAB 1: General Info (Editable) -->
          <q-tab-panel name="general" class="q-pa-none">
            <q-form ref="generalFormRef" class="column q-gutter-y-md" @submit.prevent="saveGeneralInfo">
              <div class="form-section column q-gutter-y-md">
                <div class="section-heading">Customer group</div>

                <div>
                  <label class="field-label">Group name *</label>
                  <q-input
                    v-model="form.group_name"
                    outlined
                    dense
                    class="soft-input"
                    :loading="isCheckingName"
                    :rules="[(val) => !!val?.trim() || 'Group name is required']"
                    @keyup.enter.prevent="checkGroupName"
                    @blur="checkGroupName"
                  />
                  <q-banner
                    v-if="nameConflict"
                    dense
                    rounded
                    class="bg-orange-1 text-grey-9 q-mt-sm"
                  >
                    A customer group already uses this name.
                  </q-banner>
                </div>

                <div>
                  <label class="field-label">Accent color</label>
                  <div class="color-field row no-wrap items-center q-gutter-sm">
                    <button
                      type="button"
                      class="color-swatch"
                      :style="{ backgroundColor: form.accent_color || '#B45F34' }"
                      aria-label="Pick accent color"
                    >
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-color v-model="form.accent_color" no-header-tabs />
                      </q-popup-proxy>
                    </button>
                    <q-input
                      v-model="form.accent_color"
                      outlined
                      dense
                      class="col soft-input"
                    />
                  </div>
                </div>

                <div class="settings-row row items-center justify-between">
                  <div>
                    <div class="settings-row__label">Active</div>
                    <div class="settings-row__hint">Turn this group on or off</div>
                  </div>
                  <q-toggle
                    v-model="form.is_active"
                    color="positive"
                    :disable="!canAdministerCustomerGroup"
                  />
                </div>
              </div>

              <div class="form-section form-section--divider column q-gutter-y-md">
                <div class="section-heading">Billing profile</div>

                <div>
                  <label class="field-label">Contact name *</label>
                  <q-input
                    v-model="form.admin_name"
                    outlined
                    dense
                    class="soft-input"
                    :rules="[(val) => !!val?.trim() || 'Contact name is required']"
                  />
                </div>

                <div>
                  <label class="field-label">Phone *</label>
                  <div class="phone-fuse">
                    <q-select
                      v-model="form.phone_country_code"
                      borderless
                      dense
                      emit-value
                      map-options
                      use-input
                      hide-bottom-space
                      input-debounce="0"
                      :options="filteredCountries"
                      class="phone-fuse__country"
                      dropdown-icon="ph ph-caret-down"
                      @filter="filterCountries"
                      @update:model-value="onDrawerCountryChanged"
                    >
                      <template #option="scope">
                        <q-item v-bind="scope.itemProps">
                          <q-item-section>
                            <q-item-label class="text-weight-medium">{{ scope.opt.dial }}</q-item-label>
                            <q-item-label caption>{{ scope.opt.name }}</q-item-label>
                          </q-item-section>
                        </q-item>
                      </template>
                    </q-select>
                    <div class="phone-fuse__sep" />
                    <q-input
                      :model-value="form.phone"
                      borderless
                      dense
                      hide-bottom-space
                      class="phone-fuse__number col"
                      inputmode="tel"
                      placeholder="National number — press Enter"
                      :loading="isCheckingPhone"
                      :rules="[(val) => !!nationalPhoneDigits(String(val ?? '')) || 'Phone is required']"
                      @update:model-value="onDrawerPhoneInput"
                      @keyup.enter.prevent="checkPhone"
                      @blur="checkPhone"
                    />
                  </div>
                  <q-banner
                    v-if="phoneConflictName"
                    dense
                    rounded
                    class="bg-orange-1 text-grey-9 q-mt-sm"
                  >
                    A customer already uses this phone:
                    <strong>{{ phoneConflictName }}</strong>
                  </q-banner>
                </div>

                <div>
                  <label class="field-label">Address</label>
                  <q-input
                    v-model="form.address"
                    outlined
                    dense
                    type="textarea"
                    rows="2"
                    class="soft-input soft-input--textarea"
                  />
                </div>
              </div>

              <div class="row justify-end">
                <q-btn
                  unelevated
                  color="primary"
                  icon="ph ph-check"
                  label="Save Changes"
                  no-caps
                  class="action-btn text-weight-bold"
                  :loading="isSavingGeneral"
                  :disable="!canSaveGeneral"
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

          <!-- TAB 3: Account (dues + wallet position) -->
          <q-tab-panel name="account" class="q-pa-none">
            <CustomerAccountTab
              :tenant-id="tenantId"
              :customer-group-id="customer?.customer_group_id ?? 0"
              :group-name="form.group_name"
              :billing-profile-id="billingProfileId || null"
              :summary="accountSummary"
              :is-loading="accountQuery.isLoading.value"
              :is-error="accountQuery.isError.value"
              :error="accountQuery.error.value"
              @refresh="onRefreshAccount"
              @action-complete="onAccountActionComplete"
            />
          </q-tab-panel>

          <!-- TAB 4: Universal Wallet Summary -->
          <q-tab-panel name="wallet" class="q-pa-none">
            <div class="column q-gutter-y-md">
              <q-card flat bordered class="bg-primary text-white q-pa-md rounded-borders">
                <div class="text-caption text-uppercase opacity-80">Available Net Balance</div>
                <div class="text-h4 text-weight-bolder q-my-xs">
                  {{ formatBdt(walletBalance) }}
                </div>
                <div v-if="customer.billing_profile_id" class="text-caption opacity-90">
                  Billing profile #{{ customer.billing_profile_id }}
                </div>
                <div v-else class="text-caption opacity-90">
                  No billing profile linked — wallet activity will not post until one exists.
                </div>
              </q-card>

              <div v-if="!customer.billing_profile_id" class="text-caption text-grey-7 text-center q-pa-md">
                Create or link a billing profile for this customer group to enable wallet ledger.
              </div>

              <template v-else>
                <div class="row items-center justify-between">
                  <div class="text-subtitle2 text-weight-bold text-grey-9">Wallet transactions</div>
                  <q-btn
                    flat
                    dense
                    no-caps
                    icon="ph ph-arrows-clockwise"
                    label="Refresh"
                    class="text-caption"
                    @click="onRefreshWallet"
                  />
                </div>

                <div v-if="walletLoading" class="row justify-center q-py-md">
                  <q-spinner color="primary" size="2em" />
                </div>

                <div
                  v-else-if="!ledgerEntries.length"
                  class="text-center text-grey-7 q-pa-lg border-all-1 rounded-borders"
                >
                  No wallet transactions recorded yet.
                </div>

                <q-list v-else separator bordered class="rounded-borders">
                  <q-item v-for="entry in ledgerEntries" :key="entry.id" class="q-py-sm">
                    <q-item-section>
                      <q-item-label class="text-weight-bold text-caption text-grey-9">
                        {{ walletTxLabel(entry) }}
                      </q-item-label>
                      <q-item-label caption class="text-grey-7">
                        {{ formatWalletDate(entry.created_at) }}
                        <span v-if="entry.source_id"> · {{ entry.source_id }}</span>
                      </q-item-label>
                    </q-item-section>
                    <q-item-section side class="text-right">
                      <q-item-label
                        class="text-weight-bold text-caption"
                        :class="entry.type === 'credit' ? 'text-positive' : 'text-negative'"
                      >
                        {{ entry.type === 'credit' ? '+' : '-' }}{{ formatBdt(Number(entry.amount)) }}
                      </q-item-label>
                      <q-item-label caption class="text-grey-6">
                        Bal: {{ formatBdt(Number(entry.balance_after)) }}
                      </q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </template>
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
            class="soft-input"
            :rules="[(val) => !!val?.trim() || 'Name is required']"
          />
          <q-input
            v-model="memberForm.email"
            outlined
            dense
            type="email"
            label="Email Address *"
            class="soft-input"
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
            class="soft-input"
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
import type { QSelectProps } from 'quasar';
import { useQueryClient } from '@tanstack/vue-query';
import type { CustomerAccount, CustomerGroupMember } from '../types/customer';
import {
  useCustomerMembersQuery,
  useCustomerMutations,
  useCustomerAccountQuery,
} from '../composables/useCustomerQuery';
import { customerQueryKeys } from '../services/customerQueryKeys';
import { useWalletQuery } from 'src/modules/wallet/composables/useWalletQuery';
import { walletQueryKeys } from 'src/modules/wallet/shared/queryKeys/walletQueryKeys';
import CustomerAccountTab from './CustomerAccountTab.vue';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import { useCanAdministerCustomerGroup } from '../composables/useCanAdministerCustomerGroup';
import { customerRepository } from '../repositories/customerRepository';
import {
  DEFAULT_PHONE_COUNTRY_DIAL,
  nationalPhoneDigits,
  phoneCountrySelectOptions,
} from 'src/utils/phoneCountryCodes';

const props = defineProps<{
  modelValue: boolean;
  customer: CustomerAccount | null;
  tenantId: number;
}>();

defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const canAdministerCustomerGroup = useCanAdministerCustomerGroup();
const activeTab = ref<'general' | 'members' | 'account' | 'wallet'>('general');

const drawerTabs = [
  { name: 'general' as const, label: 'General', icon: 'ph ph-user-circle' },
  { name: 'members' as const, label: 'Members', icon: 'ph ph-users-three' },
  { name: 'account' as const, label: 'Account', icon: 'ph ph-scale' },
  { name: 'wallet' as const, label: 'Wallet', icon: 'ph ph-wallet' },
];
const queryClient = useQueryClient();
const { updateCustomerMutation, createMemberMutation, updateMemberMutation, deleteMemberMutation } =
  useCustomerMutations();

const customerGroupId = computed(() => props.customer?.customer_group_id ?? null);
const billingProfileId = computed(() => props.customer?.billing_profile_id ?? 0);
const accountTabActive = computed(() => activeTab.value === 'account' && props.modelValue);
const accountQuery = useCustomerAccountQuery(
  computed(() => props.tenantId),
  customerGroupId,
  accountTabActive,
);
const accountSummary = computed(() => accountQuery.data.value);
const membersQuery = useCustomerMembersQuery(customerGroupId);
const members = computed(() => membersQuery.data.value ?? []);

const { ledgerEntries, isLoading: walletLoading, refetch: refetchWallet } = useWalletQuery(
  'customer',
  billingProfileId,
);

const walletBalance = computed(() => {
  if (ledgerEntries.value.length > 0) {
    return Number(ledgerEntries.value[0]?.balance_after ?? 0);
  }
  return Number(props.customer?.wallet_available_balance ?? 0);
});

const onRefreshWallet = () => {
  void refetchWallet();
};

const onRefreshAccount = () => {
  void accountQuery.refetch();
};

const onAccountActionComplete = async () => {
  await Promise.all([
    accountQuery.refetch(),
    refetchWallet(),
    queryClient.invalidateQueries({ queryKey: customerQueryKeys.root }),
    queryClient.invalidateQueries({ queryKey: walletQueryKeys.all }),
  ]);
};

const formatWalletDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });

const walletTxLabel = (entry: { type: string; metadata: Record<string, unknown> }) => {
  const txType = entry.metadata?.['transaction_type'] as string | undefined;
  switch (txType) {
    case 'dropship_profit':
      return 'Dropship profit';
    case 'invoice_collection':
      return 'Invoice collection';
    case 'merchant_funds_held':
      return 'Merchant profit held';
    case 'profit_paid_out':
      return 'Profit paid out';
    case 'payment_received':
      return 'Payment received';
    case 'invoice_billed':
      return 'Invoice billed';
    default:
      return (entry.metadata?.['label'] as string | undefined) || 'Adjustment';
  }
};

const isSavingGeneral = ref(false);
const isCheckingName = ref(false);
const isCheckingPhone = ref(false);
const nameConflict = ref(false);
const phoneConflictName = ref<string | null>(null);
const phoneVerified = ref(true);
const memberDialogOpen = ref(false);
const isEditingMember = ref(false);
const isSavingMember = ref(false);
const deletingMemberId = ref<number | null>(null);
const selectedMemberId = ref<number | null>(null);

const form = reactive({
  group_name: '',
  admin_name: '',
  phone: '',
  phone_country_code: DEFAULT_PHONE_COUNTRY_DIAL,
  address: '',
  accent_color: '#B45F34',
  is_active: true,
});

const filteredCountries = ref(phoneCountrySelectOptions);

const parseListedPhone = (raw?: string | null) => {
  const value = (raw || '').trim();
  const match = value.match(/^(\+\d+)\s+(.*)$/);
  if (match?.[1] && match[2] !== undefined) {
    return {
      phone_country_code: match[1],
      phone: nationalPhoneDigits(match[2]),
    };
  }
  return {
    phone_country_code: DEFAULT_PHONE_COUNTRY_DIAL,
    phone: nationalPhoneDigits(value),
  };
};

const invalidatePhoneCheck = () => {
  phoneVerified.value = false;
  phoneConflictName.value = null;
};

const onDrawerPhoneInput = (val: string | number | null) => {
  form.phone = nationalPhoneDigits(String(val ?? ''));
  invalidatePhoneCheck();
};

const onDrawerCountryChanged = () => {
  invalidatePhoneCheck();
};

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
      const parsedPhone = parseListedPhone(newCust.phone);
      form.phone = parsedPhone.phone;
      form.phone_country_code = parsedPhone.phone_country_code;
      form.address = newCust.address || '';
      form.accent_color = newCust.accent_color || '#B45F34';
      form.is_active = newCust.is_active ?? true;
      nameConflict.value = false;
      phoneConflictName.value = null;
      phoneVerified.value = true;
    }
  },
  { immediate: true }
);

watch(
  () => form.group_name,
  () => {
    nameConflict.value = false;
  },
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

const canSaveGeneral = computed(() => {
  return (
    !!form.group_name.trim() &&
    !!form.admin_name.trim() &&
    !!nationalPhoneDigits(form.phone) &&
    phoneVerified.value &&
    !nameConflict.value &&
    !phoneConflictName.value &&
    !isCheckingName.value &&
    !isCheckingPhone.value
  );
});

const checkPhone = async () => {
  const phone = nationalPhoneDigits(form.phone);
  if (!phone || !props.tenantId || !props.customer) {
    phoneConflictName.value = null;
    phoneVerified.value = false;
    return;
  }
  isCheckingPhone.value = true;
  try {
    const result = await customerRepository.findCreateConflict(props.tenantId, {
      phone,
      phone_country_code: form.phone_country_code,
    });
    const conflict = result.phone_group_name;
    const isOwnNumber =
      !!conflict &&
      conflict.trim().toLowerCase() === props.customer.group_name.trim().toLowerCase();
    phoneConflictName.value = conflict && !isOwnNumber ? conflict : null;
    phoneVerified.value = !phoneConflictName.value;
  } finally {
    isCheckingPhone.value = false;
  }
};

const checkGroupName = async () => {
  const name = form.group_name.trim();
  if (!name || !props.tenantId || !props.customer) {
    nameConflict.value = false;
    return;
  }
  isCheckingName.value = true;
  try {
    nameConflict.value = await customerRepository.isGroupNameTaken(
      props.tenantId,
      name,
      props.customer.customer_group_id,
    );
  } finally {
    isCheckingName.value = false;
  }
};

const saveGeneralInfo = async () => {
  if (!props.customer) return;
  const phone = nationalPhoneDigits(form.phone);
  if (!form.group_name.trim() || !form.admin_name.trim() || !phone) {
    return;
  }
  await checkGroupName();
  await checkPhone();
  if (nameConflict.value || !phoneVerified.value || phoneConflictName.value) return;
  isSavingGeneral.value = true;
  try {
    await updateCustomerMutation.mutateAsync({
      id: props.customer.id,
      tenant_id: props.tenantId,
      customer_group_id: props.customer.customer_group_id,
      billing_profile_id: props.customer.billing_profile_id,
      group_name: form.group_name.trim(),
      admin_name: form.admin_name.trim(),
      email: props.customer.email?.trim() || null,
      phone,
      phone_country_code: form.phone_country_code,
      address: form.address.trim() || null,
      accent_color: form.accent_color.trim() || '#B45F34',
      is_active: canAdministerCustomerGroup.value
        ? form.is_active
        : (props.customer.is_active ?? true),
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

.border-all-1 {
  border: 1px solid rgba(226, 232, 240, 0.9);
}

.action-btn {
  border-radius: 8px !important;
}

.drawer-tabs__track {
  display: flex;
  gap: 4px;
  padding: 4px;
  border-radius: 8px;
  background: #f1f5f9;
}

.drawer-tabs__item {
  flex: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-width: 0;
  border: none;
  background: transparent;
  color: #64748b;
  font-size: 13px;
  font-weight: 500;
  line-height: 1.2;
  padding: 8px 10px;
  border-radius: 6px;
  cursor: pointer;
  transition: background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
}

.drawer-tabs__item--active {
  background: #ffffff;
  color: #0f172a;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06);
}

.drawer-tabs__badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 999px;
  background: #e2e8f0;
  color: #475569;
  font-size: 11px;
  font-weight: 600;
}

.section-heading {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: #64748b;
}

.form-section--divider {
  border-top: 1px solid #f1f5f9;
  padding-top: 16px;
}

.field-label {
  display: block;
  margin-bottom: 6px;
  font-size: 13px;
  font-weight: 500;
  color: #334155;
}

.soft-input :deep(.q-field__control) {
  min-height: 40px;
  border-radius: 8px;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.05);
}

.soft-input :deep(.q-field--outlined .q-field__control:before) {
  border: 1px solid #e2e8f0;
}

.soft-input :deep(.q-field--outlined:hover .q-field__control:before) {
  border-color: #cbd5e1;
}

.soft-input :deep(.q-field__native),
.soft-input :deep(.q-field__input) {
  font-weight: 500;
}

.soft-input--textarea :deep(.q-field__control) {
  min-height: 72px;
  height: auto;
}

.phone-fuse {
  display: flex;
  align-items: stretch;
  min-height: 40px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.05);
  overflow: hidden;
  background: #ffffff;
}

.phone-fuse :deep(.q-field) {
  margin-bottom: 0;
}

.phone-fuse :deep(.q-field__control) {
  min-height: 40px;
  height: 40px;
  border-radius: 0;
  box-shadow: none;
}

.phone-fuse :deep(.q-field__control:before),
.phone-fuse :deep(.q-field__control:after) {
  border: none !important;
}

.phone-fuse__country {
  width: 88px;
  flex: 0 0 88px;
}

.phone-fuse__country :deep(.q-field__control) {
  padding-left: 12px;
  padding-right: 0;
}

.phone-fuse__country :deep(.q-field__native) {
  font-weight: 500;
  min-width: 0;
}

.phone-fuse__country :deep(.q-field__append) {
  padding-left: 0;
}

.phone-fuse__number :deep(.q-field__control) {
  padding-left: 12px;
  padding-right: 12px;
}

.phone-fuse__number :deep(.q-field__native) {
  font-weight: 500;
}

.phone-fuse__sep {
  width: 1px;
  flex-shrink: 0;
  align-self: stretch;
  background: #e2e8f0;
}

.color-field {
  width: 100%;
}

.color-swatch {
  width: 32px;
  height: 32px;
  flex-shrink: 0;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  cursor: pointer;
  padding: 0;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.05);
}

.settings-row {
  padding: 4px 0;
}

.settings-row__label {
  font-size: 13px;
  font-weight: 500;
  color: #0f172a;
}

.settings-row__hint {
  margin-top: 2px;
  font-size: 12px;
  color: #64748b;
}

/* Dark mode */
body.body--dark .customer-drawer,
body.body--dark .header-surface {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

body.body--dark .drawer-tabs__track {
  background: #262626;
}

body.body--dark .drawer-tabs__item {
  color: #94a3b8;
}

body.body--dark .drawer-tabs__item--active {
  background: #1c1c1c;
  color: #f8fafc;
}

body.body--dark .form-section--divider {
  border-top-color: #2e2e2e;
}

body.body--dark .phone-fuse {
  background: #1c1c1c;
  border-color: #334155;
}

body.body--dark .phone-fuse__sep {
  background: #334155;
}

body.body--dark .soft-input :deep(.q-field--outlined .q-field__control:before) {
  border-color: #334155;
}

body.body--dark .color-swatch {
  border-color: #334155;
}
</style>
