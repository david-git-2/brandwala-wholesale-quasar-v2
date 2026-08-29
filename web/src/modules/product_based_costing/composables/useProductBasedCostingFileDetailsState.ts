import { computed, type Ref } from 'vue';
import type { QVueGlobals } from 'quasar';
import type { ProductBasedCostingFile, ProductBasedCostingItem } from '../types';
import { toNumberSafe } from '../utils/pricing';
import { buildCostingExcelWorkbook } from '../utils/buildCostingExcelWorkbook';

export const workflowStatuses = [
  'pending',
  'offered',
  'confirmed',
  'procuring',
  'ready_for_shipment',
  'delivered',
] as const;

export const quoteStatuses = ['pending', 'offered'] as const;
export const fulfillmentStatuses = [
  'confirmed',
  'procuring',
  'ready_for_shipment',
  'delivered',
] as const;

export function normalizePbcFileStatus(status: string): string {
  const st = (status || '').toLowerCase();
  if (st === 'placing_order') return 'procuring';
  if (st === 'invoicing') return 'delivered';
  return st;
}

export const quoteVisibleColumns = [
  'select',
  'sl',
  'image',
  'name',
  'qty',
  'priceGbp',
  'productWeight',
  'packageWeight',
  'offerPriceBdt',
  'profitRate',
];

export const allColumnNames = [
  'select',
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'qty',
  'confirmedQty',
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
];

export const alwaysVisibleColumns = ['select', 'sl', 'image', 'name'];

export const columnSelectorOptions = [
  { label: 'Brand', value: 'brand' },
  { label: 'Note', value: 'note' },
  { label: 'Qty', value: 'qty' },
  { label: 'Confirmed Qty', value: 'confirmedQty' },
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
];

export function formatMoney(val: number | null | undefined): string {
  const num = typeof val === 'number' && !isNaN(val) ? val : 0;
  return num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function formatStatusLabel(value: string): string {
  switch (normalizePbcFileStatus(value)) {
    case 'pending':
      return 'Draft';
    case 'offered':
      return 'Offered';
    case 'confirmed':
      return 'Confirmed';
    case 'procuring':
      return 'Procuring';
    case 'ready_for_shipment':
      return 'Ready for Shipment';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return value.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
  }
}

export type StatusHint = {
  when: string;
  does: string;
};

export function getFileStatusHint(value: string): StatusHint | null {
  switch (normalizePbcFileStatus(value)) {
    case 'pending':
      return {
        when: 'You are making the price list',
        does: 'Add items. Send the PDF or screenshot.',
      };
    case 'offered':
      return {
        when: 'You already sent the PDF or screenshot',
        does: 'Saves that you sent it. Does not send a message.',
      };
    case 'confirmed':
      return {
        when: 'They said yes',
        does: 'Saves how many they want. Change the number if they want less.',
      };
    case 'procuring':
      return {
        when: 'You are buying the goods',
        does: 'Type how many you got for each item.',
      };
    case 'ready_for_shipment':
      return {
        when: 'You know how many you got',
        does: 'Put those items on a shipment.',
      };
    case 'delivered':
      return {
        when: 'All goods have arrived',
        does: 'This job is finished.',
      };
    case 'cancelled':
      return {
        when: 'This job is stopped',
        does: 'Closes the file.',
      };
    default:
      return null;
  }
}

export function getItemStatusHint(value: string): StatusHint | null {
  switch ((value || '').toLowerCase()) {
    case 'pending':
      return {
        when: 'They have not said yes yet',
        does: 'This item is only on the price list.',
      };
    case 'accepted':
      return {
        when: 'They want this item',
        does: 'Buy it and ship it.',
      };
    case 'rejected':
      return {
        when: 'They do not want this item',
        does: 'Skip it. Do not buy it.',
      };
    case 'unavailable':
      return {
        when: 'You got none of this item',
        does: 'Keep it for next time.',
      };
    case 'partial':
    case 'partially_available':
      return {
        when: 'You got some, but not all',
        does: 'Keep the rest for next time.',
      };
    case 'on_shipment':
      return {
        when: 'This item is already on a shipment',
        does: 'Do not buy it again.',
      };
    default:
      return null;
  }
}

export function isPassedStatus(currentStatus: string, st: string): boolean {
  if (normalizePbcFileStatus(currentStatus) === 'cancelled') {
    return false;
  }
  const currentIdx = workflowStatuses.indexOf(
    normalizePbcFileStatus(currentStatus) as (typeof workflowStatuses)[number],
  );
  const targetIdx = workflowStatuses.indexOf(
    normalizePbcFileStatus(st) as (typeof workflowStatuses)[number],
  );
  return currentIdx > -1 && targetIdx > -1 && targetIdx < currentIdx;
}

export function getStatusColor(st: string): string {
  switch (normalizePbcFileStatus(st)) {
    case 'pending':
      return 'orange-8';
    case 'offered':
      return 'blue-8';
    case 'confirmed':
      return 'blue-9';
    case 'procuring':
      return 'indigo-8';
    case 'ready_for_shipment':
      return 'green-8';
    case 'delivered':
      return 'teal-9';
    case 'cancelled':
      return 'negative';
    default:
      return 'primary';
  }
}

export function isFulfillmentStatus(fileStatus: string): boolean {
  return (fulfillmentStatuses as readonly string[]).includes(fileStatus);
}

export function getDefaultVisibleColumnsForStatus(fileStatus: string): string[] {
  const baseCols = ['select', 'sl', 'image', 'name'];
  switch (normalizePbcFileStatus(fileStatus)) {
    case 'confirmed':
      return [
        ...baseCols,
        'qty',
        'confirmedQty',
        'priceGbp',
        'productWeight',
        'packageWeight',
        'offerPriceBdt',
        'costBdt',
        'profitRate',
        'status',
      ];
    case 'procuring':
    case 'ready_for_shipment':
      return [...baseCols, 'confirmedQty', 'barcodeText', 'status'];
    case 'delivered':
      return [...allColumnNames];
    default:
      return [...quoteVisibleColumns];
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
