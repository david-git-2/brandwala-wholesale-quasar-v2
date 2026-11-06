<template>
  <ProcurementDemandDesk mode="fulfill" :fixed-document="fixedDocument" />
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import ProcurementDemandDesk, {
  type ProcurementDemandFixedDocument,
} from '../components/ProcurementDemandDesk.vue';
import type { ProcurementDemandDocumentType } from '../repositories/procurementDemandRepository';

const route = useRoute();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

const fixedDocument = computed((): ProcurementDemandFixedDocument | null => {
  const documentType = route.params.documentType as ProcurementDemandDocumentType;
  if (documentType !== 'shop_order' && documentType !== 'pbc_costing_file') {
    return null;
  }
  const rawId = route.params.documentId;
  const documentId = Number(typeof rawId === 'string' ? rawId : rawId?.[0]);
  if (!Number.isFinite(documentId)) return null;
  const documentName =
    typeof route.query.documentName === 'string' ? route.query.documentName : null;
  return { documentType, documentId, documentName };
});

const fulfillGroupLeafLabel = computed(() => {
  const doc = fixedDocument.value;
  if (!doc) return 'Delivery paper';
  const name = doc.documentName?.trim();
  if (doc.documentType === 'shop_order') {
    return name || `Order #${doc.documentId}`;
  }
  if (name) {
    return `${name} (#${doc.documentId})`;
  }
  return `Costing file #${doc.documentId}`;
});

const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

const breadcrumbItems = computed(() => {
  const tenantSlug =
    tenantStore.selectedTenant?.slug ||
    authStore.selectedTenant?.slug ||
    (route.params.tenantSlug as string | undefined);
  const procurementHub = tenantSlug ? `/${tenantSlug}/app/procurement` : '/app/procurement';
  const deliveryPaperList = tenantSlug
    ? `/${tenantSlug}/app/procurement/delivery-paper`
    : '/app/procurement/delivery-paper';

  return [
    {
      label: tenantStore.selectedTenant?.name || authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    { label: 'Procurement', to: procurementHub },
    { label: 'Delivery paper', to: deliveryPaperList },
    { label: fulfillGroupLeafLabel.value },
  ];
});

watch(breadcrumbItems, (items) => setCustomBreadcrumbs(items), { immediate: true });
onBeforeUnmount(() => clearCustomBreadcrumbs());
</script>
