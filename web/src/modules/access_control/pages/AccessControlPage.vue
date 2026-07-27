<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header section adhering to PAGE_HEADER.md -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Administration</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Access Control</h1>
        </div>
        <div class="col-auto" v-if="tenant">
          <q-chip
            dense
            square
            class="costing-status-chip"
            :style="tenant?.is_active ? activeStatusStyle : inactiveStatusStyle"
          >
            <span
              class="status-dot"
              :style="{ backgroundColor: tenant?.is_active ? '#2f8b5d' : '#66758c' }"
            />
            {{ tenant?.is_active ? 'Active' : 'Inactive' }}
          </q-chip>
        </div>
      </section>

      <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
        {{ pageError }}
      </q-banner>

      <PageInitialLoader v-if="pageLoading" />

      <template v-else>
        <div v-if="!tenant" class="text-grey-7 q-pa-lg text-center">Tenant not found.</div>

        <div v-else class="row q-col-gutter-lg">
          <!-- Main Content Area -->
          <div class="col-12">
            <!-- Top Tab Navigation -->
            <q-card flat class="floating-surface shadow-1 q-mb-md">
              <q-tabs
                :model-value="activeTab"
                dense
                class="text-grey-8"
                active-color="primary"
                indicator-color="primary"
                align="left"
                @update:model-value="onTabChange"
              >
                <q-tab name="modules" icon="ph ph-squares-four" label="Module Features" />
                <q-tab name="roles" icon="ph ph-shield-check" label="Roles &amp; Permissions" />
                <q-tab name="team" icon="ph ph-users" label="Team Members" />
                <q-tab name="customer-groups" icon="ph ph-user-list" label="Customer Groups" />
              </q-tabs>
            </q-card>

            <q-tab-panels
              v-model="activeTab"
              animated
              swipeable
              vertical
              transition-prev="jump-up"
              transition-next="jump-up"
              class="bg-transparent"
            >
              <!-- 1. MODULES PANEL -->
              <q-tab-panel name="modules" class="q-pa-none">
                <ModuleFeaturesTab
                  :tenant-id="tenantId"
                  :can-manage-modules="canManageModules"
                  :is-loading="tenantModulesQuery.isLoading.value"
                  :available-modules="availableModules"
                  :modules="modules"
                  @add-feature="addTenantFeature"
                  @remove-feature="removeTenantFeature"
                />
              </q-tab-panel>

              <!-- 2. ROLES PANEL -->
              <q-tab-panel name="roles" class="q-pa-none">
                <RolesPermissionsTab
                  v-model:scope-filter="rolesScopeFilter"
                  :is-loading="tenantRolesQuery.isLoading.value"
                  :filtered-roles="filteredRoles"
                  @create-role="openCreateRoleDialog"
                  @edit-role="openEditRoleDialog"
                  @delete-role="openDeleteRoleDialog"
                  @navigate-grants="navigateToGrants"
                />
              </q-tab-panel>

              <!-- 3. TEAM MEMBERS PANEL -->
              <q-tab-panel name="team" class="q-pa-none">
                <TeamMembersTab
                  :is-loading="tenantMembersLoading"
                  :tenant-members="tenantMembers"
                  :app-roles="appRoles"
                  :has-overrides-map="hasOverridesMap"
                  :investor-name-by-id="investorNameById"
                  @add-member="onClickAddMember"
                  @change-role="onChangeMemberRole"
                  @toggle-active="onToggleMemberActive"
                  @delete-member="onClickDeleteMember"
                  @open-overrides="openOverridesDialog"
                />
              </q-tab-panel>

              <!-- 4. CUSTOMER GROUPS PANEL -->
              <q-tab-panel name="customer-groups" class="q-pa-none">
                <CustomerGroupsTab
                  :groups-loading="customerGroupsLoading"
                  :members-loading="customerGroupMembersLoading"
                  :sorted-customer-groups="sortedCustomerGroups"
                  :selected-group-id="selectedCustomerGroupId"
                  :selected-group="selectedCustomerGroup"
                  :sorted-members="sortedCustomerGroupMembers"
                  :linked-billing-profiles="linkedBillingProfiles"
                  :shop-roles="shopRoles"
                  :has-cgm-overrides-map="hasCgmOverridesMap"
                  @create-group="openCreateGroupDialog"
                  @edit-group="openEditGroupDialog"
                  @delete-group="openDeleteGroupDialog"
                  @select-group="selectCustomerGroup"
                  @create-member="openCreateCustomerMemberDialog"
                  @edit-member="openEditCustomerMemberDialog"
                  @delete-member="openDeleteCustomerMemberDialog"
                  @change-member-role="onChangeCustomerMemberRole"
                  @toggle-member-active="onToggleCustomerGroupMemberActive"
                  @open-link-profile="openLinkProfileDialog"
                  @unlink-profile="unlinkProfile"
                  @open-overrides="openOverridesDialog"
                />
              </q-tab-panel>
            </q-tab-panels>
          </div>
        </div>
      </template>

      <!-- Dialogs -->
      <RoleFormDialog
        v-model="roleDialogOpen"
        :is-edit="isRoleEdit"
        :selected-role="selectedRole"
        :submitting="roleSubmitting"
        @save="saveRole"
      />

      <DeleteRoleDialog
        v-model="roleDeleteDialogOpen"
        :role-name="selectedRole?.name"
        :deleting="roleDeleting"
        @confirm="confirmDeleteRole"
      />

      <PermissionOverridesDialog
        v-model="overridesDialogOpen"
        :member="overridesDialogMember"
        :role-name="overridesMemberRoleName"
        :loading="overridesLoading"
        :actions="overridesActions"
        :grants="overridesGrants"
        :inherited-grants="overridesInheritedGrants"
        :saving-map="overridesSavingMap"
        @toggle-override="toggleOverrideHandler"
      />

      <AddMemberDialog
        v-model="openAddMemberDialog"
        :selected-member-role="selectedMemberRole"
        :investor-options="tenantInvestorsOptions"
        @save="handleSaveMember"
      />

      <DeleteMemberDialog
        v-model="openDeleteMemberDialog"
        :member-email="memberToDelete?.email"
        @confirm="confirmDeleteMember"
      />

      <CustomerGroupFormDialog
        v-model="openCustomerGroupDialog"
        :initial-form="customerGroupForm"
        @save="handleSaveCustomerGroup"
      />

      <DeleteCustomerGroupDialog
        v-model="openDeleteCustomerGroupDialog"
        :group-name="customerGroupToDelete?.name"
        @confirm="confirmDeleteCustomerGroup"
      />

      <CustomerGroupMemberFormDialog
        v-model="openCustomerMemberDialog"
        :initial-form="customerGroupMemberForm"
        @save="handleSaveCustomerGroupMember"
      />

      <DeleteCustomerGroupMemberDialog
        v-model="openDeleteCustomerMemberDialogModel"
        :member-email="customerGroupMemberToDelete?.email"
        @confirm="confirmDeleteCustomerGroupMember"
      />

      <LinkBillingProfileDialog
        v-model="linkProfileDialogOpen"
        :group-name="selectedCustomerGroup?.name"
        :unassociated-profile-options="unassociatedProfileOptions"
        :saving="billingProfileStore.saving"
        @create-profile="goToBillingProfileCreate"
        @submit="submitLinkProfile"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { supabase } from 'src/boot/supabase';
import { showSuccessNotification } from 'src/utils/appFeedback';
import { useRouter, useRoute } from 'vue-router';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useMembershipStore } from 'src/modules/membership/stores/membershipStore';
import type { Membership, TenantMembershipRole } from 'src/modules/membership/types';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import { useBillingProfileStore } from 'src/modules/sales_invoice/stores/billingProfileStore';
import { useTenantModuleStore } from 'src/modules/tenant/stores/tenantModuleStore';
import { useModuleStore } from 'src/modules/featureCatalog/stores/moduleStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type {
  CustomerGroup,
  CustomerGroupMember,
  Tenant,
} from 'src/modules/tenant/types';

// Tab Subcomponents
import ModuleFeaturesTab from '../components/tabs/ModuleFeaturesTab.vue';
import RolesPermissionsTab from '../components/tabs/RolesPermissionsTab.vue';
import TeamMembersTab from '../components/tabs/TeamMembersTab.vue';
import CustomerGroupsTab from '../components/tabs/CustomerGroupsTab.vue';

// TanStack Query hooks
import {
  useTenantModulesQuery,
  useCatalogModulesQuery,
  useTenantRolesQuery,
  useMemberOverrideIdsQuery,
  useCgmOverrideIdsQuery,
  useTenantMembersQuery,
  useCustomerGroupsQuery,
  useCustomerGroupMembersQuery,
  useBillingProfilesQuery,
  useInvestorsQuery,
} from '../composables/useAccessControlQueries';

// Dialog components
import RoleFormDialog from '../components/dialogs/RoleFormDialog.vue';
import DeleteRoleDialog from '../components/dialogs/DeleteRoleDialog.vue';
import PermissionOverridesDialog from '../components/dialogs/PermissionOverridesDialog.vue';
import AddMemberDialog from '../components/dialogs/AddMemberDialog.vue';
import DeleteMemberDialog from '../components/dialogs/DeleteMemberDialog.vue';
import CustomerGroupFormDialog, {
  type CustomerGroupFormData,
} from '../components/dialogs/CustomerGroupFormDialog.vue';
import DeleteCustomerGroupDialog from '../components/dialogs/DeleteCustomerGroupDialog.vue';
import CustomerGroupMemberFormDialog, {
  type CustomerMemberFormData,
} from '../components/dialogs/CustomerGroupMemberFormDialog.vue';
import DeleteCustomerGroupMemberDialog from '../components/dialogs/DeleteCustomerGroupMemberDialog.vue';
import LinkBillingProfileDialog from '../components/dialogs/LinkBillingProfileDialog.vue';

// Styling helpers
const activeStatusStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
  boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
};

const inactiveStatusStyle = {
  backgroundColor: '#dbe5f3',
  color: '#3b4b66',
  border: '1px solid #b9c8dd',
  boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
};

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

// Main stores
const tenantStore = useTenantStore();
const tenantModuleStore = useTenantModuleStore();
const moduleStore = useModuleStore();
const membershipStore = useMembershipStore();
const customerGroupStore = useCustomerGroupStore();
const billingProfileStore = useBillingProfileStore();

const tenantId = computed(() => authStore.tenantId);
const tenant = computed<Tenant | null>(
  () => tenantStore.items.find((t) => t.id === tenantId.value) || null,
);

const pageLoading = ref(false);
const pageError = ref<string | null>(null);
const activeTab = computed(() => String(route.params.tab || 'modules'));

const onTabChange = (newTab: string | number) => {
  const tenantSlug = authStore.tenantSlug;
  const path = tenantSlug
    ? `/${tenantSlug}/app/access-control/${newTab}`
    : `/app/access-control/${newTab}`;
  void router.push(path);
};

// Superadmin bypass check
const canManageModules = computed(() => {
  return authStore.matchedRole === 'superadmin' && authStore.scope === 'platform';
});

// Tab-scoped enabled flags for lazy TanStack Query execution
const isModulesTab = computed(() => activeTab.value === 'modules');
const isRolesTab = computed(() => activeTab.value === 'roles');
const isTeamTab = computed(() => activeTab.value === 'team');
const isCustomerGroupsTab = computed(() => activeTab.value === 'customer-groups');

// 1. TanStack Queries
const tenantModulesQuery = useTenantModulesQuery(tenantId, isModulesTab);
const catalogModulesQuery = useCatalogModulesQuery(isModulesTab);

const rolesScopeFilter = ref<'app' | 'shop'>('app');
const isRolesTabOrTeamOrGroup = computed(
  () => isRolesTab.value || isTeamTab.value || isCustomerGroupsTab.value,
);

const appRolesQuery = useTenantRolesQuery(tenantId, ref('app'), isRolesTabOrTeamOrGroup);
const shopRolesQuery = useTenantRolesQuery(tenantId, ref('shop'), isRolesTabOrTeamOrGroup);

const appRoles = computed(() => appRolesQuery.data.value || []);
const shopRoles = computed(() => shopRolesQuery.data.value || []);
const filteredRoles = computed(() =>
  rolesScopeFilter.value === 'app' ? appRoles.value : shopRoles.value,
);

const tenantRolesQuery = computed(() =>
  rolesScopeFilter.value === 'app' ? appRolesQuery : shopRolesQuery,
);

const memberOverridesQuery = useMemberOverrideIdsQuery(tenantId, isTeamTab);
const tenantMembersQuery = useTenantMembersQuery(tenantId, isTeamTab);
const tenantMembers = computed<Membership[]>(() => (tenantMembersQuery.data.value as Membership[]) || []);
const tenantMembersLoading = computed(() => tenantMembersQuery.isLoading.value);

const customerGroupsQuery = useCustomerGroupsQuery(tenantId, isCustomerGroupsTab);
const customerGroups = computed<CustomerGroup[]>(() => customerGroupsQuery.data.value || []);
const customerGroupsLoading = computed(() => customerGroupsQuery.isLoading.value);

const selectedCustomerGroupId = ref<number | null>(null);
const cgmOverridesQuery = useCgmOverrideIdsQuery(selectedCustomerGroupId, isCustomerGroupsTab);
const customerGroupMembersQuery = useCustomerGroupMembersQuery(selectedCustomerGroupId, isCustomerGroupsTab);
const customerGroupMembers = computed<CustomerGroupMember[]>(() => customerGroupMembersQuery.data.value || []);
const customerGroupMembersLoading = computed(() => customerGroupMembersQuery.isLoading.value);

const billingProfilesQuery = useBillingProfilesQuery(tenantId, isCustomerGroupsTab);
const billingProfiles = computed(() => billingProfilesQuery.data.value || []);

const investorsQuery = useInvestorsQuery(isTeamTab);
const allInvestors = computed(() => investorsQuery.data.value || []);

const modules = computed(() => tenantModulesQuery.data.value || []);

// Auto-select first customer group when groups load if none is selected
watch(customerGroups, (groups) => {
  if (groups.length > 0 && !selectedCustomerGroupId.value && groups[0]) {
    selectedCustomerGroupId.value = groups[0].id;
  }
}, { immediate: true });

// -------------------------------------------------------------
// 1. MODULES FUNCTIONALITY
// -------------------------------------------------------------
const availableModules = computed(() => {
  const catalog = catalogModulesQuery.data.value || [];
  const activeKeys = (tenantModulesQuery.data.value || []).map((m) => m.module_key);
  return catalog.filter((m) => !m.parent_module_key && !activeKeys.includes(m.key));
});

const addTenantFeature = async (moduleKey: string) => {
  if (!tenantId.value) return;
  const childSubmodules = moduleStore.submodulesOf(moduleKey).map((sub) => sub.key);
  const result = await tenantModuleStore.createTenantModuleWithSubmodules(
    tenantId.value,
    moduleKey,
    childSubmodules,
  );
  if (!result.success) {
    pageError.value = result.error ?? 'Failed to add feature and submodules';
  } else {
    void tenantModulesQuery.refetch();
  }
};

const removeTenantFeature = async (id: number) => {
  if (!tenantId.value) return;
  const targetModule = (tenantModulesQuery.data.value || []).find((m) => m.id === id);
  if (!targetModule) return;

  const parentKey = targetModule.module_key;
  const childSubmodules = moduleStore.submodulesOf(parentKey).map((sub) => sub.key);
  const keysToDelete = [parentKey, ...childSubmodules];

  const result = await tenantModuleStore.deleteTenantModuleWithSubmodules(
    tenantId.value,
    keysToDelete,
  );
  if (!result.success) {
    pageError.value = result.error ?? 'Failed to remove feature and submodules';
  } else {
    void tenantModulesQuery.refetch();
  }
};

// -------------------------------------------------------------
// 2. ROLES FUNCTIONALITY
// -------------------------------------------------------------
const roleDialogOpen = ref(false);
const roleDeleteDialogOpen = ref(false);
const isRoleEdit = ref(false);
const selectedRole = ref<any>(null);
const roleSubmitting = ref(false);
const roleDeleting = ref(false);

const openCreateRoleDialog = () => {
  isRoleEdit.value = false;
  selectedRole.value = null;
  roleDialogOpen.value = true;
};

const openEditRoleDialog = (role: any) => {
  isRoleEdit.value = true;
  selectedRole.value = role;
  roleDialogOpen.value = true;
};

const openDeleteRoleDialog = (role: any) => {
  selectedRole.value = role;
  roleDeleteDialogOpen.value = true;
};

const saveRole = async (form: { name: string; slug: string; is_admin: boolean }) => {
  if (!tenantId.value || !form.name.trim() || !form.slug.trim()) return;
  roleSubmitting.value = true;
  try {
    if (isRoleEdit.value && selectedRole.value) {
      const { error } = await supabase.rpc('update_tenant_role', {
        p_role_id: selectedRole.value.id,
        p_name: form.name,
        p_is_admin: form.is_admin,
      });
      if (error) throw error;
      showSuccessNotification('Role updated successfully.');
    } else {
      const { error } = await supabase.rpc('create_tenant_role', {
        p_tenant_id: tenantId.value,
        p_scope: rolesScopeFilter.value,
        p_name: form.name,
        p_slug: form.slug,
        p_is_admin: form.is_admin,
      });
      if (error) throw error;
      showSuccessNotification('Role created successfully.');
    }
    roleDialogOpen.value = false;
    void tenantRolesQuery.value.refetch();
  } catch (err: any) {
    pageError.value = err.message || 'Failed to save role';
  } finally {
    roleSubmitting.value = false;
  }
};

const confirmDeleteRole = async () => {
  if (!selectedRole.value) return;
  roleDeleting.value = true;
  try {
    const { error } = await supabase.rpc('delete_tenant_role', {
      p_role_id: selectedRole.value.id,
    });
    if (error) throw error;
    showSuccessNotification('Role deleted successfully.');
    roleDeleteDialogOpen.value = false;
    void tenantRolesQuery.value.refetch();
  } catch (err: any) {
    pageError.value = err.message || 'Failed to delete role';
  } finally {
    roleDeleting.value = false;
  }
};

const navigateToGrants = (roleId: number) => {
  const tenantSlug = authStore.tenantSlug;
  if (tenantSlug) {
    void router.push(`/${tenantSlug}/app/access-control/roles/${roleId}/grants`);
  } else {
    void router.push(`/app/access-control/roles/${roleId}/grants`);
  }
};

// -------------------------------------------------------------
// 3. TEAM FUNCTIONALITY (App Members)
// -------------------------------------------------------------
const openAddMemberDialog = ref(false);
const openDeleteMemberDialog = ref(false);
const memberToDelete = ref<Membership | null>(null);
const selectedMemberRole = ref<TenantMembershipRole>('staff');

const hasOverridesMap = computed(() => {
  const ids = memberOverridesQuery.data.value || new Set<number>();
  return tenantMembers.value.reduce(
    (acc, m) => {
      acc[m.id] = ids.has(m.id);
      return acc;
    },
    {} as Record<number, boolean>,
  );
});

const loadTenantMembers = async () => {
  await tenantMembersQuery.refetch();
};

const onClickAddMember = (roleType: TenantMembershipRole) => {
  selectedMemberRole.value = roleType;
  openAddMemberDialog.value = true;
};

const handleSaveMember = async (payload: {
  email: string;
  role: TenantMembershipRole;
  isActive: boolean;
  investorId: number | null;
}) => {
  if (!tenantId.value || !payload.email.trim()) return;
  try {
    const result = await membershipStore.createMembership({
      tenant_id: tenantId.value,
      email: payload.email,
      role: payload.role,
      is_active: payload.isActive,
      investor_id: payload.investorId || null,
    });
    if (result.success) {
      showSuccessNotification('Member added successfully.');
      openAddMemberDialog.value = false;
      await loadTenantMembers();
    } else {
      pageError.value = result.error || 'Failed to save member.';
    }
  } catch (err) {
    console.error(err);
  }
};

const onChangeMemberRole = async (member: any, roleId: number) => {
  try {
    const { error } = await supabase.rpc('assign_membership_role', {
      p_membership_id: member.id,
      p_tenant_role_id: roleId,
    });
    if (error) {
      pageError.value = error.message;
      await loadTenantMembers();
    } else {
      showSuccessNotification('Member role updated successfully.');
      await loadTenantMembers();
    }
  } catch (err) {
    console.error(err);
    pageError.value = 'Failed to update member role.';
  }
};

const onToggleMemberActive = async (member: Membership, isActive: boolean) => {
  try {
    const result = await membershipStore.updateMembership({
      ...member,
      is_active: isActive,
    });
    if (!result.success) {
      pageError.value = result.error || 'Failed to update member active status.';
      member.is_active = !isActive;
    } else {
      showSuccessNotification('Member status updated.');
    }
  } catch (error) {
    console.error(error);
    member.is_active = !isActive;
  }
};

const onClickDeleteMember = (member: Membership) => {
  if (member.role === 'admin') return;
  memberToDelete.value = member;
  openDeleteMemberDialog.value = true;
};

const confirmDeleteMember = async () => {
  if (!memberToDelete.value) return;
  if (memberToDelete.value.role === 'admin') return;
  try {
    const result = await membershipStore.deleteMembership({ id: memberToDelete.value.id });
    if (result.success) {
      showSuccessNotification('Member deleted successfully.');
      openDeleteMemberDialog.value = false;
      await loadTenantMembers();
    } else {
      pageError.value = result.error || 'Failed to delete member.';
    }
  } catch (err) {
    console.error(err);
  }
};

// -------------------------------------------------------------
// 4. CUSTOMER GROUPS FUNCTIONALITY
// -------------------------------------------------------------
const openCustomerGroupDialog = ref(false);
const openDeleteCustomerGroupDialog = ref(false);
const openCustomerMemberDialog = ref(false);
const openDeleteCustomerMemberDialogModel = ref(false);
const customerGroupToDelete = ref<CustomerGroup | null>(null);
const customerGroupMemberToDelete = ref<CustomerGroupMember | null>(null);

const customerGroupForm = ref<any>(null);
const customerGroupMemberForm = ref<any>(null);

const hasCgmOverridesMap = computed(() => {
  const ids = cgmOverridesQuery.data.value || new Set<number>();
  return customerGroupMembers.value.reduce(
    (acc, m) => {
      acc[m.id] = ids.has(m.id);
      return acc;
    },
    {} as Record<number, boolean>,
  );
});

const selectedCustomerGroup = computed(() => {
  return customerGroups.value.find((cg) => cg.id === selectedCustomerGroupId.value) || null;
});

const sortedCustomerGroups = computed(() => {
  return [...customerGroups.value].sort((a, b) => a.name.localeCompare(b.name));
});

const sortedCustomerGroupMembers = computed(() => {
  return [...customerGroupMembers.value].sort((a, b) => (a.name || '').localeCompare(b.name || ''));
});

const selectCustomerGroup = (groupId: number) => {
  selectedCustomerGroupId.value = groupId;
};

const linkedBillingProfiles = computed(() => {
  if (!selectedCustomerGroupId.value) return [];
  return billingProfiles.value.filter(
    (p) => p.customer_group_id === selectedCustomerGroupId.value,
  );
});

const unassociatedProfileOptions = computed(() => {
  return billingProfiles.value
    .filter((p) => p.customer_group_id !== selectedCustomerGroupId.value)
    .map((p) => ({
      label: p.customer_group_id
        ? `${p.name} (Group #${p.customer_group_id})`
        : p.name,
      value: p.id,
    }));
});

const linkProfileDialogOpen = ref(false);

const openLinkProfileDialog = () => {
  linkProfileDialogOpen.value = true;
};

const goToBillingProfileCreate = () => {
  linkProfileDialogOpen.value = false;
  void router.push({
    name: 'app-global-billing-profiles',
    params: {
      tenantSlug: authStore.tenantSlug || '',
    },
    query: {
      create: 'true',
    },
  });
};

const submitLinkProfile = async (profileId: number) => {
  if (!selectedCustomerGroupId.value) return;
  const profile = billingProfileStore.items.find((p) => p.id === profileId);
  if (!profile) return;

  const res = await billingProfileStore.updateBillingProfile({
    id: profile.id,
    patch: {
      name: profile.name,
      customer_group_id: selectedCustomerGroupId.value,
      email: profile.email || null,
      phone: profile.phone || null,
      address: profile.address || null,
      color: profile.color || null,
    },
  });
  if (res.success) {
    linkProfileDialogOpen.value = false;
  }
};

const unlinkProfile = async (profile: any) => {
  await billingProfileStore.updateBillingProfile({
    id: profile.id,
    patch: {
      name: profile.name,
      customer_group_id: null,
      email: profile.email || null,
      phone: profile.phone || null,
      address: profile.address || null,
      color: profile.color || null,
    },
  });
};

const openCreateGroupDialog = () => {
  customerGroupForm.value = {
    id: null,
    name: '',
    accentColor: '',
    isActive: true,
  };
  openCustomerGroupDialog.value = true;
};

const openEditGroupDialog = (group: CustomerGroup) => {
  customerGroupForm.value = {
    id: group.id,
    name: group.name,
    accentColor: group.accent_color || '',
    isActive: group.is_active,
  };
  openCustomerGroupDialog.value = true;
};

const openDeleteGroupDialog = (group: CustomerGroup) => {
  customerGroupToDelete.value = group;
  openDeleteCustomerGroupDialog.value = true;
};

const handleSaveCustomerGroup = async (form: CustomerGroupFormData) => {
  if (!tenantId.value || !form.name.trim()) return;
  try {
    if (form.id) {
      await customerGroupStore.updateCustomerGroup({
        id: form.id,
        tenant_id: tenantId.value,
        name: form.name,
        accent_color: form.accentColor,
        is_active: form.isActive,
      });
      showSuccessNotification('Customer group updated.');
    } else {
      await customerGroupStore.createCustomerGroup({
        tenant_id: tenantId.value,
        name: form.name,
        accent_color: form.accentColor,
        is_active: form.isActive,
      });
      showSuccessNotification('Customer group created.');
    }
    openCustomerGroupDialog.value = false;
    await customerGroupStore.fetchCustomerGroupsByTenant(tenantId.value);
  } catch (err) {
    console.error(err);
  }
};

const confirmDeleteCustomerGroup = async () => {
  if (!customerGroupToDelete.value) return;
  try {
    await customerGroupStore.deleteCustomerGroup({ id: customerGroupToDelete.value.id });
    showSuccessNotification('Customer group deleted.');
    openDeleteCustomerGroupDialog.value = false;
    selectedCustomerGroupId.value = null;
    await customerGroupStore.fetchCustomerGroupsByTenant(tenantId.value!);
  } catch (err) {
    console.error(err);
  }
};

const openCreateCustomerMemberDialog = () => {
  customerGroupMemberForm.value = {
    id: null,
    email: '',
    name: '',
    isActive: true,
  };
  openCustomerMemberDialog.value = true;
};

const openEditCustomerMemberDialog = (member: CustomerGroupMember) => {
  customerGroupMemberForm.value = {
    id: member.id,
    email: member.email,
    name: member.name || '',
    isActive: member.is_active,
  };
  openCustomerMemberDialog.value = true;
};

const openDeleteCustomerMemberDialog = (member: CustomerGroupMember) => {
  customerGroupMemberToDelete.value = member;
  openDeleteCustomerMemberDialogModel.value = true;
};

const handleSaveCustomerGroupMember = async (form: CustomerMemberFormData) => {
  if (!selectedCustomerGroupId.value) return;
  try {
    if (form.id) {
      await customerGroupStore.updateCustomerGroupMember({
        id: form.id,
        customer_group_id: selectedCustomerGroupId.value,
        name: form.name,
        email: form.email,
        is_active: form.isActive,
      });
      showSuccessNotification('Customer user updated.');
    } else {
      await customerGroupStore.createCustomerGroupMember({
        customer_group_id: selectedCustomerGroupId.value,
        name: form.name,
        email: form.email,
        is_active: form.isActive,
        role: 'staff',
      });
      showSuccessNotification('Customer user created.');
    }
    openCustomerMemberDialog.value = false;
    await customerGroupStore.fetchCustomerGroupMembersByGroup(selectedCustomerGroupId.value);
  } catch (err) {
    console.error(err);
  }
};

const onChangeCustomerMemberRole = async (member: any, roleId: number) => {
  try {
    const { error } = await supabase.rpc('assign_customer_group_member_role', {
      p_cgm_id: member.id,
      p_tenant_role_id: roleId,
    });
    if (error) {
      pageError.value = error.message;
    } else {
      showSuccessNotification('Customer member role updated successfully.');
      if (selectedCustomerGroupId.value) {
        await customerGroupStore.fetchCustomerGroupMembersByGroup(selectedCustomerGroupId.value);
      }
    }
  } catch (err) {
    console.error(err);
    pageError.value = 'Failed to update customer member role.';
  }
};

const onToggleCustomerGroupMemberActive = async (
  member: CustomerGroupMember,
  isActive: boolean,
) => {
  if (!selectedCustomerGroupId.value) return;
  try {
    await customerGroupStore.updateCustomerGroupMember({
      ...member,
      is_active: isActive,
    });
    showSuccessNotification('Customer user status updated.');
    await customerGroupStore.fetchCustomerGroupMembersByGroup(selectedCustomerGroupId.value);
  } catch (err) {
    console.error(err);
  }
};

const confirmDeleteCustomerGroupMember = async () => {
  if (!customerGroupMemberToDelete.value || !selectedCustomerGroupId.value) return;
  try {
    await customerGroupStore.deleteCustomerGroupMember({
      id: customerGroupMemberToDelete.value.id,
    });
    showSuccessNotification('Customer user deleted.');
    openDeleteCustomerMemberDialogModel.value = false;
    await customerGroupStore.fetchCustomerGroupMembersByGroup(selectedCustomerGroupId.value);
  } catch (err) {
    console.error(err);
  }
};

// -------------------------------------------------------------
// 5. INVESTORS LOOKUP
// -------------------------------------------------------------

const tenantInvestorsOptions = computed(() => {
  return allInvestors.value.map((i) => ({
    label: i.name,
    value: i.id,
  }));
});

const investorNameById = (id: number): string => {
  return allInvestors.value.find((i) => i.id === id)?.name || `ID #${id}`;
};

// -------------------------------------------------------------
// 6. ACCESSIBILITY OVERRIDES OVERLAY DIALOG
// -------------------------------------------------------------
const overridesDialogOpen = ref(false);
const overridesLoading = ref(false);
const overridesDialogMember = ref<any>(null);
const overridesDialogScope = ref<'app' | 'shop'>('app');
const overridesActions = ref<any[]>([]);
const overridesGrants = ref<Record<string, 'allow' | 'deny' | 'inherit'>>({});
const overridesInheritedGrants = ref<Record<string, boolean>>({});
const overridesMemberRoleName = ref<string>('');
const overridesSavingMap = ref<Record<string, boolean>>({});

const openOverridesDialog = async (member: any, scope: 'app' | 'shop') => {
  if (!tenantId.value) return;
  overridesDialogMember.value = member;
  overridesDialogScope.value = scope;
  overridesDialogOpen.value = true;
  overridesLoading.value = true;
  overridesGrants.value = {};
  overridesInheritedGrants.value = {};
  overridesMemberRoleName.value = '';

  try {
    const roles = scope === 'app' ? appRoles.value : shopRoles.value;
    let role = roles.find((r: any) => r.id === member.tenant_role_id && r.scope === scope);
    if (!role && member.role) {
      role = roles.find(
        (r: any) => r.slug.toLowerCase() === String(member.role).toLowerCase() && r.scope === scope,
      );
    }

    if (role) {
      overridesMemberRoleName.value = role.name;
      if (!role.is_admin) {
        const { data: roleGrants } = await supabase.rpc('list_tenant_role_grants', {
          p_tenant_role_id: role.id,
        });
        const inhMap: Record<string, boolean> = {};
        (roleGrants || []).forEach((rg: any) => {
          inhMap[`${rg.module_key}:${rg.action}`] = Boolean(rg.allowed);
        });
        overridesInheritedGrants.value = inhMap;
      }
    } else if (member.role) {
      overridesMemberRoleName.value = String(member.role);
    }

    const { data: actionsData } = await supabase.rpc('list_configurable_module_actions', {
      p_scope: scope,
      p_tenant_id: tenantId.value,
    });
    overridesActions.value = actionsData || [];

    if (role?.is_admin || member?.role === 'admin') {
      const inhMap: Record<string, boolean> = {};
      (actionsData || []).forEach((act: any) => {
        inhMap[`${act.module_key}:${act.action}`] = true;
      });
      overridesInheritedGrants.value = inhMap;
    }

    if (scope === 'app') {
      const { data: grantsData } = await supabase.rpc('list_membership_grants', {
        p_membership_id: member.id,
      });

      const grantsMap: Record<string, 'allow' | 'deny' | 'inherit'> = {};
      (grantsData || []).forEach((g: any) => {
        grantsMap[`${g.module_key}:${g.action}`] = g.effect as 'allow' | 'deny';
      });
      overridesGrants.value = grantsMap;
    } else {
      const { data: grantsData } = await supabase.rpc('list_customer_group_member_grants', {
        p_cgm_id: member.id,
      });

      const grantsMap: Record<string, 'allow' | 'deny' | 'inherit'> = {};
      (grantsData || []).forEach((g: any) => {
        grantsMap[`${g.module_key}:${g.action}`] = g.effect as 'allow' | 'deny';
      });
      overridesGrants.value = grantsMap;
    }
  } catch (error) {
    console.error('Failed to load member overrides:', error);
  } finally {
    overridesLoading.value = false;
  }
};

const toggleOverrideHandler = async (act: any, effect: 'allow' | 'deny' | 'inherit') => {
  const moduleKey = act.module_key;
  const action = act.action;
  const member = overridesDialogMember.value;
  const scope = overridesDialogScope.value;
  if (!member) return;

  const key = `${moduleKey}:${action}`;
  overridesSavingMap.value[key] = true;

  try {
    if (effect === 'inherit') {
      if (scope === 'app') {
        await supabase.rpc('delete_membership_grant', {
          p_membership_id: member.id,
          p_module_key: moduleKey,
          p_action: action,
        });
      } else {
        await supabase.rpc('delete_customer_group_member_grant', {
          p_cgm_id: member.id,
          p_module_key: moduleKey,
          p_action: action,
        });
      }
      overridesGrants.value[key] = 'inherit';
    } else {
      if (scope === 'app') {
        await supabase.rpc('upsert_membership_grant', {
          p_membership_id: member.id,
          p_module_key: moduleKey,
          p_action: action,
          p_effect: effect,
        });
      } else {
        await supabase.rpc('upsert_customer_group_member_grant', {
          p_cgm_id: member.id,
          p_module_key: moduleKey,
          p_action: action,
          p_effect: effect,
        });
      }
      overridesGrants.value[key] = effect;
    }
    if (scope === 'app') {
      void memberOverridesQuery.refetch();
    } else if (selectedCustomerGroupId.value) {
      void cgmOverridesQuery.refetch();
    }
  } catch (error) {
    console.error('Failed to save override:', error);
  } finally {
    overridesSavingMap.value[key] = false;
  }
};

const loadPageData = async () => {
  pageLoading.value = true;
  pageError.value = null;
  try {
    if (!tenantId.value) return;
    await tenantStore.fetchTenantDetailsByMembership({ tenantId: tenantId.value });
  } catch (err) {
    console.error(err);
    pageError.value = 'Failed to load access control details.';
  } finally {
    pageLoading.value = false;
  }
};

onMounted(() => {
  void loadPageData();
});
</script>

<style scoped>
.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>
