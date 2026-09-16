<template>
  <WorkspaceShell ref="workspaceShellRef" :logout-to="logoutTo" theme="app" :links="links">
    <template #header-left>
      <AppBreadcrumbs />
    </template>

    <template #header-extra>
      <div class="row items-center q-gutter-x-sm no-wrap">
        <NotificationBell />

        <q-separator vertical inset class="q-mx-xs text-grey-4 gt-xs" />

        <!-- Modernized Workspace / Tenant Switcher Badge -->
        <q-btn-dropdown
          v-if="tenantOptions.length"
          flat
          no-caps
          dense
          class="tenant-switcher-pill q-px-sm"
          :loading="selectingTenantId !== null"
        >
          <template #label>
            <div class="row items-center no-wrap q-gutter-x-xs">
              <q-icon name="ph ph-buildings" size="14px" color="primary" />
              <span class="tenant-switcher-pill__label ellipsis">{{ selectedTenantLabel }}</span>
            </div>
          </template>

          <q-list style="min-width: 240px" class="q-py-xs">
            <q-item-label header class="text-uppercase text-weight-bold text-grey-7" style="font-size: 9px; letter-spacing: 0.1em">
              Companies
            </q-item-label>

            <q-item
              v-for="option in tenantOptions"
              :key="option.value"
              clickable
              v-close-popup
              :active="option.value === selectedTenantId"
              active-class="bg-blue-1 text-primary text-weight-bold"
              @click="onSelectTenant(option.value)"
            >
              <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                <q-icon
                  name="ph ph-buildings"
                  size="13px"
                  :color="option.value === selectedTenantId ? 'primary' : 'grey-6'"
                />
              </q-item-section>
              <q-item-section>
                <q-item-label class="ellipsis text-caption">{{ option.label }}</q-item-label>
              </q-item-section>
              <q-item-section side v-if="option.value === selectedTenantId">
                <q-icon name="ph ph-check" size="xs" color="primary" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>

        <q-separator vertical inset class="q-mx-xs text-grey-4 gt-xs" />

        <!-- User Profile Avatar & Menu (Includes Appearance, Language, Help, Logout) -->
        <UserProfileMenu @sign-out="onMobileSignOut" />
      </div>

      <TaskSearchDialog v-if="searchDialogOpen" v-model="searchDialogOpen" />
      <GlobalStockSearchDialog v-if="stockSearchDialogOpen" v-model="stockSearchDialogOpen" />
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';

import WorkspaceShell from 'src/components/WorkspaceShell.vue';
import AppBreadcrumbs from 'src/components/navigation/AppBreadcrumbs.vue';
import UserProfileMenu from 'src/components/navigation/UserProfileMenu.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useAppWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation';
import { useAdminTenantSelection } from 'src/modules/tenant/composables/useAdminTenantSelection';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useMembershipPreferenceStore } from 'src/modules/membership/stores/membershipPreferenceStore';
import { useTenantPreferenceStore } from 'src/modules/tenant/stores/tenantPreferenceStore';
import { useAppearance } from 'src/composables/useAppearance';
import TaskSearchDialog from 'src/modules/tasks/components/TaskSearchDialog.vue';
import GlobalStockSearchDialog from 'src/modules/global/components/GlobalStockSearchDialog.vue';
import NotificationBell from 'src/modules/notifications/components/NotificationBell.vue';
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const tenantPreferenceStore = useTenantPreferenceStore();
const membershipPreferenceStore = useMembershipPreferenceStore();
const { reconcilePreferences } = useAppearance();

// Layout initialized
const { links } = useAppWorkspaceLinks();

const workspaceShellRef = ref<InstanceType<typeof WorkspaceShell> | null>(null);
const searchDialogOpen = ref(false);
const stockSearchDialogOpen = ref(false);

const onMobileSignOut = () => {
  workspaceShellRef.value?.openSignOutDialog();
};

const logoutTo = computed(() =>
  authStore.tenantSlug ? `/${authStore.tenantSlug}/app/login` : '/app/login',
);
const selectedTenantId = computed(() => tenantStore.selectedTenantId);

const tenantOptions = computed(() =>
  tenantStore.availableAdminTenants.map((tenant) => ({
    label: tenant.name,
    value: tenant.id,
  })),
);

const selectedTenantLabel = computed(() => {
  const selectedOption =
    tenantOptions.value.find((option) => option.value === selectedTenantId.value) ?? null;

  return selectedOption?.label ?? 'Select company';
});
const { ensureSelectedTenantWorkspace, selectTenantWorkspace, selectingTenantId } =
  useAdminTenantSelection();

const onSelectTenant = (tenantId: number | null) => {
  const tenant = tenantStore.availableAdminTenants.find((item) => item.id === tenantId) ?? null;

  if (!tenant) {
    return;
  }

  void selectTenantWorkspace(tenant);
};

onMounted(() => {
  void (async () => {
    if (!tenantStore.availableAdminTenants.length && authStore.user?.email) {
      await tenantStore.fetchTenantsByMembership({
        email: authStore.user.email,
      });
    } else if (tenantStore.hierarchyChildRefs.length === 0) {
      await tenantStore.hydrateHierarchyChildRefs();
    }

    await ensureSelectedTenantWorkspace();

    if (authStore.tenantId) {
      const role = authStore.matchedRole;
      await tenantPreferenceStore.ensureLoaded(
        authStore.tenantId,
        authStore.user?.email ?? null,
        role === 'owner' ||
          role === 'manager' ||
          role === 'admin' ||
          role === 'staff' ||
          role === 'viewer'
          ? role
          : null,
      );
    }

    if (authStore.membershipId) {
      await membershipPreferenceStore.ensureLoaded(
        authStore.membershipId,
        authStore.user?.email ?? null,
        authStore.tenantId,
      );
      await reconcilePreferences(authStore.membershipId, membershipPreferenceStore.preference);
    }
  })();
});
</script>

<style scoped>
.tenant-switcher-pill {
  font-weight: 600;
  font-size: 0.8125rem;
  height: 30px;
  border-radius: 8px;
  color: #1e293b !important;
  background: color-mix(in srgb, var(--q-primary, #047857) 10%, #f8fafc);
  border: 1px solid color-mix(in srgb, var(--q-primary, #047857) 25%, #e2e8f0);
}

.tenant-switcher-pill:hover {
  background: color-mix(in srgb, var(--q-primary, #047857) 15%, #f1f5f9);
}

.tenant-switcher-pill :deep(.q-btn__content) {
  color: #1e293b;
}

.tenant-switcher-pill :deep(.q-btn-dropdown__arrow) {
  color: #64748b;
  margin-left: 2px;
}

.tenant-switcher-pill__label {
  color: #1e293b;
  max-width: 140px;
}

body.body--dark .tenant-switcher-pill {
  background: #1e293b;
  border-color: #334155;
  color: #f8fafc !important;
}

body.body--dark .tenant-switcher-pill :deep(.q-btn__content),
body.body--dark .tenant-switcher-pill__label {
  color: #f8fafc;
}

body.body--dark .tenant-switcher-pill :deep(.q-btn-dropdown__arrow) {
  color: #94a3b8;
}

body.body--dark .bg-blue-1 {
  background: #1e3a8a !important;
}

@media (max-width: 600px) {
  .tenant-switcher-pill__label {
    max-width: 90px;
  }
}
</style>
