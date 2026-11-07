<template>
  <section class="manual-catalog-item-search row items-center q-gutter-sm">
    <div class="text-subtitle2 text-weight-bold col-grow">
      {{ $t('shop_admin.manual_order_add_items', 'Add items') }}
    </div>
    <q-btn
      outline
      dense
      no-caps
      color="primary"
      class="rounded-sq-btn text-weight-bold q-px-sm"
      icon="ph ph-plus"
      :label="$t('shop_admin.manual_catalog_add_items_btn', 'Add Items')"
      :disable="disabled"
      data-test="manual-catalog-add-items-open"
      @click="emit('open-add-items')"
    />
  </section>
</template>

<script setup lang="ts">
defineProps<{
  disabled?: boolean;
}>();

const emit = defineEmits<{
  (e: 'open-add-items'): void;
}>();
</script>

<style scoped>
.manual-catalog-item-search {
  padding-top: 16px;
  border-top: 1px solid var(--tf-neutral-border);
}
</style>
