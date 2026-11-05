<template>
  <div
    v-if="enabled"
    class="document-delivery-papers q-py-xs"
    :class="{ 'document-delivery-papers--section': layout === 'section' }"
  >
    <div
      class="document-delivery-papers__inner"
      :class="layout === 'section' ? 'column q-gutter-y-sm' : 'row items-center q-gutter-sm wrap'"
    >
      <span
        class="text-caption text-weight-medium text-grey-8"
        :class="layout === 'section' ? 'text-subtitle2 text-weight-bold text-grey-9' : ''"
      >
        Delivery papers
      </span>
      <TfBtn
        v-if="allowCreate"
        variant="secondary"
        size="sm"
        icon="ph ph-plus"
        label="Create"
        :class="layout === 'section' ? 'self-start' : ''"
        :loading="isCreating"
        :disable="isCreating"
        @click="onCreate"
      />
      <q-spinner-dots
        v-if="isLoading && papers.length === 0"
        size="18px"
        color="primary"
        :class="layout === 'section' ? 'self-center q-py-sm' : ''"
      />
      <div
        v-if="layout === 'section' && papers.length"
        class="column q-gutter-y-xs full-width"
      >
        <button
          v-for="paper in papers"
          :key="paper.id"
          type="button"
          class="document-delivery-papers__chip document-delivery-papers__chip--row row items-center justify-between no-wrap q-gutter-x-xs"
          @click="emit('open-paper', paper.id)"
        >
          <span class="font-mono text-caption text-weight-bold">{{ chipLabel(paper.id) }}</span>
          <TfStatusBadge :status="paper.status" />
        </button>
      </div>
      <template v-else-if="layout !== 'section'">
        <button
          v-for="paper in papers"
          :key="paper.id"
          type="button"
          class="document-delivery-papers__chip row items-center no-wrap q-gutter-x-xs"
          @click="emit('open-paper', paper.id)"
        >
          <span class="font-mono text-caption text-weight-bold">{{ chipLabel(paper.id) }}</span>
          <TfStatusBadge :status="paper.status" />
        </button>
      </template>
      <span
        v-if="!isLoading && papers.length === 0"
        class="text-caption text-grey-6"
        :class="layout === 'section' ? 'q-py-xs' : ''"
      >
        None yet
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { documentDeliveryPaperChipLabel } from '../utils/documentDeliveryPapers';
import { useDocumentDeliveryPapers } from '../composables/useDocumentDeliveryPapers';
import type { ProcurementDemandDocumentType } from '../repositories/procurementDemandRepository';
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    tenantId: number | null;
    documentType: ProcurementDemandDocumentType;
    documentId: number;
    enabled: boolean;
    allowCreate?: boolean;
    layout?: 'inline' | 'section';
  }>(),
  { layout: 'inline' },
);

const allowCreate = computed(() => props.allowCreate !== false);
const layout = computed(() => props.layout);

const emit = defineEmits<{
  (e: 'open-paper', paperId: number): void;
  (e: 'created', paperId: number): void;
}>();

const { papers, isLoading, isCreating, createPaper } = useDocumentDeliveryPapers({
  tenantId: computed(() => props.tenantId),
  documentType: computed(() => props.documentType),
  documentId: computed(() => props.documentId),
  enabled: computed(() => props.enabled && props.tenantId != null),
});

const chipLabel = (id: number) => documentDeliveryPaperChipLabel(id, 'draft');

const onCreate = async () => {
  const result = await createPaper();
  if (result?.id) emit('created', result.id);
};
</script>

<style scoped>
.document-delivery-papers__chip {
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
  background: var(--tf-neutral-surface);
  padding: 2px 8px;
  cursor: pointer;
}

.document-delivery-papers__chip:hover {
  border-color: var(--tf-neutral-border-strong);
}

.document-delivery-papers__chip--row {
  width: 100%;
  padding: 8px 10px;
  text-align: left;
}

.document-delivery-papers--section .document-delivery-papers__inner {
  width: 100%;
}
</style>
