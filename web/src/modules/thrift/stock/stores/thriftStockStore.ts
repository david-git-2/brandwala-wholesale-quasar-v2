import { defineStore } from 'pinia';
import {
  thriftStockRepository,
  type ThriftStockPricingInput,
} from '../repositories/thriftStockRepository';
import type {
  ThriftStock,
  ThriftSection,
  ThriftCondition,
  ThriftStockType,
  ThriftStockStatus,
} from '../types';

export const useThriftStockStore = defineStore('thrift_stock', {
  state: () => ({
    stocks: [] as ThriftStock[],
    loading: false,
    error: null as string | null,
    page: 1,
    pageSize: 20,
    total: 0,
    totalPages: 0,
    search: '',
    statusFilter: null as string | null,
    conditionFilter: null as string | null,
  }),

  actions: {
    async loadStocks(
      tenantId: number,
      options?: {
        page?: number;
        pageSize?: number;
        search?: string;
        status?: string | null;
        condition?: string | null;
      },
    ) {
      this.loading = true;
      this.error = null;
      try {
        const page = options?.page ?? this.page;
        const pageSize = options?.pageSize ?? this.pageSize;
        const search = options?.search ?? this.search;
        const status = options?.status !== undefined ? options.status : this.statusFilter;
        const condition =
          options?.condition !== undefined ? options.condition : this.conditionFilter;

        const result = await thriftStockRepository.fetchStocksPaginated({
          tenantId,
          page,
          pageSize,
          search,
          status,
          condition,
        });

        this.stocks = result.data;
        this.page = result.meta.page;
        this.pageSize = result.meta.page_size;
        this.total = result.meta.total;
        this.totalPages = result.meta.total_pages;
        this.search = search;
        this.statusFilter = status;
        this.conditionFilter = condition;
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
      color: string,
      size: string,
      condition: string,
      barcode: string,
      stockType: string,
      quantity: number,
      boxId: number | undefined,
      productWeight: number | undefined,
      extraWeight: number | undefined,
      note: string,
      userEmail: string,
      pricing: ThriftStockPricingInput,
      imageUrl?: string,
      shelfId?: number | null,
      originUnitPrice?: number,
      extraOriginUnitPrice?: number,
      additionalChargesCost?: number,
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
            shelf_id: shelfId ?? null,
            color,
            size,
            condition: condition as ThriftCondition,
            barcode,
            stock_type: stockType as ThriftStockType,
            quantity,
            box_id: boxId || undefined,
            product_weight: productWeight || undefined,
            extra_weight: extraWeight || undefined,
            origin_unit_price: originUnitPrice ?? undefined,
            extra_origin_unit_price: extraOriginUnitPrice ?? undefined,
            additional_charges_cost: additionalChargesCost ?? undefined,
            status: 'AVAILABLE',
            note: note || '',
            inserted_by: userEmail,
          },
          pricing,
          imageUrl,
        );
        this.stocks.unshift(stock);
        this.total += 1;
        return stock;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create stock';
        throw err;
      }
    },

    async updateStock(
      id: number,
      stock: Partial<ThriftStock>,
      pricing: ThriftStockPricingInput,
      imageUrl?: string | null,
      driveFileId?: string | null,
    ) {
      try {
        const updated = await thriftStockRepository.updateStock(
          id,
          stock,
          pricing,
          imageUrl,
          driveFileId,
        );
        const idx = this.stocks.findIndex((s) => s.id === id);
        if (idx !== -1) {
          const currentStock = this.stocks[idx]!;
          this.stocks[idx] = {
            ...currentStock,
            ...updated,
            image_url: imageUrl !== undefined ? imageUrl || undefined : currentStock.image_url,
            drive_file_id:
              driveFileId !== undefined ? driveFileId || undefined : currentStock.drive_file_id,
          };
        }
        return updated;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update stock';
        throw err;
      }
    },

    async attachStockImage(id: number, imageUrl: string, insertedBy: string, driveFileId?: string) {
      try {
        await thriftStockRepository.upsertPrimaryStockImage(id, imageUrl, insertedBy, driveFileId);
        const idx = this.stocks.findIndex((s) => s.id === id);
        if (idx !== -1) {
          const currentStock = this.stocks[idx]!;
          this.stocks[idx] = {
            ...currentStock,
            image_url: imageUrl,
            drive_file_id: driveFileId,
          };
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to attach stock image';
        throw err;
      }
    },

    async updateStockStatus(id: number, status: string) {
      try {
        await thriftStockRepository.updateStockStatus(id, status);
        const idx = this.stocks.findIndex((s) => s.id === id);
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
        this.stocks = this.stocks.filter((s) => s.id !== id);
        this.total = Math.max(0, this.total - 1);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete stock';
        throw err;
      }
    },

    async deleteStocks(ids: number[]) {
      if (!ids.length) return;
      try {
        await thriftStockRepository.deleteStocks(ids);
        const idSet = new Set(ids);
        const removedCount = this.stocks.filter((stock) => idSet.has(stock.id)).length;
        this.stocks = this.stocks.filter((stock) => !idSet.has(stock.id));
        this.total = Math.max(0, this.total - removedCount);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete stock';
        throw err;
      }
    },
  },
});
