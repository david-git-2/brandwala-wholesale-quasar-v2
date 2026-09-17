<template>
  <WorkspaceShell ref="workspaceShellRef" :logout-to="logoutTo" theme="app" :links="links">
    <template #header-left>
      <AppBreadcrumbs />
    </template>

    <template #header-extra>
      <div class="row items-center q-gutter-x-sm no-wrap">
        <!-- Modern Quick-search trigger (⌘K) -->
        <button
          type="button"
          class="header-quick-search gt-xs"
          aria-label="Search pages"
          @click="workspaceShellRef?.openCommandPalette()"
        >
          <q-icon name="ph ph-magnifying-glass" size="13px" class="q-mr-xs header-quick-search__icon" />
          <span class="header-quick-search__text">Search pages...</span>
          <kbd class="header-quick-search__kbd">⌘K</kbd>
        </button>

        <div class="header-divider gt-xs" />

        <NotificationBell />

        <div class="header-divider gt-xs" />

        <!-- Modernized Workspace / Tenant Switcher Badge -->
        <q-btn-dropdown
          v-if="tenantOptions.length"
          flat
          no-caps
          dense
          class="tenant-switcher-pill q-px-sm"
          menu-class="tenant-switcher-menu"
          :loading="selectingTenantId !== null"
        >
          <template #label>
            <div class="row items-center no-wrap q-gutter-x-xs">
              <q-icon name="ph ph-buildings" size="14px" color="primary" />
              <span class="tenant-switcher-pill__label ellipsis">{{ selectedTenantLabel }}</span>
            </div>
          </template>

          <q-list style="min-width: 240px" class="q-py-xs">
            <q-item-label header class="dropdown-header">
              Companies
            </q-item-label>

            <q-item
              v-for="option in tenantOptions"
              :key="option.value"
              clickable
              v-close-popup
              class="tenant-item"
              :active="option.value === selectedTenantId"
              active-class="tenant-item--active"
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

        <div class="header-divider gt-xs" />

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
        role === 'superadmin' || role === 'admin' || role === 'staff' || role === 'viewer'
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
.header-quick-search {
  display: inline-flex;
  align-items: center;
  height: 30px;
  padding: 0 8px 0 10px;
  border-radius: 8px;
  background: var(--bw-neutral-canvas);
  border: 1px solid var(--bw-neutral-border);
  color: var(--bw-neutral-muted);
  cursor: pointer;
  font-size: 12px;
  font-weight: 500;
  transition: all 0.15s ease-in-out;
}

.header-quick-search:hover {
  border-color: color-mix(in srgb, var(--bw-brand-accent) 40%, var(--bw-neutral-border));
  color: var(--bw-neutral-ink);
  background: var(--bw-neutral-surface);
}

.header-quick-search__icon {
  color: var(--bw-neutral-chrome);
}

.header-quick-search__kbd {
  margin-left: 8px;
  font-size: 10px;
  font-family: var(--bw-font-mono);
  font-weight: 600;
  padding: 1px 5px;
  border-radius: 4px;
  background: var(--bw-neutral-surface);
  border: 1px solid var(--bw-neutral-border);
  color: var(--bw-neutral-chrome);
}

.header-divider {
  width: 1px;
  height: 16px;
  background: var(--bw-neutral-border);
  margin: 0 4px;
}

.tenant-switcher-pill {
  font-weight: 600;
  font-size: 0.8125rem;
  height: 30px;
  border-radius: 8px;
  color: var(--bw-neutral-ink) !important;
  background: var(--bw-neutral-surface);
  border: 1px solid var(--bw-neutral-border);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
  transition: all 0.15s ease-in-out;
}

.tenant-switcher-pill:hover {
  background: color-mix(in srgb, var(--bw-neutral-ink) 4%, var(--bw-neutral-surface));
  border-color: color-mix(in srgb, var(--bw-brand-accent) 30%, var(--bw-neutral-border));
}

.tenant-switcher-pill :deep(.q-btn__content) {
  color: var(--bw-neutral-ink);
}

.tenant-switcher-pill :deep(.q-btn-dropdown__arrow) {
  color: var(--bw-neutral-chrome);
  margin-left: 2px;
}

.tenant-switcher-pill__label {
  color: var(--bw-neutral-ink);
  max-width: 140px;
}

.dropdown-header {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bw-neutral-chrome);
  padding: 8px 14px 2px;
}

.tenant-item {
  min-height: 34px;
  padding: 4px 12px;
  border-radius: 6px;
  margin: 1px 6px;
  font-size: 13px;
  color: var(--bw-neutral-ink);
  transition: background-color 0.15s ease;
}

.tenant-item:hover {
  background: color-mix(in srgb, var(--bw-neutral-ink) 4%, transparent);
}

.tenant-item--active {
  background: var(--bw-theme-primary-soft) !important;
  color: var(--bw-brand-accent) !important;
  font-weight: 600;
}

@media (max-width: 600px) {
  .tenant-switcher-pill__label {
    max-width: 90px;
  }
}
</style>
