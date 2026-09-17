<template>
  <div class="dashboard-toolbar">
    <div class="dashboard-toolbar__left">
      <!-- Brand Filter Selector (Flat, Subtle) -->
      <q-select
        v-if="hasBrands"
        :model-value="selectedBrandId"
        :options="brandOptions"
        option-value="id"
        option-label="name"
        emit-value
        map-options
        dense
        outlined
        class="brand-select-input"
        :dark="isDark"
        :popup-content-class="isDark ? 'bg-dark text-white' : ''"
        @update:model-value="$emit('update:selectedBrandId', $event)"
      >
        <template #prepend>
          <q-icon name="ph ph-buildings" size="16px" class="text-slate-400" />
        </template>
        <template #selected-item="scope">
          <div class="row items-center no-wrap">
            <span class="text-slate-800 text-body2 text-weight-medium ellipsis">{{ scope.opt.name }}</span>
          </div>
        </template>
        <template #option="scope">
          <q-item v-bind="scope.itemProps" dense class="brand-item">
            <q-item-section>
              <q-item-label class="text-slate-800 text-body2 text-weight-medium">{{ scope.opt.name }}</q-item-label>
              <q-item-label caption class="text-slate-500 text-caption-xs">{{ scope.opt.subtitle }}</q-item-label>
            </q-item-section>
          </q-item>
        </template>
      </q-select>

      <!-- Date Range Pills (Minimalist Segmented Control) -->
      <div class="segmented-date-control">
        <button
          v-for="preset in datePresets"
          :key="preset.value"
          type="button"
          class="segmented-date-btn"
          :class="{ 'segmented-date-btn--active': dateRange === preset.value }"
          @click="$emit('update:dateRange', preset.value)"
        >
          {{ preset.label }}
        </button>
      </div>
    </div>

    <div class="dashboard-toolbar__right">
      <q-btn
        flat
        round
        dense
        icon="ph ph-arrows-clockwise"
        class="refresh-btn text-slate-500"
        :loading="loading"
        @click="$emit('refresh')"
      >
        <q-tooltip>Refresh</q-tooltip>
      </q-btn>

      <q-btn
        v-if="canProcurement"
        unelevated
        no-caps
        dense
        class="btn-secondary"
        icon="ph ph-plus"
        label="Inbound"
        :to="routes.procurementShipmentCreate()"
      />

      <q-btn
        unelevated
        no-caps
        dense
        class="btn-primary"
        icon="ph ph-plus"
        label="New Invoice"
        :to="routes.globalInvoicesCreate()"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuasar } from 'quasar';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useAppDashboardRoutes } from '../composables/useAppDashboardRoutes';

const $q = useQuasar();
const isDark = computed(() => $q.dark.isActive);

export type BrandOption = {
  id: number | null;
  name: string;
  subtitle: string;
};

const props = withDefaults(
  defineProps<{
    selectedBrandId: number | null;
    dateRange: string;
    loading?: boolean;
    customBrands?: BrandOption[];
  }>(),
  {
    loading: false,
  },
);

defineEmits<{
  (e: 'update:selectedBrandId', value: number | null): void;
  (e: 'update:dateRange', value: string): void;
  (e: 'refresh'): void;
}>();

const tenantStore = useTenantStore();
const { hasModuleAccess } = useModulePermissions();
const routes = useAppDashboardRoutes();

const canProcurement = computed(() => hasModuleAccess('global_stock', 'view'));

const datePresets = [
  { label: 'Today', value: 'today' },
  { label: '7 Days', value: '7d' },
  { label: '30 Days', value: '30d' },
  { label: 'This Month', value: 'month' },
];

const activeCompanyId = computed(() => {
  return tenantStore.selectedTenant?.parent_id ?? tenantStore.selectedTenant?.id ?? null;
});

const childBrandsUnderParent = computed(() => {
  if (!activeCompanyId.value) return [];
  return (tenantStore.hierarchyChildRefs ?? []).filter(
    (ref) => ref.parent_id === activeCompanyId.value,
  );
});

const hasBrands = computed(() => {
  if (props.customBrands) {
    return props.customBrands.length > 1;
  }
  return childBrandsUnderParent.value.length > 0;
});

const brandOptions = computed<BrandOption[]>(() => {
  if (props.customBrands?.length) {
    return props.customBrands;
  }

  const base: BrandOption[] = [
    {
      id: null,
      name: 'All Brands',
      subtitle: 'Consolidated overview',
    },
  ];

  for (const ref of childBrandsUnderParent.value) {
    base.push({
      id: ref.id,
      name: ref.name || `Brand #${ref.id}`,
      subtitle: `Brand desk #${ref.id}`,
    });
  }

  return base;
});
</script>

<style scoped>
.dashboard-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.25rem 0;
  min-height: 38px;
  flex-wrap: wrap;
}

.dashboard-toolbar__left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.dashboard-toolbar__right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.brand-select-input {
  min-width: 160px;
}

.brand-select-input :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
  padding: 0 10px;
  border-radius: 8px;
  border-color: #E2E8F0;
  background: #FFFFFF;
}

body.body--dark .brand-select-input :deep(.q-field__control) {
  background: #18181B;
  border-color: #27272A;
}

.brand-select-input :deep(.q-field__native) {
  min-height: 32px;
  padding: 0;
}

.brand-select-input :deep(.q-field__marginal) {
  height: 32px;
}

.segmented-date-control {
  display: flex;
  align-items: center;
  background: #F1F5F9;
  border-radius: 8px;
  padding: 2px;
  gap: 2px;
}

body.body--dark .segmented-date-control {
  background: #18181B;
}

.segmented-date-btn {
  border: none;
  background: transparent;
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 500;
  color: #64748B;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.segmented-date-btn:hover {
  color: #0F172A;
}

body.body--dark .segmented-date-btn {
  color: #A1A1AA;
}

body.body--dark .segmented-date-btn:hover {
  color: #F4F4F5;
}

.segmented-date-btn--active {
  background: #FFFFFF;
  color: #0F172A;
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}

body.body--dark .segmented-date-btn--active {
  background: #27272A;
  color: #F4F4F5;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
}

.btn-primary {
  background: var(--bw-brand-accent, #0d6b5c) !important;
  color: #FFFFFF !important;
  font-size: 12px;
  font-weight: 600;
  padding: 5px 12px;
  border-radius: 8px !important;
  height: 32px;
  transition: all 0.15s ease;
}

.btn-primary:hover {
  filter: brightness(1.1);
}

body.body--dark .btn-primary {
  background: var(--bw-brand-accent, #4db8a4) !important;
  color: #09090B !important;
}

.btn-secondary {
  background: #FFFFFF !important;
  border: 1px solid #E2E8F0;
  color: #334155 !important;
  font-size: 12px;
  font-weight: 500;
  padding: 5px 12px;
  border-radius: 8px !important;
  height: 32px;
  transition: all 0.15s ease;
}

.btn-secondary:hover {
  background: #F8FAFC !important;
  border-color: #CBD5E1;
}

body.body--dark .btn-secondary {
  background: #18181B !important;
  border-color: #27272A !important;
  color: #D4D4D8 !important;
}

.text-caption-xs {
  font-size: 10px;
}
.text-slate-400 { color: #94A3B8; }
.text-slate-500 { color: #64748B; }
.text-slate-800 { color: #1E293B; }

body.body--dark .text-slate-800 {
  color: #F4F4F5 !important;
}

body.body--dark .brand-select-input :deep(.q-field__control) {
  background: #18181B !important;
  border-color: #27272A !important;
}

body.body--dark .brand-select-input :deep(.text-slate-800) {
  color: #F4F4F5 !important;
}
</style>
