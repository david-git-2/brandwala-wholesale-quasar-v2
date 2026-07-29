import { computed, type Ref } from 'vue';
import type { QVueGlobals } from 'quasar';
import type { ProductBasedCostingFile, ProductBasedCostingItem } from '../types';
import { toNumberSafe } from '../utils/pricing';
import { buildCostingExcelWorkbook } from '../utils/buildCostingExcelWorkbook';

export const workflowStatuses = [
  'pending',
  'offered',
  'confirmed',
  'placing_order',
  'ready_for_shipment',
  'invoicing',
  'delivered',
] as const;

export const allColumnNames = [
  'select',
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'qty',
  'confirmedQty',
  'orderedQty',
  'deliveredQty',
  'barcodeText',
  'website',
  'priceGbp',
  'totalPurchasePriceGbp',
  'productWeight',
  'packageWeight',
  'totalWeight',
  'cargoRate',
  'cargoCostGbp',
  'totalCostGbp',
  'rowTotalCostGbp',
  'costBdt',
  'totalCostBdt',
  'offerPriceBdt',
  'totalBdt',
  'profitPerUnitBdt',
  'profitBdt',
  'profitRate',
  'status',
  'action',
];

export const alwaysVisibleColumns = ['select', 'sl', 'image', 'name'];

export const columnSelectorOptions = [
  { label: 'Brand', value: 'brand' },
  { label: 'Note', value: 'note' },
  { label: 'Qty', value: 'qty' },
  { label: 'Confirmed Qty', value: 'confirmedQty' },
  { label: 'Ordered Qty', value: 'orderedQty' },
  { label: 'Delivered Qty', value: 'deliveredQty' },
  { label: 'Barcode / Code / Product ID', value: 'barcodeText' },
  { label: 'Website', value: 'website' },
  { label: 'Price (GBP)/Unit', value: 'priceGbp' },
  { label: 'Total Purchase Price (GBP)', value: 'totalPurchasePriceGbp' },
  { label: 'Product Wt (g/Unit)', value: 'productWeight' },
  { label: 'Package Wt (g/Unit)', value: 'packageWeight' },
  { label: 'Total Wt (g/Unit)', value: 'totalWeight' },
  { label: 'Cargo Rate', value: 'cargoRate' },
  { label: 'Cargo Cost (GBP/Unit)', value: 'cargoCostGbp' },
  { label: 'Total Cost (GBP/Unit)', value: 'totalCostGbp' },
  { label: 'Row Total Cost (GBP)', value: 'rowTotalCostGbp' },
  { label: 'Cost (BDT/Unit)', value: 'costBdt' },
  { label: 'Row Total Cost (BDT)', value: 'totalCostBdt' },
  { label: 'Offer Price (BDT/Unit)', value: 'offerPriceBdt' },
  { label: 'Row Offer Total (BDT)', value: 'totalBdt' },
  { label: 'Profit (BDT/Unit)', value: 'profitPerUnitBdt' },
  { label: 'Row Total Profit (BDT)', value: 'profitBdt' },
  { label: 'Profit Rate (%)', value: 'profitRate' },
  { label: 'Status', value: 'status' },
  { label: 'Action', value: 'action' },
];

export function formatMoney(val: number): string {
  return val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function formatStatusLabel(value: string): string {
  return value.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
}

export function isPassedStatus(currentStatus: string, st: string): boolean {
  if (currentStatus === 'cancelled') {
    return false;
  }
  const currentIdx = workflowStatuses.indexOf(currentStatus as (typeof workflowStatuses)[number]);
  const targetIdx = workflowStatuses.indexOf(st as (typeof workflowStatuses)[number]);
  return currentIdx > -1 && targetIdx > -1 && targetIdx < currentIdx;
}

export function getStatusColor(st: string): string {
  switch (st) {
    case 'pending':
      return 'orange-8';
    case 'offered':
      return 'blue-8';
    case 'confirmed':
      return 'blue-9';
    case 'placing_order':
      return 'indigo-8';
    case 'ready_for_shipment':
      return 'green-8';
    case 'invoicing':
      return 'purple-8';
    case 'delivered':
      return 'teal-9';
    case 'cancelled':
      return 'negative';
    default:
      return 'primary';
  }
}

export function getDefaultVisibleColumnsForStatus(fileStatus: string): string[] {
  const baseCols = ['select', 'sl', 'image', 'name'];
  switch (fileStatus) {
    case 'confirmed':
      return [...baseCols, 'qty', 'confirmedQty', 'status', 'action'];
    case 'placing_order':
      return [...baseCols, 'confirmedQty', 'orderedQty', 'barcodeText', 'status', 'action'];
    case 'invoicing':
      return [
        ...baseCols,
        'confirmedQty',
        'orderedQty',
        'deliveredQty',
        'barcodeText',
        'priceGbp',
        'costBdt',
        'status',
        'action',
      ];
    case 'delivered':
      return [...allColumnNames];
    default:
      return [...allColumnNames];
  }
}

export function safeNamePart(value: string): string {
  return value.replace(/[^a-z0-9-_]+/gi, '_').replace(/^_+|_+$/g, '');
}

export function useProductBasedCostingFileDetailsState(options: {
  costingItems: Ref<ProductBasedCostingItem[]>;
  cargoRateValue: Ref<number>;
  conversionRateValue: Ref<number>;
}) {
  const summaryMetrics = computed(() => {
    const items = options.costingItems.value;
    let totalQuantity = 0;
    let goodsCostGbp = 0;
    let cargoWeightGrams = 0;
    let cargoCostGbp = 0;

    for (const item of items) {
      const qty = toNumberSafe(item.quantity);
      const priceGbp = toNumberSafe(item.price_gbp);
      const prodWt = toNumberSafe(item.product_weight);
      const pkgWt = toNumberSafe(item.package_weight);
      const totalWtPerUnit = prodWt + pkgWt;

      totalQuantity += qty;
      goodsCostGbp += priceGbp * qty;
      cargoWeightGrams += totalWtPerUnit * qty;
      cargoCostGbp += ((totalWtPerUnit / 1000) * options.cargoRateValue.value) * qty;
    }

    const cargoWeightKg = cargoWeightGrams / 1000;
    const rate = options.conversionRateValue.value;
    const goodsCostBdt = goodsCostGbp * rate;
    const cargoCostBdt = cargoCostGbp * rate;
    const totalCostBdt = goodsCostBdt + cargoCostBdt;

    return {
      totalQuantity,
      goodsCostGbp,
      goodsCostBdt,
      cargoWeightKg,
      cargoCostGbp,
      cargoCostBdt,
      totalCostBdt,
    };
  });

  const downloadExcel = async (
    $q: QVueGlobals,
    file: ProductBasedCostingFile | null,
    items: ProductBasedCostingItem[],
  ) => {
    if (!file) {
      $q.notify({ type: 'warning', message: 'No costing file selected.' });
      return;
    }

    const loading = $q.loading.show({ message: 'Generating Excel...' });

    try {
      const workbook = await buildCostingExcelWorkbook({
        file,
        items,
      });

      const buffer = await workbook.xlsx.writeBuffer();
      const blob = new Blob([buffer], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      });
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      const fileTitle = safeNamePart(file.name ?? `costing_file_${file.id}`);
      anchor.href = url;
      anchor.download = `${fileTitle || `costing_file_${file.id}`}.xlsx`;
      anchor.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      $q.notify({
        type: 'negative',
        message: error instanceof Error ? error.message : 'Failed to generate Excel.',
      });
    } finally {
      loading();
    }
  };

  return {
    summaryMetrics,
    downloadExcel,
  };
}
