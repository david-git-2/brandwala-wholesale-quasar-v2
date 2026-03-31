<template>
  <q-layout view="lHh Lpr lFf">
    <q-header elevated class="bg-primary text-white">
      <q-toolbar>
        <q-btn flat dense round icon="menu" aria-label="Menu" @click="toggleLeftDrawer" />

        <q-toolbar-title class="brand-title">
          BrandWala
        </q-toolbar-title>

        <div class="text-caption text-white">Platform</div>
      </q-toolbar>
    </q-header>

    <q-drawer v-model="leftDrawerOpen" show-if-above bordered class="layout-drawer">
      <q-list padding>
        <q-item-label header class="text-uppercase text-grey-7"> Navigation </q-item-label>

        <EssentialLink v-for="link in linksList" :key="link.title" v-bind="link" />
      </q-list>
    </q-drawer>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { ref } from 'vue'

import EssentialLink, { type EssentialLinkProps } from 'components/EssentialLink.vue'

const linksList: EssentialLinkProps[] = [
  {
    title: 'Platform Dashboard',
    caption: 'platform/dashboard',
    icon: 'admin_panel_settings',
    to: '/platform/dashboard',
  },
  {
    title: 'Platform Tenants',
    caption: 'platform/tenants',
    icon: 'domain',
    to: '/platform/tenants',
  },
]

const leftDrawerOpen = ref(false)

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value
}
</script>
