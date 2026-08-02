<template>
  <FilterSidebar :model-value="open" title="Filters" @update:model-value="(val) => emit('update:open', val)">
    <q-select
      :model-value="searchField"
      :options="searchFieldOptions"
      filled
      dense
      emit-value
      map-options
      class="soft-input q-mb-sm"
      label="Search By"
      @update:model-value="(val) => emit('update:searchField', val)"
    />
    <q-select
      :model-value="brand"
      :options="brandOptions"
      filled
      dense
      emit-value
      map-options
      clearable
      class="soft-input q-mb-sm"
      label="Brand"
      @update:model-value="(val) => emit('update:brand', val)"
    />
    <q-select
      :model-value="category"
      :options="categoryOptions"
      filled
      dense
      emit-value
      map-options
      clearable
      class="soft-input q-mb-sm"
      label="Category"
      @update:model-value="(val) => emit('update:category', val)"
    />
    <q-select
      :model-value="vendorCode"
      :options="vendorOptions"
      filled
      dense
      emit-value
      map-options
      clearable
      class="soft-input q-mb-sm"
      label="Vendor"
      @update:model-value="onVendorChange"
    />
    <q-select
      :model-value="marketCode"
      :options="marketOptions"
      filled
      dense
      emit-value
      map-options
      clearable
      class="soft-input q-mb-sm"
      label="Market"
      @update:model-value="(val) => emit('update:marketCode', val)"
    />
    <q-select
      :model-value="availability"
      :options="availabilityOptions"
      filled
      dense
      emit-value
      map-options
      class="soft-input q-mb-md"
      label="Availability"
      @update:model-value="(val) => emit('update:availability', val)"
    />
    <div class="row q-gutter-sm justify-end">
      <q-btn flat no-caps label="Reset" @click="emit('reset')" />
      <q-btn flat no-caps label="Apply" @click="emit('apply')" />
    </div>
  </FilterSidebar>
</template>

<script setup lang="ts">
import FilterSidebar from 'src/components/FilterSidebar.vue';

interface OptionItem {
  label: string;
  value: string | null;
}

defineProps<{
  open: boolean;
  searchField: 'name' | 'barcode' | 'product_code' | 'id';
  brand: string | null;
  category: string | null;
  vendorCode: string | null;
  marketCode: string | null;
  availability: 'all' | 'available' | 'unavailable';
  searchFieldOptions: OptionItem[];
  brandOptions: OptionItem[];
  categoryOptions: OptionItem[];
  vendorOptions: OptionItem[];
  marketOptions: OptionItem[];
  availabilityOptions: OptionItem[];
}>();

const emit = defineEmits<{
  (e: 'update:open', val: boolean): void;
  (e: 'update:searchField', val: 'name' | 'barcode' | 'product_code' | 'id'): void;
  (e: 'update:brand', val: string | null): void;
  (e: 'update:category', val: string | null): void;
  (e: 'update:vendorCode', val: string | null): void;
  (e: 'update:marketCode', val: string | null): void;
  (e: 'update:availability', val: 'all' | 'available' | 'unavailable'): void;
  (e: 'apply'): void;
  (e: 'reset'): void;
  (e: 'vendorChange'): void;
}>();

const onVendorChange = (val: string | null) => {
  emit('update:vendorCode', val);
  emit('vendorChange');
};
</script>

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
