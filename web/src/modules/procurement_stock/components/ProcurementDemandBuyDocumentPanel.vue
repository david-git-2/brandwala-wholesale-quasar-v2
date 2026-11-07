<template>
  <q-page class="q-px-xs q-py-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-card flat bordered class="flex-shrink-0 q-pa-sm">
        <div class="row items-center no-wrap q-gutter-x-xs q-mb-sm">
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-left"
            color="grey-8"
            aria-label="Back to demand list"
            @click="goBack"
          />
          <div class="col min-width-0">
            <h1 class="text-subtitle1 text-weight-bold q-my-none ellipsis">{{ pageTitle }}</h1>
            <p v-if="documentHeader?.profile_name" class="text-caption text-grey-7 q-mb-none ellipsis">
              {{ documentHeader.profile_name }}
              <span v-if="documentHeader.customer_group_name">
                · {{ documentHeader.customer_group_name }}
              </span>
            </p>
          </div>
          <q-btn
            v-if="documentDirty"
            unelevated
            no-caps
            color="primary"
            icon="ph ph-floppy-disk"
            label="Save"
            class="col-shrink"
            :loading="saveLoading"
            @click="saveDocument"
          />
        </div>
        <q-input
          v-model="searchText"
          outlined
          dense
          hide-bottom-space
          clearable
          debounce="300"
          placeholder="Search lines…"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>

        <div
          class="row items-center no-wrap q-gutter-x-sm q-mt-sm demand-bulk-bar"
        >
          <q-checkbox
            dense
            :model-value="allVisibleLinesSelected"
            :indeterminate="someVisibleLinesSelected && !allVisibleLinesSelected"
            label="All loaded lines"
            class="demand-bulk-bar__select-all"
            @update:model-value="onToggleSelectAllLines"
          />
          <span v-if="selectedLineCount > 0" class="text-caption text-grey-7 col-shrink">
            {{ selectedLineCount }} selected
          </span>
          <q-select
            v-model="bulkVendorCode"
            :options="bulkVendorCodeOptions"
            option-value="code"
            option-label="label"
            emit-value
            map-options
            outlined
            dense
            options-dense
            hide-bottom-space
            clearable
            use-input
            input-debounce="200"
            placeholder="Vendor"
            class="demand-bulk-bar__vendor min-width-0"
            @filter="onBulkFilterVendors"
          />
          <q-btn
            unelevated
            no-caps
            dense
            color="primary"
            label="Bulk update"
            class="col-shrink"
            :disable="!bulkVendorCode?.trim() || selectedLineCount === 0"
            @click="applyBulkVendor"
          />
        </div>
      </q-card>

      <div class="col scroll-y-min">
        <div
          v-if="detailQuery.isLoading.value && detailItems.length === 0"
          class="row justify-center q-py-xl"
        >
          <q-spinner-dots size="32px" color="primary" />
        </div>
        <ProcurementDemandBuyLines
          v-else-if="documentType && documentId"
          :items="detailItems"
          :line-drafts="lineDrafts"
          :vendor-code-options="vendorCodeOptions"
          :selected-line-keys="selectedLineKeys"
          :is-fetching-next-page="detailQuery.isFetchingNextPage.value"
          @filter-vendors="filterVendors"
          @update-draft="onUpdateLineDraft"
          @toggle-line-select="onToggleLineSelect"
          @load-more="onLoadMoreItems"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, onBeforeUnmount, reactive, ref, watch } from 'vue';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';
import type { Vendor } from 'src/modules/vendor/types';
import {
  parseSupabaseError,
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import { useProcurementDemandBuyDocumentInfiniteQuery } from '../composables/useProcurementDemandBuyDocumentInfiniteQuery';
import { useUpsertPreorderDemandMutation } from '../composables/useProcurementPlacementMutations';
import ProcurementDemandBuyLines from './ProcurementDemandBuyLines.vue';
import type {
  ProcurementDemandDocumentType,
  ProcurementDemandItem,
  ProcurementDemandStatus,
} from '../repositories/procurementDemandRepository';
import {
  cloneLineDraft,
  type DemandBuyLineDraft,
  itemDraftKey,
  normalizePlacementsForSave,
  placementsFromItem,
  serializePlacements,
  validatePlacementDrafts,
} from '../utils/demandBuyPlacements';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const queryClient = useQueryClient();

const documentType = computed((): ProcurementDemandDocumentType | null => {
  const raw = route.params.documentType;
  const t = typeof raw === 'string' ? raw : raw?.[0];
  if (t === 'shop_order' || t === 'pbc_costing_file') return t;
  return null;
});

const documentId = computed((): number | null => {
  const raw = route.params.documentId;
  const id = Number(typeof raw === 'string' ? raw : raw?.[0]);
  return Number.isFinite(id) ? id : null;
});

const searchText = ref('');
const debouncedSearch = ref('');
let searchDebounceTimer: ReturnType<typeof setTimeout> | undefined;
watch(searchText, (v) => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(() => {
    debouncedSearch.value = v.trim();
  }, 300);
});

const buyProcurementStatus = ref<ProcurementDemandStatus>('procuring');

const parentTenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId ?? null,
);

const detailQuery = useProcurementDemandBuyDocumentInfiniteQuery({
  tenantId: parentTenantId,
  documentType,
  documentId,
  search: debouncedSearch,
  enabled: computed(() => documentType.value != null && documentId.value != null),
});

const detailItems = computed(() => detailQuery.demandItems.value);
const documentHeader = computed(() => detailQuery.documentHeader.value);

const pageTitle = computed(() => {
  const qName =
    typeof route.query.documentName === 'string' ? route.query.documentName.trim() : '';
  if (qName) return qName;
  const h = documentHeader.value;
  if (h) {
    return h.shop_order_no?.trim() || h.document_name?.trim() || `#${h.document_id}`;
  }
  if (documentId.value) return `#${documentId.value}`;
  return 'Demand document';
});

const lineDrafts = reactive<Record<string, DemandBuyLineDraft>>({});
const baselineByLine = reactive<Record<string, string>>({});

const selectedLineKeys = reactive<Record<string, boolean>>({});
const bulkVendorFilter = ref('');
const bulkVendorCode = ref<string | null>(null);

const vendorFilter = ref('');
const { data: vendorsData } = useQuery({
  queryKey: computed(() => ['vendors', 'demandBuyDoc', parentTenantId.value]),
  queryFn: () => vendorRepository.listVendors(parentTenantId.value!),
  enabled: computed(() => parentTenantId.value != null),
});

const vendorCodeOptions = computed(() => {
  const needle = vendorFilter.value.trim().toLowerCase();
  return ((vendorsData.value ?? []) as Vendor[])
    .filter((v) => {
      if (!needle) return true;
      return v.name.toLowerCase().includes(needle) || v.code.toLowerCase().includes(needle);
    })
    .map((v) => ({
      code: v.code.trim(),
      label: v.code.trim() || v.name,
    }));
});

const filterVendors = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    vendorFilter.value = val;
  });
};

const bulkVendorCodeOptions = computed(() => {
  const needle = bulkVendorFilter.value.trim().toLowerCase();
  return ((vendorsData.value ?? []) as Vendor[])
    .filter((v) => {
      if (!needle) return true;
      return v.name.toLowerCase().includes(needle) || v.code.toLowerCase().includes(needle);
    })
    .map((v) => ({
      code: v.code.trim(),
      label: v.code.trim() || v.name,
    }));
});

const onBulkFilterVendors = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    bulkVendorFilter.value = val;
  });
};

const visibleLineKeys = computed(() => detailItems.value.map((i) => itemDraftKey(i)));

const allVisibleLinesSelected = computed(() => {
  const keys = visibleLineKeys.value;
  return keys.length > 0 && keys.every((k) => selectedLineKeys[k]);
});

const someVisibleLinesSelected = computed(() =>
  visibleLineKeys.value.some((k) => selectedLineKeys[k]),
);

const selectedLineCount = computed(
  () => visibleLineKeys.value.filter((k) => selectedLineKeys[k]).length,
);

const onToggleSelectAllLines = (val: boolean) => {
  for (const key of visibleLineKeys.value) {
    if (val) selectedLineKeys[key] = true;
    else delete selectedLineKeys[key];
  }
};

const onToggleLineSelect = (item: ProcurementDemandItem, selected: boolean) => {
  const key = itemDraftKey(item);
  if (selected) selectedLineKeys[key] = true;
  else delete selectedLineKeys[key];
};

const lineNeedQty = (item: ProcurementDemandItem) =>
  item.need_quantity ?? item.quantity ?? 0;

const applyBulkVendor = () => {
  const code = bulkVendorCode.value?.trim();
  if (!code) {
    showErrorNotification('Choose a vendor.');
    return;
  }
  const keys = visibleLineKeys.value.filter((k) => selectedLineKeys[k]);
  if (keys.length === 0) {
    showErrorNotification('Select at least one line.');
    return;
  }
  const keySet = new Set(keys);
  for (const item of detailItems.value) {
    const key = itemDraftKey(item);
    if (!keySet.has(key)) continue;
    const need = lineNeedQty(item);
    if (need <= 0) continue;
    lineDrafts[key] = cloneLineDraft({
      placements: [{ vendorCode: code, quantity: need }],
    });
  }
  showSuccessNotification(`Vendor set on ${keys.length} line(s). Save to persist.`);
};

const syncDraftsFromItems = (items: ProcurementDemandItem[]) => {
  for (const item of items) {
    const key = itemDraftKey(item);
    if (baselineByLine[key] != null) continue;
    const draft: DemandBuyLineDraft = { placements: placementsFromItem(item) };
    lineDrafts[key] = cloneLineDraft(draft);
    baselineByLine[key] = serializePlacements(draft.placements);
  }
};

watch(detailItems, (items) => syncDraftsFromItems(items), { immediate: true });

watch([documentType, documentId], () => {
  for (const key of Object.keys(lineDrafts)) delete lineDrafts[key];
  for (const key of Object.keys(baselineByLine)) delete baselineByLine[key];
  for (const key of Object.keys(selectedLineKeys)) delete selectedLineKeys[key];
  bulkVendorCode.value = null;
});

const documentDirty = computed(() =>
  detailItems.value.some((item) => {
    const key = itemDraftKey(item);
    const draft = lineDrafts[key];
    if (!draft) return false;
    return serializePlacements(draft.placements) !== baselineByLine[key];
  }),
);

const upsertMutation = useUpsertPreorderDemandMutation({
  tenantId: parentTenantId,
  procurementStatus: buyProcurementStatus,
  search: debouncedSearch,
});

const saveLoading = ref(false);

const confirmDiscardIfDirty = async (): Promise<boolean> => {
  if (!documentDirty.value) return true;
  return requestConfirmation(
    'You have unsaved vendor orders. Discard changes?',
    'Unsaved changes',
    'Discard',
  );
};

const onUpdateLineDraft = (item: ProcurementDemandItem, draft: DemandBuyLineDraft) => {
  lineDrafts[itemDraftKey(item)] = cloneLineDraft(draft);
};

const onLoadMoreItems = () => {
  if (detailQuery.hasMoreItems.value && !detailQuery.isFetchingNextPage.value) {
    void detailQuery.fetchNextPage();
  }
};

const saveDocument = async () => {
  if (!parentTenantId.value) return;
  const items = detailItems.value;
  const changed = items.filter((item) => {
    const key = itemDraftKey(item);
    const draft = lineDrafts[key];
    if (!draft) return false;
    return serializePlacements(draft.placements) !== baselineByLine[key];
  });
  if (changed.length === 0) return;

  for (const item of changed) {
    const key = itemDraftKey(item);
    const draft = lineDrafts[key];
    const need = item.need_quantity ?? item.quantity ?? 0;
    const err = validatePlacementDrafts(need, draft.placements);
    if (err) {
      showErrorNotification(`${item.name}: ${err}`);
      return;
    }
  }

  saveLoading.value = true;
  try {
    for (const item of changed) {
      const key = itemDraftKey(item);
      const draft = lineDrafts[key];
      await upsertMutation.mutateAsync({
        sourceType: item.source_type,
        sourceId: item.source_id,
        vendorPlacements: normalizePlacementsForSave(draft.placements),
      });
      baselineByLine[key] = serializePlacements(draft.placements);
    }
    showSuccessNotification('Vendor orders saved.');
    await detailQuery.refetch();
    void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandBuyDocuments'] });
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to save vendor orders'));
  } finally {
    saveLoading.value = false;
  }
};

const demandListPath = computed(() => {
  const tenantSlug =
    tenantStore.selectedTenant?.slug ||
    authStore.selectedTenant?.slug ||
    (route.params.tenantSlug as string | undefined);
  return tenantSlug ? `/${tenantSlug}/app/procurement/demand` : '/app/procurement/demand';
});

const goBack = async () => {
  if (!(await confirmDiscardIfDirty())) return;
  void router.push(demandListPath.value);
};

onBeforeRouteLeave(async () => {
  if (!documentDirty.value) return true;
  return confirmDiscardIfDirty();
});

const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

const breadcrumbItems = computed(() => {
  const tenantSlug =
    tenantStore.selectedTenant?.slug ||
    authStore.selectedTenant?.slug ||
    (route.params.tenantSlug as string | undefined);
  const procurementHub = tenantSlug ? `/${tenantSlug}/app/procurement` : '/app/procurement';

  return [
    {
      label: tenantStore.selectedTenant?.name || authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    { label: 'Procurement', to: procurementHub },
    { label: 'Demand paper', to: demandListPath.value },
    { label: pageTitle.value },
  ];
});

watch(breadcrumbItems, (items) => setCustomBreadcrumbs(items), { immediate: true });
onBeforeUnmount(() => clearCustomBreadcrumbs());
</script>

<style scoped lang="scss">
.demand-bulk-bar {
  flex-wrap: wrap;
}
.demand-bulk-bar__select-all {
  flex: 0 0 auto;
}
.demand-bulk-bar__vendor {
  flex: 1 1 160px;
  min-width: 140px;
  max-width: 220px;
}
</style>
