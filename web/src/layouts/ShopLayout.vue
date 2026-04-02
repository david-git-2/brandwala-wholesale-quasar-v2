<template>
  <WorkspaceShell
    badge="SHOP"
    eyebrow="Customer Workspace"
    :title="workspaceTitle"
    :subtitle="workspaceSubtitle"
    :scope-label="scopeLabel"
    logout-to="/auth/shop/login"
    theme="shop"
    :links="links"
  >
    <template #header-extra>
      <div v-if="tenantName || customerGroupName" class="shop-context row items-center q-gutter-sm">
        <q-chip
          v-if="tenantName"
          dense
          color="white"
          text-color="dark"
          icon="storefront"
          class="shop-context__chip"
        >
          {{ tenantName }}
        </q-chip>
        <q-chip
          v-if="customerGroupName"
          dense
          color="white"
          text-color="dark"
          icon="groups"
          class="shop-context__chip"
        >
          {{ customerGroupName }}
        </q-chip>
      </div>
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed } from 'vue'

import WorkspaceShell from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShopWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'

const authStore = useAuthStore()
const { links } = useShopWorkspaceLinks()

const tenantName = computed(() => authStore.tenant?.name ?? '')
const customerGroupName = computed(() => authStore.customerGroup?.name ?? '')

const workspaceTitle = computed(() =>
  customerGroupName.value ? `${customerGroupName.value} Portal` : 'Ordering Portal',
)

const workspaceSubtitle = computed(() => {
  if (tenantName.value && customerGroupName.value) {
    return `Build carts, coordinate approvals, and manage order negotiation for ${customerGroupName.value} inside ${tenantName.value}.`
  }

  if (customerGroupName.value) {
    return `Build carts, coordinate approvals, and manage order negotiation for ${customerGroupName.value}.`
  }

  return 'Build carts, coordinate approvals, and manage order negotiation with your team.'
})

const scopeLabel = computed(() => {
  switch (authStore.matchedRole) {
    case 'customer_admin':
      return 'Customer Admin'
    case 'customer_negotiator':
      return 'Customer Negotiator'
    case 'customer_staff':
      return 'Customer Staff'
    default:
      return 'Customer'
  }
})
</script>

<style scoped>
.shop-context__chip {
  border: 1px solid var(--bw-theme-border);
  box-shadow: 0 8px 18px rgb(var(--bw-theme-primary-rgb) / 0.08);
}
</style>
