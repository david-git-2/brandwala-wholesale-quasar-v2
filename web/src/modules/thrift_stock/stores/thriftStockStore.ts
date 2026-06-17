import { defineStore } from 'pinia';
import { thriftStockRepository } from '../repositories/thriftStockRepository';
import type { ThriftStock, ThriftSection, ThriftCondition, ThriftStockType, ThriftStockStatus } from '../types';

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
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load stock';
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
      pricing: { cost_of_goods_sold: number; target_price: number; listed_price: number },
      imageUrl?: string,
      originPurchasePrice?: number
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
            section: section as ThriftSection,
            shelf_id: shelfId,
            color,
            size,
            condition: condition as ThriftCondition,
            sku,
            stock_type: stockType as ThriftStockType,
            quantity,
            box_id: boxId || undefined,
            product_weight: productWeight || undefined,
            extra_weight: extraWeight || undefined,
            status: 'AVAILABLE' as ThriftStockStatus,
            note: note || '',
            inserted_by: userEmail,
            origin_purchase_price: originPurchasePrice,
          },
          pricing,
          imageUrl
        );
        this.stocks.unshift(stock);
        return stock;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create stock';
        throw err;
      }
    },

    async updateStock(
      id: number,
      stock: Partial<ThriftStock>,
      pricing: { cost_of_goods_sold: number; target_price: number; listed_price: number }
    ) {
      try {
        const updated = await thriftStockRepository.updateStock(id, stock, pricing);
        const idx = this.stocks.findIndex(s => s.id === id);
        if (idx !== -1) {
          this.stocks[idx] = {
            ...this.stocks[idx],
            ...updated,
            // Keep previous image if not returned
            image_url: this.stocks[idx]?.image_url,
          };
        }
        return updated;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update stock';
        throw err;
      }
    },

    async updateStockStatus(id: number, status: string) {
      try {
        await thriftStockRepository.updateStockStatus(id, status);
        const idx = this.stocks.findIndex(s => s.id === id);
        const stock = this.stocks[idx];
        if (stock) {
          stock.status = status as ThriftStockStatus;
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update stock status';
        throw err;
      }
    },

    async deleteStock(id: number) {
      try {
        await thriftStockRepository.deleteStock(id);
        this.stocks = this.stocks.filter(s => s.id !== id);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete stock';
        throw err;
      }
    },
  },
});
