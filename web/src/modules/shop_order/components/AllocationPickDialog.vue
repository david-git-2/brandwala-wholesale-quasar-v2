<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: 700px; max-width: 90vw;">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6">Select Allocation to List</div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <!-- Search bar -->
      <q-card-section class="q-pt-sm">
        <q-input
          v-model="search"
          outlined
          dense
          placeholder="Filter by product name, code, brand…"
          clearable
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
        </q-input>
      </q-card-section>

      <!-- Table list -->
      <q-card-section class="q-pt-none" style="max-height: 450px; overflow-y: auto;">
        <q-table
          flat
          bordered
          dense
          row-key="allocation_id"
          :rows="filteredCandidates"
          :columns="columns"
          :pagination="{ rowsPerPage: 10 }"
        >
          <!-- image / name -->
          <template #body-cell-product_name="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <q-avatar size="32px" rounded class="q-mr-sm bg-grey-3">
                  <q-img v-if="props.row.product_image_url" :src="props.row.product_image_url" />
                  <q-icon v-else name="image" color="grey-6" />
                </q-avatar>
                <div class="ellipsis" style="max-width: 250px;">
                  <div class="text-weight-medium">{{ props.row.product_name }}</div>
                  <div class="text-caption text-grey-6">{{ props.row.product_brand }} | {{ props.row.product_category }}</div>
                </div>
              </div>
            </q-td>
          </template>

          <!-- Actions -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn
                color="primary"
                label="Pick"
                dense
                unelevated
                no-caps
                @click="onPick(props.row)"
              />
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { CandidateAllocation } from '../types'

const props = defineProps<{
  modelValue: boolean
  candidates: CandidateAllocation[]
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'pick', value: CandidateAllocation): void
}>()

const search = ref('')

const columns = [
  { name: 'product_name', label: 'Product', field: 'product_name', align: 'left' as const, sortable: true },
  { name: 'product_code', label: 'Code', field: 'product_code', align: 'left' as const, sortable: true },
  { name: 'product_barcode', label: 'Barcode', field: 'product_barcode', align: 'left' as const },
  { name: 'allocated_quantity', label: 'Allocated', field: 'allocated_quantity', align: 'center' as const, sortable: true },
  { name: 'actions', label: '', field: 'allocation_id', align: 'right' as const },
]

const filteredCandidates = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return props.candidates

  return props.candidates.filter((c) => {
    return (
      c.product_name.toLowerCase().includes(query) ||
      (c.product_code && c.product_code.toLowerCase().includes(query)) ||
      (c.product_barcode && c.product_barcode.toLowerCase().includes(query)) ||
      (c.product_brand && c.product_brand.toLowerCase().includes(query)) ||
      (c.product_category && c.product_category.toLowerCase().includes(query))
    )
  })
})

const onPick = (row: CandidateAllocation) => {
  emit('pick', row)
  emit('update:modelValue', false)
}
</script>
