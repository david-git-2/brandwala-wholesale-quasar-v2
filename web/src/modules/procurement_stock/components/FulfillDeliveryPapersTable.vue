<template>
  <section class="fulfill-delivery-papers">
    <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm">Delivery papers</div>
    <q-markup-table flat bordered dense class="fulfill-delivery-papers__table">
      <thead>
        <tr>
          <th class="text-left">Paper</th>
          <th class="text-left">Status</th>
          <th class="text-left">Order / document</th>
          <th class="text-left">Profile</th>
          <th class="text-right">Lines</th>
          <th class="text-left">Updated</th>
          <th class="text-right">Open</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="loading && papers.length === 0">
          <td colspan="7" class="text-center text-grey-7 q-py-md">
            <q-spinner-dots size="24px" color="primary" />
          </td>
        </tr>
        <tr v-else-if="papers.length === 0">
          <td colspan="7" class="text-center text-grey-7 q-py-md text-caption">
            No delivery papers for this tab yet.
          </td>
        </tr>
        <tr
          v-for="paper in papers"
          :key="paper.id"
          class="fulfill-delivery-papers__row cursor-pointer"
          @click="emit('open-paper', paper)"
        >
          <td class="font-mono text-weight-medium">DP-{{ paper.id }}</td>
          <td>
            <TfStatusBadge :status="paper.status" />
          </td>
          <td class="fulfill-delivery-papers__doc min-width-0">
            <div class="ellipsis text-weight-medium">{{ documentPrimaryLabel(paper) }}</div>
            <div class="text-caption text-grey-7 font-mono ellipsis">{{ documentIdLabel(paper) }}</div>
          </td>
          <td class="ellipsis">{{ paper.profile_name || '—' }}</td>
          <td class="text-right font-mono">{{ paper.line_count }}</td>
          <td class="text-caption text-grey-8">{{ formatUpdated(paper.updated_at) }}</td>
          <td class="text-right">
            <q-btn flat dense round icon="ph ph-arrow-square-out" color="grey-8" @click.stop="emit('open-paper', paper)" />
          </td>
        </tr>
      </tbody>
    </q-markup-table>
  </section>
</template>

<script setup lang="ts">
import { date } from 'quasar';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import type { FulfillDeliveryPaperListItem } from '../repositories/procurementDemandRepository';

defineProps<{
  papers: FulfillDeliveryPaperListItem[];
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'open-paper', paper: FulfillDeliveryPaperListItem): void;
}>();

const documentPrimaryLabel = (paper: FulfillDeliveryPaperListItem) => {
  if (paper.source_type === 'shop_order') {
    return paper.shop_order_no || `Order #${paper.source_id}`;
  }
  return paper.document_name || `Costing file #${paper.source_id}`;
};

const documentIdLabel = (paper: FulfillDeliveryPaperListItem) => {
  if (paper.source_type === 'shop_order') {
    return `Order ID ${paper.source_id}`;
  }
  return `File ID ${paper.source_id}`;
};

const formatUpdated = (value: string) => date.formatDate(value, 'D MMM YYYY, h:mm A');
</script>

<style scoped>
.fulfill-delivery-papers__table {
  width: 100%;
}

.fulfill-delivery-papers__row:hover {
  background: rgba(0, 0, 0, 0.03);
}

.fulfill-delivery-papers__doc {
  max-width: 220px;
}
</style>
