/** Weight-only header edits must not run sync_shipment_ap_bills (can mint legacy AP drafts from header totals). */
export const SHIPMENT_WEIGHT_ONLY_UPDATE_FIELDS = new Set([
  'received_weight',
  'total_weight_kg',
]);

const AP_SYNC_SHIPMENT_FIELDS = new Set([
  'vendor_id',
  'cargo_company_id',
  'name',
  'shipment_purchase_currency_id',
  'shipment_cost_currency_id',
  'purchase_invoice_total',
  'cargo_invoice_total',
  'buckets',
]);

/** Header fields that do not affect shipment AP sync (workflow / UI). */
const WORKFLOW_ONLY_SHIPMENT_FIELDS = new Set([
  'status',
  'stock_ready',
  'type',
  'received_date',
  'progress_tag_id',
  'progress_flow_id',
  'inventory_added',
  'is_archived',
]);

export const isShipmentWeightOnlyUpdate = (payload: Record<string, unknown>): boolean => {
  const keys = Object.keys(payload).filter((key) => payload[key] !== undefined);
  return keys.length > 0 && keys.every((key) => SHIPMENT_WEIGHT_ONLY_UPDATE_FIELDS.has(key));
};

export const shouldSyncShipmentApBills = (payload: Record<string, unknown>): boolean => {
  const keys = Object.keys(payload).filter((key) => payload[key] !== undefined);
  if (keys.length === 0) return false;
  if (isShipmentWeightOnlyUpdate(payload)) return false;
  if (payload.status === 'cancelled') return true;
  if (keys.some((key) => AP_SYNC_SHIPMENT_FIELDS.has(key))) return true;
  if (keys.every((key) => WORKFLOW_ONLY_SHIPMENT_FIELDS.has(key))) return false;
  return true;
};

/** After a workflow status dialog save, only cancelled needs a full overview reload. */
export const shouldRefetchOverviewAfterWorkflowStatusChange = (newStatus: string): boolean =>
  newStatus === 'cancelled';