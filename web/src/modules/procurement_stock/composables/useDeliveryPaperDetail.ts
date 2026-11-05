import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, reactive, ref, unref, watch, type MaybeRef } from 'vue';
import type { DemandStockPickSelection } from '../components/ProcurementDemandStockPickDialog.vue';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import { shopOrderQueryKeys } from 'src/modules/shop_order/shared/queryKeys/shopOrderQueryKeys';
import {
  procurementDemandRepository,
  type ApplyDeliveryPaperOutcomeAllocation,
  type DeliveryPaperDetailItem,
  type DeliveryPaperStatus,
  type PreorderDemandCloseAction,
  type ProcurementDemandDocumentType,
  type SaveDeliveryPaperDetailItem,
} from '../repositories/procurementDemandRepository';
import {
  buildOutcomeAllocations,
  deliveryPaperOutcomeCloseAction,
  totalAllocationQty,
  type DeliveryPaperOutcomeAllocationRow,
  type DeliveryPaperOutcomeField,
} from '../utils/deliveryPaperOutcomeAllocations';
import {
  lineDraftFromPaperPicks,
  capOutcomeFieldQty,
  deliveryPaperLineHasPaperQty,
  lockedOutcomeQtyFromPaperPicks,
  mapPackedStockPicksToSave,
  outcomeQtyBelowLockedMessage,
  outcomeQtyValidationMessage,
  plannedOutcomeQtyFromDraft,
  parseStatusQtyInput,
  statusQtyToSaveSplits,
  sumPackedStockPickQty,
  type DeliveryPaperLineDraftState,
  type DeliveryPaperStatusQty,
} from '../utils/deliveryPaperStatusQty';
import {
  deliveryPaperCanDelete,
  deliveryPaperCanApplyOutcome,
  deliveryPaperCanEditOutcomeQty,
  deliveryPaperCanPickStock,
  deliveryPaperCanSaveLines,
  deliveryPaperHidesUnpickedLines,
  deliveryPaperIsReadOnly,
} from '../utils/deliveryPaperEditRules';
import { parseSupabaseError, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export type DeliveryPaperLineDraft = DeliveryPaperLineDraftState;

const itemDraftKey = (item: DeliveryPaperDetailItem) =>
  `${item.source_type}:${item.source_id}`;

export function useDeliveryPaperDetail(options: {
  tenantId: MaybeRef<number | null>;
  deliveryPaperId: MaybeRef<number | null>;
  expectedDocumentType?: MaybeRef<ProcurementDemandDocumentType | null>;
  expectedDocumentId?: MaybeRef<number | null>;
}) {
  const queryClient = useQueryClient();
  const tenantId = computed(() => unref(options.tenantId));
  const deliveryPaperId = computed(() => unref(options.deliveryPaperId));
  const lineDrafts = reactive<Record<string, DeliveryPaperLineDraft>>({});
  const documentDirty = ref(false);

  const detailQuery = useQuery({
    queryKey: computed(() =>
      procurementStockQueryKeys.deliveryPaperDetail({
        tenantId: tenantId.value ?? 0,
        deliveryPaperId: deliveryPaperId.value ?? 0,
      }),
    ),
    queryFn: () =>
      procurementDemandRepository.getDeliveryPaperDetail({
        tenantId: tenantId.value!,
        deliveryPaperId: deliveryPaperId.value!,
      }),
    enabled: computed(() => tenantId.value != null && deliveryPaperId.value != null),
  });

  const syncDraftsFromItems = (items: DeliveryPaperDetailItem[]) => {
    for (const item of items) {
      const key = itemDraftKey(item);
      lineDrafts[key] = lineDraftFromPaperPicks(item);
    }
  };

  watch(
    () => detailQuery.data.value?.items,
    (items) => {
      if (!items?.length) return;
      syncDraftsFromItems(items);
      documentDirty.value = false;
    },
    { immediate: true },
  );

  const paper = computed(() => detailQuery.data.value?.paper ?? null);
  const items = computed(() => detailQuery.data.value?.items ?? []);
  const paperStatus = computed(() => paper.value?.status ?? null);

  const itemHasPaperLineQty = (item: DeliveryPaperDetailItem): boolean => {
    const key = itemDraftKey(item);
    const draft = lineDrafts[key];
    return deliveryPaperLineHasPaperQty(item, draft ?? lineDraftFromPaperPicks(item));
  };

  const visibleItems = computed(() => {
    if (!deliveryPaperHidesUnpickedLines(paperStatus.value)) return items.value;
    return items.value.filter((item) => itemHasPaperLineQty(item));
  });

  const sourceMismatch = computed(() => {
    const p = paper.value;
    const docType = unref(options.expectedDocumentType);
    const docId = unref(options.expectedDocumentId);
    if (!p || docType == null || docId == null) return false;
    return p.source_type !== docType || p.source_id !== docId;
  });

  const canPickStock = computed(() => deliveryPaperCanPickStock(paperStatus.value));
  const canEditOutcomeQty = computed(() => deliveryPaperCanEditOutcomeQty(paperStatus.value));
  const canApplyOutcome = computed(() => deliveryPaperCanApplyOutcome(paperStatus.value));
  const isPaperReadOnly = computed(() => deliveryPaperIsReadOnly(paperStatus.value));
  const canSaveLines = computed(() => deliveryPaperCanSaveLines(paperStatus.value));
  const canDeletePaper = computed(() => deliveryPaperCanDelete(paperStatus.value));

  /** Draft-only stock pick (legacy alias). */
  const isEditable = canPickStock;

  const getDraft = (item: DeliveryPaperDetailItem): DeliveryPaperLineDraft => {
    const key = itemDraftKey(item);
    if (!lineDrafts[key]) {
      lineDrafts[key] = lineDraftFromPaperPicks(item);
    }
    return lineDrafts[key];
  };

  const markDirty = () => {
    documentDirty.value = true;
  };

  const onStatusQtyInput = (
    item: DeliveryPaperDetailItem,
    field: keyof DeliveryPaperStatusQty,
    value: string | number | null,
  ) => {
    if (!canEditOutcomeQty.value) return;
    if (field === 'packed') return;
    const key = itemDraftKey(item);
    const draft = getDraft(item);
    const nextQty = capOutcomeFieldQty(
      draft,
      field,
      parseStatusQtyInput(value),
      lockedOutcomeQtyFromPaperPicks(item),
    );
    lineDrafts[key] = {
      ...draft,
      [field]: nextQty,
      ...(field === 'packed' ? { stockPicks: [] } : {}),
    };
    markDirty();
  };

  const applyStockPicks = (item: DeliveryPaperDetailItem, picks: DemandStockPickSelection[]) => {
    if (!canPickStock.value) return;
    const key = itemDraftKey(item);
    const draft = getDraft(item);
    lineDrafts[key] = {
      ...draft,
      stockPicks: picks,
      packed: sumPackedStockPickQty(picks),
    };
    markDirty();
  };

  const buildSavePayload = (): SaveDeliveryPaperDetailItem[] => {
    const status = paperStatus.value;
    const outcomeOnly = deliveryPaperCanEditOutcomeQty(status);

    return items.value
      .filter((item) => item.preorder_demand_id != null)
      .map((item) => {
        const draft = getDraft(item);
        if (outcomeOnly) {
          const locked = lockedOutcomeQtyFromPaperPicks(item);
          const planned = plannedOutcomeQtyFromDraft(draft, locked);
          return {
            preorder_demand_id: item.preorder_demand_id!,
            splits: statusQtyToSaveSplits(planned, false),
          };
        }
        const picks = mapPackedStockPicksToSave(draft.stockPicks);
        const useStockPicks = picks.length > 0;
        return {
          preorder_demand_id: item.preorder_demand_id!,
          splits: statusQtyToSaveSplits(draft, !useStockPicks),
          ...(useStockPicks ? { picks } : {}),
        };
      });
  };

  const validateOutcomeDrafts = (): string | null => {
    for (const item of visibleItems.value) {
      const draft = getDraft(item);
      const locked = lockedOutcomeQtyFromPaperPicks(item);
      const belowLocked = outcomeQtyBelowLockedMessage(draft, locked);
      if (belowLocked) {
        const label = item.name?.trim() || 'Line';
        return `${label}: ${belowLocked}`;
      }
      const message = outcomeQtyValidationMessage(draft, locked);
      if (message) {
        const label = item.name?.trim() || 'Line';
        return `${label}: ${message}`;
      }
    }
    return null;
  };

  const saveMutation = useMutation({
    mutationFn: () => {
      if (deliveryPaperCanEditOutcomeQty(paperStatus.value)) {
        const err = validateOutcomeDrafts();
        if (err) return Promise.reject(new Error(err));
      }
      return procurementDemandRepository.saveDeliveryPaperDetail({
        tenantId: tenantId.value!,
        deliveryPaperId: deliveryPaperId.value!,
        items: buildSavePayload(),
      });
    },
    onSuccess: async () => {
      showSuccessNotification('Delivery paper saved');
      documentDirty.value = false;
      await invalidateDetailAndList();
    },
    onError: (err) => {
      showErrorNotification(parseSupabaseError(err, 'Failed to save delivery paper'));
    },
  });

  const invalidateDetailAndList = async () => {
    await queryClient.invalidateQueries({
      queryKey: procurementStockQueryKeys.deliveryPaperDetail({
        tenantId: tenantId.value!,
        deliveryPaperId: deliveryPaperId.value!,
      }),
    });
    const p = paper.value;
    if (p) {
      await queryClient.invalidateQueries({
        queryKey: procurementStockQueryKeys.deliveryPapersForDocument({
          tenantId: tenantId.value!,
          documentType: p.source_type,
          documentId: p.source_id,
        }),
      });
      if (p.source_type === 'shop_order') {
        await queryClient.invalidateQueries({
          queryKey: shopOrderQueryKeys.deliveryPaperQtyByOrderItemRoot(),
        });
      }
    }
  };

  const statusMutation = useMutation({
    mutationFn: (status: DeliveryPaperStatus) =>
      procurementDemandRepository.updateDeliveryPaperStatus({
        tenantId: tenantId.value!,
        deliveryPaperId: deliveryPaperId.value!,
        status,
      }),
    onSuccess: async (_data, status) => {
      showSuccessNotification(`Status set to ${status}`);
      await invalidateDetailAndList();
    },
    onError: (err) => {
      showErrorNotification(parseSupabaseError(err, 'Failed to update status'));
    },
  });

  const updatePaperStatus = (status: DeliveryPaperStatus) => statusMutation.mutateAsync(status);

  const buildOutcomeAllocationRows = (field: DeliveryPaperOutcomeField): DeliveryPaperOutcomeAllocationRow[] =>
    buildOutcomeAllocations({
      items: visibleItems.value,
      getDraft,
      field,
    });

  const outcomeMutation = useMutation({
    mutationFn: (params: {
      closeAction: PreorderDemandCloseAction;
      allocations: ApplyDeliveryPaperOutcomeAllocation[];
    }) =>
      procurementDemandRepository.applyDeliveryPaperOutcome({
        tenantId: tenantId.value!,
        deliveryPaperId: deliveryPaperId.value!,
        closeAction: params.closeAction,
        allocations: params.allocations,
      }),
    onSuccess: async (result) => {
      if (result.close_action === 'return') {
        showSuccessNotification(`Returned ${result.unit_count ?? 0} unit(s) to warehouse`);
      } else if (result.invoice_no) {
        showSuccessNotification(`Draft bill ${result.invoice_no} created`);
      } else {
        showSuccessNotification('Outcome applied');
      }
      await invalidateDetailAndList();
    },
    onError: (err) => {
      showErrorNotification(parseSupabaseError(err, 'Failed to apply outcome'));
    },
  });

  const applyOutcome = (params: {
    field: DeliveryPaperOutcomeField;
    allocations: ApplyDeliveryPaperOutcomeAllocation[];
  }) => {
    if (documentDirty.value) {
      showErrorNotification('Save line changes before running this action.');
      return Promise.reject(new Error('unsaved'));
    }
    const draftErr = validateOutcomeDrafts();
    if (draftErr) {
      showErrorNotification(draftErr);
      return Promise.reject(new Error('outcome_qty'));
    }
    const closeAction = deliveryPaperOutcomeCloseAction(params.field);
    return outcomeMutation.mutateAsync({
      closeAction,
      allocations: params.allocations,
    });
  };

  return {
    detailQuery,
    paper,
    items,
    visibleItems,
    lineDrafts,
    documentDirty,
    sourceMismatch,
    isEditable,
    canPickStock,
    canEditOutcomeQty,
    canApplyOutcome,
    isPaperReadOnly,
    canSaveLines,
    canDeletePaper,
    isLoading: detailQuery.isLoading,
    isSaving: saveMutation.isPending,
    isUpdatingStatus: statusMutation.isPending,
    isApplyingOutcome: outcomeMutation.isPending,
    getDraft,
    onStatusQtyInput,
    applyStockPicks,
    save: () => saveMutation.mutateAsync(),
    updatePaperStatus,
    buildOutcomeAllocationRows,
    applyOutcome,
    itemDraftKey,
  };
}
