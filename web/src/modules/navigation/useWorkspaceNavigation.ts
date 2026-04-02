import { computed } from 'vue'

import type { WorkspaceLink } from 'src/components/WorkspaceShell.vue'
import { useModulePermissions } from './modulePermissions'

const appBaseLinks: WorkspaceLink[] = [
  {
    title: 'Dashboard',
    caption: 'Internal activity and quick actions',
    icon: 'insights',
    to: '/app/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'Open tenant details and assignments',
    icon: 'domain',
    to: '/app/tenants',
  },
]

const shopBaseLinks: WorkspaceLink[] = [
  {
    title: 'Dashboard',
    caption: 'Current orders, approvals, and next actions',
    icon: 'shopping_bag',
    to: '/shop/dashboard',
  },
]

const platformLinks: WorkspaceLink[] = [
  {
    title: 'Dashboard',
    caption: 'Platform pulse and rollout status',
    icon: 'space_dashboard',
    to: '/platform/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'Create and govern businesses',
    icon: 'apartment',
    to: '/platform/tenants',
  },
  {
    title: 'Feature Catalog',
    caption: 'Control modules and activation',
    icon: 'inventory_2',
    to: '/platform/modules',
  },
]

export const useAppWorkspaceLinks = () => {
  const { accessibleModuleRoutes } = useModulePermissions()

  const links = computed<WorkspaceLink[]>(() => [
    ...appBaseLinks,
    ...accessibleModuleRoutes.value.map((routeDefinition) => ({
      title: routeDefinition.title,
      caption: routeDefinition.caption,
      icon: routeDefinition.icon,
      to: routeDefinition.to,
    })),
  ])

  return {
    links,
  }
}

export const useShopWorkspaceLinks = () => {
  const { accessibleModuleRoutes } = useModulePermissions()

  const links = computed<WorkspaceLink[]>(() => [
    ...shopBaseLinks,
    ...accessibleModuleRoutes.value.map((routeDefinition) => ({
      title: routeDefinition.title,
      caption: routeDefinition.caption,
      icon: routeDefinition.icon,
      to: routeDefinition.to,
    })),
  ])

  return {
    links,
  }
}

export const usePlatformWorkspaceLinks = () => ({
  links: computed<WorkspaceLink[]>(() => platformLinks),
})
