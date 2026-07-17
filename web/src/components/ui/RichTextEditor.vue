<template>
  <q-editor
    ref="editorRef"
    :model-value="modelValue"
    :min-height="minHeight"
    flat
    bordered
    content-class="rich-text-editor__content"
    :toolbar="toolbar"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <template v-if="withTable" #insert_table>
      <q-btn dense flat no-caps size="sm" icon="table_chart" class="q-px-sm">
        <q-tooltip>Insert Table</q-tooltip>
        <q-menu
          anchor="bottom left"
          self="top left"
          :offset="[0, 4]"
          @before-show="onTableMenuOpen"
        >
          <div class="table-grid-picker q-pa-sm">
            <div v-for="row in gridSize" :key="`row-${row}`" class="table-grid-picker__row">
              <div
                v-for="col in gridSize"
                :key="`cell-${row}-${col}`"
                class="table-grid-picker__cell"
                :class="{ 'table-grid-picker__cell--active': row <= hoverRows && col <= hoverCols }"
                v-close-popup
                @mouseenter="
                  hoverRows = row;
                  hoverCols = col;
                "
                @click="onInsertTable(row, col)"
              />
            </div>
            <div class="text-caption text-grey-7 text-center q-mt-xs">
              {{ hoverRows }} × {{ hoverCols }} table
            </div>
          </div>
        </q-menu>
      </q-btn>
    </template>
  </q-editor>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';

import { insertTableAtCaret } from 'src/utils/editor';

const props = withDefaults(
  defineProps<{
    modelValue: string;
    minHeight?: string;
    withTable?: boolean;
  }>(),
  {
    minHeight: '6rem',
    withTable: true,
  },
);

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void;
}>();

const editorRef = ref<{
  focus?: () => void;
  caret?: { save?: () => void; restore?: () => void };
  $el?: HTMLElement;
} | null>(null);
const gridSize = 8;
const hoverRows = ref(3);
const hoverCols = ref(3);

const toolbar = computed(() => {
  const base: (string | string[])[] = [
    ['bold', 'italic', 'underline'],
    ['unordered', 'ordered'],
    ['undo', 'redo'],
  ];

  if (props.withTable) {
    base.push(['insert_table']);
  }

  return base;
});

const onTableMenuOpen = () => {
  hoverRows.value = 3;
  hoverCols.value = 3;
  editorRef.value?.caret?.save?.();
};

const onInsertTable = (rows: number, cols: number) => {
  insertTableAtCaret(editorRef.value, rows, cols);

  const contentEl = editorRef.value?.$el?.querySelector('.q-editor__content');
  if (contentEl) {
    emit('update:modelValue', contentEl.innerHTML);
  }
};
</script>

<style lang="scss">
.rich-text-editor__content {
  table,
  .rich-text-table {
    width: 100%;
    border-collapse: collapse;
    margin: 12px 0;
    border: 1px solid rgba(0, 0, 0, 0.24);
  }

  th,
  td {
    border: 1px solid rgba(0, 0, 0, 0.24);
    padding: 8px 12px;
    text-align: left;
    min-width: 40px;
    min-height: 24px;
  }

  th {
    background-color: rgba(0, 0, 0, 0.04);
    font-weight: bold;
  }
}

.table-grid-picker__row {
  display: flex;
  gap: 2px;
}

.table-grid-picker__row + .table-grid-picker__row {
  margin-top: 2px;
}

.table-grid-picker__cell {
  width: 16px;
  height: 16px;
  border: 1px solid rgba(0, 0, 0, 0.12);
  border-radius: 2px;
  cursor: pointer;
  background: #fff;
  transition:
    background-color 0.1s ease,
    border-color 0.1s ease;
}

.table-grid-picker__cell--active {
  background: var(--q-primary);
  border-color: var(--q-primary);
  opacity: 0.85;
}
</style>
