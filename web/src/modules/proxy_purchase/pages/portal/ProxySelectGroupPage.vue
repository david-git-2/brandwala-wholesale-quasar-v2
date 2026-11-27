<template>
  <section class="auth-card">
    <div class="auth-card__accent-bar" aria-hidden="true" />

    <div class="auth-card__header">
      <h2 class="auth-card__title">Choose your group</h2>
      <p class="auth-card__subtitle">Select the customer or supplier group you want to open.</p>
    </div>

    <div v-if="errorMessage" class="auth-card__error" role="alert">
      <q-icon name="ph ph-warning-circle" size="1.1rem" />
      <span>{{ errorMessage }}</span>
    </div>

    <PageInitialLoader v-else-if="loading" embedded />

    <div v-else class="company-list" role="list">
      <button
        v-for="group in groups"
        :key="group.member_id"
        type="button"
        class="company-card"
        role="listitem"
        :disabled="savingMemberId !== null"
        @click="selectGroup(group)"
      >
        <span class="company-card__accent" aria-hidden="true" />
        <span class="company-card__body">
          <span class="company-card__name">{{ group.people_group_name }}</span>
          <span class="company-card__role">{{ roleLabel(group) }}</span>
        </span>
        <q-spinner v-if="savingMemberId === group.member_id" size="18px" color="primary" />
        <q-icon v-else name="ph ph-caret-right" size="16px" class="company-card__chevron" />
      </button>
    </div>
  </section>
</template>

<script setup lang="ts">
import { inject, onMounted, ref, type Ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import {
  bootstrapProxyPeopleGroup,
  listProxyLoginGroups,
  type ProxyLoginGroupRow,
} from 'src/modules/workspace/submodules/auth/utils/proxyPeopleGroupSession';
import {
  getProxyDashboardRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';
import { showErrorNotification } from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

const panelTitle = inject<Ref<string>>('authPanelTitle');
if (panelTitle) {
  panelTitle.value = 'Choose your group';
}

const loading = ref(true);
const errorMessage = ref('');
const groups = ref<ProxyLoginGroupRow[]>([]);
const savingMemberId = ref<number | null>(null);

const roleLabel = (group: ProxyLoginGroupRow) => {
  const type = group.people_group_type === 'supplier' ? 'Supplier' : 'Customer';
  const role = group.matched_role === 'admin' ? 'Admin' : 'Staff';
  return `${type} · ${role}`;
};

const loadGroups = async () => {
  const email = authStore.user?.email;
  const tenantId = authStore.tenantId;
  if (!email || tenantId == null) {
    errorMessage.value = 'Sign in again to continue.';
    loading.value = false;
    return;
  }

  try {
    groups.value = await listProxyLoginGroups(email, tenantId);
    if (groups.value.length === 0) {
      errorMessage.value = 'No proxy groups are linked to this account.';
    }
  } catch (error) {
    console.error('[proxy] Failed to list groups', error);
    errorMessage.value = 'Could not load your groups.';
  } finally {
    loading.value = false;
  }
};

const selectGroup = async (group: ProxyLoginGroupRow) => {
  const email = authStore.user?.email;
  const tenantId = authStore.tenantId;
  if (!email || tenantId == null || !authStore.user) {
    return;
  }

  savingMemberId.value = group.member_id;

  try {
    const snapshot = await bootstrapProxyPeopleGroup({
      user: authStore.user,
      email,
      tenantId,
      memberId: group.member_id,
      createdAt: group.member_created_at,
      updatedAt: group.member_updated_at,
    });

    if (!snapshot) {
      showErrorNotification('Could not open that group.');
      return;
    }

    authStore.saveAccess({
      ...snapshot,
      savedAt: new Date().toISOString(),
    });
    tenantStore.hydrateSelectedTenantFromAuth(snapshot.tenant);

    const redirectPath =
      typeof route.query.redirect === 'string' ? route.query.redirect.trim() : '';
    if (redirectPath) {
      await router.replace(redirectPath);
      return;
    }

    await router.replace(
      getProxyDashboardRouteLocation(route, getTenantSlugFromRoute(route) ?? snapshot.tenant?.slug),
    );
  } catch (error) {
    console.error('[proxy] Bootstrap failed', error);
    showErrorNotification('Could not open that group.');
  } finally {
    savingMemberId.value = null;
  }
};

onMounted(() => {
  void loadGroups();
});
</script>

<style scoped>
.auth-card {
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid color-mix(in srgb, #6b6560 22%, #ffffff);
  box-shadow:
    0 2px 4px rgb(0 0 0 / 0.04),
    0 8px 24px rgb(0 0 0 / 0.06);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
  padding: 0 0 1.5rem;
}

.auth-card__accent-bar {
  height: 4px;
  background: var(--tf-theme-primary, #2a2b2a);
}

.auth-card__header {
  padding: 1.35rem clamp(1rem, 4vw, 1.5rem) 0;
}

.auth-card__title {
  margin: 0;
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--tf-theme-ink, #1c1416);
}

.auth-card__subtitle {
  margin: 0.35rem 0 0;
  color: var(--tf-theme-muted, #6b6560);
  font-size: 0.9rem;
  line-height: 1.4;
}

.auth-card__error {
  margin: 0 clamp(1rem, 4vw, 1.5rem);
  display: flex;
  gap: 0.4rem;
  align-items: flex-start;
  color: #9b2c2c;
  font-size: 0.85rem;
}

.company-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 0 clamp(0.85rem, 3.5vw, 1.25rem);
}

.company-card {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  text-align: left;
  border-radius: 8px;
  border: 1px solid var(--tf-theme-border, #ebe7e2);
  background: var(--tf-theme-surface, #fff);
  padding: 0.7rem 0.85rem;
  cursor: pointer;
}

.company-card:hover:not(:disabled) {
  border-color: color-mix(in srgb, var(--tf-theme-primary, #2a2b2a) 35%, #ebe7e2);
}

.company-card:disabled {
  opacity: 0.7;
  cursor: wait;
}

.company-card__accent {
  width: 8px;
  align-self: stretch;
  border-radius: 8px;
  flex-shrink: 0;
  background: var(--tf-theme-primary-soft, #ddd);
}

.company-card__body {
  min-width: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.company-card__name {
  font-weight: 650;
  color: var(--tf-theme-ink, #1c1416);
}

.company-card__role {
  font-size: 0.75rem;
  color: var(--tf-theme-muted, #6b6560);
}

.company-card__chevron {
  color: var(--tf-theme-muted, #6b6560);
}
</style>