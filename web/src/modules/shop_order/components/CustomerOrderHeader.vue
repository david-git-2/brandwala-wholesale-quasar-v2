<template>
  <div>
    <CatalogOrderProgressBar
      v-if="isVendorCatalog"
      variant="customer"
      :order="order"
    />

    <template v-else>
      <p v-if="metaLine" class="text-caption text-grey-7 q-mb-sm">{{ metaLine }}</p>
      <q-card flat bordered class="q-pa-sm bg-grey-1">
        <div class="row items-center justify-between no-wrap q-gutter-x-xs">
          <div class="col text-center">
            <q-badge
              unelevated
              :color="getStatusColor(normalizedStatus)"
              class="q-pa-xs text-weight-bold text-caption shadow-1 full-width justify-center status-badge"
            >
              <q-icon name="ph ph-clock text-white q-mr-xs" size="14px" />
              {{ formatStatusLabel(normalizedStatus) }}
            </q-badge>
          </div>

          <q-icon v-if="focusedSteps.next" name="ph ph-caret-right" color="grey-5" size="16px" />

          <div v-if="focusedSteps.next" class="col-auto">
            <q-chip dense outline color="grey-6" class="text-caption q-ma-none">
              Next: {{ formatStatusLabel(focusedSteps.next) }}
            </q-chip>
          </div>
        </div>
      </q-card>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { date } from 'quasar';
import { useI18n } from 'vue-i18n';
import { customerShopTypeI18nKey } from '../utils/catalogShop';
import {
  getCustomerCatalogStatusLabel,
  normalizeCatalogOrderStatus,
} from '../utils/catalogOrderStatus';
import CatalogOrderProgressBar from './CatalogOrderProgressBar.vue';

const props = defineProps<{
  order: any;
  statusSequence: string[];
  terminalStatuses: string[];
  normalizedStatus: string;
}>();

const { t } = useI18n();

const isVendorCatalog = computed(() => props.order?.shop_type_snapshot === 'vendor_catalog');

const metaLine = computed(() => {
  const parts: string[] = [];
  if (props.order?.created_at) {
    parts.push(`${t('shop_admin.placed_on')} ${formatDate(props.order.created_at)}`);
  }
  if (props.order?.shop_name) {
    parts.push(props.order.shop_name);
  }
  if (props.order?.shop_type_snapshot) {
    parts.push(t(customerShopTypeI18nKey(props.order.shop_type_snapshot)));
  }
  return parts.join(' · ');
});

const focusedSteps = computed(() => {
  const seq = props.statusSequence || [];
  const lookupStatus = normalizeCatalogOrderStatus(props.normalizedStatus);
  const idx = seq.indexOf(lookupStatus);
  if (idx === -1) {
    return { prev: null, next: null };
  }
  return {
    prev: idx > 0 ? seq[idx - 1] : null,
    next: idx < seq.length - 1 ? seq[idx + 1] : null,
  };
});

const formatDate = (dateStr?: string) => {
  if (!dateStr) return '';
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const formatStatusLabel = (st: string) => {
  if (props.order?.shop_type_snapshot === 'vendor_catalog') {
    return getCustomerCatalogStatusLabel(st);
  }
  switch (st) {
    case 'submitted':
      return 'Submitted';
    case 'costing_pending':
      return 'Costing Pending';
    case 'priced':
      return 'Priced';
    case 'countered':
      return 'Countered';
    case 'final_offered':
      return 'Final Offered';
    case 'confirmed':
      return 'Confirmed';
    case 'procuring':
      return 'Procuring';
    case 'ready_for_shipment':
      return 'Ready for shipment';
    case 'ordered':
      return 'Ready for shipment';
    case 'negotiating':
      return 'Negotiating';
    case 'placed':
      return 'Placed';
    case 'fulfilled':
      return 'Fulfilled';
    case 'processing':
      return 'Processing';
    case 'ready_for_pickup':
      return 'Ready for Pickup';
    case 'shipped':
      return 'Shipped';
    case 'delivered':
      return 'Delivered';
    case 'returned':
      return 'Returned';
    case 'cancelled':
      return 'Cancelled';
    case 'payment_received':
      return 'Payment Received';
    default:
      return st.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'costing_pending':
      return 'deep-orange-7';
    case 'negotiating':
    case 'countered':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'final_offered':
      return 'purple-7';
    case 'confirmed':
      return 'green-7';
    case 'procuring':
      return 'blue-9';
    case 'ready_for_shipment':
    case 'ordered':
      return 'indigo-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'ready_for_pickup':
      return 'indigo-7';
    case 'shipped':
      return 'light-blue-7';
    case 'delivered':
      return 'green-8';
    case 'returned':
      return 'deep-orange-8';
    case 'payment_received':
      return 'emerald-7';
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
};
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderHeader',
};
</script>

<style scoped>
.status-badge {
  border-radius: 999px;
  font-size: 12px;
}
</style>
