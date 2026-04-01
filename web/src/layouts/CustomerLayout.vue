<template>
  <q-layout view="hHh lpR fFf" class="customer-layout">
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
          <div class="brand-mark">C</div>

          <div>
            <div class="brand-title">Customer Portal</div>
            <div class="brand-subtitle">Workspace</div>
          </div>
        </q-toolbar-title>
      </q-toolbar>
    </q-header>

    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      bordered
      :width="268"
      class="layout-drawer"
    >
      <div class="drawer-inner">
        <div class="drawer-brand q-px-md q-py-lg">
          <div class="row items-center q-gutter-sm">
            <div class="brand-mark brand-mark--drawer">C</div>

            <div>
              <div class="text-subtitle1 text-weight-bold text-primary">
                Customer Portal
              </div>
              <div class="text-caption drawer-subtitle">
                Workspace
              </div>
            </div>
          </div>
        </div>

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
      </div>
    </q-drawer>

    <q-page-container class="page-container">
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import EssentialLink, { type EssentialLinkProps } from 'components/EssentialLink.vue'

const linksList: EssentialLinkProps[] = [
  {
    title: 'Dashboard',
    caption: 'customer/dashboard',
    icon: 'space_dashboard',
    to: '/customer/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'customer/tenants',
    icon: 'domain',
    to: '/customer/tenants',
  },
]

const leftDrawerOpen = ref(false)

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value
}
</script>

<style scoped>
.customer-layout {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(38, 166, 154, 0.1), transparent 30%),
    radial-gradient(circle at top right, rgba(25, 118, 210, 0.08), transparent 24%),
    radial-gradient(circle at bottom right, rgba(156, 39, 176, 0.06), transparent 28%),
    #f7f9fc;
}

.glass-header {
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border-bottom: 1px solid rgba(38, 166, 154, 0.08);
  box-shadow: 0 8px 30px rgba(17, 24, 39, 0.05);
}

.header-btn {
  color: var(--q-primary);
  background: rgba(255, 255, 255, 0.72);
  box-shadow: inset 0 0 0 1px rgba(38, 166, 154, 0.1);
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
    var(--q-secondary) 0%,
    var(--q-primary) 55%,
    var(--q-accent) 100%
  );
  box-shadow: 0 10px 22px rgba(38, 166, 154, 0.2);
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
  border-right: 1px solid rgba(38, 166, 154, 0.08);
}

.drawer-inner {
  height: 100%;
  background: linear-gradient(
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

.page-container {
  padding-top: 8px;
}
</style>
