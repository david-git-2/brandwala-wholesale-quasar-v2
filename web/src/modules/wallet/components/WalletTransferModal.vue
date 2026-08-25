<template>
  <q-dialog v-model="isOpen" persistent transition-show="scale" transition-hide="scale">
    <q-card style="width: 480px; max-width: 95vw" class="rounded-borders">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="32px" class="bg-primary-soft text-primary bw-tabular text-weight-bold">
            <q-icon name="ph ph-arrows-left-right" size="18px" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bold">Bucket Balance Transfer</div>
            <div class="text-caption text-grey-7">
              {{ entityName || entityType.toUpperCase() }} (#{{ entityId }})
            </div>
          </div>
        </div>
        <q-btn v-close-popup flat round dense icon="ph ph-x" color="grey-7" />
      </q-card-section>

      <q-card-section class="q-pt-md">
        <q-form class="q-gutter-y-md" @submit.prevent="handleTransfer">
          <!-- From Bucket Selector -->
          <div class="row q-col-gutter-sm">
            <div class="col-6">
              <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">Source Bucket</label>
              <q-select
                v-model="fromBucket"
                outlined
                dense
                emit-value
                map-options
                :options="bucketOptions"
                class="gentle-select"
              />
            </div>
            <div class="col-6">
              <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">Target Bucket</label>
              <q-select
                v-model="toBucket"
                outlined
                dense
                emit-value
                map-options
                :options="bucketOptions"
                class="gentle-select"
              />
            </div>
          </div>

          <!-- Quick Preset Buttons -->
          <div class="quick-presets row q-gutter-xs">
            <q-btn
              flat
              dense
              no-caps
              size="xs"
              class="bg-grey-2 text-grey-9 q-px-sm rounded-borders"
              label="Unlock Accrual (Pending → Available)"
              @click="setPreset('pending', 'available')"
            />
            <q-btn
              flat
              dense
              no-caps
              size="xs"
              class="bg-grey-2 text-grey-9 q-px-sm rounded-borders"
              label="Lock for Payout (Available → Locked)"
              @click="setPreset('available', 'locked')"
            />
          </div>

          <!-- Transfer Amount -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Transfer Amount (BDT)
            </label>
            <q-input
              v-model.number="amount"
              outlined
              dense
              type="number"
              step="0.01"
              min="0.01"
              placeholder="0.00"
              :rules="[(val) => (val && val > 0) || 'Enter amount greater than zero']"
            >
              <template #append>
                <span class="text-caption text-grey-6 bw-tabular">BDT</span>
              </template>
            </q-input>
          </div>

          <!-- Audit Notes -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Reason / Audit Notes (Optional)
            </label>
            <q-input
              v-model="notes"
              outlined
              dense
              type="textarea"
              rows="2"
              placeholder="e.g., Courier remittance confirmed or merchant payout hold released"
            />
          </div>

          <!-- Action Buttons -->
          <div class="row items-center justify-end q-gutter-x-sm q-pt-sm">
            <q-btn v-close-popup flat label="Cancel" no-caps color="grey-7" />
            <q-btn
              type="submit"
              unelevated
              color="primary"
              label="Execute Transfer"
              no-caps
              :loading="isSubmitting"
              class="q-px-md font-weight-bold"
            />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useQuasar } from 'quasar';
import { useWalletAccounts } from '../composables/useWalletAccounts';
import type { UniversalWalletEntityType, WalletBucket } from '../types';

const props = defineProps<{
  modelValue: boolean;
  entityType: UniversalWalletEntityType;
  entityId: number;
  entityName?: string;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'transferred'): void;
}>();

const $q = useQuasar();
const { transferBalance } = useWalletAccounts();

const fromBucket = ref<WalletBucket>('pending');
const toBucket = ref<WalletBucket>('available');
const amount = ref<number | null>(null);
const notes = ref<string>('');
const isSubmitting = ref<boolean>(false);

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const bucketOptions = [
  { label: 'Pending Balance', value: 'pending' },
  { label: 'Available Balance', value: 'available' },
  { label: 'Locked Balance', value: 'locked' },
];

function setPreset(from: WalletBucket, to: WalletBucket) {
  fromBucket.value = from;
  toBucket.value = to;
}

async function handleTransfer() {
  if (!amount.value || amount.value <= 0) {
    $q.notify({ type: 'warning', message: 'Please enter a valid transfer amount.' });
    return;
  }
  if (fromBucket.value === toBucket.value) {
    $q.notify({ type: 'warning', message: 'Source and target buckets must be different.' });
    return;
  }

  isSubmitting.value = true;
  try {
    const payload: Parameters<typeof transferBalance>[0] = {
      entity_type: props.entityType,
      entity_id: props.entityId,
      from_bucket: fromBucket.value,
      to_bucket: toBucket.value,
      amount: amount.value,
    };
    if (notes.value.trim()) {
      payload.notes = notes.value.trim();
    }
    await transferBalance(payload);

    $q.notify({
      type: 'positive',
      message: `Successfully transferred ৳${amount.value.toFixed(2)} from ${fromBucket.value} to ${toBucket.value}.`,
    });

    emit('transferred');
    isOpen.value = false;
    // Reset form
    amount.value = null;
    notes.value = '';
  } catch (err: any) {
    $q.notify({
      type: 'negative',
      message: err?.message || 'Failed to complete bucket balance transfer.',
    });
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<style scoped>
.bg-primary-soft {
  background: rgba(var(--q-primary-rgb, 59, 130, 246), 0.08) !important;
}
</style>
