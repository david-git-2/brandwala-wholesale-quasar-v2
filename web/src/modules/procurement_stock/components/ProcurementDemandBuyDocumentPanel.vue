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
          <div
            v-if="documentDirty"
            class="row items-center no-wrap q-gutter-x-xs col-shrink"
          >
            <q-btn
              outline
              no-caps
              color="grey-8"
              label="Cancel"
              class="col-shrink"
              :disable="saveLoading"
              @click="cancelDocument"
            />
            <q-btn
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
          v-if="detailItems.length > 0"
          class="demand-buy-doc-totals q-mt-sm q-pa-sm rounded-borders"
        >
          <div class="demand-buy-doc-totals__grand row items-end q-gutter-x-lg wrap">
            <div class="column">
              <span class="text-caption text-grey-7">Placed qty</span>
              <span class="demand-buy-doc-totals__value tf-num font-mono">{{
                placementTotals.grand.quantity
              }}</span>
            </div>
            <div class="column">
              <span class="text-caption text-grey-7">Placed £ (entered unit prices)</span>
              <span class="demand-buy-doc-totals__value tf-num font-mono">{{
                formatSettlementCurrencyAmount(placementTotals.grand.amount, 'GBP')
              }}</span>
            </div>
          </div>
          <div
            v-if="placementTotals.byVendor.length > 0"
            class="demand-buy-doc-totals__vendors q-mt-sm column q-gutter-y-xs"
          >
            <div
              v-for="bucket in placementTotals.byVendor"
              :key="bucket.vendorCode"
              class="row items-baseline q-gutter-x-sm wrap demand-buy-doc-totals__vendor-row"
              :class="{
                'demand-buy-doc-totals__vendor-row--active':
                  bulkVendorCode?.trim() === bucket.vendorCode,
              }"
            >
              <span class="text-caption text-grey-7 text-weight-medium ellipsis">{{
                vendorLabel(bucket.vendorCode)
              }}</span>
              <span class="demand-buy-doc-totals__subvalue tf-num font-mono">{{
                bucket.quantity
              }}</span>
              <span class="text-caption text-grey-6">placed</span>
              <span class="demand-buy-doc-totals__subvalue tf-num font-mono">{{
                formatSettlementCurrencyAmount(bucket.amount, 'GBP')
              }}</span>
            </div>
          </div>
        </div>

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
          <q-btn
            outline
            no-caps
            dense
            color="primary"
            icon="ph ph-clipboard-text"
            label="Bulk paste"
            class="col-shrink"
            @click="showBulkPasteDialog = true"
          >
            <q-tooltip>Barcode or product code, qty and unit price (saves on apply)</q-tooltip>
          </q-btn>
        </div>
      </q-card>

      <ProcurementDemandBuyBulkPasteDialog
        v-model="showBulkPasteDialog"
        :vendor-code="bulkVendorCode"
        :vendor-options="bulkVendorCodeOptions"
        :saving="bulkPasteSaving"
        @update:vendor-code="bulkVendorCode = $event"
        @apply="onBulkPasteApply"
      />

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
import { vendorRepository } from 'src/modules/people/submodules/vendor/repositories/vendorRepository';
import type { Vendor } from 'src/modules/people/submodules/vendor/types';
import {
  parseSupabaseError,
  requestConfirmation,
  requestUnsavedLeaveChoice,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import { useProcurementDemandBuyDocumentInfiniteQuery } from '../composables/useProcurementDemandBuyDocumentInfiniteQuery';
import { useBulkUpsertPreorderDemandVendorPlacementsMutation } from '../composables/useProcurementPlacementMutations';
import ProcurementDemandBuyBulkPasteDialog from './ProcurementDemandBuyBulkPasteDialog.vue';
import ProcurementDemandBuyLines from './ProcurementDemandBuyLines.vue';
import type {
  ProcurementDemandDocumentType,
  ProcurementDemandItem,
  ProcurementDemandStatus,
} from '../repositories/procurementDemandRepository';
import {
  aggregateVendorPlacementTotals,
  clearedLineDraft,
  cloneLineDraft,
  type DemandBuyLineDraft,
  itemDraftKey,
  normalizePlacementsForSave,
  backfillPlacementUnitPrices,
  backfillPlacementVendorCodes,
  orderLineUnitPrice,
  placementsFromBaseline,
  placementsFromItem,
  serializePlacements,
  upsertVendorPlacementDraft,
  validatePlacementDraftsForPersist,
} from '../utils/demandBuyPlacements';
import {
  bulkPasteRowHasValues,
  findDemandItemsByKeys,
  findUniqueDemandItemByKeys,
  normalizeProductKey,
  parsePasteQuantity,
  parsePasteUnitPrice,
  type DemandBuyBulkPasteRow,
} from '../utils/demandBuyBulkPaste';

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

const tenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId ?? null,
);

const detailQuery = useProcurementDemandBuyDocumentInfiniteQuery({
  tenantId: tenantId,
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

const placementTotals = computed(() =>
  aggregateVendorPlacementTotals(detailItems.value, (item) => {
    const key = itemDraftKey(item);
    return lineDrafts[key]?.placements ?? placementsFromItem(item);
  }),
);

const showBulkPasteDialog = ref(false);
const bulkPasteSaving = ref(false);

const selectedLineKeys = reactive<Record<string, boolean>>({});
const bulkVendorFilter = ref('');
const bulkVendorCode = ref<string | null>(null);

const vendorFilter = ref('');
const { data: vendorsData } = useQuery({
  queryKey: computed(() => ['vendors', 'demandBuyDoc', tenantId.value]),
  queryFn: () => vendorRepository.listVendors(tenantId.value!),
  enabled: computed(() => tenantId.value != null),
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

const vendorLabelByCode = computed(() => {
  const map = new Map<string, string>();
  for (const v of (vendorsData.value ?? []) as Vendor[]) {
    const code = v.code.trim();
    if (!code) continue;
    map.set(code, v.name?.trim() || code);
  }
  for (const opt of vendorCodeOptions.value) {
    if (!map.has(opt.code)) map.set(opt.code, opt.label);
  }
  return map;
});

const vendorLabel = (code: string) => vendorLabelByCode.value.get(code.trim()) ?? code.trim();

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
    if (need <= 0) {
      lineDrafts[key] = cloneLineDraft(clearedLineDraft());
      continue;
    }
    lineDrafts[key] = cloneLineDraft({
      placements: [
        {
          vendorCode: code,
          quantity: need,
          unitPrice: orderLineUnitPrice(item),
        },
      ],
    });
  }
  showSuccessNotification(`Vendor set on ${keys.length} line(s). Save to persist.`);
};

const applyDraftFromItem = (item: ProcurementDemandItem) => {
  const key = itemDraftKey(item);
  const draft: DemandBuyLineDraft = { placements: placementsFromItem(item) };
  lineDrafts[key] = cloneLineDraft(draft);
  baselineByLine[key] = serializePlacements(draft.placements);
};

const reloadDraftsFromItems = (items: ProcurementDemandItem[], keys?: Set<string>) => {
  for (const item of items) {
    const key = itemDraftKey(item);
    if (keys && !keys.has(key)) continue;
    applyDraftFromItem(item);
  }
};

const syncDraftsFromItems = (items: ProcurementDemandItem[]) => {
  for (const item of items) {
    const key = itemDraftKey(item);
    const existing = lineDrafts[key];
    if (existing) {
      backfillPlacementUnitPrices(item, existing.placements);
      backfillPlacementVendorCodes(item, existing.placements);
      continue;
    }
    applyDraftFromItem(item);
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

const bulkSaveMutation = useBulkUpsertPreorderDemandVendorPlacementsMutation({
  tenantId: tenantId,
});

const saveLoading = ref(false);

const revertUnsavedDrafts = () => {
  for (const item of detailItems.value) {
    const key = itemDraftKey(item);
    const draft = lineDrafts[key];
    if (!draft) continue;
    if (serializePlacements(draft.placements) === baselineByLine[key]) continue;
    const fromBaseline = placementsFromBaseline(baselineByLine[key]);
    lineDrafts[key] = cloneLineDraft({
      placements: fromBaseline ?? placementsFromItem(item),
    });
  }
};

const saveAllDirtyLines = async () => {
  if (!tenantId.value) return;
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
    const err = validatePlacementDraftsForPersist(draft!.placements, item);
    if (err) {
      throw new Error(`${item.name}: ${err}`);
    }
  }

  await persistVendorPlacements(changed);
  showSuccessNotification('Vendor orders saved.');
};

const confirmLeaveIfDirty = async (): Promise<boolean> => {
  if (!documentDirty.value) return true;
  const choice = await requestUnsavedLeaveChoice(
    'Save vendor orders before leaving, or discard your edits.',
    'Unsaved vendor orders',
  );
  if (choice === 'stay') return false;
  if (choice === 'discard') {
    revertUnsavedDrafts();
    return true;
  }
  saveLoading.value = true;
  try {
    await saveAllDirtyLines();
    return !documentDirty.value;
  } catch (err) {
    showErrorNotification(
      err instanceof Error ? err.message : parseSupabaseError(err, 'Failed to save vendor orders'),
    );
    return false;
  } finally {
    saveLoading.value = false;
  }
};

const onUpdateLineDraft = (item: ProcurementDemandItem, draft: DemandBuyLineDraft) => {
  lineDrafts[itemDraftKey(item)] = cloneLineDraft(draft);
};

const onLoadMoreItems = () => {
  if (detailQuery.hasMoreItems.value && !detailQuery.isFetchingNextPage.value) {
    void detailQuery.fetchNextPage();
  }
};

const persistVendorPlacements = async (items: ProcurementDemandItem[]) => {
  if (!tenantId.value || items.length === 0) return;
  for (const item of items) {
    const key = itemDraftKey(item);
    const draft = lineDrafts[key];
    if (!draft) continue;
    const err = validatePlacementDraftsForPersist(draft.placements, item);
    if (err) {
      throw new Error(`${item.name}: ${err}`);
    }
  }
  const savedKeys = new Set(items.map((item) => itemDraftKey(item)));
  await bulkSaveMutation.mutateAsync({
    lines: items.map((item) => {
      const key = itemDraftKey(item);
      const draft = lineDrafts[key];
      return {
        source_type: item.source_type,
        source_id: item.source_id,
        vendor_placements: normalizePlacementsForSave(draft!.placements, item),
      };
    }),
  });
  await detailQuery.refetch();
  reloadDraftsFromItems(detailItems.value, savedKeys);
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandBuyDocuments'] });
};

const cancelDocument = async () => {
  if (!documentDirty.value) return;
  const ok = await requestConfirmation(
    'Revert unsaved vendor order edits on this document?',
    'Cancel changes',
    'Revert',
  );
  if (!ok) return;
  revertUnsavedDrafts();
  showSuccessNotification('Changes reverted.');
};

const saveDocument = async () => {
  saveLoading.value = true;
  try {
    await saveAllDirtyLines();
  } catch (err) {
    showErrorNotification(
      err instanceof Error ? err.message : parseSupabaseError(err, 'Failed to save vendor orders'),
    );
  } finally {
    saveLoading.value = false;
  }
};

const onBulkPasteApply = async (rows: DemandBuyBulkPasteRow[]) => {
  const vendorCode = bulkVendorCode.value?.trim();
  if (!vendorCode) {
    showErrorNotification('Choose a vendor on the bulk bar.');
    return;
  }

  bulkPasteSaving.value = true;
  try {
    if (detailQuery.hasMoreItems.value) {
      await detailQuery.fetchAllPages();
    }
    const items = detailItems.value;
    const dataRows = rows.filter(bulkPasteRowHasValues);
    const pasteHasKeys = dataRows.some(
      (row) => normalizeProductKey(row.barcode) || normalizeProductKey(row.product_code),
    );
    const itemsInPasteScope = new Set<string>();
    if (pasteHasKeys) {
      for (const row of dataRows) {
        const barcode = normalizeProductKey(row.barcode);
        const productCode = normalizeProductKey(row.product_code);
        if (!barcode && !productCode) continue;
        const hits = findDemandItemsByKeys(items, barcode, productCode);
        if (hits.length === 1) itemsInPasteScope.add(itemDraftKey(hits[0]!));
      }
    }
    const toSave: ProcurementDemandItem[] = [];
    const savedKeys = new Set<string>();
    const pushToSave = (item: ProcurementDemandItem) => {
      const key = itemDraftKey(item);
      if (savedKeys.has(key)) return;
      savedKeys.add(key);
      toSave.push(item);
    };
    let skipped = 0;
    let cleared = 0;

    for (const row of dataRows) {
      const qty = parsePasteQuantity(row.quantity);
      const price = parsePasteUnitPrice(row.unit_price);
      if (qty === null && price === null) {
        skipped++;
        continue;
      }
      const barcode = normalizeProductKey(row.barcode);
      const productCode = normalizeProductKey(row.product_code);
      if (!barcode && !productCode) {
        skipped++;
        continue;
      }
      const item = findUniqueDemandItemByKeys(items, barcode, productCode);
      if (!item) {
        skipped++;
        continue;
      }
      const key = itemDraftKey(item);
      const existingPlacements =
        lineDrafts[key]?.placements ?? placementsFromItem(item);
      const patch: { quantity?: number; unitPrice?: number } = {};
      if (qty !== null) patch.quantity = qty;
      if (price !== null) patch.unitPrice = price;
      const placements = upsertVendorPlacementDraft(item, existingPlacements, vendorCode, patch);
      const draft = cloneLineDraft({ placements });
      const err = validatePlacementDraftsForPersist(draft.placements, item);
      if (err) {
        showErrorNotification(`${item.name}: ${err}`);
        return;
      }
      lineDrafts[key] = draft;
      pushToSave(item);
    }

    if (pasteHasKeys) {
      for (const item of items) {
        const key = itemDraftKey(item);
        if (itemsInPasteScope.has(key)) continue;
        const draft = cloneLineDraft(clearedLineDraft());
        if (serializePlacements(draft.placements) === baselineByLine[key]) continue;
        lineDrafts[key] = draft;
        pushToSave(item);
        cleared++;
      }
    }

    if (toSave.length === 0) {
      showErrorNotification(
        skipped > 0 ? 'No lines matched. Check barcode or product code.' : 'Nothing to apply.',
      );
      return;
    }

    await persistVendorPlacements(toSave);
    showBulkPasteDialog.value = false;
    const skipPart = skipped > 0 ? ` ${skipped} row(s) skipped.` : '';
    const clearPart = cleared > 0 ? ` ${cleared} line(s) cleared (not in paste).` : '';
    showSuccessNotification(`Pasted and saved ${toSave.length} line(s).${skipPart}${clearPart}`);
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Bulk paste failed'));
  } finally {
    bulkPasteSaving.value = false;
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
  if (!(await confirmLeaveIfDirty())) return;
  void router.push(demandListPath.value);
};

onBeforeRouteLeave(async () => {
  if (!(await confirmLeaveIfDirty())) return false;
  return true;
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
.demand-buy-doc-totals {
  border: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-canvas);
  border-radius: var(--tf-radius-md, 8px);
}
.demand-buy-doc-totals__value {
  font-size: var(--tf-text-kpi, 1.25rem);
  font-weight: 700;
  line-height: 1.2;
  color: var(--tf-theme-primary);
}
.demand-buy-doc-totals__subvalue {
  font-size: 0.95rem;
  font-weight: 600;
  line-height: 1.2;
}
.demand-buy-doc-totals__vendor-row {
  padding-left: 2px;
}
.demand-buy-doc-totals__vendor-row--active {
  padding: 4px 6px;
  margin-left: -6px;
  border-radius: var(--tf-radius-sm, 4px);
  background: color-mix(in srgb, var(--tf-theme-primary) 10%, var(--tf-neutral-canvas));
}
</style>
