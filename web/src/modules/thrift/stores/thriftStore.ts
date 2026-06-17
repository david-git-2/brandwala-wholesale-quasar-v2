import { defineStore } from 'pinia';
import { thriftRepository } from '../repositories/thriftRepository';
import type {
  ThriftCategory,
  ThriftType,
  ThriftShelf,
  ThriftStock,
  ThriftInvoice,
  ThriftLedgerEntry,
  ThriftBox,
  ThriftSection,
  ThriftCondition,
  ThriftStockType,
  ThriftStockStatus,
} from '../types';

export const useThriftStore = defineStore('thrift', {
  state: () => ({
    categories: [] as ThriftCategory[],
    types: [] as ThriftType[],
    shelves: [] as ThriftShelf[],
    stocks: [] as ThriftStock[],
    invoices: [] as ThriftInvoice[],
    ledgerEntries: [] as ThriftLedgerEntry[],
    boxes: [] as ThriftBox[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadModuleData(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        const [cats, typs, shlvs, stks, invs, ldgr, bxs] = await Promise.all([
          thriftRepository.fetchCategories(tenantId),
          thriftRepository.fetchTypes(tenantId),
          thriftRepository.fetchShelves(tenantId),
          thriftRepository.fetchStocks(tenantId),
          thriftRepository.fetchInvoices(tenantId),
          thriftRepository.fetchLedger(tenantId),
          thriftRepository.fetchBoxes(tenantId),
        ]);

        this.categories = cats;
        this.types = typs;
        this.shelves = shlvs;
        this.stocks = stks;
        this.invoices = invs;
        this.ledgerEntries = ldgr;
        this.boxes = bxs;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load Thrift module data';
      } finally {
        this.loading = false;
      }
    },

    async createCategory(tenantId: number, name: string, description: string, userEmail: string) {
      try {
        const cat = await thriftRepository.createCategory({
          tenant_id: tenantId,
          name,
          description,
          inserted_by: userEmail,
        });
        this.categories.push(cat);
        return cat;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create category';
        throw err;
      }
    },

    async createType(tenantId: number, name: string, description: string, userEmail: string) {
      try {
        const typ = await thriftRepository.createType({
          tenant_id: tenantId,
          name,
          description,
          inserted_by: userEmail,
        });
        this.types.push(typ);
        return typ;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create type';
        throw err;
      }
    },

    async createShelf(tenantId: number, name: string, locationBay: string, shelfCode: string, userEmail: string) {
      try {
        const shlf = await thriftRepository.createShelf({
          tenant_id: tenantId,
          name,
          location_bay: locationBay,
          shelf_code: shelfCode,
          inserted_by: userEmail,
        });
        this.shelves.push(shlf);
        return shlf;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create shelf';
        throw err;
      }
    },

    async createBox(tenantId: number, shipmentId: number, name: string, weight: number, receivedWeight: number, userEmail: string) {
      try {
        const box = await thriftRepository.createBox({
          tenant_id: tenantId,
          shipment_id: shipmentId,
          name,
          weight: weight || undefined,
          received_weight: receivedWeight || undefined,
          inserted_by: userEmail,
        });
        this.boxes.push(box);
        return box;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create box';
        throw err;
      }
    },

    async deleteBox(id: number) {
      try {
        await thriftRepository.deleteBox(id);
        this.boxes = this.boxes.filter(b => b.id !== id);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete box';
        throw err;
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
        const stock = await thriftRepository.createStock(
          {
            tenant_id: tenantId,
            shipment_id: shipmentId,
            name,
            brand_name: brandName || undefined,
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
            status: 'AVAILABLE',
            note: note || undefined,
            inserted_by: userEmail,
          },
          pricing
        );
        this.stocks.unshift(stock);
        return stock;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create stock';
        throw err;
      }
    },

    async updateStockStatus(id: number, status: string) {
      try {
        await thriftRepository.updateStockStatus(id, status);
        const idx = this.stocks.findIndex(s => s.id === id);
        if (idx !== -1 && this.stocks[idx]) {
          this.stocks[idx].status = status as ThriftStockStatus;
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update stock status';
        throw err;
      }
    },

    async sellThriftItems(params: {
      tenantId: number;
      invoiceNumber: string;
      recipientName: string;
      address: string;
      phone: string;
      transactionMethod: string;
      codCharge: number;
      packingCharge: number;
      invoicePrintCharge: number;
      shippingChargeCustomer: number;
      insertedBy: string;
      items: Array<{
        stock_id: number;
        quantity: number;
        sold_price: number;
        platform_fees: number;
        shipping_cost_paid_by_shop: number;
      }>;
    }) {
      this.loading = true;
      try {
        const invoiceId = await thriftRepository.markItemsAsSold(params);
        // Refresh local cache data
        await this.loadModuleData(params.tenantId);
        return invoiceId;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to mark items as sold';
        throw err;
      } finally {
        this.loading = false;
      }
    },
  },
});
