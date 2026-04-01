<template>
  <q-layout view="hHh lpR fFf" class="admin-layout">
    <q-header class="glass-header">
      <q-toolbar class="q-px-md q-py-sm">
        <q-btn
          flat
          dense
          round
          icon="menu"
          class="header-btn"
          @click="toggleLeftDrawer"
        />

        <q-toolbar-title class="row items-center q-gutter-sm">
          <div class="brand-mark">A</div>

          <div>
            <div class="brand-title">Admin App</div>
            <div class="brand-subtitle">Management Console</div>
          </div>
        </q-toolbar-title>
              <TenantSelector />

      </q-toolbar>

    </q-header>

    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      bordered
      :width="268"
      class="layout-drawer"
    >
      <div class="drawer-inner column no-wrap">
        <div class="drawer-brand q-px-md q-py-lg">
          <div class="row items-center q-gutter-sm">
            <div class="brand-mark brand-mark--drawer">A</div>

            <div>
              <div class="text-subtitle1 text-weight-bold text-primary">
                Admin App
              </div>
              <div class="text-caption drawer-subtitle">
                Management Console
              </div>
            </div>
          </div>
        </div>

        <q-scroll-area class="col">
          <q-list padding class="q-pt-md">
            <q-item-label header class="drawer-label">
              Navigation
            </q-item-label>

            <EssentialLink
              v-for="link in linksList"
              :key="link.title"
              v-bind="link"
            />
          </q-list>
        </q-scroll-area>

        <div class="q-pa-md q-pb-lg border-top">
          <q-btn
            flat
            class="full-width logout-btn"
            color="negative"
            icon="logout"
            label="Log Out"
            @click="confirmLogout"
          />
        </div>
      </div>
    </q-drawer>

    <q-page-container class="page-container">
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import EssentialLink, { type EssentialLinkProps } from 'components/EssentialLink.vue'
import TenantSelector from 'components/TenantSelector.vue'

const $q = useQuasar()
const router = useRouter()
const authStore = useAuthStore()

const linksList: EssentialLinkProps[] = [
  {
    title: 'Dashboard',
    caption: 'admin/dashboard',
    icon: 'space_dashboard',
    to: '/admin/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'admin/tenants',
    icon: 'domain',
    to: '/admin/tenants',
  },
]

const leftDrawerOpen = ref(false)

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

function confirmLogout() {
  $q.dialog({
    title: 'Confirm Logout',
    message: 'Are you sure you want to log out?',
    cancel: true,
    persistent: true,
    ok: {
      flat: true,
      color: 'negative',
      label: 'Logout',
    },
  }).onOk(() => {
    void (async () => {
      try {
        await supabase.auth.signOut()
        authStore.clearAccess()
        await router.push('/admin/login')
      } catch (error) {
        console.error('Error during logout:', error)
        $q.notify({
          type: 'negative',
          message: 'Logout failed. Please try again.',
        })
      }
    })()
  })
}
</script>

<style scoped>
.admin-layout {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(25, 118, 210, 0.1), transparent 30%),
    radial-gradient(circle at top right, rgba(156, 39, 176, 0.08), transparent 24%),
    radial-gradient(circle at bottom right, rgba(38, 166, 154, 0.08), transparent 28%),
    #f7f9fc;
}

.glass-header {
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border-bottom: 1px solid rgba(25, 118, 210, 0.08);
  box-shadow: 0 8px 30px rgba(17, 24, 39, 0.05);
}

.header-btn {
  color: var(--q-primary);
  background: rgba(255, 255, 255, 0.72);
  box-shadow: inset 0 0 0 1px rgba(25, 118, 210, 0.08);
}

.brand-mark {
  width: 36px;
  height: 36px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 700;
  color: white;
  background: linear-gradient(
    135deg,
    var(--q-primary) 0%,
    var(--q-secondary) 55%,
    var(--q-accent) 100%
  );
  box-shadow: 0 10px 22px rgba(25, 118, 210, 0.2);
}

.brand-mark--drawer {
  width: 40px;
  height: 40px;
}

.brand-title {
  font-size: 16px;
  line-height: 1.1;
  font-weight: 700;
  color: #1f2937;
}

.brand-subtitle {
  font-size: 12px;
  line-height: 1.1;
  color: #6b7280;
  margin-top: 2px;
}

.layout-drawer {
  background: rgba(255, 255, 255, 0.76);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  border-right: 1px solid rgba(25, 118, 210, 0.08);
}

.drawer-inner {
  height: 100%;
  background:
    linear-gradient(
      180deg,
      rgba(255, 255, 255, 0.72) 0%,
      rgba(255, 255, 255, 0.9) 100%
    );
}

.drawer-brand {
  border-bottom: 1px solid rgba(17, 24, 39, 0.06);
}

.drawer-subtitle {
  color: #6b7280;
}

.drawer-label {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #94a3b8;
}

.border-top {
  border-top: 1px solid rgba(17, 24, 39, 0.06);
}

.logout-btn {
  border-radius: 12px;
  background: rgba(239, 68, 68, 0.05);
  font-weight: 600;
  padding: 12px;
}

.page-container {
  padding-top: 8px;
}
</style>
