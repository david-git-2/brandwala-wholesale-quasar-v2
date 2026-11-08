<template>
  <div class="row q-col-gutter-md">
    <div class="col-12 col-sm-6">
      <div class="text-overline text-grey-7">From</div>
      <div class="text-subtitle2 text-weight-medium">{{ fromName }}</div>
      <div v-if="fromEmail" class="text-caption text-grey-7">{{ fromEmail }}</div>
      <div v-if="fromAddress" class="text-caption text-grey-7 whitespace-pre-line">
        {{ fromAddress }}
      </div>
    </div>
    <div class="col-12 col-sm-6">
      <div class="text-overline text-grey-7">To</div>
      <div class="text-subtitle2 text-weight-medium">{{ toName }}</div>
      <div v-if="toEmail" class="text-caption text-grey-7">{{ toEmail }}</div>
      <div v-if="toAddress" class="text-caption text-grey-7 whitespace-pre-line">
        {{ toAddress }}
      </div>
      <div v-if="toPhone" class="text-caption text-grey-7">{{ toPhone }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';

const props = defineProps<{
  bill: GlobalInvoiceDetail;
}>();

const fromName = computed(
  () => props.bill.from_profile?.name || '—',
);
const fromEmail = computed(() => props.bill.from_profile?.email ?? null);
const fromAddress = computed(() => props.bill.from_profile?.address ?? null);

const toName = computed(
  () =>
    props.bill.to_profile?.name
    || props.bill.profiles?.name
    || props.bill.recipient_name
    || '—',
);
const toEmail = computed(
  () => props.bill.to_profile?.email ?? props.bill.profiles?.email ?? null,
);
const toAddress = computed(
  () =>
    props.bill.to_profile?.address
    ?? props.bill.profiles?.address
    ?? props.bill.recipient_address
    ?? null,
);
const toPhone = computed(
  () => props.bill.to_profile?.phone ?? props.bill.profiles?.phone ?? props.bill.recipient_phone ?? null,
);
</script>
