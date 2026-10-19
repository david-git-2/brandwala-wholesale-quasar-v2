<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="product_based_costing.add-items-drawer-width"
    :default-width="680"
    :min-width="480"
    :max-width="1200"
    :aria-label="$t('product_based_costing.add_products')"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <div class="drawer-card column no-wrap full-height">
      <div class="row items-center justify-between q-px-md q-py-sm drawer-header shrink-0 no-wrap q-gutter-x-sm">
        <div class="col min-width-0">
          <div class="text-subtitle1 text-weight-bold text-grey-9">
            {{ $t('product_based_costing.add_products') }}
          </div>
          <div class="text-caption text-grey-7 ellipsis">
            {{ fileName }}
          </div>
        </div>
        <q-btn
          flat
          dense
          no-caps
          color="primary"
          size="sm"
          icon="ph ph-squares-four"
          :label="$t('product_based_costing.browse_catalog')"
          class="drawer-header__catalog-btn q-px-sm shrink-0"
          @click="emit('browse-catalog')"
        />
        <q-btn
          icon="ph ph-x"
          flat
          round
          dense
          color="grey-7"
          class="shrink-0"
          aria-label="Close"
          @click="close"
        />
      </div>

      <AddCostingItemsPanel
        class="col"
        :file-id="fileId"
        layout="drawer"
        @saved="close"
        @create-new-product="onCreateNewProduct"
      />
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import AddCostingItemsPanel from './AddCostingItemsPanel.vue';

const props = defineProps<{
  modelValue: boolean;
  fileId: number;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'create-new-product': [name: string];
  'browse-catalog': [];
  saved: [];
}>();

const costingStore = useProductBasedCostingStore();

const fileName = computed(
  () => costingStore.item?.name ?? `Costing File #${props.fileId}`,
);

const close = () => {
  emit('saved');
  emit('update:modelValue', false);
};

const onCreateNewProduct = (name: string) => {
  emit('create-new-product', name);
  emit('update:modelValue', false);
};
</script>

<style scoped>
.drawer-card {
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  background: var(--tf-theme-surface, #fff);
}

.drawer-header {
  background: #fff;
  border-bottom: 1px solid var(--tf-neutral-border, #e2e8f0);
}

.drawer-header__catalog-btn {
  font-weight: 600;
}
</style>
