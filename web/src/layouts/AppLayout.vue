<template>
  <WorkspaceShell ref="workspaceShellRef" :logout-to="logoutTo" theme="app" :links="links">
    <template #header-left>
      <div class="row items-center q-gutter-sm">
        <q-btn
          v-if="showHeaderBackButton"
          flat
          round
          dense
          size="md"
          color="primary"
          icon="keyboard_backspace"
          class="app-header-back-btn"
          @click="onHeaderBack"
        />
        <div v-if="headerTitle && !hasPageToolbar" class="app-context__title">
          {{ headerTitle }}
        </div>
      </div>
    </template>

    <template #header-extra>
      <!-- Mobile Only: Three Dots (Dropdown Menu) -->
      <div v-if="$q.screen.xs" class="row items-center">
        <q-btn flat round dense color="primary" icon="more_vert">
          <q-menu style="min-width: 180px">
            <q-list class="q-py-xs">
              <q-item-label
                header
                class="text-uppercase text-weight-bold text-grey-7"
                style="font-size: 10px; letter-spacing: 0.1em"
                >Quick Actions</q-item-label
              >

              <!-- Task search on mobile -->
              <q-item v-if="hasTasksModule" clickable @click="searchDialogOpen = true">
                <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                  <q-icon name="assignment" size="sm" color="primary" />
                </q-item-section>
                <q-item-section>Search Tasks</q-item-section>
              </q-item>

              <!-- Stock search on mobile -->
              <q-item v-if="hasGlobalStockModule" clickable @click="stockSearchDialogOpen = true">
                <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                  <q-icon name="inventory_2" size="sm" color="primary" />
                </q-item-section>
                <q-item-section>Search Stock</q-item-section>
              </q-item>

              <template v-if="tenantOptions.length">
                <q-separator class="q-my-xs" />
                <q-item-label
                  header
                  class="text-uppercase text-weight-bold text-grey-7"
                  style="font-size: 10px; letter-spacing: 0.1em"
                  >Workspace</q-item-label
                >
                <q-item
                  v-for="option in tenantOptions"
                  :key="option.value"
                  clickable
                  v-close-popup
                  :active="option.value === selectedTenantId"
                  active-class="text-primary text-weight-bold"
                  :style="{ paddingLeft: 16 + option.depth * 16 + 'px' }"
                  @click="onSelectTenant(option.value)"
                >
                  <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                    <q-icon
                      name="apartment"
                      size="sm"
                      :color="option.value === selectedTenantId ? 'primary' : 'grey-6'"
                    />
                  </q-item-section>
                  <q-item-section>
                    <span v-if="option.depth > 0" class="text-grey-6 q-mr-xs text-weight-bold"
                      >↳</span
                    >
                    {{ option.label }}
                  </q-item-section>
                </q-item>
              </template>

              <q-separator class="q-my-xs" />
              <q-item-label
                header
                class="text-uppercase text-weight-bold text-grey-7"
                style="font-size: 10px; letter-spacing: 0.1em"
                >Appearance</q-item-label
              >

              <q-item clickable @click="toggleDarkMode">
                <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                  <q-icon :name="darkMode ? 'dark_mode' : 'light_mode'" size="sm" color="primary" />
                </q-item-section>
                <q-item-section>Dark Mode</q-item-section>
                <q-item-section side>
                  <q-toggle :model-value="darkMode" @update:model-value="toggleDarkMode" dense />
                </q-item-section>
              </q-item>

              <q-item clickable @click="toggleDensity">
                <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                  <q-icon name="density_medium" size="sm" color="primary" />
                </q-item-section>
                <q-item-section>Compact Rows</q-item-section>
                <q-item-section side>
                  <q-toggle
                    :model-value="density === 'compact'"
                    @update:model-value="toggleDensity"
                    dense
                  />
                </q-item-section>
              </q-item>

              <q-separator class="q-my-xs" />
              <q-item clickable v-close-popup @click="onMobileSignOut">
                <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                  <q-icon name="logout" size="sm" color="negative" />
                </q-item-section>
                <q-item-section class="text-negative text-weight-medium">Sign out</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
      </div>

      <!-- Desktop: global actions in the single top bar -->
      <div v-else class="row items-center q-gutter-sm no-wrap">
        <q-btn
          v-if="hasTasksModule"
          flat
          round
          dense
          size="sm"
          color="primary"
          icon="assignment"
          @click="searchDialogOpen = true"
        >
          <q-tooltip>Search Tasks</q-tooltip>
        </q-btn>

        <q-btn
          v-if="hasGlobalStockModule"
          flat
          round
          dense
          size="sm"
          color="primary"
          icon="inventory_2"
          @click="stockSearchDialogOpen = true"
        >
          <q-tooltip>Search Stock</q-tooltip>
        </q-btn>

        <q-btn-dropdown
          v-if="tenantOptions.length"
          outline
          no-caps
          dense
          size="sm"
          color="primary"
          class="tenant-dropdown-btn pill-btn q-px-md"
          :label="selectedTenantLabel"
          :loading="selectingTenantId !== null"
        >
          <q-list style="min-width: 260px">
            <q-item
              v-for="option in tenantOptions"
              :key="option.value"
              clickable
              :active="option.value === selectedTenantId"
              active-class="bg-primary text-white"
              :style="{ paddingLeft: 16 + option.depth * 16 + 'px' }"
              @click="onSelectTenant(option.value)"
            >
              <q-item-section>
                <q-item-label class="row items-center no-wrap">
                  <span v-if="option.depth > 0" class="text-grey-6 q-mr-xs text-weight-bold"
                    >↳</span
                  >
                  <span>{{ option.label }}</span>
                </q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
      </div>

      <TaskSearchDialog v-if="searchDialogOpen" v-model="searchDialogOpen" />
      <GlobalStockSearchDialog v-if="stockSearchDialogOpen" v-model="stockSearchDialogOpen" />
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import WorkspaceShell from 'src/components/WorkspaceShell.vue';
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
const route = useRoute();
const router = useRouter();
const { links } = useAppWorkspaceLinks();

const workspaceShellRef = ref<InstanceType<typeof WorkspaceShell> | null>(null);
const searchDialogOpen = ref(false);
const stockSearchDialogOpen = ref(false);

const { darkMode, setDarkMode, density, setDensity, reconcilePreferences } = useAppearance();

const toggleDarkMode = () => {
  void setDarkMode(!darkMode.value, authStore.membershipId);
};

const toggleDensity = () => {
  const nextDensity = density.value === 'compact' ? 'comfortable' : 'compact';
  void setDensity(nextDensity, authStore.membershipId);
};

const hasPageToolbar = computed(() => route.meta?.hasPageToolbar === true);

const onMobileSignOut = () => {
  workspaceShellRef.value?.openSignOutDialog();
};
const hasTasksModule = computed(() => authStore.activeModuleKeys.includes('tasks'));
const hasGlobalStockModule = computed(() => authStore.activeModuleKeys.includes('global_stock'));
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

const tenantMenuOpen = ref(false);
const selectedTenantLabel = computed(() => {
  const selectedOption =
    tenantOptions.value.find((option) => option.value === selectedTenantId.value) ?? null;

  return selectedOption?.label ?? 'Select tenant';
});
const { ensureSelectedTenantWorkspace, selectTenantWorkspace, selectingTenantId } =
  useAdminTenantSelection();

const routeName = computed(() => String(route.name ?? ''));
const routeMetaTitle = computed(() =>
  typeof route.meta?.title === 'string' ? route.meta.title.trim() : '',
);
const routeMetaHeaderTitle = computed(() =>
  typeof route.meta?.headerTitle === 'string' ? route.meta.headerTitle.trim() : '',
);

const prettifyRouteName = (name: string) =>
  name
    .replace(/-(page|details)$/g, '')
    .split('-')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');

const headerTitle = computed(() => {
  if (routeMetaHeaderTitle.value) {
    return routeMetaHeaderTitle.value;
  }

  if (routeMetaTitle.value) {
    return routeMetaTitle.value;
  }

  if (routeName.value) {
    return prettifyRouteName(routeName.value);
  }

  return 'App';
});

const inferredBackRouteName = computed(() => {
  const name = routeName.value;
  if (!name.includes('details')) {
    return null;
  }

  const mapped = name.replace(/-details-page$/, '-page');
  if (mapped !== name && router.hasRoute(mapped)) {
    return mapped;
  }

  return null;
});

const showHeaderBackButton = computed(() => {
  const metaFlag = route.meta?.showHeaderBackButton;
  if (metaFlag === false) {
    return false;
  }

  if (metaFlag === true) {
    return true;
  }

  return routeName.value.includes('details');
});

const onHeaderBack = () => {
  if (window.history.length > 1) {
    router.back();
    return;
  }

  if (inferredBackRouteName.value) {
    void router.push({ name: inferredBackRouteName.value });
    return;
  }

  void router.push({ name: 'app-dashboard' });
};

const onSelectTenant = (tenantId: number | null) => {
  tenantMenuOpen.value = false;

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
.app-context__title {
  overflow: hidden;
  font-size: clamp(0.92rem, 1.35vw, 1.15rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--bw-theme-ink);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.app-layout__tenant-chip {
  max-width: min(21rem, 58vw);
  font-weight: 600;
  border-radius: 8px;
}

.app-header-back-btn {
  font-weight: 700;
  border: 1px solid var(--bw-theme-border);
  border-radius: 999px;
  background: color-mix(in srgb, var(--bw-theme-surface) 72%, transparent);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 26px;
  padding-left: 8px;
  padding-right: 8px;
}

.tenant-dropdown-btn {
  font-weight: 600;
  font-size: 0.78rem;
  min-height: 26px;
}

@media (max-width: 600px) {
  .app-context__title {
    max-width: 100px;
  }
  .app-layout__tenant-chip {
    max-width: 90px !important;
  }
  .tenant-dropdown-btn {
    width: 100%;
  }
}
</style>
