<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: 520px; max-width: 90vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">{{ dialogTitle }}</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-form @submit.prevent="onSubmit">
        <q-card-section class="q-gutter-y-md">
          <q-select
            v-model="form.kind"
            :options="kindOptions"
            label="Type *"
            dense
            outlined
            emit-value
            map-options
            class="soft-input"
            :disable="kindLocked || kindLockedOnEdit"
            :rules="[(v) => !!v || 'Type is required']"
            :hint="kindHint"
          />

          <div v-if="isEdit && props.location" class="q-mb-sm">
            <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Current place</div>
            <StockLocationHierarchyFields
              :locations="props.locations"
              :location-id="props.location.id"
            />
          </div>

          <q-select
            v-if="needsParent"
            v-model="form.parent_location_id"
            :options="parentOptions"
            label="Under *"
            dense
            outlined
            emit-value
            map-options
            class="soft-input"
            :rules="[(v) => v != null || 'Parent is required']"
          />

          <q-input
            v-model="form.code"
            label="Code *"
            dense
            outlined
            class="soft-input"
            :rules="[(v) => !!String(v || '').trim() || 'Code is required']"
            hint="Unique code (e.g. WH1, Z-A, S3-L2-B4)"
          />
          <q-input
            v-model="form.name"
            label="Name *"
            dense
            outlined
            class="soft-input"
            :rules="[(v) => !!String(v || '').trim() || 'Name is required']"
          />
          <div class="row q-col-gutter-md items-center">
            <div class="col-12 col-sm-4">
              <q-input
                v-model.number="form.sort_order"
                type="number"
                label="Sort order"
                dense
                outlined
                class="soft-input"
              />
            </div>
            <div class="col-6 col-sm-4">
              <q-toggle v-model="form.is_pickable" label="Pickable (sell)" />
            </div>
            <div class="col-6 col-sm-4">
              <q-toggle v-model="form.is_active" label="Active" />
            </div>
          </div>
          <q-toggle
            v-if="showDefaultToggle"
            v-model="form.is_default"
            label="Default put-away place"
            :disable="!form.is_active"
          />
          <div v-else class="text-caption bw-text-muted">
            Default put-away is only set on leaf bins (no children under them).
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
          <q-btn
            type="submit"
            color="primary"
            unelevated
            no-caps
            :label="isEdit ? 'Save' : 'Add'"
            :loading="saving"
            :disable="!canSubmit"
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import {
  STOCK_LOCATION_KIND_HINTS,
  STOCK_LOCATION_KIND_LABELS,
  STOCK_LOCATION_KIND_ORDER,
  STOCK_LOCATION_PARENT_KINDS,
  isRootStockLocationKind,
} from '../constants/stockLocationHierarchy';
import StockLocationHierarchyFields from './StockLocationHierarchyFields.vue';
import { collectDescendantLocationIds, formatStockLocationPath } from '../utils/stockLocationOptions';
import type {
  StockLocation,
  StockLocationKind,
  UpsertStockLocationPayload,
} from '../types/stockLocation';

const props = defineProps<{
  modelValue: boolean;
  location: StockLocation | null;
  locations: StockLocation[];
  presetKind?: StockLocationKind | null;
  presetParentId?: number | null;
  saving?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  save: [payload: UpsertStockLocationPayload];
}>();

const kindOptions = STOCK_LOCATION_KIND_ORDER.map((value) => ({
  label: STOCK_LOCATION_KIND_LABELS[value],
  value,
}));

const form = reactive({
  code: '',
  name: '',
  kind: 'warehouse' as StockLocationKind,
  parent_location_id: null as number | null,
  sort_order: 10,
  is_pickable: true,
  is_active: true,
  is_default: false,
});

const isEdit = computed(() => props.location != null);

const kindLocked = computed(() => Boolean(props.presetKind) && !isEdit.value);

const kindLockedOnEdit = computed(
  () => isEdit.value && childIds.value.has(props.location!.id),
);

const kindHint = computed(() => STOCK_LOCATION_KIND_HINTS[form.kind] ?? '');

const needsParent = computed(() => !isRootStockLocationKind(form.kind));

const childIds = computed(() => {
  const set = new Set<number>();
  for (const loc of props.locations) {
    if (loc.parent_location_id != null) set.add(loc.parent_location_id);
  }
  return set;
});

const isLeafCandidate = computed(() => {
  if (!isEdit.value) return true;
  return !childIds.value.has(props.location!.id);
});

const showDefaultToggle = computed(() => isLeafCandidate.value);

const invalidParentIds = computed(() => {
  if (!isEdit.value || !props.location) return new Set<number>();
  return collectDescendantLocationIds(props.locations, props.location.id);
});

const parentOptions = computed(() => {
  const allowed = STOCK_LOCATION_PARENT_KINDS[form.kind] ?? [];
  const blocked = invalidParentIds.value;
  return props.locations
    .filter(
      (l) => l.is_active && allowed.includes(l.kind) && !blocked.has(l.id),
    )
    .map((l) => {
      const path = formatStockLocationPath(props.locations, l.id);
      const suffix = path !== '—' ? ` · ${path}` : '';
      return { label: `${l.code} — ${l.name}${suffix}`, value: l.id };
    });
});

const dialogTitle = computed(() => {
  if (isEdit.value) return 'Edit place';
  const label = STOCK_LOCATION_KIND_LABELS[form.kind];
  return `Add ${label.toLowerCase()}`;
});

const canSubmit = computed(() => {
  if (!String(form.code).trim() || !String(form.name).trim() || !form.kind) return false;
  if (needsParent.value && form.parent_location_id == null) return false;
  return true;
});

const resetForm = () => {
  form.code = '';
  form.name = '';
  form.kind = props.presetKind ?? 'warehouse';
  form.parent_location_id = props.presetParentId ?? null;
  form.sort_order = 10;
  form.is_pickable = form.kind !== 'returns';
  form.is_active = true;
  form.is_default = false;
};

watch(
  () => [props.modelValue, props.location, props.presetKind, props.presetParentId] as const,
  ([open, location]) => {
    if (!open) return;
    if (location) {
      form.code = location.code;
      form.name = location.name;
      form.kind = location.kind;
      form.parent_location_id = location.parent_location_id;
      form.sort_order = location.sort_order;
      form.is_pickable = location.is_pickable;
      form.is_active = location.is_active;
      form.is_default = location.is_default;
    } else {
      resetForm();
    }
  },
);

watch(
  () => form.kind,
  (kind) => {
    if (isRootStockLocationKind(kind)) {
      form.parent_location_id = null;
    }
    if (kind === 'returns') {
      form.is_pickable = false;
    }
  },
);

const onSubmit = () => {
  if (!canSubmit.value) return;
  emit('save', {
    id: props.location?.id ?? null,
    code: form.code.trim(),
    name: form.name.trim(),
    kind: form.kind,
    parent_location_id: needsParent.value ? form.parent_location_id : null,
    sort_order: Number(form.sort_order) || 0,
    is_pickable: form.is_pickable,
    is_active: form.is_active,
    is_default: showDefaultToggle.value ? form.is_default : false,
  });
};
</script>
