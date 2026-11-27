<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="product_based_costing.add-product-cart-width"
    :default-width="960"
    :min-width="520"
    :max-width="1400"
    :z-index="6100"
    :aria-label="$t('product_based_costing.browse_catalog')"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <div class="drawer-card column no-wrap full-height">
      <div class="row items-center justify-between q-px-md q-py-sm drawer-header shrink-0 no-wrap">
        <div class="col min-width-0">
          <div class="text-subtitle1 text-weight-bold text-grey-9">
            {{ $t('product_based_costing.browse_catalog') }}
          </div>
          <div class="text-caption text-grey-7 ellipsis">
            PBC-{{ fileId }} · {{ fileName }}
          </div>
        </div>
        <q-btn
          icon="ph ph-x"
          flat
          round
          dense
          color="grey-7"
          aria-label="Close"
          class="shrink-0"
          @click="close"
        />
      </div>

      <AddProductCartPanel
        class="col"
        :file-id="fileId"
        layout="drawer"
        :filter-sidebar-z-index="7200"
      />
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import AddProductCartPanel from './AddProductCartPanel.vue';
import { useProductBasedCostingFileDetailQuery } from '../composables/useProductBasedCostingFileDetailQuery';

const props = defineProps<{
  modelValue: boolean;
  fileId: number;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  closed: [];
}>();

const fileIdRef = computed(() => props.fileId);
const { data: file } = useProductBasedCostingFileDetailQuery(fileIdRef);

const fileName = computed(
  () => file.value?.name?.trim() || `Costing File #${props.fileId}`,
);

const close = () => {
  emit('closed');
  emit('update:modelValue', false);
};
</script>

<style scoped>
.drawer-card {
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  background: var(--tf-theme-base, var(--tf-disabled-bg));
}

.drawer-header {
  background: #fff;
  border-bottom: 1px solid var(--tf-neutral-border, #e2e8f0);
}
</style>
