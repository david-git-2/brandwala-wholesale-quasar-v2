<template>
  <div class="user-profile-menu row items-center no-wrap">
    <q-btn flat dense no-caps class="user-profile-btn q-px-xs rounded-borders" aria-label="User profile">
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

        <q-icon name="ph ph-caret-down" size="12px" class="text-grey-6" />
      </div>

      <!-- Profile Dropdown Menu -->
      <q-menu anchor="bottom end" self="top end" class="user-profile-dropdown" style="min-width: 250px">
        <div class="q-pa-md bg-grey-1 border-bottom">
          <div class="row items-center no-wrap q-gutter-x-sm">
            <q-avatar size="36px" class="user-profile-btn__avatar">
              <img
                v-if="userAvatarUrl"
                :src="userAvatarUrl"
                referrerpolicy="no-referrer"
                alt="Profile avatar"
              />
              <span v-else class="user-profile-btn__initials">{{ userInitials }}</span>
            </q-avatar>

            <div class="col min-width-0">
              <div class="text-subtitle2 text-weight-bold text-grey-9 ellipsis">{{ userName }}</div>
              <div class="text-caption text-grey-6 ellipsis">{{ userEmail }}</div>
            </div>
          </div>

          <div v-if="currentRoleLabel" class="q-mt-sm">
            <q-badge color="primary" class="text-uppercase text-bold" style="font-size: 9px; padding: 2px 6px">
              {{ currentRoleLabel }}
            </q-badge>
          </div>
        </div>

        <q-list dense class="q-py-xs">
          <!-- Workspace Info -->
          <template v-if="contextValue">
            <q-item-label header class="text-uppercase text-weight-bold text-grey-7 dropdown-header">
              Workspace
            </q-item-label>
            <q-item>
              <q-item-section avatar class="q-pr-none" style="min-width: 28px">
                <q-icon name="ph ph-buildings" size="xs" color="grey-6" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-caption text-weight-medium">{{ contextValue }}</q-item-label>
              </q-item-section>
            </q-item>
            <q-separator class="q-my-xs" />
          </template>

          <!-- Appearance -->
          <q-item-label header class="text-uppercase text-weight-bold text-grey-7 dropdown-header">
            Appearance
          </q-item-label>

          <q-item clickable @click="toggleDarkMode">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon :name="darkMode ? 'ph ph-moon' : 'ph ph-sun'" size="xs" color="grey-7" />
            </q-item-section>
            <q-item-section>Dark Mode</q-item-section>
            <q-item-section side>
              <q-toggle :model-value="darkMode" dense @update:model-value="toggleDarkMode" />
            </q-item-section>
          </q-item>

          <q-item clickable @click="toggleDensity">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-rows" size="xs" color="grey-7" />
            </q-item-section>
            <q-item-section>Compact Rows</q-item-section>
            <q-item-section side>
              <q-toggle :model-value="density === 'compact'" dense @update:model-value="toggleDensity" />
            </q-item-section>
          </q-item>

          <!-- Language -->
          <q-separator class="q-my-xs" />
          <q-item-label header class="text-uppercase text-weight-bold text-grey-7 dropdown-header">
            Language
          </q-item-label>

          <q-item clickable :active="locale === 'en-US'" active-class="bg-blue-1 text-primary text-weight-bold" @click="setLocale('en-US')">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-translate" size="xs" :color="locale === 'en-US' ? 'primary' : 'grey-6'" />
            </q-item-section>
            <q-item-section>English</q-item-section>
            <q-item-section side v-if="locale === 'en-US'">
              <q-icon name="ph ph-check" size="xs" color="primary" />
            </q-item-section>
          </q-item>

          <q-item clickable :active="locale === 'bn'" active-class="bg-blue-1 text-primary text-weight-bold" @click="setLocale('bn')">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-translate" size="xs" :color="locale === 'bn' ? 'primary' : 'grey-6'" />
            </q-item-section>
            <q-item-section class="locale-bn">বাংলা</q-item-section>
            <q-item-section side v-if="locale === 'bn'">
              <q-icon name="ph ph-check" size="xs" color="primary" />
            </q-item-section>
          </q-item>

          <!-- Resources & Documentation -->
          <q-separator class="q-my-xs" />
          <q-item clickable v-close-popup :to="{ name: 'help-center-page' }">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-book-open" size="xs" color="grey-7" />
            </q-item-section>
            <q-item-section>Help & Guides</q-item-section>
          </q-item>

          <!-- Sign Out -->
          <q-separator class="q-my-xs" />
          <q-item clickable v-close-popup class="text-negative" @click="onSignOut">
            <q-item-section avatar class="q-pr-none" style="min-width: 28px">
              <q-icon name="ph ph-sign-out" size="xs" color="negative" />
            </q-item-section>
            <q-item-section class="text-weight-medium">Sign Out</q-item-section>
          </q-item>
        </q-list>
      </q-menu>
    </q-btn>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useAppearance } from 'src/composables/useAppearance';

const emit = defineEmits<{
  (e: 'sign-out'): void;
}>();

const authStore = useAuthStore();
const { locale } = useI18n();
const { darkMode, setDarkMode, density, setDensity } = useAppearance();

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

const contextValue = computed(() => authStore.selectedTenant?.name ?? authStore.tenant?.name ?? null);

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
};

const onSignOut = () => {
  emit('sign-out');
};
</script>

<style scoped>
.user-profile-btn {
  border: 1px solid transparent;
  transition: all 0.15s ease-in-out;
}

.user-profile-btn:hover {
  background: color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 40%, transparent);
}

.user-profile-btn__avatar {
  background: color-mix(in srgb, var(--q-primary, #2563eb) 12%, #e2e8f0 88%);
  color: var(--q-primary, #2563eb);
  font-weight: 700;
  font-size: 11px;
}

.user-profile-dropdown {
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12);
}

.dropdown-header {
  font-size: 9px;
  letter-spacing: 0.1em;
  padding: 4px 16px;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}

.locale-bn {
  font-weight: 600;
}

body.body--dark .border-bottom {
  border-color: #334155;
}

body.body--dark .bg-grey-1 {
  background: #1e293b !important;
}

body.body--dark .bg-blue-1 {
  background: #1e3a8a !important;
}
</style>
