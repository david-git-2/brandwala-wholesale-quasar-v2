<template>
  <div class="demand-buy-card__main col min-width-0">
    <div class="demand-buy-card__identity">
      <div class="demand-buy-card__name">{{ item.name }}</div>
      <div v-if="item.brand" class="demand-buy-card__brand">{{ item.brand }}</div>
    </div>
    <div class="demand-buy-chip-groups">
      <div v-if="item.product_code || item.barcode" class="demand-buy-chip-group">
        <q-chip
          v-if="item.product_code"
          square
          class="demand-buy-chip demand-buy-chip--code font-mono"
          icon="ph ph-hash"
          clickable
          :title="`Copy SKU ${item.product_code}`"
          @click="emit('copy-sku')"
        >
          <span class="ellipsis">{{ item.product_code }}</span>
        </q-chip>
        <q-chip
          v-if="item.barcode"
          square
          class="demand-buy-chip demand-buy-chip--code font-mono"
          icon="ph ph-barcode"
          clickable
          :title="`Copy barcode ${item.barcode}`"
          @click="emit('copy-barcode')"
        >
          <span class="ellipsis">{{ item.barcode }}</span>
        </q-chip>
      </div>
      <div class="demand-buy-chip-group">
        <q-chip
          square
          class="demand-buy-chip demand-buy-chip--source"
          :class="
            group.document_type === 'shop_order'
              ? 'demand-buy-chip--source-shop'
              : 'demand-buy-chip--source-costing'
          "
          :icon="sourceChipIcon"
        >
          <span class="ellipsis">{{ groupSourceChip }}</span>
        </q-chip>
        <q-chip
          v-if="groupDocChip"
          square
          class="demand-buy-chip demand-buy-chip--doc"
          :icon="docChipIcon"
          :title="groupDocChip"
        >
          <span class="ellipsis">{{ groupDocChip }}</span>
        </q-chip>
      </div>
      <div
        v-if="group.profile_name || group.customer_group_name"
        class="demand-buy-chip-group"
      >
        <q-chip
          v-if="group.profile_name"
          square
          icon="ph ph-user"
          class="demand-buy-chip demand-buy-chip--profile"
          :title="group.profile_name"
        >
          <span class="ellipsis">{{ group.profile_name }}</span>
        </q-chip>
        <q-chip
          v-if="group.customer_group_name"
          square
          icon="ph ph-users-three"
          class="demand-buy-chip demand-buy-chip--group"
          :title="group.customer_group_name"
        >
          <span class="ellipsis">{{ group.customer_group_name }}</span>
        </q-chip>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ProcurementDemandGroup, ProcurementDemandItem } from '../repositories/procurementDemandRepository';

const props = defineProps<{
  item: ProcurementDemandItem;
  group: ProcurementDemandGroup;
  groupSourceChip: string;
  groupDocChip: string;
}>();

const sourceChipIcon = computed(() =>
  props.group.document_type === 'shop_order' ? 'ph ph-storefront' : 'ph ph-file-text',
);

const docChipIcon = computed(() =>
  props.group.document_type === 'shop_order' ? 'ph ph-receipt' : 'ph ph-clipboard-text',
);

const emit = defineEmits<{
  'copy-sku': [];
  'copy-barcode': [];
}>();
</script>
