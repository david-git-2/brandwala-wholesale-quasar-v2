<template>
  <div class="batch-list-header shrink-0">
    <div class="row items-center q-col-gutter-xs no-wrap">
      <div v-if="showBack" class="col-auto">
        <q-btn icon="ph ph-arrow-left" flat round dense size="sm" color="grey-8" @click="emit('back')">
          <q-tooltip>Back</q-tooltip>
        </q-btn>
      </div>

      <div class="col text-subtitle1 text-weight-bold text-grey-9 ellipsis">
        Batch Code
        <span v-if="shipmentLabel" class="text-weight-medium text-grey-7"> — {{ shipmentLabel }}</span>
      </div>

      <div v-if="showDelete" class="col-auto">
        <q-btn
          flat
          dense
          no-caps
          color="negative"
          icon="ph ph-trash"
          label="Delete file"
          class="rounded-sq-btn"
          :loading="isDeletingList"
          :disable="isListLoading"
          @click="onDeleteFile"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import { type BatchCodeListRow } from '../repositories/batchCodeRepository';
import { useDeleteBatchCodeListMutation } from '../composables/useBatchCodeMutations';
import { useBatchCodeListQuery } from '../composables/useBatchCodeQueries';

const props = withDefaults(
  defineProps<{
    listId: number;
    parentTenantId: number;
    showBack?: boolean;
    showDelete?: boolean;
  }>(),
  {
    showBack: false,
    showDelete: false,
  },
);

const emit = defineEmits<{
  back: [];
  updated: [BatchCodeListRow];
  deleted: [];
  'load-error': [message: string];
}>();

const listIdRef = computed(() => props.listId);
const listQuery = useBatchCodeListQuery(listIdRef);
const deleteListMutation = useDeleteBatchCodeListMutation();

const isListLoading = computed(
  () => listQuery.isPending.value && listQuery.isFetching.value,
);
const isDeletingList = computed(() => deleteListMutation.isPending.value);
const listMeta = computed(() => listQuery.data.value ?? null);

const shipmentLabel = computed(() => {
  const shipment = listMeta.value?.shipment;
  if (!shipment) return '';
  const idPart =
    shipment.tenant_shipment_id != null ? `#${shipment.tenant_shipment_id}` : `#${shipment.id}`;
  return `${shipment.name} ${idPart}`;
});

watch(
  listMeta,
  (row) => {
    if (row) emit('updated', row);
  },
  { immediate: true },
);

watch(
  () => listQuery.error.value,
  (error) => {
    if (error) {
      emit('load-error', (error as Error).message || 'Failed to load batch list.');
    }
  },
  { immediate: true },
);

const onDeleteFile = async () => {
  if (!listMeta.value) return;

  const lineCount = listMeta.value.batch_code_items?.[0]?.count ?? 0;
  const lineNote =
    lineCount > 0
      ? ` This will also delete ${lineCount} line${lineCount === 1 ? '' : 's'}.`
      : '';

  const ok = await requestConfirmation(
    `Delete batch code for ${shipmentLabel.value}?${lineNote} This cannot be undone.`,
    'Delete batch file',
    'Delete',
  );
  if (!ok) return;

  try {
    await deleteListMutation.mutateAsync({
      listId: props.listId,
      parentTenantId: props.parentTenantId,
      shipmentId: listMeta.value.shipment_id,
    });
    showSuccessNotification('Batch file deleted');
    emit('deleted');
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to delete batch file.');
  }
};
</script>

<style scoped>
.batch-list-header {
  padding: 2px 4px 0;
}
</style>
