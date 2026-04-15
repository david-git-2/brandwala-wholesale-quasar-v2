<template>
  <WorkspaceShell
    :logout-to="logoutTo"
    theme="shop"
    :links="links"
  >
    <template #header-left>
      <div v-if="tenantName" class="shop-context">
        <div class="shop-context__title">{{ tenantName }}</div>
        <div v-if="customerGroupName" class="shop-context__meta">
          {{ customerGroupName }} · {{ roleLabel }}
        </div>
      </div>
    </template>

    <template #header-extra>
      <q-btn
        flat
        round
        dense
        icon="shopping_cart"
        class="shop-cart-btn"
        @click="goToCart"
      >
        <q-badge
          v-if="cartItemCount > 0"
          color="negative"
          floating
          rounded
          :label="cartItemCount"
        />
      </q-btn>
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'

import WorkspaceShell from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useCartStore } from 'src/modules/cart/stores/cartStore'
import { useShopWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'

const authStore = useAuthStore()
const cartStore = useCartStore()
const router = useRouter()
const { links } = useShopWorkspaceLinks()

const tenantName = computed(() => authStore.tenant?.name ?? '')
const customerGroupName = computed(() => authStore.customerGroup?.name ?? '')
const roleLabel = computed(() => {
  switch (authStore.matchedRole) {
    case 'customer_admin':
      return 'Customer Admin'
    case 'customer_negotiator':
      return 'Customer Negotiator'
    case 'customer_staff':
      return 'Customer Staff'
    default:
      return 'Customer User'
  }
})
const logoutTo = computed(() =>
  authStore.tenantSlug ? `/${authStore.tenantSlug}/shop/login` : '/shop/login',
)

const cartItemCount = computed(() => cartStore.items.length)

const goToCart = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/shop/cart`)
}
</script>

<style scoped>
.shop-context {
  min-width: 0;
}

.shop-context__title {
  overflow: hidden;
  font-size: clamp(1.2rem, 2vw, 1.7rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--bw-theme-ink);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.shop-context__meta {
  overflow: hidden;
  margin-top: 0.2rem;
  color: var(--bw-theme-muted);
  font-size: 0.9rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.shop-cart-btn {
  color: var(--bw-theme-ink);
}
</style>
