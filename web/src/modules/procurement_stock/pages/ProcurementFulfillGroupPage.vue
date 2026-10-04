<template>
  <ProcurementDemandDesk mode="fulfill" :fixed-document="fixedDocument" />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import ProcurementDemandDesk, {
  type ProcurementDemandFixedDocument,
} from '../components/ProcurementDemandDesk.vue';
import type { ProcurementDemandDocumentType } from '../repositories/procurementDemandRepository';

const route = useRoute();

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
</script>
