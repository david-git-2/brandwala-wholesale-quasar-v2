import { computed, onBeforeUnmount, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

/** Breadcrumb trail for inbound shipment pages; leaf shows shipment name instead of "Shipment Details". */
export function useInboundShipmentPageBreadcrumbs(shipmentId: number) {
  const route = useRoute();
  const authStore = useAuthStore();
  const shipmentStore = useGlobalShipmentStore();
  const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

  const shipmentLeafLabel = computed(() => {
    const ship = shipmentStore.currentShipment;
    if (ship && ship.id === shipmentId) {
      const name = ship.name?.trim();
      if (name) return name;
    }
    return Number.isFinite(shipmentId) ? `Shipment #${shipmentId}` : 'Shipment';
  });

  const breadcrumbItems = computed(() => {
    const tenantSlug =
      (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null) ||
      authStore.selectedTenant?.slug ||
      undefined;
    const params = tenantSlug ? { tenantSlug } : {};

    return [
      {
        label: authStore.selectedTenant?.name || 'Workspace',
        icon: 'ph ph-buildings',
      },
      {
        label: 'Procurement',
        to: { name: 'app-procurement-overview', params },
      },
      {
        label: 'Shipments',
        to: { name: 'app-procurement-shipment-list', params },
      },
      { label: shipmentLeafLabel.value },
    ];
  });

  watch(breadcrumbItems, (items) => setCustomBreadcrumbs(items), { immediate: true });
  onBeforeUnmount(() => clearCustomBreadcrumbs());
}
