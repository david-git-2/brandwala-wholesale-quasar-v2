import { defineStore } from 'pinia';
import { thriftStockRepository } from '../repositories/thriftStockRepository';
import type { ThriftStock } from '../types';

export const useThriftStockStore = defineStore('thrift_stock', {
  state: () => ({
    stocks: [] as ThriftStock[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadStocks(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.stocks = await thriftStockRepository.fetchStocks(tenantId);
      } catch (err: any) {
        this.error = err.message || 'Failed to load stock';
      } finally {
        this.loading = false;
      }
    },

    async createStock(
      tenantId: number,
      shipmentId: number,
      name: string,
      brandName: string,
      categoryId: number,
      typeId: number,
      section: string,
      shelfId: number,
      color: string,
      size: string,
      condition: string,
      sku: string,
      stockType: string,
      quantity: number,
      boxId: number | undefined,
      productWeight: number | undefined,
      extraWeight: number | undefined,
      note: string,
      userEmail: string,
      pricing: { cost_of_goods_sold: number; target_price: number; listed_price: number }
    ) {
      try {
        const stock = await thriftStockRepository.createStock(
          {
            tenant_id: tenantId,
            shipment_id: shipmentId,
            name,
            brand_name: brandName || '',
            category_id: categoryId,
            type_id: typeId,
            section: section as any,
            shelf_id: shelfId,
            color,
            size,
            condition: condition as any,
            sku,
            stock_type: stockType as any,
            quantity,
            box_id: boxId || undefined,
            product_weight: productWeight || undefined,
            extra_weight: extraWeight || undefined,
            status: 'AVAILABLE' as any,
            note: note || '',
            inserted_by: userEmail,
          },
          pricing
        );
        this.stocks.unshift(stock);
        return stock;
      } catch (err: any) {
        this.error = err.message || 'Failed to create stock';
        throw err;
      }
    },

    async updateStockStatus(id: number, status: string) {
      try {
        await thriftStockRepository.updateStockStatus(id, status);
        const idx = this.stocks.findIndex(s => s.id === id);
        if (idx !== -1) {
          this.stocks[idx]!.status = status as any;
        }
      } catch (err: any) {
        this.error = err.message || 'Failed to update stock status';
        throw err;
      }
    },
  },
});
