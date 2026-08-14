<template>
  <q-card flat bordered class="q-pa-md shipment-assign-shop-card">
    <div class="text-subtitle1 text-weight-bold text-primary q-mb-xs">
      Assign to shop
    </div>
    <div class="text-caption text-grey-7 q-mb-md">
      Choose which shop can sell this stock.
    </div>
    <div class="row q-col-gutter-sm items-end">
      <div class="col-12 col-sm-8">
        <q-select
          :model-value="modelValue"
          :options="childTenantOptions"
          label="Shop"
          dense
          outlined
          clearable
          emit-value
          map-options
          :loading="childTenantsLoading"
          @update:model-value="(val) => $emit('update:modelValue', val)"
        />
      </div>
      <div class="col-12 col-sm-4 row q-gutter-sm">
        <q-btn
          color="primary"
          unelevated
          no-caps
          dense
          label="Save"
          class="col"
          :loading="assigningChild"
          @click="$emit('save')"
        />
        <q-btn
          flat
          no-caps
          dense
          label="Clear"
          class="col"
          :disable="!assignedChildTenantId"
          :loading="assigningChild"
          @click="$emit('clear')"
        />
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
defineProps<{
  modelValue: number | null;
  childTenantOptions: Array<{ label: string; value: number }>;
  childTenantsLoading: boolean;
  assigningChild: boolean;
  assignedChildTenantId?: number | null | undefined;
}>();

defineEmits<{
  'update:modelValue': [val: number | null];
  save: [];
  clear: [];
}>();
</script>
