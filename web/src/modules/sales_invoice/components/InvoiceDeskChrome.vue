<script setup lang="ts">
defineProps<{
  invoiceNo?: string | null;
  typeChipLabel?: string;
  statusChipLabel?: string;
  statusChipColor?: string;
  statusChipTextColor?: string;
  paymentChipLabel?: string;
  paymentChipColor?: string;
  paymentChipTextColor?: string;
  showPaymentChip?: boolean;
  dueLabel?: string | null;
  validationReasons?: string[];
}>();
</script>

<template>
  <div class="invoice-desk-chrome-wrap">
    <q-banner
      v-if="validationReasons?.length"
      dense
      rounded
      class="invoice-desk-validation-banner bg-amber-1 text-amber-10 q-mb-xs"
    >
      <div class="text-weight-bold q-mb-xs">Complete required fields to save:</div>
      <ul class="q-my-none q-pl-md">
        <li v-for="(reason, idx) in validationReasons" :key="idx">{{ reason }}</li>
      </ul>
    </q-banner>

    <header class="invoice-desk-chrome">
      <div class="invoice-desk-chrome__left">
        <span class="invoice-desk-chrome__title">Invoice</span>
        <slot name="type" />
        <q-badge
          v-if="typeChipLabel && !$slots.type"
          outline
          color="primary"
          class="text-weight-bold q-px-sm"
        >
          {{ typeChipLabel }}
        </q-badge>
        <span v-if="invoiceNo" class="text-caption text-weight-medium text-grey-8">
          {{ invoiceNo }}
        </span>
        <q-badge
          v-if="statusChipLabel"
          :color="statusChipColor || 'grey-2'"
          :text-color="statusChipTextColor || 'grey-9'"
          class="text-weight-bold q-px-sm"
        >
          {{ statusChipLabel }}
        </q-badge>
        <q-badge
          v-if="showPaymentChip && paymentChipLabel"
          :color="paymentChipColor || 'grey-2'"
          :text-color="paymentChipTextColor || 'grey-9'"
          class="text-weight-bold q-px-sm text-capitalize"
        >
          {{ paymentChipLabel }}
        </q-badge>
        <span v-if="dueLabel" class="text-caption text-grey-7">{{ dueLabel }}</span>
      </div>

      <div class="invoice-desk-chrome__actions">
        <slot name="secondary" />
        <slot name="primary" />
        <slot name="overflow" />
      </div>
    </header>
  </div>
</template>

<style scoped lang="scss">
@import '../styles/invoice-desk.scss';
</style>
