<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Global Reference</div>
          <h1 class="text-h5 q-my-none">{{ title }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ description }}</p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            icon="add"
            :label="`Add ${entityLabel}`"
            @click="$emit('add')"
          />
        </div>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>{{ error }}</q-banner>

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">{{ entityLabel }} Catalog</div>
        </q-card-section>
        <q-card-section v-if="loading" class="text-grey-7">Loading...</q-card-section>
        <q-table v-else flat row-key="id" :rows="rows" :columns="columns" :dense="$q.screen.lt.md">
          <template #body-cell-is_active="props">
            <q-td :props="props">
              <q-badge :color="props.row.is_active ? 'positive' : 'grey-6'">
                {{ props.row.is_active ? 'Active' : 'Inactive' }}
              </q-badge>
            </q-td>
          </template>
          <template #body-cell-is_system="props">
            <q-td :props="props">
              <q-badge :color="props.row.is_system ? 'teal' : 'grey-6'">
                {{ props.row.is_system ? 'System' : 'Custom' }}
              </q-badge>
            </q-td>
          </template>
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn
                flat
                round
                dense
                icon="o_edit"
                :disable="props.row.is_system"
                @click="$emit('edit', props.row)"
              />
              <q-btn
                flat
                round
                dense
                color="negative"
                icon="o_delete"
                :disable="props.row.is_system"
                @click="$emit('delete', props.row)"
              />
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar';

defineProps<{
  title: string;
  description: string;
  entityLabel: string;
  columns: QTableColumn[];
  rows: unknown[];
  loading: boolean;
  error: string | null;
}>();

defineEmits<{
  add: [];
  edit: [row: unknown];
  delete: [row: unknown];
  refresh: [];
}>();
</script>
