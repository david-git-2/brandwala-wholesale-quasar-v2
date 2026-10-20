<template>
  <q-dialog ref="dialogRef" persistent @hide="onDialogHide">
    <q-card flat bordered class="q-dialog-plugin" style="min-width: 360px; max-width: 420px">
      <q-card-section class="q-pb-sm">
        <div class="text-subtitle2 text-weight-bold text-grey-9">Exporting Excel</div>
        <div class="text-caption text-grey-7 q-mt-2xs">
          Large shipments can take a minute. Keep this tab open.
        </div>
      </q-card-section>

      <q-card-section class="q-pt-none q-pb-md">
        <div v-if="phase === 'running'" class="column q-gutter-y-sm">
          <div class="row items-center justify-between text-caption text-grey-8">
            <span class="ellipsis col" style="min-width: 0">{{ message }}</span>
            <span class="text-weight-bold q-ml-sm">{{ percentLabel }}</span>
          </div>
          <q-linear-progress :value="progress" color="primary" rounded />
        </div>

        <div v-else-if="phase === 'done'" class="row items-center q-gutter-x-sm text-positive">
          <q-icon name="ph ph-check-circle" size="22px" />
          <span class="text-body2 text-weight-medium">File ready</span>
        </div>

        <div v-else class="column q-gutter-y-xs">
          <div class="row items-center q-gutter-x-sm text-negative">
            <q-icon name="ph ph-warning-circle" size="22px" />
            <span class="text-body2 text-weight-medium">Export failed</span>
          </div>
          <div class="text-caption text-grey-8">{{ errorMessage }}</div>
        </div>
      </q-card-section>

      <q-card-actions v-if="phase === 'error'" align="right" class="q-pt-none">
        <q-btn flat no-caps color="primary" label="Close" @click="onDialogOK" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useDialogPluginComponent } from 'quasar';

export type ShipmentExcelExportProgress = {
  message: string;
  value: number;
};

const props = defineProps<{
  task: (onProgress: (progress: ShipmentExcelExportProgress) => void) => Promise<void>;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const phase = ref<'running' | 'done' | 'error'>('running');
const message = ref('Preparing export…');
const progress = ref(0);
const errorMessage = ref('');

const percentLabel = computed(() => `${Math.round(progress.value * 100)}%`);

onMounted(() => {
  void (async () => {
    try {
      await props.task((p) => {
        message.value = p.message;
        progress.value = Math.min(1, Math.max(0, p.value));
      });
      progress.value = 1;
      message.value = 'Done';
      phase.value = 'done';
      window.setTimeout(() => onDialogOK(), 500);
    } catch (err: unknown) {
      phase.value = 'error';
      errorMessage.value = err instanceof Error ? err.message : 'Failed to generate Excel.';
    }
  })();
});
</script>
