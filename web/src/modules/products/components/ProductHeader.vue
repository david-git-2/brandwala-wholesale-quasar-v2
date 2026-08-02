<template>
  <section class="row items-center justify-between q-col-gutter-md">
    <div class="col">
      <div class="text-overline text-primary">Catalog</div>
      <h1 class="text-h5 text-weight-bold q-my-none">Products</h1>
    </div>
    <div class="col-auto row q-gutter-sm items-center">
      <q-btn
        outline
        color="primary"
        no-caps
        label="Bulk Import"
        icon="ph ph-folder-simple-plus"
        @click="emit('openBulkImport')"
      />
      <q-btn
        color="primary"
        unelevated
        no-caps
        label="Add Product"
        icon="ph ph-plus"
        @click="emit('openCreateDialog')"
      />
    </div>
  </section>
</template>

<script setup lang="ts">
const emit = defineEmits<{
  (e: 'openBulkImport'): void;
  (e: 'openCreateDialog'): void;
}>();
</script>
