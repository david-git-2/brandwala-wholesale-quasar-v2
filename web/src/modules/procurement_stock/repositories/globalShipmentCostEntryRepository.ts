import type {
  GlobalShipmentCostEntry,
  ReviseShipmentCostEntryInput,
  UpsertShipmentCostEntryPayload,
} from '../types/shipmentCostEntry';
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';

export const SHIPMENT_COST_ENTRIES_RETIRED_MESSAGE =
  'Shipment cost entries were retired (Option A). Add or edit costs as AP bills on the Costs tab.';

const costEntriesRetired = (): never => {
  throw new Error(SHIPMENT_COST_ENTRIES_RETIRED_MESSAGE);
};

export interface SaveShipmentCostEntriesOptions {
  deleteIds?: number[];
  receivedWeight?: number | null;
  totalWeightKg?: number | null;
}

export interface SaveShipmentCostEntriesResult {
  cost_entries: GlobalShipmentCostEntry[];
  items: GlobalShipmentItem[];
  items_stamped: number;
  shipment: {
    id: number;
    received_weight: number | null;
    total_weight_kg: number | null;
    updated_at: string;
  } | null;
}

export type IssueShipmentCostEntryApV2Result = {
  bill_id?: number | string;
  invoice_no?: string;
  status?: string;
  total_amount?: number | string;
  due_amount?: number | string;
  cost_entry_id?: number | string;
  source_type?: string;
  source_id?: string;
  source_key?: string;
  ap_kind?: string;
};

const listByShipmentId = async (_shipmentId: number): Promise<GlobalShipmentCostEntry[]> =>
  costEntriesRetired();

const ensureFromHeader = async (_shipmentId: number): Promise<void> => costEntriesRetired();

const saveBatch = async (
  _shipmentId: number,
  _entries: UpsertShipmentCostEntryPayload[],
  _options: SaveShipmentCostEntriesOptions = {},
): Promise<SaveShipmentCostEntriesResult> => costEntriesRetired();

const upsert = async (_payload: UpsertShipmentCostEntryPayload): Promise<GlobalShipmentCostEntry> =>
  costEntriesRetired();

const remove = async (_id: number): Promise<void> => costEntriesRetired();

const issueCostEntryApViaMoneyKernel = async (
  _costEntryId: number,
): Promise<IssueShipmentCostEntryApV2Result & { bill_id: number }> => costEntriesRetired();

const revise = async (
  _shipmentId: number,
  _entries: ReviseShipmentCostEntryInput[],
): Promise<{ shipment_id: number; items_stamped: number; wallet_posted: boolean }> =>
  costEntriesRetired();

export const globalShipmentCostEntryRepository = {
  listByShipmentId,
  ensureFromHeader,
  saveBatch,
  upsert,
  remove,
  revise,
  issueCostEntryApViaMoneyKernel,
};
