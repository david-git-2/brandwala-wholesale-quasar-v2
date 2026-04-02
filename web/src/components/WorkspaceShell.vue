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
            <div class="workspace-shell__summary-label">Signed in as</div>
            <div class="workspace-shell__summary-value">{{ userName }}</div>
            <div class="workspace-shell__summary-meta">{{ userEmail }}</div>
          </div>
        </div>

        <q-scroll-area class="workspace-shell__drawer-scroll">
          <div class="workspace-shell__nav">
            <div class="workspace-shell__nav-label">Workspace</div>

            <q-list class="workspace-shell__nav-list">
              <q-item
                v-for="link in links"
                :key="link.to"
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
                  <q-item-label caption>{{ link.caption }}</q-item-label>
                </q-item-section>
              </q-item>
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
  to: string
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
  --shell-base: var(--bw-theme-base, #f4f0e8);
  --shell-surface: var(--bw-theme-surface, rgb(255 252 246 / 0.86));
  --shell-border: var(--bw-theme-border, rgb(72 58 40 / 0.12));
  --shell-shadow: var(--bw-theme-shadow, rgb(59 46 28 / 0.14));
  --shell-ink: var(--bw-theme-ink, #241d16);
  --shell-muted: var(--bw-theme-muted, #7d6b58);
  --shell-accent: var(--bw-theme-primary, #8a5b2b);
  --shell-accent-soft: var(--bw-theme-primary-soft, rgb(138 91 43 / 0.12));
  background:
    radial-gradient(
      circle at top left,
      rgb(var(--bw-theme-primary-rgb, 138 91 43) / 0.18),
      transparent 34%
    ),
    radial-gradient(
      circle at bottom right,
      rgb(var(--bw-theme-primary-rgb, 138 91 43) / 0.12),
      transparent 30%
    ),
    linear-gradient(180deg, var(--bw-theme-gradient-top, #f8f3ec) 0%, var(--shell-base) 100%);
  color: var(--shell-ink);
}

.workspace-shell__header {
  background: color-mix(in srgb, var(--shell-surface) 90%, white 10%);
  backdrop-filter: blur(18px);
  border-bottom: 1px solid var(--shell-border);
}

.workspace-shell__toolbar {
  gap: 1rem;
  padding: 0.9rem 1.1rem;
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
  gap: 0.9rem;
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
  padding: 1.2rem;
}

.workspace-shell__summary {
  margin-top: 1.25rem;
  padding: 1rem;
  border-radius: 1.2rem;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.62), rgba(255, 255, 255, 0.24));
  border: 1px solid var(--shell-border);
}

.workspace-shell__drawer-scroll {
  flex: 1;
}

.workspace-shell__nav {
  padding: 0 0.9rem 1rem;
}

.workspace-shell__nav-list {
  margin-top: 0.7rem;
  display: grid;
  gap: 0.35rem;
}

.workspace-shell__nav-item {
  border-radius: 1rem;
  color: var(--shell-ink);
}

.workspace-shell__nav-item--active {
  background: var(--shell-accent-soft);
  color: var(--shell-ink);
}

.workspace-shell__logout {
  width: 100%;
  padding: 0.9rem 1rem;
  border-radius: 1rem;
  background: var(--shell-accent);
  color: #fffaf1;
}

.workspace-shell__page-container {
  padding: clamp(0.75rem, 2vw, 1.4rem);
}

@media (max-width: 599px) {
  .workspace-shell__toolbar {
    padding: 0.8rem;
  }

  .workspace-shell__actions {
    gap: 0.5rem;
  }
}
</style>
