<template>
  <q-page class="q-px-xs q-py-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="sourceMismatch" class="column items-center q-pa-xl text-center">
      <div class="text-body1 text-grey-8">This delivery paper does not belong to this document.</div>
      <TfBtn variant="secondary" class="q-mt-md" label="Go back" @click="goBack" />
    </div>

    <template v-else>
      <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
        <q-card flat bordered class="flex-shrink-0 q-pa-sm">
          <div class="row items-center no-wrap q-gutter-x-xs">
            <TfBtn variant="icon" icon="ph ph-arrow-left" color="grey-8" aria-label="Back" @click="goBack" />
            <div class="col min-width-0">
              <h1 class="text-subtitle1 text-weight-bold q-my-none ellipsis">
                {{ pageTitle }}
              </h1>
              <p v-if="paper?.profile_name" class="text-caption text-grey-7 q-mb-none ellipsis">
                {{ paper.profile_name }}
              </p>
              <div
                v-if="closeBillChips.length"
                class="row items-center q-gutter-xs q-mt-xs wrap delivery-paper-close-bills"
              >
                <q-chip
                  v-for="bill in closeBillChips"
                  :key="bill.id"
                  dense
                  clickable
                  outline
                  color="primary"
                  icon="ph ph-receipt"
                  class="delivery-paper-close-bill-chip"
                  @click="openCloseBill(bill)"
                >
                  {{ deliveryPaperCloseBillChipLabel(bill) }}
                  <q-tooltip>{{ deliveryPaperCloseBillChipCaption(bill) ?? 'Open bill' }}</q-tooltip>
                </q-chip>
              </div>
            </div>
            <div
              v-if="paper && canApplyOutcome && visibleOutcomeActionFields.length"
              class="row items-center no-wrap q-gutter-x-xs col-shrink delivery-paper-outcome-actions"
            >
              <TfBtn
                v-if="visibleOutcomeActionFields.includes('accepted')"
                variant="success"
                size="md"
                :label="outcomeActionButtons.accepted?.label ?? ''"
                class="delivery-paper-header-btn delivery-paper-outcome-btn--accept"
                :loading="isApplyingOutcome"
                :disable="isApplyingOutcome || (outcomeActionButtons.accepted?.disabled ?? true)"
                @click="onOutcomeAccept"
              />
              <TfBtn
                v-if="visibleOutcomeActionFields.includes('conditioned')"
                variant="primary"
                color="warning"
                size="md"
                :label="outcomeActionButtons.conditioned?.label ?? ''"
                class="delivery-paper-header-btn delivery-paper-outcome-btn--condition"
                :loading="isApplyingOutcome"
                :disable="isApplyingOutcome || (outcomeActionButtons.conditioned?.disabled ?? true)"
                @click="onOutcomeCondition"
              />
              <TfBtn
                v-if="visibleOutcomeActionFields.includes('rejected')"
                variant="danger"
                size="md"
                :label="outcomeActionButtons.rejected?.label ?? ''"
                class="delivery-paper-header-btn delivery-paper-outcome-btn--reject"
                :loading="isApplyingOutcome"
                :disable="isApplyingOutcome || (outcomeActionButtons.rejected?.disabled ?? true)"
                @click="onOutcomeReject"
              />
            </div>
            <div class="row items-center no-wrap q-gutter-x-xs col-shrink delivery-paper-header-actions">
              <q-select
                v-if="paper"
                v-model="selectedPaperStatus"
                class="delivery-paper-status-select col-shrink"
                :options="paperStatusOptions"
                emit-value
                map-options
                dense
                outlined
                hide-bottom-space
                label="Status"
                :loading="isUpdatingStatus"
                :disable="!canChangePaperStatus || isUpdatingStatus"
                @update:model-value="onPaperStatusChange"
              />
              <TfBtn
                v-if="canDeletePaper"
                variant="icon"
                color="negative"
                icon="ph ph-trash"
                aria-label="Delete delivery paper"
                :loading="isDeleting"
                @click="onDeletePaper"
              />
              <TfBtn
                v-if="canSaveLines && documentDirty"
                variant="primary"
                size="md"
                icon="ph ph-floppy-disk"
                label="Save"
                class="delivery-paper-save-btn"
                :loading="isSaving"
                @click="onSave"
              />
            </div>
          </div>
        </q-card>

        <div class="col scroll-y-min">
          <div
            v-if="isLoading && items.length === 0"
            class="row justify-center q-py-xl"
          >
            <q-spinner-dots size="32px" color="primary" />
          </div>
          <div
            v-else-if="visibleItems.length === 0"
            class="column items-center q-pa-xl text-center text-grey-7"
          >
            <div class="text-body2">
              {{
                canPickStock
                  ? 'No lines on this delivery paper.'
                  : 'No picked items on this delivery paper.'
              }}
            </div>
          </div>
          <DeliveryPaperDetailLines
            v-else
            :items="visibleItems"
            :line-drafts="lineDrafts"
            :can-pick-stock="canPickStock"
            :can-edit-outcome-qty="canEditOutcomeQty"
            :paper-status="paper?.status ?? null"
            :item-draft-key="itemDraftKey"
            @status-qty="onStatusQtyInput"
            @pick-stock="openPickDialog"
          />
        </div>
      </div>

      <ProcurementDemandStockPickDialog
        v-model="pickDialogOpen"
        hide-per-lot-add-button
        :tenant-id="parentTenantId"
        :product-id="pickTarget?.product_id ?? null"
        :product-name="pickTarget?.name ?? 'Item'"
        :need-quantity="pickNeedQuantity"
        :initial-picks="pickInitialPicks"
        @apply="onPickApply"
      />

      <DeliveryPaperOutcomeRejectDialog
        v-model="rejectDialogOpen"
        :rows="rejectAllocationRows"
        :loading="isApplyingOutcome"
        @confirm="onRejectConfirm"
      />
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import TfBtn from 'src/components/ui/TfBtn.vue';
import {
  parseSupabaseError,
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import DeliveryPaperDetailLines from '../components/DeliveryPaperDetailLines.vue';
import DeliveryPaperOutcomeRejectDialog from '../components/DeliveryPaperOutcomeRejectDialog.vue';
import ProcurementDemandStockPickDialog from '../components/ProcurementDemandStockPickDialog.vue';
import type { DemandStockPickSelection } from '../components/ProcurementDemandStockPickDialog.vue';
import { billDetailRoute } from 'src/modules/bills_pays/utils/billRoutes';
import {
  deliveryPaperCloseBillChipCaption,
  deliveryPaperCloseBillChipLabel,
} from '../utils/deliveryPaperCloseBills';
import {
  deliveryPaperCanChangeStatus,
  deliveryPaperVisibleOutcomeFields,
} from '../utils/deliveryPaperEditRules';
import type { DeliveryPaperCloseBill } from '../repositories/procurementDemandRepository';
import { useDeliveryPaperDetail } from '../composables/useDeliveryPaperDetail';
import {
  deliveryPaperOutcomeActionButtonLabel,
  deliveryPaperOutcomeActionButtonState,
  deliveryPaperOutcomeFieldsForHeaderActions,
  outcomeFieldLabel,
  totalAllocationQty,
  type DeliveryPaperOutcomeAllocationRow,
  type DeliveryPaperOutcomeField,
} from '../utils/deliveryPaperOutcomeAllocations';
import { getDeliveryPaperUnitSellPrice } from '../utils/deliveryPaperUnitSellPrice';
import { formatBdtTaka } from 'src/utils/currency';
import { deliveryPaperStatusOptionsForSelect } from '../utils/deliveryPaperStatusOptions';
import {
  procurementDemandRepository,
  type DeliveryPaperDetailItem,
  type DeliveryPaperStatus,
  type ProcurementDemandDocumentType,
} from '../repositories/procurementDemandRepository';
import { getDeliveryPaperLinePickCap } from '../utils/deliveryPaperRemainingQty';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

const props = defineProps<{
  documentType: ProcurementDemandDocumentType;
  documentId: number;
}>();

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const queryClient = useQueryClient();

const paperId = computed(() => {
  const raw = route.params.paperId;
  const id = Number(typeof raw === 'string' ? raw : raw?.[0]);
  return Number.isFinite(id) ? id : null;
});

const parentTenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId ?? null,
);

const deleteMutation = useMutation({
  mutationFn: () =>
    procurementDemandRepository.deleteDeliveryPaper({
      tenantId: parentTenantId.value!,
      deliveryPaperId: paperId.value!,
    }),
  onSuccess: async () => {
    showSuccessNotification('Delivery paper deleted');
    const p = paper.value;
    if (p && parentTenantId.value) {
      await queryClient.invalidateQueries({
        queryKey: procurementStockQueryKeys.deliveryPapersForDocument({
          tenantId: parentTenantId.value,
          documentType: p.source_type,
          documentId: p.source_id,
        }),
      });
    }
    goBack();
  },
  onError: (err) => {
    showErrorNotification(parseSupabaseError(err, 'Failed to delete delivery paper'));
  },
});

const isDeleting = computed(() => deleteMutation.isPending.value);

const {
  paper,
  items,
  visibleItems,
  lineDrafts,
  documentDirty,
  sourceMismatch,
  canPickStock,
  canEditOutcomeQty,
  canApplyOutcome,
  isPaperReadOnly,
  canSaveLines,
  canDeletePaper,
  isLoading,
  isSaving,
  isUpdatingStatus,
  onStatusQtyInput,
  applyStockPicks,
  save,
  updatePaperStatus,
  buildOutcomeAllocationRows,
  applyOutcome,
  isApplyingOutcome,
  itemDraftKey,
  getDraft,
} = useDeliveryPaperDetail({
  tenantId: parentTenantId,
  deliveryPaperId: paperId,
  expectedDocumentType: computed(() => props.documentType),
  expectedDocumentId: computed(() => props.documentId),
});

const canChangePaperStatus = computed(() =>
  deliveryPaperCanChangeStatus(paper.value?.status),
);

const visibleOutcomeFields = computed(() =>
  deliveryPaperVisibleOutcomeFields(paper.value?.status),
);

const visibleOutcomeActionFields = computed((): DeliveryPaperOutcomeField[] => {
  const allowed = new Set(visibleOutcomeFields.value);
  return deliveryPaperOutcomeFieldsForHeaderActions(visibleItems.value, getDraft).filter((field) =>
    allowed.has(field),
  );
});

const outcomeActionButtons = computed(() => {
  const states: Partial<
    Record<DeliveryPaperOutcomeField, ReturnType<typeof deliveryPaperOutcomeActionButtonState>>
  > = {};
  for (const field of visibleOutcomeActionFields.value) {
    states[field] = deliveryPaperOutcomeActionButtonState(visibleItems.value, getDraft, field);
  }
  return states;
});

const paperStatusOptions = computed(() =>
  deliveryPaperStatusOptionsForSelect(paper.value?.status),
);

const pageTitle = computed(() => {
  if (!paper.value) return 'Delivery paper';
  const refLabel =
    paper.value.source_type === 'shop_order'
      ? paper.value.shop_order_no || `Order #${paper.value.source_id}`
      : paper.value.document_name || `PBC-${paper.value.source_id}`;
  return `DP-${paper.value.id} · ${refLabel}`;
});

const closeBillChips = computed((): DeliveryPaperCloseBill[] => paper.value?.close_bills ?? []);

const openCloseBill = (bill: DeliveryPaperCloseBill) => {
  void router.push(billDetailRoute(bill.id, authStore.tenantSlug));
};

const selectedPaperStatus = ref<DeliveryPaperStatus>('draft');

watch(
  () => paper.value?.status,
  (status) => {
    if (status) selectedPaperStatus.value = status;
  },
  { immediate: true },
);

const onPaperStatusChange = async (next: DeliveryPaperStatus | null) => {
  const prev = paper.value?.status;
  if (!next || !prev || next === prev) return;
  if (prev !== 'draft' && next === 'draft') {
    showErrorNotification('This delivery paper cannot go back to Draft.');
    selectedPaperStatus.value = prev;
    return;
  }
  if (documentDirty.value) {
    showErrorNotification('Save line changes before changing status.');
    selectedPaperStatus.value = prev;
    return;
  }
  try {
    await updatePaperStatus(next);
  } catch {
    selectedPaperStatus.value = prev;
  }
};

const pickDialogOpen = ref(false);
const pickTarget = ref<DeliveryPaperDetailItem | null>(null);

const pickNeedQuantity = computed(() =>
  pickTarget.value ? getDeliveryPaperLinePickCap(pickTarget.value) : 0,
);

const pickInitialPicks = computed(() =>
  pickTarget.value ? getDraft(pickTarget.value).stockPicks : [],
);

const openPickDialog = (item: DeliveryPaperDetailItem) => {
  if (!canPickStock.value) return;
  if (parentTenantId.value == null) {
    showErrorNotification('Could not load warehouse context. Try refreshing the page.');
    return;
  }
  pickTarget.value = item;
  void nextTick(() => {
    pickDialogOpen.value = true;
  });
};

const onPickApply = (payload: { picks: DemandStockPickSelection[] }) => {
  if (!pickTarget.value) return;
  applyStockPicks(pickTarget.value, payload.picks);
  pickDialogOpen.value = false;
};

const onSave = async () => {
  await save();
};

const rejectDialogOpen = ref(false);
const rejectAllocationRows = ref<DeliveryPaperOutcomeAllocationRow[]>([]);

const ensureOutcomeAllocations = (field: 'accepted' | 'conditioned' | 'rejected') => {
  if (documentDirty.value) {
    showErrorNotification('Save line changes before running this action.');
    return null;
  }
  const rows = buildOutcomeAllocationRows(field);
  const units = totalAllocationQty(rows);
  if (units <= 0) {
    showErrorNotification(`No new ${outcomeFieldLabel(field)} qty to apply. Increase the column above what is already done, then Save.`);
    return null;
  }
  return rows;
};

const outcomeAllocationLineTotal = (rows: DeliveryPaperOutcomeAllocationRow[]) =>
  rows.reduce(
    (sum, row) =>
      sum + row.quantity * getDeliveryPaperUnitSellPrice({ unit_sell_price_amount: row.unit_sell_price_amount }),
    0,
  );

const runInvoiceOutcome = async (field: 'accepted' | 'conditioned') => {
  const rows = ensureOutcomeAllocations(field);
  if (!rows) return;
  const units = totalAllocationQty(rows);
  const lineTotal = outcomeAllocationLineTotal(rows);
  const label = deliveryPaperOutcomeActionButtonLabel(field);
  const ok = await requestConfirmation(
    `Create a draft bill for ${units} unit(s) at ${formatBdtTaka(lineTotal)} line total?`,
    field === 'conditioned' ? 'Create condition bill?' : 'Create draft bill?',
    label,
  );
  if (!ok) return;
  try {
    const result = await applyOutcome({
      field,
      allocations: rows.map(({ preorder_demand_id, global_stock_id, quantity }) => ({
        preorder_demand_id,
        global_stock_id,
        quantity,
      })),
    });
    if (result.invoice_id) {
      void router.push(billDetailRoute(result.invoice_id, authStore.tenantSlug));
    }
  } catch {
    /* notified in composable */
  }
};

const onOutcomeAccept = () => void runInvoiceOutcome('accepted');
const onOutcomeCondition = () => void runInvoiceOutcome('conditioned');

const onOutcomeReject = () => {
  const rows = ensureOutcomeAllocations('rejected');
  if (!rows) return;
  rejectAllocationRows.value = rows;
  rejectDialogOpen.value = true;
};

const onRejectConfirm = async (
  allocations: Array<{
    preorder_demand_id: number;
    global_stock_id: number;
    quantity: number;
    grade_tag_id: number;
  }>,
) => {
  try {
    await applyOutcome({ field: 'rejected', allocations });
    rejectDialogOpen.value = false;
  } catch {
    /* notified in composable */
  }
};

const onDeletePaper = async () => {
  const ok = await requestConfirmation(
    'Delete this delivery paper? This cannot be undone.',
    'Delete delivery paper',
    'Delete',
  );
  if (!ok) return;
  await deleteMutation.mutateAsync();
};

const goBack = () => {
  if (props.documentType === 'shop_order') {
    void router.push({
      name: 'app-shop-order-detail-page',
      params: { tenantSlug: authStore.tenantSlug || '', id: String(props.documentId) },
    });
    return;
  }
  void router.push({
    name: 'product-based-costing-file-details-page',
    params: { tenantSlug: authStore.tenantSlug || '', id: String(props.documentId) },
  });
};

onBeforeRouteLeave(async () => {
  if (!documentDirty.value) return true;
  return requestConfirmation('Discard unsaved changes?', 'Unsaved changes', 'Leave');
});
</script>

<style scoped>
.delivery-paper-close-bills {
  max-width: 100%;
}

.delivery-paper-close-bill-chip {
  max-width: 100%;
}

.delivery-paper-header-actions {
  margin-left: auto;
}

.delivery-paper-outcome-actions {
  margin-right: auto;
}

.delivery-paper-status-select {
  min-width: 132px;
  max-width: 160px;
}

.delivery-paper-status-select :deep(.q-field__control),
.delivery-paper-status-select :deep(.q-field__marginal) {
  height: 40px;
  min-height: 40px;
}

.delivery-paper-save-btn {
  height: 40px;
  min-height: 40px;
  padding-left: 12px;
  padding-right: 12px;
}

.delivery-paper-header-btn {
  height: 40px;
  min-height: 40px;
  padding-left: 10px;
  padding-right: 10px;
}
</style>
