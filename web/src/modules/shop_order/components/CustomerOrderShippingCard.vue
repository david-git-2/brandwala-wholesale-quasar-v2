<template>
  <q-card flat bordered class="details-card">
    <q-expansion-item
      v-if="collapsible"
      v-model="expanded"
      dense
      expand-separator
      class="shipping-expansion"
      :label="shipToLabel"
      header-class="text-body2 text-weight-medium text-grey-9"
    >
      <q-card-section class="q-px-md q-pb-md text-body2 text-grey-8">
        <ShippingDetailsBody :order="order" />
      </q-card-section>
    </q-expansion-item>

    <template v-else>
      <q-card-section class="q-px-md q-py-sm border-bottom">
        <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.shipping_details') }}</div>
      </q-card-section>

      <q-card-section class="q-px-md q-py-md text-body2 text-grey-8">
        <ShippingDetailsBody :order="order" />
      </q-card-section>
    </template>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ShippingDetailsBody from './CustomerOrderShippingDetailsBody.vue';

const props = withDefaults(
  defineProps<{
    order: any;
    collapsible?: boolean;
    defaultExpanded?: boolean;
  }>(),
  {
    collapsible: false,
    defaultExpanded: false,
  },
);

const { t } = useI18n();
const expanded = ref(props.defaultExpanded);

const shipToLabel = computed(() => {
  const name = props.order?.recipient_name;
  if (!name) {
    return t('shop_admin.shipping_details');
  }
  return t('shop_admin.ship_to', { name });
});
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderShippingCard',
};
</script>

<style scoped>
.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.shipping-expansion :deep(.q-item) {
  min-height: 48px;
  padding-left: 16px;
  padding-right: 12px;
}
</style>
