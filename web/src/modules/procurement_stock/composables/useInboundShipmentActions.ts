import { ref, computed, watch, onMounted, type Ref } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar, type QTableColumn } from 'quasar';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { globalShipmentRepository } from '../repositories/globalShipmentRepository';
import { tenantRepository } from 'src/modules/tenant/repositories/tenantRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';
import type { GlobalShipmentCostEntry, CostEntriesSavePayload } from '../types/shipmentCostEntry';
import type { ReturnLineDraft } from '../components/ShipmentVendorReturnCard.vue';
import ShipmentItemFormDialog from '../components/ShipmentItemFormDialog.vue';
import AddShipmentItemsDrawer from '../components/AddShipmentItemsDrawer.vue';
import BulkPasteDialog from '../components/BulkPasteDialog.vue';
import ReceiveShipmentDialog from '../components/ReceiveShipmentDialog.vue';
import { buildShipmentExcelWorkbook } from '../utils/buildShipmentExcelWorkbook';
import {
  showSuccessNotification,
  showErrorNotification,
  showWarningNotification,
  requestConfirmation,
} from 'src/utils/appFeedback';

export function useInboundShipmentActions(options: {
  shipmentId: number;
  activeTab: Ref<'lines' | 'balance' | 'cost' | 'receive'>;
  calculations: ReturnType<typeof import('./useInboundShipmentCalculations').useInboundShipmentCalculations>;
  assignShopCard: Ref<HTMLElement | null>;
  paySettleCard: Ref<HTMLElement | null>;
}) {
  const { shipmentId, activeTab, calculations, assignShopCard, paySettleCard } = options;

  const router = useRouter();
  const $q = useQuasar();
  const authStore = useAuthStore();
  const vendorStore = useVendorStore();
  const shipmentStore = useGlobalShipmentStore();

  const updatingStatus = ref(false);
  const targetUpdatingStatus = ref<string | null>(null);
  const progressTargetId = ref<number | null>(null);

  const loadingVendors = ref(false);
  const ensureVendorsLoaded = async () => {
    if (authStore.tenantId && vendorStore.items.length === 0) {
      loadingVendors.value = true;
      try {
        await vendorStore.fetchVendors(authStore.tenantId);
      } catch (err) {
        console.error('Failed to load vendors', err);
      } finally {
        loadingVendors.value = false;
      }
    }
  };

  const vendorOptions = computed(() =>
    vendorStore.items.map((v) => ({
      label: v.is_default ? `${v.name} (default)` : v.name,
      value: v.id,
    })),
  );

  const currentVendorLabel = computed(() => {
    const vId = shipmentStore.currentShipment?.vendor_id;
    if (!vId) return 'Select Vendor';
    const found = vendorStore.items.find((v) => v.id === vId);
    return found ? found.name : `Vendor #${vId}`;
  });

  const loadingCargo = ref(false);
  const cargoCompanies = ref<Array<{ id: number; name: string; code: string }>>([]);
  const ensureCargoLoaded = async () => {
    if (authStore.tenantId && cargoCompanies.value.length === 0) {
      loadingCargo.value = true;
      try {
        cargoCompanies.value = await globalShipmentRepository.listCargoCompaniesForTenant(
          authStore.tenantId,
        );
      } catch (err) {
        console.error('Failed to load cargo companies', err);
      } finally {
        loadingCargo.value = false;
      }
    }
  };

  const cargoOptions = computed(() =>
    cargoCompanies.value.map((c) => ({
      label: `${c.name} (${c.code})`,
      value: c.id,
    })),
  );

  const currentCargoLabel = computed(() => {
    const cId = shipmentStore.currentShipment?.cargo_company_id;
    if (!cId) return 'Cargo: None';
    const found = cargoCompanies.value.find((c) => c.id === cId);
    return found ? `Cargo: ${found.name}` : `Cargo #${cId}`;
  });

  onMounted(() => {
    ensureVendorsLoaded();
    ensureCargoLoaded();
  });

  const typeOptions = [
    { label: 'International', value: 'international' as const },
    { label: 'Local', value: 'local' as const },
    { label: 'Transfer', value: 'transfer' as const },
  ];

  const saveInlineName = async (next: string) => {
    if (!shipmentId) return;
    try {
      await shipmentStore.updateShipment(shipmentId, { name: next });
      showSuccessNotification('Shipment name updated');
    } catch (err: any) {
      showErrorNotification(err.message || 'Failed to update shipment name');
    }
  };

  const saveInlineType = async (typeVal: 'international' | 'local' | 'transfer') => {
    if (!shipmentId) return;
    try {
      await shipmentStore.updateShipment(shipmentId, { type: typeVal });
      showSuccessNotification('Shipment type updated');
    } catch (err: any) {
      showErrorNotification(err.message || 'Failed to update shipment type');
    }
  };

  const saveInlineVendor = async (val: number | null) => {
    if (!shipmentId || val == null) return;
    try {
      await shipmentStore.updateShipment(shipmentId, { vendor_id: val });
      showSuccessNotification('Vendor updated');
    } catch (err: any) {
      showErrorNotification(err.message || 'Failed to update vendor');
    }
  };

  const saveInlineCargo = async (val: number | null) => {
    if (!shipmentId) return;
    try {
      await shipmentStore.updateShipment(shipmentId, { cargo_company_id: val });
      showSuccessNotification('Cargo vendor updated');
    } catch (err: any) {
      showErrorNotification(err.message || 'Failed to update cargo vendor');
    }
  };

  const parentTenantId = computed(() => authStore.tenantId);
  const { data: childTenants, isLoading: childTenantsLoading } = useQuery({
    queryKey: computed(() => procurementStockQueryKeys.childTenants(parentTenantId.value ?? 0)),
    queryFn: async () => {
      const tenants = await tenantRepository.listTenants();
      return tenants.filter((t) => t.parent_id === parentTenantId.value);
    },
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => !!parentTenantId.value),
  });

  const childTenantOptions = computed(() =>
    (childTenants.value ?? []).map((t) => ({ label: t.name, value: t.id })),
  );
  const selectedChildTenantId = ref<number | null>(null);
  const assigningChild = ref(false);
  const paySettling = ref(false);
  const returnSubmitting = ref(false);
  const returnOutcome = ref<'cash_refund' | 'store_credit'>('store_credit');

  const returnLines = ref<ReturnLineDraft[]>([]);

  const returnOutcomeOptions = [
    { label: 'Store credit (vendor wallet)', value: 'store_credit' as const },
    { label: 'Cash refund (tenant cash)', value: 'cash_refund' as const },
  ];

  const settleEntryColumns: QTableColumn<GlobalShipmentCostEntry>[] = [
    { name: 'cost_type', label: 'Type', field: 'cost_type', align: 'left' },
    { name: 'amount', label: 'Amount (BDT)', field: 'amount', align: 'right' },
    { name: 'payment_source', label: 'Source', field: 'payment_source', align: 'left' },
    { name: 'entity_type', label: 'Payee', field: 'entity_type', align: 'left' },
  ];

  const returnLineColumns: QTableColumn<ReturnLineDraft>[] = [
    { name: 'name', label: 'Product', field: 'name', align: 'left' },
    { name: 'max_qty', label: 'Ordered', field: 'max_qty', align: 'right' },
    { name: 'return_qty', label: 'Return qty', field: 'return_qty', align: 'right' },
  ];

  watch(
    () => shipmentStore.currentShipment?.assigned_child_tenant_id,
    (id) => {
      selectedChildTenantId.value = id ?? null;
    },
    { immediate: true },
  );

  watch(
    () => shipmentStore.currentShipmentItems,
    (items) => {
      returnLines.value = (items ?? []).map((item) => ({
        shipment_item_id: item.id,
        name: item.name,
        max_qty: item.ordered_quantity ?? 0,
        return_qty: 0,
      }));
    },
    { immediate: true },
  );

  const settleableEntries = computed(() =>
    shipmentStore.currentCostEntries.filter(
      (e: any) =>
        e.payment_source &&
        e.entity_type &&
        (e.entity_type === 'vendor' || e.entity_type === 'cargo_company'),
    ),
  );

  const hasReturnQty = computed(() => returnLines.value.some((l) => l.return_qty > 0));

  const saveAssignChild = async () => {
    if (!authStore.tenantId) return;
    assigningChild.value = true;
    try {
      await shipmentStore.assignShipmentToChild(
        authStore.tenantId,
        selectedChildTenantId.value,
        shipmentId,
      );
      showSuccessNotification('Shop assignment updated');
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      showErrorNotification(msg || 'Failed to update assignment');
    } finally {
      assigningChild.value = false;
    }
  };

  const clearAssignChild = async () => {
    selectedChildTenantId.value = null;
    await saveAssignChild();
  };

  const confirmPaySettleAll = async () => {
    const ok = await requestConfirmation(
      `Pay ${settleableEntries.value.length} cost${settleableEntries.value.length === 1 ? '' : 's'} to the vendor or cargo company?`,
      'Pay costs',
      'Pay',
    );
    if (!ok) return;

    paySettling.value = true;
    try {
      const res = await shipmentStore.paySettleShipmentCosts(shipmentId);
      showSuccessNotification(
        res.wallet_posted
          ? `Settled ${res.settled_entries_count} entries — wallet posted.`
          : `Processed ${res.settled_entries_count} entries.`,
      );
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      showErrorNotification(msg || 'Settlement failed');
    } finally {
      paySettling.value = false;
    }
  };

  const confirmVendorReturn = async () => {
    const items = returnLines.value
      .filter((l) => l.return_qty > 0)
      .map((l) => ({ shipment_item_id: l.shipment_item_id, quantity: l.return_qty }));

    const ok = await requestConfirmation(
      `Return ${items.reduce((s, i) => s + i.quantity, 0)} pcs with ${returnOutcome.value === 'store_credit' ? 'store credit' : 'cash refund'}?`,
      'Submit vendor return',
      'Submit return',
    );
    if (!ok) return;

    returnSubmitting.value = true;
    try {
      await shipmentStore.returnShipmentToVendor(shipmentId, items, returnOutcome.value);
      showSuccessNotification('Vendor return submitted');
      returnLines.value = returnLines.value.map((l) => ({ ...l, return_qty: 0 }));
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      showErrorNotification(msg || 'Vendor return failed');
    } finally {
      returnSubmitting.value = false;
    }
  };

  const loadShipmentDetails = () => {
    if (!Number.isNaN(shipmentId)) {
      void shipmentStore.fetchShipmentDetails(shipmentId);
    }
  };

  const goBack = () => {
    router.back();
  };

  const changeProgress = async (tagId: number | null) => {
    if (!shipmentStore.currentShipment) return;
    const currentId =
      shipmentStore.currentShipment.progress_tag_id ??
      shipmentStore.currentShipment.progress_tag?.id ??
      null;
    if (currentId === tagId) return;
    progressTargetId.value = tagId;
    try {
      await shipmentStore.setProgressTag(shipmentStore.currentShipment.id, tagId);
    } catch (err) {
      showErrorNotification(err instanceof Error ? err.message : 'Failed to update progress');
    } finally {
      progressTargetId.value = null;
    }
  };

  const changeStatus = (newStatus: string) => {
    if (!shipmentStore.currentShipment) return;
    if (shipmentStore.currentShipment.status === newStatus) return;

    if (
      shipmentStore.currentShipment.status === 'received' ||
      shipmentStore.currentShipment.status === 'cancelled'
    ) {
      showWarningNotification(
        shipmentStore.currentShipment.status === 'received'
          ? 'To change status, please use the Rollback option to revert the shipment to Draft.'
          : 'Cancelled shipments cannot change status.',
      );
      return;
    }

    if (newStatus === 'cancelled') {
      $q.dialog({
        title: 'Cancel shipment',
        message: 'Mark this shipment as cancelled? This does not post stock.',
        cancel: true,
        persistent: true,
      }).onOk(() => {
        void (async () => {
          updatingStatus.value = true;
          targetUpdatingStatus.value = 'cancelled';
          try {
            await shipmentStore.updateShipment(shipmentId, { status: 'cancelled' });
            showSuccessNotification('Shipment cancelled.');
            loadShipmentDetails();
          } catch (err: any) {
            showErrorNotification(err.message || 'Failed to cancel shipment.');
          } finally {
            updatingStatus.value = false;
            targetUpdatingStatus.value = null;
          }
        })();
      });
      return;
    }

    if (newStatus === 'received') {
      if (!calculations.isSplitsComplete.value) {
        showWarningNotification('Please configure quantity splits for all line items first.');
        return;
      }

      $q.dialog({
        component: ReceiveShipmentDialog,
        componentProps: { shipmentId },
      }).onOk(() => {
        void loadShipmentDetails();
      });
      return;
    }

    $q.dialog({
      title: 'Confirm Status Change',
      message: `Are you sure you want to change the status of this shipment to "${newStatus}"?`,
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void (async () => {
        updatingStatus.value = true;
        targetUpdatingStatus.value = newStatus;
        try {
          await shipmentStore.updateShipment(shipmentId, { status: newStatus });
          showSuccessNotification(`Shipment status updated to: ${newStatus}`);
          loadShipmentDetails();
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          showErrorNotification(message || 'Failed to update status');
        } finally {
          updatingStatus.value = false;
          targetUpdatingStatus.value = null;
        }
      })();
    });
  };

  const rollbackShipmentToDraft = () => {
    if (!shipmentStore.currentShipment) return;

    $q.dialog({
      title: 'Rollback Shipment to Draft',
      message:
        'This will delete all active stock entries and allocations for this shipment. The shipment status will be set back to "Draft". Are you sure you want to proceed?',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void (async () => {
        updatingStatus.value = true;
        targetUpdatingStatus.value = 'draft';
        try {
          await shipmentStore.rollbackShipmentToDraft(shipmentId);
          showSuccessNotification('Shipment successfully rolled back to Draft.');
          loadShipmentDetails();
        } catch (err: any) {
          showErrorNotification(err.message || 'Failed to rollback shipment.');
        } finally {
          updatingStatus.value = false;
          targetUpdatingStatus.value = null;
        }
      })();
    });
  };

  const confirmDeleteShipment = () => {
    $q.dialog({
      title: 'Confirm Deletion',
      message:
        'Are you sure you want to delete this shipment? All shipment items will be deleted. This action cannot be undone.',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void (async () => {
        try {
          await shipmentStore.deleteShipment(shipmentId);
          showSuccessNotification('Shipment deleted successfully');
          goBack();
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          showErrorNotification(message || 'Failed to delete shipment');
        }
      })();
    });
  };

  const nextStep = computed(() => {
    const status = shipmentStore.currentShipment?.status;
    if (status === 'cancelled') {
      return {
        message: 'This shipment was cancelled.',
        label: null as string | null,
        disabled: true,
        reason: 'This shipment was cancelled.',
        action: null as (() => void) | null,
      };
    }
    if (status === 'received') {
      const assigned = shipmentStore.currentShipment?.assigned_child_tenant_id;
      if (!assigned && childTenantOptions.value.length > 0) {
        return {
          message: 'Assign to a shop so they can sell it.',
          label: 'Assign',
          disabled: false,
          reason: '',
          action: () => assignShopCard.value?.scrollIntoView({ behavior: 'smooth', block: 'start' }),
        };
      }
      if (settleableEntries.value.length > 0) {
        return {
          message: 'Pay the vendor or cargo company.',
          label: 'Pay',
          disabled: false,
          reason: '',
          action: () => paySettleCard.value?.scrollIntoView({ behavior: 'smooth', block: 'start' }),
        };
      }
      return {
        message: 'Goods are in the warehouse. Assign, pay, or return below if needed.',
        label: null,
        disabled: true,
        reason: '',
        action: null,
      };
    }
    if (!calculations.hasLineItems.value) {
      return {
        message: 'Add products, then continue.',
        label: 'Add items',
        disabled: false,
        reason: '',
        action: () => {
          activeTab.value = 'lines';
          openAddItems();
        },
      };
    }
    if (calculations.balanceNeedsAttention.value) {
      const both = calculations.weightNeedsAttention.value && calculations.purchaseNeedsAttention.value;
      return {
        message: 'Cargo weight or purchase total does not match.',
        label: both ? 'Fix balances' : calculations.weightNeedsAttention.value ? 'Fix weight' : 'Fix purchase',
        disabled: false,
        reason: '',
        action: () => {
          activeTab.value = 'balance';
        },
      };
    }
    if (status === 'in_transit') {
      if (!calculations.isSplitsComplete.value) {
        return {
          message: 'Split each line before receiving.',
          label: 'Configure splits',
          disabled: false,
          reason: '',
          action: () => {
            activeTab.value = 'lines';
          },
        };
      }
      return {
        message: 'Receive into the warehouse.',
        label: 'Add to stock',
        disabled: false,
        reason: '',
        action: () => {
          activeTab.value = 'receive';
          changeStatus('received');
        },
      };
    }
    return {
      message: 'Mark In transit when the goods have left the vendor.',
      label: 'In transit',
      disabled: false,
      reason: '',
      action: () => {
        changeStatus('in_transit');
      },
    };
  });

  const runPrimaryCta = () => {
    nextStep.value?.action?.();
  };

  const safeNamePart = (value: string) =>
    value.replace(/[^a-z0-9-_]+/gi, '_').replace(/^_+|_+$/g, '');

  const downloadExcel = async () => {
    if (!shipmentStore.currentShipment) {
      showWarningNotification('No shipment loaded.');
      return;
    }

    const loading = $q.loading.show({ message: 'Generating Excel...' });

    try {
      const workbook = await buildShipmentExcelWorkbook({
        shipment: shipmentStore.currentShipment,
        items: shipmentStore.currentShipmentItems ?? [],
        totals: calculations.totals.value,
        boxWeightSum: calculations.currentShipmentBoxesTotal.value,
        splitsSummary: calculations.splitsSummary.value,
        purchaseCurrencySymbol: calculations.currentPurchaseCurrencySymbol.value,
        costCurrencySymbol: calculations.currentCostCurrencySymbol.value,
      });

      const buffer = await workbook.xlsx.writeBuffer();
      const blob = new Blob([buffer], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      });
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      const fileTitle = safeNamePart(
        shipmentStore.currentShipment.name ?? `shipment_${shipmentStore.currentShipment.id}`,
      );
      anchor.href = url;
      anchor.download = `${fileTitle || `shipment_${shipmentStore.currentShipment.id}`}.xlsx`;
      anchor.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      showErrorNotification(error instanceof Error ? error.message : 'Failed to generate Excel.');
    } finally {
      loading();
    }
  };

  const openAddItems = () => {
    $q.dialog({
      component: AddShipmentItemsDrawer,
      componentProps: { shipmentId },
    });
  };

  const openBulkPaste = () => {
    $q.dialog({
      component: BulkPasteDialog,
    }).onOk(() => {
      loadShipmentDetails();
    });
  };

  const autoAcceptSplits = () => {
    $q.dialog({
      title: 'Auto Accept Quantity Splits',
      message:
        'This will automatically allocate 100% of the ordered quantity to "Standard Sellable" for all pending line items that do not have complete splits configured. Already completed splits will not be overwritten. Continue?',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void (async () => {
        try {
          await shipmentStore.autoAcceptAllSplits(shipmentId);
          showSuccessNotification('All pending splits auto-accepted successfully.');
        } catch (err: any) {
          showErrorNotification(err.message || 'Failed to auto-accept splits.');
        }
      })();
    });
  };

  const openEditItem = (item: GlobalShipmentItem) => {
    $q.dialog({
      component: ShipmentItemFormDialog,
      componentProps: {
        shipmentId,
        item,
        isReceived:
          shipmentStore.currentShipment?.status === 'in_transit' ||
          shipmentStore.currentShipment?.status === 'received' ||
          shipmentStore.currentShipment?.stock_ready === true,
      },
    });
  };

  const confirmDeleteItem = (itemId: number) => {
    $q.dialog({
      title: 'Confirm Deletion',
      message: 'Are you sure you want to delete this line item?',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void (async () => {
        try {
          await shipmentStore.deleteShipmentItem(itemId);
          showSuccessNotification('Item deleted successfully');
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          showErrorNotification(message || 'Failed to delete item');
        }
      })();
    });
  };

  const onSaveCostEntries = async (payload: CostEntriesSavePayload) => {
    try {
      const shipment = shipmentStore.currentShipment;
      if (!shipment) return;

      const prevWeight = shipment.received_weight;
      const nextWeight = payload.received_weight;
      const weightChanged =
        (prevWeight == null && nextWeight != null) ||
        (prevWeight != null && nextWeight == null) ||
        (prevWeight != null &&
          nextWeight != null &&
          Math.abs(prevWeight - nextWeight) > 0.0001);

      if (weightChanged) {
        await shipmentStore.updateShipment(shipmentId, {
          received_weight: nextWeight,
        });
      }

      await shipmentStore.saveCostEntries(shipmentId, payload.drafts);
      showSuccessNotification(
        calculations.isCostFinalized.value
          ? 'Costs revised and landed costs re-stamped.'
          : 'Cost entries saved.',
      );
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      showErrorNotification(msg || 'Failed to save cost entries.');
    }
  };

  return {
    updatingStatus,
    targetUpdatingStatus,
    progressTargetId,
    typeOptions,
    vendorOptions,
    currentVendorLabel,
    loadingVendors,
    cargoOptions,
    currentCargoLabel,
    loadingCargo,
    ensureVendorsLoaded,
    ensureCargoLoaded,
    saveInlineName,
    saveInlineType,
    saveInlineVendor,
    saveInlineCargo,
    childTenantOptions,
    childTenantsLoading,
    selectedChildTenantId,
    assigningChild,
    paySettling,
    returnSubmitting,
    returnOutcome,
    returnOutcomeOptions,
    returnLines,
    settleEntryColumns,
    returnLineColumns,
    settleableEntries,
    hasReturnQty,
    saveAssignChild,
    clearAssignChild,
    confirmPaySettleAll,
    confirmVendorReturn,
    loadShipmentDetails,
    goBack,
    changeProgress,
    changeStatus,
    rollbackShipmentToDraft,
    confirmDeleteShipment,
    nextStep,
    runPrimaryCta,
    downloadExcel,
    openAddItems,
    openBulkPaste,
    autoAcceptSplits,
    openEditItem,
    confirmDeleteItem,
    onSaveCostEntries,
  };
}
