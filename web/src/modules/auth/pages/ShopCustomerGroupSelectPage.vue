<template>
  <section class="auth-card auth-card--shop">
    <div class="auth-card__accent-bar" aria-hidden="true" />

    <div class="auth-card__header">
      <h2 class="auth-card__title">{{ $t('shop.select_company') }}</h2>
      <p class="auth-card__subtitle">{{ $t('shop.select_company_desc') }}</p>
    </div>

    <div v-if="errorMessage" class="auth-card__error" role="alert">
      <q-icon name="ph ph-warning-circle" size="1.1rem" />
      <span>{{ errorMessage }}</span>
    </div>

    <PageInitialLoader v-if="loading" />

    <div v-else class="company-list" role="list">
      <button
        v-for="group in groups"
        :key="group.member_id"
        type="button"
        class="company-card"
        role="listitem"
        :disabled="savingMemberId !== null"
        :data-test="`shop-select-company-${group.customer_group_id}`"
        @click="selectGroup(group)"
      >
        <span
          class="company-card__accent"
          :style="{ background: groupAccent(group.customer_group_id) }"
          aria-hidden="true"
        />
        <span class="company-card__body">
          <span class="company-card__name">{{ group.customer_group_name }}</span>
          <span class="company-card__role">{{ roleLabel(group.matched_role) }}</span>
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
import { useI18n } from 'vue-i18n';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useAuthStore } from '../stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { clearShopOrderQueryCache } from 'src/query/queryClient';
import {
  bootstrapShopCustomerGroup,
  listShopLoginGroups,
  type ShopLoginGroupRow,
} from '../utils/shopCustomerGroupSession';
import { getShopDashboardRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';
import { showErrorNotification } from 'src/utils/appFeedback';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

const panelTitle = inject<Ref<string>>('authPanelTitle');
if (panelTitle) {
  panelTitle.value = t('shop.select_company');
}

const loading = ref(true);
const errorMessage = ref('');
const groups = ref<ShopLoginGroupRow[]>([]);
const savingMemberId = ref<number | null>(null);

const roleLabel = (role: string) => {
  if (role === 'admin') return t('shop.company_role_admin');
  if (role === 'manager') return t('shop.company_role_manager');
  if (role === 'staff') return t('shop.company_role_staff');
  return role;
};

const groupAccent = (groupId: number) => {
  const hue = (groupId * 47) % 360;
  return `hsl(${hue} 42% 52%)`;
};

const loadGroups = async () => {
  const email = authStore.user?.email;
  const tenantId = authStore.tenantId;
  if (!email || tenantId == null) {
    errorMessage.value = t('shop.select_company_error');
    loading.value = false;
    return;
  }

  try {
    groups.value = await listShopLoginGroups(email, tenantId);
    if (groups.value.length === 0) {
      errorMessage.value = t('shop.select_company_empty');
    }
  } catch (error) {
    console.error('[shop] Failed to list companies', error);
    errorMessage.value = t('shop.select_company_error');
  } finally {
    loading.value = false;
  }
};

const selectGroup = async (group: ShopLoginGroupRow) => {
  const user = authStore.user;
  const email = user?.email;
  const tenantId = authStore.tenantId;
  if (!user || !email || tenantId == null) {
    return;
  }

  savingMemberId.value = group.member_id;
  try {
    const snapshot = await bootstrapShopCustomerGroup({
      user,
      email,
      tenantId,
      memberId: group.member_id,
      createdAt: group.member_created_at,
      updatedAt: group.member_updated_at,
    });
    if (!snapshot) {
      showErrorNotification(t('shop.select_company_error'));
      return;
    }

    authStore.saveAccess({
      ...snapshot,
      savedAt: new Date().toISOString(),
    });
    tenantStore.hydrateSelectedTenantFromAuth(snapshot.tenant);
    clearShopOrderQueryCache();

    const redirectPath =
      typeof route.query.redirect === 'string' ? route.query.redirect.trim() : '';
    if (
      redirectPath &&
      !redirectPath.includes('/login') &&
      !redirectPath.includes('/select-company') &&
      !redirectPath.includes('/auth/callback')
    ) {
      await router.replace(redirectPath);
      return;
    }

    await router.replace(getShopDashboardRouteLocation(route, snapshot.tenant?.slug));
  } catch (error) {
    console.error('[shop] Failed to select company', error);
    showErrorNotification(t('shop.select_company_error'));
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
  background: var(--bw-theme-primary, #2a2b2a);
}

.auth-card__header {
  padding: 1.35rem 1.5rem 0;
}

.auth-card__title {
  margin: 0;
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--bw-theme-ink, #1c1416);
}

.auth-card__subtitle {
  margin: 0.35rem 0 0;
  color: var(--bw-theme-muted, #6b6560);
  font-size: 0.9rem;
  line-height: 1.4;
}

.auth-card__error {
  margin: 0 1.5rem;
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
  padding: 0 1.25rem;
}

.company-card {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  text-align: left;
  border-radius: 8px;
  border: 1px solid var(--bw-theme-border, #ebe7e2);
  background: var(--bw-theme-surface, #fff);
  padding: 0.7rem 0.85rem;
  cursor: pointer;
}

.company-card:hover:not(:disabled) {
  border-color: color-mix(in srgb, var(--bw-theme-primary, #2a2b2a) 35%, #ebe7e2);
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
  color: var(--bw-theme-ink, #1c1416);
}

.company-card__role {
  font-size: 0.75rem;
  color: var(--bw-theme-muted, #6b6560);
}

.company-card__chevron {
  color: var(--bw-theme-muted, #6b6560);
}
</style>
