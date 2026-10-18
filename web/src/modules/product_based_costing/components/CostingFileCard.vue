<template>
  <div class="row q-col-gutter-sm">
    <div v-for="item in items" :key="item.id" class="col-12">
      <q-card
        class="q-px-sm q-py-xs cursor-pointer"
        bordered
        flat
        @click="handleSelect(item)"
      >
        <div class="row items-center justify-between no-wrap">
          <div class="col min-width-0">
            <div class="text-subtitle1 text-weight-bold ellipsis">#{{ item.id }} {{ item.name }}</div>
            <div class="text-caption ellipsis tf-card-sub">
              {{ $t('product_based_costing.created_for', { name: item.order_for || $t('product_based_costing.untitled') }) }}
            </div>
          </div>

          <div class="row items-center q-gutter-xs">
            <TfStatusBadge unique="pbc" :status="normalizeStatus(item.status)" :label="statusLabel(item.status)" />
            <TfBtn variant="icon" icon="ph ph-dots-three-vertical" @click.stop>
              <q-menu auto-close>
                <q-list dense style="min-width: 140px">
                  <q-item clickable v-ripple @click="handleCopy(item)">
                    <q-item-section>{{ $t('product_based_costing.copy') }}</q-item-section>
                  </q-item>
                  <q-item clickable v-ripple @click="handleEdit(item)">
                    <q-item-section>{{ $t('product_based_costing.edit') }}</q-item-section>
                  </q-item>
                  <q-item clickable v-ripple @click="handleDelete(item)">
                    <q-item-section class="text-negative">{{
                      $t('product_based_costing.delete')
                    }}</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </TfBtn>
          </div>
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import type { ProductBasedCostingFile } from '../types';
import { normalizePbcFileStatus } from '../composables/useProductBasedCostingFileDetailsState';

defineProps<{
  items: ProductBasedCostingFile[];
}>();

const emit = defineEmits<{
  (event: 'select', item: ProductBasedCostingFile): void;
  (event: 'copy', item: ProductBasedCostingFile): void;
  (event: 'edit', item: ProductBasedCostingFile): void;
  (event: 'delete', item: ProductBasedCostingFile): void;
}>();

const { t, te } = useI18n();

const statusLabel = (status: string | null | undefined) => {
  const value = normalizePbcFileStatus((status ?? 'pending').trim().toLowerCase() || 'pending');
  const key = `product_based_costing.status_${value}`;
  return te(key) ? t(key) : value.replaceAll('_', ' ');
};

const handleSelect = (item: ProductBasedCostingFile) => {
  emit('select', item);
};

const handleEdit = (item: ProductBasedCostingFile) => {
  emit('edit', item);
};

const handleCopy = (item: ProductBasedCostingFile) => {
  emit('copy', item);
};

const handleDelete = (item: ProductBasedCostingFile) => {
  emit('delete', item);
};

const normalizeStatus = (status: string | null | undefined) =>
  normalizePbcFileStatus((status ?? '').trim().toLowerCase() || 'pending');
</script>

<style scoped>
.tf-card-sub {
  color: var(--tf-neutral-muted);
}
</style>
