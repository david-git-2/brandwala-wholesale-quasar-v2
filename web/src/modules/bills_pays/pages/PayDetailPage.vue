<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center justify-between q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Payments" @click="goBack" />
      <q-btn
        v-if="pay && !pay.voided_at"
        outline
        dense
        no-caps
        color="negative"
        label="Void receipt"
        :loading="voidMutation.isPending.value"
        @click="openVoidDialog"
      />
    </div>

    <div v-if="detailQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>
    <div v-else-if="pay" class="col overflow-auto">
      <div class="pay-form-card q-pa-md q-gutter-y-sm">
        <div class="text-h6 text-weight-bold">Pay #{{ pay.id }}</div>
        <div class="text-caption text-grey-7">{{ pay.payment_date }} · {{ pay.source }}</div>
        <div v-if="pay.voided_at" class="text-negative text-weight-medium">Voided</div>
        <div>Profile: {{ pay.profile_name || '—' }}</div>
        <div>Amount: {{ formatAmountBdt(pay.amount) }}</div>
        <div v-if="pay.unallocated_amount > 0">Leftover: {{ formatAmountBdt(pay.unallocated_amount) }}</div>
        <div v-if="pay.reference">Ref: {{ pay.reference }}</div>
        <div v-if="pay.note">Note: {{ pay.note }}</div>

        <div v-if="pay.instruments.length" class="q-mt-md">
          <div class="text-weight-medium">Instruments</div>
          <div v-for="inst in pay.instruments" :key="inst.id" class="text-body2">
            {{ inst.payment_method_code }} — {{ formatAmountBdt(inst.amount) }}
          </div>
        </div>

        <div v-if="pay.allocations.length" class="q-mt-md">
          <div class="text-weight-medium">Allocations</div>
          <div v-for="alloc in pay.allocations" :key="alloc.id" class="text-body2">
            {{ alloc.invoice_no || alloc.global_invoice_id }} — {{ formatAmountBdt(alloc.amount) }}
          </div>
        </div>
      </div>
    </div>

    <q-dialog v-model="voidDialogOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-weight-bold">Void receipt?</q-card-section>
        <q-card-section>
          <q-input v-model="voidReason" outlined dense label="Reason" type="textarea" autogrow />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn unelevated no-caps color="negative" label="Void" @click="confirmVoid" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { paysRepository } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { useVoidPayMutation } from '../composables/useVoidPayMutation';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const voidMutation = useVoidPayMutation();

const payId = computed(() => {
  const raw = route.params.payId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);

const detailQuery = useQuery({
  queryKey: computed(() => paysQueryKeys.detail(payId.value)),
  queryFn: () => paysRepository.getPayById(payId.value!),
  enabled: computed(() => payId.value != null),
});

const pay = computed(() => detailQuery.data.value);

const voidDialogOpen = ref(false);
const voidReason = ref('Corrected entry');

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({ name: 'app-payments-page', params: tenantSlug ? { tenantSlug } : {} });
};

const openVoidDialog = () => {
  voidReason.value = 'Corrected entry';
  voidDialogOpen.value = true;
};

const confirmVoid = async () => {
  if (!payId.value || !voidReason.value.trim()) return;
  await voidMutation.mutateAsync({
    tenantId: tenantId.value,
    paymentId: payId.value,
    reason: voidReason.value.trim(),
  });
  voidDialogOpen.value = false;
  goBack();
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.pay-form-card {
  max-width: 720px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: 8px;
}
</style>
