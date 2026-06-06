<template>
  <q-layout view="hHh lpR fFf" class="workspace-shell" :class="themeClasses">
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
          <div class="row items-center no-wrap q-gutter-sm q-pa-sm rounded-borders profile-card">
            <q-avatar size="36px" class="workspace-shell__avatar">
              <img
                v-if="userAvatarUrl"
                :src="userAvatarUrl"
                class="workspace-shell__avatar-image"
                referrerpolicy="no-referrer"
                alt=""
              >
              <span v-else class="workspace-shell__avatar-fallback">{{ userInitials }}</span>
            </q-avatar>
            <div class="col ellipsis">
              <div class="text-subtitle2 text-weight-bold ellipsis text-black leading-tight">{{ userName }}</div>
              <div class="text-caption text-grey-7 ellipsis leading-tight">{{ userEmail }}</div>
            </div>
            
            <q-btn flat round dense icon="more_vert" size="sm" color="grey-7">
              <q-menu style="min-width: 200px">
                <q-list dense class="q-py-xs">
                  <q-item-label header class="text-uppercase text-weight-bold text-grey-7" style="font-size: 10px; letter-spacing: 0.1em;">Session Info</q-item-label>
                  <q-item v-if="currentRoleLabel">
                    <q-item-section avatar class="q-pr-none" style="min-width: 24px;">
                      <q-icon name="shield" size="xs" color="grey-6" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-caption text-weight-medium">Role</q-item-label>
                      <q-item-label caption>{{ currentRoleLabel }}</q-item-label>
                    </q-item-section>
                  </q-item>
                  <q-item v-if="contextLabel && contextValue">
                    <q-item-section avatar class="q-pr-none" style="min-width: 24px;">
                      <q-icon name="apartment" size="xs" color="grey-6" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-caption text-weight-medium">{{ contextLabel }}</q-item-label>
                      <q-item-label caption>{{ contextValue }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </div>
        </div>

        <q-scroll-area class="workspace-shell__drawer-scroll">
          <div class="workspace-shell__nav">
            <div class="workspace-shell__drawer-search q-mb-md">
              <q-input
                filled
                dense
                readonly
                model-value=""
                placeholder="Search pages... (⌘K)"
                class="soft-input cursor-pointer"
                @click="showCommandPalette = true"
              >
                <template #prepend>
                  <q-icon name="search" size="xs" />
                </template>
                <template #append>
                  <div class="shortcut-badge">⌘K</div>
                </template>
              </q-input>
            </div>

            <div class="workspace-shell__nav-label">Workspace</div>

            <q-list class="workspace-shell__nav-list">
              <template v-for="link in links" :key="link.to || link.title">
                <q-expansion-item
                  v-if="link.children?.length"
                  :icon="link.icon"
                  :label="link.title"
                  class="workspace-shell__nav-item workspace-shell__nav-group"
                  expand-separator
                >
                  <div class="workspace-shell__nav-sub-list">
                    <q-item
                      v-for="child in link.children"
                      :key="child.to ?? child.title"
                      clickable
                      :to="child.to!"
                      exact
                      class="workspace-shell__nav-sub-item"
                      active-class="workspace-shell__nav-item--active"
                    >
                      <q-item-section>
                        <q-item-label>{{ child.title }}</q-item-label>
                      </q-item-section>
                    </q-item>
                  </div>
                </q-expansion-item>

                <q-item
                  v-else-if="link.to"
                  clickable
                  :to="link.target ? undefined : link.to"
                  :href="link.target ? link.to : undefined"
                  :target="link.target"
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
            flat
            dense
            no-caps
            icon="logout"
            label="Sign out"
            color="negative"
            class="workspace-shell__logout"
            @click="handleLogout"
          />
        </div>
      </div>
    </q-drawer>

    <q-page-container class="workspace-shell__page-container">
      <slot />
    </q-page-container>

    <!-- Command Palette Dialog -->
    <q-dialog
      v-model="showCommandPalette"
      position="top"
      class="command-palette-dialog"
      @show="onPaletteShow"
      @hide="onPaletteHide"
    >
      <q-card style="width: 600px; max-width: 90vw; margin-top: 10vh;" class="floating-surface shadow-5 command-palette-card">
        <q-card-section class="q-pa-sm">
          <q-input
            ref="searchInputRef"
            v-model="searchQuery"
            placeholder="Type a page name to navigate..."
            outlined
            dense
            autofocus
            class="soft-input command-palette-input"
            @keydown="onInputKeydown"
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
            <template #append>
              <q-btn
                v-if="searchQuery"
                flat
                round
                dense
                icon="close"
                size="sm"
                @click="searchQuery = ''"
              />
              <q-badge color="grey-4" text-color="grey-8" class="q-ml-xs">ESC</q-badge>
            </template>
          </q-input>
        </q-card-section>

        <q-separator />

        <q-scroll-area style="height: 300px;">
          <q-list v-if="filteredLinks.length" class="q-py-xs">
            <q-item
              v-for="(link, idx) in filteredLinks"
              :key="link.to || link.title"
              clickable
              :active="idx === activeIndex"
              active-class="command-palette-item--active"
              class="command-palette-item q-mx-sm q-my-xs rounded-borders"
              @click="navigate(link)"
              @mouseenter="activeIndex = idx"
            >
              <q-item-section avatar>
                <q-icon :name="link.icon" size="sm" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">
                  {{ link.title }}
                </q-item-label>
                <q-item-label caption v-if="link.caption">
                  {{ link.caption }}
                </q-item-label>
              </q-item-section>
              <q-item-section side v-if="link.parentTitle">
                <q-badge outline color="primary" size="sm">{{ link.parentTitle }}</q-badge>
              </q-item-section>
            </q-item>
          </q-list>
          <div v-else class="flex flex-center text-grey-6 q-pa-lg">
            <q-icon name="search_off" size="md" />
            <div class="q-ml-sm">No matching pages found</div>
          </div>
        </q-scroll-area>
      </q-card>
    </q-dialog>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import type { QInput } from 'quasar'

import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { requestConfirmation } from 'src/utils/appFeedback'

export interface WorkspaceLink {
  title: string
  caption: string
  icon: string
  to?: string
  target?: string
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

const showCommandPalette = ref(false)
const searchQuery = ref('')
const activeIndex = ref(0)
const searchInputRef = ref<QInput | null>(null)

interface FlattenedLink {
  title: string
  caption: string
  icon: string
  to?: string
  target?: string | undefined
  parentTitle?: string | undefined
}

const flattenedLinks = computed(() => {
  const result: FlattenedLink[] = []

  const traverse = (items: WorkspaceLink[], parentTitle?: string) => {
    for (const item of items) {
      if (item.children && item.children.length > 0) {
        traverse(item.children, item.title)
      } else if (item.to) {
        result.push({
          title: item.title,
          caption: item.caption,
          icon: item.icon,
          to: item.to,
          target: item.target,
          parentTitle,
        })
      }
    }
  }

  traverse(props.links)
  return result
})

const filteredLinks = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()
  if (!query) {
    return flattenedLinks.value
  }
  return flattenedLinks.value.filter((link) => {
    return (
      link.title.toLowerCase().includes(query) ||
      (link.caption && link.caption.toLowerCase().includes(query)) ||
      (link.parentTitle && link.parentTitle.toLowerCase().includes(query))
    )
  })
})

watch(searchQuery, () => {
  activeIndex.value = 0
})

const onPaletteShow = () => {
  setTimeout(() => {
    searchInputRef.value?.focus()
  }, 50)
}

const onPaletteHide = () => {
  searchQuery.value = ''
  activeIndex.value = 0
}

const onInputKeydown = (e: KeyboardEvent) => {
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    activeIndex.value = (activeIndex.value + 1) % filteredLinks.value.length
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    activeIndex.value =
      (activeIndex.value - 1 + filteredLinks.value.length) % filteredLinks.value.length
  } else if (e.key === 'Enter') {
    e.preventDefault()
    const selectedLink = filteredLinks.value[activeIndex.value]
    if (selectedLink) {
      navigate(selectedLink)
    }
  } else if (e.key === 'Escape') {
    showCommandPalette.value = false
  }
}

const navigate = (link: FlattenedLink) => {
  showCommandPalette.value = false
  if (link.target === '_blank' && link.to) {
    window.open(link.to, '_blank')
  } else if (link.to) {
    void router.push(link.to)
  }
}

const handleKeyDown = (e: KeyboardEvent) => {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault()
    showCommandPalette.value = !showCommandPalette.value
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeyDown)
})

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
  window.removeEventListener('keydown', handleKeyDown)

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
  --workspace-header-offset: 58px;
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

.workspace-shell :deep(.q-drawer) {
  position: fixed !important;
  top: var(--workspace-header-offset) !important;
  bottom: 0 !important;
}

.workspace-shell :deep(.q-drawer__content) {
  height: calc(100vh - var(--workspace-header-offset)) !important;
  overflow: hidden;
}

.workspace-shell__drawer-inner {
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: color-mix(in srgb, var(--shell-surface) 94%, white 6%);
  border-right: 1px solid var(--shell-border);
}

.workspace-shell__drawer-top,
.workspace-shell__drawer-bottom {
  padding: 0.75rem;
}

.profile-card {
  background: rgba(255, 255, 255, 0.5);
  border: 1px solid var(--shell-border);
  transition: background-color 0.2s ease;
}

.profile-card:hover {
  background: rgba(255, 255, 255, 0.85);
}

.leading-tight {
  line-height: 1.25;
}

.workspace-shell__avatar {
  overflow: hidden;
  border: 1px solid var(--shell-border);
  background: #ffffff;
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
  min-height: 0;
}

.workspace-shell__drawer-scroll :deep(.q-scrollarea__content) {
  padding-bottom: 88px;
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

.workspace-shell__nav-group {
  overflow: visible;
  border: 1px solid transparent;
  margin-bottom: 0.45rem;
}

.workspace-shell__nav-group :deep(.q-expansion-item__container) {
  border-radius: 0.65rem;
}

.workspace-shell__nav-group :deep(.q-expansion-item__content) {
  overflow: visible;
  padding-bottom: 0.35rem;
}

.workspace-shell__nav-group :deep(.q-item) {
  min-height: 44px;
}

.workspace-shell__nav-sub-list {
  margin: 0.2rem 0.35rem 0.45rem 2.05rem;
  padding-left: 0.6rem;
  border-left: 1px solid var(--shell-border);
  display: grid;
  gap: 0.18rem;
}

.workspace-shell__nav-item--active {
  background: var(--shell-accent-soft);
  color: var(--shell-ink);
}



.workspace-shell__page-container {
  padding: clamp(0.5rem, 1.2vw, 0.9rem);
}


@media (max-width: 599px) {
  .workspace-shell {
    --workspace-header-offset: 54px;
  }

  .workspace-shell__toolbar {
    padding: 0.4rem 0.5rem;
    gap: 0.3rem;
  }

  .workspace-shell__actions {
    gap: 0.25rem;
  }
}

.workspace-shell__nav-sub-item {
  border-radius: 0.5rem;
  min-height: 38px;
  padding-left: 0.55rem;
  margin-left: 0.15rem;
}

.workspace-shell__drawer-search {
  cursor: pointer;
}

.workspace-shell__drawer-search :deep(.q-field__control) {
  cursor: pointer;
}

.workspace-shell__drawer-search :deep(input) {
  cursor: pointer;
}

.shortcut-badge {
  font-size: 10px;
  padding: 2px 6px;
  background: rgba(0, 0, 0, 0.05);
  border-radius: 4px;
  color: var(--shell-muted);
  font-weight: 600;
}

.command-palette-card {
  border: 1px solid var(--shell-border);
  background: rgba(255, 255, 255, 0.88);
  backdrop-filter: blur(12px);
  border-radius: 12px;
}

.command-palette-item {
  transition: all 0.2s ease;
}

.command-palette-item--active {
  background: var(--shell-accent-soft) !important;
  color: var(--shell-ink) !important;
}

.command-palette-input :deep(.q-field__control) {
  border-radius: 8px;
}

.workspace-shell__logout {
  width: 100%;
  padding: 0.45rem 0.6rem;
  border-radius: 0.5rem;
  font-weight: 600;
}

.workspace-shell__drawer-bottom {
  margin-top: auto;
  position: sticky;
  bottom: 0;
  z-index: 1;
  background: color-mix(in srgb, var(--shell-surface) 94%, white 6%);
  border-top: 1px solid var(--shell-border);
}
</style>
