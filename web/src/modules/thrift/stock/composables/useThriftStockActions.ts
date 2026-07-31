import { ref, computed, type Ref } from 'vue';
import { useQuasar, copyToClipboard } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ThriftStock, ThriftSection, ThriftCondition } from '../types';
import {
  useUpdateStockMutation,
  useUpdateStockStatusMutation,
  useDeleteStockMutation,
} from './useThriftStockMutations';
import { deleteStockCloudinaryImageStrict } from 'src/utils/stockImageClient';
import {
  thriftStockRepository,
  type ThriftStockPricingInput,
} from '../repositories/thriftStockRepository';
import { downloadCsv, rowsToCsv } from 'src/utils/csvExport';
import { formatThriftStockMeasurements } from 'src/modules/thrift/shared/utils/formatThriftStockMeasurements';
import { computeThriftUnitCosts, type ThriftUnitCostBreakdown } from 'src/modules/thrift/shared/utils/computeThriftUnitCosts';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import type { ShipmentOption } from './useThriftStockCosting';

export function useThriftStockActions(
  stocks: Ref<ThriftStock[]>,
  costBreakdownByStockId: Ref<Record<number, ThriftUnitCostBreakdown>>,
  shipmentStocksCache: Ref<Map<number, ThriftStock[]>>,
  invalidateShipmentCache: (shipmentId: number) => void,
  shipmentById: Ref<Map<number, ShipmentOption>>,
  settings: Ref<any>,
  boxesList: Ref<Array<{ id: number; name: string }>>,
  shipmentPurchaseCurrency: (shipmentId: number | null | undefined) => ThriftCurrency | undefined,
  shipmentCostCurrency: (shipmentId: number | null | undefined) => ThriftCurrency | undefined,
  buildPricingFromRow: (row: ThriftStock) => ThriftStockPricingInput,
) {
  const $q = useQuasar();
  const authStore = useAuthStore();

  const updateStockMutation = useUpdateStockMutation();
  const updateStockStatusMutation = useUpdateStockStatusMutation();
  const deleteStockMutation = useDeleteStockMutation();

  // Selection state
  const selectedStockIds = ref<number[]>([]);
  const selectedRow = ref<ThriftStock | null>(null);

  // Dialog & operation flags
  const deleteConfirmOpen = ref(false);
  const deleteLoading = ref(false);
  const bulkDeleteConfirmOpen = ref(false);
  const bulkDeleteLoading = ref(false);
  const csvExportLoading = ref(false);

  // Barcode preview
  const barcodePreviewOpen = ref(false);
  const previewBarcodeValue = ref('');
  const previewStockLabel = ref('');

  const allPageRowsSelected = computed(() => {
    if (!stocks.value.length) return false;
    return stocks.value.every((row) => selectedStockIds.value.includes(row.id));
  });

  const somePageRowsSelected = computed(() => {
    return stocks.value.some((row) => selectedStockIds.value.includes(row.id));
  });

  function toggleSelectAllPage(checked: boolean) {
    const pageIds = stocks.value.map((r) => r.id);
    if (checked) {
      const combined = new Set([...selectedStockIds.value, ...pageIds]);
      selectedStockIds.value = Array.from(combined);
    } else {
      selectedStockIds.value = selectedStockIds.value.filter((id) => !pageIds.includes(id));
    }
  }

  function toggleStockSelection(id: number, checked: boolean) {
    if (checked) {
      if (!selectedStockIds.value.includes(id)) selectedStockIds.value.push(id);
    } else {
      selectedStockIds.value = selectedStockIds.value.filter((i) => i !== id);
    }
  }

  function clearStockSelection() {
    selectedStockIds.value = [];
  }

  function confirmDelete(row: ThriftStock) {
    selectedRow.value = row;
    deleteConfirmOpen.value = true;
  }

  function confirmBulkDelete() {
    if (!selectedStockIds.value.length) return;
    bulkDeleteConfirmOpen.value = true;
  }

  async function deleteItem() {
    if (!selectedRow.value) return;
    const target = {
      id: selectedRow.value.id,
      imageUrl: selectedRow.value.image_url ?? undefined,
      shipmentId: selectedRow.value.shipment_id,
    };
    deleteLoading.value = true;
    try {
      if (target.imageUrl) {
        await deleteStockCloudinaryImageStrict(target.imageUrl);
      }
      await deleteStockMutation.mutateAsync(target.id);
      if (target.shipmentId) {
        invalidateShipmentCache(target.shipmentId);
      }
      selectedStockIds.value = selectedStockIds.value.filter((id) => id !== target.id);
      $q.notify({ type: 'positive', message: 'Thrift stock deleted successfully' });
      deleteConfirmOpen.value = false;
      selectedRow.value = null;
    } catch (err: unknown) {
      $q.notify({ type: 'negative', message: (err as Error).message || 'Delete failed' });
    } finally {
      deleteLoading.value = false;
    }
  }

  async function deleteSelectedItems() {
    if (!selectedStockIds.value.length) return;
    bulkDeleteLoading.value = true;
    try {
      const targets = selectedStockIds.value
        .map((id) => {
          const row = stocks.value.find((s) => s.id === id);
          return row ? { id: row.id, imageUrl: row.image_url ?? undefined, shipmentId: row.shipment_id } : null;
        })
        .filter((t): t is { id: number; imageUrl: string | undefined; shipmentId: number } => t !== null);

      const affectedShipments = new Set<number>();
      for (const t of targets) {
        if (t.imageUrl) {
          await deleteStockCloudinaryImageStrict(t.imageUrl);
        }
        await deleteStockMutation.mutateAsync(t.id);
        if (t.shipmentId) affectedShipments.add(t.shipmentId);
      }

      for (const shipmentId of affectedShipments) {
        invalidateShipmentCache(shipmentId);
      }

      $q.notify({
        type: 'positive',
        message: `${targets.length} stock item(s) deleted successfully`,
      });
      selectedStockIds.value = [];
      bulkDeleteConfirmOpen.value = false;
    } catch (err: unknown) {
      $q.notify({ type: 'negative', message: (err as Error).message || 'Bulk delete failed' });
    } finally {
      bulkDeleteLoading.value = false;
    }
  }

  async function updateStatus(id: number, status: string) {
    try {
      await updateStockStatusMutation.mutateAsync({ id, status });
      $q.notify({ type: 'positive', message: `Stock status updated to ${status}` });
    } catch (err: unknown) {
      $q.notify({ type: 'negative', message: (err as Error).message || 'Failed to update status' });
    }
  }

  function openBarcodePreview(row: ThriftStock) {
    previewBarcodeValue.value = row.barcode || '';
    previewStockLabel.value = [row.brand_name, row.name].filter(Boolean).join(' - ');
    barcodePreviewOpen.value = true;
  }

  async function copyPreviewBarcode() {
    if (!previewBarcodeValue.value) return;
    try {
      await copyToClipboard(previewBarcodeValue.value);
      $q.notify({ type: 'positive', message: 'Barcode copied to clipboard' });
    } catch (err) {
      console.error('Copy barcode failed:', err);
    }
  }

  async function saveStockCell(
    row: ThriftStock,
    stockPatch: Partial<ThriftStock> = {},
    pricingPatch?: Partial<ThriftStockPricingInput>,
  ) {
    const isManual =
      pricingPatch?.is_listed_price_manual !== undefined
        ? !!pricingPatch.is_listed_price_manual
        : !!row.pricing?.is_listed_price_manual;

    const finalPricingPatch = pricingPatch ? { ...pricingPatch } : {};

    if (!isManual && row.shipment_id) {
      const shipment = shipmentById.value.get(row.shipment_id);
      if (shipment) {
        const currentPricing = {
          ...buildPricingFromRow(row),
          ...pricingPatch,
          is_listed_price_manual: false,
        };
        const currentSettings = settings.value;

        const updatedRow = { ...row, ...stockPatch, pricing: currentPricing };
        const cache = shipmentStocksCache.value.get(row.shipment_id) || [];
        const mergedStocks = cache.map((item) => (item.id === row.id ? updatedRow : item));

        const U = mergedStocks.reduce((acc, s) => acc + (s.quantity || 0), 0);
        const breakdown = computeThriftUnitCosts(
          updatedRow,
          shipment,
          currentSettings || {},
          Math.max(U, 1),
          currentPricing,
          mergedStocks,
        );

        finalPricingPatch.listed_unit_price = breakdown.suggested_sell_unit_price;
        finalPricingPatch.is_listed_price_manual = false;
      }
    }

    const pricing = { ...buildPricingFromRow(row), ...pricingPatch, ...finalPricingPatch };
    const updated = await updateStockMutation.mutateAsync({
      id: row.id,
      stock: stockPatch,
      pricing,
    });

    if (row.shipment_id) {
      const cache = shipmentStocksCache.value.get(row.shipment_id);
      if (cache) {
        const idx = cache.findIndex((item) => item.id === row.id);
        if (idx !== -1) {
          cache[idx] = updated;
          shipmentStocksCache.value = new Map(shipmentStocksCache.value);
        }
      }
    }

    $q.notify({ type: 'positive', message: 'Stock updated' });
  }

  function onTextCellSave(row: ThriftStock, field: string, val: string) {
    const targetField = field as 'barcode' | 'name' | 'brand_name';
    const v = val.trim();
    if (targetField === 'barcode' && !v) {
      $q.notify({ type: 'warning', message: 'Barcode cannot be empty' });
      return;
    }
    if ((row[targetField] || '') === v) return;
    void saveStockCell(row, { [targetField]: v });
  }

  function onSectionSave(row: ThriftStock, val: ThriftSection | null) {
    const newSection = val || 'UNISEX';
    if (row.section === newSection) return;
    void saveStockCell(row, { section: newSection });
  }

  function onConditionSave(row: ThriftStock, val: ThriftCondition | null) {
    const newCondition = val || 'EXCELLENT';
    if (row.condition === newCondition) return;
    void saveStockCell(row, { condition: newCondition });
  }

  function onBoxSave(row: ThriftStock, val: number | null) {
    if (row.box_id === val) return;
    void saveStockCell(row, { box_id: val ?? undefined });
  }

  function onNumberCellSave(
    row: ThriftStock,
    field: string,
    val: number,
  ) {
    const targetField = field as 'product_weight' | 'extra_weight' | 'quantity';
    const current = row[targetField] ?? 0;
    if (current === val) return;
    void saveStockCell(row, { [targetField]: val });
  }

  function onOriginUnitPriceSave(row: ThriftStock, val: number) {
    if ((row.origin_unit_price ?? 0) === val) return;
    void saveStockCell(row, { origin_unit_price: val });
  }

  function onExtraOriginUnitPriceSave(row: ThriftStock, val: number) {
    if ((row.extra_origin_unit_price ?? 0) === val) return;
    void saveStockCell(row, { extra_origin_unit_price: val });
  }

  function onItemMarkupSave(row: ThriftStock, pct: number) {
    const rate = Math.max(0, pct / 100);
    const patch: Partial<ThriftStockPricingInput> = { markup_rate_override: rate };
    if (row.pricing?.is_listed_price_manual) {
      patch.is_listed_price_manual = false;
    }
    void saveStockCell(row, {}, patch);
  }

  function resetItemMarkupToShipment(row: ThriftStock) {
    const patch: Partial<ThriftStockPricingInput> = { markup_rate_override: null };
    if (row.pricing?.is_listed_price_manual) {
      patch.is_listed_price_manual = false;
    }
    void saveStockCell(row, {}, patch);
  }

  function onListedUnitPriceSave(row: ThriftStock, val: number) {
    const breakdown = costBreakdownByStockId.value[row.id];
    const suggested = breakdown?.suggested_sell_unit_price ?? 0;

    if (Math.abs(val - suggested) < 0.01) {
      void saveStockCell(row, {}, { listed_unit_price: val, is_listed_price_manual: false });
    } else {
      void saveStockCell(row, {}, { listed_unit_price: val, is_listed_price_manual: true });
    }
  }

  function resetPriceToSuggested(row: ThriftStock) {
    const breakdown = costBreakdownByStockId.value[row.id];
    if (!breakdown) return;
    void saveStockCell(
      row,
      {},
      { listed_unit_price: breakdown.suggested_sell_unit_price, is_listed_price_manual: false },
    );
  }

  function onStatusCellSave(row: ThriftStock, val: string) {
    if ((row.status || 'AVAILABLE') === val) return;
    void updateStatus(row.id, val);
  }

  async function downloadStockCsv() {
    if (!authStore.tenantId) return;
    csvExportLoading.value = true;
    try {
      const list = await thriftStockRepository.fetchStocks(authStore.tenantId);

      const exportRows = list.map((stock: ThriftStock) => {
        const breakdown = costBreakdownByStockId.value[stock.id];
        const pCurr = shipmentPurchaseCurrency(stock.shipment_id);
        const cCurr = shipmentCostCurrency(stock.shipment_id);
        const box = boxesList.value.find((b) => b.id === stock.box_id);

        return {
          ID: stock.id,
          Barcode: stock.barcode || '',
          'Item Name': stock.name || '',
          Brand: stock.brand_name || '',
          Section: stock.section || '',
          Measurements: formatThriftStockMeasurements(stock),
          Box: box ? box.name : stock.box_id || '',
          'Product Wt (g)': stock.product_weight ?? '',
          'Extra Wt (g)': stock.extra_weight ?? '',
          Condition: stock.condition || '',
          Quantity: stock.quantity ?? '',
          [`Origin Unit Price (${pCurr?.code || ''})`]: stock.origin_unit_price ?? '',
          [`Extra Origin Unit Price (${pCurr?.code || ''})`]: stock.extra_origin_unit_price ?? '',
          [`Product Unit Cost (${cCurr?.code || ''})`]: breakdown?.product_unit_cost ?? '',
          [`Cargo Share (${cCurr?.code || ''})`]: breakdown?.cargo_share_per_unit ?? '',
          [`Ops Share (${cCurr?.code || ''})`]: breakdown?.ops_share_per_unit ?? '',
          [`Add'l Charges (${cCurr?.code || ''})`]: stock.additional_charges_cost ?? '',
          [`Landed Unit Cost (${cCurr?.code || ''})`]: breakdown?.landed_unit_cost ?? '',
          'Item Markup %': stock.pricing?.markup_rate_override != null ? `${stock.pricing.markup_rate_override * 100}%` : '',
          'Effective Margin %': breakdown?.effective_markup_pct != null ? `${breakdown.effective_markup_pct}%` : '',
          [`Listed Sell Price (${cCurr?.code || ''})`]: stock.pricing?.listed_unit_price ?? '',
          Status: stock.status || 'AVAILABLE',
        };
      });

      const headers = Object.keys(exportRows[0] || {});
      const csvStr = rowsToCsv(headers, exportRows);
      const dateStr = new Date().toISOString().slice(0, 10);
      downloadCsv(`thrift-stocks-${dateStr}.csv`, csvStr);
      $q.notify({ type: 'positive', message: `Exported ${exportRows.length} stock items` });
    } catch (err: unknown) {
      $q.notify({ type: 'negative', message: (err as Error).message || 'Export failed' });
    } finally {
      csvExportLoading.value = false;
    }
  }

  return {
    selectedStockIds,
    selectedRow,
    deleteConfirmOpen,
    deleteLoading,
    bulkDeleteConfirmOpen,
    bulkDeleteLoading,
    csvExportLoading,
    barcodePreviewOpen,
    previewBarcodeValue,
    previewStockLabel,
    allPageRowsSelected,
    somePageRowsSelected,
    toggleSelectAllPage,
    toggleStockSelection,
    clearStockSelection,
    confirmDelete,
    confirmBulkDelete,
    deleteItem,
    deleteSelectedItems,
    updateStatus,
    openBarcodePreview,
    copyPreviewBarcode,
    saveStockCell,
    onTextCellSave,
    onSectionSave,
    onConditionSave,
    onBoxSave,
    onNumberCellSave,
    onOriginUnitPriceSave,
    onExtraOriginUnitPriceSave,
    onItemMarkupSave,
    resetItemMarkupToShipment,
    onListedUnitPriceSave,
    resetPriceToSuggested,
    onStatusCellSave,
    downloadStockCsv,
  };
}
