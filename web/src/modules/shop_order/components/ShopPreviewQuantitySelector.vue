<template>
  <div class="quantity-selector-container">
    <!-- Stock status line -->
    <div v-if="showStockQuantity" class="stock-display text-caption text-grey-7 q-mb-xs">
      <q-icon name="inventory_2" size="14px" class="q-mr-xs" />
      Available: <span class="text-weight-bold text-grey-9">{{ stock }}</span> units
    </div>
    <div v-else class="stock-display text-caption q-mb-xs">
      <span v-if="stock > 0" class="text-success-custom text-weight-medium">
        <q-icon name="check_circle" size="14px" class="q-mr-xs" />
        In Stock
      </span>
      <span v-else class="text-negative text-weight-medium">
        <q-icon name="cancel" size="14px" class="q-mr-xs" />
        Out of Stock
      </span>
    </div>

    <!-- Selector controls -->
    <div class="flex items-center no-wrap quantity-controls">
      <q-btn
        flat
        round
        dense
        size="sm"
        icon="remove"
        color="primary"
        class="control-btn minus-btn"
        :disable="modelValue <= 0"
        @click="decrement"
      />
      <div class="quantity-value text-subtitle2 text-weight-bold text-center">
        {{ modelValue }}
      </div>
      <q-btn
        flat
        round
        dense
        size="sm"
        icon="add"
        color="primary"
        class="control-btn plus-btn"
        :disable="modelValue >= stock"
        @click="increment"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    modelValue: number;
    stock: number;
    showStockQuantity: boolean;
  }>(),
  {
    modelValue: 0,
    stock: 99,
    showStockQuantity: true,
  }
);

const emit = defineEmits<{
  (e: 'update:modelValue', val: number): void;
}>();

const increment = () => {
  if (props.modelValue < props.stock) {
    emit('update:modelValue', props.modelValue + 1);
  }
};

const decrement = () => {
  if (props.modelValue > 0) {
    emit('update:modelValue', props.modelValue - 1);
  }
};
</script>

<style scoped>
.quantity-selector-container {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.stock-display {
  font-size: 11px;
  display: flex;
  align-items: center;
}

.text-success-custom {
  color: #10b981; /* Premium emerald green */
}

.quantity-controls {
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 20px;
  padding: 2px;
  background: rgba(0, 0, 0, 0.02);
  transition: all 0.2s ease;
}

.quantity-controls:hover {
  border-color: rgba(var(--q-primary), 0.3);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.control-btn {
  background: white;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  transition: transform 0.1s ease, background-color 0.2s ease;
}

.control-btn:active {
  transform: scale(0.92);
}

.quantity-value {
  min-width: 32px;
  user-select: none;
}
</style>
