<template>
  <WorkspaceShell ref="workspaceShellRef" :logout-to="logoutTo" theme="app" :links="links">
    <template #header-left>
      <AppBreadcrumbs />
    </template>

    <template #header-center>
      <!-- Quick Navigation Omnibar Trigger (Cmd + K) -->
      <button
        type="button"
        class="header-search-trigger row items-center justify-between no-wrap q-px-sm"
        @click="workspaceShellRef?.openCommandPalette()"
      >
        <div class="row items-center no-wrap text-grey-7">
          <q-icon name="ph ph-magnifying-glass" size="13px" class="q-mr-xs text-grey-6" />
          <span class="header-search-trigger__text">Search pages...</span>
        </div>
        <kbd class="header-search-trigger__kbd">⌘K</kbd>
      </button>
    </template>

    <template #header-extra>
      <div class="row items-center q-gutter-x-sm no-wrap">
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
              Workspaces & Locations
            </q-item-label>

            <q-item
              v-for="option in tenantOptions"
              :key="option.value"
              clickable
              v-close-popup
              :active="option.value === selectedTenantId"
              active-class="bg-blue-1 text-primary text-weight-bold"
              :style="{ paddingLeft: 16 + option.depth * 12 + 'px' }"
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
                <q-item-label class="row items-center no-wrap">
                  <span v-if="option.depth > 0" class="text-grey-5 q-mr-xs text-caption">↳</span>
                  <span class="ellipsis text-caption">{{ option.label }}</span>
                </q-item-label>
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
import type { Tenant } from 'src/modules/tenant/types';

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

const tenantOptions = computed(() => {
  const tenants = tenantStore.availableAdminTenants;

  const map = new Map<number, { tenant: Tenant; children: Tenant[] }>();
  tenants.forEach((t) => {
    map.set(t.id, { tenant: t, children: [] });
  });

  const roots: Tenant[] = [];
  tenants.forEach((t) => {
    if (t.parent_id === null || !map.has(t.parent_id)) {
      roots.push(t);
    } else {
      map.get(t.parent_id)?.children.push(t);
    }
  });

  const result: Array<{ label: string; value: number; depth: number }> = [];
  const traverse = (t: Tenant, depth: number) => {
    result.push({
      label: t.name,
      value: t.id,
      depth,
    });
    const entry = map.get(t.id);
    if (entry) {
      entry.children.forEach((child) => traverse(child, depth + 1));
    }
  };

  roots.forEach((root) => traverse(root, 0));
  return result;
});

const selectedTenantLabel = computed(() => {
  const selectedOption =
    tenantOptions.value.find((option) => option.value === selectedTenantId.value) ?? null;

  return selectedOption?.label ?? 'Select workspace';
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
        role === 'admin' || role === 'staff' || role === 'viewer' ? role : null,
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
.header-search-trigger {
  display: flex;
  align-items: center;
  width: 100%;
  max-width: 200px;
  height: 28px;
  padding: 0 8px;
  background: color-mix(in srgb, var(--bw-theme-surface, white) 70%, #f1f5f9 30%);
  border: 1px solid color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 85%, transparent);
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.15s ease-in-out;
}

.header-search-trigger:hover {
  background: var(--bw-theme-surface, white);
  border-color: var(--q-primary, #2563eb);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.header-search-trigger__text {
  font-size: 0.75rem;
  color: #64748b;
  letter-spacing: -0.01em;
}

.header-search-trigger__kbd {
  font-size: 0.625rem;
  font-family: inherit;
  font-weight: 600;
  color: #94a3b8;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  padding: 0px 4px;
  line-height: 1.1;
}

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

body.body--dark .header-search-trigger {
  background: #1e293b;
  border-color: #334155;
}

body.body--dark .header-search-trigger:hover {
  background: #0f172a;
  border-color: #60a5fa;
}

body.body--dark .header-search-trigger__text {
  color: #94a3b8;
}

body.body--dark .header-search-trigger__kbd {
  background: #0f172a;
  border-color: #334155;
  color: #64748b;
}

body.body--dark .tenant-switcher-pill {
  background: #1e293b;
  border-color: #334155;
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
