<template>
  <div class="row q-col-gutter-md">
    <div
      v-for="item in items"
      :key="item.id"
      class="col-12 col-sm-6"
    >
      <q-card
        class="q-pa-md cursor-pointer"
        bordered
        flat
        @click="handleSelect(item)"
      >
        <div class="row items-start justify-between no-wrap">
          <div>
            <div class="text-h6 text-weight-bold">
              #{{ item.id }} {{ item.name }}
            </div>

            <div class="text-subtitle2 q-mt-sm">
              created for: {{ item.order_for }}
            </div>
          </div>

          <div class="row items-center q-gutter-xs">
            <q-btn
              icon="more_vert"
              flat
              round
              dense
              @click.stop
            >
              <q-menu auto-close>
                <q-list dense style="min-width: 140px">
                  <q-item clickable v-ripple @click="handleEdit(item)">
                    <q-item-section avatar>
                      <q-icon name="edit" />
                    </q-item-section>
                    <q-item-section>Edit</q-item-section>
                  </q-item>
                  <q-item clickable v-ripple @click="handleDelete(item)">
                    <q-item-section avatar>
                      <q-icon name="delete_outline" color="negative" />
                    </q-item-section>
                    <q-item-section class="text-negative">Delete</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </div>
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useQuasar } from 'quasar'
import type { ProductBasedCostingFile } from '../types'

defineProps<{
  items: ProductBasedCostingFile[]
}>()

const emit = defineEmits<{
  (event: 'select', item: ProductBasedCostingFile): void
  (event: 'edit', item: ProductBasedCostingFile): void
  (event: 'delete', item: ProductBasedCostingFile): void
}>()

const $q = useQuasar()

const handleSelect = (item: ProductBasedCostingFile) => {
  emit('select', item)
}

const handleEdit = (item: ProductBasedCostingFile) => {
  emit('edit', item)
}

const handleDelete = (item: ProductBasedCostingFile) => {
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete #${item.id} ${item.name}?`,
    cancel: true,
    persistent: true
  }).onOk(() => {
    emit('delete', item)
  })
}
</script>
