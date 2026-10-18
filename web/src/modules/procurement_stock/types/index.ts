// Shared procurement_stock types — domain modules import from typed files.
export type { StockLocation, StockLocationKind, UpsertStockLocationPayload } from './stockLocation';
export type {
  CargoCompany,
  CargoCompanyCreateInput,
  CargoCompanyUpdateInput,
} from './cargoCompany';
export type {
  CostEntryDraft,
  CostEntriesSavePayload,
  GlobalShipmentCostEntry,
  GlobalShipmentCostBucket,
  GlobalShipmentCostComponent,
  ReviseShipmentCostEntryInput,
  UpsertShipmentCostEntryPayload,
} from './shipmentCostEntry';
export {
  CARGO_COST_BUCKET,
  DEFAULT_COST_COMPONENT,
  LOCAL_COST_BUCKET,
  PRODUCT_COST_BUCKET,
} from './shipmentCostEntry';
export type {
  ShipmentSection,
  ShipmentSectionMetadata,
  CreateShipmentSectionPayload,
  UpdateShipmentSectionPayload,
} from './shipmentSection';
export {
  STOCK_AVAILABILITY_OPTIONS,
  STOCK_AVAILABILITY_LABELS,
  type StockAvailability,
} from '../constants/stockAvailability';
