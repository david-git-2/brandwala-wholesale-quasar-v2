<template>
  <div class="erd-scroll">
    <div class="erd-canvas" :style="{ width: `${layout.width}px`, height: `${layout.height}px` }">
      <svg class="erd-wires" :width="layout.width" :height="layout.height">
        <path
          v-for="edge in paths"
          :key="edge.id"
          :d="edge.d"
          fill="none"
          stroke="rgba(226,232,240,0.55)"
          stroke-width="1.25"
        />
      </svg>
      <article
        v-for="node in layout.nodes"
        :key="node.table.name"
        class="erd-card"
        :style="{ left: `${node.x}px`, top: `${node.y}px`, width: `${node.w}px` }"
      >
        <header class="erd-card-head">
          <q-icon name="ph ph-table" size="14px" />
          <span>{{ node.table.name }}</span>
        </header>
        <div
          v-for="col in node.cols"
          :key="col.name"
          class="erd-row"
        >
          <q-icon :name="markIcon(node.table, col.name)" size="12px" class="erd-mark" />
          <span class="erd-col">{{ col.name }}</span>
          <span class="erd-type">{{ shortType(col.type) }}</span>
        </div>
      </article>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  erdAnchor,
  erdElbowPath,
  layoutErdCanvas,
  type SchemaTable,
} from 'src/lib/schemaFromTypes';

const props = defineProps<{
  tables: SchemaTable[];
  keysOnly: boolean;
}>();

const layout = computed(() => layoutErdCanvas(props.tables, props.keysOnly));

const paths = computed(() => {
  const byName = new Map(layout.value.nodes.map((n) => [n.table.name, n]));
  return layout.value.edges.flatMap((edge) => {
    const fromNode = byName.get(edge.fromTable);
    const toNode = byName.get(edge.toTable);
    if (!fromNode || !toNode) return [];
    const fromRight = fromNode.x + fromNode.w <= toNode.x;
    const from = erdAnchor(fromNode, edge.fromCol, fromRight ? 'right' : 'left');
    const to = erdAnchor(toNode, edge.toCol, fromRight ? 'left' : 'right');
    return [{ id: edge.id, d: erdElbowPath(from, to) }];
  });
});

function shortType(type: string): string {
  return type
    .replace(/\s*\|\s*null/g, '')
    .replace('number', 'int')
    .replace('boolean', 'bool')
    .replace('string', 'text')
    .slice(0, 18);
}

function markIcon(table: SchemaTable, colName: string): string {
  if (colName === 'id') return 'ph ph-key';
  if (table.relationships.some((r) => r.columns.includes(colName))) return 'ph ph-diamond';
  return 'ph ph-dot';
}
</script>

<style scoped>
.erd-scroll {
  border-radius: 12px;
  background: #0c0c0e;
  background-image: radial-gradient(rgba(255, 255, 255, 0.07) 1px, transparent 1px);
  background-size: 18px 18px;
}
.erd-canvas {
  position: relative;
}
.erd-wires {
  position: absolute;
  inset: 0;
  pointer-events: none;
}
.erd-card {
  position: absolute;
  background: #16161a;
  border: 1px solid #2a2a32;
  border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
  color: #ececef;
  overflow: hidden;
}
.erd-card-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  font-size: 13px;
  font-weight: 650;
  border-bottom: 1px solid #2a2a32;
}
.erd-row {
  display: grid;
  grid-template-columns: 18px 1fr auto;
  gap: 6px;
  align-items: center;
  padding: 5px 12px;
  font-size: 12px;
  min-height: 28px;
}
.erd-mark {
  color: #a1a1aa;
  opacity: 0.9;
}
.erd-col {
  font-weight: 550;
}
.erd-type {
  color: #8b8b98;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 11px;
}
</style>
