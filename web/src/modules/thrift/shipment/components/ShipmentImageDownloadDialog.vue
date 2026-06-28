<template>
  <q-dialog ref="dialogRef" persistent @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="min-width: 350px; border-radius: 12px;">
      <q-card-section class="q-pb-none">
        <div class="text-subtitle1 text-weight-bold text-grey-9">
          Download images
        </div>
        <div class="text-caption text-grey-7">
          {{ shipmentName }}
        </div>
      </q-card-section>

      <q-card-section class="q-py-md">
        <!-- Running Phase UI -->
        <div v-if="phase === 'listing'" class="column items-center q-py-md">
          <q-spinner color="primary" size="36px" />
          <div class="text-caption text-grey-7 q-mt-sm">Listing shipment images...</div>
        </div>

        <div v-else-if="phase === 'downloading'" class="column q-gutter-y-sm">
          <div class="row justify-between text-caption text-grey-8">
            <span>Downloading image {{ current + 1 }} of {{ total }}</span>
            <span class="text-weight-bold">{{ Math.round((current / total) * 100) }}%</span>
          </div>
          <q-linear-progress :value="current / total" color="primary" rounded />
          <div class="text-caption text-grey-6 ellipsis" v-if="currentBarcode">
            Current: {{ currentBarcode }}
          </div>
        </div>

        <div v-else-if="phase === 'zipping'" class="column items-center q-py-md">
          <q-spinner-gears color="secondary" size="36px" />
          <div class="text-caption text-grey-7 q-mt-sm">Creating zip folder archive...</div>
        </div>

        <!-- Done UI -->
        <div v-else-if="phase === 'done'" class="column q-gutter-y-sm">
          <div class="row items-center q-gutter-x-sm text-green-7 q-py-xs">
            <q-icon name="check_circle" size="24px" />
            <div class="text-weight-bold">Download completed successfully!</div>
          </div>
          <div class="text-body2 text-grey-8">
            {{ message }}
          </div>
          <div v-if="errors.length > 0" class="q-mt-sm border-t q-pt-xs">
            <div class="text-caption text-weight-bold text-red-7 q-mb-xs">
              Failed items ({{ errors.length }}):
            </div>
            <q-scroll-area style="height: 100px;" class="bg-grey-1 rounded-borders q-pa-xs">
              <div v-for="(err, idx) in errors" :key="idx" class="text-caption text-grey-8" style="font-size: 11px;">
                Barcode: {{ err.barcode }} - {{ err.message }}
              </div>
            </q-scroll-area>
          </div>
        </div>

        <!-- Cancelled UI -->
        <div v-else-if="phase === 'cancelled'" class="column items-center q-py-md text-orange-7">
          <q-icon name="cancel" size="36px" />
          <div class="text-subtitle2 text-weight-bold q-mt-sm">Download Cancelled</div>
          <div class="text-caption text-grey-6 q-mt-xs">Operation stopped by user</div>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pt-none">
        <q-btn
          color="grey-7"
          flat
          label="Cancel"
          v-if="phase !== 'done' && phase !== 'cancelled'"
          @click="cancelDownload"
        />
        <q-btn
          color="primary"
          label="Close"
          v-else
          @click="closeDialog"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useDialogPluginComponent, useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  downloadShipmentImagesToDevice,
  ShipmentDownloadCancelledError,
} from 'src/utils/shipmentImageDownloadClient';

const props = defineProps<{
  shipmentId: number;
  shipmentName: string;
}>();

defineEmits([
  ...useDialogPluginComponent.emits,
]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const $q = useQuasar();
const authStore = useAuthStore();

const phase = ref<'listing' | 'downloading' | 'zipping' | 'done' | 'cancelled'>('listing');
const current = ref(0);
const total = ref(0);
const currentBarcode = ref('');
const message = ref('');
const errors = ref<Array<{ barcode: string; message: string }>>([]);

const abortController = new AbortController();

async function startDownload() {
  if (!authStore.tenantId) return;
  try {
    const res = await downloadShipmentImagesToDevice(authStore.tenantId, props.shipmentId, {
      signal: abortController.signal,
      onProgress: (p) => {
        phase.value = p.phase;
        current.value = p.current;
        total.value = p.total;
        if (p.currentBarcode) {
          currentBarcode.value = p.currentBarcode;
        }
      },
    });
    message.value = res.message || '';
    errors.value = res.errors.map((e) => ({ barcode: e.barcode, message: e.message }));
  } catch (err: unknown) {
    if (err instanceof ShipmentDownloadCancelledError) {
      phase.value = 'cancelled';
    } else {
      $q.notify({ type: 'negative', message: (err as Error).message || 'Download failed' });
      phase.value = 'cancelled';
    }
  }
}

function cancelDownload() {
  abortController.abort();
  phase.value = 'cancelled';
}

function closeDialog() {
  onDialogOK();
}

onMounted(() => {
  void startDownload();
});
</script>

<style scoped>
.border-t {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}
</style>
