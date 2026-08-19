<template>
  <div class="children-tab-col col column q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="row items-center q-gutter-x-sm">
        <q-input
          v-model="childSearch"
          placeholder="Filter child files by name/ref..."
          outlined
          dense
          clearable
          style="min-width: 280px"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>
        <q-btn
          flat
          dense
          no-caps
          icon="ph ph-arrows-clockwise"
          label="Refresh"
          :loading="loadingChildLines"
          @click="fetchChildLines"
        />
      </div>
      <div class="text-caption text-grey-7">
        Showing eligible child procurement files (Orders & Costing files in Ready for Shipment)
      </div>
    </div>

    <div class="col scroll relative-position">
      <q-inner-loading :showing="loadingChildLines" />
      <q-table
        flat
        bordered
        :rows="groupedChildFiles"
        :columns="childFileColumns"
        row-key="group_key"
        dense
        hide-pagination
        class="full-width"
        :pagination="{ rowsPerPage: 0 }"
      >
        <template #body-cell-source_type_label="props">
          <q-td :props="props">
            <q-chip
              dense
              square
              :color="props.row.source_type_label.includes('Costing') ? 'teal-1' : 'blue-1'"
              :text-color="props.row.source_type_label.includes('Costing') ? 'teal-9' : 'blue-9'"
              class="text-weight-bold text-caption"
            >
              {{ props.row.source_type_label }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-reference_label="props">
          <q-td :props="props">
            <div class="text-weight-bold ellipsis" style="max-width: 280px" :title="props.value">
              {{ props.value }}
            </div>
          </q-td>
        </template>

        <template #body-cell-child_tenant_name="props">
          <q-td :props="props">
            <div class="ellipsis" style="max-width: 140px" :title="props.value">
              {{ props.value }}
            </div>
          </q-td>
        </template>

        <template #body-cell-item_count="props">
          <q-td :props="props" class="text-right">
            <q-badge color="grey-3" text-color="grey-9" class="text-weight-medium">
              {{ props.value }} {{ props.value === 1 ? 'item' : 'items' }}
            </q-badge>
          </q-td>
        </template>

        <template #body-cell-action="props">
          <q-td :props="props" class="text-right">
            <q-btn
              color="primary"
              unelevated
              dense
              no-caps
              size="sm"
              icon="ph ph-plus"
              label="Add All to Shipment"
              :loading="pullingGroupKey === props.row.group_key"
              @click="onPullChildFile(props.row)"
            />
          </q-td>
        </template>
      </q-table>
    </div>

    <div class="panel-footer q-pa-md">
      <q-btn
        unelevated
        no-caps
        color="primary"
        label="Done"
        class="full-width"
        @click="$emit('done')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { globalShipmentRepository, type GlobalShipmentItem } from '../repositories/globalShipmentRepository';

const props = defineProps<{
  shipmentId: number;
}>();

const emit = defineEmits<{
  done: [];
  countUpdated: [count: number];
}>();

const $q = useQuasar();
const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();

interface GroupedChildFile {
  group_key: string;
  source_type_label: string;
  reference_label: string;
  child_tenant_name: string;
  item_count: number;
  total_quantity: number;
  total_price_gbp: number;
  lines: any[];
}

const childSearch = ref('');
const childLines = ref<any[]>([]);
const loadingChildLines = ref(false);
const pullingGroupKey = ref<string | null>(null);

const childFileColumns: Array<{
  name: string;
  label: string;
  field: string | ((row: any) => any);
  align?: 'left' | 'right' | 'center';
  style?: string;
  format?: (val: any) => string;
}> = [
  { name: 'source_type_label', label: 'Type', field: 'source_type_label', align: 'left', style: 'width: 100px' },
  { name: 'reference_label', label: 'File / Reference', field: 'reference_label', align: 'left' },
  { name: 'child_tenant_name', label: 'Child Tenant', field: 'child_tenant_name', align: 'left', style: 'width: 130px' },
  { name: 'item_count', label: 'Items', field: 'item_count', align: 'right', style: 'width: 90px' },
  { name: 'total_quantity', label: 'Total Qty', field: 'total_quantity', align: 'right', style: 'width: 100px' },
  {
    name: 'total_price_gbp',
    label: 'Total Value',
    field: 'total_price_gbp',
    align: 'right',
    style: 'width: 110px',
    format: (val: any) => (val != null && !isNaN(Number(val)) ? `£${Number(val).toFixed(2)}` : '—'),
  },
  { name: 'action', label: '', field: 'action', align: 'right', style: 'width: 160px' },
];

const groupedChildFiles = computed<GroupedChildFile[]>(() => {
  const map = new Map<string, GroupedChildFile>();
  const q = (childSearch.value || '').trim().toLowerCase();

  for (const line of childLines.value) {
    const groupKey = `${line.reference_label}||${line.child_tenant_name}`;
    let group = map.get(groupKey);

    if (!group) {
      group = {
        group_key: groupKey,
        source_type_label: line.source_type === 'costing_item' ? 'Costing' : 'Order',
        reference_label: line.reference_label || 'Untitled File',
        child_tenant_name: line.child_tenant_name || '',
        item_count: 0,
        total_quantity: 0,
        total_price_gbp: 0,
        lines: [],
      };
      map.set(groupKey, group);
    }

    group.lines.push(line);
    group.item_count += 1;
    group.total_quantity += Number(line.quantity) || 0;
    group.total_price_gbp += (Number(line.quantity) || 0) * (Number(line.price_gbp) || 0);
  }

  const result = Array.from(map.values());
  emit('countUpdated', result.length);

  if (!q) return result;

  return result.filter(
    (file) =>
      file.reference_label.toLowerCase().includes(q) ||
      file.child_tenant_name.toLowerCase().includes(q) ||
      file.lines.some((l) => (l.name || '').toLowerCase().includes(q)),
  );
});

const fetchChildLines = async () => {
  const parentTenantId = authStore.tenantId;
  if (!parentTenantId) return;

  loadingChildLines.value = true;
  try {
    const rawLines = await globalShipmentRepository.listChildProcurementLines(parentTenantId);
    childLines.value = (rawLines ?? []).map((line: any) => ({
      ...line,
      source_key: `${line.source_type}:${line.source_id}`,
    }));
  } catch (err) {
    console.error('Failed to fetch child procurement lines:', err);
  } finally {
    loadingChildLines.value = false;
  }
};

const onPullChildFile = async (file: GroupedChildFile) => {
  pullingGroupKey.value = file.group_key;
  try {
    const results = await Promise.all(
      file.lines.map((line) =>
        globalShipmentRepository.addChildLineToParentShipment(
          props.shipmentId,
          line.source_type,
          line.source_id,
        ),
      ),
    );
    const addedItems = results.flatMap((row) => {
      if (!row) return [];
      return (Array.isArray(row) ? row : [row]) as GlobalShipmentItem[];
    }).filter((item) => item?.id != null);
    shipmentStore.mergeShipmentItems(props.shipmentId, addedItems);
    $q.notify({
      type: 'positive',
      message: `Added ${addedItems.length} item${addedItems.length === 1 ? '' : 's'} from "${file.reference_label}".`,
    });
    await fetchChildLines();
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: err instanceof Error ? err.message : 'Failed to pull file into shipment.',
    });
  } finally {
    pullingGroupKey.value = null;
  }
};

onMounted(() => {
  void fetchChildLines();
});

defineExpose({
  fetchChildLines,
  groupedCount: computed(() => groupedChildFiles.value.length),
});
</script>

<style scoped>
.children-tab-col {
  min-height: 0;
  overflow: hidden;
}

.children-tab-col :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #ffffff;
}

.panel-footer {
  border-top: 1px solid rgba(226, 232, 240, 0.8);
  background: rgba(248, 250, 252, 0.5);
}
</style>
