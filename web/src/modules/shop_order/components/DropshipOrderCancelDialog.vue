<script setup lang="ts">
import { ref } from 'vue';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { showErrorNotification, showSuccessNotification, parseSupabaseError } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  orderId: number;
  orderNo: string;
  hasInvoice?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'cancelled'): void;
}>();

const reason = ref('');
const loading = ref(false);

const close = () => emit('update:modelValue', false);

const confirmCancel = async () => {
  loading.value = true;
  try {
    const result = await shopOrderRepository.cancelShopOrderDropship(
      props.orderId,
      reason.value.trim() || null,
    );
    const released = result.restock_summary?.pick_rows_released ?? 0;
    showSuccessNotification(
      released > 0
        ? `Order cancelled. ${released} pick hold(s) released back to sellable stock.`
        : 'Order cancelled.',
    );
    emit('cancelled');
    close();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to cancel order'));
  } finally {
    loading.value = false;
  }
};
</script>

<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: min(480px, 92vw)">
      <q-card-section>
        <div class="text-h6">Cancel this order?</div>
        <div class="text-body2 q-mt-sm">
          Order #{{ orderNo }} will be marked cancelled. Any processing picks will be released back to
          sellable stock.
        </div>
        <q-banner v-if="hasInvoice" dense rounded class="bg-orange-1 text-orange-10 q-mt-md">
          This order has an invoice. Cancelling will clean up invoice and wallet rows where applicable.
        </q-banner>
      </q-card-section>

      <q-card-section class="q-pt-none">
        <q-input
          v-model="reason"
          type="textarea"
          autogrow
          outlined
          dense
          label="Reason (optional)"
        />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat no-caps label="Keep order" @click="close" />
        <q-btn
          color="negative"
          unelevated
          no-caps
          label="Cancel order"
          :loading="loading"
          @click="confirmCancel"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>
