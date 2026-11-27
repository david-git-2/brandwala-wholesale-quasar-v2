<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="col row no-wrap overflow-hidden config-layout">
      <nav class="config-nav column flex-shrink-0">
        <q-list padding class="q-pa-none config-nav__list">
          <q-item
            v-for="item in menuItems"
            :key="item.key"
            v-ripple
            clickable
            :active="activeSection === item.key"
            active-class="config-nav__item--active"
            class="config-nav__item rounded-borders"
            @click="activeSection = item.key"
          >
            <q-item-section>
              <q-item-label class="text-body2">{{ item.label }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </nav>

      <q-separator vertical class="q-mx-md" />

      <section v-if="activeSection === 'people'" class="col scroll config-panel">
        <ProxyPeopleGroupsPanel />
      </section>
      <section v-else-if="activeSection === 'shipment'" class="col scroll config-panel">
        <ProxyShipmentManagementPanel />
      </section>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import ProxyPeopleGroupsPanel from '../components/ProxyPeopleGroupsPanel.vue';
import ProxyShipmentManagementPanel from '../components/ProxyShipmentManagementPanel.vue';

type ConfigSection = 'people' | 'shipment';

const menuItems = [
  { key: 'people' as const, label: 'People management' },
  { key: 'shipment' as const, label: 'Shipment management' },
];

const activeSection = ref<ConfigSection>('people');
</script>

<style scoped>
.config-layout {
  min-height: 0;
}

.config-nav {
  width: 220px;
}

.config-nav__list :deep(.q-item) {
  min-height: 56px;
  padding-top: 14px;
  padding-bottom: 14px;
}

.config-nav__item--active {
  color: var(--q-primary);
  background: color-mix(in srgb, var(--q-primary) 12%, transparent);
  font-weight: 600;
}

.config-panel {
  padding-top: 2px;
}

</style>