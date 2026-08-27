<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="purge-modal-card">
      <!-- Modal Header -->
      <q-card-section class="q-pa-md bg-negative text-white row items-center justify-between no-wrap">
        <div class="row items-center q-gutter-sm no-wrap">
          <q-avatar size="32px" color="white" text-color="negative" font-size="18px" square class="rounded-borders">
            <q-icon name="ph ph-warning-octagon" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bold">Reset Operational Data</div>
            <div class="text-caption opacity-80">{{ tenant.name }} ({{ tenant.slug }})</div>
          </div>
        </div>
        <q-btn v-close-popup flat round dense icon="ph ph-x" color="white" />
      </q-card-section>

      <q-card-section class="q-pa-md q-gutter-y-md">
        <!-- Warning Banner -->
        <div class="warning-callout q-pa-sm row items-start q-gutter-sm no-wrap">
          <q-icon name="ph ph-warning" color="negative" size="20px" class="q-mt-xs" />
          <div class="text-caption text-grey-9">
            <strong>Irreversible Action:</strong> This operation permanently wipes operational records (stocks, shipments, invoices, orders, carts, and ledgers).
            Master catalog, categories, locations, vendors, and user memberships are strictly preserved.
          </div>
        </div>

        <!-- Scope Selection -->
        <div>
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Select Wipe Scope:</div>
          <q-option-group
            v-model="selectedScope"
            :options="scopeOptions"
            color="negative"
            dense
            class="text-caption"
          />
        </div>

        <!-- Child Store Dropdown (Only visible when Specific Child Store Only is selected) -->
        <div v-if="selectedScope === 'child_only'" class="q-pl-sm">
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Select Target Sister Concern (Shop):</div>
          <q-select
            v-if="childOptions.length"
            v-model="selectedChildId"
            :options="childOptions"
            emit-value
            map-options
            outlined
            dense
            color="negative"
            placeholder="Select a child store"
          />
          <div v-else class="text-caption text-negative q-pa-xs">
            No child stores found under this parent organization.
          </div>
        </div>

        <!-- Impact Breakdown Summary -->
        <div>
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-weight-bold text-grey-8">Estimated Records to be Wiped:</span>
            <q-spinner v-if="isPreviewLoading" size="14px" color="negative" />
          </div>
          <div class="row q-col-gutter-xs">
            <div v-for="item in previewDisplayList" :key="item.label" class="col-6 col-sm-4">
              <div class="count-pill q-pa-xs text-center">
                <div class="text-weight-bolder text-negative text-body2">{{ item.count }}</div>
                <div class="text-caption text-grey-7 text-truncate">{{ item.label }}</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Preserved Checklist -->
        <div class="preserved-box q-pa-sm">
          <div class="text-caption text-weight-bold text-positive row items-center q-gutter-xs q-mb-xs">
            <q-icon name="ph ph-shield-check" size="16px" />
            <span>Strictly Preserved (Not Deleted)</span>
          </div>
          <div class="text-caption text-grey-7">
            Products, Variants, Categories, Tags, Stock Locations, Vendors, Customer Accounts, Roles & Permissions.
          </div>
        </div>

        <!-- Confirmation Phrase Input -->
        <div>
          <div class="text-caption text-grey-8 q-mb-xs">
            Type <strong class="text-negative">{{ expectedPhrase }}</strong> to confirm:
          </div>
          <q-input
            v-model="confirmationInput"
            outlined
            dense
            color="negative"
            placeholder="Type confirmation phrase here"
            autocomplete="off"
          />
        </div>
      </q-card-section>

      <q-separator />

      <!-- Modal Actions -->
      <q-card-actions align="right" class="q-pa-md q-gutter-sm">
        <q-btn
          v-close-popup
          flat
          dense
          no-caps
          label="Cancel"
          color="grey-8"
          class="pill-btn q-px-md"
          :disable="isSubmitting"
        />
        <q-btn
          unelevated
          dense
          no-caps
          color="negative"
          icon="ph ph-trash"
          label="Confirm & Wipe Data"
          class="pill-btn q-px-md"
          :loading="isSubmitting"
          :disable="!isConfirmed"
          @click="handlePurge"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, toRef, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { useTenantStore } from '../stores/tenantStore';
import { useTenantPurgeMutation, useTenantPurgePreviewQuery } from '../composables/useTenantPurge';
import type { Tenant } from '../types';

interface Props {
  modelValue: boolean;
  tenant: Tenant;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const tenantStore = useTenantStore();
const { items } = storeToRefs(tenantStore);

const selectedScope = ref<'all_hierarchy' | 'child_only'>('all_hierarchy');
const selectedChildId = ref<number | null>(null);
const confirmationInput = ref('');

const isModalOpen = toRef(props, 'modelValue');
const parentId = computed(() => props.tenant.id);

const scopeOptions = [
  {
    label: 'Full Organization Reset (Parent + All Sister Concern Desks)',
    value: 'all_hierarchy',
  },
  {
    label: 'Specific Child Store Only (Wipe local shop orders/invoices only)',
    value: 'child_only',
  },
];

const childTenants = computed(() => {
  return items.value.filter((t) => t.parent_id === props.tenant.id);
});

const childOptions = computed(() => {
  return childTenants.value.map((child) => ({
    label: `${child.name} (${child.slug})`,
    value: child.id,
  }));
});

watch(
  childTenants,
  (children) => {
    if (children.length && !selectedChildId.value) {
      selectedChildId.value = children[0]?.id ?? null;
    }
  },
  { immediate: true },
);

const activeTargetTenant = computed<Tenant | null>(() => {
  if (selectedScope.value === 'child_only' && selectedChildId.value) {
    return items.value.find((t) => t.id === selectedChildId.value) ?? null;
  }
  return props.tenant;
});

// TanStack Query preview hook
const { data: previewData, isLoading: isPreviewLoading } = useTenantPurgePreviewQuery(
  parentId,
  selectedScope,
  selectedChildId,
  isModalOpen,
);

const purgeMutation = useTenantPurgeMutation();
const isSubmitting = computed(() => purgeMutation.isPending.value);

const previewDisplayList = computed(() => {
  const counts = previewData.value;
  if (selectedScope.value === 'child_only') {
    return [
      { label: 'Shipments', count: '0 (Preserved)' },
      { label: 'Global Stocks', count: '0 (Preserved)' },
      { label: 'Invoices', count: counts ? String(counts.invoices) : '-' },
      { label: 'Shop Orders', count: counts ? String(counts.orders) : '-' },
      { label: 'Carts', count: counts ? String(counts.carts) : '-' },
      { label: 'Wallets', count: counts ? `${counts.wallets_to_reset} (Reset)` : '-' },
    ];
  }

  return [
    { label: 'Shipments', count: counts ? String(counts.shipments) : '-' },
    { label: 'Global Stocks', count: counts ? String(counts.stocks) : '-' },
    { label: 'Invoices', count: counts ? String(counts.invoices) : '-' },
    { label: 'Shop Orders', count: counts ? String(counts.orders) : '-' },
    { label: 'Carts', count: counts ? String(counts.carts) : '-' },
    { label: 'Ledgers & Wallets', count: counts ? String(counts.ledgers) : '-' },
  ];
});

const expectedPhrase = computed(() => {
  const target = activeTargetTenant.value;
  const slug = (target?.slug || props.tenant.slug || 'TENANT').toUpperCase();
  return `PURGE OPERATIONAL DATA ${slug}`;
});

const isConfirmed = computed(() => {
  if (selectedScope.value === 'child_only' && !selectedChildId.value) {
    return false;
  }
  return confirmationInput.value.trim() === expectedPhrase.value;
});

const handlePurge = async () => {
  if (!isConfirmed.value) return;

  const target = activeTargetTenant.value;
  const targetSlug = target?.slug || props.tenant.slug || '';

  try {
    await purgeMutation.mutateAsync({
      parentTenantId: props.tenant.id,
      scope: selectedScope.value,
      confirmationSlug: targetSlug,
      targetChildId: selectedScope.value === 'child_only' ? (selectedChildId.value ?? null) : null,
      targetName: target?.name || props.tenant.name,
    });

    emit('update:modelValue', false);
    confirmationInput.value = '';
  } catch {
    // Handled in composable onError
  }
};
</script>

<style scoped>
.purge-modal-card {
  width: 520px;
  max-width: 95vw;
  border-radius: 14px;
  overflow: hidden;
}

.warning-callout {
  border-radius: 8px;
  background: rgba(229, 57, 53, 0.08);
  border: 1px solid rgba(229, 57, 53, 0.2);
}

.preserved-box {
  border-radius: 8px;
  background: rgba(46, 125, 50, 0.06);
  border: 1px solid rgba(46, 125, 50, 0.2);
}

.count-pill {
  background: rgba(34, 56, 101, 0.04);
  border-radius: 6px;
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.pill-btn {
  border-radius: 8px;
}
</style>
