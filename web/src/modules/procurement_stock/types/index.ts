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
  GlobalShipmentCostType,
  ReviseShipmentCostEntryInput,
  ShipmentCostPaymentSource,
  UpsertShipmentCostEntryPayload,
} from './shipmentCostEntry';
export { DAY_ONE_COST_TYPES, STUB_COST_TYPES } from './shipmentCostEntry';
export type {
  ShipmentSection,
  ShipmentSectionMetadata,
  CreateShipmentSectionPayload,
  UpdateShipmentSectionPayload,
} from './shipmentSection';
export {
  STOCK_AVAILABILITY_OPTIONS,
  formatStockAvailability,
  availabilityChipColor,
  type StockAvailability,
} from '../constants/stockAvailability';