<template>
  <div class="schema-live">
    <div class="schema-banner">
      <div>
        <h3 class="schema-banner-title">Live schema</h3>
        <p class="schema-banner-copy">
          From <code>database.types.ts</code>. {{ filtered.length }} tables.
          ERD canvas with table cards and FK wires. Full tables stay in the grid below.
        </p>
      </div>
      <div class="schema-controls">
        <div class="schema-scope">
          <button
            v-for="mod in SCHEMA_MODULES"
            :key="mod.id"
            type="button"
            class="schema-scope-btn"
            :class="{ 'schema-scope-btn--active': moduleId === mod.id }"
            @click="moduleId = mod.id"
          >
            {{ mod.label }}
          </button>
          <button
            type="button"
            class="schema-scope-btn"
            :class="{ 'schema-scope-btn--active': moduleId === 'all' }"
            @click="moduleId = 'all'"
          >
            All
          </button>
        </div>
        <input
          v-model="search"
          type="search"
          class="schema-search"
          placeholder="Filter tables or columns"
        />
        <label class="schema-check">
          <input v-model="showColumns" type="checkbox" />
          Keys on ERD
        </label>
      </div>
    </div>

    <section v-if="slices.length" class="schema-erd-wrap">
      <section v-for="slice in slices" :key="slice.title" class="schema-slice">
        <h4 class="schema-slice-title">{{ slice.title }}</h4>
        <SchemaErdCanvas :tables="slice.tables" :keys-only="showColumns" />
      </section>
    </section>

    <h4 class="schema-slice-title">All columns</h4>
    <div class="schema-grid">
      <article v-for="table in filtered" :key="table.name" class="schema-card">
        <header class="schema-card-head">
          <span class="schema-card-name">{{ table.name }}</span>
          <span class="schema-card-meta">{{ table.columns.length }} cols</span>
        </header>
        <table class="schema-cols">
          <tbody>
            <tr v-for="col in table.columns" :key="col.name">
              <td><code>{{ col.name }}</code></td>
              <td class="schema-type">{{ shortType(col.type) }}</td>
              <td class="schema-null">{{ col.isNullable ? 'null' : '' }}</td>
            </tr>
          </tbody>
        </table>
        <ul v-if="table.relationships.length" class="schema-fks">
          <li v-for="rel in table.relationships" :key="rel.foreignKeyName">
            {{ rel.columns.join(', ') }} → {{ rel.referencedRelation }}
          </li>
        </ul>
      </article>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import typesSource from 'src/types/database.types.ts?raw';
import SchemaErdCanvas from 'src/components/dev/SchemaErdCanvas.vue';
import {
  SCHEMA_MODULES,
  filterTables,
  parseDatabaseTypes,
  tablesToErdSlices,
} from 'src/lib/schemaFromTypes';

const moduleId = ref('procurement');
const search = ref('');
const showColumns = ref(true);

const schema = parseDatabaseTypes(typesSource);

const filtered = computed(() =>
  filterTables(schema.tables, moduleId.value, search.value),
);

const slices = computed(() => tablesToErdSlices(filtered.value, moduleId.value));

function shortType(type: string): string {
  return type.replace(/\s*\|\s*null/g, '').slice(0, 48);
}
</script>

<style scoped>
.schema-live {
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px 20px 48px;
}
.schema-erd-wrap {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 28px;
}
.schema-slice {
  width: 100%;
  margin-bottom: 32px;
}
.schema-banner {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 20px;
}
.schema-banner-title {
  margin: 0 0 4px;
  font-size: 18px;
}
.schema-banner-copy {
  margin: 0;
  font-size: 13px;
  color: #64748b;
}
.schema-controls {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
}
.schema-scope-btn {
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 12px;
  cursor: pointer;
}
.schema-scope-btn--active {
  border-color: var(--bw-brand-accent, #0d6b5c);
  color: var(--bw-brand-accent, #0d6b5c);
  font-weight: 600;
}
.schema-search {
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 6px 10px;
  font-size: 13px;
  min-width: 180px;
}
.schema-check {
  font-size: 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  color: #64748b;
}
.schema-slice-title {
  margin: 0 0 12px;
  font-size: 14px;
  font-weight: 650;
}
.schema-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 12px;
}
.schema-card {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 10px 12px;
  background: #fff;
}
.schema-fks {
  margin: 8px 0 0;
  padding: 0;
  list-style: none;
  font-size: 11px;
  color: #475569;
}
.schema-null {
  color: #94a3b8;
  width: 36px;
}
.schema-card-head {
  display: flex;
  justify-content: space-between;
  margin-bottom: 6px;
}
.schema-card-name {
  font-weight: 650;
  font-size: 13px;
}
.schema-card-meta {
  font-size: 11px;
  color: #94a3b8;
}
.schema-cols {
  width: 100%;
  font-size: 12px;
  border-collapse: collapse;
}
.schema-cols td {
  padding: 2px 4px;
  vertical-align: top;
}
.schema-type {
  color: #64748b;
  word-break: break-all;
}
body.body--dark .schema-scope-btn,
body.body--dark .schema-search,
body.body--dark .schema-card {
  background: #18181b;
  border-color: #27272a;
  color: #e4e4e7;
}
</style>
