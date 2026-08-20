import { defineStore } from 'pinia';
import {
  globalShipmentRepository,
  type FinalizeShipmentResult,
  type FinalizeShipmentStockRow,
  type GlobalShipment,
  type GlobalShipmentItem,
  type SettleShipmentPayeeParams,
  type ShipmentProgressFlow,
  type ShipmentProgressFlowStage,
  type ShipmentProgressTag,
  type ShipmentSummaryKPIs,
} from '../repositories/globalShipmentRepository';
import { globalShipmentBoxRepository } from '../repositories/globalShipmentBoxRepository';
import { type GlobalShipmentBox } from '../repositories/globalShipmentBoxRepository';
import { globalShipmentCostEntryRepository } from '../repositories/globalShipmentCostEntryRepository';
import { shipmentSectionRepository } from '../repositories/shipmentSectionRepository';
import type {
  CostEntryDraft,
  GlobalShipmentCostEntry,
  ReviseShipmentCostEntryInput,
} from '../types/shipmentCostEntry';
import type {
  CreateShipmentSectionPayload,
  ShipmentSection,
  UpdateShipmentSectionPayload,
} from '../types/shipmentSection';
import { isShipmentCostFinalized } from '../utils/costEntriesCosting';
import { applyShipmentWeightBalance } from '../utils/applyShipmentWeightBalance';
import { applyShipmentPurchaseBalance } from '../utils/applyShipmentPurchaseBalance';
import { syncShipmentWeightToProduct } from '../utils/syncShipmentWeightToProduct';
import { supabase } from 'src/boot/supabase';
import { useStockLocationStore } from './stockLocationStore';
import { getDefaultPutawayLocationId } from '../utils/stockLocationOptions';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export const useGlobalShipmentStore = defineStore('global_shipment', {
  state: () => ({
    rows: [] as GlobalShipment[],
    loading: false,
    saving: false,
    error: null as string | null,
    page: 1,
    pageSize: 20,
    total: 0,
    totalPages: 0,
    search: '',
    statusFilter: null as string | null,

    // Single shipment states
    currentShipment: null as GlobalShipment | null,
    currentShipmentSections: [] as ShipmentSection[],
    currentShipmentItems: [] as GlobalShipmentItem[],
    currentShipmentBoxes: [] as GlobalShipmentBox[],
    currentShipmentStocks: [] as any[],
    currentCostEntries: [] as GlobalShipmentCostEntry[],
    currentShipmentSummary: null as ShipmentSummaryKPIs | null,
    costEntriesLoading: false,
    costEntriesSaving: false,
    progressTags: [] as ShipmentProgressTag[],
    progressFlows: [] as ShipmentProgressFlow[],
    progressStagesByFlow: {} as Record<number, ShipmentProgressFlowStage[]>,
    progressUpdating: false,
  }),


  actions: {
    async fetchShipments(
      tenantId: number,
      options?: {
        page?: number;
        pageSize?: number;
        search?: string | null;
        status?: string | null;
      },
    ) {
      this.loading = true;
      this.error = null;
      try {
        const page = options?.page ?? this.page;
        const pageSize = options?.pageSize ?? this.pageSize;
        const search = options?.search !== undefined ? options.search : this.search;
        const status = options?.status !== undefined ? options.status : this.statusFilter;

        const result = await globalShipmentRepository.listPaginated(
          tenantId,
          page,
          pageSize,
          search || undefined,
          status || undefined,
        );

        this.rows = result.data;
        this.page = result.meta.page;
        this.pageSize = result.meta.pageSize;
        this.total = result.meta.total;
        this.totalPages = result.meta.totalPages;
        this.search = search || '';
        this.statusFilter = status;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load shipments';
      } finally {
        this.loading = false;
      }
    },

    async fetchShipmentBoxes(shipmentId: number) {
      try {
        const boxes = await globalShipmentBoxRepository.listByShipmentId(shipmentId);
        this.currentShipmentBoxes = boxes;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load boxes';
      }
    },

    async fetchShipmentSections(shipmentId: number) {
      try {
        const sections = await shipmentSectionRepository.listByShipmentId(shipmentId);
        this.currentShipmentSections = sections;
        return sections;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load shipment sections';
        return [];
      }
    },

    async fetchShipmentDetails(shipmentId: number) {
      this.loading = true;
      this.error = null;
      try {
        const overview = await globalShipmentRepository.getShipmentOverviewDetails(shipmentId);
        this.currentShipment = overview.shipment;
        this.currentShipmentItems = overview.items;
        this.currentShipmentBoxes = overview.boxes;
        this.currentShipmentSections = overview.sections;
        this.currentCostEntries = overview.cost_entries as any;

        if (overview.shipment.progress_flow_id && overview.flow_stages?.length) {
          this.progressStagesByFlow[overview.shipment.progress_flow_id] = overview.flow_stages;
        }

        this.currentShipmentStocks = [];
        return overview;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load shipment details';
      } finally {
        this.loading = false;
      }
    },


    async fetchShipmentSummary(shipmentId: number) {
      try {
        this.currentShipmentSummary = await globalShipmentRepository.getShipmentSummary(shipmentId);
        return this.currentShipmentSummary;
      } catch (err: unknown) {
        console.error('Failed to fetch shipment summary', err);
        return null;
      }
    },

    async fetchCostEntries(shipmentId: number) {
      this.costEntriesLoading = true;
      try {
        await globalShipmentCostEntryRepository.ensureFromHeader(shipmentId);
        this.currentCostEntries =
          (await globalShipmentCostEntryRepository.listByShipmentId(shipmentId)) as any;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load cost entries';
        this.currentCostEntries = [];
        throw err;
      } finally {
        this.costEntriesLoading = false;
      }
    },

    /**
     * Pre-finalize: upsert/delete via cost-entry RPCs.
     * Post-finalize (stock_ready / Ready Stock): revise_global_shipment_costs only.
     */
    async saveCostEntries(shipmentId: number, drafts: CostEntryDraft[]) {
      const shipment = this.currentShipment;
      if (!shipment || shipment.id !== shipmentId) {
        throw new Error('Shipment not loaded');
      }

      this.costEntriesSaving = true;
      this.error = null;
      try {
        const finalized = isShipmentCostFinalized(shipment);

        if (finalized) {
          const payload: ReviseShipmentCostEntryInput[] = drafts.map((d) => {
            const meta: Record<string, unknown> = {};
            if (d.cost_type === 'cargo' && d.per_kg_rate != null) {
              meta.per_kg_rate = d.per_kg_rate;
            }
            if (d.note != null && d.note.trim() !== '') {
              meta.note = d.note.trim();
            }
            return {
              cost_type: d.cost_type,
              amount: Number(d.amount) || 0,
              exchange_rate: Number(d.exchange_rate) || 1,
              payment_source: d.payment_source,
              entity_type: d.entity_type,
              entity_id: d.entity_type ? d.entity_id : null,
              section_id: d.section_id ?? null,
              metadata: meta,
            };
          });
          await globalShipmentCostEntryRepository.revise(shipmentId, payload);
        } else {
          const existingIds = new Set(this.currentCostEntries.map((e: any) => e.id));
          const keptIds = new Set(
            drafts.map((d) => d.id).filter((id): id is number => typeof id === 'number'),
          );

          for (const id of existingIds) {
            if (typeof id === 'number' && !keptIds.has(id)) {
              await globalShipmentCostEntryRepository.remove(id);
            }
          }

          for (const d of drafts) {
            const meta: Record<string, unknown> = {};
            if (d.cost_type === 'cargo' && d.per_kg_rate != null) {
              meta.per_kg_rate = d.per_kg_rate;
            }
            if (d.note != null && d.note.trim() !== '') {
              meta.note = d.note.trim();
            }

            await globalShipmentCostEntryRepository.upsert({
              shipment_id: shipmentId,
              id: d.id,
              cost_type: d.cost_type,
              amount: Number(d.amount) || 0,
              exchange_rate: Number(d.exchange_rate) || 1,
              payment_source: d.payment_source,
              entity_type: d.entity_type,
              entity_id: d.entity_type ? d.entity_id : null,
              section_id: d.section_id ?? null,
              metadata: meta,
            });
          }
        }

        this.currentCostEntries =
          (await globalShipmentCostEntryRepository.listByShipmentId(shipmentId)) as any;

        if (finalized) {
          this.currentShipmentItems =
            await globalShipmentRepository.listShipmentItems(shipmentId);
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to save cost entries';
        throw err;
      } finally {
        this.costEntriesSaving = false;
      }
    },

    /**
     * Match invoices: write paid purchase total to the single product cost entry.
     * Multiple product FX rows → edit on Landed cost instead.
     */
    async savePurchaseInvoiceTotal(shipmentId: number, total: number) {
      const shipment = this.currentShipment;
      if (!shipment || shipment.id !== shipmentId) {
        throw new Error('Current shipment not loaded');
      }

      const count = this.currentCostEntries.filter((e: any) => e.cost_type === 'product').length;
      if (count > 1) {
        throw new Error(
          'Multiple product cost entries exist. Update on Landed cost tab directly.',
        );
      }

      this.costEntriesSaving = true;
      this.error = null;
      try {
        const existing: any = this.currentCostEntries.find((e: any) => e.cost_type === 'product');
        const rounded = Math.round(total * 100) / 100;
        const payload: any = {
          shipment_id: shipmentId,
          id: existing?.id ?? null,
          cost_type: 'product',
          amount: rounded,
          exchange_rate: existing ? Number(existing.exchange_rate) || 1 : 1,
          currency_id: existing?.currency_id ?? shipment.shipment_purchase_currency_id,
          payment_source: existing?.payment_source ?? null,
          entity_type:
            existing?.entity_type === 'vendor' || existing?.entity_type === 'cargo_company'
              ? existing.entity_type
              : null,
          entity_id: existing?.entity_id ?? null,
          metadata: existing?.metadata ?? {},
        };
        await globalShipmentCostEntryRepository.upsert(payload);

        this.currentCostEntries =
          (await globalShipmentCostEntryRepository.listByShipmentId(shipmentId)) as any;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to save purchase invoice total';
        throw err;
      } finally {
        this.costEntriesSaving = false;
      }
    },

    async applyWeightBalance(shipmentId: number) {
      this.loading = true;
      this.error = null;
      try {
        const preload =
          this.currentShipment && this.currentShipment.id === shipmentId
            ? { shipment: this.currentShipment, items: this.currentShipmentItems }
            : undefined;
        const result = await applyShipmentWeightBalance(shipmentId, preload);
        await this.fetchShipmentDetails(shipmentId);
        return result;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to apply weight balance';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async applyPurchaseBalance(shipmentId: number) {
      this.loading = true;
      this.error = null;
      try {
        if (!this.currentCostEntries.length || this.currentShipment?.id !== shipmentId) {
          await this.fetchCostEntries(shipmentId);
        }
        const preload =
          this.currentShipment && this.currentShipment.id === shipmentId
            ? {
                shipment: this.currentShipment,
                items: this.currentShipmentItems,
                costEntries: this.currentCostEntries,
              }
            : undefined;
        const result = await applyShipmentPurchaseBalance(shipmentId, preload as any);
        await this.fetchShipmentDetails(shipmentId);
        return result;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to apply purchase balance';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async createShipment(
      tenantId: number,
      payload: {
        name: string;
        type: 'international' | 'local' | 'transfer';
        shipment_purchase_currency_id: number | null;
        shipment_cost_currency_id: number | null;
      },
    ) {
      this.loading = true;
      this.error = null;
      try {
        const newShipment = await globalShipmentRepository.createShipment(tenantId, payload);
        this.rows.unshift(newShipment);
        return newShipment;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create shipment';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async createShipmentDraft(
      tenantId: number,
      payload: {
        name: string;
        type: 'international' | 'local' | 'transfer';
        vendor_id?: number | null;
        cargo_company_id?: number | null;
      },
    ) {
      this.loading = true;
      this.error = null;
      try {
        const newShipment = await globalShipmentRepository.createShipmentDraft(tenantId, payload);
        this.rows.unshift(newShipment);
        return newShipment;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create shipment';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async updateShipment(
      id: number,
      payload: Partial<
        Omit<GlobalShipment, 'id' | 'created_at' | 'updated_at' | 'parent_tenant_id'>
      >,
    ) {
      this.loading = true;
      this.error = null;
      try {
        const updated = await globalShipmentRepository.updateShipment(id, payload);
        if (this.currentShipment?.id === id) {
          this.currentShipment = updated;
        }
        const index = this.rows.findIndex((r) => r.id === id);
        if (index !== -1) {
          this.rows[index] = updated;
        }
        return updated;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update shipment';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async deleteShipment(id: number) {
      this.loading = true;
      this.error = null;
      try {
        // Block delete if referenced in global_stocks
        const isReferenced = await globalShipmentRepository.checkShipmentStockReferences(id);
        if (isReferenced) {
          throw new Error(
            'Cannot delete shipment. One or more shipment items are currently referenced in Warehouse Stock.',
          );
        }

        await globalShipmentRepository.deleteShipment(id);
        this.rows = this.rows.filter((r) => r.id !== id);
        if (this.currentShipment?.id === id) {
          this.currentShipment = null;
          this.currentShipmentSections = [];
          this.currentShipmentItems = [];
          this.currentShipmentBoxes = [];
          this.currentShipmentStocks = [];
          this.currentCostEntries = [];
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete shipment';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    mergeShipmentItems(shipmentId: number, items: GlobalShipmentItem[]) {
      if (this.currentShipment?.id !== shipmentId || items.length === 0) return;
      const itemMap = new Map(this.currentShipmentItems.map((item) => [item.id, item]));
      for (const newItem of items) {
        if (newItem?.id != null) itemMap.set(newItem.id, newItem);
      }
      this.currentShipmentItems = Array.from(itemMap.values()).sort(
        (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
      );
    },

    async addShipmentItem(
      payload: Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'sort_order'>,
    ) {
      this.saving = true;
      this.error = null;
      try {
        const maxSortOrder =
          this.currentShipmentItems.length > 0
            ? Math.max(...this.currentShipmentItems.map((item) => item.sort_order ?? 0))
            : 0;
        const defaultSectionId =
          payload.section_id ??
          (this.currentShipment?.id === payload.shipment_id
            ? (this.currentShipmentSections[0]?.id ?? null)
            : null);

        const newItem = await globalShipmentRepository.createShipmentItem({
          ...payload,
          section_id: defaultSectionId,
          sort_order: maxSortOrder + 1,
        });
        if (this.currentShipment?.id === payload.shipment_id) {
          this.currentShipmentItems.push(newItem);
        }
        return newItem;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to add shipment item';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async addShipmentItemsBulk(
      shipmentId: number,
      items: Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'sort_order'>[],
    ) {
      if (items.length === 0) return [];
      this.saving = true;
      this.error = null;
      try {
        const addedItems = await globalShipmentRepository.createShipmentItemsBulk(
          shipmentId,
          items as any,
        );
        this.mergeShipmentItems(shipmentId, addedItems);
        return addedItems;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to add shipment items in bulk';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async updateShipmentItem(
      id: number,
      payload: Partial<
        Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'shipment_id'>
      >,
    ) {
      const index = this.currentShipmentItems.findIndex((item) => item.id === id);
      if (index === -1) {
        throw new Error('Item not found in current shipment');
      }
      const existingItem = this.currentShipmentItems[index];
      if (!existingItem) {
        throw new Error('Item not found in current shipment');
      }

      // Snapshot previous item state for rollback if API call fails
      const previousItem = { ...existingItem };

      // Optimistically update local store state instantly (0ms delay)
      const optimisticItem = { ...previousItem, ...payload } as GlobalShipmentItem;
      const optimisticItems = [...this.currentShipmentItems];
      optimisticItems[index] = optimisticItem;
      this.currentShipmentItems = optimisticItems;

      this.saving = true;
      this.error = null;

      try {
        const updated = await globalShipmentRepository.updateShipmentItem(id, payload);
        const syncItems = [...this.currentShipmentItems];
        const syncIndex = syncItems.findIndex((item) => item.id === id);
        if (syncIndex !== -1) {
          syncItems[syncIndex] = { ...syncItems[syncIndex], ...updated };
          this.currentShipmentItems = syncItems;
        }
        return updated;
      } catch (err: unknown) {
        // Rollback optimistic update on error
        const rollbackItems = [...this.currentShipmentItems];
        const rollbackIndex = rollbackItems.findIndex((item) => item.id === id);
        if (rollbackIndex !== -1) {
          rollbackItems[rollbackIndex] = previousItem;
          this.currentShipmentItems = rollbackItems;
        }
        this.error = (err as Error).message || 'Failed to update shipment item';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async updateShipmentItemsBulk(
      shipmentId: number,
      updates: Array<{
        id: number;
        payload: Partial<
          Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'shipment_id'>
        >;
      }>,
    ) {
      if (updates.length === 0) return [];
      this.saving = true;
      this.error = null;
      try {
        const updatedItems = await globalShipmentRepository.updateShipmentItemsBulk(
          shipmentId,
          updates,
        );

        if (this.currentShipment?.id === shipmentId) {
          const itemMap = new Map(this.currentShipmentItems.map((item) => [item.id, item]));
          for (const updated of updatedItems) {
            itemMap.set(updated.id, updated);
          }
          this.currentShipmentItems = Array.from(itemMap.values()).sort(
            (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
          );
        }

        // Sync modified weight fields to the products catalog in background
        const productUpdates: Promise<void>[] = [];
        for (const u of updates) {
          const item = this.currentShipmentItems.find((item) => item.id === u.id);
          if (item && item.product_id != null) {
            if ('product_weight' in u.payload && u.payload.product_weight !== undefined) {
              productUpdates.push(
                syncShipmentWeightToProduct(
                  item.product_id,
                  'product_weight',
                  u.payload.product_weight,
                ),
              );
            }
            if ('package_weight' in u.payload && u.payload.package_weight !== undefined) {
              productUpdates.push(
                syncShipmentWeightToProduct(
                  item.product_id,
                  'package_weight',
                  u.payload.package_weight,
                ),
              );
            }
          }
        }
        if (productUpdates.length > 0) {
          void Promise.all(productUpdates);
        }

        return updatedItems;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update shipment items in bulk';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async deleteShipmentItem(id: number) {
      this.saving = true;
      this.error = null;
      try {
        const isReferenced = await globalShipmentRepository.checkShipmentItemStockReferences(id);
        if (isReferenced) {
          throw new Error(
            'Cannot delete item. This shipment item is referenced in Warehouse Stock.',
          );
        }

        await globalShipmentRepository.deleteShipmentItem(id);
        this.currentShipmentItems = this.currentShipmentItems.filter((item) => item.id !== id);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete shipment item';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async deleteShipmentItemsBulk(shipmentId: number, ids: number[]) {
      if (ids.length === 0) return;
      this.saving = true;
      this.error = null;
      try {
        await globalShipmentRepository.deleteShipmentItemsBulk(shipmentId, ids);
        const idSet = new Set(ids);
        this.currentShipmentItems = this.currentShipmentItems.filter((item) => !idSet.has(item.id));
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete selected items';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async reorderShipmentItems(
      shipmentId: number,
      itemsOrder: { id: number; sort_order: number }[],
    ) {
      this.loading = true;
      this.error = null;
      try {
        await globalShipmentRepository.updateShipmentItemsOrder(itemsOrder);
        await this.fetchShipmentDetails(shipmentId);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to reorder shipment items';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    /**
     * Receive: stamp landed_cost_bdt + post stock via finalize_global_shipment.
     * No wallet / ledger posts. Cost-entry mutation after this uses revise only.
     */
    async finalizeShipment(
      shipmentId: number,
      stockRows: FinalizeShipmentStockRow[],
    ): Promise<FinalizeShipmentResult> {
      this.loading = true;
      this.error = null;
      try {
        if (!stockRows.length) {
          throw new Error('No quantities received to stock.');
        }

        const result = await globalShipmentRepository.finalizeShipment(shipmentId, stockRows);

        if (
          typeof result?.items_stamped !== 'number' ||
          typeof result?.stock_rows_posted !== 'number'
        ) {
          throw new Error('Invalid finalize response: missing stamp counts');
        }
        if (result.wallet_posted === true) {
          throw new Error('Finalize unexpectedly posted wallet ledger rows');
        }

        if (this.currentShipment?.id === shipmentId) {
          this.currentShipment = {
            ...this.currentShipment,
            status: 'received',
            stock_ready: result.stock_ready === true,
            inventory_added: result.stock_ready === true,
          };
        }

        await this.fetchShipmentDetails(shipmentId);
        return result;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to finalize shipment';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async ensureProgressTags(tenantId: number) {
      try {
        this.progressFlows = await globalShipmentRepository.listShipmentProgressFlows(tenantId, true);
        const flowId =
          this.currentShipment?.progress_flow_id ??
          this.progressFlows.find((flow) => flow.is_default)?.id ??
          null;
        if (!flowId) {
          this.progressTags = [];
          return;
        }
        const stages = await globalShipmentRepository.listShipmentProgressFlowStages(flowId, false);
        this.progressStagesByFlow[flowId] = stages;
        this.progressTags = stages.map((stage) => ({
          id: stage.tag_id,
          name: stage.name,
          slug: stage.slug,
          group_name: 'shipment_progress',
          sort_order: stage.sort_order,
          color: stage.color,
          is_active: stage.is_active,
        }));
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load progress tags';
        throw err;
      }
    },

    async setProgressTag(shipmentId: number, tagId: number | null) {
      this.progressUpdating = true;
      this.error = null;
      try {
        const progressTag = await globalShipmentRepository.setShipmentProgressTag(
          shipmentId,
          tagId,
        );
        if (this.currentShipment?.id === shipmentId) {
          this.currentShipment = {
            ...this.currentShipment,
            progress_tag: progressTag,
            progress_tag_id: progressTag?.id ?? null,
          };
        }
        const idx = this.rows.findIndex((r) => r.id === shipmentId);
        const existingRow = this.rows[idx];
        if (existingRow) {
          this.rows[idx] = {
            ...existingRow,
            progress_tag: progressTag,
            progress_tag_id: progressTag?.id ?? null,
          };
        }
        return progressTag;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update progress tag';
        throw err;
      } finally {
        this.progressUpdating = false;
      }
    },

    async autoAcceptAllSplits(shipmentId: number) {
      this.loading = true;
      this.error = null;
      try {
        const authStore = useAuthStore();
        const locationStore = useStockLocationStore();

        if (!authStore.tenantId) {
          throw new Error('Tenant ID is missing');
        }

        if (locationStore.items.length === 0) {
          await locationStore.fetchLocations(authStore.tenantId, false);
        }

        const locationId = getDefaultPutawayLocationId(locationStore.items);
        if (!locationId) {
          throw new Error('No default put-away location configured');
        }

        const items = this.currentShipmentItems;
        const stocks = this.currentShipmentStocks || [];

        const pendingItems = items.filter((item) => {
          const itemStocks = stocks.filter((s) => s.shipment_item_id === item.id);
          const sum = itemStocks.reduce((acc, s) => acc + (s.quantity || 0), 0);
          return sum !== item.ordered_quantity;
        });

        if (pendingItems.length === 0) {
          return;
        }

        const pendingItemIds = pendingItems.map((item) => item.id);
        const { error: deleteError } = await supabase
          .from('global_stocks')
          .delete()
          .in('shipment_item_id', pendingItemIds);
        if (deleteError) throw deleteError;

        const stockRows = pendingItems.map((item) => ({
          parent_tenant_id: authStore.tenantId!,
          shipment_item_id: item.id,
          availability: 'sellable' as const,
          location_id: locationId,
          quantity: item.ordered_quantity,
          is_usable: true,
        }));

        const { error: insertError } = await supabase.from('global_stocks').insert(stockRows);
        if (insertError) throw insertError;

        await this.fetchShipmentDetails(shipmentId);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to auto-accept splits';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async rollbackShipmentToDraft(shipmentId: number) {
      this.loading = true;
      this.error = null;
      try {
        // 1. Check for invoice references
        const invoiceNos =
          await globalShipmentRepository.checkShipmentInvoiceReferences(shipmentId);
        if (invoiceNos.length > 0) {
          throw new Error(
            `Cannot rollback shipment. The following invoices contain stock from this shipment and must be deleted first: ${invoiceNos.join(', ')}`,
          );
        }

        // 2. Delete global_stocks associated with shipment items
        const itemIds = this.currentShipmentItems.map((item) => item.id);
        if (itemIds.length > 0) {
          const { error: deleteStocksError } = await supabase
            .from('global_stocks')
            .delete()
            .in('shipment_item_id', itemIds);
          if (deleteStocksError) throw deleteStocksError;
        }

        // 3. Update shipment status to Draft and stock_ready to false
        await globalShipmentRepository.updateShipment(shipmentId, {
          status: 'draft',
          stock_ready: false,
        });

        // 4. Reload details
        await this.fetchShipmentDetails(shipmentId);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to rollback shipment';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async assignShipmentToChild(parentTenantId: number, childTenantId: number | null, shipmentId: number) {
      this.loading = true;
      this.error = null;
      try {
        const res = await globalShipmentRepository.assignShipmentToChild(parentTenantId, childTenantId, shipmentId);
        if (this.currentShipment?.id === shipmentId) {
          this.currentShipment = {
            ...this.currentShipment,
            assigned_child_tenant_id: childTenantId,
          };
        }
        return res;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to assign shipment to child';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async returnShipmentToVendor(
      shipmentId: number,
      itemsQty: Array<{ shipment_item_id: number; quantity: number }>,
      outcome: 'cash_refund' | 'store_credit',
    ) {
      this.loading = true;
      this.error = null;
      try {
        const res = await globalShipmentRepository.returnShipmentToVendor(shipmentId, itemsQty, outcome);
        await this.fetchShipmentDetails(shipmentId);
        return res;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to process vendor return';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async settleShipmentPayee(params: SettleShipmentPayeeParams) {
      this.loading = true;
      this.error = null;
      try {
        const res = await globalShipmentRepository.settleShipmentPayee(params);
        return res;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to settle shipment payee';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async listShipmentPayeeSettlements(shipmentId: number) {
      this.loading = true;
      this.error = null;
      try {
        const res = await globalShipmentRepository.listShipmentPayeeSettlements(shipmentId);
        return res;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to list shipment payee settlements';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    // --- Public tracking token ---

    async generateTrackingToken(shipmentId: number) {
      this.error = null;
      try {
        const token = await globalShipmentRepository.generateTrackingToken(shipmentId);
        if (this.currentShipment?.id === shipmentId) {
          this.currentShipment = { ...this.currentShipment, public_tracking_token: token };
        }
        const idx = this.rows.findIndex((r) => r.id === shipmentId);
        if (idx >= 0) this.rows[idx] = { ...this.rows[idx]!, public_tracking_token: token };
        return token;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to generate tracking link';
        throw err;
      }
    },

    async revokeTrackingToken(shipmentId: number) {
      this.error = null;
      try {
        await globalShipmentRepository.revokeTrackingToken(shipmentId);
        if (this.currentShipment?.id === shipmentId) {
          this.currentShipment = { ...this.currentShipment, public_tracking_token: null };
        }
        const idx = this.rows.findIndex((r) => r.id === shipmentId);
        if (idx >= 0) this.rows[idx] = { ...this.rows[idx]!, public_tracking_token: null };
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to revoke tracking link';
        throw err;
      }
    },

    // --- Progress flow settings management ---

    async loadProgressFlows(tenantId: number, includeArchived = true) {
      return this.loadProgressTagsForSettings(tenantId, includeArchived);
    },

    async loadProgressTagsForSettings(tenantId: number, includeArchived = true) {
      this.error = null;
      try {
        this.progressFlows = await globalShipmentRepository.listShipmentProgressFlows(
          tenantId,
          includeArchived,
        );
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load progress flows';
        throw err;
      }
    },

    async loadProgressFlowStages(flowId: number, includeArchived = true) {
      this.error = null;
      try {
        const stages = await globalShipmentRepository.listShipmentProgressFlowStages(
          flowId,
          includeArchived,
        );
        this.progressStagesByFlow[flowId] = stages;
        return stages;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load progress stages';
        throw err;
      }
    },

    async createProgressFlow(tenantId: number, name: string) {
      this.error = null;
      try {
        const flow = await globalShipmentRepository.createShipmentProgressFlow(tenantId, name);
        this.progressFlows = [...this.progressFlows, flow].sort((a, b) => a.name.localeCompare(b.name));
        return flow;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create progress flow';
        throw err;
      }
    },

    async updateProgressFlow(flowId: number, name: string) {
      this.error = null;
      try {
        const flow = await globalShipmentRepository.updateShipmentProgressFlow(flowId, name);
        const idx = this.progressFlows.findIndex((item) => item.id === flowId);
        if (idx >= 0) this.progressFlows[idx] = flow;
        return flow;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update progress flow';
        throw err;
      }
    },

    async archiveProgressFlow(flowId: number, archive: boolean) {
      this.error = null;
      try {
        const flow = await globalShipmentRepository.archiveShipmentProgressFlow(flowId, archive);
        const idx = this.progressFlows.findIndex((item) => item.id === flowId);
        if (idx >= 0) this.progressFlows[idx] = flow;
        return flow;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to archive progress flow';
        throw err;
      }
    },

    async setDefaultProgressFlow(flowId: number) {
      this.error = null;
      try {
        const flow = await globalShipmentRepository.setDefaultShipmentProgressFlow(flowId);
        this.progressFlows = this.progressFlows.map((item) => ({
          ...item,
          is_default: item.id === flow.id,
        }));
        return flow;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to set default flow';
        throw err;
      }
    },

    async createProgressFlowStage(flowId: number, name: string, color?: string | null) {
      this.error = null;
      try {
        const stage = await globalShipmentRepository.createShipmentProgressFlowStage(flowId, name, color);
        const list = this.progressStagesByFlow[flowId] ?? [];
        this.progressStagesByFlow[flowId] = [...list, stage].sort((a, b) => a.sort_order - b.sort_order);
        return stage;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create progress stage';
        throw err;
      }
    },

    async updateProgressFlowStage(flowId: number, flowStageId: number, fields: { name?: string; color?: string | null }) {
      this.error = null;
      try {
        const stage = await globalShipmentRepository.updateShipmentProgressFlowStage(flowStageId, fields);
        const list = this.progressStagesByFlow[flowId] ?? [];
        const idx = list.findIndex((item) => item.flow_stage_id === flowStageId);
        if (idx >= 0) list[idx] = stage;
        this.progressStagesByFlow[flowId] = [...list];
        return stage;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update progress stage';
        throw err;
      }
    },

    async archiveProgressFlowStage(flowId: number, flowStageId: number, archive: boolean) {
      this.error = null;
      try {
        const stage = await globalShipmentRepository.archiveShipmentProgressFlowStage(flowStageId, archive);
        const list = this.progressStagesByFlow[flowId] ?? [];
        const idx = list.findIndex((item) => item.flow_stage_id === flowStageId);
        if (idx >= 0) list[idx] = stage;
        this.progressStagesByFlow[flowId] = [...list];
        return stage;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to archive progress stage';
        throw err;
      }
    },

    async reorderProgressFlowStages(flowId: number, flowStageIds: number[]) {
      this.error = null;
      try {
        await globalShipmentRepository.reorderShipmentProgressFlowStages(flowId, flowStageIds);
        const byId = Object.fromEntries(
          (this.progressStagesByFlow[flowId] ?? []).map((stage) => [stage.flow_stage_id, stage]),
        );
        this.progressStagesByFlow[flowId] = flowStageIds
          .map((id, idx) => ({ ...byId[id], sort_order: idx + 1 }))
          .filter(Boolean) as ShipmentProgressFlowStage[];
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to reorder progress stages';
        throw err;
      }
    },

    async setShipmentFlow(shipmentId: number, flowId: number) {
      this.progressUpdating = true;
      this.error = null;
      try {
        await globalShipmentRepository.setShipmentProgressFlow(shipmentId, flowId);
        const flow = this.progressFlows.find((item) => item.id === flowId) ?? null;
        const stages = await globalShipmentRepository.listShipmentProgressFlowStages(flowId, false);
        this.progressStagesByFlow[flowId] = stages;
        this.progressTags = stages.map((stage) => ({
          id: stage.tag_id,
          name: stage.name,
          slug: stage.slug,
          group_name: 'shipment_progress',
          sort_order: stage.sort_order,
          color: stage.color,
          is_active: stage.is_active,
        }));
        if (this.currentShipment?.id === shipmentId) {
          const currentTagId = this.currentShipment.progress_tag_id;
          const currentStillValid =
            currentTagId != null &&
            stages.some((stage) => stage.tag_id === currentTagId);
          this.currentShipment = {
            ...this.currentShipment,
            progress_flow_id: flowId,
            progress_flow: flow,
            progress_tag_id: currentStillValid
              ? (currentTagId ?? null)
              : (stages[0]?.tag_id ?? null),
          };
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to set shipment flow';
        throw err;
      } finally {
        this.progressUpdating = false;
      }
    },

    async createSection(payload: CreateShipmentSectionPayload) {
      this.saving = true;
      this.error = null;
      try {
        const newSection = await shipmentSectionRepository.create(payload);
        if (this.currentShipment?.id === payload.shipment_id) {
          this.currentShipmentSections.push(newSection);
          this.currentShipmentSections.sort((a, b) => a.sort_order - b.sort_order);
        }
        return newSection;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create shipment section';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async updateSection(id: number, payload: UpdateShipmentSectionPayload) {
      this.saving = true;
      this.error = null;
      try {
        const updated = await shipmentSectionRepository.update(id, payload);
        const idx = this.currentShipmentSections.findIndex((s) => s.id === id);
        if (idx >= 0) {
          this.currentShipmentSections[idx] = updated;
          this.currentShipmentSections.sort((a, b) => a.sort_order - b.sort_order);
        }
        return updated;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update shipment section';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async deleteSection(id: number) {
      this.saving = true;
      this.error = null;
      try {
        await shipmentSectionRepository.delete(id);
        this.currentShipmentSections = this.currentShipmentSections.filter((s) => s.id !== id);
        // Clear section_id on local items assigned to this section
        this.currentShipmentItems = this.currentShipmentItems.map((item) =>
          item.section_id === id ? { ...item, section_id: null } : item,
        );
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete shipment section';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async reorderSections(shipmentId: number, sectionIds: number[]) {
      this.saving = true;
      this.error = null;
      try {
        await shipmentSectionRepository.reorder(shipmentId, sectionIds);
        if (this.currentShipment?.id === shipmentId) {
          const sectionMap = new Map(this.currentShipmentSections.map((s) => [s.id, s]));
          this.currentShipmentSections = sectionIds
            .map((id, idx) => {
              const sec = sectionMap.get(id);
              return sec ? { ...sec, sort_order: idx } : null;
            })
            .filter((s): s is ShipmentSection => s !== null);
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to reorder shipment sections';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async moveItemToSection(itemId: number, sectionId: number | null) {
      return this.updateShipmentItem(itemId, { section_id: sectionId });
    },
  },
});


