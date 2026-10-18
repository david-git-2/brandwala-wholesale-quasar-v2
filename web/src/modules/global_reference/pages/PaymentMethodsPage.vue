<template>
  <q-page class="tf-page">
    <section class="tf-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Catalog</div>
          <h1 class="text-h5 q-my-none">Payment Methods</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Bangladesh and international payment methods reference catalog.
          </p>
        </div>
      </section>

      <q-banner v-if="isError" class="tf-status-banner text-white" rounded>
        {{ error?.message || 'Failed to load payment methods.' }}
      </q-banner>

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Payment Method Catalog</div>
        </q-card-section>

        <q-card-section v-if="isLoading" class="text-grey-7">Loading payment methods...</q-card-section>

        <q-card-section v-else-if="!items || items.length === 0" class="text-center text-grey-7">
          No payment methods found.
        </q-card-section>

        <q-table v-else flat row-key="id" :rows="items" :columns="columns" :dense="$q.screen.lt.md">
          <template #body-cell-code="props">
            <q-td :props="props">
              <q-badge color="primary" outline>{{ props.row.code }}</q-badge>
            </q-td>
          </template>

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
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar';
import { useGlobalPaymentMethodsQuery } from '../composables/useGlobalReferenceQuery';

const { data: items, isLoading, isError, error } = useGlobalPaymentMethodsQuery();

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'category', label: 'Category', field: 'category', align: 'left', sortable: true },
  { name: 'scope', label: 'Scope', field: 'scope', align: 'left', sortable: true },
  { name: 'sort_order', label: 'Order', field: 'sort_order', align: 'left', sortable: true },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'left', sortable: true },
  { name: 'is_system', label: 'Type', field: 'is_system', align: 'left', sortable: true },
];
</script>
