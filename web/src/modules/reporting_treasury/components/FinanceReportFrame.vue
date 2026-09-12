<template>
  <q-page
    class="finance-report-page bg-grey-1 column no-wrap"
    style="height: calc(100vh - 55px); overflow: hidden"
  >
    <div class="bg-white border-bottom q-px-md q-py-xs shrink-0 shadow-xs">
      <div class="row items-center justify-between q-col-gutter-xs">
        <div class="col-auto row items-center q-gutter-xs">
          <slot name="filters" />
        </div>
        <div class="col-auto row items-center q-gutter-x-xs">
          <slot name="toolbar-actions" />
          <q-btn
            v-if="showExport"
            outline
            dense
            size="sm"
            color="primary"
            icon="ph ph-file-csv"
            label="Export CSV"
            no-caps
            class="rounded-sq-btn q-px-sm text-weight-bold"
            :disable="exportDisabled || loading"
            @click="$emit('export')"
          />
          <q-btn
            flat
            round
            dense
            size="sm"
            icon="ph ph-arrows-clockwise"
            color="grey-7"
            :loading="loading"
            @click="$emit('refresh')"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <q-banner v-if="error" class="bg-negative text-white q-px-md q-py-xs shrink-0">
      {{ error }}
    </q-banner>

    <div v-if="$slots.kpi" class="bg-white border-bottom q-px-md q-py-xs shrink-0">
      <slot name="kpi" />
    </div>

    <div class="table-scroll-container col-grow overflow-hidden q-pa-xs">
      <slot />
    </div>
  </q-page>
</template>

<script setup lang="ts">
defineProps<{
  loading?: boolean;
  error?: string | null;
  showExport?: boolean;
  exportDisabled?: boolean;
}>();

defineEmits<{
  export: [];
  refresh: [];
}>();
</script>

<style scoped>
.rounded-sq-btn {
  border-radius: 8px !important;
}

.shrink-0 {
  flex-shrink: 0;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}

.table-scroll-container {
  display: flex;
  flex-direction: column;
}

.table-scroll-container :deep(.q-table__container) {
  height: 100%;
  display: flex;
  flex-direction: column;
  border-radius: 0;
  border: 1px solid #e2e8f0;
}

.table-scroll-container :deep(.q-table__middle) {
  flex: 1 1 auto;
  overflow-y: auto;
}

.table-scroll-container :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #fafafa;
}
</style>
