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
      <div class="row items-center q-gutter-sm">
        <q-btn
          v-if="canShowOrdersIcon"
          flat
          color="primary"
          icon="receipt_long"
          label="Orders"
          no-caps
          @click="goToOrders"
        />
        <q-btn
          v-if="canShowCartIcon"
          color="primary"
          icon="shopping_cart"
          :label="isKobaActive ? '' : 'Cart'"
          :flat="isKobaActive"
          :round="isKobaActive"
          :dense="isKobaActive"
          :unelevated="!isKobaActive"
          :class="isKobaActive ? '' : 'shop-cart-btn'"
          no-caps
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
      </div>
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import WorkspaceShell from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useCartStore } from 'src/modules/cart/stores/cartStore'
import { useShopWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'
import { canAccessModule } from 'src/modules/navigation/modulePermissions'
import { useKobaCartStore } from 'src/modules/koba/retail/stores/kobaCartStore'

const authStore = useAuthStore()
const cartStore = useCartStore()
const kobaCartStore = useKobaCartStore()
const router = useRouter()
const route = useRoute()
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

const isKobaActive = computed(() => {
  return !!(route.name && String(route.name).includes('koba'))
})

const cartItemCount = computed(() => {
  if (isKobaActive.value) {
    return kobaCartStore.itemCount
  }
  return cartStore.items.length
})

const isCommerceCartActive = computed(() =>
  canAccessModule({
    scope: authStore.scope,
    tenantId: authStore.tenantId,
    customerGroupId: authStore.customerGroupId,
    role: authStore.matchedRole,
    moduleKey: 'commerce_cart',
    activeModuleKeys: authStore.activeModuleKeys,
  }),
)

const isStandardCartActive = computed(() =>
  canAccessModule({
    scope: authStore.scope,
    tenantId: authStore.tenantId,
    customerGroupId: authStore.customerGroupId,
    role: authStore.matchedRole,
    moduleKey: 'cart',
    activeModuleKeys: authStore.activeModuleKeys,
  }),
)

const canShowCartIcon = computed(() => {
  if (isKobaActive.value) {
    return true
  }
  return isCommerceCartActive.value || isStandardCartActive.value
})

const isCommerceOrderActive = computed(() =>
  canAccessModule({
    scope: authStore.scope,
    tenantId: authStore.tenantId,
    customerGroupId: authStore.customerGroupId,
    role: authStore.matchedRole,
    moduleKey: 'commerce_order',
    activeModuleKeys: authStore.activeModuleKeys,
  }),
)

const isStandardOrderActive = computed(() =>
  canAccessModule({
    scope: authStore.scope,
    tenantId: authStore.tenantId,
    customerGroupId: authStore.customerGroupId,
    role: authStore.matchedRole,
    moduleKey: 'order_management',
    activeModuleKeys: authStore.activeModuleKeys,
  }),
)

const canShowOrdersIcon = computed(() => {
  if (isKobaActive.value) {
    return true
  }
  return isCommerceOrderActive.value || isStandardOrderActive.value
})

const kobaCartRouteName = computed(() => {
  const name = String(route.name ?? '')
  if (name.includes('retail')) {
    return name.includes('shop') ? 'shop-koba-retail-cart-page' : 'app-koba-retail-cart-page'
  }
  if (name.includes('wholesale') || name.includes('resale')) {
    return name.includes('shop') ? 'shop-koba-wholesale-cart-page' : 'app-koba-wholesale-cart-page'
  }
  return name.includes('shop') ? 'shop-koba-retail-cart-page' : 'app-koba-retail-cart-page'
})

const goToCart = async () => {
  if (isKobaActive.value) {
    const targetRoute = kobaCartRouteName.value
    if (router.hasRoute(targetRoute)) {
      await router.push({ name: targetRoute })
    } else {
      const fallbackRoute = String(route.name ?? '').includes('shop') ? 'shop-koba-retail-cart-page' : 'app-koba-retail-cart-page'
      if (router.hasRoute(fallbackRoute)) {
        await router.push({ name: fallbackRoute })
      }
    }
    return
  }
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  if (isCommerceCartActive.value) {
    await router.push(`${tenantPrefix}/shop/commerce-shop/cart`)
  } else {
    await router.push(`${tenantPrefix}/shop/cart`)
  }
}

const goToOrders = async () => {
  if (isKobaActive.value) {
    const targetRoute = String(route.name ?? '').includes('shop') ? 'shop-koba-retail-orders-page' : 'app-koba-retail-orders-page'
    if (router.hasRoute(targetRoute)) {
      await router.push({ name: targetRoute })
      return
    }
  }
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  if (isCommerceOrderActive.value) {
    await router.push(`${tenantPrefix}/shop/commerce-shop/orders`)
  } else {
    await router.push(`${tenantPrefix}/shop/orders`)
  }
}

onMounted(() => {
  if (authStore.tenantId) {
    void cartStore.fetchItemsForContext({
      tenant_id: authStore.tenantId,
      customer_group_id: authStore.customerGroupId,
    })
  }
  if (isKobaActive.value) {
    void kobaCartStore.fetchCart()
  }
})

watch(
  () => isKobaActive.value,
  (active) => {
    if (active) {
      void kobaCartStore.fetchCart()
    }
  },
)
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
  border-radius: 999px;
}
</style>
