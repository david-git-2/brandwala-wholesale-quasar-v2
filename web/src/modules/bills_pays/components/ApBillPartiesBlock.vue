<template>
  <div class="row q-col-gutter-md">
    <div v-if="showCounterparty" class="col-12 col-sm-6">
      <div class="text-overline text-grey-7">{{ counterpartyLabel }}</div>
      <div class="text-subtitle2 text-weight-medium">{{ counterpartyName }}</div>
      <div v-if="counterpartyEmail" class="text-caption text-grey-7">{{ counterpartyEmail }}</div>
      <div v-if="counterpartyAddress" class="text-caption text-grey-7 whitespace-pre-line">
        {{ counterpartyAddress }}
      </div>
    </div>
    <div :class="showCounterparty ? 'col-12 col-sm-6' : 'col-12'">
      <div class="text-overline text-grey-7">{{ tenantLabel }}</div>
      <div class="text-subtitle2 text-weight-medium">{{ tenantName }}</div>
      <div class="text-caption text-grey-7 q-mt-xs">Amount is paid out by the tenant.</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { toRef, type Ref } from 'vue';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import { useApBillParties } from '../composables/useApBillParties';

const props = defineProps<{
  bill: GlobalInvoiceDetail;
}>();

const billRef = toRef(props, 'bill') as Ref<GlobalInvoiceDetail | undefined>;

const {
  tenantName,
  counterpartyName,
  counterpartyAddress,
  counterpartyEmail,
  showCounterparty,
  counterpartyLabel,
  tenantLabel,
} = useApBillParties(billRef);
</script>
