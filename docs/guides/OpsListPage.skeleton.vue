<!--
  Canonical ops list chrome. Copy into web/src/modules/<m>/pages/<Name>ListPage.vue.
  Wire search, columns, and create handler. Do not open InboundShipmentListPage for layout.
-->
<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <q-card flat bordered class="q-pa-xs flex-shrink-0 list-toolbar-card">
      <div class="row items-center justify-between q-gutter-xs">
        <q-input
          v-model="search"
          outlined
          rounded
          dense
          debounce="300"
          placeholder="Search…"
          class="col-grow"
          hide-bottom-space
        />
        <TfBtn
          v-if="rows.length"
          variant="primary"
          size="md"
          label="New"
          @click="onCreate"
        />
      </div>
    </q-card>

    <div class="col overflow-hidden">
      <TfSkeletonRows v-if="loading && !rows.length" :rows="8" :cols="4" />
      <TfEmptyState
        v-else-if="!rows.length"
        title="No records yet"
        message="Create the first one to get started."
      >
        <TfBtn variant="primary" size="md" label="New" @click="onCreate" />
      </TfEmptyState>
      <q-table
        v-else
        flat
        bordered
        dense
        class="sticky-header-table full-width"
        :rows="rows"
        :columns="columns"
        row-key="id"
        :loading="loading"
        hide-pagination
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { QTableColumn } from 'quasar';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfSkeletonRows from 'src/components/ui/TfSkeletonRows.vue';

const search = ref('');
const loading = ref(false);
const rows = ref<{ id: string }[]>([]);

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' },
];

function onCreate() {
  // ⚠️ verify: route or open create sheet
}
</script>
