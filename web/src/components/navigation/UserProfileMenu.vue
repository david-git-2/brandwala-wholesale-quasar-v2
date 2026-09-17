<template>
  <div class="user-profile-menu row items-center no-wrap">
    <q-btn flat dense no-caps class="user-profile-btn" aria-label="User profile">
      <div class="row items-center no-wrap q-gutter-x-xs">
        <q-avatar size="28px" class="user-profile-btn__avatar">
          <img
            v-if="userAvatarUrl"
            :src="userAvatarUrl"
            referrerpolicy="no-referrer"
            alt="Profile avatar"
          />
          <span v-else class="user-profile-btn__initials">{{ userInitials }}</span>
        </q-avatar>

        <q-icon name="ph ph-caret-down" size="12px" class="user-profile-btn__caret" />
      </div>

      <!-- Profile Dropdown Menu -->
      <q-menu anchor="bottom end" self="top end" class="user-profile-dropdown" style="min-width: 250px">
        <div class="user-profile-dropdown__header q-pa-md">
          <div class="row items-center no-wrap q-gutter-x-sm">
            <q-avatar size="34px" class="user-profile-btn__avatar">
              <img
                v-if="userAvatarUrl"
                :src="userAvatarUrl"
                referrerpolicy="no-referrer"
                alt="Profile avatar"
              />
              <span v-else class="user-profile-btn__initials">{{ userInitials }}</span>
            </q-avatar>

            <div class="col min-width-0">
              <div class="user-profile-dropdown__name ellipsis">{{ userName }}</div>
              <div class="user-profile-dropdown__email ellipsis">{{ userEmail }}</div>
            </div>
          </div>

          <div v-if="currentRoleLabel" class="q-mt-sm">
            <span class="user-profile-dropdown__badge">
              {{ currentRoleLabel }}
            </span>
          </div>
        </div>

        <q-list dense class="q-py-xs user-profile-dropdown__list">
          <!-- Workspace Info -->
          <template v-if="contextValue">
            <q-item-label header class="dropdown-header">
              Workspace
            </q-item-label>
            <q-item class="dropdown-item">
              <q-item-section avatar class="q-pr-none" style="min-width: 28px">
                <q-icon name="ph ph-buildings" size="xs" class="dropdown-item__icon" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-caption text-weight-medium">{{ contextValue }}</q-item-label>
              </q-item-section>
            </q-item>
            <q-item
              v-if="isShopScope && canSwitchCompany"
              clickable
              v-close-popup
              class="dropdown-item"
              data-test="shop-profile-switch-company"
              @click="goSwitchCompany"
            >
              <q-item-section avatar class="q-pr-none" style="min-width: 28px">
                <q-icon name="ph ph-arrows-left-right" size="xs" class="dropdown-item__icon" />
              </q-item-section>
              <q-item-section>{{ $t('shop.switch_company') }}</q-item-section>
            </q-item>
            <q-separator class="q-my-xs dropdown-sep" />
          </template>

          <!-- Appearance -->
          <q-item-label header class="dropdown-header">
            Appearance
          </q-item-label>

          <q-item clickable class="dropdown-item" @click="toggleDarkMode">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon :name="darkMode ? 'ph ph-moon' : 'ph ph-sun'" size="xs" class="dropdown-item__icon" />
            </q-item-section>
            <q-item-section>Dark Mode</q-item-section>
            <q-item-section side>
              <q-toggle :model-value="darkMode" dense color="primary" @update:model-value="toggleDarkMode" />
            </q-item-section>
          </q-item>

          <q-item v-if="!isShopScope" clickable class="dropdown-item" @click="toggleDensity">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-rows" size="xs" class="dropdown-item__icon" />
            </q-item-section>
            <q-item-section>Compact Rows</q-item-section>
            <q-item-section side>
              <q-toggle :model-value="density === 'compact'" dense color="primary" @update:model-value="toggleDensity" />
            </q-item-section>
          </q-item>

          <!-- Language -->
          <q-separator class="q-my-xs dropdown-sep" />
          <q-item-label header class="dropdown-header">
            Language
          </q-item-label>

          <q-item
            clickable
            class="dropdown-item"
            :active="locale === 'en-US'"
            active-class="dropdown-item--active"
            @click="setLocale('en-US')"
          >
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-translate" size="xs" :class="locale === 'en-US' ? 'text-primary' : 'dropdown-item__icon'" />
            </q-item-section>
            <q-item-section>English</q-item-section>
            <q-item-section side v-if="locale === 'en-US'">
              <q-icon name="ph ph-check" size="xs" color="primary" />
            </q-item-section>
          </q-item>

          <q-item
            clickable
            class="dropdown-item"
            :active="locale === 'bn'"
            active-class="dropdown-item--active"
            @click="setLocale('bn')"
          >
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-translate" size="xs" :class="locale === 'bn' ? 'text-primary' : 'dropdown-item__icon'" />
            </q-item-section>
            <q-item-section class="locale-bn">বাংলা</q-item-section>
            <q-item-section side v-if="locale === 'bn'">
              <q-icon name="ph ph-check" size="xs" color="primary" />
            </q-item-section>
          </q-item>

          <!-- Notifications (app scope) -->
          <template v-if="authStore.scope === 'app'">
            <q-separator class="q-my-xs dropdown-sep" />
            <q-item clickable v-close-popup class="dropdown-item" data-test="profile-notifications-settings" @click="goNotificationPreferences">
              <q-item-section avatar class="q-pr-none" style="min-width: 28px">
                <q-icon name="ph ph-bell" size="xs" class="dropdown-item__icon" />
              </q-item-section>
              <q-item-section>Browser alerts</q-item-section>
            </q-item>
          </template>

          <!-- About System -->
          <template v-if="!isShopScope">
            <q-separator class="q-my-xs dropdown-sep" />
            <q-item clickable v-close-popup class="dropdown-item" @click="showAboutDialog = true">
              <q-item-section avatar class="q-pr-none" style="min-width: 28px">
                <q-icon name="ph ph-info" size="xs" color="primary" />
              </q-item-section>
              <q-item-section>About System</q-item-section>
            </q-item>
          </template>

          <!-- Sign Out -->
          <q-separator class="q-my-xs dropdown-sep" />
          <q-item clickable v-close-popup class="dropdown-item text-negative" @click="onSignOut">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-sign-out" size="xs" color="negative" />
            </q-item-section>
            <q-item-section class="text-weight-medium">Sign Out</q-item-section>
          </q-item>
        </q-list>
      </q-menu>
    </q-btn>

    <!-- About System Dialog -->
    <AboutSystemDialog v-if="!isShopScope" v-model="showAboutDialog" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useAppearance } from 'src/composables/useAppearance';
import AboutSystemDialog from 'src/components/navigation/AboutSystemDialog.vue';
import { listShopLoginGroups } from 'src/modules/auth/utils/shopCustomerGroupSession';
import { getShopSelectCompanyRouteLocation, getAppRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';

const showAboutDialog = ref(false);
const companyCount = ref(0);

const emit = defineEmits<{
  (e: 'sign-out'): void;
}>();

const authStore = useAuthStore();
const router = useRouter();
const { locale } = useI18n();
const { darkMode, setDarkMode, density, setDensity } = useAppearance();

const isShopScope = computed(() => authStore.scope === 'shop');
const canSwitchCompany = computed(() => isShopScope.value && companyCount.value > 1);

const userName = computed(() => {
  return authStore.user?.fullName || authStore.user?.email?.split('@')[0] || 'User';
});

const userEmail = computed(() => authStore.user?.email ?? '');
const userAvatarUrl = computed(() => {
  return authStore.user?.avatarUrl ?? null;
});

const userInitials = computed(() => {
  const name = userName.value.trim();
  if (!name) return 'U';
  const parts = name.split(/\s+/).filter(Boolean);
  if (parts.length >= 2 && parts[0] && parts[1]) {
    return `${parts[0].charAt(0)}${parts[1].charAt(0)}`.toUpperCase();
  }
  return name.slice(0, 2).toUpperCase();
});

const currentRoleLabel = computed(() => {
  const role = authStore.matchedRole;
  if (!role) return '';
  return role.charAt(0).toUpperCase() + role.slice(1);
});

const contextValue = computed(() => {
  if (authStore.scope === 'shop') {
    return authStore.customerGroup?.name ?? authStore.tenant?.name ?? null;
  }
  return authStore.selectedTenant?.name ?? authStore.tenant?.name ?? null;
});

const toggleDarkMode = () => {
  void setDarkMode(!darkMode.value, authStore.membershipId);
};

const toggleDensity = () => {
  const nextDensity = density.value === 'compact' ? 'comfortable' : 'compact';
  void setDensity(nextDensity, authStore.membershipId);
};

const setLocale = (newLocale: string) => {
  locale.value = newLocale;
  localStorage.setItem('bw_locale', newLocale);
  localStorage.setItem('locale', newLocale);
  document.documentElement.lang = newLocale === 'bn' ? 'bn' : 'en';
};

const onSignOut = () => {
  emit('sign-out');
};

const goSwitchCompany = () => {
  void router.push(getShopSelectCompanyRouteLocation(router.currentRoute.value));
};

const goNotificationPreferences = () => {
  void router.push(
    getAppRouteLocation(
      { name: 'notifications-preferences', params: {}, query: {} },
      authStore.tenantSlug,
    ),
  );
};

onMounted(async () => {
  if (!isShopScope.value || !authStore.user?.email || authStore.tenantId == null) {
    return;
  }
  try {
    const groups = await listShopLoginGroups(authStore.user.email, authStore.tenantId);
    companyCount.value = groups.length;
  } catch {
    companyCount.value = 0;
  }
});
</script>

<style scoped>
.user-profile-btn {
  border-radius: 8px;
  padding: 3px 6px;
  border: 1px solid transparent;
  transition: all 0.15s ease-in-out;
}

.user-profile-btn:hover {
  background: color-mix(in srgb, var(--bw-neutral-ink) 5%, transparent);
}

.user-profile-btn__avatar {
  background: var(--bw-theme-primary-soft);
  color: var(--bw-brand-accent);
  font-weight: 700;
  font-size: 11px;
  border: 1px solid color-mix(in srgb, var(--bw-brand-accent) 20%, transparent);
}

.user-profile-btn__caret {
  color: var(--bw-neutral-chrome);
  margin-left: 2px;
}

.user-profile-dropdown {
  border-radius: 12px;
  overflow: hidden;
  background: var(--bw-neutral-surface);
  border: 1px solid var(--bw-neutral-border);
  box-shadow: 0 12px 32px -4px rgba(0, 0, 0, 0.18);
}

.user-profile-dropdown__header {
  background: var(--bw-neutral-canvas);
  border-bottom: 1px solid var(--bw-neutral-border);
}

.user-profile-dropdown__name {
  font-size: 13px;
  font-weight: 600;
  color: var(--bw-neutral-ink);
  line-height: 1.3;
}

.user-profile-dropdown__email {
  font-size: 11.5px;
  color: var(--bw-neutral-muted);
  line-height: 1.3;
}

.user-profile-dropdown__badge {
  display: inline-flex;
  align-items: center;
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  padding: 1.5px 7px;
  border-radius: 999px;
  background: var(--bw-theme-primary-soft);
  color: var(--bw-brand-accent);
  border: 1px solid color-mix(in srgb, var(--bw-brand-accent) 22%, transparent);
}

.dropdown-header {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bw-neutral-chrome);
  padding: 8px 14px 2px;
}

.dropdown-item {
  min-height: 34px;
  padding: 4px 12px;
  border-radius: 6px;
  margin: 1px 6px;
  font-size: 13px;
  color: var(--bw-neutral-ink);
  transition: background-color 0.15s ease;
}

.dropdown-item:hover {
  background: color-mix(in srgb, var(--bw-neutral-ink) 4%, transparent);
}

.dropdown-item__icon {
  color: var(--bw-neutral-chrome);
}

.dropdown-item--active {
  background: var(--bw-theme-primary-soft) !important;
  color: var(--bw-brand-accent) !important;
  font-weight: 600;
}

.dropdown-sep {
  background: var(--bw-neutral-border);
  opacity: 0.7;
}
</style>
