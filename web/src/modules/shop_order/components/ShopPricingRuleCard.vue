<template>
  <q-card flat bordered class="q-mb-md">
    <q-card-section class="q-py-sm">
      <div class="row items-center justify-end q-gutter-x-md">
        <!-- Dropship Floor Markup Input -->
          <q-input
            v-model.number="dropshipMarkupPercentage"
            type="number"
            dense
            outlined
            style="width: 150px"
            suffix="%"
            label="Dropship Floor %"
            hint="Floor markup on cost"
            step="0.1"
            min="0"
          />

          <!-- Global Display Quantity Add Input -->
          <q-input
            v-model.number="globalQuantityAdd"
            type="number"
            dense
            outlined
            style="width: 150px"
            label="Add Quantity"
            placeholder="e.g. 100"
            hint="Added to available stock"
            step="1"
          />

          <!-- Sell Price Markup Input -->
          <q-input
            v-model.number="markupPercentage"
            type="number"
            dense
            outlined
            style="width: 160px"
            suffix="%"
            label="Sell Price Markup %"
            hint="Rounded to nearest 5/0"
            step="0.1"
            min="0"
          />

          <!-- Save Button -->
          <q-btn
            unelevated
            color="primary"
            dense
            class="q-px-md"
            icon="ph ph-floppy-disk"
            :label="$t('shop_admin.save_rule')"
            :loading="isSaving"
            @click="onSaveRule"
          />
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { ShopPricingRule } from '../types';

const props = defineProps<{
  rule: ShopPricingRule | null;
  isSaving: boolean;
}>();

const emit = defineEmits<{
  (
    e: 'save',
    payload: {
      markup_percentage: number;
      dropship_markup_percentage?: number;
      global_quantity_add?: number | null;
      is_auto_publish: boolean;
      default_show_quantity: boolean;
    }
  ): void;
}>();

const markupPercentage = ref<number>(0);
const dropshipMarkupPercentage = ref<number>(0);
const globalQuantityAdd = ref<number | null>(null);
const isAutoPublish = ref<boolean>(false);
const defaultShowQuantity = ref<boolean>(true);

watch(
  () => props.rule,
  (newRule) => {
    if (newRule) {
      markupPercentage.value = Number(newRule.markup_percentage ?? 0);
      dropshipMarkupPercentage.value = Number(newRule.dropship_markup_percentage ?? 0);
      globalQuantityAdd.value = newRule.default_add_quantity ?? 0;
      isAutoPublish.value = Boolean(newRule.is_auto_publish);
      defaultShowQuantity.value = newRule.default_show_quantity ?? true;
    }
  },
  { immediate: true }
);

const onSaveRule = () => {
  emit('save', {
    markup_percentage: Number(markupPercentage.value) || 0,
    dropship_markup_percentage: Number(dropshipMarkupPercentage.value) || 0,
    global_quantity_add: globalQuantityAdd.value !== null && globalQuantityAdd.value !== undefined && globalQuantityAdd.value !== ('' as any)
      ? Number(globalQuantityAdd.value)
      : null,
    is_auto_publish: isAutoPublish.value,
    default_show_quantity: defaultShowQuantity.value,
  });
};
</script>
