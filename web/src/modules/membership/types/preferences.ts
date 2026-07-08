export interface MembershipPreferenceSchema {
  ui?: {
    productBasedCosting?: {
      fileDetailsVisibleColumns?: string[];
    };
    thriftShipment?: {
      detailsVisibleColumns?: string[];
    };
    procurementShipment?: {
      detailsVisibleColumns?: string[];
    };
    appearance?: {
      darkMode?: boolean;
      density?: 'comfortable' | 'compact';
      navPinned?: boolean;
    };
  };
}

export const MEMBERSHIP_UI_PATHS = {
  productBasedCostingFileDetailsColumns: ['ui', 'productBasedCosting', 'fileDetailsVisibleColumns'],
  thriftShipmentDetailsColumns: ['ui', 'thriftShipment', 'detailsVisibleColumns'],
  procurementShipmentDetailsColumns: ['ui', 'procurementShipment', 'detailsVisibleColumns'],
  uiAppearanceDarkMode: ['ui', 'appearance', 'darkMode'],
  uiAppearanceDensity: ['ui', 'appearance', 'density'],
  uiAppearanceNavPinned: ['ui', 'appearance', 'navPinned'],
} as const;

export type MembershipUiPathKey = keyof typeof MEMBERSHIP_UI_PATHS;

export const LEGACY_MEMBERSHIP_PREFERENCE_KEYS: Record<string, MembershipUiPathKey> = {
  'ui.productBasedCosting.fileDetailsVisibleColumns': 'productBasedCostingFileDetailsColumns',
  'ui.thriftShipment.detailsVisibleColumns': 'thriftShipmentDetailsColumns',
  'ui.procurementShipment.detailsVisibleColumns': 'procurementShipmentDetailsColumns',
};
