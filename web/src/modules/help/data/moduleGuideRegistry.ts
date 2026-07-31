import type { ModuleGuide } from '../types';

import { customerDashboardGuide } from './guides/customerDashboard';
import { gettingStartedGuide } from './guides/gettingStarted';
import { investorPortalGuide } from './guides/investorPortal';
import { platformAdminGuide } from './guides/platformAdmin';
import { shopCategoriesGuide } from './guides/shopCategories';
import { shopManagementGuide } from './guides/shopManagement';
import { shopOrderMerchantGuide } from './guides/shopOrderMerchant';
import { shopOrderStaffGuide } from './guides/shopOrderStaff';
import { thriftBarcodeGuide } from './guides/thriftBarcode';
import { thriftShipmentGuide } from './guides/thriftShipment';
import { thriftStockGuide } from './guides/thriftStock';
import { universalWalletGuide } from './guides/universalWallet';

/**
 * Aggregates per-guide files under `data/guides/`.
 * Add a new guide file there, then register it here.
 */
export const MODULE_GUIDE_REGISTRY: readonly ModuleGuide[] = [
  customerDashboardGuide,
  gettingStartedGuide,
  platformAdminGuide,
  shopCategoriesGuide,
  shopManagementGuide,
  shopOrderStaffGuide,
  shopOrderMerchantGuide,
  universalWalletGuide,
  investorPortalGuide,
  thriftStockGuide,
  thriftShipmentGuide,
  thriftBarcodeGuide,
];

