<template>
  <q-drawer
    v-model="isOpen"
    side="right"
    overlay
    elevated
    :width="480"
    class="catalog-backlog-drawer bg-white"
  >
    <div class="column full-height">
      <!-- Header -->
      <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
        <div>
          <div class="text-subtitle1 text-weight-bold row items-center">
            <q-icon name="ph ph-tray" class="q-mr-xs text-primary" size="20px" />
            Customer Order Backlog
          </div>
          <div class="text-caption text-grey-7">
            Unfulfilled demand for this billing profile
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense @click="isOpen = false" />
      </div>

      <q-separator />

      <!-- Body / List -->
      <div class="col scroll q-pa-md">
        <div v-if="loading" class="q-gutter-y-md">
          <q-card v-for="n in 3" :key="n" flat bordered class="q-pa-sm">
            <q-skeleton type="text" width="60%" />
            <q-skeleton type="text" width="40%" />
          </q-card>
        </div>

        <div v-else-if="items.length === 0" class="text-center text-grey-6 q-pa-xl">
          <q-icon name="ph ph-check-circle" size="48px" class="q-mb-sm text-positive" />
          <div class="text-body1 text-weight-medium">No open backlog</div>
          <div class="text-caption">All previous demand for this billing profile is fully ordered or fulfilled.</div>
        </div>

        <template v-else>
          <div class="q-gutter-y-sm">
            <q-card
              v-for="item in items"
              :key="item.id"
              flat
              bordered
              class="backlog-item-card"
            >
              <q-card-section class="q-pa-sm row items-center q-col-gutter-sm">
                <div class="col-auto">
                  <q-avatar square size="42px" class="bg-grey-2 rounded-borders">
                    <img v-if="item.image_url" :src="item.image_url" :alt="item.name" />
                    <q-icon v-else name="ph ph-package" color="grey-6" />
                  </q-avatar>
                </div>

                <div class="col">
                  <div class="text-subtitle2 text-weight-bold ellipsis">{{ item.name }}</div>
                  <div class="row items-center q-gutter-x-xs text-caption text-grey-7">
                    <span v-if="item.product_code">SKU: {{ item.product_code }}</span>
                    <span v-if="item.product_code && item.barcode">•</span>
                    <span v-if="item.barcode">BC: {{ item.barcode }}</span>
                  </div>
                </div>

                <div class="col-auto text-right">
                  <q-chip dense color="orange-9" text-color="white" class="text-weight-bold">
                    Open: {{ item.open_quantity }}
                  </q-chip>
                  <div class="text-caption text-grey-6">
                    Req: {{ item.requested_quantity }} | Fulfilled: {{ item.fulfilled_quantity }}
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </template>
      </div>

      <q-separator />

      <!-- Footer Actions -->
      <div class="q-pa-md bg-grey-1 row items-center justify-end">
        <q-btn
          flat
          label="Close"
          color="grey-8"
          no-caps
          @click="isOpen = false"
        />
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { shopOrderRepository } from '../repositories/shopOrderRepository';

export interface BacklogItem {
  id: number;
  tenant_id: number;
  billing_profile_id: number;
  product_id: number;
  order_id: number | null;
  order_item_id: number | null;
  requested_quantity: number;
  fulfilled_quantity: number;
  open_quantity: number;
  backlog_status: string;
  name: string;
  image_url: string | null;
  barcode: string | null;
  product_code: string | null;
  created_at: string;
}

const props = defineProps<{
  modelValue: boolean;
  tenantId: number;
  billingProfileId: number | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const items = ref<BacklogItem[]>([]);
const loading = ref(false);

const loadBacklogItems = async () => {
  if (!props.tenantId || !props.billingProfileId) {
    items.value = [];
    return;
  }
  loading.value = true;
  try {
    const data = await shopOrderRepository.listCustomerOrderBacklogItems(
      props.tenantId,
      props.billingProfileId,
    );
    items.value = data || [];
  } catch (err) {
    console.error('Failed to load customer backlog items:', err);
    items.value = [];
  } finally {
    loading.value = false;
  }
};

watch(
  () => props.modelValue,
  (visible) => {
    if (visible) {
      void loadBacklogItems();
    }
  },
);
</script>

<script lang="ts">
export default {
  name: 'CatalogBacklogDrawer',
};
</script>

<style scoped>
.backlog-item-card {
  border-radius: 8px;
}
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
</style>
