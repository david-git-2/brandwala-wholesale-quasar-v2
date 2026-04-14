<template>
  <q-layout view="hHh Lpr lFf" class="workspace-shell" :class="themeClasses">
    <q-header class="workspace-shell__header">
      <q-toolbar class="workspace-shell__toolbar">
        <q-btn
          flat
          round
          dense
          icon="menu"
          class="workspace-shell__menu"
          @click="drawerOpen = !drawerOpen"
        />

        <div class="workspace-shell__context">
          <slot name="header-left" />
        </div>

        <q-space />

        <div class="workspace-shell__actions">
          <slot name="header-extra" />
        </div>
      </q-toolbar>
    </q-header>

    <q-drawer
      v-model="drawerOpen"
      show-if-above
      bordered
      :width="300"
      class="workspace-shell__drawer"
    >
      <div class="workspace-shell__drawer-inner">
        <div class="workspace-shell__drawer-top">
          <div class="workspace-shell__summary">
            <div class="workspace-shell__profile-row">
              <q-avatar size="42px" class="workspace-shell__avatar">
                <img
                  v-if="userAvatarUrl"
                  :src="userAvatarUrl"
                  class="workspace-shell__avatar-image"
                  referrerpolicy="no-referrer"
                  alt=""
                >
                <span v-else class="workspace-shell__avatar-fallback">{{ userInitials }}</span>
              </q-avatar>
            </div>
            <div class="workspace-shell__summary-label">Signed in as</div>
            <div class="workspace-shell__summary-value">{{ userName }}</div>
            <div class="workspace-shell__summary-meta">{{ userEmail }}</div>
            <div v-if="currentRoleLabel" class="workspace-shell__summary-meta">
              Role: {{ currentRoleLabel }}
            </div>
            <div v-if="contextLabel && contextValue" class="workspace-shell__summary-meta">
              {{ contextLabel }}: {{ contextValue }}
            </div>
          </div>
        </div>

        <q-scroll-area class="workspace-shell__drawer-scroll">
          <div class="workspace-shell__nav">
            <div class="workspace-shell__nav-label">Workspace</div>

            <q-list class="workspace-shell__nav-list">
              <template v-for="link in links" :key="link.to || link.title">
                <q-expansion-item
                  v-if="link.children?.length"
                  :icon="link.icon"
                  :label="link.title"
                  class="workspace-shell__nav-item"
                  default-opened
                >
                  <q-item
                    v-for="child in link.children"
                    :key="child.to ?? child.title"
                    clickable
                    :to="child.to!"
                    class="workspace-shell__nav-sub-item"
                    active-class="workspace-shell__nav-item--active"
                  >
                    <q-item-section>
                      <q-item-label>{{ child.title }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-expansion-item>

                <q-item
                  v-else-if="link.to"
                  clickable
                  :to="link.to"
                  class="workspace-shell__nav-item"
                  active-class="workspace-shell__nav-item--active"
                >
                  <q-item-section avatar>
                    <q-icon :name="link.icon" />
                  </q-item-section>

                  <q-item-section>
                    <q-item-label>{{ link.title }}</q-item-label>
                  </q-item-section>
                </q-item>
              </template>
            </q-list>
          </div>
        </q-scroll-area>

        <div class="workspace-shell__drawer-bottom">
          <q-btn
            unelevated
            icon="logout"
            label="Sign out"
            class="workspace-shell__logout"
            @click="handleLogout"
          />
        </div>
      </div>
    </q-drawer>

    <q-page-container class="workspace-shell__page-container">
      <slot />
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { requestConfirmation } from 'src/utils/appFeedback'

export interface WorkspaceLink {
  title: string
  caption: string
  icon: string
  to?: string
  children?: WorkspaceLink[]
}

const props = defineProps<{
  logoutTo: string
  theme: 'platform' | 'app' | 'shop'
  links: WorkspaceLink[]
}>()

const WORKSPACE_THEME_CLASSES = ['theme-platform', 'theme-app', 'theme-shop']

const drawerOpen = ref(false)
const router = useRouter()
const authStore = useAuthStore()

const themeClasses = computed(() => [
  `workspace-shell--${props.theme}`,
  `theme-${props.theme}`,
])

const applyBodyThemeClass = (theme: 'platform' | 'app' | 'shop') => {
  if (typeof document === 'undefined') {
    return
  }

  document.body.classList.remove(...WORKSPACE_THEME_CLASSES)
  document.body.classList.add(`theme-${theme}`)
}

watch(
  () => props.theme,
  (theme) => {
    applyBodyThemeClass(theme)
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  if (typeof document === 'undefined') {
    return
  }

  document.body.classList.remove(...WORKSPACE_THEME_CLASSES)
})
const userName = computed(
  () => authStore.user?.fullName ?? authStore.user?.email ?? 'Workspace user',
)
const userEmail = computed(() => authStore.user?.email ?? 'No active session')
const userAvatarUrl = computed(() => authStore.user?.avatarUrl ?? null)
const currentRoleLabel = computed(() => {
  const role = authStore.matchedRole
  if (!role) {
    return ''
  }

  return role
    .split('_')
    .map((part) => (part ? part[0]!.toUpperCase() + part.slice(1) : ''))
    .join(' ')
})
const contextLabel = computed(() => {
  if (authStore.scope === 'shop') {
    return 'Customer group'
  }

  if (authStore.scope === 'app') {
    return 'Tenant'
  }

  return ''
})
const contextValue = computed(() => {
  if (authStore.scope === 'shop') {
    return authStore.customerGroup?.name ?? ''
  }

  if (authStore.scope === 'app') {
    return authStore.selectedTenant?.name ?? authStore.tenant?.name ?? ''
  }

  return ''
})
const userInitials = computed(() => {
  const source = userName.value?.trim() || userEmail.value?.trim()
  if (!source) return '?'

  const parts = source.split(/\s+/).filter(Boolean)
  if (parts.length >= 2) {
    return `${parts[0]?.[0] ?? ''}${parts[1]?.[0] ?? ''}`.toUpperCase()
  }

  return source.slice(0, 2).toUpperCase()
})

const handleLogout = async () => {
  const shouldSignOut = await requestConfirmation(
    'End your current session on this workspace?',
    'Sign out',
    'Sign out',
  )

  if (!shouldSignOut) {
    return
  }

  drawerOpen.value = false

  try {
    await supabase.auth.signOut()
  } catch (error) {
    console.error('[auth] Failed to sign out from Supabase session', error)
  } finally {
    authStore.clearAccess()

    try {
      await router.replace(props.logoutTo)
    } catch (error) {
      console.error('[auth] Failed to redirect after sign out', error)
    }
  }
}
</script>

<style scoped>
.workspace-shell {
  min-height: 100vh;
  --shell-base: var(--bw-theme-base, #eef2f5);
  --shell-surface: var(--bw-theme-surface, rgb(255 255 255 / 0.92));
  --shell-border: var(--bw-theme-border, rgb(40 56 74 / 0.12));
  --shell-shadow: var(--bw-theme-shadow, rgb(25 35 47 / 0.08));
  --shell-ink: var(--bw-theme-ink, #1f2937);
  --shell-muted: var(--bw-theme-muted, #6b7280);
  --shell-accent: var(--bw-theme-primary, #2563eb);
  --shell-accent-soft: var(--bw-theme-primary-soft, rgb(37 99 235 / 0.12));
  background: var(--shell-base);
  color: var(--shell-ink);
}

.workspace-shell__header {
  background: color-mix(in srgb, var(--shell-surface) 90%, white 10%);
  backdrop-filter: blur(18px);
  border-bottom: 1px solid var(--shell-border);
}

.workspace-shell__toolbar {
  gap: 0.6rem;
  padding: 0.55rem 0.75rem;
}

.workspace-shell__menu {
  color: var(--shell-ink);
  background: var(--shell-accent-soft);
}

.workspace-shell__context {
  min-width: 0;
  flex: 1 1 auto;
}

.workspace-shell__actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.workspace-shell__summary-label,
.workspace-shell__nav-label {
  font-size: 0.72rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--shell-muted);
}

.workspace-shell__summary-value {
  margin-top: 0.22rem;
  font-weight: 600;
}

.workspace-shell__summary-meta {
  margin-top: 0.28rem;
  color: var(--shell-muted);
  word-break: break-word;
}

.workspace-shell__drawer {
  background: transparent;
}

.workspace-shell__drawer-inner {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: color-mix(in srgb, var(--shell-surface) 94%, white 6%);
  border-right: 1px solid var(--shell-border);
}

.workspace-shell__drawer-top,
.workspace-shell__drawer-bottom {
  padding: 0.75rem;
}

.workspace-shell__summary {
  margin-top: 0.5rem;
  padding: 0.75rem;
  border-radius: 0.75rem;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.62), rgba(255, 255, 255, 0.24));
  border: 1px solid var(--shell-border);
}

.workspace-shell__profile-row {
  display: flex;
  align-items: center;
  margin-bottom: 0.55rem;
}

.workspace-shell__avatar {
  overflow: hidden;
  border: 1px solid var(--shell-border);
  background: color-mix(in srgb, var(--shell-accent) 18%, white 82%);
}

.workspace-shell__avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.workspace-shell__avatar-fallback {
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--shell-ink);
}

.workspace-shell__drawer-scroll {
  flex: 1;
}

.workspace-shell__nav {
  padding: 0 0.6rem 0.75rem;
}

.workspace-shell__nav-list {
  margin-top: 0.45rem;
  display: grid;
  gap: 0.2rem;
}

.workspace-shell__nav-item {
  border-radius: 0.65rem;
  color: var(--shell-ink);
}

.workspace-shell__nav-item--active {
  background: var(--shell-accent-soft);
  color: var(--shell-ink);
}

.workspace-shell__logout {
  width: 100%;
  padding: 0.65rem 0.8rem;
  border-radius: 0.65rem;
  background: var(--shell-accent);
  color: #fffaf1;
}

.workspace-shell__page-container {
  padding: clamp(0.5rem, 1.2vw, 0.9rem);
}

@media (max-width: 599px) {
  .workspace-shell__toolbar {
    padding: 0.5rem 0.6rem;
  }

  .workspace-shell__actions {
    gap: 0.35rem;
  }
}

.workspace-shell__nav-sub-item {
  padding-left: 3.4rem;
}
</style>
