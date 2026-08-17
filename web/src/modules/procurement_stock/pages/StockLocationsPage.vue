<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Procurement & Stock</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Shelves & boxes</h1>
          <div class="text-body2 text-grey-7 q-mt-xs">
            Shelves and boxes where warehouse stock sits.
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            v-if="canCreate && hasLocations"
            color="primary"
            unelevated
            no-caps
            label="Add shelf"
            @click="openCreate('shelf')"
          />
        </div>
      </section>

      <q-banner v-if="store.error" class="bw-status-banner bg-negative text-white">
        <div class="row items-center justify-between q-gutter-sm">
          <div>{{ store.error }}</div>
          <q-btn flat dense no-caps color="white" label="Retry" @click="reload" />
        </div>
      </q-banner>

      <StockLocationsSkeleton v-if="store.loading && !store.items.length" />

      <div
        v-else-if="!hasLocations"
        class="column flex-center empty-state stock-locations-empty text-center q-pa-xl"
      >
        <svg
          class="empty-state__art q-mb-md"
          width="160"
          height="120"
          viewBox="0 0 160 120"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          aria-hidden="true"
        >
          <rect
            x="18"
            y="22"
            width="124"
            height="78"
            rx="8"
            fill="var(--bw-theme-primary-soft)"
            stroke="var(--bw-theme-border)"
            stroke-width="1.5"
          />
          <rect x="28" y="34" width="104" height="8" rx="2" fill="var(--bw-theme-primary)" opacity="0.35" />
          <rect x="28" y="54" width="104" height="8" rx="2" fill="var(--bw-theme-primary)" opacity="0.35" />
          <rect x="28" y="74" width="104" height="8" rx="2" fill="var(--bw-theme-primary)" opacity="0.35" />
          <rect
            x="36"
            y="40"
            width="28"
            height="22"
            rx="3"
            fill="var(--bw-theme-surface)"
            stroke="var(--bw-theme-primary)"
            stroke-width="1.25"
          />
          <rect
            x="72"
            y="60"
            width="22"
            height="18"
            rx="3"
            fill="var(--bw-theme-surface)"
            stroke="var(--bw-theme-primary)"
            stroke-width="1.25"
          />
          <rect
            x="102"
            y="40"
            width="18"
            height="14"
            rx="2.5"
            fill="var(--bw-theme-surface)"
            stroke="var(--bw-theme-primary)"
            stroke-width="1.25"
            opacity="0.7"
          />
          <circle cx="128" cy="28" r="14" fill="var(--bw-theme-primary)" />
          <path
            d="M128 21v14M121 28h14"
            stroke="var(--bw-theme-surface)"
            stroke-width="2"
            stroke-linecap="round"
          />
        </svg>
        <div class="text-subtitle1 text-weight-medium q-mb-xs">No shelves yet</div>
        <div class="text-body2 bw-text-muted q-mb-md" style="max-width: 320px">
          Add a shelf to start organizing stock into slots and boxes.
        </div>
        <q-btn
          v-if="canCreate"
          color="primary"
          unelevated
          no-caps
          icon="ph ph-plus"
          label="Add shelf"
          @click="openCreate('shelf')"
        />
      </div>

      <template v-else>
        <q-card flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-input
                v-model="searchText"
                dense
                outlined
                clearable
                class="soft-input"
                placeholder="Search code or name"
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" />
                </template>
              </q-input>
            </div>
            <div class="col-auto row q-gutter-sm items-center">
              <q-select
                v-model="kindFilter"
                :options="kindFilterOptions"
                dense
                outlined
                emit-value
                map-options
                clearable
                label="Type"
                class="soft-input"
                style="min-width: 140px"
              />
              <q-toggle v-model="showInactive" label="Show inactive" dense />
            </div>
          </div>
        </q-card>

        <q-card flat bordered class="q-pa-none overflow-hidden" style="min-width: 0">
          <q-table
            flat
            :rows="visibleRows"
            :columns="columns"
            row-key="id"
            :loading="store.loading || store.saving"
            hide-pagination
            :pagination="{ rowsPerPage: 0 }"
          >
            <template #body-cell-name="props">
              <q-td :props="props">
                <div
                  class="row items-center no-wrap"
                  :style="{ paddingLeft: `${props.row.depth * 1.25}rem` }"
                >
                  <q-btn
                    v-if="props.row.children.length"
                    flat
                    dense
                    round
                    size="sm"
                    :icon="expanded.has(props.row.id) ? 'ph ph-caret-down' : 'ph ph-caret-right'"
                    @click="toggleExpand(props.row.id)"
                  />
                  <span v-else class="q-px-sm" style="width: 28px" />
                  <div>
                    <div class="text-weight-medium">{{ props.row.name }}</div>
                    <div class="text-caption bw-text-muted">{{ props.row.code }}</div>
                  </div>
                </div>
              </q-td>
            </template>

            <template #body-cell-kind="props">
              <q-td :props="props">
                <q-badge outline color="primary" :label="kindLabel(props.row.kind)" />
              </q-td>
            </template>

            <template #body-cell-is_default="props">
              <q-td :props="props" class="text-center">
                <q-icon
                  v-if="props.row.is_default"
                  name="ph ph-check-circle"
                  color="primary"
                  size="20px"
                >
                  <q-tooltip>Default put-away</q-tooltip>
                </q-icon>
                <span v-else class="bw-text-muted">—</span>
              </q-td>
            </template>

            <template #body-cell-is_pickable="props">
              <q-td :props="props" class="text-center">
                <q-icon
                  :name="props.row.is_pickable ? 'ph ph-check' : 'ph ph-minus'"
                  :color="props.row.is_pickable ? 'positive' : 'grey-5'"
                  size="18px"
                />
              </q-td>
            </template>

            <template #body-cell-is_active="props">
              <q-td :props="props" class="text-center">
                <q-badge
                  :color="props.row.is_active ? 'positive' : 'grey-5'"
                  :label="props.row.is_active ? 'Active' : 'Inactive'"
                />
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props" class="text-right">
                <q-btn
                  v-if="canCreate && props.row.kind === 'shelf'"
                  flat
                  dense
                  round
                  icon="ph ph-plus"
                  color="primary"
                  @click="openCreate('slot', props.row.id)"
                >
                  <q-tooltip>Add slot</q-tooltip>
                </q-btn>
                <q-btn
                  v-if="canCreate && props.row.kind === 'slot'"
                  flat
                  dense
                  round
                  icon="ph ph-plus"
                  color="primary"
                  @click="openCreate('box', props.row.id)"
                >
                  <q-tooltip>Add box</q-tooltip>
                </q-btn>
                <q-btn
                  v-if="canCreate && props.row.kind === 'returns'"
                  flat
                  dense
                  round
                  icon="ph ph-plus"
                  color="primary"
                  @click="openCreate('slot', props.row.id)"
                >
                  <q-tooltip>Add slot</q-tooltip>
                </q-btn>
                <q-btn
                  v-if="canEdit && props.row.isLeaf && !props.row.is_default && props.row.is_active"
                  flat
                  dense
                  round
                  icon="ph ph-star"
                  color="grey-7"
                  :loading="store.saving"
                  @click="onSetDefault(props.row)"
                >
                  <q-tooltip>Set as default put-away</q-tooltip>
                </q-btn>
                <q-btn
                  v-if="canEdit"
                  flat
                  dense
                  round
                  icon="ph ph-pencil-simple"
                  color="grey-7"
                  @click="openEdit(props.row)"
                >
                  <q-tooltip>Edit</q-tooltip>
                </q-btn>
                <q-btn
                  v-if="canDelete"
                  flat
                  dense
                  round
                  icon="ph ph-trash"
                  color="negative"
                  :loading="store.saving"
                  @click="onDelete(props.row)"
                >
                  <q-tooltip>Delete</q-tooltip>
                </q-btn>
              </q-td>
            </template>

            <template #no-data>
              <div class="column items-center q-pa-xl empty-state text-center">
                <q-icon name="ph ph-funnel-simple" size="48px" color="grey-4" class="q-mb-md" />
                <div class="text-subtitle1 text-weight-medium q-mb-xs">No matching places</div>
                <div class="text-body2 bw-text-muted q-mb-md" style="max-width: 320px">
                  Try clearing filters or searching a different code.
                </div>
                <q-btn
                  flat
                  no-caps
                  color="grey-7"
                  label="Clear filters"
                  @click="clearFilters"
                />
              </div>
            </template>
          </q-table>
        </q-card>
      </template>

      <StockLocationFormDialog
        v-model="dialogOpen"
        :location="editingLocation"
        :locations="store.items"
        :preset-kind="presetKind"
        :preset-parent-id="presetParentId"
        :saving="store.saving"
        @save="onSave"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import StockLocationFormDialog from '../components/StockLocationFormDialog.vue';
import StockLocationsSkeleton from '../components/StockLocationsSkeleton.vue';
import { useStockLocationStore } from '../stores/stockLocationStore';
import type {
  StockLocation,
  StockLocationKind,
  StockLocationTreeNode,
  UpsertStockLocationPayload,
} from '../types/stockLocation';

const authStore = useAuthStore();
const store = useStockLocationStore();
const { hasModuleAccess } = useModulePermissions();

const canCreate = computed(() => hasModuleAccess('global_stock_location', 'create'));
const canEdit = computed(() => hasModuleAccess('global_stock_location', 'edit'));
const canDelete = computed(
  () =>
    hasModuleAccess('global_stock_location', 'delete') ||
    hasModuleAccess('global_stock_location', 'edit'),
);

const searchText = ref('');
const kindFilter = ref<StockLocationKind | null>(null);
const showInactive = ref(true);
const dialogOpen = ref(false);
const editingLocation = ref<StockLocation | null>(null);
const presetKind = ref<StockLocationKind | null>(null);
const presetParentId = ref<number | null>(null);
const expanded = ref(new Set<number>());

const kindFilterOptions: { label: string; value: StockLocationKind }[] = [
  { label: 'Shelf', value: 'shelf' },
  { label: 'Slot', value: 'slot' },
  { label: 'Box', value: 'box' },
  { label: 'Returns', value: 'returns' },
];

const kindLabel = (kind: StockLocationKind) => {
  if (kind === 'returns') return 'Returns';
  return kind.charAt(0).toUpperCase() + kind.slice(1);
};

const columns: QTableColumn[] = [
  { name: 'name', label: 'Place', field: 'name', align: 'left' },
  { name: 'kind', label: 'Type', field: 'kind', align: 'left' },
  { name: 'is_default', label: 'Default', field: 'is_default', align: 'center' },
  { name: 'is_pickable', label: 'Pickable', field: 'is_pickable', align: 'center' },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'center' },
  { name: 'actions', label: '', field: 'actions', align: 'right' },
];

const hasLocations = computed(() => store.items.length > 0);

const hasActiveFilters = computed(
  () => Boolean(searchText.value?.trim()) || kindFilter.value != null || !showInactive.value,
);

const childParentIds = computed(() => {
  const set = new Set<number>();
  for (const loc of store.items) {
    if (loc.parent_location_id != null) set.add(loc.parent_location_id);
  }
  return set;
});

const buildTree = (items: StockLocation[]): StockLocationTreeNode[] => {
  const byParent = new Map<number | null, StockLocation[]>();
  for (const item of items) {
    const key = item.parent_location_id;
    const list = byParent.get(key) ?? [];
    list.push(item);
    byParent.set(key, list);
  }
  for (const list of byParent.values()) {
    list.sort((a, b) => a.sort_order - b.sort_order || a.code.localeCompare(b.code));
  }

  const walk = (parentId: number | null, depth: number): StockLocationTreeNode[] => {
    const children = byParent.get(parentId) ?? [];
    return children.map((loc) => {
      const kids = walk(loc.id, depth + 1);
      const hasActiveChild = store.items.some(
        (i) => i.parent_location_id === loc.id && i.is_active,
      );
      return {
        ...loc,
        children: kids,
        depth,
        isLeaf: !hasActiveChild,
      };
    });
  };

  // Roots: null parent. Also attach orphans under a synthetic root by treating missing parents as root.
  const roots = walk(null, 0);
  const rootedIds = new Set<number>();
  const mark = (nodes: StockLocationTreeNode[]) => {
    for (const n of nodes) {
      rootedIds.add(n.id);
      mark(n.children);
    }
  };
  mark(roots);
  for (const item of items) {
    if (!rootedIds.has(item.id) && item.parent_location_id != null) {
      // orphan — show as root so it is not lost
      roots.push({
        ...item,
        children: [],
        depth: 0,
        isLeaf: !childParentIds.value.has(item.id),
      });
    }
  }
  return roots;
};

const matchesFilter = (loc: StockLocation) => {
  if (!showInactive.value && !loc.is_active) return false;
  if (kindFilter.value && loc.kind !== kindFilter.value) return false;
  const q = searchText.value.trim().toLowerCase();
  if (!q) return true;
  return loc.code.toLowerCase().includes(q) || loc.name.toLowerCase().includes(q);
};

const filteredItems = computed(() => store.items.filter(matchesFilter));

/** When searching/filtering, include ancestors so tree context remains */
const itemsForTree = computed(() => {
  if (!hasActiveFilters.value) return store.items.filter((i) => showInactive.value || i.is_active);
  const matched = new Set(filteredItems.value.map((i) => i.id));
  const byId = new Map(store.items.map((i) => [i.id, i]));
  const include = new Set(matched);
  for (const id of matched) {
    let cur = byId.get(id);
    while (cur?.parent_location_id != null) {
      include.add(cur.parent_location_id);
      cur = byId.get(cur.parent_location_id);
    }
  }
  return store.items.filter((i) => include.has(i.id));
});

const tree = computed(() => buildTree(itemsForTree.value));

const flattenVisible = (nodes: StockLocationTreeNode[]): StockLocationTreeNode[] => {
  const out: StockLocationTreeNode[] = [];
  for (const node of nodes) {
    out.push(node);
    if (node.children.length && expanded.value.has(node.id)) {
      out.push(...flattenVisible(node.children));
    }
  }
  return out;
};

const visibleRows = computed(() => flattenVisible(tree.value));

watch(
  tree,
  (nodes) => {
    // Expand roots by default
    const next = new Set(expanded.value);
    for (const n of nodes) {
      if (n.children.length) next.add(n.id);
    }
    expanded.value = next;
  },
  { immediate: true },
);

const toggleExpand = (id: number) => {
  const next = new Set(expanded.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  expanded.value = next;
};

const clearFilters = () => {
  searchText.value = '';
  kindFilter.value = null;
  showInactive.value = true;
};

const reload = async () => {
  if (!authStore.tenantId) return;
  try {
    await store.fetchLocations(authStore.tenantId, true);
  } catch {
    // store.error set
  }
};

const openCreate = (kind: StockLocationKind = 'shelf', parentId: number | null = null) => {
  editingLocation.value = null;
  presetKind.value = kind;
  presetParentId.value = parentId;
  dialogOpen.value = true;
};

const openEdit = (row: StockLocation) => {
  editingLocation.value = row;
  presetKind.value = null;
  presetParentId.value = null;
  dialogOpen.value = true;
};

const onSave = async (payload: UpsertStockLocationPayload) => {
  if (!authStore.tenantId) return;
  try {
    await store.upsertLocation(authStore.tenantId, payload);
    dialogOpen.value = false;
    showSuccessNotification(payload.id ? 'Place updated' : 'Place added');
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to save');
  }
};

const onSetDefault = async (row: StockLocation) => {
  const currentDefault = store.items.find((item) => item.is_default && item.is_active);
  if (currentDefault && currentDefault.id !== row.id) {
    const ok = await requestConfirmation(
      `Replace default "${currentDefault.code}" with "${row.code}"?`,
      'Set default put-away',
      'Set default',
    );
    if (!ok) return;
  }
  try {
    await store.setDefault(row.id);
    showSuccessNotification(`${row.code} is now the default put-away`);
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to set default');
  }
};

const onDelete = async (row: StockLocation) => {
  const childHint =
    row.kind === 'shelf' || row.kind === 'returns' || row.kind === 'slot'
      ? ' Any slots/boxes under it will be deleted too.'
      : '';
  const ok = await requestConfirmation(
    `Delete "${row.code}"?${childHint}`,
    'Delete place',
    'Delete',
  );
  if (!ok || !authStore.tenantId) return;
  try {
    await store.deleteLocation(authStore.tenantId, row.id);
    showSuccessNotification('Place deleted');
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to delete');
  }
};

onMounted(() => {
  void reload();
});
</script>

<style scoped>
.stock-locations-empty {
  min-height: calc(100vh - 180px);
  width: 100%;
}
</style>
