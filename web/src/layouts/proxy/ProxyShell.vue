<template>
  <q-layout view="hHh lpR fFf" class="shop-shell theme-shop">
    <q-header class="shop-shell__header">
      <q-toolbar class="shop-shell__toolbar">
        <div class="shop-shell__left">
          <button
            type="button"
            class="shop-shell__tenant-link"
            data-test="proxy-header-tenant-link"
            @click="goHome"
          >
            <span class="shop-shell__tenant-text shop-banner-font">{{ tenantName }}</span>
          </button>

          <template v-if="groupName">
            <span class="shop-shell__context-divider" aria-hidden="true" />
            <div class="proxy-shell__group">
              <div class="proxy-shell__group-name">{{ groupName }}</div>
              <div class="proxy-shell__group-caption">Proxy portal</div>
            </div>
          </template>
        </div>

        <div class="shop-shell__actions">
          <UserProfileMenu @sign-out="openSignOutDialog" />
        </div>
      </q-toolbar>
    </q-header>

    <q-page-container
      class="shop-shell__page-container"
      :class="$q.screen.xs ? 'q-pa-xs' : 'q-pa-md'"
    >
      <slot />
    </q-page-container>

    <q-dialog v-model="showLogoutDialog" persistent class="shop-shell__signout-dialog">
      <div class="shop-shell__signout-card">
        <div class="shop-shell__signout-identity">
          <div class="shop-shell__signout-avatar">
            <img v-if="userAvatarUrl" :src="userAvatarUrl" referrerpolicy="no-referrer" alt="" />
            <span v-else>{{ userInitials }}</span>
          </div>
          <div>
            <div class="shop-shell__signout-name">{{ userName }}</div>
            <div class="shop-shell__signout-email">{{ userEmail }}</div>
          </div>
        </div>

        <p class="shop-shell__signout-message">
          You’ll be signed out of the proxy portal. Your data stays safe.
        </p>

        <div class="shop-shell__signout-actions">
          <button
            class="shop-shell__signout-btn shop-shell__signout-btn--cancel"
            @click="showLogoutDialog = false"
          >
            Stay signed in
          </button>
          <button
            class="shop-shell__signout-btn shop-shell__signout-btn--confirm"
            @click="confirmLogout"
          >
            <q-icon name="ph ph-sign-out" size="1rem" />
            Sign out
          </button>
        </div>
      </div>
    </q-dialog>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import UserProfileMenu from 'src/components/navigation/UserProfileMenu.vue';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { getProxyDashboardRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';

const WORKSPACE_THEME_CLASSES = [
  'theme-platform',
  'theme-app',
  'theme-shop',
  'theme-investor',
  'theme-proxy',
];

const props = defineProps<{
  logoutTo: string;
}>();

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const showLogoutDialog = ref(false);

const tenantName = computed(() => authStore.tenant?.name ?? 'Proxy');
const groupName = computed(() => authStore.customerGroup?.name ?? '');
const userName = computed(
  () => authStore.user?.fullName ?? authStore.member?.name ?? authStore.user?.email ?? 'User',
);
const userEmail = computed(() => authStore.user?.email ?? '');
const userAvatarUrl = computed(() => authStore.user?.avatarUrl ?? null);
const userInitials = computed(() => {
  const source = userName.value.trim();
  if (!source) return 'U';
  const parts = source.split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return `${parts[0]?.[0] ?? ''}${parts[1]?.[0] ?? ''}`.toUpperCase();
  }
  return source.slice(0, 2).toUpperCase();
});

const goHome = () => {
  void router.push(getProxyDashboardRouteLocation(route, authStore.tenantSlug));
};

const openSignOutDialog = () => {
  showLogoutDialog.value = true;
};

const confirmLogout = async () => {
  showLogoutDialog.value = false;

  try {
    await supabase.auth.signOut();
  } catch (error) {
    console.error('[auth] Failed to sign out from Supabase session', error);
  } finally {
    authStore.clearAccess();

    try {
      await router.replace(props.logoutTo);
    } catch (error) {
      console.error('[auth] Failed to redirect after sign out', error);
    }
  }
};

onMounted(() => {
  WORKSPACE_THEME_CLASSES.forEach((themeClass) => {
    if (themeClass !== 'theme-shop') {
      document.body.classList.remove(themeClass);
    }
  });
  document.body.classList.add('theme-shop');
});

onBeforeUnmount(() => {
  document.body.classList.remove('theme-shop');
});

defineExpose({
  openSignOutDialog,
});
</script>

<style scoped>
.proxy-shell__group {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.05rem;
}

.proxy-shell__group-name {
  font-size: 0.8125rem;
  font-weight: 650;
  color: var(--tf-theme-ink, #2a2b2a);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 11rem;
}

.proxy-shell__group-caption {
  font-size: 0.6875rem;
  color: var(--tf-theme-muted, #736a61);
}
</style>

<!-- Mirror shop-shell chrome (ShopShell styles are scoped and do not apply here). -->
<style>
.shop-shell {
  min-height: 100vh;
  --shop-shell-base: var(--tf-theme-base, #ffffff);
  --shop-shell-surface: var(--tf-theme-surface, #ffffff);
  --shop-shell-border: var(--tf-theme-border, #ebe7e2);
  --shop-shell-ink: var(--tf-theme-ink, #2a2b2a);
  --shop-shell-muted: var(--tf-theme-muted, #5e4955);
  --shop-shell-accent: var(--tf-theme-primary, #2a2b2a);
  --shop-shell-accent-soft: var(--tf-theme-primary-soft, rgb(153 104 136 / 0.16));
  background: var(--shop-shell-base);
  color: var(--shop-shell-ink);
}

.shop-shell__header {
  background: color-mix(in srgb, var(--shop-shell-surface) 90%, white 10%);
  border-bottom: 1px solid var(--shop-shell-border);
}

.shop-shell__toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.45rem 0.9rem;
  min-height: 54px;
}

.shop-shell__left {
  min-width: 0;
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 0.55rem;
}

.shop-shell__context-divider {
  width: 1px;
  height: 18px;
  background: var(--tf-neutral-border-strong, #ddd);
  flex-shrink: 0;
}

.shop-shell__tenant-link {
  display: inline-flex;
  align-items: center;
  margin: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
  padding: 0.15rem 0.15rem 0.15rem 0;
  flex: 0 1 auto;
  min-width: 0;
  max-width: 9rem;
  color: var(--tf-neutral-ink, #2a2b2a);
}

.shop-shell__tenant-text {
  min-width: 0;
  font-size: clamp(0.95rem, 2.8vw, 1.125rem);
  line-height: 1.1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.shop-shell__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.4rem;
  flex-shrink: 0;
}

.shop-shell__page-container {
  background: var(--shop-shell-base);
}

.shop-shell__signout-dialog .q-dialog__inner {
  padding: 16px;
}

.shop-shell__signout-dialog .q-dialog__backdrop {
  background: rgb(0 0 0 / 0.45);
}

.shop-shell__signout-card {
  width: min(92vw, 26rem);
  border-radius: 1.25rem;
  padding: 1.5rem;
  background: #ffffff;
  border: 1px solid #ebe7e2;
  box-shadow: 0 20px 60px rgb(0 0 0 / 0.18);
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.shop-shell__signout-identity {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.shop-shell__signout-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  background: #f1e9ee;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.8rem;
  font-weight: 700;
  color: #2a2b2a;
}

.shop-shell__signout-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.shop-shell__signout-name {
  font-size: 0.95rem;
  font-weight: 700;
  color: #2a2b2a;
}

.shop-shell__signout-email {
  font-size: 0.78rem;
  color: #5e4955;
}

.shop-shell__signout-message {
  margin: 0;
  font-size: 0.85rem;
  color: #5e4955;
  line-height: 1.5;
}

.shop-shell__signout-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
}

.shop-shell__signout-btn {
  padding: 0.55rem 0;
  border-radius: 8px;
  border: none;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
}

.shop-shell__signout-btn--cancel {
  background: #f3f1f2;
  color: #2a2b2a;
  border: 1px solid #e4e0e2;
}

.shop-shell__signout-btn--confirm {
  background: #2a2b2a;
  color: #ffffff;
}

@media (max-width: 599px) {
  .shop-shell__toolbar {
    min-height: 56px;
    padding: calc(0.35rem + env(safe-area-inset-top, 0px)) 0.7rem 0.4rem;
  }

  .shop-shell__tenant-link {
    max-width: min(34vw, 8rem);
  }
}
</style>
