<script setup lang="ts">
import { useQuasar, copyToClipboard as quasarCopyToClipboard } from 'quasar';

const props = defineProps<{
  order: any;
}>();

const $q = useQuasar();

const copyToClipboard = (text: string | null | undefined, label: string) => {
  if (!text) return;
  quasarCopyToClipboard(text)
    .then(() => {
      $q.notify({
        type: 'positive',
        message: `${label} copied to clipboard`,
        timeout: 1500,
      });
    })
    .catch(() => {
      $q.notify({
        type: 'negative',
        message: `Failed to copy ${label.toLowerCase()}`,
        timeout: 1500,
      });
    });
};

const copyAllShippingDetails = () => {
  const o = props.order;
  if (!o) return;
  const parts = [];
  if (o.recipient_name) parts.push(`Name: ${o.recipient_name}`);
  if (o.recipient_phone) parts.push(`Phone: ${o.recipient_phone}`);
  if (o.shipping_address) parts.push(`Address: ${o.shipping_address}`);
  if (o.delivery_instructions) parts.push(`Instructions: ${o.delivery_instructions}`);

  copyToClipboard(parts.join('\n'), 'Shipping details');
};
</script>

<template>
  <q-card flat bordered class="details-card">
    <q-card-section class="q-px-lg q-py-md border-bottom">
      <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.shipping_details') }}</div>
    </q-card-section>

    <q-card-section class="q-px-lg q-py-md">
      <div class="text-body2 text-grey-8">
        <div class="text-weight-bold text-grey-9 row items-center justify-between">
          <span>{{ order.recipient_name }}</span>
          <q-btn
            flat
            dense
            round
            size="sm"
            icon="ph ph-copy"
            color="grey-6"
            @click="copyToClipboard(order.recipient_name, 'Recipient Name')"
          >
            <q-tooltip>Copy Name</q-tooltip>
          </q-btn>
        </div>

        <div class="row items-center justify-between q-mt-xs">
          <span>{{ order.recipient_phone }}</span>
          <q-btn
            flat
            dense
            round
            size="sm"
            icon="ph ph-copy"
            color="grey-6"
            @click="copyToClipboard(order.recipient_phone, 'Phone Number')"
          >
            <q-tooltip>Copy Phone</q-tooltip>
          </q-btn>
        </div>

        <div class="q-mt-sm text-grey-6 bg-grey-1 q-pa-sm rounded-borders relative-position">
          <div class="row items-start justify-between">
            <div class="col" style="white-space: pre-wrap">{{ order.shipping_address }}</div>
            <q-btn
              flat
              dense
              round
              size="sm"
              icon="ph ph-copy"
              color="grey-6"
              class="q-ml-xs"
              @click="copyToClipboard(order.shipping_address, 'Shipping Address')"
            >
              <q-tooltip>Copy Address</q-tooltip>
            </q-btn>
          </div>
        </div>

        <div class="q-mt-md">
          <q-btn
            outline
            dense
            size="sm"
            color="primary"
            icon="ph ph-copy"
            label="Copy All Details"
            class="full-width pill-btn"
            @click="copyAllShippingDetails"
          />
        </div>

        <div
          v-if="order.delivery_instructions"
          class="q-mt-sm q-pa-sm bg-blue-50 text-blue-9 text-caption rounded-borders"
          style="border: 1px solid #90caf9;"
        >
          <div class="text-weight-bold">{{ $t('shop_admin.delivery_instructions_notes') }}</div>
          <div style="white-space: pre-wrap">{{ order.delivery_instructions }}</div>
        </div>

        <div class="q-mt-md text-caption text-grey-5">
          Ordered by: {{ order.created_by_email }}
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<style scoped>
.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.pill-btn {
  border-radius: 8px;
}
</style>
