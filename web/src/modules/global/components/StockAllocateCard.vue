<template>
  <q-card flat bordered class="allocate-card">
    <q-card-section class="allocate-card__header column items-center text-center">
      <SmartImage
        class="allocate-card__image"
        :src="stock.image_url"
        :alt="stock.name"
        :product-id="stock.product_id"
        :enable-edit="false"
      />
      <div
        class="text-subtitle2 text-weight-medium q-mt-sm full-width"
        style="word-break: break-word"
      >
        {{ stock.name }}
      </div>
      <div class="text-caption text-grey-8 q-mt-xs">
        Global pool: <span class="text-weight-bold text-primary">{{ stock.excellent_qty }}</span>
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section class="allocate-card__children q-pa-sm">
      <div
        v-for="child in childTenants"
        :key="child.id"
        class="row items-center q-col-gutter-sm q-mb-sm"
      >
        <div class="col text-body2 ellipsis">{{ child.name }}</div>
        <div class="col-auto" style="width: 88px">
          <q-input
            :model-value="quantities[child.id] ?? 0"
            type="number"
            dense
            filled
            min="0"
            class="soft-input allocate-card__qty-input"
            input-class="text-center"
            @update:model-value="(value) => onQuantityInput(child.id, value)"
          />
        </div>
      </div>

      <div v-if="!childTenants.length" class="text-caption text-grey-7 text-center q-py-sm">
        No child tenants found.
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section class="q-py-sm">
      <div
        class="text-caption q-mb-sm"
        :class="isOverAllocated ? 'text-negative text-weight-medium' : 'text-grey-8'"
      >
        Allocated: {{ allocatedTotal }} · Remaining: {{ remainingQty }}
        <span v-if="isOverAllocated"> · Over by {{ allocatedTotal - stock.excellent_qty }}</span>
      </div>
      <q-btn
        color="primary"
        no-caps
        class="pill-btn full-width"
        label="Save"
        :loading="saving"
        :disable="isOverAllocated || !childTenants.length"
        @click="emit('save', stock.id)"
      />
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import SmartImage from 'src/components/SmartImage.vue';
import type { GlobalStockRow, AllocateChildTenant } from '../types';

const props = defineProps<{
  stock: GlobalStockRow;
  childTenants: AllocateChildTenant[];
  quantities: Record<number, number>;
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:quantities', stockId: number, childTenantId: number, quantity: number): void;
  (e: 'save', stockId: number): void;
}>();

const allocatedTotal = computed(() =>
  props.childTenants.reduce((sum, child) => sum + Math.max(0, props.quantities[child.id] ?? 0), 0),
);

const remainingQty = computed(() => Math.max(0, props.stock.excellent_qty - allocatedTotal.value));

const isOverAllocated = computed(() => allocatedTotal.value > props.stock.excellent_qty);

const onQuantityInput = (childTenantId: number, value: string | number | null) => {
  const parsed = Number(value);
  const quantity = Number.isFinite(parsed) ? Math.max(0, Math.floor(parsed)) : 0;
  emit('update:quantities', props.stock.id, childTenantId, quantity);
};
</script>

<style scoped>
.allocate-card {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.allocate-card__header {
  gap: 4px;
}

.allocate-card__image {
  width: 1.4in;
  height: 1.4in;
  object-fit: contain;
  background: #fff;
  border-radius: 8px;
}

.allocate-card__children {
  flex: 1;
}

.allocate-card__qty-input :deep(.q-field__control) {
  min-height: 34px;
}
</style>
