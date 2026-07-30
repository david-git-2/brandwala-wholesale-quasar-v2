import type { ModuleGuide } from '../types';

import { gettingStartedGuide } from './guides/gettingStarted';
import { investorPortalGuide } from './guides/investorPortal';
import { platformAdminGuide } from './guides/platformAdmin';
import { shopCategoriesGuide } from './guides/shopCategories';
import { shopManagementGuide } from './guides/shopManagement';
import { shopOrderMerchantGuide } from './guides/shopOrderMerchant';
import { shopOrderStaffGuide } from './guides/shopOrderStaff';
import { universalWalletGuide } from './guides/universalWallet';

/**
 * Aggregates per-guide files under `data/guides/`.
 * Add a new guide file there, then register it here.
 */
export const MODULE_GUIDE_REGISTRY: readonly ModuleGuide[] = [
  gettingStartedGuide,
  platformAdminGuide,
  shopCategoriesGuide,
  shopManagementGuide,
  shopOrderStaffGuide,
  shopOrderMerchantGuide,
  universalWalletGuide,
  investorPortalGuide,
];
