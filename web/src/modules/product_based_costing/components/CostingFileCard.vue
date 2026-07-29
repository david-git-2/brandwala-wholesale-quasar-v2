<template>
  <div class="row q-col-gutter-md">
    <div v-for="item in items" :key="item.id" class="col-12 col-sm-6">
      <q-card
        class="q-pa-md cursor-pointer"
        bordered
        flat
        :style="statusSurfaceStyle(item.status)"
        @click="handleSelect(item)"
      >
        <div class="row items-start justify-between no-wrap">
          <div>
            <div class="text-h6 text-weight-bold">#{{ item.id }} {{ item.name }}</div>

            <div class="text-subtitle2 q-mt-sm">created for: {{ item.order_for }}</div>
          </div>

          <div class="row items-center q-gutter-xs">
            <q-chip dense square :style="statusChipStyle(item.status)" class="costing-status-chip">
              <span class="status-dot" :style="{ backgroundColor: statusDotColor(item.status) }" />
              {{ item.status ?? 'pending' }}
            </q-chip>
            <q-btn icon="ph ph-dots-three-vertical" flat round dense @click.stop>
              <q-menu auto-close>
                <q-list dense style="min-width: 140px">
                  <q-item clickable v-ripple @click="handleCopy(item)">
                    <q-item-section>Copy</q-item-section>
                  </q-item>
                  <q-item clickable v-ripple @click="handleEdit(item)">
                    <q-item-section>Edit</q-item-section>
                  </q-item>
                  <q-item clickable v-ripple @click="handleDelete(item)">
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
import { useQuasar } from 'quasar';
import type { ProductBasedCostingFile } from '../types';

defineProps<{
  items: ProductBasedCostingFile[];
}>();

const emit = defineEmits<{
  (event: 'select', item: ProductBasedCostingFile): void;
  (event: 'copy', item: ProductBasedCostingFile): void;
  (event: 'edit', item: ProductBasedCostingFile): void;
  (event: 'delete', item: ProductBasedCostingFile): void;
}>();

const $q = useQuasar();

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
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete #${item.id} ${item.name}?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    emit('delete', item);
  });
};

const normalizeStatus = (status: string | null | undefined) => {
  const value = (status ?? '').trim().toLowerCase();
  return value || 'pending';
};

const statusSurfaceStyle = (status: string | null | undefined) => {
  const value = normalizeStatus(status);
  if (value === 'pending') {
    return {
      backgroundColor: '#fffbf2',
      boxShadow: 'inset 6px 0 0 #d8a54a',
    };
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#f3f7ff',
      boxShadow: 'inset 6px 0 0 #6f93d8',
    };
  }
  if (value === 'confirmed') {
    return {
      backgroundColor: '#e6f7ff',
      boxShadow: 'inset 6px 0 0 #1890ff',
    };
  }
  if (value === 'placing_order') {
    return {
      backgroundColor: '#f0f5ff',
      boxShadow: 'inset 6px 0 0 #2f54eb',
    };
  }
  if (value === 'ready_for_shipment') {
    return {
      backgroundColor: '#f6ffed',
      boxShadow: 'inset 6px 0 0 #52c41a',
    };
  }
  if (value === 'invoicing') {
    return {
      backgroundColor: '#f8f9fa',
      boxShadow: 'inset 6px 0 0 #722ed1',
    };
  }
  if (value === 'delivered') {
    return {
      backgroundColor: '#e6fffb',
      boxShadow: 'inset 6px 0 0 #13c2c2',
    };
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#fff4f6',
      boxShadow: 'inset 6px 0 0 #c97586',
    };
  }
  return {
    backgroundColor: '#f8f9fb',
    boxShadow: 'inset 6px 0 0 #8ea0b8',
  };
};

const statusChipStyle = (status: string | null | undefined) => {
  const value = normalizeStatus(status);
  if (value === 'pending') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
      boxShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
    };
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
      boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
    };
  }
  if (value === 'confirmed') {
    return {
      backgroundColor: '#bae7ff',
      color: '#0050b3',
      border: '1px solid #91d5ff',
      boxShadow: '0 1px 2px rgba(0, 80, 179, 0.18)',
    };
  }
  if (value === 'placing_order') {
    return {
      backgroundColor: '#d6e4ff',
      color: '#10239e',
      border: '1px solid #adc6ff',
      boxShadow: '0 1px 2px rgba(16, 35, 158, 0.18)',
    };
  }
  if (value === 'ready_for_shipment') {
    return {
      backgroundColor: '#d9f7be',
      color: '#237804',
      border: '1px solid #b7eb8f',
      boxShadow: '0 1px 2px rgba(35, 120, 4, 0.18)',
    };
  }
  if (value === 'invoicing') {
    return {
      backgroundColor: '#efdbff',
      color: '#391085',
      border: '1px solid #d3ade6',
      boxShadow: '0 1px 2px rgba(57, 16, 133, 0.18)',
    };
  }
  if (value === 'delivered') {
    return {
      backgroundColor: '#b5f5ec',
      color: '#00474f',
      border: '1px solid #87e8de',
      boxShadow: '0 1px 2px rgba(0, 71, 79, 0.18)',
    };
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
      boxShadow: '0 1px 2px rgba(111, 43, 58, 0.18)',
    };
  }
  return {
    backgroundColor: '#dbe5f3',
    color: '#3b4b66',
    border: '1px solid #b9c8dd',
    boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
  };
};

const statusDotColor = (status: string | null | undefined) => {
  const value = normalizeStatus(status);
  if (value === 'pending') return '#9a6a24';
  if (value === 'offered') return '#3f67b3';
  if (value === 'confirmed') return '#1890ff';
  if (value === 'placing_order') return '#2f54eb';
  if (value === 'ready_for_shipment') return '#52c41a';
  if (value === 'invoicing') return '#722ed1';
  if (value === 'delivered') return '#13c2c2';
  if (value === 'cancelled') return '#a64c62';
  return '#66758c';
};
</script>

<style scoped>
.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>
