<template>
  <div class="row q-col-gutter-md">
    <div
      v-for="item in items"
      :key="item.id"
      :class="colClass"
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
              icon="edit"
              flat
              round
              dense
              @click.stop="handleEdit(item)"
            />
            <q-btn
              icon="delete"
              flat
              round
              dense
              color="negative"
              @click.stop="handleDelete(item)"
            />
          </div>
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useQuasar } from 'quasar'

defineProps({
  items: {
    type: Array,
    required: true
  }
})

const emit = defineEmits(['select', 'edit', 'delete'])

const $q = useQuasar()

const colClass = computed(() => {
  return $q.screen.gt.md ? 'col-6' : 'col-12'
})

const handleSelect = (item) => {
  emit('select', item)
}

const handleEdit = (item) => {
  emit('edit', item)
}

const handleDelete = (item) => {
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
