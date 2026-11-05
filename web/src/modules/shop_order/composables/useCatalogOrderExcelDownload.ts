import type { QVueGlobals } from 'quasar';
import { buildCostingExcelWorkbook } from 'src/modules/product_based_costing/utils/buildCostingExcelWorkbook';
import { safeNamePart } from 'src/modules/product_based_costing/composables/useProductBasedCostingFileDetailsState';
import type { ShopOrder, ShopOrderItem } from '../types';
import { mapCatalogOrderToCostingExcelInput } from '../utils/mapCatalogOrderToCostingExcelInput';

function shopOrderCustomerNameForExport(order: ShopOrder): string {
  const groupName = order.customer_group_name?.trim();
  if (groupName) return groupName;
  if (order.recipient_name?.trim()) return order.recipient_name.trim();
  if (order.name?.trim()) return order.name.trim();
  return order.shop_name?.trim() ?? '';
}

export function useCatalogOrderExcelDownload() {
  const downloadCatalogOrderExcel = async (
    $q: QVueGlobals,
    order: ShopOrder | null,
    items: ShopOrderItem[],
    options?: { includeImages?: boolean },
  ) => {
    if (!order) {
      $q.notify({ type: 'warning', message: 'No order loaded.' });
      return;
    }
    if (!items.length) {
      $q.notify({ type: 'warning', message: 'No line items to export.' });
      return;
    }

    const loading = $q.loading.show({ message: 'Generating Excel...' });

    try {
      const input = mapCatalogOrderToCostingExcelInput(order, items);
      const workbook = await buildCostingExcelWorkbook({
        ...input,
        includeImages: options?.includeImages !== false,
      });
      const buffer = await workbook.xlsx.writeBuffer();
      const blob = new Blob([buffer], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      });
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      const orderPart = safeNamePart(order.order_no || `shop_order_${order.id}`);
      const customerPart = safeNamePart(shopOrderCustomerNameForExport(order));
      const base = [orderPart, customerPart].filter(Boolean).join('_');
      anchor.href = url;
      anchor.download = `${base || `shop_order_${order.id}`}.xlsx`;
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

  return { downloadCatalogOrderExcel };
}
